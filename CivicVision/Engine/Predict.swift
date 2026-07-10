// Predictive intelligence engine — "science-as-a-service".
//
// Translates current air + water pollution into attributable chronic-disease
// burden for three organ systems (cardiovascular, respiratory, renal) and the
// quality-adjusted life-years (QALYs) recoverable per 100,000 residents if that
// pollution were reduced. Uses log-linear concentration-response functions from
// the epidemiological literature; see CITATIONS below. All outputs are modeled
// estimates for civic decision-support, not clinical predictions.

import Foundation

enum PredictSystem: String, CaseIterable, Identifiable {
    case cardio, respiratory, renal
    var id: String { rawValue }
}

// ── Concentration-response coefficients (relative risk per unit exposure) ──
// Expressed as β where RR = exp(β · Δexposure).
enum CRF {
    // PM2.5, per µg/m³
    static let pm25_cvd = log(1.11) / 10   // cardiovascular mortality  (Pope et al., 2004/2019)
    static let pm25_resp = log(1.06) / 10  // respiratory mortality     (Krewski et al., 2009)
    static let pm25_renal = log(1.04) / 10 // CKD incidence (emerging)  (Bowe et al., 2018)
    // Ozone (warm-season 8-hr), per ppb
    static let o3_resp = log(1.02) / 10    // respiratory mortality     (Turner et al., 2016)
    // Waterborne contaminant load (0…100 index), per point
    static let water_renal = log(1.6) / 100 // renal — PFAS/arsenic/lead (Bowe 2018; Zheng 2021)
    static let water_cvd = log(1.15) / 100  // cardiovascular — metals   (Moon et al., 2012)
}

// Counterfactual targets (clean-air / clean-water reference).
enum Target {
    static let pm25 = 5.0     // WHO 2021 AQG annual, µg/m³
    static let ozone = 30.0   // ≈ WHO peak-season 60 µg/m³, ppb
    static let waterLoad = 10.0 // residual load index
}

// US baseline age-adjusted mortality (per 100k/yr) for each system.
private let baseMortality: [PredictSystem: Double] = [.cardio: 165, .respiratory: 55, .renal: 13]
// Life-years lost per premature death, and a morbidity uplift for disability
// years (YLD) folded into the QALY weight.
private let yll: [PredictSystem: Double] = [.cardio: 11, .respiratory: 10, .renal: 9]
private let morbidityUplift = 1.2

let CITATIONS = [
    "Pope CA III et al. (2004) Circulation — PM2.5 & cardiovascular mortality.",
    "Krewski D et al. (2009) HEI — PM2.5 & respiratory mortality.",
    "Turner MC et al. (2016) AJRCCM — long-term ozone & respiratory mortality.",
    "Bowe B et al. (2018) JASN — PM2.5 & chronic kidney disease.",
    "Moon K et al. (2012) Circulation — arsenic exposure & cardiovascular disease.",
    "WHO (2021) Global Air Quality Guidelines — PM2.5 & O₃ targets.",
]

struct PredictInputs {
    var pm25: Double      // µg/m³
    var ozone: Double     // ppb (converted upstream)
    var waterLoad: Double // 0…100 (= 100 − WQI)
    var state: StateHealth
    var scenario: Double  // 0…1 reduction fraction toward target
    var population: Double // county population for absolute scaling
}

struct SystemResult: Identifiable {
    let system: PredictSystem
    let label: String
    let localRate: Double        // localized baseline mortality /100k
    let afCurrent: Double        // attributable fraction now
    let afScenario: Double       // attributable fraction under the scenario
    let burdenNow: Double        // attributable QALYs lost /100k/yr now
    let recoverablePer100k: Double // QALYs recoverable /100k/yr under scenario
    let recoverableCounty: Double  // scaled to county population
    let pctOfBurden: Double      // share of attributable burden the scenario removes
    var id: String { system.rawValue }
}

struct PollutantFootprint: Identifiable {
    let key: String
    let label: String
    let systems: [PredictSystem]
    let qalys: Double
    var id: String { key }
}

struct Prediction {
    let systems: [SystemResult]
    let totalBurdenNow: Double        // QALYs/100k/yr
    let totalRecoverablePer100k: Double
    let totalRecoverableCounty: Double
    let maxRecoverablePer100k: Double // if reduced fully to target
    let pollutantFootprint: [PollutantFootprint]
    let scenario: Double
    let population: Double
}

private func af(_ rr: Double) -> Double { rr <= 1 ? 0 : (rr - 1) / rr }
private func reduceToward(_ cur: Double, _ target: Double, _ f: Double) -> Double {
    max(target, cur - f * max(0, cur - target))
}

private let sysMeta: [(system: PredictSystem, label: String, prevKey: HealthKey)] = [
    (.cardio, "Cardiovascular", .chd),
    (.respiratory, "Respiratory", .copd),
    (.renal, "Renal", .ckd),
]

