// Port of `com.origamitoolbox.oripa.model.statemachine.CpEvent`
// (oripa-port src/js/core/model/statemachine/CpEvent.js).
//
// Java package-private `byte` constants describing the "current event" the state machines
// track internally. Exposed publicly here (as the JS port does) so tests/tools can read the
// constants; the machine implementations use numeric literals in `switch` like the reference.
import Foundation

public enum CpEvent: Int, CaseIterable, Sendable {
    case setTempPoint = 0
    case confirmPoint = 1
    case setTempLine = 2
    case confirmLine = 3
    case finish = 4

    // MARK: - Java constant names

    public static let CONFIRM_LINE = CpEvent.confirmLine
    public static let CONFIRM_POINT = CpEvent.confirmPoint
    public static let FINISH = CpEvent.finish
    public static let SET_TEMP_LINE = CpEvent.setTempLine
    public static let SET_TEMP_POINT = CpEvent.setTempPoint
}
