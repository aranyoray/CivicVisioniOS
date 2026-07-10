import SwiftUI

/// Gates the app behind a one-time disclaimer, then shows the navigation stack.
struct RootView: View {
    @Environment(ExposureStore.self) private var store
    @AppStorage("civicvision.disclaimerAccepted.v1") private var disclaimerAccepted = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if disclaimerAccepted {
                NavigationStack {
                    HomeView()
                }
                .task { store.startIfNeeded() }
            } else {
                DisclaimerGate { disclaimerAccepted = true }
            }
        }
    }
}
