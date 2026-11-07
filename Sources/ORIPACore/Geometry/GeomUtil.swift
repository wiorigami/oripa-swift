// Port of `com.origamitoolbox.oripa.util.GeomUtil` (oripa-port src/js/core/util/GeomUtil.js).
//
// Android imports are replaced with plain Swift: `Point` int keys -> "x,y" strings,
// `android.opengl.Matrix` -> GLUtil, `Log` debug dropped. All math is IEEE-754 double like the
// JS reference (the Java floats are widened at the call sites that cast, e.g. getTransformedLine).
import Foundation

public enum GeomUtil {
    public static let EPS = 5.0e-4
    public static let NUM_PRECISION = 1000
    public static let PI = 3.141592653589793
    public static let TWO_PI = 6.283185307179586
    /// `Math.PI - EPS` literal used by `isParallel`.
    private static let PI_MINUS_EPS = 3.141092653589793

    // MARK: - Small helpers

    /// JS `clamp(i, i2)`: positive modulo.
    public static func clamp(_ i: Int, _ i2: Int) -> Int {
        guard i2 != 0 else { return 0 }
        let r = i % i2
        return r < 0 ? r + i2 : r
    }

    /// JS `constrain(value, min, max)`.
    public static func constrain(_ d: Double, _ d2: Double, _ d3: Double) -> Double {
        max(min(d, d3), d2)
    }

    /// `constrain` for the integer grid loops.
    public static func constrain(_ value: Int, _ d2: Int, _ d3: Int) -> Int {
        max(min(value, d3), d2)
    }

    /// `Math.round(i * d) | 0`.
    public static func getIntKey(_ i: Int, _ d: Double) -> Int {
        JavaMath.roundToInt(Double(i) * d)
    }

    /// `getIntKey(NUM_PRECISION, d)`.
    public static func getDefaultIntKey(_ d: Double) -> Int {
        getIntKey(NUM_PRECISION, d)
    }

    // MARK: - Distances / angles

    public static func getDistance(_ pointDouble: PointDouble, _ pointDouble2: PointDouble) -> Double {
        getDistance(pointDouble.x, pointDouble.y, pointDouble2.x, pointDouble2.y)
    }

    public static func getDistance(_ d: Double, _ d2: Double, _ d3: Double, _ d4: Double) -> Double {
        sqrt(getDistanceSquared(d, d2, d3, d4))
    }

    public static func getDistanceSquared(_ d: Double, _ d2: Double, _ d3: Double, _ d4: Double) -> Double {
        pow(d3 - d, 2.0) + pow(d4 - d2, 2.0)
    }

    public static func getAngleRadians(_ pointDouble: PointDouble, _ pointDouble2: PointDouble) -> Double {
        getAngleRadians(pointDouble.x, pointDouble.y, pointDouble2.x, pointDouble2.y)
    }

    public static func getAngleRadians(_ d: Double, _ d2: Double, _ d3: Double, _ d4: Double) -> Double {
        atan2(d4 - d2, d3 - d)
    }

    public static func getDotProductLines2D(
        _ d: Double, _ d2: Double, _ d3: Double, _ d4: Double,
        _ d5: Double, _ d6: Double, _ d7: Double, _ d8: Double
    ) -> Double {
        ((d3 - d) * (d7 - d5)) + ((d4 - d2) * (d8 - d6))
    }

    public static func getAngleRadBetweenLines(
        _ d: Double, _ d2: Double, _ d3: Double, _ d4: Double,
        _ d5: Double, _ d6: Double, _ d7: Double, _ d8: Double
    ) -> Double {
        acos(constrain(
            getDotProductLines2D(d, d2, d3, d4, d5, d6, d7, d8)
                / (getDistance(d, d2, d3, d4) * getDistance(d5, d6, d7, d8)),
            -1.0, 1.0
        ))
    }

    public static func isParallel(_ pointDouble: PointDouble, _ pointDouble2: PointDouble,
                                  _ pointDouble3: PointDouble, _ pointDouble4: PointDouble) -> Bool {
        isParallel(pointDouble.x, pointDouble.y, pointDouble2.x, pointDouble2.y,
                   pointDouble3.x, pointDouble3.y, pointDouble4.x, pointDouble4.y)
    }

    public static func isParallel(
        _ d: Double, _ d2: Double, _ d3: Double, _ d4: Double,
        _ d5: Double, _ d6: Double, _ d7: Double, _ d8: Double
    ) -> Bool {
        let angle = getAngleRadBetweenLines(d, d2, d3, d4, d5, d6, d7, d8)
        return angle < EPS || angle > PI_MINUS_EPS
    }

