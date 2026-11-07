// Port of `com.origamitoolbox.oripa.model.renderdata.GLDataFmOverlap`
// (oripa-port src/js/core/model/renderdata/GLDataFmOverlap.js).
//
// The overlap view needs, per folded face, a triangle fan of the face (vertex type
// 0 = front colour, 1 = back colour), a quad per edge (type 2 = outline) and, optionally,
// a shadow band: an inner ring on the outline (type 3) and an outer ring (type 4) whose
// vertices are pushed out along the vertex normals / bisector. The two "sides" of the model
// are baked into two data sets: sortedFaces (front, z=false) and sortedFacesReverse
// (flipped, z=true) — the renderer picks one.
//
// Java encodings: pointPosition float[], pointType byte[], pointAngleDeg short[] (tenths of
// a degree), drawOrder short[] — plus the reverse* variants.
import Foundation

public final class GLDataFmOverlap {
    public let pointPosition: [Float]
    public let pointType: [UInt8]
    public let pointAngleDeg: [Float]
    public let drawOrder: [Int]
    public let reversePointPosition: [Float]
    public let reversePointType: [UInt8]
    public let reversePointAngleDeg: [Float]
    public let reverseDrawOrder: [Int]

    public init(
        _ pointPosition: [Float],
        _ pointType: [UInt8],
        _ pointAngleDeg: [Float],
        _ drawOrder: [Int],
        _ reversePointPosition: [Float],
        _ reversePointType: [UInt8],
        _ reversePointAngleDeg: [Float],
        _ reverseDrawOrder: [Int]
    ) {
        self.pointPosition = pointPosition
        self.pointType = pointType
        self.pointAngleDeg = pointAngleDeg
        self.drawOrder = drawOrder
        self.reversePointPosition = reversePointPosition
        self.reversePointType = reversePointType
        self.reversePointAngleDeg = reversePointAngleDeg
        self.reverseDrawOrder = reverseDrawOrder
    }

    // MARK: - helpers

    private static func faceVertexType(_ face: OriFace, _ z: Bool) -> Int {
        let isCCW = face.isCCWOrientation
        return ((z || !isCCW) && (!z || isCCW)) ? 1 : 0
    }

    private static func angleDegTen(_ x: Double, _ y: Double) -> Int {
        jsTruncate(atan2(y, x) * 180 / Double.pi * 10)
    }

    private struct OneSide {
        var pointPosition: [Float]
        var pointType: [UInt8]
        var pointAngleDeg: [Float]
        var drawOrder: [Int]
    }

    // MARK: - no shadow pass

