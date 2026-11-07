// Wiring of the ui-canvas screens/renderers into the ui-shell registries.
//
// Mirrors the JS `ui.registerScreen("editor")` plus the preview/thumbnail hand-offs the
// `ui-projects` workstream uses. `OrAppIntegration.installIfNeeded()` (ui-shell) calls
// `install()`; the same calls are safe to repeat (the registries are idempotent).
import Foundation
import SwiftUI
import ORIPACore

@MainActor
public enum ORIPACanvasIntegration {
    /// Installs the editor screen factory, the read-only CP preview renderer and the
    /// OPXC→PNG thumbnail renderer owned by this workstream.
    public static func install() {
        OrScreenRegistry.editorScreenFactory = { params, app in
            AnyView(EditorScreen(params: params, app: app))
        }
        OrScreenRegistry.creasePatternPreviewFactory = { data in
            previewView(opxcData: data)
        }
        OrScreenRegistry.projectThumbnailRenderer = { data in
            thumbnailPNG(opxcData: data)
        }
    }

    /// Read-only preview of a project's OPXC bytes (`GLRendererPreviewCP`).
    public static func previewView(opxcData: Data) -> AnyView? {
        guard let cp = try? OripaIO.loadCreasePatternForce(data: opxcData) else { return nil }
        return AnyView(CanvasPreviewView(creasePattern: cp))
    }

    /// `io.getCreasePatternThumb(180, 180, cp)` for a project's OPXC bytes.
    public static func thumbnailPNG(opxcData: Data) -> Data? {
        guard let cp = try? OripaIO.loadCreasePatternForce(data: opxcData) else { return nil }
        return CoreRenderBridge.renderThumbnail(cp: cp)
    }
}

/// Read-only crease-pattern canvas used by the preview screen and project thumbnails
/// (`PreviewRenderer`, fit to the view with a 5 % margin).
public struct CanvasPreviewView: View {
    @StateObject private var renderer = PreviewRenderer()
    private let creasePattern: CreasePattern

    public init(creasePattern: CreasePattern) {
        self.creasePattern = creasePattern
    }

    public var body: some View {
        PreviewCanvasView(renderer: renderer)
            .background(Color.white)
            .onAppear {
                CoreRenderBridge.configurePreview(renderer, cp: creasePattern)
            }
    }
}
