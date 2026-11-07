// Render data produced by the grid line generators (the JS reference wraps the same three
// arrays in `GLDataLinesWidth`; this struct keeps them together without depending on the
// render-data package owned by fold-io).
//
// `vertexPosition` is a flat `[x, y]` list: every grid line contributes two vertices
// (start, end), so the renderer draws segment i as
// `pos[2*i] .. pos[2*i+1]` -> `pos[2*i+2] .. pos[2*i+3]`.
// `vertexAngleDeg` is the per-vertex orientation (angle base) in degrees * 100 like the
// Android short[] encoding. `drawOrder` is the triangle index list for GL_LINES.
public struct GridRenderData: Equatable {
    public var vertexPosition: [Float]
    public var vertexAngleDeg: [Int16]
    public var drawOrder: [Int16]

    public init(_ vertexPosition: [Float], _ vertexAngleDeg: [Int16], _ drawOrder: [Int16]) {
        self.vertexPosition = vertexPosition
        self.vertexAngleDeg = vertexAngleDeg
        self.drawOrder = drawOrder
    }
}
