// US EPA Air Quality Index engine.
//
// Computes a per-pollutant sub-index from concentration using the official
// piecewise-linear breakpoints, then the overall AQI = max sub-index and the
// dominant ("driver") pollutant. Focus pollutants: PM2.5, PM10, ozone (+ NO₂).
// Breakpoints: EPA AQI Technical Assistance Document (PM2.5 uses the 2024 update).

import Foundation

enum Pollutant: String, CaseIterable, Sendable {
    case pm25, pm10, ozone, no2

    var label: String {
        switch self {
        case .pm25: return "PM2.5"
        case .pm10: return "PM10"
        case .ozone: return "Ozone"
        case .no2: return "NO₂"
        }
    }
}

private struct Bp {
    let cLo: Double, cHi: Double, iLo: Double, iHi: Double
}

// Concentration in the unit noted; index in AQI points.
private let breakpoints: [Pollutant: [Bp]] = [
    // PM2.5, µg/m³, 24-hr (2024 revised)
    .pm25: [
        Bp(cLo: 0.0, cHi: 9.0, iLo: 0, iHi: 50),
        Bp(cLo: 9.1, cHi: 35.4, iLo: 51, iHi: 100),
        Bp(cLo: 35.5, cHi: 55.4, iLo: 101, iHi: 150),
        Bp(cLo: 55.5, cHi: 125.4, iLo: 151, iHi: 200),
        Bp(cLo: 125.5, cHi: 225.4, iLo: 201, iHi: 300),
        Bp(cLo: 225.5, cHi: 500.4, iLo: 301, iHi: 500),
    ],
    // PM10, µg/m³, 24-hr
    .pm10: [
        Bp(cLo: 0, cHi: 54, iLo: 0, iHi: 50),
        Bp(cLo: 55, cHi: 154, iLo: 51, iHi: 100),
        Bp(cLo: 155, cHi: 254, iLo: 101, iHi: 150),
        Bp(cLo: 255, cHi: 354, iLo: 151, iHi: 200),
        Bp(cLo: 355, cHi: 424, iLo: 201, iHi: 300),
        Bp(cLo: 425, cHi: 604, iLo: 301, iHi: 500),
    ],
    // Ozone, ppb, 8-hr
    .ozone: [
        Bp(cLo: 0, cHi: 54, iLo: 0, iHi: 50),
        Bp(cLo: 55, cHi: 70, iLo: 51, iHi: 100),
        Bp(cLo: 71, cHi: 85, iLo: 101, iHi: 150),
        Bp(cLo: 86, cHi: 105, iLo: 151, iHi: 200),
        Bp(cLo: 106, cHi: 200, iLo: 201, iHi: 300),
    ],
    // NO2, ppb, 1-hr
    .no2: [
        Bp(cLo: 0, cHi: 53, iLo: 0, iHi: 50),
        Bp(cLo: 54, cHi: 100, iLo: 51, iHi: 100),
        Bp(cLo: 101, cHi: 360, iLo: 101, iHi: 150),
        Bp(cLo: 361, cHi: 649, iLo: 151, iHi: 200),
        Bp(cLo: 650, cHi: 1249, iLo: 201, iHi: 300),
        Bp(cLo: 1250, cHi: 2049, iLo: 301, iHi: 500),
    ],
]

// Open-Meteo reports ozone & NO2 in µg/m³; EPA breakpoints use ppb.
// At 25°C / 1 atm: ppb = µg/m³ / (molarMass / 24.45).
private let ugm3ToPpb: [Pollutant: Double] = [
    .ozone: 24.45 / 48.0,  // ≈ 0.509
    .no2: 24.45 / 46.01,   // ≈ 0.531
]

func toPpbIfNeeded(_ p: Pollutant, _ ugm3: Double) -> Double {
    if let k = ugm3ToPpb[p] { return ugm3 * k }
    return ugm3
}

/// Sub-index (AQI points) for one pollutant from its concentration in EPA units.
func subIndex(_ p: Pollutant, _ conc: Double?) -> Int? {
    guard let conc, !conc.isNaN, conc >= 0, let table = breakpoints[p] else { return nil }
    let top = table[table.count - 1]
    let c = min(conc, top.cHi)
    for b in table where c >= b.cLo && c <= b.cHi {
        return Int(jsRound(((b.iHi - b.iLo) / (b.cHi - b.cLo)) * (c - b.cLo) + b.iLo))
    }
    return Int(top.iHi)
}

func bandFromAqi(_ aqi: Int) -> RiskBand {
    if aqi <= 50 { return .good }
    if aqi <= 100 { return .moderate }
    if aqi <= 150 { return .sensitive }
    if aqi <= 200 { return .unhealthy }
    if aqi <= 300 { return .very }
    return .hazard
}

struct AqiInputs {
    var pm25: Double?  // µg/m³
    var pm10: Double?  // µg/m³
    var ozone: Double? // µg/m³ (Open-Meteo) — converted internally
    var no2: Double?   // µg/m³
}

struct AqiSub: Identifiable {
    let pollutant: Pollutant
    let concentration: Double? // native display unit (µg/m³)
    let index: Int?
    var id: String { pollutant.rawValue }
}

struct AqiResult {
    let aqi: Int
    let band: RiskBand
    let driver: Pollutant
    let subs: [AqiSub]
    let simulated: Bool
}

/// Compute the composite AQI = max sub-index, and identify the driver pollutant.
func computeAqi(_ inp: AqiInputs, simulated: Bool, usAqi: Double? = nil) -> AqiResult {
    let order: [Pollutant] = [.pm25, .pm10, .ozone, .no2]
    let concFor: (Pollutant) -> Double? = { p in
        switch p {
        case .pm25: return inp.pm25
        case .pm10: return inp.pm10
        case .ozone: return inp.ozone
        case .no2: return inp.no2
        }
    }
    let subs: [AqiSub] = order.map { p in
        let conc = concFor(p)
        let epaConc = conc.map { toPpbIfNeeded(p, $0) }
        return AqiSub(pollutant: p, concentration: conc, index: subIndex(p, epaConc))
    }

    var driver: Pollutant = .pm25
    var maxIdx = -1
    for s in subs {
        if let idx = s.index, idx > maxIdx {
            maxIdx = idx
            driver = s.pollutant
        }
    }

    // Prefer the authoritative Open-Meteo US AQI for the headline when present,
    // but keep the computed sub-indices for the pollutant breakdown.
    let aqi: Int
    if let usAqi, usAqi >= 0 {
        aqi = Int(jsRound(usAqi))
    } else {
        aqi = max(0, maxIdx)
    }
    return AqiResult(aqi: aqi, band: bandFromAqi(aqi), driver: driver, subs: subs, simulated: simulated)
}
