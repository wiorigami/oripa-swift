// Fold CP screen — SwiftUI port of `editor/FoldCpFragment` (via
// `oripa-port/src/js/ui/fragments/fold.js`).
//
// Full-screen folded-model viewer with three modes selected by the toolbar spinner
// (`R.array.fold_action_spinner_labels`):
//   0 X-Ray / Wireframe  -> FoldRenderer mode .xray
//   1 Overlap [BETA]     -> FoldRenderer mode .overlap
//   2 Cut Line           -> FoldRenderer mode .cross (split view: CP top / FM bottom in
//                           portrait, CP right / FM left in landscape)
//
// Chrome (`FoldChrome.swift`): transparent floating toolbar with back arrow + spinner +
// settings gear, Cut Line move/rotate mini buttons, export FAB.
// Dialogs (`Dialogs/FoldSettingsDialogs.swift`, `Dialogs/ColorPicker.swift`) and the export
// dialogs (`FoldExportDialogs.swift`) are overlays owned by this screen, like the Android
// DialogFragments.
//
// Mounted by ui-canvas' EditorScreen as `FoldScreen(session: session, app: app)`; back calls
// `session.returnToPaint()` (EditorActivity.returnToPaintFragment) and the navigation stack
// is never popped from here.
import SwiftUI
import ORIPACore

/// The fold screen with fragment lifecycle: the model is entered on appear and dropped on
/// disappear (Android re-creates `FoldCpFragment` on every fold entry).
@MainActor
public struct FoldScreen: View {
    @StateObject private var model: FoldViewModel
    /// When false the platform touch surface is omitted: headless snapshot rendering
    /// (`ImageRenderer`) cannot rasterise `UIViewRepresentable`/`NSViewRepresentable`.
    /// Production always renders the gestures.
    private let rendersPlatformGestures: Bool

    /// - Parameters:
    ///   - initialModeIndex: snapshot-QA hook (`ORIPASnapshots` renders the Overlap / Cut Line
    ///     modes too); the shipping app always enters on the X-Ray item (0), like the freshly
    ///     created Android fragment.
    ///   - rendersPlatformGestures: pass false only from headless snapshot scenarios.
    public init(session: any EditorSessionProtocol,
                app: AppModel,
                initialModeIndex: Int = 0,
                rendersPlatformGestures: Bool = true) {
        _model = StateObject(wrappedValue: FoldViewModel(session: session,
                                                         app: app,
                                                         initialModeIndex: initialModeIndex))
        self.rendersPlatformGestures = rendersPlatformGestures
    }

    public var body: some View {
        GeometryReader { geometry in
            FoldScreenContent(model: model,
                              safeArea: geometry.safeAreaInsets,
                              rendersPlatformGestures: rendersPlatformGestures)
                .onAppear { model.enter(size: geometry.size) }
                .onDisappear { model.leave() }
                .onChange(of: geometry.size) { newSize in
                    model.resize(newSize)
                }
        }
        .ignoresSafeArea()
        .background(FoldTheme.surface)
    }
}

