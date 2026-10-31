import Foundation

public enum MapBasemapStyle: String, Codable, CaseIterable, Sendable {
    case `default`
    case satellite

    public var label: String {
        switch self {
        case .default: return "Default"
        case .satellite: return "Satellite"
        }
    }
}

public final class ViewedPinsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let viewedKey = "ra.viewedPins"
    private let basemapKey = "ra.basemap"
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadViewedSlugs() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        let array = defaults.stringArray(forKey: viewedKey) ?? []
        return Set(array)
    }

    public func markViewed(slug: String) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        var current = Set(defaults.stringArray(forKey: viewedKey) ?? [])
        current.insert(slug)
        defaults.set(Array(current), forKey: viewedKey)
        return current
    }

    public func loadBasemap() -> MapBasemapStyle {
        lock.lock()
        defer { lock.unlock() }
        guard let raw = defaults.string(forKey: basemapKey),
              let style = MapBasemapStyle(rawValue: raw) else {
            return .default
        }
        return style
    }

    public func saveBasemap(_ style: MapBasemapStyle) {
        lock.lock()
        defer { lock.unlock() }
        defaults.set(style.rawValue, forKey: basemapKey)
    }
}

