// Headless snapshot-mode flag.
//
// SwiftUI's `ImageRenderer` (used by `swift run ORIPASnapshots`, no window server) does not
// render the content of `ScrollView`, `LazyVGrid` or `LazyVStack` — those containers only
// materialise visible children through a hosting/scroll layer that does not exist headlessly.
//
// `SnapshotScenarios` sets `\.oripaSnapshotMode == true`; the shell screens then lay their
// content out eagerly in a plain `VStack`/`HStack` grid instead of the scrolling lazy
// containers. At runtime the flag is always false, so the real (scrollable, lazy) layout is
// what users get; the flag only affects the visual-QA snapshots.
import SwiftUI

private struct OrIPASnapshotModeKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// True while rendering a headless snapshot (see `SnapshotScenarios`).
    var oripaSnapshotMode: Bool {
        get { self[OrIPASnapshotModeKey.self] }
        set { self[OrIPASnapshotModeKey.self] = newValue }
    }
}

public extension View {
    /// Marks the subtree as a headless snapshot render (eager layout, no scroll views).
    func oripaSnapshotMode(_ enabled: Bool = true) -> some View {
        environment(\.oripaSnapshotMode, enabled)
    }
}
