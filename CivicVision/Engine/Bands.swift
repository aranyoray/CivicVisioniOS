// Shared six-step risk banding used across air, water and health.

import Foundation

enum RiskBand: String, CaseIterable, Sendable {
    case good, moderate, sensitive, unhealthy, very, hazard

    var label: String {
        switch self {
        case .good: return "Good"
        case .moderate: return "Moderate"
        case .sensitive: return "Sensitive"
        case .unhealthy: return "Unhealthy"
        case .very: return "Very Unhealthy"
        case .hazard: return "Hazardous"
        }
    }
}

/// 0…100 score → band (higher score = healthier). Shared by WQI, health and the civic score.
func bandFromScore(_ score: Double) -> RiskBand {
    if score >= 85 { return .good }
    if score >= 70 { return .moderate }
    if score >= 55 { return .sensitive }
    if score >= 35 { return .unhealthy }
    if score >= 20 { return .very }
    return .hazard
}

@inline(__always)
func clamp(_ v: Double, _ lo: Double = 0, _ hi: Double = 100) -> Double {
    min(hi, max(lo, v))
}
