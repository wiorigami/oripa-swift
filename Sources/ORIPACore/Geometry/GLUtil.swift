// Port of `com.origamitoolbox.oripa.util.GLUtil` (oripa-port src/js/core/util/GLUtil.js).
//
// Android GLES/NIO usage is replaced with pure math:
//  - matrix helpers are exact ports of `android.opengl.Matrix` (column-major `float[16]`).
//    The JS reference keeps the matrix entries in doubles (plain arrays), so this port uses
//    `[Double]` as the canonical matrix type; `[Float]` overloads exist for the render/fold
//    render-data paths that store Android `float[]`/`Float32Array` matrices.
//  - NIO buffer helpers return Swift arrays.
//  - `checkGlError` is a no-op (no GL context).
import Foundation

public enum GLUtil {
    public static let MAX_FACE_SETS = 6
    public static let MAX_LINES_PER_SET = 10922
    public static let MAX_LINE_SETS = 6

    /// No GL context in the port; Android threw on GL errors.
    public static func checkGlError(_ str: String) {}

    // MARK: - Buffer helpers

    public static func getByteBuffer<T: BinaryInteger>(_ values: [T]) -> [UInt8] {
        values.map { UInt8(truncatingIfNeeded: $0) }
    }

    public static func getFloatBuffer<T: BinaryFloatingPoint>(_ values: [T]) -> [Float] {
        values.map { Float($0) }
    }

    public static func getShortBuffer<T: BinaryInteger>(_ values: [T]) -> [Int16] {
        values.map { Int16(truncatingIfNeeded: $0) }
    }

    // MARK: - Matrix primitives ([Double] canonical type)

    public static func setIdentityM(_ matrix: inout [Double], _ offset: Int) {
        for i in 0..<16 { matrix[offset + i] = 0.0 }
        var j = 0
        while j < 16 {
            matrix[offset + j] = 1.0
            j += 5
        }
    }

    /// `android.opengl.Matrix.translateM`: m = m * T(x, y, z).
    public static func translateM(_ matrix: inout [Double], _ offset: Int,
                                  _ x: Double, _ y: Double, _ z: Double) {
        for i in 0..<4 {
            let mi = offset + i
            matrix[12 + mi] += matrix[mi] * x + matrix[4 + mi] * y + matrix[8 + mi] * z
        }
    }

    /// `android.opengl.Matrix.scaleM`: m = m * S(x, y, z).
    public static func scaleM(_ matrix: inout [Double], _ offset: Int,
                              _ x: Double, _ y: Double, _ z: Double) {
        for i in 0..<4 {
            let mi = offset + i
            matrix[mi] *= x
            matrix[4 + mi] *= y
            matrix[8 + mi] *= z
        }
    }

    /// `android.opengl.Matrix.setRotateM`.
    public static func setRotateM(_ rm: inout [Double], _ offset: Int,
                                  _ a: Double, _ x: Double, _ y: Double, _ z: Double) {
        rm[offset + 3] = 0
        rm[offset + 7] = 0
        rm[offset + 11] = 0
        rm[offset + 12] = 0
        rm[offset + 13] = 0
        rm[offset + 14] = 0
        rm[offset + 15] = 1
        let aRad = a * (Double.pi / 180.0)
        let s = sin(aRad)
        let c = cos(aRad)
        var x = x, y = y, z = z
        if x == 1.0 && y == 0.0 && z == 0.0 {
            rm[offset + 5] = c
            rm[offset + 10] = c
            rm[offset + 6] = s
            rm[offset + 9] = -s
            rm[offset + 1] = 0
            rm[offset + 2] = 0
            rm[offset + 4] = 0
            rm[offset + 8] = 0
            rm[offset + 0] = 1
        } else if x == 0.0 && y == 1.0 && z == 0.0 {
            rm[offset + 0] = c
            rm[offset + 10] = c
            rm[offset + 8] = s
            rm[offset + 2] = -s
            rm[offset + 1] = 0
            rm[offset + 4] = 0
            rm[offset + 6] = 0
            rm[offset + 9] = 0
            rm[offset + 5] = 1
        } else if x == 0.0 && y == 0.0 && z == 1.0 {
            rm[offset + 0] = c
            rm[offset + 5] = c
            rm[offset + 1] = s
            rm[offset + 4] = -s
            rm[offset + 2] = 0
            rm[offset + 6] = 0
            rm[offset + 8] = 0
            rm[offset + 9] = 0
            rm[offset + 10] = 1
        } else {
            var len = sqrt(x * x + y * y + z * z)
            if len != 1.0 { len = 1.0 / len }
            x *= len
            y *= len
            z *= len
            let nc = 1.0 - c
            let xy = x * y
            let yz = y * z
            let zx = z * x
            let xs = x * s
            let ys = y * s
            let zs = z * s
            rm[offset + 0] = x * x * nc + c
            rm[offset + 1] = xy * nc + zs
            rm[offset + 2] = zx * nc - ys
            rm[offset + 4] = xy * nc - zs
            rm[offset + 5] = y * y * nc + c
            rm[offset + 6] = yz * nc + xs
            rm[offset + 8] = zx * nc + ys
            rm[offset + 9] = yz * nc - xs
            rm[offset + 10] = z * z * nc + c
        }
    }

