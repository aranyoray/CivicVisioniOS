// Live water feed — USGS NWIS Instantaneous Values (pH, dissolved oxygen,
// temperature, turbidity) where a gauge is nearby. Free, no key, HTTPS, US-only.

import Foundation

enum WaterService {
    /// Fetch nearby USGS gauge readings, sorted by distance. Empty if none nearby.
    static func fetch(lat: Double, lon: Double) async throws -> [WaterSiteReading] {
        let dl = 0.5
        let bbox = [
            String(format: "%.6f", lon - dl),
            String(format: "%.6f", lat - dl),
            String(format: "%.6f", lon + dl),
            String(format: "%.6f", lat + dl),
        ].joined(separator: ",")

        var comps = URLComponents(string: "https://waterservices.usgs.gov/nwis/iv/")!
        comps.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "bBox", value: bbox),
            URLQueryItem(name: "parameterCd", value: "00010,00400,00300,63680"),
            URLQueryItem(name: "siteStatus", value: "active"),
        ]
        guard let url = comps.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(NWISResponse.self, from: data)
        let series = decoded.value?.timeSeries ?? []
        if series.isEmpty { return [] }

        struct Accum {
            var name: String
            var distance: Double
            var tempC: Double?
            var pH: Double?
            var doMgL: Double?
            var turbidity: Double?
            var timestamp: Date
        }
        var bySite: [String: Accum] = [:]
        var order: [String] = []

        for ts in series {
            guard let siteId = ts.sourceInfo?.siteCode?.first?.value else { continue }
            let pCode = ts.variable?.variableCode?.first?.value ?? ""
            let last = ts.values?.first?.value?.last
            let parsed = last.flatMap { Double($0.value) }
            let v: Double? = (parsed != nil && !parsed!.isNaN && parsed! > -9000) ? parsed : nil

            if bySite[siteId] == nil {
                let g = ts.sourceInfo?.geoLocation?.geogLocation
                let siteLat = g?.latitude ?? lat
                let siteLon = g?.longitude ?? lon
                bySite[siteId] = Accum(
                    name: ts.sourceInfo?.siteName ?? siteId,
                    distance: haversine(lat, lon, siteLat, siteLon),
                    timestamp: last.flatMap { parseDate($0.dateTime) } ?? Date()
                )
                order.append(siteId)
            }
            switch pCode {
            case "00010": bySite[siteId]?.tempC = v
            case "00400": bySite[siteId]?.pH = v
            case "00300": bySite[siteId]?.doMgL = v
            case "63680": bySite[siteId]?.turbidity = v
            default: break
            }
            if let dt = last.flatMap({ parseDate($0.dateTime) }) {
                bySite[siteId]?.timestamp = dt
            }
        }

        let all: [WaterSiteReading] = order.compactMap { id in
            guard let s = bySite[id] else { return nil }
            return WaterSiteReading(
                id: id, siteName: s.name, distanceMeters: s.distance,
                temperatureC: s.tempC, pH: s.pH, dissolvedOxygenMgL: s.doMgL,
                turbidityFNU: s.turbidity, timestamp: s.timestamp
            )
        }
        let withData = all.filter { $0.temperatureC != nil || $0.pH != nil || $0.dissolvedOxygenMgL != nil || $0.turbidityFNU != nil }
        let pool = withData.isEmpty ? all : withData
        return pool.sorted { $0.distanceMeters < $1.distanceMeters }
    }

    // MARK: - Decoding

    private struct NWISResponse: Decodable {
        let value: Value?
        struct Value: Decodable { let timeSeries: [TimeSeries]? }
    }
    private struct TimeSeries: Decodable {
        let sourceInfo: SourceInfo?
        let variable: Variable?
        let values: [ValuesBlock]?
    }
    private struct SourceInfo: Decodable {
        let siteName: String?
        let siteCode: [CodeValue]?
        let geoLocation: GeoLocation?
    }
    private struct GeoLocation: Decodable { let geogLocation: GeogLocation? }
    private struct GeogLocation: Decodable { let latitude: Double?; let longitude: Double? }
    private struct Variable: Decodable { let variableCode: [CodeValue]? }
    private struct CodeValue: Decodable { let value: String? }
    private struct ValuesBlock: Decodable { let value: [Sample]? }
    private struct Sample: Decodable { let value: String; let dateTime: String }
}

private func haversine(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
    let R = 6_371_000.0
    let toR: (Double) -> Double = { $0 * .pi / 180 }
    let dLat = toR(lat2 - lat1)
    let dLon = toR(lon2 - lon1)
    let a = pow(sin(dLat / 2), 2) + cos(toR(lat1)) * cos(toR(lat2)) * pow(sin(dLon / 2), 2)
    return 2 * R * asin(min(1, sqrt(a)))
}

private let isoFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
private let isoPlain = ISO8601DateFormatter()

private func parseDate(_ s: String) -> Date? {
    isoFractional.date(from: s) ?? isoPlain.date(from: s)
}
