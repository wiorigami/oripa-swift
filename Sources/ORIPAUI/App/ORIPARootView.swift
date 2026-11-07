// App root view. Owned by the `ui-shell` workstream after scaffolding.
import SwiftUI
import ORIPACore

public struct ORIPARootView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text(AppInfo.displayName).font(.largeTitle.bold())
            Text("version \(AppInfo.version)").foregroundStyle(.secondary)
            Text("SwiftUI port scaffolding — ui-shell workstream replaces this view.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
