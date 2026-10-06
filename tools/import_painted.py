#!/usr/bin/env python3
"""Cuts generated art sheets into game assets.
art/source/gpt_batch_01.png (ChatGPT, 1672x941): top = city map, bottom = two portraits."""
import os
from PIL import Image, ImageFilter, ImageEnhance

ROOT = os.path.join(os.path.dirname(__file__), "..")
src = Image.open(os.path.join(ROOT, "art/source/gpt_batch_01.png")).convert("RGB")

# Map: 1672x567 -> padded with a foggy continuation above/below (so a tall phone screen never
# shows a void), then x2 (sharpened) for zoomed-in views. PAD must match data/map_painted.json "offset".
PAD = 260
core = src.crop((0, 0, 1672, 567))
W, H = core.size
canvas = Image.new("RGB", (W, H + PAD * 2), (6, 9, 14))
top = core.crop((0, 0, W, PAD)).transpose(Image.FLIP_TOP_BOTTOM).filter(ImageFilter.GaussianBlur(14))
bot = core.crop((0, H - PAD, W, H)).transpose(Image.FLIP_TOP_BOTTOM).filter(ImageFilter.GaussianBlur(14))
canvas.paste(top, (0, 0))
canvas.paste(bot, (0, PAD + H))
fog = Image.new("RGB", canvas.size, (6, 9, 14))
mask = Image.new("L", canvas.size, 0)
for y in range(canvas.size[1]):
    if y < PAD:
        a = int(255 * (0.55 + 0.45 * (1 - y / PAD)))
    elif y >= PAD + H:
        a = int(255 * (0.55 + 0.45 * ((y - PAD - H) / PAD)))
    else:
        continue
    mask.paste(a, (0, y, W, y + 1))
canvas = Image.composite(fog, canvas, mask)
canvas.paste(core, (0, PAD))
m = canvas.resize((W * 2, (H + PAD * 2) * 2), Image.LANCZOS)
m = m.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
m.save(os.path.join(ROOT, "art/city/map_night.png"), optimize=True)

def portrait(box, name):
    p = src.crop(box).resize((600, 720), Image.LANCZOS)
    p = p.filter(ImageFilter.UnsharpMask(radius=2, percent=50, threshold=2))
    p = ImageEnhance.Contrast(p).enhance(1.04)
    p.save(os.path.join(ROOT, f"art/characters/{name}.png"), optimize=True)

portrait((290, 572, 597, 941), "doctor_volkov")
portrait((1058, 572, 1365, 941), "doctor_orlova")
print("ok")
