#if canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import Foundation
import Observation
import SwiftUI
import UIKit
import WebKit

@MainActor
@Observable
public final class StageController: NSObject {
    public private(set) var isReady: Bool = false
    public private(set) var isLoadingScan: Bool = false
    public private(set) var scanErrorMessage: String?
    public private(set) var isRateLimited: Bool = false
    public private(set) var cameraMode: CameraMode = .pov
    public private(set) var markersVisible: Bool = true
    public private(set) var createMode: Bool = false
    public private(set) var cropState: StageCropStatePayload = .idle
    public private(set) var toastMessage: String?

    public var onAnnotationTapped: ((Int) -> Void)?
    public var onPointPicked: ((Vec3, CameraSnapshot) -> Void)?

    public let schemeHandler: ArchiveSchemeHandler
    @ObservationIgnored public private(set) lazy var webView: WKWebView = makeWebView()

    @ObservationIgnored private var pendingCommands: [StageCommand] = []
    @ObservationIgnored private var cropCommitContinuation: CheckedContinuation<(CropResult?, String?), Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    public init(apiClient: APIClient, diskCache: DiskAssetCache) {
        self.schemeHandler = ArchiveSchemeHandler(apiClient: apiClient, diskCache: diskCache)
        super.init()
    }

    public func loadEntry(
        slug: String,
        remoteModelPath: String,
        crop: Crop?,
        annotations: [Annotation],
        selectedAnnotationId: Int? = nil
    ) {
        schemeHandler.setPreviewGLB(nil)
        scanErrorMessage = nil
        isRateLimited = false
        let cleanPath = remoteModelPath.hasPrefix("/") ? remoteModelPath : "/\(remoteModelPath)"
        let stageURL = "\(ArchiveSchemeHandler.scheme)://models\(cleanPath)"
        let numbered = annotations.enumerated().map { idx, ann in
            StageAnnotation(from: ann, number: idx + 1)
        }
        send(
            .loadScan(
                url: stageURL,
                slug: slug,
                crop: crop,
                annotations: numbered,
                selectedAnnotationId: selectedAnnotationId
            )
        )
    }

    public func loadLocalPreview(glbData: Data) {
        schemeHandler.setPreviewGLB(glbData)
        scanErrorMessage = nil
        isRateLimited = false
        let bust = Int(Date().timeIntervalSince1970 * 1000)
        let stageURL = "\(ArchiveSchemeHandler.scheme)://preview/scan-\(bust).glb"
        send(
            .loadScan(
                url: stageURL,
                slug: nil,
                crop: nil,
                annotations: [],
                selectedAnnotationId: nil
            )
        )
    }

    public func clearScan() {
        schemeHandler.setPreviewGLB(nil)
        send(.clearScan)
    }

    public func toggleCameraMode() {
        let next: CameraMode = (cameraMode == .pov) ? .orbit : .pov
        cameraMode = next
        send(.setMode(next))
        showToast(next == .pov ? "POV view" : "Orbit view")
    }

    public func toggleMarkersVisible() {
        markersVisible.toggle()
        send(.setMarkersVisible(markersVisible))
        showToast(markersVisible ? "Annotations on" : "Annotations off")
    }

    public func setCreateMode(_ active: Bool) {
        createMode = active
        send(.setCreateMode(active))
        if !active {
            showToast("Canceled")
        }
    }

    public func syncAnnotations(_ annotations: [Annotation], selectedId: Int?) {
        let numbered = annotations.enumerated().map { idx, ann in
            StageAnnotation(from: ann, number: idx + 1)
        }
        send(.setAnnotations(annotations: numbered, selectedId: selectedId))
    }

    public func selectAnnotation(id: Int?, fly: Bool = true) {
        if id != nil && !markersVisible {
            markersVisible = true
            send(.setMarkersVisible(true))
        }
        send(.selectAnnotation(id: id, fly: fly))
    }

    // MARK: - Admin Crop & Levelling Gizmo

    public func startCrop() {
        send(.startCrop)
    }

    public func cancelCrop() {
        send(.cancelCrop)
        showToast("Crop canceled")
    }

    public func resetCrop() {
        send(.resetCrop)
        showToast("Crop reset")
    }

    public func toggleRotateTool() {
        let next: CropGizmoTool = (cropState.tool == .rotate) ? .box : .rotate
        send(.setCropTool(next))
        showToast(next == .rotate ? "Rotate to level" : "Resize box")
    }

