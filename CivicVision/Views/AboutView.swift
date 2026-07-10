import SwiftUI

struct AboutView: View {
    private struct Source: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let url: String
    }

    private let sources: [Source] = [
        Source(
            title: "🟢 Live — Air quality",
            body: "Open-Meteo Air Quality API (CAMS). Free, no key, global. US AQI plus PM2.5, PM10, ozone, NO₂. Sub-indices recomputed with US EPA AQI breakpoints (PM2.5 2024 update); the composite equals the worst sub-index.",
            url: "https://open-meteo.com/en/docs/air-quality-api"
        ),
        Source(
            title: "🟢 Live — Water (pH, dissolved oxygen)",
            body: "USGS NWIS Instantaneous Values, free, no key, US-only. When a gauge is nearby, its pH and dissolved-oxygen readings overlay the modeled water profile.",
            url: "https://waterservices.usgs.gov/"
        ),
        Source(
            title: "🟡 Modeled — PFAS, microplastics, heavy metals",
            body: "No free realtime feed exists for these. CivicVision estimates them deterministically from a location's industrial-pressure signature, scored against EPA reference limits (PFAS MCL 4 ppt, arsenic MCL 10 ppb, lead action 15 ppb). Illustrative, not a utility water-quality report.",
            url: "https://www.epa.gov/sdwa/and-polyfluoroalkyl-substances-pfas"
        ),
        Source(
            title: "🟡 Modeled — Community health baseline",
            body: "State-level adult chronic-disease prevalence (coronary heart disease, stroke, COPD, current asthma, chronic kidney disease, diabetes) in the style of CDC BRFSS / PLACES — approximate reference values, adjusted to a county estimate by the locality's environmental load.",
            url: "https://www.cdc.gov/places/"
        ),
        Source(
            title: "🔮 Modeled — Predictive intelligence",
            body: "Log-linear concentration-response functions from the epidemiological literature (Pope 2004; Krewski 2009; Turner 2016; Bowe 2018; Moon 2012) convert pollution above WHO 2021 targets into an attributable fraction of baseline mortality, then into recoverable QALYs via years-of-life-lost and a disability uplift. Decision-support estimates, not clinical predictions.",
            url: "https://www.who.int/publications/i/item/9789240034228"
        ),
    ]

    var body: some View {
        DetailScaffold(
            title: "Sources & methods",
            subtitle: "Live environmental feeds where they exist, transparent modeling where they don't. Every value is labeled Live or Modeled in the interface."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(sources) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.title).font(.headline).foregroundStyle(Theme.text)
                        Text(s.body).font(.subheadline).foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let url = URL(string: s.url) {
                            Link(destination: url) {
                                Text(s.url).font(.caption).underline().foregroundStyle(Theme.text)
                            }
                        }
                    }
                    .cardSurface(padding: 16)
                }

                // Full disclaimer set, always available here.
                SectionLabel("Important disclaimers")
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(DisclaimerContent.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(item.icon)
                                Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                            }
                            Text(item.body).font(.subheadline).foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface(padding: 16)
                    }
                }

                Text(DisclaimerContent.footer)
                    .font(.caption).foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                Text("CivicVision \(appVersion)")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
                    .padding(.top, 4)
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }
}
