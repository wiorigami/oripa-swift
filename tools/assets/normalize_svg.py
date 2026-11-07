#!/usr/bin/env python3
"""Normalise Android-converted SVG drawables for deterministic rasterisation.

The SVGs in `oripa-port/src/assets/icons/` were converted from the APK's
VectorDrawables.  Two constructs in them break ImageMagick's internal SVG
renderer (MSVG), producing fully transparent PNGs:

1. 8-digit ARGB hex colours (`#AARRGGBB`) which are not valid SVG 1.1 -- the
   renderer silently drops the fill.  Rewritten here as `rgba(r,g,b,a)`.
2. `transform` attributes on groups (`<g transform="translate(...) rotate(...)">`,
   used by the two `*_arrow_drop_right_*` icons).  MSVG ignores the transform and
   the path disappears.  This script composes the transform list and bakes the
   resulting affine matrix into every path's `d` coordinates, then drops the
   attribute.  Only `path` elements are transformed; the icons referenced by the
   app contain no other transformed shape kinds, and an unsupported construct
   fails loudly instead of silently rendering a blank icon.
3. Unresolved `@string/...` path-data references left behind by the APK -> SVG
   conversion (`design_ic_visibility`, `$avd_hide_password__0`,
   `$avd_show_password__0`).  When `ORIPA_SVG_RES_DIR` points at the decoded
   `rev/apktool/res` directory, `@string/name` attribute values are replaced with
   the value from `values/strings.xml` (the vector drawables store their long path
   data in string resources).

Usage:
    ORIPA_SVG_RES_DIR=/path/to/rev/apktool/res \
        python3 normalize_svg.py <input.svg> <output.svg>

Exit status is non-zero when the input cannot be normalised (the caller then
falls back to a different rasteriser).
"""
import math
import os
import re
import sys
import xml.etree.ElementTree as ET

SVG_NS = "http://www.w3.org/2000/svg"

ARG_RE = re.compile(r"#([0-9a-fA-F]{8})\b")
FLOAT = r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"
NUM_RE = re.compile(FLOAT)

IDENTITY = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


class UnsupportedSvg(ValueError):
    """Raised for constructs we cannot safely rewrite."""


# ---------------------------------------------------------------------------
# Affine matrices: (a, b, c, d, e, f) maps (x, y) -> (a*x + c*y + e, b*x + d*y + f)
# ---------------------------------------------------------------------------


def multiply(m1, m2):
    """Return m1 * m2 (apply m2 first, then m1)."""
    a1, b1, c1, d1, e1, f1 = m1
    a2, b2, c2, d2, e2, f2 = m2
    return (
        a1 * a2 + c1 * b2,
        b1 * a2 + d1 * b2,
        a1 * c2 + c1 * d2,
        b1 * c2 + d1 * d2,
        a1 * e2 + c1 * f2 + e1,
        b1 * e2 + d1 * f2 + f1,
    )


def is_identity(m):
    return all(abs(x - y) < 1e-12 for x, y in zip(m, IDENTITY))


def translate(tx, ty):
    return (1.0, 0.0, 0.0, 1.0, tx, ty)


def scale(sx, sy):
    return (sx, 0.0, 0.0, sy, 0.0, 0.0)


def rotate_deg(deg):
    rad = math.radians(deg)
    cos, sin = math.cos(rad), math.sin(rad)
    return (cos, sin, -sin, cos, 0.0, 0.0)


def parse_number_list(text):
    return [float(value) for value in NUM_RE.findall(text)]


def parse_transform(text):
    """Parse an SVG transform list into a single affine matrix."""
    matrix = IDENTITY
    i = 0
    length = len(text)
    while i < length:
        while i < length and text[i] in " \t\r\n,":
            i += 1
        if i >= length:
            break
        open_paren = text.find("(", i)
        if open_paren < 0:
            raise UnsupportedSvg("malformed transform: %r" % text)
        name = text[i:open_paren].strip()
        close_paren = text.find(")", open_paren)
        if close_paren < 0:
            raise UnsupportedSvg("malformed transform: %r" % text)
        args = parse_number_list(text[open_paren + 1:close_paren])
        matrix = multiply(matrix, _transform_matrix(name, args))
        i = close_paren + 1
    return matrix