    // MARK: - Intersections

    public static func getLineIntersect(_ pointDouble: PointDouble, _ pointDouble2: PointDouble,
                                        _ pointDouble3: PointDouble, _ pointDouble4: PointDouble) -> PointDouble? {
        getLineIntersect(pointDouble.x, pointDouble.y, pointDouble2.x, pointDouble2.y,
                         pointDouble3.x, pointDouble3.y, pointDouble4.x, pointDouble4.y)
    }

    public static func getLineIntersect(
        _ d: Double, _ d2: Double, _ d3: Double, _ d4: Double,
        _ d5: Double, _ d6: Double, _ d7: Double, _ d8: Double
    ) -> PointDouble? {
        if isParallel(d, d2, d3, d4, d5, d6, d7, d8) { return nil }
        let d9 = d - d3
        let d10 = d2 - d4
        let d11 = d5 - d7
        let d12 = d6 - d8
        let d13 = (d9 * d12) - (d10 * d11)
        let d14 = (d * d4) - (d2 * d3)
        let d15 = (d5 * d8) - (d6 * d7)
        return PointDouble(((d11 * d14) - (d9 * d15)) / d13, ((d14 * d12) - (d10 * d15)) / d13)
    }

    public static func getSegmentIntersect(_ pointDouble: PointDouble, _ pointDouble2: PointDouble,
                                           _ pointDouble3: PointDouble, _ pointDouble4: PointDouble) -> PointDouble? {
        getSegmentIntersect(pointDouble.x, pointDouble.y, pointDouble2.x, pointDouble2.y,
                            pointDouble3.x, pointDouble3.y, pointDouble4.x, pointDouble4.y)
    }

    public static func getSegmentIntersect(
        _ d: Double, _ d2: Double, _ d3: Double, _ d4: Double,
        _ d5: Double, _ d6: Double, _ d7: Double, _ d8: Double
    ) -> PointDouble? {
        guard let lineIntersect = getLineIntersect(d, d2, d3, d4, d5, d6, d7, d8),
              isInRange(d, d3, lineIntersect.x), isInRange(d2, d4, lineIntersect.y),
              isInRange(d5, d7, lineIntersect.x), isInRange(d6, d8, lineIntersect.y) else {
            return nil
        }
        return lineIntersect
    }

    // MARK: - Perpendicular

    public static func getPerpendicularDistance(_ pointDouble: PointDouble, _ pointDouble2: PointDouble,
                                                _ pointDouble3: PointDouble) -> Double {
        getPerpendicularDistance(pointDouble.x, pointDouble.y, pointDouble2.x, pointDouble2.y,
                                 pointDouble3.x, pointDouble3.y)
    }

    public static func getPerpendicularDistance(
        _ d: Double, _ d2: Double, _ d3: Double, _ d4: Double, _ d5: Double, _ d6: Double
    ) -> Double {
        abs(((((d4 - d2) * d5) - ((d3 - d) * d6)) + (d3 * d2)) - (d4 * d)) / getDistance(d, d2, d3, d4)
    }

    public static func getPerpendicularIntersect(_ pointDouble: PointDouble, _ pointDouble2: PointDouble,
                                                 _ pointDouble3: PointDouble) -> PointDouble {
        getPerpendicularIntersect(pointDouble.x, pointDouble.y, pointDouble2.x, pointDouble2.y,
                                  pointDouble3.x, pointDouble3.y)
    }

    public static func getPerpendicularIntersect(
        _ d: Double, _ d2: Double, _ d3: Double, _ d4: Double, _ d5: Double, _ d6: Double
    ) -> PointDouble {
        let d7 = d3 - d
        let d8 = d4 - d2
        let distanceSquared = (((d5 - d) * d7) + ((d6 - d2) * d8)) / getDistanceSquared(d, d2, d3, d4)
        return PointDouble(d + (d7 * distanceSquared), d2 + (distanceSquared * d8))
    }

    public static func getDistanceBetweenParallel(
        _ d: Double, _ d2: Double, _ d3: Double, _ d4: Double,
        _ d5: Double, _ d6: Double, _ d7: Double, _ d8: Double
    ) -> Double {
        getDistance(
            getPerpendicularIntersect(d, d2, d3, d4, 0.0, 0.0),
            getPerpendicularIntersect(d5, d6, d7, d8, 0.0, 0.0)
        )
    }

