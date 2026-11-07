// Fold export dialogs — port of `oripa-port/src/js/ui/dialogs/fold_export.js`
// (`ExportExternalDialogFragment` file-type list + `ExportPngSquareDialogFragment`
// NumberPicker wheel; the actual export flow lives in `FoldViewModel`).
import SwiftUI
import ORIPACore

// MARK: - Export file type dialog

/// `ExportExternalDialogFragment`: title "Export Model" + download icon, single-choice list
/// of `FileType.getExtension()` values (svg/png), Export disabled until a choice is made.
struct FoldExportFileTypeDialog: View {
    let fileTypes: [FileType]
    let onSelect: (FileType) -> Void
    let onCancel: () -> Void

    @State private var selectedIndex = -1

    var body: some View {
        FoldDialogScrim(onDismiss: onCancel) {
            FoldDialogCard(title: FoldStrings.exportTitle,
                           icon: "ic_file_download_dark_24dp",
                           contentPadding: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0),
                           buttons: [
                               FoldDialogButton(text: "cancel", action: onCancel),
                               FoldDialogButton(text: "Export",
                                                primary: true,
                                                enabled: selectedIndex >= 0) {
                                   guard selectedIndex >= 0, selectedIndex < fileTypes.count else { return }
                                   onSelect(fileTypes[selectedIndex])
                               },
                           ]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(fileTypes.enumerated()), id: \.offset) { index, fileType in
                        FoldChoiceRow(label: fileType.getExtension(),
                                      selected: index == selectedIndex) {
                            selectedIndex = index
                        }
                    }
                }
            }
            .frame(width: FoldTheme.dialogWidth)
        }
    }
}

// MARK: - PNG options dialog

/// `ExportPngSquareDialogFragment` (`dialog_export_png_square.xml`): "Image size (pixels):"
/// + the Android NumberPicker wheel, min 200 / max 1600 / step 40 / default 1000.
struct FoldPngOptionsDialog: View {
    let onOK: (Int) -> Void
    let onCancel: () -> Void

    @State private var index: Int

    /// NumberPicker values: `min + i*step`.
    static let values: [Int] = Array(stride(from: 200, through: 1600, by: 40))

    init(defaultSize: Int,
         onOK: @escaping (Int) -> Void,
         onCancel: @escaping () -> Void) {
        self.onOK = onOK
        self.onCancel = onCancel
        let initialIndex = FoldPngOptionsDialog.values.firstIndex(of: defaultSize)
            ?? FoldPngOptionsDialog.values.firstIndex(of: 1000)
            ?? 0
        _index = State(initialValue: initialIndex)
    }

    var body: some View {
        FoldDialogScrim(onDismiss: onCancel) {
            // `dialog_export_png_square.xml`: horizontal LinearLayout, `paddingLeft/Right 8dp`,
            // `gravity="center"`, children `layout_margin="8dp"` with `layout_weight="1"`
            // (label and NumberPicker split the card width evenly).
            FoldDialogCard(title: FoldStrings.pngOptionsTitle,
                           icon: "ic_image_dark_24dp",
                           contentPadding: EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8),
                           buttons: [
                               FoldDialogButton(text: "cancel", action: onCancel),
                               FoldDialogButton(text: "ok", primary: true) {
                                   let values = FoldPngOptionsDialog.values
                                   let safeIndex = min(max(0, index), values.count - 1)
                                   onOK(values[safeIndex])
                               },
                           ]) {
                HStack(spacing: 0) {
                    Text(FoldStrings.imageSizeLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(FoldTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    FoldNumberPicker(values: FoldPngOptionsDialog.values, index: $index)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: FoldTheme.dialogWidth)
        }
    }
}

// MARK: - Android NumberPicker wheel

/// Three visible rows (previous / selected / next); taps on the adjacent rows step, a
/// vertical drag scrolls (Android NumberPicker behaviour, no hover wheel on touch).
struct FoldNumberPicker: View {
    let values: [Int]
    @Binding var index: Int

    @State private var dragStartY: CGFloat?
    @State private var dragStartIndex = 0

    private static let rowHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            adjacentRow(index > 0 ? String(values[index - 1]) : "") {
                if index > 0 { index -= 1 }
            }
            selectedRow
            adjacentRow(index < values.count - 1 ? String(values[index + 1]) : "") {
                if index < values.count - 1 { index += 1 }
            }
        }
        .frame(width: 96)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    if dragStartY == nil {
                        dragStartY = gesture.startLocation.y
                        dragStartIndex = index
                    }
                    guard let startY = dragStartY else { return }
                    let steps = Int(((startY - gesture.location.y) / Self.rowHeight).rounded(.towardZero))
                    let newIndex = min(max(0, dragStartIndex + steps), values.count - 1)
                    if newIndex != index { index = newIndex }
                }
                .onEnded { _ in dragStartY = nil }
        )
    }

    private var selectedRow: some View {
        Text(index >= 0 && index < values.count ? String(values[index]) : "")
            .font(.system(size: 22))
            .foregroundStyle(FoldTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: Self.rowHeight)
            .overlay(alignment: .top) {
                Rectangle().fill(FoldTheme.divider).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(FoldTheme.divider).frame(height: 1)
            }
    }

    private func adjacentRow(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(FoldTheme.textDisabled)
                .frame(maxWidth: .infinity)
                .frame(height: Self.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(FoldPressableStyle())
    }
}
