// The "Local Flat Foldability" check screen.
//
// Port of `oripa-port/src/js/ui/fragments/check.js` (CheckCpFragment +
// fragment_check_cp.xml + GLSurfaceViewCheckCp):
//   - transparent gradient toolbar with the up arrow and title "Local Flat Foldability"
//   - full-screen CheckRenderer showing the pink flat-foldable face polygons, typed CP
//     lines/vertices and red error points
//   - pinch zoom + two-finger pan only (no drawing); back arrow -> return to paint
//
// The paint fragment runs `cp.isFlatFoldable()` before showing this fragment (it fills
// cp.facesCheck / cp.pointErrorCheck); the check data is cleared when the fragment leaves.
import Foundation
import SwiftUI
import ORIPACore

@MainActor
final class CheckCoordinator {
    let session: EditorSession
    let renderer: CheckRenderer
    let recognizer = CanvasGestureRecognizer()
    let app: AppModel

    private var lastTwo: (scale: CGFloat, cx: CGFloat, cy: CGFloat)?

    init(session: EditorSession, renderer: CheckRenderer, app: AppModel) {
        self.session = session
        self.renderer = renderer
        self.app = app
        bindCallbacks()
    }

    private func bindCallbacks() {
        var callbacks = CanvasGestureRecognizer.Callbacks()
        callbacks.onTwoFingerStart = { [weak self] state in
            self?.lastTwo = (scale: 1, cx: state.cx, cy: state.cy)
        }
        callbacks.onTwoFingerMove = { [weak self] state in
            self?.handleTwoFinger(state)
        }
        callbacks.onTwoFingerEnd = { [weak self] in
            self?.lastTwo = nil
        }
        recognizer.callbacks = callbacks
    }

    func configure() {
        CoreRenderBridge.configureCheck(renderer, cp: session.cp, settings: session.settings)
        renderer.requestDraw()
    }

    private func handleTwoFinger(_ state: TwoFingerState) {
        let previous = lastTwo ?? (scale: 1, cx: state.cx, cy: state.cy)
        let factor = previous.scale > 0 ? state.scale / previous.scale : 1
        let panDx = state.cx - previous.cx
        let panDy = state.cy - previous.cy
        lastTwo = (scale: state.scale, cx: state.cx, cy: state.cy)

        let vt = renderer.viewTransform
        // ViewTransform gesture methods take canvas px (check.js keeps the same matrix ops).
        if panDx != 0 || panDy != 0 {
            vt.translateTransformM(dxPx: panDx, dyPx: panDy)
        }
        if factor != 1 {
            vt.scaleTransformM(factor: factor, focusXPx: state.cx, focusYPx: state.cy)
        }
        renderer.requestDraw()
    }
}

public struct CheckScreen: View {
    @ObservedObject var session: EditorSession
    @ObservedObject var renderer: CheckRenderer
    let app: AppModel
    let coordinator: CheckCoordinator
    private let interactionEnabled: Bool
    @Environment(\.oripaSnapshotMode) private var snapshotMode

    init(session: EditorSession, renderer: CheckRenderer, app: AppModel,
         coordinator: CheckCoordinator, interactionEnabled: Bool = true) {
        self.session = session
        self.renderer = renderer
        self.app = app
        self.coordinator = coordinator
        self.interactionEnabled = interactionEnabled
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.white
            CheckCanvasView(renderer: renderer)
                .ignoresSafeArea()
                .contentShape(Rectangle())
            if interactionEnabled && !snapshotMode {
                CanvasGestureOverlay(recognizer: coordinator.recognizer)
                    .ignoresSafeArea()
            }

            checkToolbar
        }
        .onAppear {
            coordinator.configure()
        }
        .onDisappear {
            // CheckCpFragment clears the check render data after use.
            session.cp.clearCheckData()
        }
    }

    /// `.editor-check-toolbar`: transparent gradient over the canvas, no elevation.
    ///
    /// APK `fragment_check_cp.xml` is a full-width `Toolbar` (56 dp, `actionBarSize`) with
    /// `background_gradient_transparent` (colorPrimary at the top → transparent at the
    /// bottom, no elevation). Its home-as-up button is 56 dp wide starting at x = 0, so the
    /// 24 dp arrow sits 16 dp from the screen edge and the title starts at x = 72 dp
    /// (56 dp navigation + 16 dp `contentInsetStartWithNavigation`). The title uses the
    /// AppCompat toolbar style `abc_text_size_title_material_toolbar` = 20 sp; the
    /// measured 6 px stems at 2.625 px/dp (0.115 em) are Roboto **Medium**, matching
    /// `OrTheme.toolbarTitle()` (the Settings title measures the same 6 px stems).
    private var checkToolbar: some View {
        HStack(spacing: 0) {
            EditorIconButton(icon: "ic_arrow_back_dark_24dp",
                             title: PaintStrings.navigateUp,
                             size: 56,
                             // The bundled back-arrow PNG is opaque white; the reference
                             // tints it with the Material icon-active colour.
                             role: .tint(OrTheme.iconActive)) {
                session.returnToPaint()
            }
            Text(PaintStrings.checkTitle)
                .font(OrTheme.toolbarTitle())
                .foregroundColor(OrTheme.textPrimary)
                .lineLimit(1)
                .padding(.leading, 16)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 56)
        .background(
            LinearGradient(colors: [Color(hex: 0xF5F5F5, opacity: 0.94),
                                    Color(hex: 0xF5F5F5, opacity: 0.0)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}
