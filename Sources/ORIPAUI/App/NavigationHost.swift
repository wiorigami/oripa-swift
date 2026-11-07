// Retained navigation host + wiring points for screens owned by other workstreams.
//
// Keeps every screen of the stack alive in the SwiftUI hierarchy while only the topmost
// one is visible/interactive — the exact behaviour of the JS router, which leaves covered
// screens in the DOM (`display: none`) so their state is retained.
import SwiftUI

// MARK: - Screen registry

/// Type-erased wiring points for screens that live in another workstream's files (the
/// editor is owned by ui-canvas). Declared here so ORIPAUI compiles while those files are
/// still landing; the app-integration layer installs the real factories.
@MainActor
public enum OrScreenRegistry {
    /// `.editor(params)` factory. Installed as
    /// `{ AnyView(EditorScreen(params: $0, app: $1)) }` (contract §5.2).
    public static var editorScreenFactory: ((EditorParams, AppModel) -> AnyView)?

    /// Read-only CP preview renderer for a project's OPXC bytes
    /// (installed with ui-canvas's `PreviewRenderer`). Returning nil lets the preview screen
    /// fall back to the stored thumbnail.
    public static var creasePatternPreviewFactory: ((Data) -> AnyView?)?

    /// OPXC → PNG thumbnail renderer (installed with ui-canvas's `CPPNGExport`).
    public static var projectThumbnailRenderer: ((Data) -> Data?)?

    /// True once at least the editor screen has been wired.
    public static var isEditorAvailable: Bool { editorScreenFactory != nil }
}

// MARK: - Navigation host

/// Renders the retained navigation stack.
public struct ORIPANavigationHost: View {
    @ObservedObject public var app: AppModel

    public init(app: AppModel) {
        self.app = app
    }

    public var body: some View {
        ZStack {
            ForEach(Array(app.navigation.enumerated()), id: \.element.id) { index, entry in
                let isTop = index == app.navigation.count - 1
                ORIPAScreenView(entry: entry, isTop: isTop)
                    .environment(\.oripaNavID, entry.id)
                    .zIndex(Double(index))
                    .opacity(isTop ? 1 : 0)
                    .allowsHitTesting(isTop)
                    .accessibilityHidden(!isTop)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OrTheme.background)
    }
}

/// One route → screen mapping (`screens` registry of the JS router).
struct ORIPAScreenView: View {
    let entry: NavEntry
    let isTop: Bool
    @EnvironmentObject private var app: AppModel

    var body: some View {
        switch entry.route {
        case .splash:
            SplashScreen()
        case .projects:
            ProjectsScreen()
        case .preview(let params):
            PreviewScreen(params: params)
        case .settings:
            SettingsScreen()
        case .editor(let params):
            if let factory = OrScreenRegistry.editorScreenFactory {
                factory(params, app)
            } else {
                OrFeatureUnavailableScreen()
            }
        }
    }
}

// MARK: - Placeholder

/// Shown when a workstream's screen is not wired in yet (development only; never a silent
/// blank screen). Mirrors the JS port's "Feature under construction" dialog text.
struct OrFeatureUnavailableScreen: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(spacing: 16) {
            OrToolbar(title: "ORIPA", nav: .back)
            Spacer()
            Text("Feature under construction.\n\nThank you for your patience!")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundColor(OrTheme.textSecondary)
                .padding(24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OrTheme.background)
    }
}