    public func toggleCropMode() {
        guard cropState.tool != .rotate else { return }
        let next: CropMode = (cropState.mode == .keep) ? .remove : .keep
        send(.setCropMode(next))
        showToast(next == .keep ? "Keep inside box" : "Remove inside box")
    }

    public func confirmCropRound() {
        send(.confirmCropRound)
    }

    public func discardCropRound() {
        send(.discardCropRound)
        showToast("Box discarded")
    }

    public func commitCrop() async -> (CropResult?, String?) {
        await withCheckedContinuation { continuation in
            self.cropCommitContinuation = continuation
            self.send(.commitCrop)
        }
    }

    public func applyCommittedCrop(_ result: CropResult) {
        send(.applyCommittedCrop(result))
    }

    public func showToast(_ text: String, durationSeconds: Double = 1.4) {
        toastMessage = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(durationSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }

    // MARK: - Bridge Dispatch & Event Handling

    public func send(_ command: StageCommand) {
        _ = webView
        guard isReady else {
            pendingCommands.append(command)
            return
        }
        dispatchNow(command)
    }

    private func dispatchNow(_ command: StageCommand) {
        guard let jsonData = try? JSONEncoder().encode(command),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        let js = "window.ArchiveStage && window.ArchiveStage.dispatch(\(jsonString));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    fileprivate func handleIncomingScriptBody(_ body: Any) {
        let jsonData: Data?
        if let dict = body as? [String: Any] {
            jsonData = try? JSONSerialization.data(withJSONObject: dict)
        } else if let str = body as? String {
            jsonData = Data(str.utf8)
        } else {
            jsonData = nil
        }
        guard let jsonData,
              let event = try? JSONDecoder().decode(StageEvent.self, from: jsonData) else {
            return
        }

        switch event {
        case .ready:
            isReady = true
            let queued = pendingCommands
            pendingCommands.removeAll()
            for cmd in queued {
                dispatchNow(cmd)
            }
        case .scanLoading:
            isLoadingScan = true
            scanErrorMessage = nil
            isRateLimited = false
        case .scanLoaded:
            isLoadingScan = false
            scanErrorMessage = nil
        case let .scanError(message, rateLimited):
            isLoadingScan = false
            scanErrorMessage = message
            isRateLimited = rateLimited
        case let .modeChanged(mode):
            cameraMode = mode
        case let .annotationTapped(id):
            onAnnotationTapped?(id)
        case let .pointPicked(point, snapshot):
            onPointPicked?(point, snapshot)
        case let .cropState(state):
            let wasReset = state.boxResetNotice == true
            cropState = state
            if wasReset {
                showToast("Box reset to fit the new level", durationSeconds: 2.4)
            }
        case let .cropResult(result, thumbDataUrl):
            if let cont = cropCommitContinuation {
                cropCommitContinuation = nil
                cont.resume(returning: (result, thumbDataUrl))
            }
        }
    }

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: ArchiveSchemeHandler.scheme)
        config.allowsInlineMediaPlayback = true
        config.suppressesIncrementalRendering = false

        let contentController = WKUserContentController()
        contentController.add(WeakScriptMessageHandler(target: self), name: "archiveStage")
        config.userContentController = contentController

        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = true
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.scrollView.contentInsetAdjustmentBehavior = .never
        #if DEBUG
        if #available(iOS 16.4, *) {
            view.isInspectable = true
        }
        #endif

        if let indexURL = URL(string: "\(ArchiveSchemeHandler.scheme)://app/index.html") {
            view.load(URLRequest(url: indexURL))
        }
        return view
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: StageController?

    init(target: StageController) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body
        Task { @MainActor [weak target] in
            target?.handleIncomingScriptBody(body)
        }
    }
}

public struct ArchiveStageView: UIViewRepresentable {
    let controller: StageController

    public init(controller: StageController) {
        self.controller = controller
    }

    public func makeUIView(context: Context) -> StageHostUIView {
        let host = StageHostUIView()
        host.attach(webView: controller.webView)
        return host
    }

    public func updateUIView(_ uiView: StageHostUIView, context: Context) {
        uiView.attach(webView: controller.webView)
    }
}

public final class StageHostUIView: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attach(webView: WKWebView) {
        guard webView.superview !== self else { return }
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
#endif