def _transform_matrix(name, args):
    def need(count, low=1):
        if len(args) < low or len(args) > count:
            raise UnsupportedSvg("transform %s got %d args" % (name, len(args)))

    if name == "matrix":
        if len(args) != 6:
            raise UnsupportedSvg("matrix needs 6 args")
        return tuple(args)
    if name == "translate":
        need(2)
        return translate(args[0], args[1] if len(args) == 2 else 0.0)
    if name == "scale":
        need(2)
        return scale(args[0], args[1] if len(args) == 2 else args[0])
    if name == "rotate":
        need(3)
        if len(args) not in (1, 3):
            raise UnsupportedSvg("rotate needs 1 or 3 args")
        angle = args[0]
        if len(args) == 3:
            cx, cy = args[1], args[2]
            return multiply(multiply(translate(cx, cy), rotate_deg(angle)),
                            translate(-cx, -cy))
        return rotate_deg(angle)
    if name == "skewX":
        need(1)
        return (1.0, 0.0, math.tan(math.radians(args[0])), 1.0, 0.0, 0.0)
    if name == "skewY":
        need(1)
        return (1.0, math.tan(math.radians(args[0])), 0.0, 1.0, 0.0, 0.0)
    raise UnsupportedSvg("unsupported transform function %r" % name)


# ---------------------------------------------------------------------------
# Path data rewriting
# ---------------------------------------------------------------------------

_PARAM_COUNT = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 2, "A": 7}


def tokenize_path(data):
    """Split path data into [(command, [numbers...]), ...] (implicit repeats expanded)."""
    tokens = []
    i = 0
    length = len(data)
    current = None
    while i < length:
        ch = data[i]
        if ch in " \t\r\n,":
            i += 1
            continue
        if ch.isalpha():
            if ch not in "MmLlHhVvCcSsQqTtAaZz":
                raise UnsupportedSvg("unsupported path command %r" % ch)
            current = ch
            i += 1
            numbers = []
            while i < length:
                if data[i].isalpha():
                    break
                match = NUM_RE.match(data, i)
                if not match:
                    if data[i] in " \t\r\n,":
                        i += 1
                        continue
                    raise UnsupportedSvg("bad character in path data: %r" % data[i])
                numbers.append(float(match.group(0)))
                i = match.end()
            tokens.append((current, numbers))
        elif current is None:
            raise UnsupportedSvg("path data does not start with a command")
        else:
            # Implicit repeated command, e.g. "M0 0 10 10" == "M0 0 L10 10".
            numbers = []
            while i < length and not data[i].isalpha():
                match = NUM_RE.match(data, i)
                if not match:
                    if data[i] in " \t\r\n,":
                        i += 1
                        continue
                    raise UnsupportedSvg("bad character in path data: %r" % data[i])
                numbers.append(float(match.group(0)))
                i = match.end()
            tokens.append((current, numbers))
    return tokens


def _fmt(value):
    text = ("%.6f" % value).rstrip("0").rstrip(".")
    if text in ("", "-0", "0"):
        return "0"
    return text


def _transform_point(matrix, x, y):
    a, b, c, d, e, f = matrix
    return (a * x + c * y + e, b * x + d * y + f)


def _emit(command, points):
    return command + " " + " ".join(_fmt(v) for point in points for v in point)


