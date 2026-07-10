// CivicVision orchestrator — assembles a complete civic health profile for a
// location by blending proven live feeds (Open-Meteo air, USGS water) with the
// modeled science layer (simulated contaminants, health baseline, predictive
// QALY engine). Everything downstream reads from one CivicProfile.

import Foundation

/// A single live air reading (from Open-Meteo, or modeled fallback).
struct AirReading {
    var aqi: Double?
    var pm25: Double?
    var pm10: Double?
    var ozone: Double?
    var no2: Double?
    var timestamp: Date
}

/// A live USGS gauge reading near the location.
struct WaterSiteReading: Identifiable {
    let id: String
    let siteName: String
    let distanceMeters: Double
    let temperatureC: Double?
    let pH: Double?
    let dissolvedOxygenMgL: Double?
    let turbidityFNU: Double?
    let timestamp: Date
}

/// Deterministic county population estimate for absolute QALY scaling.
func simulatePopulation(_ lat: Double, _ lon: Double) -> Double {
    let rng = Rng(seed: locationSeed(lat, lon, salt: "pop"))
    let pressure = pressureField(lat, lon)
    // Log-distributed: rural ~15k, dense metro ~2.5M.
    let base = 15000 + pow(rng.unit(), 2) * 400000
    let urbanBoost = 1 + pressure * pressure * 8
    return (jsRound(base * urbanBoost / 1000)) * 1000
}

/// Simulate an air reading when the live feed is unavailable.
func simulateAir(_ lat: Double, _ lon: Double) -> AirReading {
    let rng = Rng(seed: locationSeed(lat, lon, salt: "air"))
    let pressure = pressureField(lat, lon)
    let pm25 = clamp(rng.normal(mean: 4 + pressure * 22, sd: 4, lo: 0, hi: 250), 0, 250)
    let pm10 = clamp(pm25 * rng.range(1.4, 2.1) + rng.range(0, 8), 0, 400)
    let ozone = clamp(rng.normal(mean: 45 + pressure * 40, sd: 15, lo: 2, hi: 220), 2, 240) // µg/m³
    let no2 = clamp(rng.normal(mean: 6 + pressure * 45, sd: 12, lo: 0, hi: 300), 0, 320)    // µg/m³
    // Leave aqi nil so computeAqi derives it from the sub-indices.
    return AirReading(aqi: nil, pm25: pm25, pm10: pm10, ozone: ozone, no2: no2, timestamp: Date())
}

struct CivicScores {
    let air: Int
    let water: Int
    let health: Int
}

struct CivicProfile {
    let air: AqiResult
    let water: WqiResult
    let health: HealthProfile
    let prediction: Prediction
    let civicScore: Int
    let civicBand: RiskBand
    let scores: CivicScores
    let envLoad: Double     // 0…1, higher = worse
    let population: Double
    let stateAbbr: String?
    let simulatedAir: Bool
    let simulatedWater: Bool
}

struct BuildArgs {
    var lat: Double
    var lon: Double
    var stateAbbr: String?
    var liveAir: AirReading?
    var liveWater: [WaterSiteReading]
    var scenario: Double // 0…1
    var populationOverride: Double?
}

func buildCivicProfile(_ args: BuildArgs) -> CivicProfile {
    let lat = args.lat, lon = args.lon

    // ── Air ──
    let airSimulated = !(args.liveAir != nil && args.liveAir?.pm25 != nil)
    let airReading = airSimulated ? simulateAir(lat, lon) : args.liveAir!
    let air = computeAqi(
        AqiInputs(pm25: airReading.pm25, pm10: airReading.pm10, ozone: airReading.ozone, no2: airReading.no2),
        simulated: airSimulated,
        usAqi: airReading.aqi
    )

    // ── Water: simulate contaminants, overlay live USGS pH/DO when present ──
    var wm = simulateWater(lat, lon)
    if let site = args.liveWater.first(where: { $0.pH != nil || $0.dissolvedOxygenMgL != nil }) {
        if let pH = site.pH {
            wm.pH = pH
            wm.pHLive = true
        }
        if let doV = site.dissolvedOxygenMgL {
            wm.dissolvedOxygen = doV
            wm.doLive = true
        }
    }
    let water = computeWqi(wm)

    // ── Environmental load 0…1 (higher = worse) ──
    let airScore = clamp(100 - Double(air.aqi) * 0.4)
    let waterScore = Double(water.wqi)
    let envLoad = clamp(0.55 * (1 - airScore / 100) + 0.45 * (1 - waterScore / 100), 0, 1)

    // ── Health (county-adjusted baseline) ──
    let health = buildHealthProfile(args.stateAbbr, envLoad: envLoad)
    let st = stateHealth(args.stateAbbr)
    let chdPct = health.conditions.first(where: { $0.key == .chd })?.countyPct ?? US_AVERAGE.chd
    let copdPct = health.conditions.first(where: { $0.key == .copd })?.countyPct ?? US_AVERAGE.copd
    let ckdPct = health.conditions.first(where: { $0.key == .ckd })?.countyPct ?? US_AVERAGE.ckd
    let focusRatio = (chdPct / 6.0 + copdPct / 6.5 + ckdPct / 3.0) / 3
    let healthScore = clamp(100 - (focusRatio - 1) * 140)

    // ── Prediction ──
    let population = args.populationOverride ?? simulatePopulation(lat, lon)
    let prediction = buildPrediction(PredictInputs(
        pm25: airReading.pm25 ?? 0,
        ozone: toPpbIfNeeded(.ozone, airReading.ozone ?? 0),
        waterLoad: 100 - Double(water.wqi),
        state: st,
        scenario: args.scenario,
        population: population
    ))

    // ── Civic Health Score ──
    let civicScore = Int(jsRound(0.4 * airScore + 0.3 * waterScore + 0.3 * healthScore))

    return CivicProfile(
        air: air,
        water: water,
        health: health,
        prediction: prediction,
        civicScore: civicScore,
        civicBand: bandFromScore(Double(civicScore)),
        scores: CivicScores(air: Int(jsRound(airScore)), water: Int(jsRound(waterScore)), health: Int(jsRound(healthScore))),
        envLoad: envLoad,
        population: population,
        stateAbbr: args.stateAbbr,
        simulatedAir: airSimulated,
        simulatedWater: water.simulated
    )
}
