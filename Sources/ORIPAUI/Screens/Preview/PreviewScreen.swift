// Preview screen — port of `PreviewCreasePatternActivity` (+ `PreviewDataFragment` /
// `GLSurfaceViewPreviewCP`).
//
// Android layout `activity_preview_cp.xml`: full-screen read-only CP renderer behind a
// transparent gradient toolbar (up arrow + project name) and an Edit FAB; the overflow menu
// is `preview_cp_action_bar.xml` (Rename / Make a copy / Delete). Rename/copy/delete finish
// the preview and report a result to ProjectsActivity (codes 3/4/5), which refreshes the
// list and shows "File renamed" / "File copied" / "File deleted".
import SwiftUI

public struct PreviewScreen: View {
    public let params: PreviewParams

    @EnvironmentObject private var app: AppModel
    @Environment(\.oripaNavID) private var navID
    @Environment(\.oripaSnapshotMode) private var snapshotMode

    @State private var projectData: Data?
    @State private var thumbnail: Image?

    public init(params: PreviewParams) {
        self.params = params
    }

    private var name: String { params.name }

    public var body: some View {
        ZStack(alignment: .top) {
            OrTheme.surface
                .ignoresSafeArea()
            previewArea
            OrToolbar(title: name,
                      nav: .custom(icon: "abc_ic_ab_back_material",
                                   title: ProjectDialogStrings.navigateUp),
                      background: .transparent,
                      actions: [
                          OrToolbarAction(title: ProjectDialogStrings.rename,
                                          showAs: .never) { onRename() },
                          OrToolbarAction(title: ProjectDialogStrings.copy,
                                          showAs: .never) { onCopy() },
                          OrToolbarAction(title: ProjectDialogStrings.remove,
                                          showAs: .never) { onDelete() },
                      ],
                      // `.preview-toolbar .m-toolbar-title { padding: 0 4px 0 8px }`
                      titlePadding: 8)
        }
        .overlay(alignment: .bottomTrailing) {
            OrFAB(icon: "ic_edit_light_24dp", title: "Edit") {
                editCreasePattern()
            }
            .padding(OrTheme.fabMargin)
        }
        .onAppear { load() }
    }

    // MARK: - Preview content

    /// Headless snapshots never run `onAppear`; read the store eagerly in that mode only
    /// (runtime behaviour is unchanged: data is loaded in `onAppear`/`load()`).
    private var effectiveProjectData: Data? {
        snapshotMode ? app.store.readProject(name: name) : projectData
    }

    private var effectiveThumbnail: Image? {
        guard snapshotMode else { return thumbnail }
        if let data = app.store.readThumb(name: name) ?? app.store.regenerateThumb(name: name) {
            return OripaImage.image(data: data)
        }
        return nil
    }

    @ViewBuilder
    private var previewArea: some View {
        if let data = effectiveProjectData,
           let factory = OrScreenRegistry.creasePatternPreviewFactory,
           let preview = factory(data) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OrTheme.surface)
        } else if let effectiveThumbnail {
            // Fallback of the JS port (`renderWithThumbnail`): scaled stored thumbnail.
            effectiveThumbnail
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OrTheme.surface)
        } else {
            OrTheme.surface
        }
    }

    private func load() {
        projectData = app.store.readProject(name: name)
        if let data = app.store.readThumb(name: name) {
            thumbnail = OripaImage.image(data: data)
        } else if let generated = app.store.regenerateThumb(name: name) {
            thumbnail = OripaImage.image(data: generated)
        }
        if projectData == nil {
            thumbnail = nil
        }
    }

    // MARK: - Actions (result codes 3/4/5 of ProjectsActivity.onActivityResult)

    private func onRename() {
        ProjectDialogs.rename(app: app, name: name, silent: true) { _ in
            finish(snackbar: ProjectDialogStrings.renameSuccess)
        }
    }

    private func onCopy() {
        ProjectDialogs.copy(app: app, name: name) { _ in
            finish(snackbar: ProjectDialogStrings.copySuccess)
        }
    }

    private func onDelete() {
        ProjectDialogs.deleteOne(app: app, name: name) {
            finish(snackbar: ProjectDialogStrings.deleteSuccess)
        }
    }

    /// The preview activity finishes; the projects screen shows the result snackbar after
    /// it resumes (the JS port modelled this with the `onResult` callback).
    private func finish(snackbar: String?) {
        if let snackbar {
            app.toast.show(snackbar)
        }
        app.pop()
    }

    private func editCreasePattern() {
        // PreviewCreasePatternActivity.editCreasePattern: start EditorActivity with
        // SRC_IS_INTERNAL=true and finish the preview (`opts.replace = true`).
        app.editProjectReplacingPreview(name: name)
    }
}
