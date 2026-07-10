import SwiftUI

struct AirView: View {
    @Environment(ExposureStore.self) private var store

    private let advice: [RiskBand: String] = [
        .good: "Air is clean. Outdoor activity unrestricted.",
        .moderate: "Acceptable. Unusually sensitive people consider lighter exertion.",
        .sensitive: "Sensitive groups (asthma, cardiac) reduce prolonged outdoor exertion.",
        .unhealthy: "Everyone reduce prolonged outdoor exertion. Keep windows closed.",
        .very: "Avoid outdoor exertion. Use HEPA filtration indoors.",
        .hazard: "Health emergency. Stay indoors with sealed windows and filtration.",
    ]

    private let systems: [Pollutant: String] = [
        .pm25: "Cardiovascular · Respiratory · Renal",
        .pm10: "Respiratory",
        .ozone: "Respiratory",
        .no2: "Respiratory",
    ]

    var body: some View {
        DetailScaffold(
            title: "Air Quality",
            subtitle: "US EPA AQI from PM2.5, PM10 and ozone — the composite equals the worst sub-index."
        ) {
            if let air = store.civic?.air {
                VStack(alignment: .leading, spacing: 12) {
                    // Headline
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("US AQI · \(air.driver.label)-DRIVEN")
                                .font(.system(size: 11, weight: .semibold)).tracking(0.6)
                                .foregroundStyle(Theme.textTertiary)
                            Spacer()
                            SimBadge(live: !air.simulated)
                        }
                        HStack(alignment: .bottom) {
                            Text("\(air.aqi)")
                                .font(.system(size: 68, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(air.band.fg)
                            Spacer()
                            BandPill(band: air.band)
                        }
                    }
                    .cardSurface(padding: 24)

                    SectionLabel("Pollutant breakdown")
                    VStack(spacing: 16) {
                        ForEach(air.subs) { s in
                            let idx = s.index ?? 0
                            let idxText = s.index.map { String($0) } ?? "—"
                            let affects = systems[s.pollutant] ?? ""
                            Meter(
                                label: s.pollutant.label,
                                score: max(3, 100 - Double(idx) * 0.4),
                                valueText: "\(fmtNum(s.concentration)) µg/m³",
                                reference: "Sub-AQI \(idxText) · affects \(affects)",
                                band: bandFromAqi(idx)
                            )
                        }
                    }
                    .cardSurface(padding: 16)

                    SectionLabel("What to do")
                    Callout(band: air.band, text: advice[air.band] ?? "")
                }
            } else {
                NoLocationCard(noun: "air quality")
            }

            FootNote("Live source: Open-Meteo Air Quality (CAMS), free, no key. Values fall back to a modeled estimate when the live feed is unavailable. Sub-indices are computed with US EPA AQI breakpoints (PM2.5 2024 update). Informational only — not a government air-quality advisory.")
        }
    }
}
