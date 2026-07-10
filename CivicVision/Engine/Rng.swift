// Deterministic pseudo-random generation seeded by location.
//
// A faithful port of the web app's xmur3 + mulberry32 generators. The same
// coordinates always produce the same simulated readings, so a place looks
// stable across visits and never "flickers" between renders. Every simulated
// value derived from this generator is clearly labeled "Modeled" in the UI.
//
// All arithmetic is done in UInt32 with wrapping operators (&*, &+, <<, >>),
// which reproduces JavaScript's 32-bit `Math.imul` / bitwise semantics
// bit-for-bit, so the iOS app and the web app agree on every modeled value.

import Foundation

/// JavaScript `Math.round`: rounds half toward +∞ (not away-from-zero).
/// Needed so location seeds match the web app for negative coordinates.
@inline(__always)
func jsRound(_ x: Double) -> Double {
    (x + 0.5).rounded(.down)
}

private func xmur3(_ str: String) -> () -> UInt32 {
    var h: UInt32 = 1779033703 ^ UInt32(str.utf16.count)
    for code in str.utf16 {
        h = (h ^ UInt32(code)) &* 3432918353
        h = (h << 13) | (h >> 19)
    }
    return {
        h = (h ^ (h >> 16)) &* 2246822507
        h = (h ^ (h >> 13)) &* 3266489909
        h ^= h >> 16
        return h
    }
}

private func mulberry32(_ seed: UInt32) -> () -> Double {
    var a = seed
    return {
        a = a &+ 0x6d2b_79f5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4294967296.0
    }
}

/// A small, seedable random source with domain-friendly helpers.
final class Rng {
    private let nextValue: () -> Double

    init(seed: String) {
        let s = xmur3(seed)
        self.nextValue = mulberry32(s())
    }

    /// Uniform in [0, 1).
    func unit() -> Double { nextValue() }

    /// Uniform in [min, max).
    func range(_ minV: Double, _ maxV: Double) -> Double {
        minV + nextValue() * (maxV - minV)
    }

    /// Approximately-normal sample (sum of 3 uniforms) with mean/sd, optionally clamped.
    func normal(mean: Double, sd: Double, lo: Double = -.infinity, hi: Double = .infinity) -> Double {
        let u = (nextValue() + nextValue() + nextValue()) / 3   // ~N(0.5, …)
        let z = (u - 0.5) * 3.4641                               // scale so sd of the sum ≈ 1
        return min(hi, max(lo, mean + z * sd))
    }

    /// True with probability p.
    func chance(_ p: Double) -> Bool { nextValue() < p }
}

/// Stable seed for a coordinate — rounded so nearby points share a locality signature (~2 km grid).
func locationSeed(_ lat: Double, _ lon: Double, salt: String = "") -> String {
    let rl = jsRound(lat * 50) / 50
    let ro = jsRound(lon * 50) / 50
    return "civicvision:\(fixed2(rl)):\(fixed2(ro)):\(salt)"
}

/// A 0…1 "urbanization / industrial pressure" proxy for a coordinate.
/// We can't know true land use offline, so we derive a smooth, deterministic
/// field from the coordinates that clusters into believable hot/cool zones.
func pressureField(_ lat: Double, _ lon: Double) -> Double {
    let a = sin(lat * 1.7) * cos(lon * 1.3)
    let b = sin(lon * 0.9 + 2.1) * cos(lat * 0.6)
    let c = sin((lat + lon) * 0.45)
    let raw = (a + b + c) / 3            // -1…1
    return min(1, max(0, (raw + 1) / 2)) // 0…1
}

/// Format like JavaScript's `Number.toFixed(2)` for the seed grid values.
/// Grid values are exact multiples of 0.02, so 2-decimal formatting is exact.
private func fixed2(_ value: Double) -> String {
    let v = value == 0 ? 0.0 : value // avoid "-0.00"
    return String(format: "%.2f", v)
}
