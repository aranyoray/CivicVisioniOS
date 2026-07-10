// Community health baseline.
//
// State-level adult chronic-disease prevalence for the three organ systems the
// product focuses on — cardiovascular, respiratory, renal — plus diabetes as a
// shared upstream driver. Figures are crude adult prevalence (%) in the style of
// CDC BRFSS / PLACES and are approximate reference values for demonstration.
// A county estimate is derived by nudging the state baseline with the locality's
// live+modeled environmental load (a modeled adjustment, clearly labeled).

import Foundation

struct StateHealth {
    var chd: Double      // coronary heart disease, %
    var stroke: Double   // stroke, %
    var copd: Double     // chronic obstructive pulmonary disease, %
    var asthma: Double   // current asthma, %
    var ckd: Double      // chronic kidney disease, %
    var diabetes: Double // diagnosed diabetes, %

    subscript(key: HealthKey) -> Double {
        switch key {
        case .chd: return chd
        case .stroke: return stroke
        case .copd: return copd
        case .asthma: return asthma
        case .ckd: return ckd
        case .diabetes: return diabetes
        }
    }
}

enum HealthKey: String {
    case chd, stroke, copd, asthma, ckd, diabetes
}

enum HealthSystem: String {
    case cardio, respiratory, renal, metabolic
}

let US_AVERAGE = StateHealth(chd: 6.0, stroke: 3.3, copd: 6.5, asthma: 9.5, ckd: 3.0, diabetes: 11.0)

// [chd, stroke, copd, asthma, ckd, diabetes]
private let stateTable: [String: [Double]] = [
    "AL": [7.4, 4.3, 8.9, 9.8, 3.4, 14.6],
    "AK": [4.9, 2.9, 6.0, 9.3, 2.5, 8.6],
    "AZ": [5.6, 3.0, 6.4, 9.7, 3.0, 11.3],
    "AR": [7.6, 4.2, 9.4, 9.6, 3.4, 13.8],
    "CA": [5.3, 3.0, 5.2, 9.1, 2.9, 10.5],
    "CO": [4.6, 2.5, 5.1, 8.9, 2.4, 8.0],
    "CT": [5.0, 2.8, 5.6, 10.6, 2.8, 9.6],
    "DE": [5.9, 3.3, 6.7, 9.9, 3.1, 11.9],
    "DC": [4.7, 3.0, 5.3, 11.5, 3.0, 9.2],
    "FL": [6.2, 3.4, 6.6, 8.8, 3.2, 11.6],
    "GA": [6.3, 3.7, 7.1, 9.7, 3.2, 12.4],
    "HI": [4.6, 2.9, 4.9, 10.4, 2.9, 11.0],
    "ID": [5.3, 2.8, 6.0, 9.0, 2.6, 9.5],
    "IL": [5.8, 3.2, 6.2, 9.6, 2.9, 10.8],
    "IN": [6.6, 3.6, 8.1, 10.2, 3.0, 12.0],
    "IA": [5.9, 3.0, 6.4, 8.8, 2.7, 9.9],
    "KS": [5.8, 3.1, 6.7, 9.1, 2.7, 10.6],
    "KY": [7.8, 4.2, 10.5, 11.4, 3.3, 13.6],
    "LA": [7.2, 4.3, 8.2, 9.5, 3.5, 14.2],
    "ME": [5.9, 3.1, 7.4, 11.2, 2.9, 10.2],
    "MD": [5.6, 3.2, 6.0, 9.9, 3.1, 11.3],
    "MA": [4.9, 2.7, 5.6, 10.9, 2.8, 9.3],
    "MI": [6.3, 3.4, 7.6, 10.8, 3.0, 11.4],
    "MN": [4.4, 2.5, 5.0, 8.5, 2.5, 8.5],
    "MS": [7.9, 4.6, 9.0, 9.4, 3.6, 15.0],
    "MO": [6.5, 3.6, 8.0, 9.9, 3.0, 11.7],
    "MT": [5.2, 2.8, 6.3, 9.1, 2.6, 9.1],
    "NE": [5.6, 2.9, 6.1, 8.7, 2.6, 9.6],
    "NV": [6.0, 3.3, 6.6, 9.0, 3.0, 11.4],
    "NH": [5.3, 2.8, 6.3, 10.4, 2.8, 9.6],
    "NJ": [5.4, 3.0, 5.4, 9.4, 3.0, 10.6],
    "NM": [5.6, 3.1, 6.6, 10.0, 3.0, 11.9],
    "NY": [5.5, 3.1, 5.9, 10.1, 3.0, 10.8],
    "NC": [6.2, 3.7, 7.1, 9.4, 3.1, 11.8],
    "ND": [5.4, 2.7, 5.8, 8.6, 2.6, 9.7],
    "OH": [6.7, 3.6, 8.2, 10.5, 3.0, 11.9],
    "OK": [7.5, 4.2, 9.1, 10.1, 3.2, 13.5],
    "OR": [5.0, 2.8, 6.0, 10.3, 2.7, 9.6],
    "PA": [6.3, 3.4, 7.1, 10.2, 3.1, 11.5],
    "RI": [5.3, 2.9, 6.4, 10.8, 2.9, 10.0],
    "SC": [6.6, 4.0, 7.6, 9.6, 3.3, 12.6],
    "SD": [5.5, 2.8, 6.0, 8.5, 2.6, 9.4],
    "TN": [7.3, 4.1, 9.3, 10.6, 3.2, 13.2],
    "TX": [6.1, 3.5, 6.5, 8.6, 3.2, 12.1],
    "UT": [4.3, 2.4, 5.2, 9.3, 2.4, 8.7],
    "VT": [5.2, 2.7, 6.5, 10.6, 2.7, 8.9],
    "VA": [5.8, 3.4, 6.5, 9.3, 3.0, 11.0],
    "WA": [4.9, 2.8, 5.7, 9.7, 2.6, 9.4],
    "WV": [8.4, 4.5, 12.1, 12.3, 3.4, 15.6],
    "WI": [5.4, 3.0, 6.2, 9.6, 2.7, 9.8],
    "WY": [5.4, 2.8, 6.2, 9.0, 2.6, 9.3],
]

