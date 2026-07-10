import SwiftUI

struct PredictView: View {
    @Environment(ExposureStore.self) private var store
    @State private var popText = ""

    private func sysMeta(_ s: PredictSystem) -> (label: String, icon: String, color: Color) {
        switch s {
        case .cardio: return ("Cardiovascular", "🫀", RiskBand.unhealthy.fg)
        case .respiratory: return ("Respiratory", "🫁", RiskBand.sensitive.fg)
        case .renal: return ("Renal", "🩺", RiskBand.very.fg)
        }
    }

    var body: some View {
        DetailScaffold(
            title: "Predictive Intelligence",
            subtitle: "How many quality-adjusted life-years (QALYs) could this community recover by cutting air & water pollution?"
        ) {
            if let civic = store.civic {
                let p = civic.prediction
                VStack(alignment: .leading, spacing: 12) {
                    scenarioHero(p: p, store: store)

                    SectionLabel("Recoverable by organ system")
                    VStack(spacing: 12) {
                        ForEach(p.systems) { s in
                            systemCard(s)
                        }
                    }

                    SectionLabel("Compounding effects")
                    compoundingCard(p: p)

                    SectionLabel("County population")
                    populationCard(civic: civic, store: store)
                }
            } else {
                NoLocationCard(noun: "recoverable health")
            }

            SectionLabel("Method & citations")
            VStack(alignment: .leading, spacing: 8) {
                Text("Log-linear concentration-response functions convert exposure above WHO targets into an attributable fraction of baseline mortality, then into QALYs via years-of-life-lost and a disability uplift. Estimates are for civic decision-support, not clinical use.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(CITATIONS, id: \.self) { c in
                    Text("· \(c)").font(.caption).foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .cardSurface(padding: 16)

            FootNote("Modeled decision-support estimates for populations, not predictions for any individual. Not medical advice.")
        }
        .onChange(of: store.population) { _, newValue in
            if newValue == nil { popText = "" }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func scenarioHero(p: Prediction, store: ExposureStore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RECOVERABLE AT THIS SCENARIO")
                .font(.system(size: 11, weight: .semibold)).tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
            HStack(alignment: .bottom, spacing: 6) {
                Text(fmtQaly(p.totalRecoverablePer100k))
                    .font(.system(size: 58, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(RiskBand.good.fg)
                Text("QALYs / 100k / yr").font(.subheadline).foregroundStyle(Theme.textTertiary)
                    .padding(.bottom, 8)
            }
            (
                Text("≈ ") + Text(fmtNum(p.totalRecoverableCounty, 0)).fontWeight(.bold).foregroundColor(Theme.text)
                + Text(" quality-life-years per year across ~\(fmtCompact(p.population)) residents.")
            )
            .font(.subheadline)
            .foregroundColor(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Reduce air + water pollution by").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(Int((store.scenario * 100).rounded()))%").font(.subheadline.weight(.bold)).monospacedDigit()
                        .foregroundStyle(Theme.text)
                }
                Slider(value: Binding(get: { store.scenario }, set: { store.setScenario($0) }), in: 0...1)
                    .tint(RiskBand.good.fg)
                    .accessibilityLabel("Pollution reduction percentage")
                HStack(spacing: 8) {
                    presetButton("25%", 0.25, store: store)
                    presetButton("50%", 0.5, store: store)
                    presetButton("To WHO target", 1, store: store)
                }
                Text("Targets: PM2.5 → \(Int(Target.pm25)) µg/m³, ozone → \(Int(Target.ozone)) ppb (WHO 2021 guidelines).")
                    .font(.caption).foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)
        }
        .cardSurface(padding: 24)
    }

    private func presetButton(_ label: String, _ value: Double, store: ExposureStore) -> some View {
        let active = abs(store.scenario - value) < 0.001
        return Button {
            store.setScenario(value)
        } label: {
            Text(label).font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(active ? RiskBand.good.bg : Theme.surface))
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                .foregroundStyle(active ? RiskBand.good.fg : Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func systemCard(_ s: SystemResult) -> some View {
        let meta = sysMeta(s.system)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Text(meta.icon)
                    Text(meta.label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                }
                Spacer()
                Text("+\(fmtQaly(s.recoverablePer100k)) QALY/100k")
                    .font(.subheadline.weight(.bold)).monospacedDigit()
                    .foregroundStyle(RiskBand.good.fg)
            }
            MeterBar(fraction: max(0.02, s.pctOfBurden), color: meta.color)
            HStack {
                Text("Removes \(fmtPct(s.pctOfBurden)) of attributable burden")
                Spacer(minLength: 8)
                Text("≈ \(fmtNum(s.recoverableCounty, 0)) QALY/yr county")
            }
            .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
        }
        .cardSurface(padding: 16)
    }

    private func compoundingCard(p: Prediction) -> some View {
        let maxQ = max(p.pollutantFootprint.map(\.qalys).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("A single stressor damages several organ systems at once. Full QALY footprint per pollutant (per 100k/yr, if eliminated):")
                .font(.caption).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(p.pollutantFootprint) { f in
                let clean = f.qalys < 0.05
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(f.label).font(.subheadline.weight(.medium)).foregroundStyle(Theme.text)
                        Spacer()
                        Text(clean ? "within target" : "\(fmtQaly(f.qalys)) QALY/100k")
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(clean ? RiskBand.good.fg : Theme.text)
                    }
                    MeterBar(fraction: clean ? 1 : max(0.02, f.qalys / maxQ),
                             color: clean ? RiskBand.good.fg : RiskBand.unhealthy.fg)
                    HStack(spacing: 6) {
                        ForEach(f.systems) { sys in
                            Text(sysMeta(sys).label)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Theme.surfaceHover))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
        }
        .cardSurface(padding: 16)
    }

    private func populationCard(civic: CivicProfile, store: ExposureStore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scale county totals to a known population")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                TextField(fmtNum(civic.population, 0), text: $popText)
                    .keyboardType(.numberPad)
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: 180)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.border, lineWidth: 1))
                    .onChange(of: popText) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        if digits != newValue { popText = digits; return }
                        store.setPopulation(digits.isEmpty ? nil : Double(digits))
                    }
                if store.population != nil {
                    Button("reset to estimate") {
                        store.setPopulation(nil)
                        popText = ""
                    }
                    .font(.caption).foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .cardSurface(padding: 16)
    }
}
