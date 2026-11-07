// App root view shared by the iOS app entry (iOSApp/) and the macOS app (ORIPAMac).
//
// Creates the AppModel, injects the shared services as environment objects, hosts the
// retained navigation stack and the global overlays (popup menu, dialog, snackbar) and
// wires the native document picker. Both platform wrappers only need:
//
//     ORIPARootView()
//
// Reference: `src/index.template.html` + the `#app` root of the web port (theme background,
// safe-area strip in colorPrimaryDark) and `src/js/ui/app.js` (router start with splash).
import SwiftUI
import UniformTypeIdentifiers

public struct ORIPARootView: View {
    @StateObject private var app: AppModel
    @State private var didStart = false

    /// Default app entry point (iOSApp / ORIPAMac wrappers).
    public init() {
        _app = StateObject(wrappedValue: AppModel())
    }

    /// Inject a custom model (snapshots, tests, previews).
    public init(app: AppModel) {
        _app = StateObject(wrappedValue: app)
    }

    public var body: some View {
        ZStack {
            // Android status-bar strip colour (colorPrimaryDark) behind the safe areas.
            OrTheme.primaryDark.ignoresSafeArea()
            ORIPANavigationHost(app: app)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { OrMenuHost(center: app.menus) }
        .overlay { OrDialogHost(center: app.dialogs) }
        .overlay { SnackbarHost(center: app.toast) }
        .overlay { OrFileImporterHost() }
        .overlay { OrEscapeShortcutHost() }
        .environmentObject(app)
        .environmentObject(app.prefs)
        .environmentObject(app.store)
        .environmentObject(app.fileExchange)
        .environmentObject(app.toast)
        .environmentObject(app.dialogs)
        .environmentObject(app.menus)
        .preferredColorScheme(.light)
        .task {
            guard !didStart else { return }
            didStart = true
            OrAppIntegration.installIfNeeded()
            // Splash stays for 800 ms (SplashActivity parity), then the recovery prompt (if
            // an unfinished autosave exists) appears over the projects screen.
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            app.promptForRecoveryIfNeeded()
        }
    }
}

// MARK: - Document picker host

/// Hosts `.fileImporter`, which needs an owning view with the `isPresented` binding.
/// `FileExchange.pickImport()` flips the published flag; the picker result feeds back into
/// `FileExchange.completeImport`.
private struct OrFileImporterHost: View {
    @EnvironmentObject private var exchange: FileExchange

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .fileImporter(isPresented: $exchange.isImporting,
                          allowedContentTypes: FileExchange.importContentTypes,
                          allowsMultipleSelection: true) { result in
                exchange.completeImport(result)
            }
            .onChange(of: exchange.isImporting) { isImporting in
                if !isImporting {
                    // A cancel sometimes only resets the binding without calling the
                    // completion handler; make sure the awaiting continuation resolves.
                    exchange.importDismissed()
                }
            }
    }
}

// MARK: - Keyboard shortcuts

/// Desktop convenience: Escape behaves like Android back (`app.js` keydown handler).
private struct OrEscapeShortcutHost: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            Button("") { _ = app.handleSystemBack() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .frame(width: 0, height: 0)
        }
        .frame(width: 0, height: 0)
        #if os(macOS)
        .onExitCommand { _ = app.handleSystemBack() }
        #endif
    }
}
