// Port of `com.origamitoolbox.oripa.util.Stack<E>` (marker interface in Java).
import Foundation

/// Java `Stack<E>` interface: shared contract of `SimpleStack` and `FixedStack`.
public protocol Stack: AnyObject {
    associatedtype Element
    func push(_ e: Element)
    @discardableResult func pop() throws -> Element
    func peek() throws -> Element
    func isEmpty() -> Bool
    func clear()
    func size() -> Int
}
