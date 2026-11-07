// Port of `com.origamitoolbox.oripa.model.renderdata.GLDataCpLinesTyped`
// (oripa-port src/js/core/model/renderdata/GLDataCpLinesTyped.js).
//
// Java encodings: lineArray = float[] (x0,y0,x1,y1 per line), typeArray = byte[]
// (two entries per line, as the Java). Swift keeps [Float] / [UInt8].
import Foundation

public final class GLDataCpLinesTyped {
    public let lineArray: [Float]
    public let typeArray: [UInt8]

    public init(_ lineArray: [Float], _ typeArray: [UInt8]) {
        self.lineArray = lineArray
        self.typeArray = typeArray
    }

    /// `getRenderData(Iterable<OriLine>, boolean z, boolean z2)`.
    /// z = include mountain/valley/boundary, z2 = include flat.
    public static func getRenderData(_ lines: [OriLine], _ z: Bool, _ z2: Bool) -> GLDataCpLinesTyped {
        var lineArray: [Float] = []
        var typeArray: [UInt8] = []
        for line in lines {
            let t = line.type().rawValue
            if !z && (t == 2 || t == 3 || t == 1) { continue }
            if !z2 && t == 0 { continue }
            lineArray.append(Float(line.start.x))
            lineArray.append(Float(line.start.y))
            lineArray.append(Float(line.end.x))
            lineArray.append(Float(line.end.y))
            typeArray.append(UInt8(truncatingIfNeeded: t))
            typeArray.append(UInt8(truncatingIfNeeded: t))
        }
        return GLDataCpLinesTyped(lineArray, typeArray)
    }
}
