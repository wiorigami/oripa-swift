// "Export Crease Pattern" flow.
//
// Port of `oripa-port/src/js/ui/dialogs/export_cp.js`:
//   ExportExternalDialogFragment (single-choice list of file types, Export disabled until
//   one is picked)
//   ExportPngSquareDialogFragment (square PNG size 200..1600 step 40, default 1000)
//   PaintCpFragment.onClickExportFile / onExportFileTypeSelected /
//   onExportPngSquareOptionsSelected
//   io/export/Exporter.writeToDownloads (native port: FileExchange share/save + snackbars)
//
// The session provides the encoded bytes through `ExportCPHost`; PNG is rendered by
// `CPPNGExport` from the editor bridge, exactly like `renderCpPng` with the Android
// `lineWidthScale = 2.0` factor.
//
// Dialog chrome follows `editor.css` + `dialogs/error.js` `D.material.dialog`: a 24 dp
// heading icon, 20/28 medium title, 48 dp single-choice rows with the Material radio at
// the trailing edge, and uppercase text buttons (CANCEL / EXPORT). The export card has no
// explicit width in the reference and therefore hugs its content at 284 dp; PNG Options
// passes width=320 like the reference.
import Foundation
import SwiftUI

/// The editor session surface used by the export dialog.
@MainActor
public protocol ExportCPHost: AnyObject {
    var srcFilenameNoExt: String { get }
    var settings: EditorSettings { get }
    /// `OripaIO.exportSvg(cp)`.
    func exportSVGData() -> Data?
    /// `OripaIO.exportOpx(cp)`.
    func exportOPXData() -> Data?
    /// `OripaIO.exportCp(cp)`.
    func exportCPData() -> Data?
    /// `renderCpPng(cp, size, size, {showGrid, showFlatLines, dashed, lineWidthScale: 2})`.
    func exportPNGData(sizePx: Int) -> Data?
}

@MainActor
public enum ExportCPDialog {
    /// PaintCpFragment: ExportExternalDialogFragment.newInstance(..., {SVG, PNG, OPX, CP}).
    public static let fileTypes = ["SVG", "PNG", "OPX", "CP"]

    /// ExportPngSquareDialogFragment.newInstance(200, 1600, 40, 1000).
    public static let pngMin = 200
    public static let pngMax = 1600
    public static let pngStep = 40
    public static let pngDefault = 1000

    /// Reference card widths (`M.dialog` width option / content-driven min-width 280).
    private static let exportDialogWidth: CGFloat = 284
    private static let pngDialogWidth: CGFloat = 320

    // MARK: - Entry point

    public static func show(_ dialogs: DialogCenter,
                            fileExchange: FileExchange,
                            toast: SnackbarCenter,
                            host: ExportCPHost) {
        let state = ExportChoiceState()
        let content = ExportDialogContent(state: state,
                                          fileTypes: fileTypes,
                                          dialogs: dialogs) { index in
            // The dialog closes itself before exporting (JS dlg.close(); export…).
            handleFileType(fileTypes[index],
                           dialogs: dialogs,
                           fileExchange: fileExchange,
                           toast: toast,
                           host: host)
        }
        dialogs.show(OrDialogSpec(
            title: nil,
            icon: nil,
            content: AnyView(content),
            buttons: [],
            cancelable: true,
            width: exportDialogWidth))
    }

    // MARK: - File type handling

    private static func handleFileType(_ typeName: String,
                                       dialogs: DialogCenter,
                                       fileExchange: FileExchange,
                                       toast: SnackbarCenter,
                                       host: ExportCPHost) {
        if typeName == "PNG" {
            showPngOptions(dialogs, fileExchange: fileExchange, toast: toast, host: host)
            return
        }
        switch typeName {
        case "SVG":
            guard let data = host.exportSVGData() else {
                snackFail(dialogs, toast)
                return
            }
            write(fileExchange: fileExchange, toast: toast,
                  data: data, filename: "\(host.srcFilenameNoExt).svg", mimeType: "image/svg+xml")
        case "OPX":
            guard let data = host.exportOPXData() else {
                snackFail(dialogs, toast)
                return
            }
            write(fileExchange: fileExchange, toast: toast,
                  data: data, filename: "\(host.srcFilenameNoExt).opx", mimeType: "text/xml")
        case "CP":
            guard let data = host.exportCPData() else {
                snackFail(dialogs, toast)
                return
            }
            write(fileExchange: fileExchange, toast: toast,
                  data: data, filename: "\(host.srcFilenameNoExt).cp", mimeType: "text/plain")
        default:
            break
        }
    }