    public static func isCollinear(_ pointDouble: PointDouble, _ pointDouble2: PointDouble,
                                   _ pointDouble3: PointDouble, _ pointDouble4: PointDouble) -> Bool {
        isCollinear(pointDouble.x, pointDouble.y, pointDouble2.x, pointDouble2.y,
                    pointDouble3.x, pointDouble3.y, pointDouble4.x, pointDouble4.y)
    }

    public static func isCollinear(
        _ d: Double, _ d2: Double, _ d3: Double, _ d4: Double,
        _ d5: Double, _ d6: Double, _ d7: Double, _ d8: Double
    ) -> Bool {
        isParallel(d, d2, d3, d4, d5, d6, d7, d8)
            && getDistanceBetweenParallel(d, d2, d3, d4, d5, d6, d7, d8) < EPS
    }

    // MARK: - Ranges

    /// `isInRange(max(a, b), min(a, b), value)` with EPS slack.
    public static func isInRange(_ d: Double, _ d2: Double, _ d3: Double) -> Bool {
        d3 <= max(d, d2) + EPS && d3 >= min(d, d2) - EPS
    }

    public static func isInRange(_ pointDouble: PointDouble, _ pointDouble2: PointDouble,
                                 _ pointDouble3: PointDouble) -> Bool {
        isInRange(pointDouble.x, pointDouble2.x, pointDouble3.x)
            && isInRange(pointDouble.y, pointDouble2.y, pointDouble3.y)
    }

    /// `isInRangeInt`: integer ranges have no EPS slack.
    public static func isInRangeInt(_ i: Int, _ i2: Int, _ i3: Int) -> Bool {
        i3 <= max(i, i2) && i3 >= min(i, i2)
    }

    // MARK: - Polygon / triangle helpers

    public static func getDeterminant3x3(_ values: [Double]) -> Double {
        guard values.count == 9 else { return .nan }
        return ((values[0] * ((values[4] * values[8]) - (values[7] * values[5])))
            - (values[3] * ((values[1] * values[8]) - (values[7] * values[2]))))
            + (values[6] * ((values[1] * values[5]) - (values[4] * values[2])))
    }

    public static func isCCW(_ pointDouble: PointDouble, _ pointDouble2: PointDouble,
                             _ pointDouble3: PointDouble) -> Bool {
        getDeterminant3x3([1.0, 1.0, 1.0,
                           pointDouble.x, pointDouble2.x, pointDouble3.x,
                           pointDouble.y, pointDouble2.y, pointDouble3.y]) >= -EPS
    }

    public static func getIncenter(_ pointDouble: PointDouble, _ pointDouble2: PointDouble,
                                   _ pointDouble3: PointDouble) -> PointDouble {
        let distance = getDistance(pointDouble, pointDouble2)
            + getDistance(pointDouble2, pointDouble3)
            + getDistance(pointDouble3, pointDouble)
        let d2 = getDistance(pointDouble, pointDouble2) / distance
        let d3 = getDistance(pointDouble2, pointDouble3) / distance
        let d4 = getDistance(pointDouble3, pointDouble) / distance
        let d = d2 + d3 + d4
        return PointDouble(
            (((pointDouble3.x * d2) + (pointDouble.x * d3)) + (pointDouble2.x * d4)) / d,
            (((d2 * pointDouble3.y) + (d3 * pointDouble.y)) + (d4 * pointDouble2.y)) / d
        )
    }

    public static func getPolygonArea(_ list: [PointDouble]) -> Double {
        var area = 0.0
        var size = list.count - 1
        for i in 0..<list.count {
            area += (list[size].x * list[i].y) - (list[i].x * list[size].y)
            size = i
        }
        return area / 2.0
    }

    // MARK: - Origin shapes

    public static func isPointInOriginRectangle(_ pointDouble: PointDouble, _ d: Double,
                                                _ d2: Double, _ d3: Double) -> Bool {
        let d4 = d + d3
        if pointDouble.x >= (-d4) && pointDouble.x <= d4 {
            let d5 = d2 + d3
            if pointDouble.y >= (-d5) && pointDouble.y <= d5 {
                return true
            }
        }
        return false
    }

    public static func isPointInOriginSquare(_ pointDouble: PointDouble, _ d: Double, _ d2: Double) -> Bool {
        isPointInOriginRectangle(pointDouble, d, d, d2)
    }

    public static func isPointOutsideOriginRectangle(_ pointDouble: PointDouble, _ d: Double,
                                                     _ d2: Double, _ d3: Double) -> Bool {
        let d4 = d + d3
        if pointDouble.x >= (-d4) && pointDouble.x <= d4 {
            let d5 = d2 + d3
            if pointDouble.y >= (-d5) && pointDouble.y <= d5 {
                return false
            }
        }
        return true
    }

