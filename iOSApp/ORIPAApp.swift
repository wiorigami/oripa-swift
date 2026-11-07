// iOS/iPadOS entry point.
//
// The whole UI lives in the SwiftPM `ORIPAUI` library so it can be shared with the
// macOS wrapper (Sources/ORIPAMac) and the headless snapshot tool. This file only
// hosts the app scene; keep it trivial.
import SwiftUI
import ORIPAUI

@main
struct ORIPAApp: App {
    var body: some Scene {
        WindowGroup {
            ORIPARootView()
        }
    }
}