    private static func multiply(_ lhs: [Double], _ lhsOffset: Int,
                                 _ rhs: [Double], _ rhsOffset: Int) -> [Double] {
        let a00 = lhs[lhsOffset], a01 = lhs[lhsOffset + 1], a02 = lhs[lhsOffset + 2], a03 = lhs[lhsOffset + 3]
        let a10 = lhs[lhsOffset + 4], a11 = lhs[lhsOffset + 5], a12 = lhs[lhsOffset + 6], a13 = lhs[lhsOffset + 7]
        let a20 = lhs[lhsOffset + 8], a21 = lhs[lhsOffset + 9], a22 = lhs[lhsOffset + 10], a23 = lhs[lhsOffset + 11]
        let a30 = lhs[lhsOffset + 12], a31 = lhs[lhsOffset + 13], a32 = lhs[lhsOffset + 14], a33 = lhs[lhsOffset + 15]

        var result = [Double](repeating: 0.0, count: 16)
        for column in 0..<4 {
            let b0 = rhs[rhsOffset + column * 4]
            let b1 = rhs[rhsOffset + column * 4 + 1]
            let b2 = rhs[rhsOffset + column * 4 + 2]
            let b3 = rhs[rhsOffset + column * 4 + 3]
            let base = column * 4
            result[base] = b0 * a00 + b1 * a10 + b2 * a20 + b3 * a30
            result[base + 1] = b0 * a01 + b1 * a11 + b2 * a21 + b3 * a31
            result[base + 2] = b0 * a02 + b1 * a12 + b2 * a22 + b3 * a32
            result[base + 3] = b0 * a03 + b1 * a13 + b2 * a23 + b3 * a33
        }
        return result
    }

    /// `android.opengl.Matrix.rotateM`: m = m * R(a, x, y, z).
    public static func rotateM(_ matrix: inout [Double], _ offset: Int,
                               _ a: Double, _ x: Double, _ y: Double, _ z: Double) {
        var temp = [Double](repeating: 0.0, count: 16)
        setRotateM(&temp, 0, a, x, y, z)
        let result = multiply(matrix, offset, temp, 0)
        for i in 0..<16 { matrix[offset + i] = result[i] }
    }

    /// `android.opengl.Matrix.multiplyMM`: result = lhs * rhs (column-major 4x4).
    public static func multiplyMM(_ result: inout [Double], _ resultOffset: Int,
                                  _ lhs: [Double], _ lhsOffset: Int,
                                  _ rhs: [Double], _ rhsOffset: Int) {
        let product = multiply(lhs, lhsOffset, rhs, rhsOffset)
        for i in 0..<16 { result[resultOffset + i] = product[i] }
    }

