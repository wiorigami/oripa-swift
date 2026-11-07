// Native macOS entry point (SwiftPM executable, assembled into ORIPA.app by
// scripts/build_mac.sh). The iOS entry point lives in iOSApp/ and both wrappers
// share the same SwiftUI screens from the ORIPAUI library.
import SwiftUI
import ORIPAUI

@main
struct ORIPAMacApp: App {
    var body: some Scene {
        WindowGroup("ORIPA") {
            ORIPARootView()
                .frame(minWidth: 640, minHeight: 480)
        }
        .defaultSize(width: 1024, height: 768)
        .windowResizability(.contentMinSize)
    }
}
