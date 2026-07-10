import SwiftUI

/// Shared layout for the pushed detail screens (title, subtitle, centered column).
struct DetailScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.largeTitle.bold()).foregroundStyle(Theme.text)
                    Text(subtitle).font(.subheadline).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 4)
                content()
            }
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A small muted footnote used for per-screen source notes and disclaimers.
struct FootNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
    }
}

/// Shown on a detail screen when no location has been chosen yet.
struct NoLocationCard: View {
    let noun: String
    var body: some View {
        Text("No location yet. Go back and set a ZIP or place on the home screen to see \(noun).")
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .cardSurface(padding: 16)
    }
}