    public static func isPointOutsideOriginSquare(_ pointDouble: PointDouble, _ d: Double, _ d2: Double) -> Bool {
        isPointOutsideOriginRectangle(pointDouble, d, d, d2)
    }

    public static func isPointInOriginHexagon(_ pointDouble: PointDouble, _ d: Double, _ d2: Double) -> Bool {
        let dSqrt = d * sqrt(3.0)
        return isPointInOriginRectangle(pointDouble, d, dSqrt / 2.0, d2)
            && abs(pointDouble.y) <= (((-sqrt(3.0)) * abs(pointDouble.x)) + dSqrt) + (d2 * 2.0)
    }

    // MARK: - Convex polygon / polygon crossing tests

    public static func isPointInConvexPolygon(_ i: Int, _ z: Bool, _ pointDouble: PointDouble,
                                              _ pointDouble2: PointDouble,
                                              _ pointDoubleArr: [PointDouble]) -> Bool {
        var hashSet = Set<String>()
        var length = pointDoubleArr.count - 1
        for i2 in 0..<pointDoubleArr.count {
            let pointDouble3 = pointDoubleArr[length]
            let pointDouble4 = pointDoubleArr[i2]
            if getDistance(pointDouble4, pointDouble) < EPS
                || getPerpendicularDistance(pointDouble3, pointDouble4, pointDouble) < EPS {
                return false
            }
            let segmentIntersect = getSegmentIntersect(pointDouble3, pointDouble4, pointDouble, pointDouble2)
            if let segmentIntersect {
                if getDistance(pointDouble4, segmentIntersect) < EPS {
                    let pointDouble5 = pointDoubleArr[clamp(i2 + 1, pointDoubleArr.count)]
                    if z || !isCollinear(pointDouble3, pointDouble4, pointDouble4, pointDouble5) {
                        return false
                    }
                }
                if getDistance(pointDouble3, segmentIntersect) < EPS {
                    let pointDouble6 = pointDoubleArr[clamp(length - 1, pointDoubleArr.count)]
                    if z || !isCollinear(pointDouble6, pointDouble3, pointDouble3, pointDouble4) {
                        return false
                    }
                }
                hashSet.insert(String(getIntKey(i, segmentIntersect.x)) + ","
                    + String(getIntKey(i, segmentIntersect.y)))
            }
            length = i2
        }
        return hashSet.count % 2 != 0
    }

