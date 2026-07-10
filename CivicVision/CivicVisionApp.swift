import SwiftUI

@main
struct CivicVisionApp: App {
    @State private var store = ExposureStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.text)
        }
    }
}
