import SwiftUI

/// First-run consent screen. The user must acknowledge the medical and
/// data-accuracy disclaimers before using the app. Shown once; the choice is
/// persisted. The same content is always available under "Sources & methods".
struct DisclaimerGate: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🛰️ CivicVision")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.text)
                        Text("Before you begin")
                            .font(.headline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.top, 24)

                    ForEach(DisclaimerContent.items) { item in
                        DisclaimerRow(item: item)
                    }

                    Text(DisclaimerContent.footer)
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            VStack(spacing: 10) {
                Button(action: onAccept) {
                    Text("I understand — continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.text))
                        .foregroundStyle(Theme.bg)
                }
                Text("By continuing you acknowledge the notices above.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(
                Theme.surface
                    .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}

private struct DisclaimerRow: View {
    let item: DisclaimerItem
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.icon)
                Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
            }
            Text(item.body)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: 16)
    }
}

struct DisclaimerItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
}

/// Central source of truth for the disclaimer text (reused on the About screen).
enum DisclaimerContent {
    static let items: [DisclaimerItem] = [
        DisclaimerItem(
            icon: "⚕️",
            title: "Not medical advice",
            body: "CivicVision is for general information and education only. It is not a medical device and does not provide medical advice, diagnosis, or treatment. Always consult a qualified health professional about your health, and never disregard or delay professional advice because of something you saw in this app."
        ),
        DisclaimerItem(
            icon: "🧪",
            title: "Live vs. modeled data",
            body: "Air quality (Open-Meteo/CAMS) and, where a gauge is nearby, water pH and dissolved oxygen (USGS) are live. PFAS, microplastics, heavy metals, the community-health baseline, and the recoverable-QALY estimates are MODELED — computed from public reference data and the epidemiological literature, not measured at your address. Every value is labeled Live or Modeled in the app."
        ),
        DisclaimerItem(
            icon: "🚰",
            title: "Not an official report",
            body: "CivicVision is not a substitute for your water utility's Consumer Confidence Report, an official government air-quality advisory, or laboratory testing. For decisions about drinking water or exposure, rely on your utility and local authorities."
        ),
        DisclaimerItem(
            icon: "📉",
            title: "Estimates may be inaccurate",
            body: "Predictions are population-level, decision-support estimates with inherent uncertainty. They may be wrong for any individual location or person, and live feeds can be delayed or unavailable. Use CivicVision as one input among many."
        ),
        DisclaimerItem(
            icon: "🆘",
            title: "In an emergency",
            body: "If you have a medical emergency, call your local emergency number (911 in the US) or Poison Control (1-800-222-1222 in the US). Do not use this app to manage an emergency."
        ),
    ]

    static let footer =
        "CivicVision surfaces county-level environmental and community-health signals for the cardiovascular, respiratory, and renal systems. No account is required and the app does not collect or sell your personal data. Your location is used only to fetch environmental data and is not stored on our servers."
}
