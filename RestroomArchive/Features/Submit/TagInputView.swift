#if canImport(SwiftUI)
import SwiftUI

public struct TagInputView: View {
    @Binding var tags: [String]
    let suggestions: [String]
    var maxTags: Int = 20
    var maxLength: Int = 40

    @State private var draftTag: String = ""

    public init(tags: Binding<[String]>, suggestions: [String], maxTags: Int = 20, maxLength: Int = 40) {
        self._tags = tags
        self.suggestions = suggestions
        self.maxTags = maxTags
        self.maxLength = maxLength
    }

    private var matchingSuggestions: [String] {
        let existing = Set(tags.map { $0.lowercased() })
        let query = draftTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return suggestions
            .filter { !existing.contains($0.lowercased()) }
            .filter { query.isEmpty ? true : $0.lowercased().contains(query) }
            .prefix(12)
            .map { $0 }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                Button {
                                    tags.removeAll(where: { $0 == tag })
                                } label: {
                                    Text("×")
                                        .font(ArchiveFont.bold(11))
                                }
                                .buttonStyle(.plain)
                            }
                            .font(ArchiveFont.regular(11))
                            .foregroundStyle(ArchiveColor.paper)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(ArchiveColor.ink)
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                TextField("Type a tag and tap Add (e.g. accessible, marble, bar)", text: $draftTag)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .archiveFieldStyle()
                    .onSubmit {
                        commitDraftTag()
                    }
                    .onChange(of: draftTag) { _, val in
                        if val.contains(",") {
                            let parts = val.split(separator: ",")
                            for part in parts {
                                appendTag(String(part))
                            }
                            draftTag = ""
                        }
                    }

                Button("Add") {
                    commitDraftTag()
                }
                .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                .disabled(draftTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tags.count >= maxTags)
            }

            if !matchingSuggestions.isEmpty && tags.count < maxTags {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(matchingSuggestions, id: \.self) { suggestion in
                            Button {
                                appendTag(suggestion)
                                draftTag = ""
                            } label: {
                                Text("+ \(suggestion)")
                                    .font(ArchiveFont.regular(11))
                                    .foregroundStyle(ArchiveColor.muted)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(ArchiveColor.subtleFill)
                                    .overlay(Rectangle().stroke(ArchiveColor.inputBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func commitDraftTag() {
        appendTag(draftTag)
        draftTag = ""
    }

    private func appendTag(_ raw: String) {
        guard tags.count < maxTags else { return }
        let cleaned = String(
            raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .prefix(maxLength)
        )
        guard !cleaned.isEmpty else { return }
        guard !tags.contains(where: { $0.lowercased() == cleaned }) else { return }
        tags.append(cleaned)
    }
}
#endif

