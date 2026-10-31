#if canImport(UIKit) && canImport(UniformTypeIdentifiers)
import ArchiveCore
import Foundation
import UIKit
import UniformTypeIdentifiers

/// Native iOS Share Extension enabling Archivists to share an exported `.glb` scan
/// directly from Scaniverse, KIRI Engine, Polycam, or Files into The Restroom Archive.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let actionButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        Task { @MainActor in
            await importSharedGLB()
        }
    }

    private func configureUI() {
        view.backgroundColor = .white

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.borderColor = UIColor.black.cgColor
        container.layer.borderWidth = 1
        container.backgroundColor = .white
        view.addSubview(container)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "THE RESTROOM ARCHIVE"
        titleLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        titleLabel.textColor = .black

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Importing .glb scan…"
        statusLabel.font = UIFont(name: "HelveticaNeue", size: 13) ?? .systemFont(ofSize: 13)
        statusLabel.textColor = .darkGray
        statusLabel.numberOfLines = 0

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.setTitle("Close", for: .normal)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.backgroundColor = .black
        actionButton.titleLabel?.font = UIFont(name: "HelveticaNeue", size: 13) ?? .systemFont(ofSize: 13)
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        actionButton.addTarget(self, action: #selector(closeExtension), for: .touchUpInside)

        container.addSubview(titleLabel)
        container.addSubview(statusLabel)
        container.addSubview(actionButton)

        NSLayoutConstraint.activate([
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            statusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),

            actionButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            actionButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            actionButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18)
        ])
    }

    @MainActor
    private func importSharedGLB() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            statusLabel.text = "No shared file was provided."
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }
        let glbType = UTType(filenameExtension: "glb")?.identifier ?? "model.gltf-binary"
        let candidateTypes = [glbType, UTType.fileURL.identifier, UTType.data.identifier, UTType.item.identifier]

        guard let provider = providers.first(where: { p in
            candidateTypes.contains(where: { p.hasItemConformingToTypeIdentifier($0) })
        }),
        let matchedType = candidateTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            statusLabel.text = "Please share a binary .GLB 3D scan file."
            return
        }

        do {
            let (data, fileName) = try await loadFileBytes(from: provider, typeIdentifier: matchedType)
            let store = DraftSubmissionStore()
            let draft = try await store.createDraftFromGLB(
                data: data,
                originalFileName: fileName,
                sourceNote: "Imported via iOS Share Sheet"
            )

            statusLabel.text = "Saved \(draft.glbFileName) (\(UploadLimits.formatFileSize(draft.glbByteSize))) to The Restroom Archive drafts."
            if let deepLink = URL(string: "restroomarchive://submit-draft?id=\(draft.id.uuidString)") {
                openHostApp(url: deepLink)
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            statusLabel.text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadFileBytes(from provider: NSItemProvider, typeIdentifier: String) async throws -> (Data, String) {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: ArchiveAPIError.invalidGLBFile)
                    return
                }
                do {
                    let data = try Data(contentsOf: url)
                    continuation.resume(returning: (data, url.lastPathComponent))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Walks the responder chain to ask UIApplication (when available) to open the main app URL.
    private func openHostApp(url: URL) {
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: url)
                break
            }
            responder = current.next
        }
    }

    @objc private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
#endif

