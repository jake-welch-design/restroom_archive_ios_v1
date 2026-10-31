#if canImport(SwiftUI)
import SwiftUI

public enum ArchiveColor {
    public static let ink = Color.black
    public static let paper = Color.white
    public static let subtleFill = Color(red: 240 / 255, green: 240 / 255, blue: 240 / 255)
    public static let hoverFill = Color(red: 249 / 255, green: 249 / 255, blue: 249 / 255)
    public static let muted = Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255)
    public static let dim = Color(red: 153 / 255, green: 153 / 255, blue: 153 / 255)
    public static let inputBorder = Color(red: 204 / 255, green: 204 / 255, blue: 204 / 255)
    public static let rule = Color(red: 221 / 255, green: 221 / 255, blue: 221 / 255)
    public static let rowRule = Color(red: 232 / 255, green: 232 / 255, blue: 232 / 255)
    public static let danger = Color(red: 204 / 255, green: 51 / 255, blue: 51 / 255)
    public static let warning = Color(red: 170 / 255, green: 102 / 255, blue: 0 / 255)
    public static let publish = Color(red: 26 / 255, green: 127 / 255, blue: 55 / 255)
    public static let pinRed = Color(red: 1.0, green: 0.0, blue: 0.0)
    public static let pinSelected = Color(red: 1.0, green: 138 / 255, blue: 138 / 255)
    public static let stageBackground = Color.black
}

public enum ArchiveFont {
    public static func regular(_ size: CGFloat) -> Font {
        .custom("HelveticaNeue", size: size)
    }

    public static func medium(_ size: CGFloat) -> Font {
        .custom("HelveticaNeue-Medium", size: size)
    }

    public static func bold(_ size: CGFloat) -> Font {
        .custom("HelveticaNeue-Bold", size: size)
    }

    public static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

public struct ArchivePrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ArchiveFont.regular(compact ? 12 : 13))
            .foregroundStyle(ArchiveColor.paper)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 6 : 8)
            .background(ArchiveColor.ink)
            .opacity(!isEnabled ? 0.35 : (configuration.isPressed ? 0.75 : 1.0))
            .contentShape(Rectangle())
    }
}

public struct ArchiveOutlineButtonStyle: ButtonStyle {
    var active: Bool = false
    var compact: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    public init(active: Bool = false, compact: Bool = false) {
        self.active = active
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ArchiveFont.regular(compact ? 11 : 12))
            .foregroundStyle(active ? ArchiveColor.paper : ArchiveColor.ink)
            .padding(.horizontal, compact ? 8 : 11)
            .padding(.vertical, compact ? 5 : 7)
            .background(active ? ArchiveColor.ink : (configuration.isPressed ? ArchiveColor.subtleFill : ArchiveColor.paper))
            .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
            .opacity(isEnabled ? 1.0 : 0.4)
            .contentShape(Rectangle())
    }
}

public struct ArchiveActionButtonStyle: ButtonStyle {
    public enum Tone {
        case publish
        case reject
        case dangerFill
    }

    let tone: Tone
    @Environment(\.isEnabled) private var isEnabled

    public init(tone: Tone) {
        self.tone = tone
    }

    public func makeBody(configuration: Configuration) -> some View {
        let fg: Color = {
            switch tone {
            case .publish: return ArchiveColor.publish
            case .reject: return ArchiveColor.danger
            case .dangerFill: return ArchiveColor.paper
            }
        }()
        let bg: Color = {
            switch tone {
            case .publish, .reject:
                return configuration.isPressed ? ArchiveColor.subtleFill : ArchiveColor.paper
            case .dangerFill:
                return ArchiveColor.danger
            }
        }()
        let border: Color = {
            switch tone {
            case .publish: return ArchiveColor.publish
            case .reject, .dangerFill: return ArchiveColor.danger
            }
        }()

        return configuration.label
            .font(ArchiveFont.regular(12))
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(bg)
            .overlay(Rectangle().stroke(border, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.4)
            .contentShape(Rectangle())
    }
}

public struct ArchiveLinkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ArchiveFont.regular(12))
            .foregroundStyle(ArchiveColor.ink)
            .underline()
            .opacity(!isEnabled ? 0.4 : (configuration.isPressed ? 0.6 : 1.0))
    }
}

public struct ArchiveFieldModifier: ViewModifier {
    var isFocused: Bool = false

    public func body(content: Content) -> some View {
        content
            .font(ArchiveFont.regular(13))
            .foregroundStyle(ArchiveColor.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(ArchiveColor.paper)
            .overlay(
                Rectangle()
                    .stroke(isFocused ? ArchiveColor.ink : ArchiveColor.inputBorder, lineWidth: 1)
            )
    }
}

public extension View {
    func archiveFieldStyle(focused: Bool = false) -> some View {
        modifier(ArchiveFieldModifier(isFocused: focused))
    }
}

public struct ArchiveSegmentedBar<Option: Hashable>: View {
    public struct Item: Identifiable {
        public let id: Option
        public let label: String
        public let badge: Int?

