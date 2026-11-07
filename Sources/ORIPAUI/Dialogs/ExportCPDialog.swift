// "Export Crease Pattern" flow.
//
// Port of `oripa-port/src/js/ui/dialogs/export_cp.js`:
//   ExportExternalDialogFragment (radio list of file types)
//   ExportPngSquareDialogFragment (square PNG size 200..1600 step 40, default 1000)
//   PaintCpFragment.onClickExportFile / onExportFileTypeSelected /
//   onExportPngSquareOptionsSelected
//   io/export/Exporter.writeToDownloads (native port: FileExchange share/save + snackbars)
//
// The session provides the encoded bytes through `ExportCPHost`; PNG is rendered by
// `CPPNGExport` from the editor bridge, exactly like `renderCpPng` with the Android
// `lineWidthScale = 2.0` factor.
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

    // MARK: - Entry point

    public static func show(_ dialogs: DialogCenter,
                            fileExchange: FileExchange,
                            toast: SnackbarCenter,
                            host: ExportCPHost) {
        let content = ExportTypeChoiceView(dialogs: dialogs, fileTypes: fileTypes) { index in
            // The dialog closes itself before exporting (JS dlg.close(); export…).
            handleFileType(fileTypes[index],
                           dialogs: dialogs,
                           fileExchange: fileExchange,
                           toast: toast,
                           host: host)
        }
        dialogs.show(OrDialogSpec(
            title: PaintStrings.exportTitle,
            icon: "ic_file_download_dark_24dp",
            content: AnyView(content),
            buttons: [],
            cancelable: true,
            width: 320))
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
        var value = pngDefault
        let content = PngSizeChoiceView(initialValue: value) { newValue in
            value = newValue
        }
        dialogs.show(OrDialogSpec(
            title: PaintStrings.pngOptionsTitle,
            icon: "ic_image_dark_24dp",
            content: AnyView(content),
            buttons: [
                OrDialogButton(PaintStrings.cancel),
                OrDialogButton("OK", primary: true) {
                    // The size chooser keeps its value in the observed model.
                    let size = content.value
                    guard let data = host.exportPNGData(sizePx: size) else {
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
            width: 320))
        _ = value
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

// MARK: - File-type radio list (buttons live in the content so Export can stay disabled)

private struct ExportTypeChoiceView: View {
    let dialogs: DialogCenter
    let fileTypes: [String]
    let onExport: (Int) -> Void

    @State private var selected: Int = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(fileTypes.enumerated()), id: \.offset) { index, type in
                Button {
                    selected = index
                } label: {
                    HStack(spacing: 16) {
                        Text(type.lowercased())
                            .font(OrTheme.menuItem())
                            .foregroundColor(OrTheme.textPrimary)
                        Spacer(minLength: 8)
                        OrRadioMark(isChecked: selected == index)
                    }
                    .padding(.horizontal, 8)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                OrTextButton(PaintStrings.cancel) {
                    dialogs.closeTop()
                }
                OrTextButton(PaintStrings.exportPositive, isPrimary: true) {
                    guard selected >= 0 else { return }
                    dialogs.closeTop()
                    onExport(selected)
                }
                .disabled(selected < 0)
                .opacity(selected < 0 ? 0.38 : 1)
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - PNG size chooser (NumberPicker 200..1600 step 40, default 1000)

private struct PngSizeChoiceView: View {
    /// Value is mirrored into this class so the dialog buttons can read it.
    final class Model: ObservableObject {
        @Published var value: Int
        init(_ value: Int) { self.value = value }
    }

    @ObservedObject private var model: Model
    let onChange: (Int) -> Void

    init(initialValue: Int, onChange: @escaping (Int) -> Void) {
        self.model = Model(initialValue)
        self.onChange = onChange
    }

    var value: Int { model.value }

    private func setValue(_ v: Int) {
        let stepped = Int((Double(v) / Double(ExportCPDialog.pngStep)).rounded()) * ExportCPDialog.pngStep
        let clamped = min(ExportCPDialog.pngMax, max(ExportCPDialog.pngMin, stepped))
        model.value = clamped
        onChange(clamped)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PaintStrings.pngDimensionText)
                .font(OrTheme.body())
                .foregroundColor(OrTheme.textSecondary)
            HStack {
                Spacer(minLength: 0)
                Button { setValue(model.value - ExportCPDialog.pngStep) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: OrTheme.stepperButtonSize, height: OrTheme.stepperButtonSize)
                }
                .buttonStyle(.plain)
                .foregroundColor(OrTheme.iconActive)

                Text("\(model.value)")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(OrTheme.textPrimary)
                    .frame(minWidth: 96)

                Button { setValue(model.value + ExportCPDialog.pngStep) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: OrTheme.stepperButtonSize, height: OrTheme.stepperButtonSize)
                }
                .buttonStyle(.plain)
                .foregroundColor(OrTheme.iconActive)
                Spacer(minLength: 0)
            }
        }
    }
}
