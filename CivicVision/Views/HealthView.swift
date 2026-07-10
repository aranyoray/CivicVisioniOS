import SwiftUI

struct HealthView: View {
    @Environment(ExposureStore.self) private var store

    private let systemLabel: [HealthSystem: String] = [
        .cardio: "Cardiovascular",
        .respiratory: "Respiratory",
        .renal: "Renal",
        .metabolic: "Metabolic (shared driver)",
    ]
    private let systemIcon: [HealthSystem: String] = [
        .cardio: "🫀", .respiratory: "🫁", .renal: "🩺", .metabolic: "🍬",
    ]
    private let order: [HealthSystem] = [.cardio, .respiratory, .renal, .metabolic]

    var body: some View {
        DetailScaffold(
            title: "Community Health",
            subtitle: "Chronic-disease prevalence for the three organ systems most sensitive to environmental load."
        ) {
            if let civic = store.civic {
                VStack(alignment: .leading, spacing: 12) {
                    // Hero
                    HStack(spacing: 20) {
                        ScoreRing(value: Double(civic.scores.health),
                                  band: bandFromScore(Double(civic.scores.health)),
                                  caption: "Health score")
                        VStack(alignment: .leading, spacing: 8) {
                            BandPill(band: bandFromScore(Double(civic.scores.health)))
                            Text(placeLine(civic))
                                .font(.subheadline).foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Local air + water load adjusts the baseline by \(fmtDelta((civic.health.envModifier - 1) * 100))%.")
                                .font(.caption).foregroundStyle(Theme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .cardSurface()

                    ForEach(order, id: \.self) { sys in
                        let conds = civic.health.conditions.filter { $0.system == sys }
                        if !conds.isEmpty {
                            SectionLabel("\(systemIcon[sys] ?? "")  \(systemLabel[sys] ?? "")")
                            VStack(spacing: 16) {
                                ForEach(conds) { c in
                                    ConditionRow(c: c)
                                }
                            }
                            .cardSurface(padding: 16)
                        }
                    }

                    NavigationLink(destination: PredictView()) {
                        HStack(spacing: 12) {
                            Text("🔮")
                            Text("See how much of this burden is recoverable →")
                                .font(.subheadline.weight(.medium))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(RiskBand.good.fg)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(RiskBand.good.bg))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            } else {
                NoLocationCard(noun: "the community health profile")
            }

            FootNote("Baseline prevalence is state-level adult crude prevalence in the style of CDC BRFSS / PLACES (approximate reference values), adjusted to a county estimate by the locality's modeled environmental load. Percentage points (pp) compare the county estimate to the US average. Modeled — not a diagnosis.")
        }
    }

    private func placeLine(_ civic: CivicProfile) -> String {
        let county = store.coord?.county
        let prefix = county.map { "\($0), " } ?? ""
        return "\(prefix)\(civic.stateAbbr ?? "US") · est. population \(fmtCompact(civic.population))"
    }
}

private struct ConditionRow: View {
    let c: Condition

    private func deltaBand(_ vsUS: Double) -> RiskBand {
        if vsUS <= -0.5 { return .good }
        if vsUS < 0.5 { return .moderate }
        if vsUS < 1.5 { return .sensitive }
        if vsUS < 3 { return .unhealthy }
        return .very
    }

    var body: some View {
        let scale = max(c.countyPct, c.usPct) * 1.6
        let band = deltaBand(c.vsUS)
        let worse = c.vsUS > 0
        let countyFrac = scale > 0 ? min(1, c.countyPct / scale) : 0
        let usFrac = scale > 0 ? min(1, c.usPct / scale) : 0

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(c.label).font(.subheadline).foregroundStyle(Theme.text)
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    Text("\(fmtNum(c.countyPct))%")
                        .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(Theme.text)
                    Text("\(fmtDelta(c.vsUS)) pp vs US")
                        .font(.system(size: 10, weight: .semibold)).monospacedDigit()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(worse ? RiskBand.unhealthy.bg : RiskBand.good.bg))
                        .foregroundStyle(worse ? RiskBand.unhealthy.fg : RiskBand.good.fg)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceHover)
                    Capsule().fill(band.fg).frame(width: geo.size.width * countyFrac)
                    // US average marker
                    Rectangle().fill(Theme.textTertiary)
                        .frame(width: 2)
                        .offset(x: geo.size.width * usFrac - 1)
                }
            }
            .frame(height: 8)
            Text("State \(fmtNum(c.statePct))% · US avg \(fmtNum(c.usPct))% (marker)")
                .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
        }
    }
}
