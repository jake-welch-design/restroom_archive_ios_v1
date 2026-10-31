#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit) && canImport(UniformTypeIdentifiers)
import ArchiveCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

public struct SubmitWizardView: View {
    @Environment(AppState.self) private var appState

    @State private var currentStep: Int = 1
    @State private var selectedFileData: Data?
    @State private var selectedFileName: String = ""
    @State private var activeDraftId: UUID?
    @State private var fileError: String?

    @State private var name: String = ""
    @State private var city: String = ""
    @State private var country: String = ""
    @State private var subdivision: String = ""
    @State private var lat: String = ""
    @State private var lng: String = ""
    @State private var scanDate: Date = Date()
    @State private var descriptionText: String = ""
    @State private var descriptors: [String] = []

    @State private var nearbyPlaceSuggestions: [String] = []
    @State private var coordsCheckResult: (key: String, ok: Bool)?
    @State private var isCheckingCoords: Bool = false

    @State private var compliesWithAgreements: Bool = false
    @State private var showAgreementsInline: Bool = false
    @State private var uploadError: String?
    @State private var isUploading: Bool = false
    @State private var uploadSuccess: Bool = false

    @State private var showFileImporter: Bool = false
    @State private var showGuideSheet: Bool = false
    @State private var showDraftsSheet: Bool = false
    @State private var savedDrafts: [DraftSubmission] = []

    public init() {}

    private static var glbContentTypes: [UTType] {
        var types: [UTType] = [.data, .item]
        if let glb = UTType(filenameExtension: "glb") {
            types.insert(glb, at: 0)
        }
        return types
    }

    private var subdivisions: [Region]? {
        Regions.subdivisions(for: country)
    }

    private var locationValid: Bool {
        guard !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !country.isEmpty else {
            return false
        }
        return subdivisions == nil || !subdivision.isEmpty
    }

    private var composedLocation: String {
        locationValid ? Regions.composeLocation(city: city, country: country, subdivision: subdivision) : ""
    }

    private var step1Valid: Bool {
        selectedFileData != nil
    }

