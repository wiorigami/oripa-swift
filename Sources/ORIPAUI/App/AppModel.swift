// Root application model: retained navigation stack, shared services and Android-style
// back semantics.
//
// Port of `ORIPA.ui.app` (`src/js/ui/app.js`):
//   * `showScreen(id, params, {replace})` -> `push` / `replaceTop`
//   * `back()` consults the top screen's `onBack()` first, then pops (never below root)
//   * covered screens stay alive (state retained) — implemented by keeping every stack
//     entry in the SwiftUI hierarchy (see `ORIPANavigationHost`)
// plus the shared services the screens use: Preferences, ProjectStore, FileExchange,
// SnackbarCenter, DialogCenter and OrMenuCenter.
import Foundation
import SwiftUI
import ORIPACore

extension EnvironmentValues {
    private struct OrIPANavIDKey: EnvironmentKey {
        static let defaultValue: UUID? = nil
    }

    /// Navigation-stack entry id of the screen being rendered (register back handlers etc.).
    public var oripaNavID: UUID? {
        get { self[OrIPANavIDKey.self] }
        set { self[OrIPANavIDKey.self] = newValue }
    }
}

/// @MainActor application model injected as an `EnvironmentObject` by `ORIPARootView`.
@MainActor
public final class AppModel: ObservableObject {

    // MARK: Navigation

    /// Retained screen stack. The last element is the visible screen.
    @Published public private(set) var navigation: [NavEntry]

    // MARK: Shared services

    public let prefs: Preferences
    public let store: ProjectStore
    public let fileExchange: FileExchange
    public let toast: SnackbarCenter
    public let dialogs: DialogCenter
    public let menus: OrMenuCenter

    // MARK: Back handling

    /// `onBack()` handlers of the screens currently in the stack, keyed by stack entry id.
    private var backHandlers: [UUID: () -> Bool] = [:]

    // MARK: Recovery

    private var didPromptForRecovery = false

    // MARK: Init

    public init(navigation: [Route] = [.splash],
                prefs: Preferences? = nil,
                store: ProjectStore? = nil,
                fileExchange: FileExchange? = nil,
                toast: SnackbarCenter? = nil,
                dialogs: DialogCenter? = nil,
                menus: OrMenuCenter? = nil) {
        self.navigation = navigation.map { NavEntry(route: $0) }
        self.prefs = prefs ?? Preferences()
        self.store = store ?? ProjectStore()
        self.fileExchange = fileExchange ?? FileExchange()
        self.toast = toast ?? SnackbarCenter()
        self.dialogs = dialogs ?? DialogCenter()
        self.menus = menus ?? OrMenuCenter()
        self.store.preferences = self.prefs
    }

    // MARK: Navigation API (ORIPA.ui.app)

    public var topEntry: NavEntry? { navigation.last }
    public var currentRoute: Route? { navigation.last?.route }
    public var currentScreenId: String? { currentRoute?.screenId }
    public var stackDepth: Int { navigation.count }
    public var isAtRoot: Bool { navigation.count <= 1 }

    /// `ui.showScreen(id, params)` — push a screen on top of the retained stack.
    public func push(_ route: Route) {
        navigation.append(NavEntry(route: route))
    }

    /// Push a screen, replacing the current top (`opts.replace = true`).
    public func replaceTop(_ route: Route) {
        if navigation.isEmpty {
            navigation.append(NavEntry(route: route))
            return
        }
        let removed = navigation.removeLast()
        backHandlers.removeValue(forKey: removed.id)
        navigation.append(NavEntry(route: route))
    }

    /// `app.back()`: let the top screen consume the back action; otherwise pop.
    /// Returns false at the root (Android back would finish the activity).
    @discardableResult
    public func back() -> Bool {
        if let top = navigation.last, let handler = backHandlers[top.id] {
            if handler() { return true }
        }
        if navigation.count > 1 {
            pop()
            return true
        }
        return false
    }

    /// Pop the top screen (`popTop` of the JS router).
    public func pop() {
        guard navigation.count > 1 else { return }
        let removed = navigation.removeLast()
        backHandlers.removeValue(forKey: removed.id)
    }

    /// `app.popToRoot()`: return to the projects screen (or whatever the root is).
    public func popToRoot() {
        while navigation.count > 1 {
            pop()
        }
    }

    /// Escape / Android system back: menus first, then dialogs, then the screen back logic
    /// (mirrors the JS `window.addEventListener("keydown", …Escape…)` handler).
    @discardableResult
    public func handleSystemBack() -> Bool {
        if menus.isOpen {
            menus.dismiss()
            return true
        }
        if dialogs.isPresented {
            dialogs.closeTop()
            return true
        }
        return back()
    }

    // MARK: Screen back handlers

