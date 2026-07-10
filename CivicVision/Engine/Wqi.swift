// Water Quality Index engine.
//
// Composite 0…100 (higher = cleaner) built from three pillars the product
// tracks: (1) contaminants of emerging concern — PFAS + microplastics,
// (2) chemical safety — heavy metals (arsenic, lead) + pH, (3) ecological —
// dissolved oxygen. Live pH/DO come from USGS when a nearby gauge reports them;
// PFAS, microplastics and heavy metals have no free realtime feed, so they are
// modeled deterministically from a location's industrial-pressure signature
// (clearly labeled "Modeled" in the UI).

import Foundation

// Regulatory / guideline reference points.
enum WaterRef {
    static let pfasMcl = 4.0            // EPA 2024 MCL, ppt (PFOA / PFOS individually)
    static let arsenicMcl = 10.0        // EPA MCL, ppb
    static let leadAction = 15.0        // EPA action level, ppb
    static let microplasticsConcern = 10.0 // particles/L, informal concern threshold
    static let doHealthy = 8.0          // mg/L, well-oxygenated
    static let doStress = 5.0           // mg/L, aquatic stress
    static let phLo = 6.5
    static let phHi = 8.5
}

struct WaterMeasures {
    var pfas: Double          // ppt (sum of quantified PFAS)
    var microplastics: Double // particles/L
    var arsenic: Double       // ppb
    var lead: Double          // ppb
    var pH: Double            // standard units
    var dissolvedOxygen: Double // mg/L
    var pHLive: Bool
    var doLive: Bool
}

struct SubScore: Identifiable {
    let key: String
    let label: String
    let value: Double
    let unit: String
    let score: Double // 0…100, higher = better
    let reference: String?
    let live: Bool
    var id: String { key }
}

struct WaterPillar: Identifiable {
    let key: String
    let label: String
    let score: Double
    let subs: [SubScore]
    var id: String { key }
}

struct WqiResult {
    let wqi: Int // 0…100
    let band: RiskBand
    let driver: String // worst pillar label
    let pillars: [WaterPillar]
    let measures: WaterMeasures
    let simulated: Bool
}

// Convert a concentration into a 0…100 score that is 100 at "clean" and 0 at
// `zero` (a badness ceiling). Linear, clamped.
private func decayScore(_ value: Double, clean: Double, zero: Double) -> Double {
    if value <= clean { return 100 }
    if value >= zero { return 0 }
    return clamp(100 * (1 - (value - clean) / (zero - clean)))
}

private func pHScore(_ pH: Double) -> Double {
    if pH >= WaterRef.phLo && pH <= WaterRef.phHi { return 100 }
    let dist = pH < WaterRef.phLo ? WaterRef.phLo - pH : pH - WaterRef.phHi
    return clamp(100 - dist * 55) // ~0 at ±1.8 outside the band
}

private func doScore(_ mgL: Double) -> Double {
    if mgL >= WaterRef.doHealthy { return 100 }
    if mgL <= 2 { return 0 } // hypoxic
    return clamp((mgL - 2) / (WaterRef.doHealthy - 2) * 100)
}

/// Simulate the measures that have no realtime feed, from location pressure.
func simulateWater(_ lat: Double, _ lon: Double) -> WaterMeasures {
    let rng = Rng(seed: locationSeed(lat, lon, salt: "water"))
    let pressure = pressureField(lat, lon) // 0…1
    let pfas = clamp(rng.normal(mean: 1 + pressure * 12, sd: 3, lo: 0, hi: 60), 0, 60)
    let microplastics = clamp(rng.normal(mean: 2 + pressure * 16, sd: 4, lo: 0, hi: 80), 0, 80)
    let arsenic = clamp(rng.normal(mean: 1 + pressure * 8, sd: 2.2, lo: 0, hi: 40), 0, 40)
    let lead = clamp(rng.normal(mean: 0.5 + pressure * 9, sd: 2.5, lo: 0, hi: 45), 0, 45)
    let pH = clamp(rng.normal(mean: 7.6 - pressure * 0.7, sd: 0.35, lo: 5.5, hi: 9), 5.5, 9)
    let dissolvedOxygen = clamp(rng.normal(mean: 9 - pressure * 3.5, sd: 0.9, lo: 1.5, hi: 12), 1.5, 12)
    return WaterMeasures(
        pfas: pfas, microplastics: microplastics, arsenic: arsenic, lead: lead,
        pH: pH, dissolvedOxygen: dissolvedOxygen, pHLive: false, doLive: false
    )
}

