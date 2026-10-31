import Foundation

public struct Region: Codable, Identifiable, Hashable, Sendable {
    public var id: String { code }
    public let code: String
    public let name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

public enum Regions {
    public static let usStates: [Region] = [
        Region(code: "AL", name: "Alabama"),
        Region(code: "AK", name: "Alaska"),
        Region(code: "AZ", name: "Arizona"),
        Region(code: "AR", name: "Arkansas"),
        Region(code: "CA", name: "California"),
        Region(code: "CO", name: "Colorado"),
        Region(code: "CT", name: "Connecticut"),
        Region(code: "DE", name: "Delaware"),
        Region(code: "DC", name: "District of Columbia"),
        Region(code: "FL", name: "Florida"),
        Region(code: "GA", name: "Georgia"),
        Region(code: "HI", name: "Hawaii"),
        Region(code: "ID", name: "Idaho"),
        Region(code: "IL", name: "Illinois"),
        Region(code: "IN", name: "Indiana"),
        Region(code: "IA", name: "Iowa"),
        Region(code: "KS", name: "Kansas"),
        Region(code: "KY", name: "Kentucky"),
        Region(code: "LA", name: "Louisiana"),
        Region(code: "ME", name: "Maine"),
        Region(code: "MD", name: "Maryland"),
        Region(code: "MA", name: "Massachusetts"),
        Region(code: "MI", name: "Michigan"),
        Region(code: "MN", name: "Minnesota"),
        Region(code: "MS", name: "Mississippi"),
        Region(code: "MO", name: "Missouri"),
        Region(code: "MT", name: "Montana"),
        Region(code: "NE", name: "Nebraska"),
        Region(code: "NV", name: "Nevada"),
        Region(code: "NH", name: "New Hampshire"),
        Region(code: "NJ", name: "New Jersey"),
        Region(code: "NM", name: "New Mexico"),
        Region(code: "NY", name: "New York"),
        Region(code: "NC", name: "North Carolina"),
        Region(code: "ND", name: "North Dakota"),
        Region(code: "OH", name: "Ohio"),
        Region(code: "OK", name: "Oklahoma"),
        Region(code: "OR", name: "Oregon"),
        Region(code: "PA", name: "Pennsylvania"),
        Region(code: "RI", name: "Rhode Island"),
        Region(code: "SC", name: "South Carolina"),
        Region(code: "SD", name: "South Dakota"),
        Region(code: "TN", name: "Tennessee"),
        Region(code: "TX", name: "Texas"),
        Region(code: "UT", name: "Utah"),
        Region(code: "VT", name: "Vermont"),
        Region(code: "VA", name: "Virginia"),
        Region(code: "WA", name: "Washington"),
        Region(code: "WV", name: "West Virginia"),
        Region(code: "WI", name: "Wisconsin"),
        Region(code: "WY", name: "Wyoming"),
        Region(code: "AS", name: "American Samoa"),
        Region(code: "GU", name: "Guam"),
        Region(code: "MP", name: "Northern Mariana Islands"),
        Region(code: "PR", name: "Puerto Rico"),
        Region(code: "VI", name: "U.S. Virgin Islands"),
    ]

    public static let caProvinces: [Region] = [
        Region(code: "AB", name: "Alberta"),
        Region(code: "BC", name: "British Columbia"),
        Region(code: "MB", name: "Manitoba"),
        Region(code: "NB", name: "New Brunswick"),
        Region(code: "NL", name: "Newfoundland and Labrador"),
        Region(code: "NS", name: "Nova Scotia"),
        Region(code: "NT", name: "Northwest Territories"),
        Region(code: "NU", name: "Nunavut"),
        Region(code: "ON", name: "Ontario"),
        Region(code: "PE", name: "Prince Edward Island"),
        Region(code: "QC", name: "Quebec"),
        Region(code: "SK", name: "Saskatchewan"),
        Region(code: "YT", name: "Yukon"),
    ]

