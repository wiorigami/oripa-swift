// `CpContext` adapter over the Android-default `Preferences` + the paint by-value column.
//
// The core tool state machines (ChangeLineSM / DeleteLineSM / AddSegmentByValue*) read the
// Android menu-id preferences and the by-value angle/length text fields through this small
// context object (contract §5.1). In the reference this is `makeStateMachineContext` in
// `oripa-port/src/js/ui/fragments/paint.js`.
import Foundation
import ORIPACore

/// The paint-fragment slice the by-value state machines read/write.
public struct PaintByValueAccessors {
    /// `getByValueButtonAngleDegText()` (parse failure/empty → 0.0).
    public var getAngleDeg: () -> Double
    /// `getByValueButtonLengthText()`.
    public var getLength: () -> Double
    /// `setByValueButtonAngleDegText(double)` (formatted with ≤ 9 fraction digits).
    public var setAngleDeg: (Double) -> Void
    /// `setByValueButtonLengthText(double)`.
    public var setLength: (Double) -> Void

    public init(getAngleDeg: @escaping () -> Double,
                getLength: @escaping () -> Double,
                setAngleDeg: @escaping (Double) -> Void,
                setLength: @escaping (Double) -> Void) {
        self.getAngleDeg = getAngleDeg
        self.getLength = getLength
        self.setAngleDeg = setAngleDeg
        self.setLength = setLength
    }

    /// A detached context used by headless tools/tests (`context == nil` in the JS port
    /// falls back to the same zero values).
    public static let empty = PaintByValueAccessors(getAngleDeg: { 0 },
                                                    getLength: { 0 },
                                                    setAngleDeg: { _ in },
                                                    setLength: { _ in })
}

/// `context` passed to `CpStateMachine.doTransition` / `finish` / `doBatch*Operation`.
public final class EditorCpContext: CpContext {
    private let prefs: Preferences
    public var byValue: PaintByValueAccessors

    public init(prefs: Preferences, byValue: PaintByValueAccessors) {
        self.prefs = prefs
        self.byValue = byValue
    }

    /// `SharedPreferences.getInt(key, default)`; the keys are the `PaintCpFragment.*`
    /// preference names and the defaults are the Java `R.id` menu values.
    ///
    /// The state machines are only driven from the paint screen (main actor), but
    /// `CpContext` is a Foundation-only protocol; the lock-free `assumeIsolated` hop keeps
    /// the read on its owning actor without changing the protocol.
    public func getPref(_ key: String, _ defaultValue: Int) -> Int {
        MainActor.assumeIsolated {
            prefs.int(key, default: defaultValue)
        }
    }

    public func getByValueButtonAngleDegText() -> Double {
        MainActor.assumeIsolated { byValue.getAngleDeg() }
    }

    public func getByValueButtonLengthText() -> Double {
        MainActor.assumeIsolated { byValue.getLength() }
    }

    public func setByValueButtonAngleDegText(_ value: Double) {
        MainActor.assumeIsolated { byValue.setAngleDeg(value) }
    }

    public func setByValueButtonLengthText(_ value: Double) {
        MainActor.assumeIsolated { byValue.setLength(value) }
    }
}
