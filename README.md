# CivicVision for iOS

**Multifactor environmental health for any US locality.** Enter a ZIP code or place — or use your device location — and CivicVision surfaces county-level air and water quality, community health, and its signature feature: a predictive model of the quality-adjusted life-years (QALYs) a community could recover by cutting air and water pollution. Focused on the three organ systems most sensitive to environmental load: **cardiovascular, respiratory, and renal**.

This is a native **SwiftUI** port of the [CivicVision web app](https://github.com/ravirajbuilds/envirovitalsweb). Every engine — the EPA AQI calculator, the water-quality index, the state health baseline, the QALY predictor, and the deterministic location-seeded generator — is reimplemented in Swift and produces the same values as the web app.

## What it shows

- **Air Quality (AQI)** — US EPA AQI from PM2.5, PM10 and ozone (+ NO₂), computed with official breakpoints; the composite equals the worst sub-index and names the driver pollutant.
- **Water Quality (WQI)** — a 0–100 index across three pillars: PFAS & microplastics, heavy metals & pH, and dissolved oxygen.
- **Community Health** — chronic-disease prevalence (coronary heart disease, stroke, COPD, asthma, chronic kidney disease, diabetes) for the county, compared to the US average.
- **Predictive Intelligence** — an interactive scenario engine: reduce air + water pollution toward WHO 2021 targets and see the recoverable QALYs per 100k (and county-wide), broken out by organ system, plus each pollutant's compounding multi-system footprint.

## Data & methods

CivicVision is **live where feeds exist, transparently modeled where they don't** — every value is labeled **Live** or **Modeled** in the UI.

- **Live:** Open-Meteo Air Quality (CAMS) for air; USGS NWIS for pH & dissolved oxygen where a gauge is nearby. Both free, no key, HTTPS.
- **Modeled:** PFAS, microplastics and heavy metals (no free realtime feed) are estimated deterministically from a location's industrial-pressure signature against EPA reference limits. Health baselines are state-level CDC-BRFSS/PLACES-style prevalence adjusted to a county estimate. The predictive engine uses log-linear concentration-response functions from the epidemiological literature (Pope 2004; Krewski 2009; Turner 2016; Bowe 2018; Moon 2012) and WHO 2021 air-quality targets.

Modeled figures are civic decision-support estimates, **not clinical predictions**, **not medical advice**, and **not a substitute for a utility water-quality report or a government air-quality advisory**. See the full disclaimer set in the app (shown on first launch and always available under **Sources & methods**).

## Requirements

- **Xcode 16** or newer
- **iOS 17.0+** deployment target (uses the Observation framework: `@Observable` / `@Bindable`)
- No third-party dependencies, no CocoaPods/SPM packages, no API keys.

## Build & run

```bash
open CivicVision.xcodeproj
```

Select the **CivicVision** scheme and an iOS 17+ simulator (or a device) and press **Run** (⌘R).

From the command line:

```bash
xcodebuild -scheme CivicVision -destination 'generic/platform=iOS' build
```

> The project uses an Xcode 16 **file-system–synchronized group**, so every file placed under `CivicVision/` is compiled automatically — there is no per-file list to maintain. If you'd rather regenerate the project, an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec is provided: `brew install xcodegen && xcodegen generate`.

## Shipping to the App Store

The project is configured for release:

- **App icon** — a single 1024×1024 opaque asset in `Assets.xcassets/AppIcon.appiconset` (Xcode generates the smaller sizes).
- **Privacy manifest** — `CivicVision/PrivacyInfo.xcprivacy` declares no tracking, precise-location used only for app functionality (not linked to identity), and the required-reason `UserDefaults` API.
- **Location permission** — `NSLocationWhenInUseUsageDescription` is set via build settings (`GENERATE_INFOPLIST_FILE = YES`).
- **Disclaimers** — a first-run consent gate plus per-screen medical/data disclaimers.
- **Networking** — all endpoints are HTTPS, so no App Transport Security exceptions are needed.

Before your first upload, set your **Team** and a unique **bundle identifier** (currently `lol.raviraj.civicvision`) under *Signing & Capabilities*, then **Product ▸ Archive**. In App Store Connect, answer the privacy questionnaire to match the manifest: *Precise Location → App Functionality → not used for tracking, not linked to identity.*

## Project structure

```
CivicVision/
├── CivicVisionApp.swift        App entry point
├── PrivacyInfo.xcprivacy       Privacy manifest
├── Assets.xcassets/            App icon + accent color
├── Engine/                     Pure logic (ports of the web app's lib/civic)
│   ├── Rng.swift               Deterministic location-seeded PRNG (xmur3 + mulberry32)
│   ├── Bands.swift             Six-step risk banding
│   ├── Aqi.swift               EPA AQI engine
│   ├── Wqi.swift               Water Quality Index engine
│   ├── Health.swift            State chronic-disease baseline (50 states + DC)
│   ├── Predict.swift           Concentration-response QALY predictor
│   ├── CivicProfile.swift      Orchestrator that assembles one profile
│   └── Format.swift            Display formatting helpers
├── Services/                   Live feeds
│   ├── AirService.swift        Open-Meteo air quality
│   ├── WaterService.swift      USGS NWIS water
│   └── Geocoder.swift          ZIP (Zippopotam) + place (Open-Meteo) search
├── Store/
│   └── ExposureStore.swift     App state, CoreLocation, orchestration
├── Theme/
│   └── Theme.swift             Light/dark color system
└── Views/                      SwiftUI screens & components
    ├── RootView.swift          Disclaimer gate + navigation
    ├── DisclaimerView.swift    First-run consent
    ├── HomeView.swift          Dashboard
    ├── AirView / WaterView / HealthView / PredictView / AboutView
    ├── LocationSearchView.swift
    ├── Components.swift        Reusable UI (rings, meters, pills, cards)
    └── DetailScaffold.swift
```

## Disclaimer

CivicVision is for general information and education only. It is not a medical device and does not provide medical advice, diagnosis, or treatment. Always consult a qualified health professional. In an emergency, call your local emergency number (911 in the US) or Poison Control (1-800-222-1222 in the US).