    private static let rawCountries: [Region] = [
        Region(code: "AF", name: "Afghanistan"),
        Region(code: "AX", name: "Åland Islands"),
        Region(code: "AL", name: "Albania"),
        Region(code: "DZ", name: "Algeria"),
        Region(code: "AD", name: "Andorra"),
        Region(code: "AO", name: "Angola"),
        Region(code: "AI", name: "Anguilla"),
        Region(code: "AQ", name: "Antarctica"),
        Region(code: "AG", name: "Antigua and Barbuda"),
        Region(code: "AR", name: "Argentina"),
        Region(code: "AM", name: "Armenia"),
        Region(code: "AW", name: "Aruba"),
        Region(code: "AU", name: "Australia"),
        Region(code: "AT", name: "Austria"),
        Region(code: "AZ", name: "Azerbaijan"),
        Region(code: "BS", name: "Bahamas"),
        Region(code: "BH", name: "Bahrain"),
        Region(code: "BD", name: "Bangladesh"),
        Region(code: "BB", name: "Barbados"),
        Region(code: "BY", name: "Belarus"),
        Region(code: "BE", name: "Belgium"),
        Region(code: "BZ", name: "Belize"),
        Region(code: "BJ", name: "Benin"),
        Region(code: "BM", name: "Bermuda"),
        Region(code: "BT", name: "Bhutan"),
        Region(code: "BO", name: "Bolivia"),
        Region(code: "BQ", name: "Caribbean Netherlands"),
        Region(code: "BA", name: "Bosnia and Herzegovina"),
        Region(code: "BW", name: "Botswana"),
        Region(code: "BV", name: "Bouvet Island"),
        Region(code: "BR", name: "Brazil"),
        Region(code: "IO", name: "British Indian Ocean Territory"),
        Region(code: "VG", name: "British Virgin Islands"),
        Region(code: "BN", name: "Brunei"),
        Region(code: "BG", name: "Bulgaria"),
        Region(code: "BF", name: "Burkina Faso"),
        Region(code: "BI", name: "Burundi"),
        Region(code: "KH", name: "Cambodia"),
        Region(code: "CM", name: "Cameroon"),
        Region(code: "CA", name: "Canada"),
        Region(code: "CV", name: "Cape Verde"),
        Region(code: "KY", name: "Cayman Islands"),
        Region(code: "CF", name: "Central African Republic"),
        Region(code: "TD", name: "Chad"),
        Region(code: "CL", name: "Chile"),
        Region(code: "CN", name: "China"),
        Region(code: "CX", name: "Christmas Island"),
        Region(code: "CC", name: "Cocos (Keeling) Islands"),
        Region(code: "CO", name: "Colombia"),
        Region(code: "KM", name: "Comoros"),
        Region(code: "CG", name: "Congo (Republic)"),
        Region(code: "CD", name: "Congo (DRC)"),
        Region(code: "CK", name: "Cook Islands"),
        Region(code: "CR", name: "Costa Rica"),
        Region(code: "CI", name: "Côte d'Ivoire"),
        Region(code: "HR", name: "Croatia"),
        Region(code: "CU", name: "Cuba"),
        Region(code: "CW", name: "Curaçao"),
        Region(code: "CY", name: "Cyprus"),
        Region(code: "CZ", name: "Czechia"),
        Region(code: "DK", name: "Denmark"),
        Region(code: "DJ", name: "Djibouti"),
        Region(code: "DM", name: "Dominica"),
        Region(code: "DO", name: "Dominican Republic"),
        Region(code: "EC", name: "Ecuador"),
        Region(code: "EG", name: "Egypt"),
        Region(code: "SV", name: "El Salvador"),
        Region(code: "GQ", name: "Equatorial Guinea"),
        Region(code: "ER", name: "Eritrea"),
        Region(code: "EE", name: "Estonia"),
        Region(code: "SZ", name: "Eswatini"),
        Region(code: "ET", name: "Ethiopia"),
        Region(code: "FK", name: "Falkland Islands"),
        Region(code: "FO", name: "Faroe Islands"),
        Region(code: "FJ", name: "Fiji"),
        Region(code: "FI", name: "Finland"),
        Region(code: "FR", name: "France"),
        Region(code: "GF", name: "French Guiana"),
        Region(code: "PF", name: "French Polynesia"),
        Region(code: "TF", name: "French Southern Territories"),
        Region(code: "GA", name: "Gabon"),
        Region(code: "GM", name: "Gambia"),
        Region(code: "GE", name: "Georgia"),
        Region(code: "DE", name: "Germany"),
        Region(code: "GH", name: "Ghana"),
        Region(code: "GI", name: "Gibraltar"),
        Region(code: "GR", name: "Greece"),
        Region(code: "GL", name: "Greenland"),
        Region(code: "GD", name: "Grenada"),
        Region(code: "GP", name: "Guadeloupe"),
        Region(code: "GT", name: "Guatemala"),
        Region(code: "GG", name: "Guernsey"),
        Region(code: "GN", name: "Guinea"),
        Region(code: "GW", name: "Guinea-Bissau"),
        Region(code: "GY", name: "Guyana"),
        Region(code: "HT", name: "Haiti"),
        Region(code: "HM", name: "Heard and McDonald Islands"),
        Region(code: "HN", name: "Honduras"),
        Region(code: "HK", name: "Hong Kong"),
        Region(code: "HU", name: "Hungary"),
        Region(code: "IS", name: "Iceland"),
        Region(code: "IN", name: "India"),
        Region(code: "ID", name: "Indonesia"),
        Region(code: "IR", name: "Iran"),
        Region(code: "IQ", name: "Iraq"),
        Region(code: "IE", name: "Ireland"),
        Region(code: "IM", name: "Isle of Man"),
        Region(code: "IL", name: "Israel"),
        Region(code: "IT", name: "Italy"),
        Region(code: "JM", name: "Jamaica"),
        Region(code: "JP", name: "Japan"),
        Region(code: "JE", name: "Jersey"),
        Region(code: "JO", name: "Jordan"),
        Region(code: "KZ", name: "Kazakhstan"),
        Region(code: "KE", name: "Kenya"),
        Region(code: "KI", name: "Kiribati"),
        Region(code: "KW", name: "Kuwait"),
        Region(code: "KG", name: "Kyrgyzstan"),
        Region(code: "LA", name: "Laos"),
        Region(code: "LV", name: "Latvia"),
        Region(code: "LB", name: "Lebanon"),
        Region(code: "LS", name: "Lesotho"),
        Region(code: "LR", name: "Liberia"),
        Region(code: "LY", name: "Libya"),
        Region(code: "LI", name: "Liechtenstein"),
        Region(code: "LT", name: "Lithuania"),
        Region(code: "LU", name: "Luxembourg"),
        Region(code: "MO", name: "Macao"),
        Region(code: "MG", name: "Madagascar"),
        Region(code: "MW", name: "Malawi"),
        Region(code: "MY", name: "Malaysia"),
        Region(code: "MV", name: "Maldives"),
        Region(code: "ML", name: "Mali"),
        Region(code: "MT", name: "Malta"),
        Region(code: "MH", name: "Marshall Islands"),
        Region(code: "MQ", name: "Martinique"),
        Region(code: "MR", name: "Mauritania"),
        Region(code: "MU", name: "Mauritius"),
        Region(code: "YT", name: "Mayotte"),
        Region(code: "MX", name: "Mexico"),
        Region(code: "FM", name: "Micronesia"),
        Region(code: "MD", name: "Moldova"),
        Region(code: "MC", name: "Monaco"),
        Region(code: "MN", name: "Mongolia"),
        Region(code: "ME", name: "Montenegro"),
        Region(code: "MS", name: "Montserrat"),
        Region(code: "MA", name: "Morocco"),
        Region(code: "MZ", name: "Mozambique"),
        Region(code: "MM", name: "Myanmar"),
        Region(code: "NA", name: "Namibia"),
        Region(code: "NR", name: "Nauru"),
        Region(code: "NP", name: "Nepal"),
        Region(code: "NL", name: "Netherlands"),
        Region(code: "NC", name: "New Caledonia"),
        Region(code: "NZ", name: "New Zealand"),
        Region(code: "NI", name: "Nicaragua"),
        Region(code: "NE", name: "Niger"),
        Region(code: "NG", name: "Nigeria"),
        Region(code: "NU", name: "Niue"),
        Region(code: "NF", name: "Norfolk Island"),
        Region(code: "KP", name: "North Korea"),
        Region(code: "MK", name: "North Macedonia"),
        Region(code: "NO", name: "Norway"),
        Region(code: "OM", name: "Oman"),
        Region(code: "PK", name: "Pakistan"),
        Region(code: "PW", name: "Palau"),
        Region(code: "PS", name: "Palestine"),
        Region(code: "PA", name: "Panama"),
        Region(code: "PG", name: "Papua New Guinea"),
        Region(code: "PY", name: "Paraguay"),
        Region(code: "PE", name: "Peru"),
        Region(code: "PH", name: "Philippines"),
        Region(code: "PN", name: "Pitcairn Islands"),
        Region(code: "PL", name: "Poland"),
        Region(code: "PT", name: "Portugal"),
        Region(code: "QA", name: "Qatar"),
        Region(code: "RE", name: "Réunion"),
        Region(code: "RO", name: "Romania"),
        Region(code: "RU", name: "Russia"),
        Region(code: "RW", name: "Rwanda"),
        Region(code: "BL", name: "Saint Barthélemy"),
        Region(code: "SH", name: "Saint Helena"),
        Region(code: "KN", name: "Saint Kitts and Nevis"),
        Region(code: "LC", name: "Saint Lucia"),
        Region(code: "MF", name: "Saint Martin"),
        Region(code: "PM", name: "Saint Pierre and Miquelon"),
        Region(code: "VC", name: "Saint Vincent and the Grenadines"),
        Region(code: "WS", name: "Samoa"),
        Region(code: "SM", name: "San Marino"),
        Region(code: "ST", name: "São Tomé and Príncipe"),
        Region(code: "SA", name: "Saudi Arabia"),
        Region(code: "SN", name: "Senegal"),
        Region(code: "RS", name: "Serbia"),
        Region(code: "SC", name: "Seychelles"),
        Region(code: "SL", name: "Sierra Leone"),
        Region(code: "SG", name: "Singapore"),
        Region(code: "SX", name: "Sint Maarten"),
        Region(code: "SK", name: "Slovakia"),
        Region(code: "SI", name: "Slovenia"),
        Region(code: "SB", name: "Solomon Islands"),
        Region(code: "SO", name: "Somalia"),
        Region(code: "ZA", name: "South Africa"),
        Region(code: "GS", name: "South Georgia and South Sandwich Islands"),
        Region(code: "KR", name: "South Korea"),
        Region(code: "SS", name: "South Sudan"),
        Region(code: "ES", name: "Spain"),
        Region(code: "LK", name: "Sri Lanka"),
        Region(code: "SD", name: "Sudan"),
        Region(code: "SR", name: "Suriname"),
        Region(code: "SJ", name: "Svalbard and Jan Mayen"),
        Region(code: "SE", name: "Sweden"),
        Region(code: "CH", name: "Switzerland"),
        Region(code: "SY", name: "Syria"),
        Region(code: "TW", name: "Taiwan"),
        Region(code: "TJ", name: "Tajikistan"),
        Region(code: "TZ", name: "Tanzania"),
        Region(code: "TH", name: "Thailand"),
        Region(code: "TL", name: "Timor-Leste"),
        Region(code: "TG", name: "Togo"),
        Region(code: "TK", name: "Tokelau"),
        Region(code: "TO", name: "Tonga"),
        Region(code: "TT", name: "Trinidad and Tobago"),
        Region(code: "TN", name: "Tunisia"),
        Region(code: "TR", name: "Turkey"),
        Region(code: "TM", name: "Turkmenistan"),
        Region(code: "TC", name: "Turks and Caicos Islands"),
        Region(code: "TV", name: "Tuvalu"),
        Region(code: "UG", name: "Uganda"),
        Region(code: "UA", name: "Ukraine"),
        Region(code: "AE", name: "United Arab Emirates"),
        Region(code: "GB", name: "United Kingdom"),
        Region(code: "US", name: "United States"),
        Region(code: "UY", name: "Uruguay"),
        Region(code: "UZ", name: "Uzbekistan"),
        Region(code: "VU", name: "Vanuatu"),
        Region(code: "VA", name: "Vatican City"),
        Region(code: "VE", name: "Venezuela"),
        Region(code: "VN", name: "Vietnam"),
        Region(code: "WF", name: "Wallis and Futuna"),
        Region(code: "EH", name: "Western Sahara"),
        Region(code: "YE", name: "Yemen"),
        Region(code: "ZM", name: "Zambia"),
        Region(code: "ZW", name: "Zimbabwe"),
    ]

