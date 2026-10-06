#!/usr/bin/env python3
"""Wraps a phone screenshot in a simple iPhone frame (rounded body, Dynamic Island, home indicator)
so safe-area handling is visible. usage: device_frame.py in.png out.png portrait|landscape"""
import sys
from PIL import Image, ImageDraw

src, dst, orient = sys.argv[1], sys.argv[2], sys.argv[3]
im = Image.open(src).convert("RGB")
w, h = im.size
s = w / (390 if orient == "portrait" else 844)        # px per point
bez = int(14 * s)
W, H = w + bez * 2, h + bez * 2
out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(out)
d.rounded_rectangle([0, 0, W - 1, H - 1], radius=int(62 * s), fill=(18, 18, 22, 255))
mask = Image.new("L", (w, h), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=int(48 * s), fill=255)
out.paste(im, (bez, bez), mask)
if orient == "portrait":
    iw, ih = 126 * s, 37 * s
    d.rounded_rectangle([W / 2 - iw / 2, bez + 11 * s, W / 2 + iw / 2, bez + 11 * s + ih], radius=ih / 2, fill=(0, 0, 0, 255))
    d.rounded_rectangle([W / 2 - 67 * s, H - bez - 13 * s, W / 2 + 67 * s, H - bez - 8 * s], radius=3 * s, fill=(235, 235, 235, 230))
else:
    iw, ih = 37 * s, 126 * s
    d.rounded_rectangle([bez + 11 * s, H / 2 - ih / 2, bez + 11 * s + iw, H / 2 + ih / 2], radius=iw / 2, fill=(0, 0, 0, 255))
    d.rounded_rectangle([W / 2 - 67 * s, H - bez - 10 * s, W / 2 + 67 * s, H - bez - 5 * s], radius=3 * s, fill=(235, 235, 235, 230))
bg = Image.new("RGB", (W + int(40 * s), H + int(40 * s)), (14, 16, 20))
bg.paste(out, (int(20 * s), int(20 * s)), out)
bg.save(dst)