    /// Register the `onBack()` handler of a screen (`screen.onBack` of the JS router).
    public func setBackHandler(for entryID: UUID?, handler: @escaping () -> Bool) {
        guard let entryID else { return }
        backHandlers[entryID] = handler
    }

    public func removeBackHandler(for entryID: UUID?) {
        guard let entryID else { return }
        backHandlers.removeValue(forKey: entryID)
    }

    // MARK: - Project lifecycle (Android ProjectsActivity / PreviewCreasePatternActivity)

    /// `store.prepareProjectOpen()`: clear prefs + delete the temp autosave before the editor.
    public func prepareProjectOpen() {
        store.prepareProjectOpen()
    }

    /// Projects FAB "New File" (`ProjectsActivity.lambda$onCreate$0`).
    public func openNewFile() {
        prepareProjectOpen()
        push(.editor(EditorParams()))
    }

    /// Open an existing internal project in the editor.
    public func openProject(name: String) {
        prepareProjectOpen()
        push(.editor(EditorParams(projectName: name, srcIsInternal: true)))
    }

    /// Preview "Edit" FAB: start the editor and finish the preview (`opts.replace = true`).
    public func editProjectReplacingPreview(name: String) {
        prepareProjectOpen()
        replaceTop(.editor(EditorParams(projectName: name, srcIsInternal: true)))
    }

    /// Projects "Import": stage the picked file in `Documents/import_data` and open the
    /// editor on it (Android `onExternalFileSelected`). Returns false for unsupported files
    /// or staging failures (caller shows `message_file_copy_error_text`).
    @discardableResult
    public func openImportedFile(_ file: ImportedFile) -> Bool {
        let ext = file.ext.isEmpty ? ProjectStore.fileExtension(of: file.name) : file.ext
        guard FileExchange.importExtensions.contains(ext) else { return false }
        let staged: StagedImport
        do {
            staged = try store.createImportStaging(data: file.bytes, filename: file.name)
        } catch {
            return false
        }
        prepareProjectOpen()
        push(.editor(EditorParams(srcFilenameWithExt: staged.name,
                                  srcProjectDirPath: AppInfo.importDataDirectory,
                                  srcIsInternal: false)))
        return true
    }

    /// Recover the crash-safe autosave: stage the bytes as an external file and open the
    /// editor on it (marked modified, so the save dialog offers to keep the work).
    @discardableResult
    public func recoverDraft() -> Bool {
        guard let (data, meta) = store.readTempSave() else { return false }
        let baseName = meta.srcFilenameNoExt.isEmpty
            ? ProjectStore.filenameNoExt(AppInfo.tempSaveFile)
            : meta.srcFilenameNoExt
        guard let staged = try? store.createImportStaging(data: data,
                                                          filename: baseName + ".opxc") else {
            return false
        }
        prepareProjectOpen()
        push(.editor(EditorParams(srcFilenameWithExt: staged.name,
                                  srcProjectDirPath: AppInfo.importDataDirectory,
                                  srcIsInternal: meta.srcIsInternal)))
        return true
    }

    public func openSettings() {
        push(.settings)
    }

    public func openPreview(name: String) {
        push(.preview(PreviewParams(name: name)))
    }

    /// Show the About dialog (`AboutDialogFragment`); available from every screen.
    public func showAboutDialog() {
        dialogs.show(AboutDialog.makeSpec(app: self))
    }

    // MARK: - Crash recovery prompt

    /// Called once after launch: prompt to recover an unfinished autosave instead of
    /// silently discarding it (native-port requirement; the Android app had no recovery UI).
    public func promptForRecoveryIfNeeded() {
        guard !didPromptForRecovery else { return }
        didPromptForRecovery = true
        guard let draft = store.recoverableDraft() else { return }
        let title = RecoveryStrings.title
        let message = RecoveryStrings.message(projectName: draft.projectName,
                                              savedAt: draft.savedAt)
        dialogs.show(OrDialogSpec(
            title: title,
            icon: "ic_error_outline_dark_24dp",
            content: AnyView(OrDialogText(message)),
            buttons: [
                OrDialogButton(RecoveryStrings.discard) {
                    self.store.deleteTempSave()
                    return true
                },
                OrDialogButton(RecoveryStrings.recover, primary: true) {
                    if !self.recoverDraft() {
                        self.store.deleteTempSave()
                    }
                    return true
                },
            ],
            onClose: nil
        ))
    }

    /// Strings of the launch recovery prompt (native addition — no Android string exists).
    public enum RecoveryStrings {
        public static let title = "Unsaved work found"
        public static let discard = "Discard"
        public static let recover = "Recover"
        public static func message(projectName: String?, savedAt: Date) -> String {
            let name = projectName ?? "untitled"
            return "ORIPA did not close normally. Recover the unsaved changes to \u{201C}\(name)\u{201D} from \(ProjectStore.lastModifiedText(savedAt))?"
        }
    }
}
