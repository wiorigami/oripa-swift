#!/usr/bin/env python3
"""Normalise Android-converted SVG drawables for rasterisation.

Android VectorDrawables converted to SVG can contain 8-digit ARGB hex colours
(#AARRGGBB) which SVG does not define; ImageMagick/QuickLook then drop the fill
(fully transparent icon). Rewrite them as rgba().
"""
import re
import sys

ARG = re.compile(r'#([0-9a-fA-F]{8})\b')
RGBA = re.compile(r'#([0-9a-fA-F]{6})\b')


def repl_argb(m):
    v = m.group(1)
    a = int(v[0:2], 16) / 255.0
    r = int(v[2:4], 16)
    g = int(v[4:6], 16)
    b = int(v[6:8], 16)
    return f'rgba({r},{g},{b},{a:.4f})'


def main():
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, 'r', encoding='utf-8') as f:
        data = f.read()
    data = ARG.sub(repl_argb, data)
    with open(dst, 'w', encoding='utf-8') as f:
        f.write(data)


if __name__ == '__main__':
    main()
