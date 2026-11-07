// Port of `com.origamitoolbox.oripa.model.statemachine.CpTransitionResult`
// (oripa-port src/js/core/model/statemachine/CpTransitionResult.js).
//
// Java `byte` result codes returned by `doTransition`/`doLongTransition`. The Swift machines
// return `Int` (contract §5.1) with these raw values; the aliases mirror the Java constant names.
import Foundation

public enum CpTransitionResult: Int, CaseIterable, Sendable {
    case changedPoints = 0
    case changedLines = 1
    case noChange = 2
    case finished = 3

    // MARK: - Java constant names

    public static let CHANGED_LINES = CpTransitionResult.changedLines
    public static let CHANGED_POINTS = CpTransitionResult.changedPoints
    public static let FINISHED = CpTransitionResult.finished
    public static let NO_CHANGE = CpTransitionResult.noChange
}