private func systemRR(_ sys: PredictSystem, _ pm25: Double, _ ozone: Double, _ waterLoad: Double) -> Double {
    let dPm = max(0, pm25 - Target.pm25)
    let dO3 = max(0, ozone - Target.ozone)
    let dW = max(0, waterLoad - Target.waterLoad)
    switch sys {
    case .cardio:
        return exp(CRF.pm25_cvd * dPm) * exp(CRF.water_cvd * dW)
    case .respiratory:
        return exp(CRF.pm25_resp * dPm) * exp(CRF.o3_resp * dO3)
    case .renal:
        return exp(CRF.water_renal * dW) * exp(CRF.pm25_renal * dPm)
    }
}

func buildPrediction(_ inp: PredictInputs) -> Prediction {
    let pm25 = inp.pm25, ozone = inp.ozone, waterLoad = inp.waterLoad
    let state = inp.state, scenario = inp.scenario, population = inp.population

    let scPm = reduceToward(pm25, Target.pm25, scenario)
    let scO3 = reduceToward(ozone, Target.ozone, scenario)
    let scW = reduceToward(waterLoad, Target.waterLoad, scenario)

    let systems: [SystemResult] = sysMeta.map { m in
        let localRate = (baseMortality[m.system] ?? 0) * (state[m.prevKey] / US_AVERAGE[m.prevKey])
        let yllVal = (yll[m.system] ?? 0) * morbidityUplift
        let afCurrent = af(systemRR(m.system, pm25, ozone, waterLoad))
        let afScenario = af(systemRR(m.system, scPm, scO3, scW))
        let burdenNow = localRate * afCurrent * yllVal
        let recoverablePer100k = localRate * (afCurrent - afScenario) * yllVal
        return SystemResult(
            system: m.system, label: m.label, localRate: localRate,
            afCurrent: afCurrent, afScenario: afScenario, burdenNow: burdenNow,
            recoverablePer100k: recoverablePer100k,
            recoverableCounty: recoverablePer100k * population / 100_000,
            pctOfBurden: afCurrent > 0 ? (afCurrent - afScenario) / afCurrent : 0
        )
    }

    // Full-reduction ceiling (scenario = 1) for the headline "recoverable" figure.
    let maxRecoverablePer100k = sysMeta.reduce(0.0) { acc, m in
        let localRate = (baseMortality[m.system] ?? 0) * (state[m.prevKey] / US_AVERAGE[m.prevKey])
        let yllVal = (yll[m.system] ?? 0) * morbidityUplift
        let afNow = af(systemRR(m.system, pm25, ozone, waterLoad))
        let afTarget = af(systemRR(m.system, Target.pm25, Target.ozone, Target.waterLoad))
        return acc + localRate * (afNow - afTarget) * yllVal
    }

    // Multi-system footprint of each pollutant — the "compounding" story: one
    // stressor damages several organ systems at once.
    func footprintFor(pm: Double? = nil, o3: Double? = nil, w: Double? = nil) -> Double {
        let p = pm ?? pm25
        let o = o3 ?? ozone
        let wl = w ?? waterLoad
        return sysMeta.reduce(0.0) { acc, m in
            let localRate = (baseMortality[m.system] ?? 0) * (state[m.prevKey] / US_AVERAGE[m.prevKey])
            let yllVal = (yll[m.system] ?? 0) * morbidityUplift
            let afNow = af(systemRR(m.system, pm25, ozone, waterLoad))
            let afWithout = af(systemRR(m.system, p, o, wl))
            return acc + localRate * (afNow - afWithout) * yllVal
        }
    }

    let pollutantFootprint = [
        PollutantFootprint(key: "pm25", label: "PM2.5", systems: [.cardio, .respiratory, .renal], qalys: footprintFor(pm: Target.pm25)),
        PollutantFootprint(key: "ozone", label: "Ozone", systems: [.respiratory], qalys: footprintFor(o3: Target.ozone)),
        PollutantFootprint(key: "water", label: "Water contaminants", systems: [.renal, .cardio], qalys: footprintFor(w: Target.waterLoad)),
    ].sorted { $0.qalys > $1.qalys }

    let totalBurdenNow = systems.reduce(0) { $0 + $1.burdenNow }
    let totalRecoverablePer100k = systems.reduce(0) { $0 + $1.recoverablePer100k }
    return Prediction(
        systems: systems,
        totalBurdenNow: totalBurdenNow,
        totalRecoverablePer100k: totalRecoverablePer100k,
        totalRecoverableCounty: totalRecoverablePer100k * population / 100_000,
        maxRecoverablePer100k: maxRecoverablePer100k,
        pollutantFootprint: pollutantFootprint,
        scenario: scenario,
        population: population
    )
}
