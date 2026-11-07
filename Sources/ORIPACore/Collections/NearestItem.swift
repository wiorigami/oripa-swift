// Port of `com.origamitoolbox.oripa.util.NearestItem<E>` (oripa-port src/js/core/util/NearestItem.js).
import Foundation

public final class NearestItem<Item> {
    public var nearestItem: Item?
    public var distance: Double

    /// Java `new NearestItem()`: no item, `Double.MAX_VALUE` distance.
    public init() {
        self.nearestItem = nil
        self.distance = Double.greatestFiniteMagnitude
    }

    public init(_ nearestItem: Item?, _ distance: Double) {
        self.nearestItem = nearestItem
        self.distance = distance
    }
}
