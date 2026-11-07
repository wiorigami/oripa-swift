// Java `java.util` exceptions used by the ported core (`Error` with the Java exception name in
// the reference JS port). Shipping UI code should not depend on catching these.
import Foundation

public enum CoreError: Error, Equatable, CustomStringConvertible {
    case noSuchElement(String)
    case emptyStack
    case illegalArgument(String)
    case indexOutOfBounds(Int)
    case illegalState(String)

    public static func noSuchElementException() -> CoreError {
        CoreError.noSuchElement("NoSuchElementException")
    }

    public static func illegalArgumentException(_ message: String) -> CoreError {
        CoreError.illegalArgument(message)
    }

    public var description: String {
        switch self {
        case .noSuchElement(let message): return message
        case .emptyStack: return "EmptyStackException"
        case .illegalArgument(let message): return "IllegalArgumentException: " + message
        case .indexOutOfBounds(let index): return "IndexOutOfBoundsException: \(index)"
        case .illegalState(let message): return "IllegalStateException: " + message
        }
    }
}
