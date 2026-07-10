// Color system — a direct port of the web app's CSS custom properties, with the
// same light/dark palettes. Colors adapt automatically to the system appearance.

import SwiftUI
import UIKit

extension Color {
    /// Build a color from a 6-digit hex string (e.g. "#1f1f1f" or "1f1f1f").
    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// A color that resolves differently in light vs dark appearance.
    static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}

enum Theme {
    static let bg = Color.dynamic(light: "f7f7f5", dark: "0a0a0a")
    static let surface = Color.dynamic(light: "ffffff", dark: "161616")
    static let surfaceHover = Color.dynamic(light: "fafafa", dark: "1c1c1c")
    static let border = Color.dynamic(light: "e5e5e3", dark: "2a2a2a")
    static let borderStrong = Color.dynamic(light: "d4d4d2", dark: "3a3a3a")

    static let text = Color.dynamic(light: "0a0a0a", dark: "fafafa")
    static let textSecondary = Color.dynamic(light: "525252", dark: "a3a3a3")
    static let textTertiary = Color.dynamic(light: "8a8a8a", dark: "6a6a6a")
}

extension RiskBand {
    /// Foreground / accent color for this band.
    var fg: Color {
        switch self {
        case .good: return .dynamic(light: "16a34a", dark: "4ade80")
        case .moderate: return .dynamic(light: "ca8a04", dark: "facc15")
        case .sensitive: return .dynamic(light: "ea580c", dark: "fb923c")
        case .unhealthy: return .dynamic(light: "dc2626", dark: "f87171")
        case .very: return .dynamic(light: "9f1239", dark: "fb7185")
        case .hazard: return .dynamic(light: "4a044e", dark: "e879f9")
        }
    }

    /// Tinted background for pills and callouts.
    var bg: Color {
        switch self {
        case .good: return .dynamic(light: "dcfce7", dark: "052e1a")
        case .moderate: return .dynamic(light: "fef9c3", dark: "3a2a04")
        case .sensitive: return .dynamic(light: "ffedd5", dark: "3d1a05")
        case .unhealthy: return .dynamic(light: "fee2e2", dark: "3f0e0e")
        case .very: return .dynamic(light: "ffe4e6", dark: "3f0a1a")
        case .hazard: return .dynamic(light: "f5d0fe", dark: "2a0a2e")
        }
    }
}
