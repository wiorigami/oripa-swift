// Port of `com.origamitoolbox.oripa.model.renderdata.GLDataCpPreview`
// (oripa-port src/js/core/model/renderdata/GLDataCpPreview.js).
//
// Java read an .opxc File through LoaderOpxcToGL; the Swift port accepts the same bytes.
import Foundation

public final class GLDataCpPreview {
    public let linePosition: [Float]
    public let lineType: [Int]
    public let minMax: MinMaxFloat

    public init(_ linePosition: [Float], _ lineType: [Int], _ minMax: MinMaxFloat) {
        self.linePosition = linePosition
        self.lineType = lineType
        self.minMax = minMax
    }

    public static func getRenderData(_ data: Data) throws -> GLDataCpPreview {
        var list: [Float] = []
        var list2: [Int] = []
        let minMax = MinMaxFloat()
        try LoaderOpxcToGL.getCreasePattern(data, &list, &list2, minMax)
        return GLDataCpPreview(list, list2, minMax)
    }

    public static func getRenderData(_ text: String) throws -> GLDataCpPreview {
        var list: [Float] = []
        var list2: [Int] = []
        let minMax = MinMaxFloat()
        try LoaderOpxcToGL.getCreasePattern(text, &list, &list2, minMax)
        return GLDataCpPreview(list, list2, minMax)
    }

    public static func getRenderDataBlank() -> GLDataCpPreview {
        GLDataCpPreview([], [], MinMaxFloat.readArray([0, 0, 0, 0]))
    }
}