    private var step2Valid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              locationValid,
              let parsedLat = Double(lat.trimmingCharacters(in: .whitespaces)),
              let parsedLng = Double(lng.trimmingCharacters(in: .whitespaces)),
              (-90...90).contains(parsedLat),
              (-180...180).contains(parsedLng) else {
            return false
        }
        return true
    }

    private var step3Valid: Bool {
        !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var coordsKey: String {
        "\(composedLocation)|\(country)|\(lat)|\(lng)"
    }

    private var coordsOk: Bool? {
        coordsCheckResult?.key == coordsKey ? coordsCheckResult?.ok : nil
    }

    private var googleMapsURL: URL {
        let query = [name.trimmingCharacters(in: .whitespacesAndNewlines), composedLocation]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !query.isEmpty,
           let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)") {
            return url
        }
        return URL(string: "https://www.google.com/maps")!
    }

    public var body: some View {
        Group {
            if let user = appState.currentUser {
                if user.isBanned {
                    gatedNotice(
                        title: "Account Suspended",
                        body: user.adminMessage ?? "Your account cannot submit scans at this time."
                    )
                } else if user.isMuted {
                    gatedNotice(
                        title: "Temporarily Muted",
                        body: "Your account is temporarily muted until \(ArchiveDateFormatter.formatDayMonthYear(user.mutedUntil))."
                    )
                } else if !user.canSubmit {
                    ScrollView {
                        SubmissionAccessRequestView()
                            .padding(16)
                    }
                } else {
                    wizardContent(isAdmin: user.isAdmin)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Sign in to submit scans to The Restroom Archive.")
                                .font(ArchiveFont.regular(13))
                                .foregroundStyle(ArchiveColor.muted)
                            Spacer()
                            Button("Submission Guide ?") {
                                showGuideSheet = true
                            }
                            .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                        }
                        AuthFormView()
                    }
                    .padding(16)
                }
            }
        }
        .background(ArchiveColor.paper)
        .task {
            await reloadDraftsList()
            await openPendingDraftIfNeeded()
        }
        .onChange(of: appState.pendingDraftIdToOpen) { _, _ in
            Task { await openPendingDraftIfNeeded() }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: Self.glbContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImportedFile(result)
        }
        .sheet(isPresented: $showGuideSheet) {
            SubmissionGuideSheet()
        }
        .sheet(isPresented: $showDraftsSheet) {
            draftsPickerSheet
        }
    }

    private func gatedNotice(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ArchiveFont.bold(14))
                .foregroundStyle(ArchiveColor.danger)
            Text(body)
                .font(ArchiveFont.regular(13))
                .foregroundStyle(ArchiveColor.ink)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Wizard Body

    private func wizardContent(isAdmin: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header toolbar: Guide + Offline Drafts
                HStack(spacing: 8) {
                    Button("Submission Guide ?") {
                        showGuideSheet = true
                    }
                    .buttonStyle(ArchiveOutlineButtonStyle(compact: true))

                    if !savedDrafts.isEmpty {
                        Button("Drafts (\(savedDrafts.count))") {
                            showDraftsSheet = true
                        }
                        .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                    }

                    Spacer()

                    if selectedFileData != nil && !uploadSuccess {
                        Button("Save Draft") {
                            Task { await saveCurrentAsDraft() }
                        }
                        .buttonStyle(ArchiveLinkButtonStyle())
                    }
                }

                if uploadSuccess {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(isAdmin ? "Published." : "Submitted for approval.")
                            .font(ArchiveFont.bold(14))
                            .foregroundStyle(ArchiveColor.publish)

                        Text("Your scan is now loaded in the 3D stage above.")
                            .font(ArchiveFont.regular(12))
                            .foregroundStyle(ArchiveColor.muted)

                        Button("Submit another") {
                            resetWizard(restoreStage: false)
                        }
                        .buttonStyle(ArchiveOutlineButtonStyle())
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
                } else {
                    stepTabBar

                    switch currentStep {
                    case 1:
                        step1ScanView
                    case 2:
                        step2DetailsView
                    case 3:
                        step3DescriptionView
                    default:
                        step4ReviewView
                    }
                }
            }
            .padding(16)
        }
    }

    private var stepTabBar: some View {
        let steps: [(n: Int, label: String)] = [
            (1, "Scan"),
            (2, "Details"),
            (3, "Description"),
            (4, "Review")
        ]
        return HStack(spacing: 0) {
            ForEach(steps, id: \.n) { step in
                let active = currentStep == step.n
                let accessible = canAccessStep(step.n)
                Button {
                    if accessible { currentStep = step.n }
                } label: {
                    Text("\(step.n) \(step.label)")
                        .font(active ? ArchiveFont.bold(11.5) : ArchiveFont.regular(11.5))
                        .foregroundStyle(
                            active
                                ? ArchiveColor.paper
                                : (accessible ? ArchiveColor.ink : ArchiveColor.dim)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(active ? ArchiveColor.ink : ArchiveColor.paper)
                        .overlay(alignment: .leading) {
                            if step.n > 1 {
                                Rectangle().fill(ArchiveColor.ink).frame(width: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(!accessible)
            }
        }
        .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
    }

    // MARK: - Step 1: Scan (.glb)

    private var step1ScanView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GLB file *")
                .font(ArchiveFont.medium(12))
                .foregroundStyle(ArchiveColor.ink)

            Button {
                showFileImporter = true
            } label: {
                HStack {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 14))
                    Text(selectedFileData == nil ? "Choose .glb File from Files…" : "Replace .glb File…")
                        .font(ArchiveFont.regular(13))
                    Spacer()
                }
                .padding(12)
                .background(ArchiveColor.subtleFill)
                .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if let fileError {
                Text(fileError)
                    .font(ArchiveFont.regular(12))
                    .foregroundStyle(ArchiveColor.danger)
            } else if let data = selectedFileData {
                Text("\(selectedFileName) (\(UploadLimits.formatFileSize(Int64(data.count)))) selected. Previewing live in the 3D stage above.")
                    .font(ArchiveFont.regular(12))
                    .foregroundStyle(ArchiveColor.ink)
            } else {
                Text("Up to \(UploadLimits.maxGlbMB) MB. Tip: You can also export a .GLB directly from Scaniverse or Files using the iOS Share Sheet -> The Restroom Archive.")
                    .font(ArchiveFont.regular(12))
                    .foregroundStyle(ArchiveColor.muted)
            }

            HStack {
                if selectedFileData != nil {
                    Button("Clear Scan") {
                        resetWizard(restoreStage: true)
                    }
                    .buttonStyle(ArchiveLinkButtonStyle())
                }
                Spacer()
                Button("Next") {
                    Task { await goNext() }
                }
                .buttonStyle(ArchivePrimaryButtonStyle())
                .disabled(!step1Valid)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Step 2: Details + Native Location Autofill

    private var step2DetailsView: some View {
        VStack(alignment: .leading, spacing: 13) {
            // 1-Tap iOS Location Autofill Banner
            HStack(spacing: 8) {
                Button {
                    Task { await autofillFromCurrentLocation() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: appState.locationService.isLocating ? "location.fill" : "location")
                            .font(.system(size: 11))
                        Text(appState.locationService.isLocating ? "Locating…" : "Use Current Location")
                    }
                }
                .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                .disabled(appState.locationService.isLocating)

                Text("Autofills coordinates, city, country & nearby places")
                    .font(ArchiveFont.regular(11))
                    .foregroundStyle(ArchiveColor.muted)
            }

            // Establishment Name
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("Name *")
                        .font(ArchiveFont.medium(12))
                    InfoTooltipButton(
                        title: "Name",
                        lines: ["The name of the establishment."]
                    )
                }
                TextField("Establishment name", text: $name)
                    .archiveFieldStyle()

                if !nearbyPlaceSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(nearbyPlaceSuggestions, id: \.self) { place in
                                Button(place) {
                                    name = place
                                }
                                .font(ArchiveFont.regular(11))
                                .foregroundStyle(ArchiveColor.ink)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(ArchiveColor.subtleFill)
                                .overlay(Rectangle().stroke(ArchiveColor.inputBorder, lineWidth: 1))
                            }
                        }
                    }
                }
            }

            // City
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("City *")
                        .font(ArchiveFont.medium(12))
                    InfoTooltipButton(
                        title: "City",
                        lines: [
                            "The town or city as it would appear in a mailing address (in Manhattan, that's New York).",
                            "The Archive adds the state, province or country from your picks below."
                        ]
                    )
                }
                TextField("Brooklyn", text: $city)
                    .archiveFieldStyle()
            }

            // Country
            VStack(alignment: .leading, spacing: 5) {
                Text("Country *")
                    .font(ArchiveFont.medium(12))
                Picker("Country", selection: $country) {
                    Text("Select a country").tag("")
                    ForEach(Regions.countries) { c in
                        Text(c.name).tag(c.code)
                    }
                }
                .pickerStyle(.menu)
                .tint(ArchiveColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .archiveFieldStyle()
                .onChange(of: country) { _, newCountry in
                    if !Regions.isSubdivisionCode(country: newCountry, code: subdivision) {
                        subdivision = ""
                    }
                }
            }

            // US State / Canadian Province
            if let subdivisions {
                VStack(alignment: .leading, spacing: 5) {
                    Text(country == "CA" ? "Province *" : "State *")
                        .font(ArchiveFont.medium(12))
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

            if !composedLocation.isEmpty {
                Text("Will be listed as \"\(composedLocation)\".")
                    .font(ArchiveFont.regular(11))
                    .foregroundStyle(ArchiveColor.muted)
            }

            // Coordinates
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("Coordinates *")
                        .font(ArchiveFont.medium(12))
                    InfoTooltipButton(
                        title: "Coordinates",
                        lines: [
                            "Please be as accurate as you can. Tap 'Use Current Location' while on site, or copy coordinates from Google Maps and tap 'Paste'."
                        ]
                    )
                    Spacer()
                    Button("Paste") {
                        if let str = UIPasteboard.general.string,
                           let pair = Regions.parseCoordinatePair(str) {
                            lat = pair.lat
                            lng = pair.lng
                        }
                    }
                    .buttonStyle(ArchiveLinkButtonStyle())

                    Link("Google Maps", destination: googleMapsURL)
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.ink)
                        .underline()
                }

                HStack(spacing: 8) {
                    TextField("Latitude", text: $lat)
                        .keyboardType(.numbersAndPunctuation)
                        .archiveFieldStyle()
                    TextField("Longitude", text: $lng)
                        .keyboardType(.numbersAndPunctuation)
                        .archiveFieldStyle()
                }

                if coordsOk == false {
                    Text("Coordinates don't match the location")
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.danger)
                }
            }

            // Date
            VStack(alignment: .leading, spacing: 5) {
                Text("Date *")
                    .font(ArchiveFont.medium(12))
                DatePicker("", selection: $scanDate, displayedComponents: .date)
                    .labelsHidden()
            }

            HStack {
                Button("Back") { currentStep = 1 }
                    .buttonStyle(ArchiveLinkButtonStyle())
                Spacer()
                Button(isCheckingCoords ? "Checking…" : "Next") {
                    Task { await goNext() }
                }
                .buttonStyle(ArchivePrimaryButtonStyle())
                .disabled(!step2Valid || isCheckingCoords || coordsOk == false)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Step 3: Description & Descriptors

    private var step3DescriptionView: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("Description *")
                        .font(ArchiveFont.medium(12))
                    InfoTooltipButton(
                        title: "A good description tells us:",
                        lines: [
                            "• How does someone find this restroom inside the establishment?",
                            "• What are the primary amenities and where are they placed relative to each other?",
                            "• What are the decorative characteristics?",
                            "• How does the space feel?",
                            "• Are there any notable aspects you would like visitors to pay attention to?"
                        ]
                    )
                    Spacer()
                    Text("\(descriptionText.count)/1000")
                        .font(ArchiveFont.mono(11))
                        .foregroundStyle(ArchiveColor.muted)
                }

                TextEditor(text: $descriptionText)
                    .font(ArchiveFont.regular(13))
                    .frame(minHeight: 130)
                    .padding(4)
                    .overlay(Rectangle().stroke(ArchiveColor.inputBorder, lineWidth: 1))
                    .onChange(of: descriptionText) { _, val in
                        if val.count > 1000 {
                            descriptionText = String(val.prefix(1000))
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("Descriptors")
                        .font(ArchiveFont.medium(12))
                    InfoTooltipButton(
                        title: "Choosing Descriptors",
                        lines: [
                            "Choose tags that describe: Setting / Context, Condition / Maintenance, Spatial Quality, Atmosphere, Decor, or unique continuities.",
                            "Accessible tag checklist: Spacious enough for a wheelchair, grab bars, knee clearance under sink, lever/push/sensor faucet (no knobs), and lever door handle."
                        ]
                    )
                }
                TagInputView(
                    tags: $descriptors,
                    suggestions: appState.descriptorSuggestions
                )
            }

            HStack {
                Button("Back") { currentStep = 2 }
                    .buttonStyle(ArchiveLinkButtonStyle())
                Spacer()
                Button("Next") {
                    Task { await goNext() }
                }
                .buttonStyle(ArchivePrimaryButtonStyle())
                .disabled(!step3Valid)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Step 4: Review & 8-Point Attestation

    private var step4ReviewView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                reviewRow("File", "\(selectedFileName) (\(UploadLimits.formatFileSize(Int64(selectedFileData?.count ?? 0))))")
                reviewRow("Name", name)
                reviewRow("Location", composedLocation)
                reviewRow("Coordinates", "\(lat), \(lng)")
                reviewRow("Date", ArchiveDateFormatter.formatDayMonthYear(ArchiveDateFormatter.isoDateString(from: scanDate)))
                reviewRow("Description", descriptionText)
                if !descriptors.isEmpty {
                    reviewRow("Descriptors", descriptors.joined(separator: ", "))
                }
            }
            .padding(12)
            .background(ArchiveColor.hoverFill)
            .overlay(Rectangle().stroke(ArchiveColor.rule, lineWidth: 1))

            // Per-submission attestation checkbox
            Button {
                compliesWithAgreements.toggle()
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: compliesWithAgreements ? "checkmark.square.fill" : "square")
                        .font(.system(size: 15))
                        .foregroundStyle(ArchiveColor.ink)
                    Text("I confirm this submission complies with the Archivist submission agreements and license terms.")
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.ink)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)

            Button(showAgreementsInline ? "Hide submission agreements" : "Read the 8 submission agreements") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showAgreementsInline.toggle()
                }
            }
            .buttonStyle(ArchiveLinkButtonStyle())

            if showAgreementsInline {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(SubmissionAgreements.all.enumerated()), id: \.offset) { idx, agreement in
                        Text("\(idx + 1). \(agreement)")
                            .font(ArchiveFont.regular(11.5))
                            .foregroundStyle(ArchiveColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(ArchiveColor.subtleFill)
                .overlay(Rectangle().stroke(ArchiveColor.rule, lineWidth: 1))
            }

            if let uploadError {
                Text(uploadError)
                    .font(ArchiveFont.regular(12))
                    .foregroundStyle(ArchiveColor.danger)
            }

            HStack {
                Button("Back") { currentStep = 3 }
                    .buttonStyle(ArchiveLinkButtonStyle())
                    .disabled(isUploading)
                Spacer()
                Button(isUploading ? "Uploading…" : "Submit Scan") {
                    Task { await submitUpload() }
                }
                .buttonStyle(ArchivePrimaryButtonStyle())
                .disabled(isUploading || !compliesWithAgreements)
            }
            .padding(.top, 4)
        }
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(ArchiveFont.medium(10.5))
                .foregroundStyle(ArchiveColor.muted)
            Text(value)
                .font(ArchiveFont.regular(12.5))
                .foregroundStyle(ArchiveColor.ink)
        }
    }

    // MARK: - Offline Drafts Sheet

    private var draftsPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(savedDrafts) { draft in
                    HStack {
                        Button {
                            Task {
                                await loadDraftIntoWizard(draft)
                                showDraftsSheet = false
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(draft.name.isEmpty ? draft.glbFileName : draft.name)
                                    .font(ArchiveFont.bold(13))
                                    .foregroundStyle(ArchiveColor.ink)
                                Text("\(UploadLimits.formatFileSize(draft.glbByteSize)) · Saved \(draft.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(ArchiveFont.regular(11))
                                    .foregroundStyle(ArchiveColor.muted)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button("Delete") {
                            Task {
                                try? await appState.draftStore.deleteDraft(id: draft.id)
                                await reloadDraftsList()
                            }
                        }
                        .font(ArchiveFont.regular(11))
                        .foregroundStyle(ArchiveColor.danger)
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Saved Drafts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { showDraftsSheet = false }
                }
            }
        }
    }

    // MARK: - Actions & Validation Helpers

    private func canAccessStep(_ step: Int) -> Bool {
        if step <= 1 { return true }
        if step == 2 { return step1Valid }
        let detailsDone = step1Valid && step2Valid && coordsOk == true
        if step == 3 { return detailsDone }
        return detailsDone && step3Valid
    }

    private func goNext() async {
        if currentStep == 1 {
            guard step1Valid else { return }
            currentStep = 2
            return
        }
        if currentStep == 2 {
            guard step2Valid else { return }
            await verifyCoordinates()
            guard currentStep == 2, coordsOk == true else { return }
            currentStep = 3
            return
        }
        if currentStep == 3 {
            guard step3Valid else { return }
            currentStep = 4
        }
    }

    private func verifyCoordinates() async {
        let key = coordsKey
        if coordsCheckResult?.key == key { return }
        guard let parsedLat = Double(lat.trimmingCharacters(in: .whitespaces)),
              let parsedLng = Double(lng.trimmingCharacters(in: .whitespaces)) else {
            return
        }
        isCheckingCoords = true
        var ok = true
        if let res = try? await appState.apiClient.checkCoordinates(
            CoordsCheckRequest(
                city: city,
                country: country,
                subdivision: subdivision,
                lat: parsedLat,
                lng: parsedLng
            )
        ) {
            ok = res.match != false
        }
        isCheckingCoords = false
        coordsCheckResult = (key: key, ok: ok)
    }

    private func handleImportedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            fileError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                if let size = resourceValues.fileSize, Int64(size) > UploadLimits.maxGlbBytes {
                    fileError = "This scan is \(UploadLimits.formatFileSize(Int64(size))), over the \(UploadLimits.maxGlbMB) MB limit. Re-exporting with Draco compression, or decimating the mesh, will usually bring a room scan under it."
                    return
                }
                let data = try Data(contentsOf: url)
                if Int64(data.count) > UploadLimits.maxGlbBytes {
                    fileError = "This scan is \(UploadLimits.formatFileSize(Int64(data.count))), over the \(UploadLimits.maxGlbMB) MB limit. Re-exporting with Draco compression, or decimating the mesh, will usually bring a room scan under it."
                    return
                }
                if !UploadLimits.hasValidGLBMagic(data) {
                    fileError = "The selected file is not a valid binary glTF (.glb) model."
                    return
                }
                fileError = nil
                uploadError = nil
                selectedFileData = data
                selectedFileName = url.lastPathComponent
                appState.startLocalSubmissionPreview(glbData: data)
            } catch {
                fileError = "Could not read file: \(error.localizedDescription)"
            }
        }
    }

    private func autofillFromCurrentLocation() async {
        do {
            let snap = try await appState.locationService.fetchAutofillSnapshot()
            lat = snap.latString
            lng = snap.lngString
            if city.isEmpty && !snap.city.isEmpty {
                city = snap.city
            }
            if country.isEmpty && !snap.country.isEmpty {
                country = snap.country
                if !snap.subdivision.isEmpty {
                    subdivision = snap.subdivision
                }
            }
            nearbyPlaceSuggestions = snap.nearbyPlaceCandidates
            if name.isEmpty, let first = snap.nearbyPlaceCandidates.first {
                name = first
            }
        } catch {
            appState.showBanner(error.localizedDescription)
        }
    }

    private func saveCurrentAsDraft() async {
        guard let data = selectedFileData else { return }
        let isoDate = ArchiveDateFormatter.isoDateString(from: scanDate)
        do {
            if let existingId = activeDraftId, var draft = await appState.draftStore.draft(id: existingId) {
                draft.name = name
                draft.city = city
                draft.country = country
                draft.subdivision = subdivision
                draft.isoDate = isoDate
                draft.lat = lat
                draft.lng = lng
                draft.description = descriptionText
                draft.descriptors = descriptors
                try await appState.draftStore.updateDraft(draft)
            } else {
                var created = try await appState.draftStore.createDraftFromGLB(
                    data: data,
                    originalFileName: selectedFileName,
                    lat: lat,
                    lng: lng,
                    city: city,
                    country: country,
                    subdivision: subdivision,
                    name: name
                )
                created.isoDate = isoDate
                created.description = descriptionText
                created.descriptors = descriptors
                try await appState.draftStore.updateDraft(created)
                activeDraftId = created.id
            }
            await reloadDraftsList()
            appState.showBanner("Saved offline draft.")
        } catch {
            appState.showBanner((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func reloadDraftsList() async {
        savedDrafts = await appState.draftStore.listDrafts()
    }

    private func openPendingDraftIfNeeded() async {
        guard let targetId = appState.pendingDraftIdToOpen else { return }
        appState.pendingDraftIdToOpen = nil
        if let draft = await appState.draftStore.draft(id: targetId) {
            await loadDraftIntoWizard(draft)
        }
    }

    private func loadDraftIntoWizard(_ draft: DraftSubmission) async {
        guard let bytes = await appState.draftStore.glbData(for: draft) else {
            appState.showBanner("Draft .glb file could not be loaded.")
            return
        }
        activeDraftId = draft.id
        selectedFileData = bytes
        selectedFileName = draft.glbFileName
        name = draft.name
        city = draft.city
        country = draft.country
        subdivision = draft.subdivision
        lat = draft.lat
        lng = draft.lng
        scanDate = ArchiveDateFormatter.toUtcDate(draft.isoDate) ?? Date()
        descriptionText = draft.description
        descriptors = draft.descriptors
        fileError = nil
        uploadError = nil
        currentStep = 2
        appState.startLocalSubmissionPreview(glbData: bytes)
    }

    private func submitUpload() async {
        guard let data = selectedFileData else {
            uploadError = "Please select a .glb file."
            return
        }
        guard step3Valid else {
            uploadError = "Please add a description."
            return
        }
        guard compliesWithAgreements else {
            uploadError = "Please confirm this submission complies with the agreements."
            return
        }

        isUploading = true
        uploadError = nil
        defer { isUploading = false }

        let form = SubmitRestroomForm(
            fileData: data,
            fileName: selectedFileName.isEmpty ? "scan.glb" : selectedFileName,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            location: composedLocation,
            country: country,
            isoDate: ArchiveDateFormatter.isoDateString(from: scanDate),
            lat: lat.trimmingCharacters(in: .whitespaces),
            lng: lng.trimmingCharacters(in: .whitespaces),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            descriptors: descriptors
        )

        do {
            let res = try await appState.apiClient.submitRestroom(form)
            if let draftId = activeDraftId {
                try? await appState.draftStore.deleteDraft(id: draftId)
                activeDraftId = nil
                await reloadDraftsList()
            }
            appState.hasUnsavedSubmissionPreview = false
            await appState.refreshCatalog()
            if appState.restrooms.contains(where: { $0.slug == res.slug }) {
                appState.selectRestroom(slug: res.slug)
            } else {
                appState.restoreSelectedRestroomOnStage()
            }
            uploadSuccess = true
        } catch {
            uploadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func resetWizard(restoreStage: Bool) {
        activeDraftId = nil
        selectedFileData = nil
        selectedFileName = ""
        fileError = nil
        name = ""
        city = ""
        country = ""
        subdivision = ""
        lat = ""
        lng = ""
        scanDate = Date()
        descriptionText = ""
        descriptors = []
        nearbyPlaceSuggestions = []
        coordsCheckResult = nil
        compliesWithAgreements = false
        showAgreementsInline = false
        uploadError = nil
        uploadSuccess = false
        currentStep = 1
        if restoreStage {
            appState.endLocalSubmissionPreview()
        }
    }
}
#endif

