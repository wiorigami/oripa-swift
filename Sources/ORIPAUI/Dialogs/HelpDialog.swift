// Per-tool help dialogs.
//
// Port of `oripa-port/src/js/ui/dialogs/help.js` (Android PaintCpHelpDialogFragment +
// dialog/HelpImageDialogFragment): title, one-line usage hint and a 160 dp full-colour
// illustration (assets/icons/ic_oripa_*_help_*.svg, rasterised in Resources/Icons),
// with a single "Close" button.
//
// The tool type is `CpToolType` / `StateMachineManager.getToolType()` (byte).
import Foundation
import SwiftUI

@MainActor
public enum HelpDialog {
    public struct Entry: Equatable {
        public var title: String
        public var message: String
        public var image: String

        public init(title: String, message: String, image: String) {
            self.title = title
            self.message = message
            self.image = image
        }
    }

    /// PaintCpHelpDialogFragment.newInstance(byte toolType) table.
    public static let entries: [Int: Entry] = [
        0: Entry(title: "Segment", message: "Select 2 points",
                 image: "ic_oripa_segment_help_v2"),
        1: Entry(title: "Line", message: "Select 2 points + 2 lines",
                 image: "ic_oripa_line_help_v3"),
        2: Entry(title: "Perpendicular Bisector", message: "Select 2 points + 2 lines",
                 image: "ic_oripa_pbisector_help_v3"),
        3: Entry(title: "Angle Bisector", message: "Select 3 points + 1 line",
                 image: "ic_oripa_bisector_help_v2"),
        4: Entry(title: "Incenter", message: "Select 3 points",
                 image: "ic_oripa_incenter_help_v2"),
        5: Entry(title: "Perpendicular Segment", message: "Select 1 point + 1 line",
                 image: "ic_oripa_vertical_help_v2"),
        6: Entry(title: "Symmetrical Segment", message: "Select 3 points + 1 line",
                 image: "ic_oripa_symmetry_help_v2"),
        7: Entry(title: "Line Extension", message: "Select 2 points + 1 line",
                 image: "ic_oripa_extend_line_help_v2"),
        8: Entry(title: "Mirror Copy", message: "Select multiple lines + long press 1 line",
                 image: "ic_oripa_mirror_help_v2"),
        9: Entry(title: "Segment by Value",
                 message: "Select 2 points or enter value to set angle/length\n\nSelect 1 point to draw",
                 image: "ic_oripa_by_value_help_v2"),
        10: Entry(title: "Change Line", message: "Select 1 or more lines",
                  image: "ic_oripa_select_line_help_v2"),
        11: Entry(title: "Select Line", message: "Select 1 or more lines",
                  image: "ic_oripa_select_line_help_v2"),
        12: Entry(title: "Delete Line", message: "Select 1 or more lines",
                  image: "ic_oripa_select_line_help_v2"),
        13: Entry(title: "Clean Vertex",
                  message: "Select 1 point or more points\n\nDelete unnecessary or stray vertices",
                  image: "ic_oripa_delete_vertex_help"),
    ]

    public static let defaultEntry = Entry(title: "Help", message: "",
                                           image: "ic_oripa_segment_help_v2")

    public static func entry(forTool toolType: Int) -> Entry {
        entries[toolType] ?? defaultEntry
    }

    /// The dialog body as a plain `AnyView` for headless snapshots.
    public static func snapshotContent(toolType: Int) -> AnyView {
        let entry = entry(forTool: toolType)
        let content = VStack(alignment: .leading, spacing: 12) {
            if !entry.message.isEmpty {
                Text(entry.message)
                    .font(OrTheme.body())
                    .foregroundColor(OrTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MaterialIcon(entry.image, size: 160)
                .frame(width: 160, height: 160, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        return AnyView(content)
    }

    /// HelpImageDialogFragment.newInstance(title, message, image).
    public static func showImageHelp(_ dialogs: DialogCenter,
                                     title: String,
                                     message: String,
                                     image: String) {
        let content = VStack(alignment: .leading, spacing: 12) {
            if !message.isEmpty {
                Text(message)
                    .font(OrTheme.body())
                    .foregroundColor(OrTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !image.isEmpty {
                MaterialIcon(image, size: 160)
                    .frame(width: 160, height: 160, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        dialogs.show(OrDialogSpec(
            title: title,
            icon: "ic_help_outline_dark_24dp",
            content: AnyView(content),
            buttons: [OrDialogButton(PaintStrings.close, primary: true)],
            width: 320))
    }

    /// PaintCpHelpDialogFragment.newInstance(toolType).
    public static func showForTool(_ dialogs: DialogCenter, toolType: Int) {
        let entry = entry(forTool: toolType)
        showImageHelp(dialogs, title: entry.title, message: entry.message, image: entry.image)
    }
}