def transform_path(data, matrix):
    """Return `data` with `matrix` baked into every absolute coordinate."""
    tokens = tokenize_path(data)
    out = []
    cur = (0.0, 0.0)
    start = (0.0, 0.0)
    prev_cubic_ctrl = None  # absolute, pre-transform
    prev_quad_ctrl = None   # absolute, pre-transform

    def move_to(point):
        return _emit("M", [_transform_point(matrix, *point)])

    def line_to(point):
        return _emit("L", [_transform_point(matrix, *point)])

    for command, numbers in tokens:
        upper = command.upper()
        relative = command.islower()
        idx = 0
        if upper == "Z":
            out.append("Z")
            cur = start
            prev_cubic_ctrl = prev_quad_ctrl = None
            continue
        count = _PARAM_COUNT[upper]
        if count == 0 or len(numbers) < count:
            raise UnsupportedSvg("path command %r without arguments" % command)
        first_segment = True
        while idx + count <= len(numbers):
            args = numbers[idx:idx + count]
            idx += count
            if upper == "A":
                raise UnsupportedSvg("arc commands under a transform are unsupported")
            if upper == "M":
                point = (args[0], args[1])
                if relative:
                    point = (cur[0] + point[0], cur[1] + point[1])
                if first_segment:
                    out.append(move_to(point))
                    start = point
                else:
                    out.append(line_to(point))
                cur = point
                prev_cubic_ctrl = prev_quad_ctrl = None
            elif upper == "L":
                point = (args[0], args[1])
                if relative:
                    point = (cur[0] + point[0], cur[1] + point[1])
                out.append(line_to(point))
                cur = point
                prev_cubic_ctrl = prev_quad_ctrl = None
            elif upper == "H":
                x = args[0] + (cur[0] if relative else 0.0)
                point = (x, cur[1])
                out.append(line_to(point))
                cur = point
                prev_cubic_ctrl = prev_quad_ctrl = None
            elif upper == "V":
                y = args[0] + (cur[1] if relative else 0.0)
                point = (cur[0], y)
                out.append(line_to(point))
                cur = point
                prev_cubic_ctrl = prev_quad_ctrl = None
            elif upper == "C":
                ctrl1 = (args[0], args[1])
                ctrl2 = (args[2], args[3])
                point = (args[4], args[5])
                if relative:
                    ctrl1 = (cur[0] + ctrl1[0], cur[1] + ctrl1[1])
                    ctrl2 = (cur[0] + ctrl2[0], cur[1] + ctrl2[1])
                    point = (cur[0] + point[0], cur[1] + point[1])
                out.append(_emit("C", [_transform_point(matrix, *ctrl1),
                                       _transform_point(matrix, *ctrl2),
                                       _transform_point(matrix, *point)]))
                prev_cubic_ctrl = ctrl2
                prev_quad_ctrl = None
                cur = point
            elif upper == "S":
                if prev_cubic_ctrl is not None:
                    ctrl1 = (2 * cur[0] - prev_cubic_ctrl[0],
                             2 * cur[1] - prev_cubic_ctrl[1])
                else:
                    ctrl1 = cur
                ctrl2 = (args[0], args[1])
                point = (args[2], args[3])
                if relative:
                    ctrl2 = (cur[0] + ctrl2[0], cur[1] + ctrl2[1])
                    point = (cur[0] + point[0], cur[1] + point[1])
                out.append(_emit("C", [_transform_point(matrix, *ctrl1),
                                       _transform_point(matrix, *ctrl2),
                                       _transform_point(matrix, *point)]))
                prev_cubic_ctrl = ctrl2
                prev_quad_ctrl = None
                cur = point
            elif upper == "Q":
                ctrl = (args[0], args[1])
                point = (args[2], args[3])
                if relative:
                    ctrl = (cur[0] + ctrl[0], cur[1] + ctrl[1])
                    point = (cur[0] + point[0], cur[1] + point[1])
                out.append(_emit("Q", [_transform_point(matrix, *ctrl),
                                       _transform_point(matrix, *point)]))
                prev_quad_ctrl = ctrl
                prev_cubic_ctrl = None
                cur = point
            elif upper == "T":
                if prev_quad_ctrl is not None:
                    ctrl = (2 * cur[0] - prev_quad_ctrl[0],
                            2 * cur[1] - prev_quad_ctrl[1])
                else:
                    ctrl = cur
                point = (args[0], args[1])
                if relative:
                    point = (cur[0] + point[0], cur[1] + point[1])
                out.append(_emit("Q", [_transform_point(matrix, *ctrl),
                                       _transform_point(matrix, *point)]))
                prev_quad_ctrl = ctrl
                prev_cubic_ctrl = None
                cur = point
            first_segment = False
    return " ".join(out)


