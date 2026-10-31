#if canImport(SwiftUI) && canImport(MapKit) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import MapKit
import SwiftUI
import UIKit

public struct ArchiveMapView: View {
    @Environment(AppState.self) private var appState
    let rows: [RestroomSummary]

    @State private var showDetailCard: Bool = true
    @State private var recenterToken: Int = 0
    @State private var recenterCoordinate: CLLocationCoordinate2D?

    public init(rows: [RestroomSummary]) {
        self.rows = rows
    }

    private var mappableRows: [RestroomSummary] {
        rows.filter(\.hasCoordinates)
    }

    public var body: some View {
        ZStack {
            ArchiveMKMapRepresentable(
                rows: mappableRows,
                selectedSlug: appState.selectedSlug,
                viewedSlugs: appState.viewedSlugs,
                basemapStyle: appState.basemapStyle,
                recenterToken: recenterToken,
                recenterCoordinate: recenterCoordinate,
                onSelectSlug: { slug in
                    appState.selectRestroom(slug: slug)
                    showDetailCard = true
                }
            )

            // Top-right basemap switcher + Near Me recenter button
            VStack {
                HStack(spacing: 6) {
                    Spacer()

                    Button {
                        Task {
                            if let coord = try? await appState.locationService.requestSingleLocation() {
                                recenterCoordinate = CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng)
                                recenterToken += 1
                            }
                        }
                    } label: {
                        Image(systemName: "location")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ArchiveColor.ink)
                            .padding(7)
                            .background(ArchiveColor.paper)
                            .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Center map on my location")

                    HStack(spacing: 0) {
                        ForEach(Array(MapBasemapStyle.allCases.enumerated()), id: \.element) { idx, style in
                            let active = appState.basemapStyle == style
                            Button {
                                appState.setBasemapStyle(style)
                            } label: {
                                Text(style.label)
                                    .font(ArchiveFont.regular(11))
                                    .foregroundStyle(active ? ArchiveColor.paper : ArchiveColor.ink)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(active ? ArchiveColor.ink : ArchiveColor.paper)
                                    .overlay(alignment: .leading) {
                                        if idx > 0 {
                                            Rectangle().fill(ArchiveColor.ink).frame(width: 1)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
                }
                .padding(10)

                Spacer()

                // Bottom selected entry detail card
                if showDetailCard, let selected = appState.selectedRestroom {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selected.name)
                                    .font(ArchiveFont.bold(13))
                                    .foregroundStyle(ArchiveColor.ink)
                                Text("\(selected.location) · \(ArchiveDateFormatter.formatDayMonthYear(selected.isoDate))")
                                    .font(ArchiveFont.regular(11))
                                    .foregroundStyle(ArchiveColor.muted)
                            }
                            Spacer()
                            Button {
                                showDetailCard = false
                            } label: {
                                Text("×")
                                    .font(ArchiveFont.regular(17))
                                    .foregroundStyle(ArchiveColor.ink)
                                    .padding(.horizontal, 4)
                            }
                            .buttonStyle(.plain)
                        }

                        ScrollView {
                            EntryDetailBlockView(entry: selected)
                        }
                        .frame(maxHeight: 165)
                    }
                    .padding(12)
                    .background(ArchiveColor.paper)
                    .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
            }
        }
    }
}

private final class RestroomPinAnnotation: NSObject, MKAnnotation {
    let slug: String
    let title: String?
    let subtitle: String?
    dynamic var coordinate: CLLocationCoordinate2D