    /// Java `doPolygonLinesCross(z, polygon1, polygon2)`.
    public static func doPolygonLinesCross(_ z: Bool, _ pointDoubleArr: [PointDouble],
                                           _ pointDoubleArr2: [PointDouble]) -> Bool {
        var map: [String: PointDouble] = [:]
        var mapOrder: [String] = []
        func setMap(_ point: PointDouble) {
            let key = String(getDefaultIntKey(point.x)) + "," + String(getDefaultIntKey(point.y))
            if map[key] == nil { mapOrder.append(key) }
            map[key] = point
        }
        var i = 1
        var length = pointDoubleArr.count - 1
        var i2 = 0
        while i2 < pointDoubleArr.count {
            let prev = pointDoubleArr[length]
            let cur = pointDoubleArr[i2]
            let prevPrev = pointDoubleArr[clamp(length - i, pointDoubleArr.count)]
            let i3 = i2 + 1
            let next = pointDoubleArr[clamp(i3, pointDoubleArr.count)]
            var length2 = pointDoubleArr2.count - i
            for i4 in 0..<pointDoubleArr2.count {
                let qPrev = pointDoubleArr2[length2]
                let qCur = pointDoubleArr2[i4]
                if !isParallel(prev, cur, qPrev, qCur) {
                    let qPrevPrev = pointDoubleArr2[clamp(length2 - 1, pointDoubleArr2.count)]
                    let qNext = pointDoubleArr2[clamp(i4 + 1, pointDoubleArr2.count)]
                    var allow: Bool
                    if getDistance(cur, qPrev) >= EPS {
                        if getDistance(prev, qCur) >= EPS {
                            if getDistance(cur, qCur) >= EPS {
                                allow = getDistance(prev, qPrev) >= EPS
                                    || ((!isCollinear(prevPrev, prev, qPrev, qCur)
                                        || (!z && isCollinear(prevPrev, prev, prev, cur)))
                                        && (!isCollinear(prev, cur, qPrevPrev, qPrev)
                                            || (!z && isCollinear(qPrevPrev, qPrev, qPrev, qCur))))
                            } else {
                                allow = (!isCollinear(cur, next, qPrev, qCur)
                                    || (!z && isCollinear(prev, cur, cur, next)))
                                    && (!isCollinear(prev, cur, qCur, qNext)
                                        || (!z && isCollinear(qPrev, qCur, qCur, qNext)))
                            }
                        } else {
                            allow = !isCollinear(prevPrev, prev, qCur, qNext)
                                || (!z && (isCollinear(prevPrev, prev, prev, cur)
                                    || isCollinear(qPrev, qCur, qCur, qNext)))
                        }
                    } else {
                        allow = !isCollinear(cur, next, qPrevPrev, qPrev)
                            || (!z && (isCollinear(prev, cur, cur, next)
                                || isCollinear(qPrevPrev, qPrev, qPrev, qCur)))
                    }
                    if allow {
                        let segmentIntersect = getSegmentIntersect(
                            prev.x, prev.y, cur.x, cur.y, qPrev.x, qPrev.y, qCur.x, qCur.y)
                        if let segmentIntersect { setMap(segmentIntersect) }
                    }
                }
                length2 = i4
            }
            length = i2
            i2 = i3
            i = 1
        }
        if mapOrder.count != 2 {
            return mapOrder.count > 2
        }
        let values = mapOrder.map { map[$0]! }
        if getDistance(values[0], values[1]) < EPS {
            return false
        }
        var length3 = pointDoubleArr.count - 1
        var i5 = 0
        var i6 = 1
        var i7 = 0
        while i7 < pointDoubleArr.count {
            if isCollinear(pointDoubleArr[length3], pointDoubleArr[i7], values[i5], values[i6]) {
                var length4 = pointDoubleArr2.count - i6
                var i8 = 0
                while i8 < pointDoubleArr2.count {
                    if isCollinear(pointDoubleArr2[length4], pointDoubleArr2[i8], values[0], values[i6]) {
                        return false
                    }
                    length4 = i8
                    i8 += 1
                    i6 = 1
                }
            }
            length3 = i7
            i6 = 1
            i7 += 1
            i5 = 0
        }
        return true
    }

    // MARK: - Mirror transform

    /// Java `getMirrorTransformMatrix`: 4x4 column-major double[16] mirroring across the line
    /// through `pointDouble` and `pointDouble2`.
    public static func getMirrorTransformMatrix(_ pointDouble: PointDouble,
                                                _ pointDouble2: PointDouble) -> [Double] {
        let center = PointDouble(
            (pointDouble.x + pointDouble2.x) / 2.0,
            (pointDouble.y + pointDouble2.y) / 2.0
        )
        var degrees = atan2(pointDouble2.y - pointDouble.y, pointDouble2.x - pointDouble.x) * 180.0 / PI
        if degrees < 0.0 { degrees += 180.0 }
        let f = 90.0 - degrees
        var matrix = [Double](repeating: 0.0, count: 16)
        GLUtil.setIdentityM(&matrix, 0)
        GLUtil.translateM(&matrix, 0, center.x, center.y, 0.0)
        GLUtil.rotateM(&matrix, 0, f, 0.0, 0.0, -1.0)
        GLUtil.scaleM(&matrix, 0, -1.0, 1.0, 1.0)
        GLUtil.rotateM(&matrix, 0, f, 0.0, 0.0, 1.0)
        GLUtil.translateM(&matrix, 0, -center.x, -center.y, 0.0)
        return matrix
    }

    /// Java `getTransformedLine`: keeps Java's `(float)` casts on the input coordinates.
    public static func getTransformedLine(_ pointDouble: PointDouble, _ pointDouble2: PointDouble,
                                          _ matrix: [Double]) -> Segment<PointDouble> {
        Segment(
            GLUtil.getTransformedPointDouble(matrix, Double(Float(pointDouble.x)), Double(Float(pointDouble.y))),
            GLUtil.getTransformedPointDouble(matrix, Double(Float(pointDouble2.x)), Double(Float(pointDouble2.y)))
        )
    }

    public static func getTransformedLine(_ pointDouble: PointDouble, _ pointDouble2: PointDouble,
                                          _ matrix: [Float]) -> Segment<PointDouble> {
        Segment(
            GLUtil.getTransformedPointDouble(matrix, Float(pointDouble.x), Float(pointDouble.y)),
            GLUtil.getTransformedPointDouble(matrix, Float(pointDouble2.x), Float(pointDouble2.y))
        )
    }
}