# ---------------------------------------------------------------------------
# SVG tree rewriting
# ---------------------------------------------------------------------------


def _local_name(tag):
    return tag.rsplit("}", 1)[-1]


def flatten_transforms(element, parent_matrix):
    transform = element.get("transform")
    matrix = parent_matrix
    if transform:
        matrix = multiply(parent_matrix, parse_transform(transform))
        del element.attrib["transform"]
    name = _local_name(element.tag)
    if name == "path":
        if not is_identity(matrix):
            data = element.get("d")
            if not data:
                raise UnsupportedSvg("transformed path without data")
            element.set("d", transform_path(data, matrix))
    elif name in ("svg", "g"):
        for child in element:
            flatten_transforms(child, matrix)
    elif not is_identity(matrix):
        # rect/circle/line/polygon/... under a transform: not needed by the app
        # icon set; refuse rather than silently dropping the shape.
        raise UnsupportedSvg("transformed <%s> elements are unsupported" % name)


STRING_REF_RE = re.compile(r"^@string/([A-Za-z0-9_]+)$")


def load_string_resources():
    """Map of `@string/name` resource names -> string values from the decoded APK."""
    res_dir = os.environ.get("ORIPA_SVG_RES_DIR", "")
    if not res_dir:
        return {}
    strings_path = os.path.join(res_dir, "values", "strings.xml")
    if not os.path.isfile(strings_path):
        sys.stderr.write("normalize_svg: no %s; @string/ refs stay unresolved\n"
                         % strings_path)
        return {}
    with open(strings_path, "r", encoding="utf-8") as handle:
        text = handle.read()
    resources = {}
    for match in re.finditer(r'<string name="([^"]+)"[^>]*>(.*?)</string>', text, re.S):
        resources[match.group(1)] = match.group(2).strip()
    return resources


def resolve_string_refs(root, resources):
    """Replace attribute values of the form `@string/name` with their APK value."""
    if not resources:
        return 0
    resolved = 0
    for element in root.iter():
        for key, value in list(element.attrib.items()):
            if key == "android:pathData":
                continue
            match = STRING_REF_RE.match(value.strip()) if isinstance(value, str) else None
            if not match:
                continue
            replacement = resources.get(match.group(1))
            if replacement is None:
                sys.stderr.write("normalize_svg: unresolved @string/%s\n" % match.group(1))
                continue
            element.set(key, replacement)
            resolved += 1
    return resolved


def repl_argb(match):
    value = match.group(1)
    alpha = int(value[0:2], 16) / 255.0
    red = int(value[2:4], 16)
    green = int(value[4:6], 16)
    blue = int(value[6:8], 16)
    return "rgba(%d,%d,%d,%.4f)" % (red, green, blue, alpha)


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("usage: normalize_svg.py <input.svg> <output.svg>\n")
        return 2
    src, dst = argv[1], argv[2]
    with open(src, "r", encoding="utf-8") as handle:
        data = handle.read()
    data = ARG_RE.sub(repl_argb, data)
    try:
        root = ET.fromstring(data)
        resolve_string_refs(root, load_string_resources())
        flatten_transforms(root, IDENTITY)
    except (ET.ParseError, UnsupportedSvg) as error:
        sys.stderr.write("normalize_svg: cannot normalise %s: %s\n" % (src, error))
        return 1
    ET.register_namespace("", SVG_NS)
    # Drop formatting whitespace so the output is stable if the input is stable.
    with open(dst, "w", encoding="utf-8") as handle:
        handle.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        handle.write(ET.tostring(root, encoding="unicode"))
        handle.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
