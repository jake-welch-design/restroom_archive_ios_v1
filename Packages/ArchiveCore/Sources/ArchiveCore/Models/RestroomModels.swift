import Foundation

public struct PublicUserRef: Codable, Hashable, Sendable {
    public var username: String
    public var displayName: String?

    public init(username: String, displayName: String? = nil) {
        self.username = username
        self.displayName = displayName
    }

    public var formattedAttribution: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        return "@\(username)"
    }
}

public struct RestroomSummary: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var slug: String
    public var name: String
    public var location: String
    public var country: String?
    public var lat: Double?
    public var lng: Double?
    public var date: String
    public var isoDate: String
    public var description: String?
    public var descriptors: [String]
    public var submitter: PublicUserRef?
    public var status: String
    public var crop: Crop?
    public var modelUrl: String
    public var thumbUrl: String?

    public init(
        id: Int,
        slug: String,
        name: String,
        location: String,
        country: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        date: String,
        isoDate: String,
        description: String? = nil,
        descriptors: [String] = [],
        submitter: PublicUserRef? = nil,
        status: String = "published",
        crop: Crop? = nil,
        modelUrl: String,
        thumbUrl: String? = nil
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.location = location
        self.country = country
        self.lat = lat
        self.lng = lng
        self.date = date
        self.isoDate = isoDate
        self.description = description
        self.descriptors = descriptors
        self.submitter = submitter
        self.status = status
        self.crop = crop
        self.modelUrl = modelUrl
        self.thumbUrl = thumbUrl
    }

    public var hasCoordinates: Bool {
        lat != nil && lng != nil
    }
}

public struct SiteStats: Codable, Hashable, Sendable {
    public var restrooms: Int
    public var cities: Int
    public var countries: Int?
    public var archivists: Int

    public init(restrooms: Int, cities: Int, countries: Int?, archivists: Int) {
        self.restrooms = restrooms
        self.cities = cities
        self.countries = countries
        self.archivists = archivists
    }
}

public struct CoordsCheckRequest: Codable, Hashable, Sendable {
    public var city: String
    public var country: String
    public var subdivision: String
    public var lat: Double
    public var lng: Double

    public init(city: String, country: String, subdivision: String, lat: Double, lng: Double) {
        self.city = city
        self.country = country
        self.subdivision = subdivision
        self.lat = lat
        self.lng = lng
    }
}

public struct CoordsCheckResponse: Codable, Hashable, Sendable {
    public var match: Bool?
}

public struct SubmitRestroomResponse: Codable, Hashable, Sendable {
    public var ok: Bool
    public var slug: String
}

public struct RestroomPatchBody: Codable, Hashable, Sendable {
    public var name: String
    public var location: String
    public var country: String?
    public var isoDate: String
    public var lat: Double?
    public var lng: Double?
    public var description: String?
    public var descriptors: [String]?

    public init(
        name: String,
        location: String,
        country: String? = nil,
        isoDate: String,
        lat: Double? = nil,
        lng: Double? = nil,
        description: String? = nil,
        descriptors: [String]? = nil
    ) {
        self.name = name
        self.location = location
        self.country = country
        self.isoDate = isoDate
        self.lat = lat
        self.lng = lng
        self.description = description
        self.descriptors = descriptors
    }
}

public struct OkResponse: Codable, Hashable, Sendable {
    public var ok: Bool
}