/// The fold screen body without the lifecycle/geometry wrapper. Also used by the headless
/// snapshot support, which pre-enters the view model so `ImageRenderer` can render the
/// screen without relying on `.onAppear`.
@MainActor
struct FoldScreenContent: View {
    @ObservedObject var model: FoldViewModel
    var safeArea: EdgeInsets
    var rendersPlatformGestures: Bool
    /// Measured toolbar spinner width, used to anchor the mode popup (`M.menu`).
    @State private var spinnerWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            canvas
            if rendersPlatformGestures {
                FoldGestureLayer(handlers: model.gestureHandlers)
            }
            chrome
            if let settings = model.settingsSheet {
                settingsOverlay(settings)
            }
            if let export = model.exportSheet {
                exportOverlay(export)
            }
            if model.showsModeMenu {
                FoldModeMenu(model: model,
                             topInset: safeArea.top,
                             // APK screenshot: the spinner dropdown's left edge is 72 dp
                             // (back button 56 + content inset 16), overlapping the toolbar.
                             leading: 72)
                    .ignoresSafeArea()
            }
        }
    }

    /// Full-bleed white canvas with the active mode's renderer.
    private var canvas: some View {
        ZStack {
            FoldTheme.surface
            if let renderer = model.activeRenderer {
                FoldCanvasView(renderer: renderer)
                    .id(ObjectIdentifier(renderer))
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Chrome

    /// Floating toolbar (top), Cut Line mini buttons (bottom-left) and export FAB
    /// (bottom-right, 16dp margins).
    private var chrome: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                FoldToolbar(model: model,
                            topInset: safeArea.top,
                            spinnerWidth: $spinnerWidth)
                Spacer(minLength: 0)
            }
            ZStack(alignment: .bottomLeading) {
                if model.crossButtonsVisible {
                    FoldCrossButtons(model: model)
                        .padding(.leading, safeArea.leading)
                }
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    FoldFAB(icon: "ic_file_download_light_24dp", title: "Export") {
                        model.openExport()
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
            .padding(.bottom, safeArea.bottom)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: - Settings dialogs

    @ViewBuilder
    private func settingsOverlay(_ sheet: FoldSettingsSheet) -> some View {
        switch sheet {
        case .xray(let initialWireframe):
            FoldXraySettingsDialog(initialWireframe: initialWireframe,
                                   onWireframe: { model.xraySettingsWireframeChanged($0) },
                                   onDismiss: { model.closeSettings() })
        case let .overlap(flip, front, back, line):
            FoldOverlapSettingsDialog(initialFlip: flip,
                                      initialFrontColor: front,
                                      initialBackColor: back,
                                      initialLineColor: line,
                                      onFlip: { model.overlapSettingsFlipChanged($0) },
                                      onColors: { model.overlapSettingsColorsChanged(front: $0,
                                                                                     back: $1,
                                                                                     line: $2) },
                                      onDismiss: { model.closeSettings() })
        case let .crossLine(angle, position, buttonsVisible, angleMax, positionMax, wireframeInitial):
            FoldCrossLineSettingsDialog(initialAngleDeg: angle,
                                        initialPosition: position,
                                        initialButtonVisible: buttonsVisible,
                                        angleDegMax: angleMax,
                                        positionMax: positionMax,
                                        wireframeInitial: wireframeInitial,
                                        onUpdate: { model.crossLineSettingsUpdated(angleDeg: $0,
                                                                                   position: $1) },
                                        onWireframe: { model.crossLineSettingsWireframeChanged($0) },
                                        onButtonVisible: { model.crossLineSettingsButtonsVisibleChanged($0) },
                                        onConfirm: { model.crossLineSettingsConfirmed(angleDeg: $0,
                                                                                      position: $1,
                                                                                      wireframeEnabled: $2) },
                                        onCancel: { model.crossLineSettingsCancelled() })
        }
    }

    // MARK: - Export dialogs

    @ViewBuilder
    private func exportOverlay(_ sheet: FoldExportSheet) -> some View {
        switch sheet {
        case .fileType:
            FoldExportFileTypeDialog(fileTypes: [.svg, .png],
                                     onSelect: { model.selectExportFileType($0) },
                                     onCancel: { model.closeExport() })
        case .pngOptions(let defaultSize):
            FoldPngOptionsDialog(defaultSize: defaultSize,
                                 onOK: { model.exportPNG(size: $0) },
                                 onCancel: { model.closeExport() })
        }
    }
}

// MARK: - Canvas

/// SwiftUI `Canvas` wrapper around a `FoldRenderer`; observes the renderer's redraw token.
private struct FoldCanvasView: View {
    @ObservedObject var renderer: FoldRenderer

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            renderer.draw(in: context, size: size)
        }
        .allowsHitTesting(false)
    }
}
