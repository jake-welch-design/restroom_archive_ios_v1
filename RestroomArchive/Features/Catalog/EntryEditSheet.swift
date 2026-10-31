#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI
import UIKit

public struct EntryEditSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let entry: RestroomSummary

    @State private var name: String
    @State private var city: String
    @State private var country: String
    @State private var subdivision: String
    @State private var lat: String
    @State private var lng: String
    @State private var scanDate: Date
    @State private var descriptionText: String
    @State private var descriptors: [String]
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    public init(entry: RestroomSummary) {
        self.entry = entry
        _name = State(initialValue: entry.name)
        _city = State(initialValue: Regions.cityFromLocation(entry.location))
        let initialCountry = entry.country ?? (Regions.isSubdivisionCode(country: "US", code: Regions.subdivisionFromLocation(entry.location)) ? "US" : "")
        _country = State(initialValue: initialCountry)
        let trailing = Regions.subdivisionFromLocation(entry.location)
        let initialSub = Regions.isSubdivisionCode(country: initialCountry, code: trailing) ? trailing : ""
        _subdivision = State(initialValue: initialSub)
        _lat = State(initialValue: entry.lat.map { String($0) } ?? "")
        _lng = State(initialValue: entry.lng.map { String($0) } ?? "")
        _scanDate = State(initialValue: ArchiveDateFormatter.toUtcDate(entry.isoDate) ?? Date())
        _descriptionText = State(initialValue: entry.description ?? "")
        _descriptors = State(initialValue: entry.descriptors)
    }

    private var subdivisions: [Region]? {
        Regions.subdivisions(for: country)
    }

    private var composedLocation: String {
        guard !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !country.isEmpty,
              subdivisions == nil || !subdivision.isEmpty else {
            return entry.location
        }
        return Regions.composeLocation(city: city, country: country, subdivision: subdivision)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name *")
                            .font(ArchiveFont.medium(11))
                        TextField("Establishment name", text: $name)
                            .archiveFieldStyle()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("City *")
                            .font(ArchiveFont.medium(11))
                        TextField("Brooklyn", text: $city)
                            .archiveFieldStyle()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Country *")
                            .font(ArchiveFont.medium(11))
                        Picker("Country", selection: $country) {
                            Text("Select a country").tag("")
                            ForEach(Regions.countries) { region in
                                Text(region.name).tag(region.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(ArchiveColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .archiveFieldStyle()
                        .onChange(of: country) { _, newValue in
                            if !Regions.isSubdivisionCode(country: newValue, code: subdivision) {
                                subdivision = ""
                            }
                        }
                    }

                    if let subdivisions {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(country == "CA" ? "Province *" : "State *")
                                .font(ArchiveFont.medium(11))
                            Picker("Subdivision", selection: $subdivision) {
                                Text(country == "CA" ? "Select a province" : "Select a state").tag("")
                                ForEach(subdivisions) { sub in
                                    Text(sub.name).tag(sub.code)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(ArchiveColor.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .archiveFieldStyle()
                        }
                    }

                    Text("Listed as: \"\(composedLocation)\"")
                        .font(ArchiveFont.regular(11))
                        .foregroundStyle(ArchiveColor.muted)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Coordinates")
                                .font(ArchiveFont.medium(11))
                            Spacer()
                            Button("Paste \"lat, lng\"") {
                                if let str = UIPasteboard.general.string,
                                   let pair = Regions.parseCoordinatePair(str) {
                                    lat = pair.lat
                                    lng = pair.lng
                                }
                            }
                            .buttonStyle(ArchiveLinkButtonStyle())
                        }
                        HStack(spacing: 8) {
                            TextField("Latitude", text: $lat)
                                .keyboardType(.numbersAndPunctuation)
                                .archiveFieldStyle()
                            TextField("Longitude", text: $lng)
                                .keyboardType(.numbersAndPunctuation)
                                .archiveFieldStyle()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan Date *")
                            .font(ArchiveFont.medium(11))
                        DatePicker(
                            "",
                            selection: $scanDate,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Description *")
                                .font(ArchiveFont.medium(11))
                            Spacer()
                            Text("\(descriptionText.count)/1000")
                                .font(ArchiveFont.mono(11))
                                .foregroundStyle(ArchiveColor.muted)
                        }
                        TextEditor(text: $descriptionText)
                            .font(ArchiveFont.regular(13))
                            .frame(minHeight: 110)
                            .padding(4)
                            .overlay(Rectangle().stroke(ArchiveColor.inputBorder, lineWidth: 1))
                            .onChange(of: descriptionText) { _, val in
                                if val.count > 1000 {
                                    descriptionText = String(val.prefix(1000))
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Descriptors")
                            .font(ArchiveFont.medium(11))
                        TagInputView(
                            tags: $descriptors,
                            suggestions: appState.descriptorSuggestions
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(ArchiveFont.regular(12))
                            .foregroundStyle(ArchiveColor.danger)
                    }

                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(ArchiveOutlineButtonStyle())

                        Spacer()

                        Button(isSaving ? "Saving…" : "Save Changes") {
                            Task { await save() }
                        }
                        .buttonStyle(ArchivePrimaryButtonStyle())
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(16)
            }
            .background(ArchiveColor.paper)
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let parsedLat = Double(lat.trimmingCharacters(in: .whitespaces))
        let parsedLng = Double(lng.trimmingCharacters(in: .whitespaces))

        if !city.isEmpty, !country.isEmpty, let parsedLat, let parsedLng {
            if let check = try? await appState.apiClient.checkCoordinates(
                CoordsCheckRequest(
                    city: city,
                    country: country,
                    subdivision: subdivision,
                    lat: parsedLat,
                    lng: parsedLng
                )
            ), check.match == false {
                errorMessage = "Coordinates don't match the selected location."
                return
            }
        }

        let isoDate = ArchiveDateFormatter.isoDateString(from: scanDate)
        let body = RestroomPatchBody(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            location: composedLocation,
            country: country.isEmpty ? nil : country,
            isoDate: isoDate,
            lat: parsedLat,
            lng: parsedLng,
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            descriptors: descriptors
        )

        do {
            try await appState.apiClient.updateRestroom(slug: entry.slug, body: body)
            await appState.refreshCatalog()
            appState.showBanner("Entry updated.")
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
#endif

