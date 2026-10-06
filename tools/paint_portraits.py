#!/usr/bin/env python3
"""Painterly post-process for placeholder portraits: brush blobs, grain, night grade, vignette.
in: raw PNG renders (tools/render_svg.mjs)  out: art/characters/<id>.png (overrides the SVG)."""
import os, sys, random
from PIL import Image, ImageFilter, ImageChops, ImageEnhance
import numpy as np

src, dst = sys.argv[1], sys.argv[2]
for f in sorted(os.listdir(src)):
    if not f.endswith(".png"):
        continue
    im = Image.open(os.path.join(src, f)).convert("RGB")
    w, h = im.size
    paint = im.filter(ImageFilter.ModeFilter(9)).filter(ImageFilter.GaussianBlur(1.6))
    soft = im.filter(ImageFilter.GaussianBlur(2.2))
    img = Image.blend(paint, soft, 0.35)
    img = Image.blend(img, im, 0.28)
    a = np.asarray(img).astype(np.float32) / 255.0
    # Night grade: cool shadows, warm highlights, lifted blacks.
    lum = a.mean(axis=2, keepdims=True)
    shadow = np.array([0.05, 0.09, 0.16])
    warm = np.array([1.06, 0.98, 0.86])
    a = a * (warm * lum + (1 - lum)) + shadow * (1 - lum) * 0.55
    # Brush-stroke texture: directional noise.
    rng = np.random.default_rng(abs(hash(f)) % 2**32)
    n = rng.normal(0, 1, (h // 3, w // 3)).astype(np.float32)
    strokes = np.asarray(Image.fromarray(((n * 0.5 + 0.5).clip(0, 1) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
                         .filter(ImageFilter.GaussianBlur(3)).rotate(28, resample=Image.BICUBIC)).astype(np.float32) / 255.0
    a *= (0.93 + 0.14 * strokes[..., None])
    # Film grain + vignette.
    a += rng.normal(0, 0.028, a.shape).astype(np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w * 0.5) / (w * 0.62)) ** 2 + ((yy - h * 0.42) / (h * 0.62)) ** 2)
    a *= (1.0 - 0.55 * np.clip(d - 0.45, 0, 1))[..., None]
    out = Image.fromarray((a.clip(0, 1) * 255).astype(np.uint8))
    out = ImageEnhance.Contrast(out).enhance(1.08)
    out.save(os.path.join(dst, f), optimize=True)
    print("painted", f)
