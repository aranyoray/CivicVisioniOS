// Location search — ZIP / postal codes via Zippopotam, place names via the
// Open-Meteo geocoding API. Both free, no key, HTTPS.

import Foundation

struct GeoSuggestion: Identifiable, Hashable {
    let id: String
    let lat: Double
    let lon: Double
    let label: String
    let sublabel: String?
    let kind: Kind
    let state: String?       // full name, e.g. "New York"
    let stateAbbr: String?   // 2-letter, US only
    let county: String?      // e.g. "Kings County"
    let countryCode: String? // ISO-2, uppercase

    enum Kind: String { case zip, place }
}

// Full US state / DC name → 2-letter abbreviation (health dataset key).
private let usStateAbbr: [String: String] = [
    "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR", "california": "CA",
    "colorado": "CO", "connecticut": "CT", "delaware": "DE", "district of columbia": "DC",
    "florida": "FL", "georgia": "GA", "hawaii": "HI", "idaho": "ID", "illinois": "IL",
    "indiana": "IN", "iowa": "IA", "kansas": "KS", "kentucky": "KY", "louisiana": "LA",
    "maine": "ME", "maryland": "MD", "massachusetts": "MA", "michigan": "MI", "minnesota": "MN",
    "mississippi": "MS", "missouri": "MO", "montana": "MT", "nebraska": "NE", "nevada": "NV",
    "new hampshire": "NH", "new jersey": "NJ", "new mexico": "NM", "new york": "NY",
    "north carolina": "NC", "north dakota": "ND", "ohio": "OH", "oklahoma": "OK",
    "oregon": "OR", "pennsylvania": "PA", "rhode island": "RI", "south carolina": "SC",
    "south dakota": "SD", "tennessee": "TN", "texas": "TX", "utah": "UT", "vermont": "VT",
    "virginia": "VA", "washington": "WA", "west virginia": "WV", "wisconsin": "WI", "wyoming": "WY",
]

private func abbrFromStateName(_ name: String?) -> String? {
    guard let name else { return nil }
    return usStateAbbr[name.trimmingCharacters(in: .whitespaces).lowercased()]
}

private struct PostalPattern {
    let country: String // "us" | "gb" | "ca"
    let label: String
    let pattern: String
}

private let postalPatterns: [PostalPattern] = [
    PostalPattern(country: "us", label: "US ZIP code", pattern: #"^\s*(\d{5})(?:[-\s]?\d{4})?\s*$"#),
    PostalPattern(country: "gb", label: "UK postcode", pattern: #"^\s*([A-Za-z]{1,2}\d[A-Za-z\d]?)\s*\d[A-Za-z]{2}\s*$"#),
    PostalPattern(country: "ca", label: "Canadian postcode", pattern: #"^\s*([A-Za-z]\d[A-Za-z])\s*\d[A-Za-z]\d\s*$"#),
]

enum Geocoder {
    /// Resolve a query to location suggestions. Postal codes first, then place search.
    static func geocode(_ query: String) async throws -> [GeoSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 { return [] }

        for p in postalPatterns {
            guard let match = firstCapture(trimmed, pattern: p.pattern) else { continue }
            do {
                let results = try await searchPostal(p, code: match)
                if !results.isEmpty { return results }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // fall through to place search on postal lookup failure
            }
            break
        }
        return try await searchPlace(trimmed)
    }

    private static func searchPostal(_ p: PostalPattern, code: String) async throws -> [GeoSuggestion] {
        let normalized = code.uppercased()
        let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? normalized
        guard let url = URL(string: "https://api.zippopotam.us/\(p.country)/\(encoded)") else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
        let decoded = try JSONDecoder().decode(ZippopotamResponse.self, from: data)
        return decoded.places.enumerated().map { (i, place) in
            GeoSuggestion(
                id: "\(p.country)-\(normalized)-\(i)",
                lat: Double(place.latitude) ?? 0,
                lon: Double(place.longitude) ?? 0,
                label: "\(normalized) — \(place.placeName), \(place.stateAbbreviation)",
                sublabel: p.label,
                kind: .zip,
                state: place.state,
                stateAbbr: p.country == "us" ? place.stateAbbreviation : nil,
                county: nil,
                countryCode: p.country.uppercased()
            )
        }
    }

    private static func searchPlace(_ query: String) async throws -> [GeoSuggestion] {
        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comps.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "6"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = comps.url else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        guard let results = decoded.results else { return [] }
        return results.map { r in
            let region = [r.admin1, r.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            let isUS = (r.country_code ?? "").uppercased() == "US"
            return GeoSuggestion(
                id: "om-\(r.id)",
                lat: r.latitude,
                lon: r.longitude,
                label: r.name,
                sublabel: region.isEmpty ? nil : region,
                kind: .place,
                state: r.admin1,
                stateAbbr: isUS ? abbrFromStateName(r.admin1) : nil,
                county: r.admin2,
                countryCode: (r.country_code ?? "").uppercased().isEmpty ? nil : (r.country_code ?? "").uppercased()
            )
        }
    }

    // MARK: - Decoding

    private struct ZippopotamResponse: Decodable {
        let places: [Place]
        struct Place: Decodable {
            let placeName: String
            let state: String
            let stateAbbreviation: String
            let latitude: String
            let longitude: String
            enum CodingKeys: String, CodingKey {
                case placeName = "place name"
                case state
                case stateAbbreviation = "state abbreviation"
                case latitude, longitude
            }
        }
    }

    private struct OpenMeteoResponse: Decodable { let results: [Result]? }
    private struct Result: Decodable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let country_code: String?
        let admin1: String?
        let admin2: String?
    }
}

/// Return the first capture group of `pattern` in `text`, or nil.
private func firstCapture(_ text: String, pattern: String) -> String? {
    guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let m = re.firstMatch(in: text, range: range), m.numberOfRanges > 1,
          let capture = Range(m.range(at: 1), in: text) else { return nil }
    return String(text[capture])
}
