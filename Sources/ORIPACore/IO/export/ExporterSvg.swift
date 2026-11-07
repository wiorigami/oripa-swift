// Port of `src/js/core/io/export/ExporterSvg.js` (Java
// `com.origamitoolbox.oripa.io.export.ExporterSvg`).
//
// Coordinate mapping: cp/fm coordinates [-halfSize, halfSize] -> [0, 1000] px, y is flipped
// the same way as the Java (scaleY has the same formula).
//
// Folded model styles: overlap (front/back colored faces) and xray/wireframe (all faces +
// half edges). Colors are Android ARGB ints converted with `ColorUtil.intToStringRgb`
// (uppercase #RRGGBB).
import Foundation

public enum ExporterSvg {
    private static let SVG_DIMEN = 1000
    private static let ATTRIBUTE_SVG_DIMEN = String(SVG_DIMEN)
    private static let CLASS_BOUNDARY = "bo"
    private static let CLASS_CREASE = "cr"
    private static let CLASS_BACK = "ba"
    private static let CLASS_FRONT = "fr"
    private static let STYLE_FOLD_OVERLAP_POLYGON = "polygon {stroke:%s;stroke-width:2px;} .fr {fill:%s;} .ba {fill:%s;}"
    private static let STYLE_FOLD_XRAY = "polygon {fill:black;opacity:0.05;} line {stroke:black;} ." +
        CLASS_BOUNDARY + " {stroke-width:4;opacity:0.2;} ." + CLASS_CREASE + " {stroke-width:1;opacity:0.15;}"
    private static let STYLE_FOLD_WIRE = "." + CLASS_BOUNDARY + " {stroke:black;stroke-width:4;} ." +
        CLASS_CREASE + " {stroke:gray;stroke-width:1;}"

    private static func abbreviation(_ lineType: Int) -> String {
        LineType.getAbbreviation(lineType) ?? ""
    }

    private static func styleCp() -> String {
        "." + abbreviation(2) + " {stroke:red;stroke-width:2} ." +
            abbreviation(3) + " {stroke:blue;stroke-width:2} ." +
            abbreviation(0) + " {stroke:aqua;stroke-width:1} ." +
            abbreviation(1) + " {stroke:black;stroke-width:4}"
    }

    private static func intToStringRgb(_ color: Int) -> String {
        ColorUtil.intToStringRgb(color)
    }

    private static func scaleX(_ halfSize: Double, _ x: Double) -> Double {
        (((x / halfSize) + 1.0) * Double(SVG_DIMEN)) / 2.0
    }

    private static func scaleY(_ halfSize: Double, _ y: Double) -> Double {
        (((y / halfSize) + 1.0) * Double(SVG_DIMEN)) / 2.0
    }

    private static func startDoc(_ out: inout String) {
        out += "<?xml version='1.0' encoding='UTF-8' standalone='no'?>\n"
        out += "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n"
        out += "<svg version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" " +
            "width=\"" + ATTRIBUTE_SVG_DIMEN + "px\" height=\"" + ATTRIBUTE_SVG_DIMEN + "px\" viewBox=\"0 0 " +
            String(SVG_DIMEN) + " " + String(SVG_DIMEN) + "\">\n"
    }

    private static func endDoc(_ out: inout String) {
        out += "</svg>\n"
    }

    private static func facePoints(_ foldedModel: FoldedModel, _ face: OriFace) -> String {
        var out = ""
        for halfEdge in face.halfEdges {
            guard let point = halfEdge.start.valueAfterFold else { continue }
            out += OripaIO.doubleToString(scaleX(foldedModel.foldedModelHalfSize, point.x)) + "," +
                OripaIO.doubleToString(scaleY(foldedModel.foldedModelHalfSize, point.y)) + " "
        }
        return out
    }

    // MARK: - public API

    public static func getBlank() -> Data {
        var out = ""
        startDoc(&out)
        endDoc(&out)
        return OripaIO.textToBytes(out)
    }

    public static func getCreasePattern(_ creasePattern: CreasePattern) -> Data {
        var out = ""
        startDoc(&out)
        out += "<style type=\"text/css\">" + styleCp() + "</style>"
        let halfSize = Double(creasePattern.creasePatternHalfSize)
        for line in creasePattern.lineMVFB {
            out += "<line class=\"" + abbreviation(line.type().rawValue) + "\" x1=\"" +
                OripaIO.doubleToString(scaleX(halfSize, line.start.x)) + "\" y1=\"" +
                OripaIO.doubleToString(scaleY(halfSize, line.start.y)) + "\" x2=\"" +
                OripaIO.doubleToString(scaleX(halfSize, line.end.x)) + "\" y2=\"" +
                OripaIO.doubleToString(scaleY(halfSize, line.end.y)) + "\"/>"
        }
        endDoc(&out)
        return OripaIO.textToBytes(out)
    }

    public static func getFoldedModelOverlap(
        _ foldedModel: FoldedModel,
        _ flip: Bool,
        _ frontColor: Int,
        _ backColor: Int,
        _ lineColor: Int
    ) -> Data {
        var out = ""
        startDoc(&out)
        let faces = flip ? foldedModel.sortedFacesReverse : foldedModel.sortedFaces
        var style = STYLE_FOLD_OVERLAP_POLYGON
        // JS String#replace with "%s" replaces the first occurrence each time.
        if let range = style.range(of: "%s") {
            style.replaceSubrange(range, with: intToStringRgb(lineColor))
        }
        if let range = style.range(of: "%s") {
            style.replaceSubrange(range, with: intToStringRgb(frontColor))
        }
        if let range = style.range(of: "%s") {
            style.replaceSubrange(range, with: intToStringRgb(backColor))
        }
        out += "<style type=\"text/css\">" + style + "</style>"
        for face in faces {
            let isBack = flip ? face.isCCWOrientation : !face.isCCWOrientation
            out += "<polygon points=\"" + facePoints(foldedModel, face) + "\" class=\"" +
                (isBack ? CLASS_BACK : CLASS_FRONT) + "\"/>"
        }
        endDoc(&out)
        return OripaIO.textToBytes(out)
    }

    public static func getFoldedModelXray(_ foldedModel: FoldedModel, _ wire: Bool) -> Data {
        var out = ""
        startDoc(&out)
        out += "<style type=\"text/css\">" + (wire ? STYLE_FOLD_WIRE : STYLE_FOLD_XRAY) + "</style>"
        if !wire {
            for face in foldedModel.mFaces {
                out += "<polygon points=\"" + facePoints(foldedModel, face) + "\"/>"
            }
        }
        let halfSize = foldedModel.foldedModelHalfSize
        for halfEdge in foldedModel.mHalfEdges {
            guard let start = halfEdge.start.valueAfterFold,
                  let end = halfEdge.end.valueAfterFold else { continue }
            out += "<line class=\"" + (halfEdge.lineType == 1 ? CLASS_BOUNDARY : CLASS_CREASE) + "\" x1=\"" +
                OripaIO.doubleToString(scaleX(halfSize, start.x)) + "\" y1=\"" +
                OripaIO.doubleToString(scaleY(halfSize, start.y)) + "\" x2=\"" +
                OripaIO.doubleToString(scaleX(halfSize, end.x)) + "\" y2=\"" +
                OripaIO.doubleToString(scaleY(halfSize, end.y)) + "\"/>"
        }
        endDoc(&out)
        return OripaIO.textToBytes(out)
    }
}