    private static func getDataOneSideNoShadow(_ faces: [OriFace], _ z: Bool, _ from: Int, _ to: Int) -> OneSide {
        var halfEdgeCount = 0
        var triangleCount = 0
        for i in from..<to {
            let n = faces[i].halfEdges.count
            triangleCount += (n - 2) * 3
            halfEdgeCount += n
        }
        let vertexCount = halfEdgeCount * 5
        var pointPosition = [Float](repeating: 0, count: vertexCount * 2)
        var pointAngleDeg = [Float](repeating: 0, count: vertexCount)
        var pointType = [UInt8](repeating: 0, count: vertexCount)
        var drawOrder = [Int](repeating: 0, count: triangleCount + halfEdgeCount * 6)
        var cursor = 0
        var di = 0
        for i in from..<to {
            let face = faces[i]
            let edges = face.halfEdges
            let n = edges.count
            let isCCW = face.isCCWOrientation
            let vType = UInt8(truncatingIfNeeded: faceVertexType(face, z))
            let ringBase = cursor
            for j in 0..<n {
                let endPoint = edges[j].end.valueAfterFold ?? PointDouble(0, 0)
                pointPosition[cursor * 2] = Float(endPoint.x)
                pointPosition[cursor * 2 + 1] = Float(endPoint.y)
                pointAngleDeg[cursor] = 0
                pointType[cursor] = vType
                if j >= 2 {
                    drawOrder[di] = ringBase; di += 1
                    drawOrder[di] = isCCW ? cursor - 1 : cursor; di += 1
                    drawOrder[di] = isCCW ? cursor : cursor - 1; di += 1
                }
                cursor += 1
            }
            for j in 0..<n {
                let he = edges[j]
                let start = he.start.valueAfterFold ?? PointDouble(0, 0)
                let end = he.end.valueAfterFold ?? PointDouble(0, 0)
                let lineBase = cursor
                pointPosition[lineBase * 2] = Float(start.x)
                pointPosition[lineBase * 2 + 1] = Float(start.y)
                pointPosition[(lineBase + 1) * 2] = Float(end.x)
                pointPosition[(lineBase + 1) * 2 + 1] = Float(end.y)
                pointPosition[(lineBase + 2) * 2] = Float(end.x)
                pointPosition[(lineBase + 2) * 2 + 1] = Float(end.y)
                pointPosition[(lineBase + 3) * 2] = Float(start.x)
                pointPosition[(lineBase + 3) * 2 + 1] = Float(start.y)
                let angle = atan2(end.y - start.y, end.x - start.x)
                let degMinus = angleDegTen(cos(angle - Double.pi / 2), sin(angle - Double.pi / 2))
                let degPlus = angleDegTen(cos(angle + Double.pi / 2), sin(angle + Double.pi / 2))
                pointAngleDeg[lineBase] = Float(degMinus)
                pointAngleDeg[lineBase + 1] = Float(degMinus)
                pointAngleDeg[lineBase + 2] = Float(degPlus)
                pointAngleDeg[lineBase + 3] = Float(degPlus)
                for k in 0..<4 { pointType[lineBase + k] = 2 }
                drawOrder[di] = lineBase; di += 1
                drawOrder[di] = lineBase + 1; di += 1
                drawOrder[di] = lineBase + 2; di += 1
                drawOrder[di] = lineBase; di += 1
                drawOrder[di] = lineBase + 2; di += 1
                drawOrder[di] = lineBase + 3; di += 1
                cursor += 4
            }
        }
        return OneSide(pointPosition: pointPosition, pointType: pointType,
                       pointAngleDeg: pointAngleDeg, drawOrder: drawOrder)
    }

    // MARK: - with shadow pass

