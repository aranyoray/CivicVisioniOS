import SwiftUI

struct WaterView: View {
    @Environment(ExposureStore.self) private var store

    private let advice: [RiskBand: String] = [
        .good: "Water indicators within safe ranges across all three pillars.",
        .moderate: "Generally safe. Sensitive households may prefer filtration for trace contaminants.",
        .sensitive: "Elevated contaminant load. Consider certified filtration (activated carbon / RO).",
        .unhealthy: "Contaminant load exceeds guideline levels. Use certified filtration; check local advisories.",
        .very: "Poor water quality. Avoid untreated tap water; follow utility advisories.",
        .hazard: "Hazardous indicators. Do not consume untreated water; contact your utility.",
    ]

    var body: some View {
        DetailScaffold(
            title: "Water Quality",
            subtitle: "A 0–100 index across PFAS & microplastics, heavy metals & pH, and dissolved oxygen."
        ) {
            if let water = store.civic?.water {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("WATER QUALITY INDEX · WEAKEST: \(water.driver.uppercased())")
                                .font(.system(size: 11, weight: .semibold)).tracking(0.6)
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Spacer()
                            SimBadge(live: !water.simulated)
                        }
                        HStack(alignment: .bottom) {
                            Text("\(water.wqi)")
                                .font(.system(size: 68, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(water.band.fg)
                            Spacer()
                            BandPill(band: water.band)
                        }
                    }
                    .cardSurface(padding: 24)

                    ForEach(water.pillars) { pillar in
                        SectionLabel("\(pillar.label) · \(Int(pillar.score.rounded()))/100")
                        VStack(spacing: 16) {
                            ForEach(pillar.subs) { s in
                                Meter(
                                    label: s.label,
                                    score: s.score,
                                    valueText: s.unit.isEmpty ? fmtNum(s.value) : "\(fmtNum(s.value)) \(s.unit)",
                                    reference: s.reference,
                                    live: s.live,
                                    band: bandFromScore(s.score)
                                )
                            }
                        }
                        .cardSurface(padding: 16)
                    }

                    SectionLabel("What to do")
                    Callout(band: water.band, text: advice[water.band] ?? "")
                }
            } else {
                NoLocationCard(noun: "water quality")
            }

            FootNote("Live source: USGS NWIS (pH, dissolved oxygen) where a gauge is nearby. PFAS, microplastics and heavy-metal levels have no free realtime feed and are MODELED from local industrial-pressure signatures against EPA reference limits — for demonstration only, not a substitute for your utility's water-quality report or laboratory testing.")
        }
    }
}