func stateHealth(_ abbr: String?) -> StateHealth {
    guard let abbr, let row = stateTable[abbr.uppercased()] else { return US_AVERAGE }
    return StateHealth(chd: row[0], stroke: row[1], copd: row[2], asthma: row[3], ckd: row[4], diabetes: row[5])
}

struct Condition: Identifiable {
    let key: HealthKey
    let label: String
    let system: HealthSystem
    let countyPct: Double
    let statePct: Double
    let usPct: Double
    let vsUS: Double // percentage-point difference vs national
    var id: String { key.rawValue }
}

private let conditionMeta: [(key: HealthKey, label: String, system: HealthSystem)] = [
    (.chd, "Coronary heart disease", .cardio),
    (.stroke, "Stroke", .cardio),
    (.copd, "COPD", .respiratory),
    (.asthma, "Current asthma", .respiratory),
    (.ckd, "Chronic kidney disease", .renal),
    (.diabetes, "Diabetes", .metabolic),
]

struct HealthProfile {
    let stateAbbr: String?
    let conditions: [Condition]
    /// Local environmental adjustment applied, as a multiplier (e.g. 1.05 = +5%).
    let envModifier: Double
}

/// Build a county-level profile. `envLoad` is a 0…1 signal where higher = worse
/// local air+water; it nudges the state baseline by up to ±8% to produce a
/// modeled county estimate. Different conditions respond with different
/// environmental sensitivity (respiratory & renal most, per the literature).
func buildHealthProfile(_ stateAbbr: String?, envLoad: Double) -> HealthProfile {
    let st = stateHealth(stateAbbr)
    let centered = (min(1, max(0, envLoad)) - 0.5) * 2 // -1…1
    let sensitivity: [HealthSystem: Double] = [
        .respiratory: 0.08,
        .renal: 0.07,
        .cardio: 0.06,
        .metabolic: 0.03,
    ]
    let conditions: [Condition] = conditionMeta.map { m in
        let statePct = st[m.key]
        let usPct = US_AVERAGE[m.key]
        let mod = 1 + centered * (sensitivity[m.system] ?? 0)
        let countyPct = jsRound(statePct * mod * 10) / 10
        return Condition(
            key: m.key, label: m.label, system: m.system,
            countyPct: countyPct, statePct: statePct, usPct: usPct,
            vsUS: jsRound((countyPct - usPct) * 10) / 10
        )
    }
    let envModifier = 1 + centered * 0.06
    return HealthProfile(stateAbbr: stateAbbr?.uppercased(), conditions: conditions, envModifier: envModifier)
}
