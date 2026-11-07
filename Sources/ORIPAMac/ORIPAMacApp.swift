// Native macOS entry point (SwiftPM executable, bundled by scripts/build_mac.sh).
// The iOS entry point lives in iOSApp/ and shares the same ORIPAUI screens.
import SwiftUI
import ORIPAUI

@main
struct ORIPAMacApp: App {
    var body: some Scene {
        WindowGroup {
            ORIPARootView()
                .frame(minWidth: 480, minHeight: 640)
        }
        .windowResizability(.contentSize)
    }
}