    private static func getDataOneSideWithShadow(_ faces: [OriFace], _ z: Bool, _ from: Int, _ to: Int) -> OneSide {
        var halfEdgeCount = 0
        var triangleCount = 0
        for i in from..<to {
            let n = faces[i].halfEdges.count
            triangleCount += (n - 2) * 3
            halfEdgeCount += n
        }
        let shadowVertexCount = halfEdgeCount * 4
        let lineVertexCount = halfEdgeCount * 4
        let vertexCount = halfEdgeCount + shadowVertexCount + lineVertexCount
        var pointPosition = [Float](repeating: 0, count: vertexCount * 2)
        var pointAngleDeg = [Float](repeating: 0, count: vertexCount)
        var pointType = [UInt8](repeating: 0, count: vertexCount)
        var drawOrder = [Int](repeating: 0, count: triangleCount + halfEdgeCount * 12 + halfEdgeCount * 6)
        var cursor = 0
        var di = 0
        for i in from..<to {
            let face = faces[i]
            let edges = face.halfEdges
            let n = edges.count
            guard n > 0 else { continue }
            let isCCW = face.isCCWOrientation
            let vType = UInt8(truncatingIfNeeded: faceVertexType(face, z))

            // face ring + triangle fan
            let ringBase = cursor
            for j in 0..<n {
                let endPoint = edges[j].end.valueAfterFold ?? PointDouble(0, 0)
                pointPosition[cursor * 2] = Float(endPoint.x)
                pointPosition[cursor * 2 + 1] = Float(endPoint.y)
                pointAngleDeg[cursor] = 0
                pointType[cursor] = vType
                if j >= 2 {
                    drawOrder[di] = ringBase; di += 1
                    drawOrder[di] = isCCW ? cursor - 1 : cursor; di += 1
                    drawOrder[di] = isCCW ? cursor : cursor - 1; di += 1
                }
                cursor += 1
            }

            // shadow band: 4 verts per edge, all placed on the edge start point;
            // the vertex shader offset (angle) pushes types 3/4 outwards.
            let shadowBase = cursor
            let lastEdge = edges[n - 1]
            let lastStart = lastEdge.start.valueAfterFold ?? PointDouble(0, 0)
            let lastEnd = lastEdge.end.valueAfterFold ?? PointDouble(0, 0)
            var prevAngle = atan2(lastEnd.y - lastStart.y, lastEnd.x - lastStart.x)
            for j in 0..<n {
                let he = edges[j]
                let start = he.start.valueAfterFold ?? PointDouble(0, 0)
                let end = he.end.valueAfterFold ?? PointDouble(0, 0)
                let curAngle = atan2(end.y - start.y, end.x - start.x)
                let refPrev: Double
                let refCur: Double
                if isCCW {
                    refPrev = prevAngle - Double.pi / 2
                    refCur = curAngle - Double.pi / 2
                } else {
                    refPrev = prevAngle + Double.pi / 2
                    refCur = curAngle + Double.pi / 2
                }
                let between = GeomUtil.getAngleRadBetweenLines(
                    0, 0, cos(refPrev), sin(refPrev), 0, 0, cos(refCur), sin(refCur))
                let v = cursor
                pointPosition[v * 2] = Float(start.x)
                pointPosition[v * 2 + 1] = Float(start.y)
                pointPosition[(v + 1) * 2] = Float(start.x)
                pointPosition[(v + 1) * 2 + 1] = Float(start.y)
                pointPosition[(v + 2) * 2] = Float(start.x)
                pointPosition[(v + 2) * 2 + 1] = Float(start.y)
                pointPosition[(v + 3) * 2] = Float(start.x)
                pointPosition[(v + 3) * 2 + 1] = Float(start.y)
                pointAngleDeg[v] = 0
                pointAngleDeg[v + 1] = Float(angleDegTen(cos(refPrev), sin(refPrev)))
                let midRef = isCCW ? refPrev + between / 2 : refPrev - between / 2
                pointAngleDeg[v + 2] = Float(angleDegTen(cos(midRef), sin(midRef)))
                pointAngleDeg[v + 3] = Float(angleDegTen(cos(refCur), sin(refCur)))
                pointType[v] = 3
                pointType[v + 1] = 4
                pointType[v + 2] = 4
                pointType[v + 3] = 4
                let nextStart = (j == n - 1) ? shadowBase : v + 4
                if isCCW {
                    drawOrder[di] = v; di += 1
                    drawOrder[di] = v + 3; di += 1
                    drawOrder[di] = nextStart + 1; di += 1
                    drawOrder[di] = v; di += 1
                    drawOrder[di] = nextStart + 1; di += 1
                    drawOrder[di] = nextStart; di += 1
                    drawOrder[di] = v; di += 1
                    drawOrder[di] = v + 1; di += 1
                    drawOrder[di] = v + 2; di += 1
                    drawOrder[di] = v; di += 1
                    drawOrder[di] = v + 2; di += 1
                    drawOrder[di] = v + 3; di += 1
                } else {
                    drawOrder[di] = v; di += 1
                    drawOrder[di] = nextStart + 1; di += 1
                    drawOrder[di] = v + 3; di += 1
                    drawOrder[di] = v; di += 1
                    drawOrder[di] = nextStart; di += 1
                    drawOrder[di] = nextStart + 1; di += 1
                    drawOrder[di] = v; di += 1
                    drawOrder[di] = v + 2; di += 1
                    drawOrder[di] = v + 1; di += 1
                    drawOrder[di] = v; di += 1
                    drawOrder[di] = v + 3; di += 1
                    drawOrder[di] = v + 2; di += 1
                }
                cursor += 4
                prevAngle = curAngle
            }

            // outline quads
            for j in 0..<n {
                let he = edges[j]
                let s2 = he.start.valueAfterFold ?? PointDouble(0, 0)
                let e2 = he.end.valueAfterFold ?? PointDouble(0, 0)
                let lineBase = cursor
                pointPosition[lineBase * 2] = Float(s2.x)
                pointPosition[lineBase * 2 + 1] = Float(s2.y)
                pointPosition[(lineBase + 1) * 2] = Float(e2.x)
                pointPosition[(lineBase + 1) * 2 + 1] = Float(e2.y)
                pointPosition[(lineBase + 2) * 2] = Float(e2.x)
                pointPosition[(lineBase + 2) * 2 + 1] = Float(e2.y)
                pointPosition[(lineBase + 3) * 2] = Float(s2.x)
                pointPosition[(lineBase + 3) * 2 + 1] = Float(s2.y)
                let angle = atan2(e2.y - s2.y, e2.x - s2.x)
                let degMinus = angleDegTen(cos(angle - Double.pi / 2), sin(angle - Double.pi / 2))
                let degPlus = angleDegTen(cos(angle + Double.pi / 2), sin(angle + Double.pi / 2))
                pointAngleDeg[lineBase] = Float(degMinus)
                pointAngleDeg[lineBase + 1] = Float(degMinus)
                pointAngleDeg[lineBase + 2] = Float(degPlus)
                pointAngleDeg[lineBase + 3] = Float(degPlus)
                for m in 0..<4 { pointType[lineBase + m] = 2 }
                drawOrder[di] = lineBase; di += 1
                drawOrder[di] = lineBase + 1; di += 1
                drawOrder[di] = lineBase + 2; di += 1
                drawOrder[di] = lineBase; di += 1
                drawOrder[di] = lineBase + 2; di += 1
                drawOrder[di] = lineBase + 3; di += 1
                cursor += 4
            }
        }
        return OneSide(pointPosition: pointPosition, pointType: pointType,
                       pointAngleDeg: pointAngleDeg, drawOrder: drawOrder)
    }