    /// ExportPngSquareDialogFragment: square size chooser, OK -> export PNG.
    public static func showPngOptions(_ dialogs: DialogCenter,
                                      fileExchange: FileExchange,
                                      toast: SnackbarCenter,
                                      host: ExportCPHost) {
        let model = PngSizeModel(ExportCPDialog.pngDefault)
        let content = PngOptionsDialogContent(model: model)
        dialogs.show(OrDialogSpec(
            title: nil,
            icon: nil,
            content: AnyView(content),
            buttons: [
                OrDialogButton(PaintStrings.cancel),
                OrDialogButton("OK", primary: true) {
                    guard let data = host.exportPNGData(sizePx: model.value) else {
                        snackFail(dialogs, toast)
                        return true
                    }
                    write(fileExchange: fileExchange, toast: toast,
                          data: data, filename: "\(host.srcFilenameNoExt).png",
                          mimeType: "image/png")
                    return true
                },
            ],
            cancelable: true,
            width: pngDialogWidth))
    }

    // MARK: - Writing + snackbars

    private static func write(fileExchange: FileExchange, toast: SnackbarCenter,
                              data: Data, filename: String, mimeType: String) {
        fileExchange.export(data, filename: filename, mimeType: mimeType) { ok in
            if ok {
                toast.show(PaintStrings.downloadSuccess)
            } else {
                toast.show(PaintStrings.downloadFail)
            }
        }
    }

    private static func snackFail(_ dialogs: DialogCenter, _ toast: SnackbarCenter) {
        toast.show(PaintStrings.downloadFail)
        dialogs.showError(PaintStrings.downloadFail)
    }
}

// MARK: - File-type single choice list

@MainActor
private final class ExportChoiceState: ObservableObject {
    /// Android `ExportExternalDialogFragment.selected = -1`: nothing is checked initially.
    @Published var selected: Int = -1
}

/// 24 dp heading icon + 20/28 title, then four 48 dp radio rows and the CANCEL / EXPORT
/// action row. The action row cancels the card's 24 dp content inset (`-16` horizontal)
/// and its 8 dp bottom padding (`-8`) so it spans the card like the reference actions bar.
private struct ExportDialogContent: View {
    @ObservedObject var state: ExportChoiceState
    let fileTypes: [String]
    let dialogs: DialogCenter
    let onExport: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            EditorDialogHeading(icon: "ic_file_download_dark_24dp",
                                title: PaintStrings.exportTitle)
            ForEach(Array(fileTypes.enumerated()), id: \.offset) { index, type in
                EditorDialogChoiceRow(label: type.lowercased(),
                                      isChecked: state.selected == index) {
                    state.selected = index
                }
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                EditorDialogTextButton(text: PaintStrings.cancel,
                                       color: OrTheme.textSecondary) {
                    dialogs.closeTop()
                }
                EditorDialogTextButton(text: PaintStrings.exportPositive,
                                       color: state.selected >= 0 ? OrTheme.accent
                                                                  : OrTheme.textDisabled,
                                       isEnabled: state.selected >= 0) {
                    guard state.selected >= 0 else { return }
                    dialogs.closeTop()
                    onExport(state.selected)
                }
            }
            .padding(8)
            .frame(minHeight: OrTheme.dialogActionsHeight)
            .padding(.top, 8)
            .padding(.horizontal, -24)
            // The action row is the card's last element; eat the dialog content's bottom
            // padding plus the empty-actions card padding so the row ends at the card edge.
            .padding(.bottom, -16)
        }
    }
}

// MARK: - PNG size chooser (200..1600 step 40, default 1000)

/// Mirrors the JS `value` closure so the OK button (owned by the dialog spec) can read it.
@MainActor
private final class PngSizeModel: ObservableObject {
    @Published private(set) var value: Int

    init(_ value: Int) {
        self.value = PngSizeModel.clamp(value)
    }

    func step(_ delta: Int) {
        value = PngSizeModel.clamp(value + delta)
    }

    private static func clamp(_ raw: Int) -> Int {
        let stepped = Int((Double(raw) / Double(ExportCPDialog.pngStep)).rounded())
            * ExportCPDialog.pngStep
        return min(ExportCPDialog.pngMax, max(ExportCPDialog.pngMin, stepped))
    }
}

/// `ui-png-options`: "Image size (pixels):" then a centered − value + stepper row.
private struct PngOptionsDialogContent: View {
    @ObservedObject var model: PngSizeModel

    var body: some View {
        VStack(spacing: 0) {
            EditorDialogHeading(icon: "ic_image_dark_24dp", title: PaintStrings.pngOptionsTitle)
            Text(PaintStrings.pngDimensionText)
                .font(.system(size: 16))
                .foregroundColor(OrTheme.textSecondary)
                .lineLimit(1)
                .frame(height: 24, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                Spacer(minLength: 0)
                stepperButton("\u{2212}") { model.step(-ExportCPDialog.pngStep) }
                Text(String(model.value))
                    .font(.system(size: 20))
                    .foregroundColor(OrTheme.textPrimary)
                    .frame(minWidth: 64, alignment: .leading)
                stepperButton("+") { model.step(ExportCPDialog.pngStep) }
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
        }
    }

    /// `.m-stepper-btn`: 40 × 40, accent, 22 sp glyph, no background.
    private func stepperButton(_ glyph: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 22))
                .foregroundColor(OrTheme.accent)
                .frame(width: OrTheme.stepperButtonSize, height: OrTheme.stepperButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
