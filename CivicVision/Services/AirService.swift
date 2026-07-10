// Live air-quality feed — Open-Meteo Air Quality API (CAMS). Free, no key, HTTPS.

import Foundation

enum AirService {
    /// Fetch the current air reading for a coordinate. Throws on network / decode failure.
    static func fetch(lat: Double, lon: Double) async throws -> AirReading {
        var comps = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: "us_aqi,pm2_5,pm10,ozone,nitrogen_dioxide"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = comps.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(AirResponse.self, from: data)
        let c = decoded.current
        return AirReading(
            aqi: c?.us_aqi,
            pm25: c?.pm2_5,
            pm10: c?.pm10,
            ozone: c?.ozone,
            no2: c?.nitrogen_dioxide,
            timestamp: Date()
        )
    }

    private struct AirResponse: Decodable {
        let current: Current?
        struct Current: Decodable {
            let us_aqi: Double?
            let pm2_5: Double?
            let pm10: Double?
            let ozone: Double?
            let nitrogen_dioxide: Double?
        }
    }
}
