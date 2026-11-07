// Port of the Android `Context` surface consumed by the tool state machines.
//
// Reference: oripa-port/src/js/core/model/tool/{ChangeLineSM,DeleteLineSM}.js and
// {AddSegmentByValueGetAngle,AddSegmentByValueGetLength,AddSegmentByValueDrawLine}SM.js,
// where the JS port replaces the Android `Context`/`PaintCpFragment` casts with an explicit
// `context` object (`context.getPref(key, def)`, `context.paintFragment.*`).
//
// This is the shared boundary API from docs/PORT-CONTRACT.md §5.1: declared here (core-tools),
// implemented by ORIPAUI (ui-canvas's editor/paint session, adapted over `Preferences` and the
// paint fragment). Foundation-only: no SwiftUI/UIKit.
//
// Method names are the exact Java `PaintCpFragment` names (`…AngleDegText`) so the port stays
// 1:1 with the reference call sites; the contract's abbreviated `…AngleText` wording is the
// same API.
import Foundation

/// The `context` object handed to `CpStateMachine.doTransition` / `doBatch*Operation` /
/// `finish`, i.e. the slice of the Android activity/paint fragment the state machines read.
///
/// The JS reference tolerates a missing context/fragment (falls back to Android defaults).
/// The Swift port models that with an optional `CpContext` argument plus the per-machine
/// defaults (`ChangeLineSM.RID.FROM_ANY`, `0.0` for by-value fields), so callers may pass
/// `nil` — e.g. from tests.
public protocol CpContext: AnyObject {
    /// `SharedPreferences.getInt(key, default)` — Android preference int read used by
    /// `ChangeLineSM` / `DeleteLineSM` for the from/to/delete line-type menu ids
    /// (`R.id.*` numeric values, see `ChangeLineSM.RID` / `DeleteLineSM.RID`).
    func getPref(_ key: String, _ defaultValue: Int) -> Int

    /// `PaintCpFragment.getByValueButtonAngleDegText()`: current "Segment by Value" angle
    /// in degrees, `0.0` when the field is empty/unparseable.
    func getByValueButtonAngleDegText() -> Double

    /// `PaintCpFragment.getByValueButtonLengthText()`: current "Segment by Value" length,
    /// `0.0` when the field is empty/unparseable.
    func getByValueButtonLengthText() -> Double

    /// `PaintCpFragment.setByValueButtonAngleDegText(double)`: the angle is displayed with
    /// at most 9 fraction digits in the reference.
    func setByValueButtonAngleDegText(_ value: Double)

    /// `PaintCpFragment.setByValueButtonLengthText(double)`.
    func setByValueButtonLengthText(_ value: Double)
}
