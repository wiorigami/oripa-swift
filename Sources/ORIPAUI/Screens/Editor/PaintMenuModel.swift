// Paint-screen menu / toolbar state.
//
// Port of the `state` object of `oripa-port/src/js/ui/fragments/paint.js` (minus the
// touch-handling flags, which live in the paint screen itself). The Android preference
// names (`PaintCpFragment.drawAction` …) persist the selected menu ids as the Java
// `R.id` integers, and the core state machines read the same ids back through the
// CpContext adapter.
import Foundation
import SwiftUI

@MainActor
public final class PaintMenuModel: ObservableObject {
    // Selected menu ids (Android R.id values).
    @Published public private(set) var drawActionId: Int
    @Published public private(set) var addMethodId: Int
    @Published public private(set) var addLineTypeId: Int
    @Published public private(set) var changeFromId: Int
    @Published public private(set) var changeToId: Int
    @Published public private(set) var deleteTypeId: Int

    // Toolbar / by-value UI state (not persisted).
    @Published public var topToolbarShown = false
    @Published public var menusHidden = false
    @Published public var byValueIndex: Int = 0
    @Published public var byValueAngleText: String = "0"
    @Published public var byValueLengthText: String = "0"

    public let prefs: Preferences

    /// Called after a menu selection changed so the caller can recreate the state machine.
    public var onToolChanged: ((PaintActionKind) -> Void)?

    public init(prefs: Preferences) {
        self.prefs = prefs
        let state = EditorPrefs.readMenuState(prefs)
        self.drawActionId = state.drawAction
        self.addMethodId = state.addMethod
        self.addLineTypeId = state.addLineType
        self.changeFromId = state.changeFrom
        self.changeToId = state.changeTo
        self.deleteTypeId = state.deleteType
    }

    // MARK: - Current selections

    public var currentAction: PaintActionItem { PaintTools.action(drawActionId) }
    public var currentMethod: PaintMethodItem { PaintTools.method(addMethodId) }
    public var currentLineType: PaintLineTypeItem { PaintTools.lineType(addLineTypeId) }
    public var currentChangeFrom: PaintChangeItem { PaintTools.changeFromItem(changeFromId) }
    public var currentChangeTo: PaintChangeItem { PaintTools.changeToItem(changeToId) }
    public var currentDeleteType: PaintDeleteTypeItem { PaintTools.deleteTypeItem(deleteTypeId) }

    /// `InputLineType` raw value for `cp.inputLineType`.
    public var inputLineType: Int { currentLineType.type }

    /// `updateByValueVisibility()`: visible only for Add Line + Segment by Value + toolbars shown.
    public var byValueVisible: Bool {
        !menusHidden && topToolbarShown && currentAction.action == .add && addMethodId == PaintTools.Id.methodByValue
    }

    // MARK: - Selection mutators (persist + notify)

    public func applyAction(_ id: Int) {
        drawActionId = id
        prefs.setInt(id, for: PaintTools.PrefKey.drawAction)
        notify(.add) // kind is re-read by the caller from currentAction
    }

    public func applyMethod(_ id: Int) {
        addMethodId = id
        prefs.setInt(id, for: PaintTools.PrefKey.addMethod)
        notify(.add)
    }

    public func applyLineType(_ id: Int) {
        addLineTypeId = id
        prefs.setInt(id, for: PaintTools.PrefKey.addLineType)
    }

    public func applyChangeFrom(_ id: Int) {
        changeFromId = id
        prefs.setInt(id, for: PaintTools.PrefKey.changeLineTypeFrom)
    }

    public func applyChangeTo(_ id: Int) {
        changeToId = id
        prefs.setInt(id, for: PaintTools.PrefKey.changeLineTypeTo)
    }

    public func applyDeleteType(_ id: Int) {
        deleteTypeId = id
        prefs.setInt(id, for: PaintTools.PrefKey.deleteLineType)
    }

    public func setByValueIndex(_ index: Int) {
        byValueIndex = min(max(0, index), PaintTools.ByValueEntry.allCases.count - 1)
    }

    public func setByValueAngle(_ value: Double) {
        byValueAngleText = PaintStrings.formatNumber(value.truncatingRemainder(dividingBy: 360))
    }

    public func setByValueLength(_ value: Double) {
        byValueLengthText = PaintStrings.formatNumber(value)
    }

    public var byValueAngleValue: Double { PaintStrings.parseNumber(byValueAngleText) }
    public var byValueLengthValue: Double { PaintStrings.parseNumber(byValueLengthText) }

    public var byValueEntry: PaintTools.ByValueEntry {
        PaintTools.ByValueEntry(rawValue: byValueIndex) ?? .getAngle
    }

    /// `toggleDrawTools()`.
    public func toggleDrawTools() {
        topToolbarShown.toggle()
    }

    /// `setMenusHidden(true/false)`.
    public func setMenusHidden(_ hidden: Bool) {
        menusHidden = hidden
    }

    private func notify(_ kind: PaintActionKind) {
        onToolChanged?(kind)
    }
}
