import SwiftUI

struct HomeView: View {
    @Environment(ExposureStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                LocationHeaderView()
                if store.civic != nil {
                    CivicHero()
                }
                AirCard()
                WaterCard()
                HealthCard()
                PredictCard()
                NavigationLink(destination: AboutView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                        Text("Sources & methods").font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .cardSurface(padding: 16)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Header

private struct LocationHeaderView: View {
    @Environment(ExposureStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Text("🛰️").font(.title)
                    Text("CivicVision").font(.largeTitle.bold()).foregroundStyle(Theme.text)
                }
                Spacer()
                Button {
                    store.refresh()
                } label: {
                    if store.loadingAir || store.loadingWater {
                        ProgressView().scaleEffect(0.7).frame(width: 54, height: 30)
                    } else {
                        Text("Refresh").font(.caption.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                    }
                }
                .foregroundStyle(Theme.textSecondary)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                .accessibilityLabel("Refresh location and data")
            }

            Text("Multifactor environmental health for any US locality")
                .font(.caption).foregroundStyle(Theme.textTertiary)

            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse").font(.caption2)
                Text(subtitle).font(.subheadline).monospacedDigit()
            }
            .foregroundStyle(Theme.textSecondary)

            if let note = statusNote {
                Text(note).font(.caption).foregroundStyle(Theme.textTertiary)
            }
            if let updated = store.lastUpdated {
                HStack(spacing: 8) {
                    Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    if store.coord?.source == .manual {
                        Button("Use my GPS") { store.requestLocation() }
                            .font(.caption)
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            }

            LocationSearchView()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        let coord = store.coord
        if let place = placeString {
            return place
        }
        switch store.geoStatus {
        case .denied, .unsupported: return "Enter a ZIP or place to begin."
        case .requesting: return "Acquiring GPS fix…"
        default: break
        }
        if let coord {
            let acc = coord.accuracy.map { " · ±\(Int($0))m" } ?? ""
            return String(format: "%.3f, %.3f%@", coord.lat, coord.lon, acc)
        }
        return "Enter a ZIP or place to monitor your locality."
    }

    private var placeString: String? {
        guard let coord = store.coord else { return nil }
        if let county = coord.county, let state = coord.state {
            return "\(county), \(coord.stateAbbr ?? state)"
        }
        if let state = coord.state {
            let city = coord.label?.components(separatedBy: " · ").first
            return [city, state].compactMap { $0 }.joined(separator: ", ")
        }
        return coord.label
    }

    private var statusNote: String? {
        guard placeString != nil else { return nil }
        switch store.geoStatus {
        case .denied: return "GPS denied; showing selected location."
        case .unsupported: return "GPS unavailable; showing selected location."
        case .requesting: return "Acquiring GPS fix…"
        default: return nil
        }
    }
}

// MARK: - Civic hero

private struct CivicHero: View {
    @Environment(ExposureStore.self) private var store

    var body: some View {
        if let civic = store.civic {
            let rows: [(String, Int)] = [
                ("Air", civic.scores.air),
                ("Water", civic.scores.water),
                ("Health", civic.scores.health),
            ]
            HStack(spacing: 20) {
                ScoreRing(value: Double(civic.civicScore), band: civic.civicBand, caption: "Civic score")
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        BandPill(band: civic.civicBand)
                        Text("composite index").font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                    VStack(spacing: 8) {
                        ForEach(rows, id: \.0) { row in
                            HStack(spacing: 8) {
                                Text(row.0).font(.caption.weight(.medium))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 44, alignment: .leading)
                                MeterBar(fraction: Double(row.1) / 100, color: bandFromScore(Double(row.1)).fg, height: 6)
                                Text("\(row.1)").font(.caption.weight(.semibold)).monospacedDigit()
                                    .foregroundStyle(Theme.text)
                                    .frame(width: 26, alignment: .trailing)
                            }
                        }
                    }
                    Text("Higher is healthier · \(civic.civicBand.label) for \(civic.stateAbbr ?? "this area")")
                        .font(.caption).foregroundStyle(Theme.textTertiary)
                }
            }
            .cardSurface()
        }
    }
}

// MARK: - Cards

private struct EmptyLine: View {
    let text: String
    var body: some View {
        Text(text).font(.subheadline).foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AirCard: View {
    @Environment(ExposureStore.self) private var store
    var body: some View {
        let air = store.civic?.air
        CivicCardLink(icon: "💨", title: "Air Quality", band: air?.band,
                      loading: store.loadingAir && air == nil) {
            AirView()
        } content: {
            if let air {
                VStack(alignment: .leading, spacing: 16) {
                    HeadlineNumber(value: "\(air.aqi)", caption: "US AQI · \(air.driver.label)-driven", color: air.band.fg, size: 40)
                    HStack {
                        MetricTile(label: "PM2.5", value: air.subs[0].concentration, unit: "µg/m³")
                        MetricTile(label: "PM10", value: air.subs[1].concentration, unit: "µg/m³")
                        MetricTile(label: "Ozone", value: air.subs[2].concentration, unit: "µg/m³")
                    }
                }
            } else {
                EmptyLine(text: "Set a location to see county air quality.")
            }
        }
    }
}

private struct WaterCard: View {
    @Environment(ExposureStore.self) private var store
    var body: some View {
        let water = store.civic?.water
        CivicCardLink(icon: "💧", title: "Water Quality", band: water?.band,
                      loading: store.loadingWater && water == nil) {
            WaterView()
        } content: {
            if let water {
                VStack(alignment: .leading, spacing: 16) {
                    HeadlineNumber(value: "\(water.wqi)", caption: "WQI · \(water.driver)", color: water.band.fg, size: 40)
                    HStack {
                        MetricTile(label: "PFAS", value: water.measures.pfas, unit: "ppt")
                        MetricTile(label: "Microplast.", value: water.measures.microplastics, unit: "/L")
                        MetricTile(label: "pH", value: water.measures.pH)
                    }
                }
            } else {
                EmptyLine(text: "Set a location to see county water quality.")
            }
        }
    }
}

private struct HealthCard: View {
    @Environment(ExposureStore.self) private var store
    var body: some View {
        let civic = store.civic
        let health = civic?.health
        CivicCardLink(icon: "🫀", title: "Community Health",
                      band: civic.map { bandFromScore(Double($0.scores.health)) }) {
            HealthView()
        } content: {
            if let civic, let health {
                let cardio = health.conditions.first { $0.key == .chd }
                let resp = health.conditions.first { $0.key == .copd }
                let renal = health.conditions.first { $0.key == .ckd }
                VStack(alignment: .leading, spacing: 16) {
                    HeadlineNumber(value: "\(civic.scores.health)", caption: "health score", size: 40)
                    HStack {
                        MetricTile(label: "Cardio", value: cardio?.countyPct, unit: "% CHD")
                        MetricTile(label: "Respir.", value: resp?.countyPct, unit: "% COPD")
                        MetricTile(label: "Renal", value: renal?.countyPct, unit: "% CKD")
                    }
                }
            } else {
                EmptyLine(text: "Set a location to see the community health profile.")
            }
        }
    }
}

private struct PredictCard: View {
    @Environment(ExposureStore.self) private var store
    var body: some View {
        let p = store.civic?.prediction
        CivicCardLink(icon: "🔮", title: "Predictive Intelligence", band: nil) {
            PredictView()
        } content: {
            if let p {
                VStack(alignment: .leading, spacing: 6) {
                    HeadlineNumber(value: fmtQaly(p.maxRecoverablePer100k),
                                   caption: "QALYs / 100k · recoverable",
                                   color: RiskBand.good.fg, size: 34)
                    (
                        Text("Cutting air + water pollution to WHO targets could recover ")
                            .foregroundColor(Theme.textSecondary)
                        + Text(fmtNum(p.maxRecoverablePer100k * p.population / 100_000, 0))
                            .fontWeight(.bold).foregroundColor(Theme.text)
                        + Text(" quality-life-years/yr across ~\(fmtNum(p.population, 0)) residents. Model the compounding effects →")
                            .foregroundColor(Theme.textSecondary)
                    )
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                EmptyLine(text: "Set a location to model health gains from cleaner air & water.")
            }
        }
    }
}