    /// `android.opengl.Matrix.multiplyMV`: resultVec = lhsMat * rhsVec.
    public static func multiplyMV(_ resultVec: inout [Double], _ resultVecOffset: Int,
                                  _ lhsMat: [Double], _ lhsMatOffset: Int,
                                  _ rhsVec: [Double], _ rhsVecOffset: Int) {
        let x = rhsVec[rhsVecOffset]
        let y = rhsVec[rhsVecOffset + 1]
        let z = rhsVec[rhsVecOffset + 2]
        let w = rhsVec[rhsVecOffset + 3]
        let r0 = lhsMat[lhsMatOffset] * x + lhsMat[lhsMatOffset + 4] * y
            + lhsMat[lhsMatOffset + 8] * z + lhsMat[lhsMatOffset + 12] * w
        let r1 = lhsMat[lhsMatOffset + 1] * x + lhsMat[lhsMatOffset + 5] * y
            + lhsMat[lhsMatOffset + 9] * z + lhsMat[lhsMatOffset + 13] * w
        let r2 = lhsMat[lhsMatOffset + 2] * x + lhsMat[lhsMatOffset + 6] * y
            + lhsMat[lhsMatOffset + 10] * z + lhsMat[lhsMatOffset + 14] * w
        let r3 = lhsMat[lhsMatOffset + 3] * x + lhsMat[lhsMatOffset + 7] * y
            + lhsMat[lhsMatOffset + 11] * z + lhsMat[lhsMatOffset + 15] * w
        resultVec[resultVecOffset] = r0
        resultVec[resultVecOffset + 1] = r1
        resultVec[resultVecOffset + 2] = r2
        resultVec[resultVecOffset + 3] = r3
    }

    /// `android.opengl.Matrix.invertM`: returns false (Java) / nil-equivalent when singular.
    @discardableResult
    public static func invertM(_ mInv: inout [Double], _ mInvOffset: Int,
                               _ m: [Double], _ mOffset: Int) -> Bool {
        let a00 = m[mOffset], a01 = m[mOffset + 1], a02 = m[mOffset + 2], a03 = m[mOffset + 3]
        let a10 = m[mOffset + 4], a11 = m[mOffset + 5], a12 = m[mOffset + 6], a13 = m[mOffset + 7]
        let a20 = m[mOffset + 8], a21 = m[mOffset + 9], a22 = m[mOffset + 10], a23 = m[mOffset + 11]
        let a30 = m[mOffset + 12], a31 = m[mOffset + 13], a32 = m[mOffset + 14], a33 = m[mOffset + 15]

        let b00 = a00 * a11 - a01 * a10
        let b01 = a00 * a12 - a02 * a10
        let b02 = a00 * a13 - a03 * a10
        let b03 = a01 * a12 - a02 * a11
        let b04 = a01 * a13 - a03 * a11
        let b05 = a02 * a13 - a03 * a12
        let b06 = a20 * a31 - a21 * a30
        let b07 = a20 * a32 - a22 * a30
        let b08 = a20 * a33 - a23 * a30
        let b09 = a21 * a32 - a22 * a31
        let b10 = a21 * a33 - a23 * a31
        let b11 = a22 * a33 - a23 * a32

        var det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06
        if det == 0.0 { return false }
        det = 1.0 / det

        mInv[mInvOffset] = (a11 * b11 - a12 * b10 + a13 * b09) * det
        mInv[mInvOffset + 1] = (a02 * b10 - a01 * b11 - a03 * b09) * det
        mInv[mInvOffset + 2] = (a31 * b05 - a32 * b04 + a33 * b03) * det
        mInv[mInvOffset + 3] = (a22 * b04 - a21 * b05 - a23 * b03) * det
        mInv[mInvOffset + 4] = (a12 * b08 - a10 * b11 - a13 * b07) * det
        mInv[mInvOffset + 5] = (a00 * b11 - a02 * b08 + a03 * b07) * det
        mInv[mInvOffset + 6] = (a32 * b02 - a30 * b05 - a33 * b01) * det
        mInv[mInvOffset + 7] = (a20 * b05 - a22 * b02 + a23 * b01) * det
        mInv[mInvOffset + 8] = (a10 * b10 - a11 * b08 + a13 * b06) * det
        mInv[mInvOffset + 9] = (a01 * b08 - a00 * b10 - a03 * b06) * det
        mInv[mInvOffset + 10] = (a30 * b04 - a31 * b02 + a33 * b00) * det
        mInv[mInvOffset + 11] = (a21 * b02 - a20 * b04 - a23 * b00) * det
        mInv[mInvOffset + 12] = (a11 * b07 - a10 * b09 - a12 * b06) * det
        mInv[mInvOffset + 13] = (a00 * b09 - a01 * b07 + a02 * b06) * det
        mInv[mInvOffset + 14] = (a31 * b01 - a30 * b03 - a32 * b00) * det
        mInv[mInvOffset + 15] = (a20 * b03 - a21 * b01 + a22 * b00) * det
        return true
    }

