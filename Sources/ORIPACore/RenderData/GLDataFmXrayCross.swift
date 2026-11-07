// Port of `com.origamitoolbox.oripa.model.renderdata.GLDataFmXrayCross`
// (oripa-port src/js/core/model/renderdata/GLDataFmXrayCross.js).
//
// Draw data shared by the xray folded-model view and the cross (cut line) view:
// FM face/line geometry + two-color CP panel geometry.
// Java encodings: cpPointPosition float[], cpLineType byte[], cpLineDrawOrder short[],
// cpPolygonDrawOrder short[], fmPointPosition float[], fmFaceDrawOrder short[],
// fmBoundaryLineDrawOrder short[], fmCreaseLineDrawOrder short[].
import Foundation

public final class GLDataFmXrayCross {
    public let cpPointPosition: [Float]
    public let cpLineType: [UInt8]
    public let cpLineDrawOrder: [Int]
    public let cpPolygonDrawOrder: [Int]
    public let fmPointPosition: [Float]
    public let fmFaceDrawOrder: [Int]
    public let fmBoundaryLineDrawOrder: [Int]
    public let fmCreaseLineDrawOrder: [Int]

    public init(
        _ cpPointPosition: [Float],
        _ cpLineType: [UInt8],
        _ cpLineDrawOrder: [Int],
        _ cpPolygonDrawOrder: [Int],
        _ fmPointPosition: [Float],
        _ fmFaceDrawOrder: [Int],
        _ fmBoundaryLineDrawOrder: [Int],
        _ fmCreaseLineDrawOrder: [Int]
    ) {
        self.cpPointPosition = cpPointPosition
        self.cpLineType = cpLineType
        self.cpLineDrawOrder = cpLineDrawOrder
        self.cpPolygonDrawOrder = cpPolygonDrawOrder
        self.fmPointPosition = fmPointPosition
        self.fmFaceDrawOrder = fmFaceDrawOrder
        self.fmBoundaryLineDrawOrder = fmBoundaryLineDrawOrder
        self.fmCreaseLineDrawOrder = fmCreaseLineDrawOrder
    }

    public static func getRenderData(
        _ vertices: [OriVertex],
        _ halfEdges: [OriHalfEdge],
        _ faces: [OriFace]
    ) -> GLDataFmXrayCross {
        // CP panel: 3 copies of every vertex (slot 0/1/2 = boundary/mountain/valley).
        var cpPointPosition = [Float](repeating: 0, count: vertices.count * 2 * 3)
        var cpLineType = [UInt8](repeating: 0, count: vertices.count * 3)
        for (i, vertex) in vertices.enumerated() {
            for j in 0..<3 {
                let p = ((i * 3) + j) * 2
                cpPointPosition[p] = Float(vertex.x)
                cpPointPosition[p + 1] = Float(vertex.y)
            }
            cpLineType[i * 3] = 1
            cpLineType[i * 3 + 1] = 2
            cpLineType[i * 3 + 2] = 3
        }

        // FM panel: one point per vertex (valueAfterFold).
        var fmPointPosition = [Float](repeating: 0, count: vertices.count * 2)
        for (i, vertex) in vertices.enumerated() {
            let folded = vertex.valueAfterFold ?? PointDouble(0, 0)
            fmPointPosition[i * 2] = Float(folded.x)
            fmPointPosition[i * 2 + 1] = Float(folded.y)
        }

        var faceIndexCount = 0
        for face in faces { faceIndexCount += face.halfEdges.count - 2 }
        var cpPolygonDrawOrder = [Int](repeating: 0, count: faceIndexCount * 3)
        var fmFaceDrawOrder = [Int](repeating: 0, count: faceIndexCount * 3)
        var cursor = 0
        for face in faces {
            let n = face.halfEdges.count
            guard n > 0 else { continue }
            let first = face.halfEdges[0].end.index
            if n >= 3 {
                for j in 2..<n {
                    let start = face.halfEdges[j].start.index
                    let end = face.halfEdges[j].end.index
                    cpPolygonDrawOrder[cursor] = first * 3
                    if face.isCCWOrientation {
                        cpPolygonDrawOrder[cursor + 1] = end * 3
                        cpPolygonDrawOrder[cursor + 2] = start * 3
                    } else {
                        cpPolygonDrawOrder[cursor + 1] = start * 3
                        cpPolygonDrawOrder[cursor + 2] = end * 3
                    }
                    fmFaceDrawOrder[cursor] = first
                    fmFaceDrawOrder[cursor + 1] = start
                    fmFaceDrawOrder[cursor + 2] = end
                    cursor += 3
                }
            }
        }

        // Lines: draw each crease once (one of its two half-edges); boundaries once.
        var cpLineDrawOrder: [Int] = []
        var fmBoundaryLineDrawOrder: [Int] = []
        var fmCreaseLineDrawOrder: [Int] = []
        for halfEdge in halfEdges {
            let type = halfEdge.lineType
            let isCCW = halfEdge.face?.isCCWOrientation ?? false
            let include = type == 1 || (isCCW ? type == 2 : type == 3)
            if !include { continue }
            let si = halfEdge.start.index
            let ei = halfEdge.end.index
            cpLineDrawOrder.append(si * 3 + type - 1)
            cpLineDrawOrder.append(ei * 3 + type - 1)
            if type == 1 {
                fmBoundaryLineDrawOrder.append(si)
                fmBoundaryLineDrawOrder.append(ei)
            } else {
                fmCreaseLineDrawOrder.append(si)
                fmCreaseLineDrawOrder.append(ei)
            }
        }

        return GLDataFmXrayCross(cpPointPosition, cpLineType, cpLineDrawOrder, cpPolygonDrawOrder,
                                 fmPointPosition, fmFaceDrawOrder, fmBoundaryLineDrawOrder, fmCreaseLineDrawOrder)
    }
}