    private static func getDataOneSide(_ faces: [OriFace], _ z: Bool, _ withShadow: Bool,
                                       _ from: Int, _ to: Int) -> OneSide {
        withShadow
            ? getDataOneSideWithShadow(faces, z, from, to)
            : getDataOneSideNoShadow(faces, z, from, to)
    }

    // MARK: - public API

    /// `getRenderData(faces, facesReverse, withShadow, from, to)`.
    public static func getRenderData(
        _ faces: [OriFace],
        _ facesReverse: [OriFace],
        _ withShadow: Bool,
        _ from: Int,
        _ to: Int
    ) -> GLDataFmOverlap {
        let front = getDataOneSide(faces, false, withShadow, from, to)
        let reverse = getDataOneSide(facesReverse, true, withShadow, from, to)
        return GLDataFmOverlap(
            front.pointPosition, front.pointType, front.pointAngleDeg, front.drawOrder,
            reverse.pointPosition, reverse.pointType, reverse.pointAngleDeg, reverse.drawOrder)
    }

    /// `getRenderDataSplit(faces, facesReverse, withShadow)` -> 6 data sets
    /// (Android splits into 6 GL shape sets because of 16-bit index buffers).
    public static func getRenderDataSplit(
        _ faces: [OriFace],
        _ facesReverse: [OriFace],
        _ withShadow: Bool
    ) -> [GLDataFmOverlap] {
        let size = min(faces.count, facesReverse.count)
        var result: [GLDataFmOverlap] = []
        for i in 0..<6 {
            let from = (size * i) / 6
            let to = (size * (i + 1)) / 6
            result.append(getRenderData(faces, facesReverse, withShadow, from, to))
        }
        return result
    }

    public static func getRenderDataBlankSplit() -> [GLDataFmOverlap] {
        (0..<6).map { _ in
            GLDataFmOverlap([], [], [], [], [], [], [], [])
        }
    }
}