        public init(id: Option, label: String, badge: Int? = nil) {
            self.id = id
            self.label = label
            self.badge = badge
        }
    }

    let items: [Item]
    @Binding var selection: Option

    public init(items: [Item], selection: Binding<Option>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isSelected = selection == item.id
                Button {
                    selection = item.id
                } label: {
                    HStack(spacing: 4) {
                        Text(item.label)
                            .lineLimit(1)
                        if let badge = item.badge, badge > 0 {
                            Text("\(badge)")
                                .font(ArchiveFont.medium(10))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(isSelected ? ArchiveColor.paper : ArchiveColor.ink)
                                .foregroundStyle(isSelected ? ArchiveColor.ink : ArchiveColor.paper)
                        }
                    }
                    .font(ArchiveFont.regular(12))
                    .foregroundStyle(isSelected ? ArchiveColor.paper : ArchiveColor.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 6)
                    .background(isSelected ? ArchiveColor.ink : ArchiveColor.paper)
                    .overlay(alignment: .leading) {
                        if index > 0 {
                            Rectangle()
                                .fill(ArchiveColor.ink)
                                .frame(width: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
    }
}

public struct ArchiveUnderlineTabs<Option: Hashable>: View {
    public struct Item: Identifiable {
        public let id: Option
        public let label: String
        public let badge: Int?
        public let disabled: Bool

        public init(id: Option, label: String, badge: Int? = nil, disabled: Bool = false) {
            self.id = id
            self.label = label
            self.badge = badge
            self.disabled = disabled
        }
    }

    let items: [Item]
    @Binding var selection: Option

    public init(items: [Item], selection: Binding<Option>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(items) { item in
                    let active = selection == item.id
                    Button {
                        guard !item.disabled else { return }
                        selection = item.id
                    } label: {
                        HStack(spacing: 4) {
                            Text(item.label)
                                .font(ArchiveFont.regular(12))
                            if let badge = item.badge, badge > 0 {
                                Text("\(badge)")
                                    .font(ArchiveFont.medium(10))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(ArchiveColor.danger)
                                    .foregroundStyle(ArchiveColor.paper)
                            }
                        }
                        .foregroundStyle(
                            item.disabled
                                ? ArchiveColor.inputBorder
                                : (active ? ArchiveColor.ink : ArchiveColor.muted)
                        )
                        .padding(.bottom, 7)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(active ? ArchiveColor.ink : Color.clear)
                                .frame(height: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(item.disabled)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ArchiveColor.rule)
                .frame(height: 1)
        }
    }
}

public struct ArchivePillBadge: View {
    public enum Tone {
        case role
        case neutral
        case warn
        case danger
        case outline
    }

    let label: String
    let tone: Tone

    public init(_ label: String, tone: Tone = .neutral) {
        self.label = label
        self.tone = tone
    }

    public var body: some View {
        let fg: Color = {
            switch tone {
            case .role: return ArchiveColor.paper
            case .neutral, .outline: return ArchiveColor.muted
            case .warn: return ArchiveColor.warning
            case .danger: return ArchiveColor.danger
            }
        }()
        let bg: Color = {
            switch tone {
            case .role: return ArchiveColor.ink
            case .neutral: return ArchiveColor.subtleFill
            case .warn: return ArchiveColor.warning.opacity(0.1)
            case .danger: return ArchiveColor.danger.opacity(0.1)
            case .outline: return ArchiveColor.paper
            }
        }()
        let border: Color = {
            switch tone {
            case .role: return ArchiveColor.ink
            case .neutral: return ArchiveColor.subtleFill
            case .warn: return ArchiveColor.warning
            case .danger: return ArchiveColor.danger
            case .outline: return ArchiveColor.inputBorder
            }
        }()

        Text(label)
            .font(ArchiveFont.regular(10))
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .overlay(Rectangle().stroke(border, lineWidth: 1))
    }
}

public struct InfoTooltipButton: View {
    let title: String
    let lines: [String]
    @State private var isPresented = false

    public init(title: String, lines: [String]) {
        self.title = title
        self.lines = lines
    }

    public var body: some View {
        Button {
            isPresented = true
        } label: {
            Text("?")
                .font(ArchiveFont.medium(10))
                .foregroundStyle(ArchiveColor.muted)
                .frame(width: 16, height: 16)
                .overlay(Rectangle().stroke(ArchiveColor.inputBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Info: \(title)")
        .popover(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(ArchiveFont.bold(12))
                    .foregroundStyle(ArchiveColor.ink)
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: 300, alignment: .leading)
            .background(ArchiveColor.paper)
            .presentationCompactAdaptation(.popover)
        }
    }
}
#endif

