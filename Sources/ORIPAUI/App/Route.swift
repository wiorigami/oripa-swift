// Android-style screen routes + activity parameter objects.
//
// Port of the `ui.registerScreen` / `ui.showScreen` stack of `src/js/ui/app.js`, with the
// Android `Intent` extras documented in `docs/reports/ui-projects.md`:
//   * `.editor(EditorParams())`                     — EditorActivity with no extras (new file)
//   * `.editor(EditorParams(projectName:))`         — internal project (srcIsInternal = true)
//   * `.editor(EditorParams(srcFilenameWithExt:…))` — imported external file, staged in
//     `Documents/import_data` (srcIsInternal = false)
import Foundation

/// One screen of the retained navigation stack (`Route` + Android screen ids).
public enum Route: Hashable {
    /// `SplashActivity` — grey_50 window with the ORIPA wordmark for 800 ms.
    case splash
    /// `ProjectsActivity` — project grid/list.
    case projects
    /// `PreviewCreasePatternActivity` — read-only CP preview.
    case preview(PreviewParams)
    /// `EditorActivity` (+ retained `ProjectDataFragment`).
    case editor(EditorParams)
    /// `PaintCpSettingsActivity` — the paint settings screen.
    case settings
}

/// Android `EditorActivity` Intent extras (`ProjectKey.*` of the port).
public struct EditorParams: Hashable {
    /// Internal project name in `project_data` (no extension), when editing an existing file.
    public var projectName: String?
    /// External file name with extension (import path), when opening a picked file.
    public var srcFilenameWithExt: String?
    /// External file directory (`import_data` for the native import staging path).
    public var srcProjectDirPath: String?
    /// Android `SRC_IS_INTERNAL`: true for internal `project_data` files.
    public var srcIsInternal: Bool

    public init(projectName: String? = nil,
                srcFilenameWithExt: String? = nil,
                srcProjectDirPath: String? = nil,
                srcIsInternal: Bool = true) {
        self.projectName = projectName
        self.srcFilenameWithExt = srcFilenameWithExt
        self.srcProjectDirPath = srcProjectDirPath
        self.srcIsInternal = srcIsInternal
    }

    /// EditorActivity with no extras — the "New File" FAB path.
    public static var newFile: EditorParams { EditorParams() }
}

/// `PreviewCreasePatternActivity` extras.
public struct PreviewParams: Hashable {
    /// Internal project name in `project_data`.
    public var name: String

    public init(name: String) {
        self.name = name
    }
}

/// A retained entry of the navigation stack. The id keeps SwiftUI view identity (and thus
/// each screen's @State, exactly like the JS router keeps covered screens in the DOM).
public struct NavEntry: Identifiable, Hashable {
    public let id: UUID
    public let route: Route

    public init(route: Route, id: UUID = UUID()) {
        self.route = route
        self.id = id
    }
}

// MARK: - Android screen ids (ORIPA.ui.screenIds)

public extension Route {
    /// `ORIPA.ui.screenIds` of the JS port.
    var screenId: String {
        switch self {
        case .splash: return "splash"
        case .projects: return "projects"
        case .preview: return "preview"
        case .editor: return "editor"
        case .settings: return "settings"
        }
    }
}