    init(entry: RestroomSummary) {
        self.slug = entry.slug
        self.title = entry.name
        self.subtitle = entry.location
        self.coordinate = CLLocationCoordinate2D(
            latitude: entry.lat ?? 0,
            longitude: entry.lng ?? 0
        )
        super.init()
    }
}

private struct ArchiveMKMapRepresentable: UIViewRepresentable {
    let rows: [RestroomSummary]
    let selectedSlug: String?
    let viewedSlugs: Set<String>
    let basemapStyle: MapBasemapStyle
    let recenterToken: Int
    let recenterCoordinate: CLLocationCoordinate2D?
    let onSelectSlug: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectSlug: onSelectSlug)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = true
        context.coordinator.applyBasemap(basemapStyle, to: mapView)
        context.coordinator.syncPins(
            rows: rows,
            selectedSlug: selectedSlug,
            viewedSlugs: viewedSlugs,
            in: mapView,
            initialFit: true
        )
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onSelectSlug = onSelectSlug
        context.coordinator.applyBasemap(basemapStyle, to: mapView)
        context.coordinator.syncPins(
            rows: rows,
            selectedSlug: selectedSlug,
            viewedSlugs: viewedSlugs,
            in: mapView,
            initialFit: false
        )
        if context.coordinator.lastRecenterToken != recenterToken,
           let coord = recenterCoordinate {
            context.coordinator.lastRecenterToken = recenterToken
            let region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 6_000,
                longitudinalMeters: 6_000
            )
            mapView.setRegion(region, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSelectSlug: (String) -> Void
        var currentBasemap: MapBasemapStyle?
        var currentSlugs: Set<String> = []
        var selectedSlug: String?
        var viewedSlugs: Set<String> = []
        var lastRecenterToken: Int = 0
        private var activeTileOverlay: MKTileOverlay?

        init(onSelectSlug: @escaping (String) -> Void) {
            self.onSelectSlug = onSelectSlug
        }

        func applyBasemap(_ style: MapBasemapStyle, to mapView: MKMapView) {
            guard currentBasemap != style else { return }
            currentBasemap = style
            if let existing = activeTileOverlay {
                mapView.removeOverlay(existing)
            }

            let template: String
            switch style {
            case .default:
                // Exact CARTO Positron monochrome basemap used on restroomarchive.com
                template = "https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png"
            case .satellite:
                // Exact Esri World Imagery basemap used on restroomarchive.com
                template = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
            }

            let overlay = MKTileOverlay(urlTemplate: template)
            overlay.canReplaceMapContent = true
            overlay.tileSize = style == .default ? CGSize(width: 512, height: 512) : CGSize(width: 256, height: 256)
            activeTileOverlay = overlay
            mapView.addOverlay(overlay, level: .aboveLabels)
        }

        func syncPins(
            rows: [RestroomSummary],
            selectedSlug: String?,
            viewedSlugs: Set<String>,
            in mapView: MKMapView,
            initialFit: Bool
        ) {
            let incomingSlugs = Set(rows.map(\.slug))
            let selectionChanged = self.selectedSlug != selectedSlug
            let viewedChanged = self.viewedSlugs != viewedSlugs
            self.selectedSlug = selectedSlug
            self.viewedSlugs = viewedSlugs

            if incomingSlugs != currentSlugs {
                currentSlugs = incomingSlugs
                let existing = mapView.annotations.compactMap { $0 as? RestroomPinAnnotation }
                mapView.removeAnnotations(existing)
                let newPins = rows.map(RestroomPinAnnotation.init)
                mapView.addAnnotations(newPins)

                if initialFit, !newPins.isEmpty {
                    mapView.showAnnotations(newPins, animated: false)
                }
            } else if selectionChanged || viewedChanged {
                for ann in mapView.annotations {
                    guard let pin = ann as? RestroomPinAnnotation,
                          let view = mapView.view(for: pin) else { continue }
                    stylePinView(view, slug: pin.slug)
                }
            }

            if selectionChanged,
               let slug = selectedSlug,
               let target = mapView.annotations.compactMap({ $0 as? RestroomPinAnnotation }).first(where: { $0.slug == slug }) {
                let currentSpan = mapView.region.span
                let span = MKCoordinateSpan(
                    latitudeDelta: min(currentSpan.latitudeDelta, 0.25),
                    longitudeDelta: min(currentSpan.longitudeDelta, 0.25)
                )
                mapView.setRegion(MKCoordinateRegion(center: target.coordinate, span: span), animated: true)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pin = annotation as? RestroomPinAnnotation else { return nil }
            let identifier = "RestroomDotPin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: pin, reuseIdentifier: identifier)
            view.annotation = pin
            view.canShowCallout = false
            stylePinView(view, slug: pin.slug)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let pin = view.annotation as? RestroomPinAnnotation else { return }
            mapView.deselectAnnotation(pin, animated: false)
            onSelectSlug(pin.slug)
        }

        private func stylePinView(_ view: MKAnnotationView, slug: String) {
            let isSelected = (slug == selectedSlug)
            let isViewed = viewedSlugs.contains(slug)
            let size: CGFloat = isSelected ? 16 : 12

            let fillColor: UIColor
            if isSelected {
                fillColor = UIColor(red: 1.0, green: 138 / 255, blue: 138 / 255, alpha: 1.0)
            } else if isViewed {
                fillColor = UIColor(red: 201 / 255, green: 143 / 255, blue: 143 / 255, alpha: 1.0)
            } else {
                fillColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            }

            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size + 4, height: size + 4))
            view.image = renderer.image { ctx in
                let rect = CGRect(x: 2, y: 2, width: size, height: size)
                ctx.cgContext.setFillColor(fillColor.cgColor)
                ctx.cgContext.fillEllipse(in: rect)
                ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
                ctx.cgContext.setLineWidth(isSelected ? 2.0 : 1.2)
                ctx.cgContext.strokeEllipse(in: rect)
            }
            view.displayPriority = isSelected ? .required : .defaultHigh
        }
    }
}
#endif

