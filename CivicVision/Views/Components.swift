// Shared UI building blocks — ports of the web app's Card / Civic components.

import SwiftUI
import UIKit

// MARK: - Haptics

/// Tiny helper for tactile feedback on primary actions.
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - Card surface

struct CardSurface: ViewModifier {
    var padding: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

extension View {
    func cardSurface(padding: CGFloat = 20) -> some View { modifier(CardSurface(padding: padding)) }
}

// MARK: - Band pill

struct BandPill: View {
    let band: RiskBand
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(band.fg).frame(width: 6, height: 6)
            Text(band.label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(band.bg))
        .foregroundStyle(band.fg)
    }
}

// MARK: - Live / Modeled badge

struct SimBadge: View {
    let live: Bool
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(live ? RiskBand.good.fg : Theme.textTertiary).frame(width: 6, height: 6)
            Text(live ? "LIVE" : "MODELED")
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(live ? RiskBand.good.bg : Theme.surfaceHover))
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .foregroundStyle(live ? RiskBand.good.fg : Theme.textTertiary)
    }
}

// MARK: - Circular score ring

struct ScoreRing: View {
    let value: Double
    let band: RiskBand
    var size: CGFloat = 132
    var suffix: String? = nil
    var caption: String? = nil

    var body: some View {
        let pct = CGFloat(max(0, min(100, value)) / 100)
        let lineWidth = size * 0.09
        ZStack {
            Circle()
                .stroke(Theme.border, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(band.fg, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: pct)
            VStack(spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(value.rounded()))")
                        .font(.system(size: size * 0.23, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    if let suffix {
                        Text(suffix).font(.system(size: size * 0.12, weight: .semibold))
                    }
                }
                .foregroundStyle(band.fg)
                if let caption {
                    Text(caption.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(lineWidth)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption ?? "Score") \(Int(value.rounded())) out of 100, \(band.label)")
    }
}

// MARK: - Horizontal meter

struct MeterBar: View {
    let fraction: Double // 0…1
    let color: Color
    var height: CGFloat = 8
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceHover)
                Capsule().fill(color)
                    .frame(width: geo.size.width * CGFloat(max(0.03, min(1, fraction))))
                    .animation(.easeOut(duration: 0.6), value: fraction)
            }
        }
        .frame(height: height)
    }
}

struct Meter: View {
    let label: String
    let score: Double       // 0…100, higher is better
    let valueText: String
    var reference: String? = nil
    var live: Bool? = nil
    let band: RiskBand

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.subheadline).foregroundStyle(Theme.text)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Text(valueText)
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Theme.text)
                    if let live { SimBadge(live: live) }
                }
            }
            MeterBar(fraction: score / 100, color: band.fg)
            if let reference {
                Text(reference).font(.caption2).foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

// MARK: - Section label

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
}

// MARK: - Callout

struct Callout: View {
    let band: RiskBand
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(band.fg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(band.bg))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - KPI metric tile

struct MetricTile: View {
    let label: String
    let value: Double?
    var unit: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold)).tracking(0.5)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
            Text(fmtMetric(value))
                .font(.headline).monospacedDigit()
                .foregroundStyle(Theme.text)
            if let unit {
                Text(unit).font(.caption2).foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Home card

struct CivicCardLink<Destination: View, Content: View>: View {
    let icon: String
    let title: String
    var band: RiskBand?
    var loading: Bool = false
    @ViewBuilder let destination: () -> Destination
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 0) {
                if let band {
                    Rectangle().fill(band.fg).frame(width: 4)
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Text(icon).font(.title3)
                        Text(title).font(.headline).foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if loading {
                            ProgressView().scaleEffect(0.7)
                        } else if let band {
                            BandPill(band: band)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    content()
                }
                .padding(20)
                .padding(.leading, band == nil ? 0 : 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Big headline number

struct HeadlineNumber: View {
    let value: String
    let caption: String
    var color: Color = Theme.text
    var size: CGFloat = 44
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(caption)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textTertiary)
        }
    }
}
