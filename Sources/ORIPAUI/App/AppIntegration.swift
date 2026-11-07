// App integration hooks.
//
// The shell (this workstream) compiles and renders without the editor/preview renderer
// files owned by ui-canvas: those are attached here through the type-erased
// `OrScreenRegistry` once available. Keeping the wiring in one small file means the
// workstreams can land independently and the final integration is a single edit.
import Foundation
import SwiftUI
import ORIPACore

/// Installs the real screens/renderers owned by other UI workstreams.
@MainActor
public enum OrAppIntegration {

    private static var installed = false

    /// Safe to call repeatedly (called from `ORIPARootView` on appear).
    public static func installIfNeeded() {
        guard !installed else { return }
        installed = true
        installEditor()
    }

    // MARK: Editor + CP renderers (owned by ui-canvas)

    /// `ORIPACanvasIntegration` (ui-canvas) registers the editor screen factory, the
    /// read-only crease-pattern preview renderer and the OPXC→PNG thumbnail renderer.
    private static func installEditor() {
        ORIPACanvasIntegration.install()
        // `ProjectStore.regenerateThumb` repairs missing project thumbnails from the OPXC
        // bytes; the canvas workstream provides the renderer through its registry.
        if let renderer = OrScreenRegistry.projectThumbnailRenderer {
            ProjectStore.thumbnailRenderer = renderer
        }
    }
}
