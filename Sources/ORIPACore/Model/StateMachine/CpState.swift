// Port of `com.origamitoolbox.oripa.model.statemachine.CpState`
// (oripa-port src/js/core/model/statemachine/CpState.js).
//
// The picked-object state shared by every tool state machine:
//   * `pointsPicked` — Java `LinkedHashSet<OriPoint>` (insertion ordered in the reference),
//   * `linesPicked`  — Java `HashSet<OriLine>`,
//   * `tempPointPicked` / `tempLinePicked` — the indirect ("tap to confirm") candidate.
import Foundation

public final class CpState {
    /// Java `Set<OriPoint> pointsPicked = new LinkedHashSet()`.
    public let pointsPicked = JavaLinkedSet<OriPoint>()

    /// Java `Set<OriLine> linesPicked = new HashSet()`.
    public let linesPicked = JavaSet<OriLine>()

    /// Java `OriPoint tempPointPicked = null`.
    public var tempPointPicked: OriPoint?

    /// Java `OriLine tempLinePicked = null`.
    public var tempLinePicked: OriLine?

    public init() {}
}
