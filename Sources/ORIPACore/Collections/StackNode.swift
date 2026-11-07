// Port of `com.origamitoolbox.oripa.util.StackNode<E>` (marker interface in Java).
import Foundation

/// Java `StackNode<E>`: `next()` / `setNext(node)` / `value()`.
public protocol StackNode: AnyObject {
    associatedtype Value
    func next() -> Self?
    func setNext(_ stackNode: Self?)
    func value() -> Value
}