func bandFromWqi(_ wqi: Int) -> RiskBand {
    if wqi >= 85 { return .good }
    if wqi >= 70 { return .moderate }
    if wqi >= 55 { return .sensitive }
    if wqi >= 35 { return .unhealthy }
    if wqi >= 20 { return .very }
    return .hazard
}

/// Build pillar scores and the weighted composite from a measures set
/// (with any live USGS pH/DO already overlaid onto the modeled baseline).
func computeWqi(_ base: WaterMeasures) -> WqiResult {
    let m = base

    let cec: [SubScore] = [
        SubScore(key: "pfas", label: "PFAS (forever chemicals)", value: m.pfas, unit: "ppt",
                 score: decayScore(m.pfas, clean: WaterRef.pfasMcl, zero: WaterRef.pfasMcl * 10),
                 reference: "EPA MCL \(fmtRef(WaterRef.pfasMcl)) ppt", live: false),
        SubScore(key: "microplastics", label: "Microplastics", value: m.microplastics, unit: "particles/L",
                 score: decayScore(m.microplastics, clean: 1, zero: 50),
                 reference: "concern ≥ \(fmtRef(WaterRef.microplasticsConcern))/L", live: false),
    ]

    let chem: [SubScore] = [
        SubScore(key: "arsenic", label: "Arsenic", value: m.arsenic, unit: "ppb",
                 score: decayScore(m.arsenic, clean: 1, zero: WaterRef.arsenicMcl * 3),
                 reference: "EPA MCL \(fmtRef(WaterRef.arsenicMcl)) ppb", live: false),
        SubScore(key: "lead", label: "Lead", value: m.lead, unit: "ppb",
                 score: decayScore(m.lead, clean: 1, zero: WaterRef.leadAction * 3),
                 reference: "action \(fmtRef(WaterRef.leadAction)) ppb", live: false),
        SubScore(key: "pH", label: "pH", value: m.pH, unit: "",
                 score: pHScore(m.pH),
                 reference: "\(fmtRef(WaterRef.phLo))–\(fmtRef(WaterRef.phHi))", live: m.pHLive),
    ]

    let eco: [SubScore] = [
        SubScore(key: "do", label: "Dissolved oxygen", value: m.dissolvedOxygen, unit: "mg/L",
                 score: doScore(m.dissolvedOxygen),
                 reference: "healthy ≥ \(fmtRef(WaterRef.doHealthy))", live: m.doLive),
    ]

    let mean: ([SubScore]) -> Double = { s in s.reduce(0) { $0 + $1.score } / Double(s.count) }
    let pillars = [
        WaterPillar(key: "cec", label: "PFAS & microplastics", score: mean(cec), subs: cec),
        WaterPillar(key: "chem", label: "Heavy metals & pH", score: mean(chem), subs: chem),
        WaterPillar(key: "eco", label: "Dissolved oxygen", score: mean(eco), subs: eco),
    ]

    // Weighted composite — chemical safety weighted highest (direct human-health
    // relevance), then CEC, then ecological.
    let weights: [String: Double] = ["cec": 0.35, "chem": 0.45, "eco": 0.2]
    let wqi = Int(jsRound(pillars.reduce(0.0) { $0 + $1.score * (weights[$1.key] ?? 0) }))

    let driver = pillars.min(by: { $0.score < $1.score })?.label ?? pillars[0].label
    return WqiResult(
        wqi: wqi, band: bandFromWqi(wqi), driver: driver, pillars: pillars, measures: m,
        simulated: !(m.pHLive && m.doLive)
    )
}

/// Compact reference formatting (drops a trailing ".0").
private func fmtRef(_ v: Double) -> String {
    v == v.rounded() ? String(Int(v)) : String(v)
}
