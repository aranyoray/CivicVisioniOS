// Display formatting helpers shared across CivicVision screens.
// Mirrors the web app's `format.ts` (Number.toLocaleString / toFixed semantics).

import Foundation

private let groupingFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    f.locale = Locale(identifier: "en_US")
    return f
}()

/// Grouped integer string, e.g. 1240 → "1,240".
private func grouped(_ v: Double) -> String {
    groupingFormatter.string(from: NSNumber(value: v.rounded())) ?? String(Int(v.rounded()))
}

func fmtNum(_ v: Double?, _ digits: Int = 1) -> String {
    guard let v, !v.isNaN else { return "—" }
    if abs(v) >= 1000 { return grouped(v) }
    if v == v.rounded() { return String(Int(v)) }
    return String(format: "%.\(digits)f", v)
}

/// Compact count, e.g. 1_240 → "1.2k", 2_400_000 → "2.4M".
func fmtCompact(_ v: Double?) -> String {
    guard let v, !v.isNaN else { return "—" }
    let absV = abs(v)
    if absV >= 1_000_000 { return "\(String(format: "%.1f", v / 1_000_000))M" }
    if absV >= 1_000 {
        let digits = absV >= 100_000 ? 0 : 1
        return "\(String(format: "%.\(digits)f", v / 1_000))k"
    }
    return String(Int(v.rounded()))
}

func fmtQaly(_ v: Double) -> String {
    if v >= 100 { return grouped(v) }
    if v >= 10 { return String(format: "%.0f", v) }
    return String(format: "%.1f", v)
}

func fmtPct(_ fraction: Double, _ digits: Int = 0) -> String {
    "\(String(format: "%.\(digits)f", fraction * 100))%"
}

func fmtDelta(_ pp: Double) -> String {
    let sign = pp > 0 ? "+" : ""
    return "\(sign)\(String(format: "%.1f", pp))"
}

/// Compact metric formatting used in KPI tiles (mirrors `Metric` in the web app).
func fmtMetric(_ value: Double?) -> String {
    guard let value, !value.isNaN else { return "—" }
    if value == value.rounded() || abs(value) >= 10 {
        return String(format: "%.0f", value)
    }
    return String(format: "%.1f", value)
}