    /// `invertM` convenience: returns nil when singular.
    public static func invertMatrix(_ matrix: [Double]) -> [Double]? {
        var inverse = [Double](repeating: 0.0, count: 16)
        return invertM(&inverse, 0, matrix, 0) ? inverse : nil
    }

    // MARK: - Point transforms

    public static func getObjectPointFromWorldPointDouble(_ matrix: [Double],
                                                         _ f: Double, _ f2: Double) -> PointDouble {
        var work = [Double](repeating: 0.0, count: 24)
        work[20] = f
        work[21] = f2
        work[23] = 1.0
        invertM(&work, 4, matrix, 0)
        multiplyMV(&work, 0, work, 4, work, 20)
        return PointDouble(work[0], work[1])
    }

    /// Java returned `android.graphics.PointF`; the port returns `PointDouble` (same x/y data).
    public static func getObjectPointFromWorldPointFloat(_ matrix: [Double],
                                                        _ f: Double, _ f2: Double) -> PointDouble {
        getObjectPointFromWorldPointDouble(matrix, f, f2)
    }

    public static func getObjectPointFromWorldPointFloat(_ matrix: [Float],
                                                        _ f: Float, _ f2: Float) -> PointDouble {
        getObjectPointFromWorldPointDouble(matrix.map { Double($0) }, Double(f), Double(f2))
    }

    public static func getTransformedPointDouble(_ matrix: [Double],
                                                 _ f: Double, _ f2: Double) -> PointDouble {
        var work = [Double](repeating: 0.0, count: 8)
        work[4] = f
        work[5] = f2
        work[7] = 1.0
        multiplyMV(&work, 0, matrix, 0, work, 4)
        return PointDouble(work[0], work[1])
    }

    public static func getTransformedPointDouble(_ matrix: [Float],
                                                 _ f: Float, _ f2: Float) -> PointDouble {
        getTransformedPointDouble(matrix.map { Double($0) }, Double(f), Double(f2))
    }

    // MARK: - Transform composition helpers (used by fold-io)

    public static func rotateTranslateTransformM(_ matrix: inout [Double], _ f: Double,
                                                 _ f2: Double, _ f3: Double,
                                                 _ f4: Double, _ f5: Double) {
        var temp = [Double](repeating: 0.0, count: 16)
        setIdentityM(&temp, 0)
        translateM(&temp, 0, f4 + f2, f5 + f3, 0.0)
        rotateM(&temp, 0, f, 0.0, 0.0, 1.0)
        translateM(&temp, 0, -f2, -f3, 0.0)
        var result = [Double](repeating: 0.0, count: 16)
        multiplyMM(&result, 0, temp, 0, matrix, 0)
        for i in 0..<16 { matrix[i] = result[i] }
    }

    public static func scaleTransformM(_ matrix: inout [Double], _ f: Double, _ f2: Double, _ f3: Double) {
        var temp = [Double](repeating: 0.0, count: 16)
        setIdentityM(&temp, 0)
        translateM(&temp, 0, f2, f3, 0.0)
        scaleM(&temp, 0, f, f, 1.0)
        translateM(&temp, 0, -f2, -f3, 0.0)
        var result = [Double](repeating: 0.0, count: 16)
        multiplyMM(&result, 0, temp, 0, matrix, 0)
        for i in 0..<16 { matrix[i] = result[i] }
    }

    public static func translateTransformM(_ matrix: inout [Double], _ f: Double, _ f2: Double) {
        var temp = [Double](repeating: 0.0, count: 16)
        setIdentityM(&temp, 0)
        translateM(&temp, 0, f, f2, 0.0)
        var result = [Double](repeating: 0.0, count: 16)
        multiplyMM(&result, 0, temp, 0, matrix, 0)
        for i in 0..<16 { matrix[i] = result[i] }
    }
}