    public static let countries: [Region] = {
        let locale = Locale(identifier: "en")
        return rawCountries.sorted {
            $0.name.compare($1.name, options: [.caseInsensitive, .diacriticInsensitive], locale: locale) == .orderedAscending
        }
    }()

    private static let countryByCode: [String: Region] = Dictionary(
        uniqueKeysWithValues: countries.map { ($0.code, $0) }
    )

    public static func subdivisions(for countryCode: String) -> [Region]? {
        switch countryCode {
        case "US": return usStates
        case "CA": return caProvinces
        default: return nil
        }
    }

    public static func isCountryCode(_ code: String) -> Bool {
        countryByCode[code] != nil
    }

    public static func isSubdivisionCode(_ code: String, for countryCode: String) -> Bool {
        subdivisions(for: countryCode)?.contains(where: { $0.code == code }) ?? false
    }

    public static func countryName(for code: String) -> String? {
        countryByCode[code]?.name
    }

    public static func composeLocation(
        city: String,
        country: String,
        subdivision: String? = nil
    ) -> String {
        var trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix(",") {
            trimmed = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let suffix: String
        if subdivisions(for: country) != nil, let subdivision, !subdivision.isEmpty {
            suffix = subdivision
        } else {
            suffix = country
        }
        return "\(trimmed), \(suffix)"
    }

    public static func cityFromLocation(_ location: String) -> String {
        guard let comma = location.lastIndex(of: ",") else {
            return location.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(location[..<comma]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func subdivisionFromLocation(_ location: String) -> String {
        guard let comma = location.lastIndex(of: ",") else {
            return ""
        }
        let next = location.index(after: comma)
        return String(location[next...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    /// Maps an ISO country code returned by CoreLocation (`CLPlacemark.isoCountryCode`)
    /// onto the archive's country + territory convention (where US territories like `PR`
    /// file under `US` with subdivision `PR`).
    public static func normalizeReverseGeocodedRegion(
        isoCountryCode: String?,
        administrativeArea: String?
    ) -> (country: String, subdivision: String) {
        guard let rawCountry = isoCountryCode?.uppercased() else {
            return ("", "")
        }
        let usTerritories: Set<String> = ["AS", "GU", "MP", "PR", "VI"]
        if usTerritories.contains(rawCountry) {
            return ("US", rawCountry)
        }
        guard isCountryCode(rawCountry) else {
            return ("", "")
        }
        if let subs = subdivisions(for: rawCountry), let admin = administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines), !admin.isEmpty {
            let upper = admin.uppercased()
            if subs.contains(where: { $0.code == upper }) {
                return (rawCountry, upper)
            }
            if let matchedByName = subs.first(where: { $0.name.caseInsensitiveCompare(admin) == .orderedSame }) {
                return (rawCountry, matchedByName.code)
            }
        }
        return (rawCountry, "")
    }

    /// Parses a Google Maps / Apple Maps `"lat, lng"` string into individual strings.
    public static func parseCoordinatePair(_ raw: String) -> (lat: String, lng: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let latText = parts[0].trimmingCharacters(in: .whitespaces)
        let lngText = parts[1].trimmingCharacters(in: .whitespaces)
        guard let lat = Double(latText), let lng = Double(lngText),
              lat >= -90, lat <= 90, lng >= -180, lng <= 180 else {
            return nil
        }
        return (latText, lngText)
    }
}

