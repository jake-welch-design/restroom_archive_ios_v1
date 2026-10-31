#if canImport(SwiftUI) && canImport(AVKit) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import AVKit
import SwiftUI

public struct SubmissionGuideSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private struct StepSpec: Identifiable, Hashable {
        let id: String
        let shortLabel: String
        let title: String
    }

    private let steps: [StepSpec] = [
        .init(id: "app", shortLabel: "1. App", title: "Download a 3D scanning app"),
        .init(id: "scan", shortLabel: "2. Scan", title: "Scan your restroom"),
        .init(id: "process", shortLabel: "3. Processing", title: "Process and optimize"),
        .init(id: "details", shortLabel: "4. Details", title: "Take note of contextual details"),
        .init(id: "export", shortLabel: "5. Export", title: "Export as .GLB"),
        .init(id: "upload", shortLabel: "6. Upload", title: "Upload and complete your submission")
    ]

    @State private var currentIndex: Int = 0

    public init() {}

    public var body: some View {
        let step = steps[currentIndex]

        VStack(spacing: 0) {
            HStack {
                Text("Submission Guide")
                    .font(ArchiveFont.regular(14))
                    .foregroundStyle(ArchiveColor.muted)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("×")
                        .font(ArchiveFont.regular(20))
                        .foregroundStyle(ArchiveColor.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle().fill(ArchiveColor.rule).frame(height: 1)
            }

            ArchiveUnderlineTabs(
                items: steps.enumerated().map { idx, item in
                    .init(id: idx, label: item.shortLabel)
                },
                selection: $currentIndex
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(step.title)
                        .font(ArchiveFont.bold(16))
                        .foregroundStyle(ArchiveColor.ink)

                    stepContent(for: step.id)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Footer Prev / Dots / Next
            HStack {
                Button {
                    if currentIndex > 0 { currentIndex -= 1 }
                } label: {
                    Text(currentIndex == 0 ? "←" : "← \(steps[currentIndex - 1].shortLabel)")
                }
                .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                .disabled(currentIndex == 0)

                Spacer()

                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { idx in
                        Circle()
                            .fill(idx == currentIndex ? ArchiveColor.ink : ArchiveColor.rule)
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                Button {
                    if currentIndex == steps.count - 1 {
                        dismiss()
                    } else {
                        currentIndex += 1
                    }
                } label: {
                    Text(currentIndex == steps.count - 1 ? "Done" : "\(steps[currentIndex + 1].shortLabel) →")
                }
                .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .overlay(alignment: .top) {
                Rectangle().fill(ArchiveColor.rule).frame(height: 1)
            }
        }
        .background(ArchiveColor.paper)
    }

    @ViewBuilder
    private func stepContent(for id: String) -> some View {
        switch id {
        case "app":
            guideParagraph("Download a 3D scanning app to your mobile device. The recommended option depends on your device:")
            guideSubheading("iPhone with LiDAR (12 Pro and later Pro and Pro Max models) and LiDAR compatible Android models:")
            Link("Scaniverse, using Mesh mode", destination: URL(string: "https://scaniverse.com/")!)
                .font(ArchiveFont.regular(13))
                .foregroundStyle(ArchiveColor.ink)
                .underline()
            guideSubheading("Android and iPhone without LiDAR:")
            Link("KIRI Engine, using its Photo Scan mode", destination: URL(string: "https://www.kiriengine.app/")!)
                .font(ArchiveFont.regular(13))
                .foregroundStyle(ArchiveColor.ink)
                .underline()
            guideStill(
                name: "app-options",
                caption: "The top two recommended scanning apps: Scaniverse for LiDAR and KIRI Engine for photogrammetry. (The Restroom Archive is not sponsored by either app!)"
            )

        case "scan":
            guideSubheading("Scanning techniques")
            guideParagraph("While techniques may vary depending on the method you choose to make a scan, it is generally recommended to start towards the bottom in an empty corner, and then slowly and methodically move around the room in one direction, from bottom to top, stopping to capture all angles of every object in the space, until you reach the top.")
            guideParagraph("Be sure to capture the floor and ceiling and avoid crossing over the same spot too many times which might cause drift. If using LiDAR, the lasers will bounce off of reflective surfaces such as mirrors or stainless steel trashcans or appliances. Spend a bit of time on these if they're slightly matte and can be captured at a steeper angle, but otherwise, it is expected that these will create holes and artifacts and that's okay.")
            guideParagraph("If using a photo scan, take many overlapping shots, more than feels necessary. Plain walls and uniform tile give the software little to match between photos, so include edges, fixtures, and corners in each frame wherever you can.")
            guideClip(name: "scan-demo", caption: "Demo of scanning a restroom from all angles from bottom to top")

            guideSubheading("Common issues")
            Text("Note: Since switching to Scaniverse, Jake has encountered these issues much less frequently than when he was using Polycam. Consider making the change if you haven't already.")
                .font(ArchiveFont.regular(12.5))
                .foregroundStyle(ArchiveColor.ink)
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    Rectangle().fill(ArchiveColor.ink).frame(width: 3)
                }

            guideParagraph("The most common scanning issues Archivists encounter are large holes, blurry patches, and scanning drift. If these are too severe or distort important elements beyond recognition, the scan will likely be rejected from being added to the Archive.")
            guideParagraph("Large holes and blurry spots most often occur when an area is missed during the scanning process. Occasionally, even if a surface seemed to be well-captured, these gaps will appear if the surface is busy and complicated (like walls covered with heavy graffiti) or if there was low lighting in the space. Blurry patches occur where there were smaller holes, and the 3D scanning software filled the gap during processing, approximating the missed texture.")
            guideStill(name: "holes", caption: "Example of scan missing important details")
            guideStill(name: "blur", caption: "Example of scan with holes, blurry patches, and surface drift")
            guideParagraph("Scanning drift is when parts of the mesh don't line up, causing artifacts such as duplicate objects and breaks in what are obviously straight lines. This most commonly happens when moving too fast or when going over the same portion of the space too many times.")
            guideStill(name: "drift", caption: "Example of Scanning drift, note the paper towel dispenser, trashcan, and door.")
            guideParagraph("All of these issues can be prevented by following the scanning techniques as outlined above. They do, however, still occur no matter what. Artifacts are expected, so if you think the scan is still high enough quality where it matters (toilets, sinks, etc.), you are encouraged to still submit.")

            guideSubheading("LiDAR vs. photogrammetry")
            guideParagraph("To produce scans for The Restroom Archive, 3D scanning apps typically use two methods: LiDAR and photogrammetry.")
            guideParagraph("LiDAR, or light detection and ranging, uses laser sensors and your phone camera to measure distances and build a textured mesh. iPhone Pro/Max models from 12 onward, as well as select Android devices, have LiDAR sensors.")
            guideParagraph("Photogrammetry works by taking multiple overlapping photographs of a space from different angles and stitching them together to form an approximate mesh. While photogrammetry is less accurate than LiDAR, it is still a viable method for those who can't use LiDAR on their device.")
            Link("Read more tips on scanning techniques →", destination: URL(string: "https://dev.scaniverse.com/support")!)
                .font(ArchiveFont.regular(13))
                .foregroundStyle(ArchiveColor.ink)
                .underline()

        case "process":
            guideParagraph("After scanning, there are likely to still be artifacts caused by reflective surfaces, as mentioned earlier. Sometimes an error might also cause the scan to process at a tilted angle. It is encouraged to crop and level your restroom models before exporting.")
            guideClip(name: "crop", caption: "Cropping a scan")

        case "details":
            guideParagraph("As an Archivist, it's important to not only capture the space, but to provide valuable context. Take note while you're in the space of any peculiarities. How does someone access the restroom? Was the door outside labeled anything unusual? Is there any storytelling in the restroom that ties it to the establishment or neighborhood? These details will be important during the submission process.")
            guideStill(name: "description-example", caption: "Example of a description which provides excellent context to the scan")

        case "export":
            guideParagraph("Once you're ready to submit, export the model as a .GLB file. This format is important as it saves the 3D mesh together with its texture and is relatively small in file size. Note that the max file size to upload is 25MB, so if your scan is larger, it is recommended that you compress it beforehand.")
            guideParagraph("On iOS, you can share the exported .GLB directly from Scaniverse or Files to The Restroom Archive via the Share Sheet, or save it to Files and select it in the Submit tab.")
            guideClip(name: "export", caption: "Exporting from Scaniverse: Choose Share, then .GLB")

        default:
            guideParagraph("Find your exported file and upload it in the Submit tab. Follow the submission process and check the '?' tooltips along the way if you need extra guidance. Write a detailed description using any notes you gathered earlier and submit. Once approved, your restroom will now be part of The Restroom Archive!")
            guideClip(name: "upload", caption: "The submission wizard end to end: scan, details, description, review.")
        }
    }

    private func guideSubheading(_ text: String) -> some View {
        Text(text)
            .font(ArchiveFont.bold(13))
            .foregroundStyle(ArchiveColor.ink)
            .padding(.top, 4)
    }

    private func guideParagraph(_ text: String) -> some View {
        Text(text)
            .font(ArchiveFont.regular(13))
            .foregroundStyle(ArchiveColor.ink)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func guideStill(name: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncCachedImage(
                remotePath: "/guide/\(name).jpg",
                apiClient: appState.apiClient,
                diskCache: appState.diskCache,
                contentMode: .fit
            ) {
                ZStack {
                    ArchiveColor.subtleFill
                    ProgressView().tint(ArchiveColor.ink)
                }
                .aspectRatio(1, contentMode: .fit)
            }
            .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))

            Text(caption)
                .font(ArchiveFont.regular(11.5))
                .foregroundStyle(ArchiveColor.muted)
        }
        .padding(.vertical, 4)
    }

    private func guideClip(name: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let url = appState.apiClient.resolveURL("/guide/\(name).mp4") {
                LoopingGuideVideoView(url: url)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
            }
            Text(caption)
                .font(ArchiveFont.regular(11.5))
                .foregroundStyle(ArchiveColor.muted)
        }
        .padding(.vertical, 4)
    }
}

private struct LoopingGuideVideoView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                ArchiveColor.subtleFill
            }
        }
        .onAppear {
            let avPlayer = AVPlayer(url: url)
            avPlayer.isMuted = true
            avPlayer.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: avPlayer.currentItem,
                queue: .main
            ) { _ in
                avPlayer.seek(to: .zero)
                avPlayer.play()
            }
            player = avPlayer
            avPlayer.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
#endif

