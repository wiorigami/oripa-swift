// Port of `com.origamitoolbox.oripa.model.creasepattern.grid.GridManager`
// (oripa-port src/js/core/model/creasepattern/grid/GridManager.js).
import Foundation

public final class GridManager {
    private let _boxHalfSideLength: Float
    private var _gridLines: AbstractGridLines
    private var _gridPoints: AbstractGridPoints
    private var _divisionNum = -1
    private var _gridType = GridType.undefined

    public init(_ boxHalfSideLength: Float) {
        self._boxHalfSideLength = boxHalfSideLength
        // Default 4x4 square grid (JS constructor calls update(4, 0)).
        self._gridPoints = GridSquarePoints(4)
        self._gridLines = GridSquareLines(4, boxHalfSideLength)
        try! update(4, GridType.square)
    }

    public func findLine(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriLine> {
        _gridLines.findLine(pointDouble, d)
    }

    public func findPoint(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriPoint> {
        _gridPoints.findPoint(pointDouble, d, Double(_boxHalfSideLength))
    }

    public func getRenderData() -> GridRenderData {
        _gridLines.getRenderData()
    }

    public func getDivisionNumber() -> Int { _divisionNum }
    public func getGridType() -> GridType { _gridType }
    public func getBoxHalfSideLength() -> Float { _boxHalfSideLength }

    /// Java `update(int divisionNumber, byte gridType)`.
    @discardableResult
    public func update(_ divisionNumber: Int, _ gridType: Int) throws -> Bool {
        guard let type = GridType(rawValue: gridType) else {
            throw CoreError.illegalArgument("IllegalArgumentException")
        }
        return try update(divisionNumber, type)
    }

    /// Java `update(int divisionNumber, byte gridType)`.
    @discardableResult
    public func update(_ divisionNumber: Int, _ gridType: GridType) throws -> Bool {
        if divisionNumber < 2 || gridType == .undefined {
            throw CoreError.illegalArgument("IllegalArgumentException")
        }
        if _divisionNum == divisionNumber && _gridType == gridType {
            return false
        }
        _divisionNum = divisionNumber
        _gridType = gridType
        if gridType != .triangle {
            _gridPoints = GridSquarePoints(divisionNumber)
            _gridLines = GridSquareLines(divisionNumber, _boxHalfSideLength)
        } else {
            _gridPoints = GridTrianglePoints(divisionNumber)
            _gridLines = GridTriangleLines(divisionNumber, _boxHalfSideLength)
        }
        return true
    }
}
