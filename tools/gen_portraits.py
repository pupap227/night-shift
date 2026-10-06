#!/usr/bin/env python3
"""Placeholder portrait generator -> art/characters/<asset_id>.svg

Stylised noir head-and-shoulders portraits: warm key light from the left, cold blue fill
from the right. Each character has its own face shape, hair, age marks and props so the
cards read as different people. Replace any output with a painted PNG of the same asset id.
"""
import math, os

OUT = os.path.join(os.path.dirname(__file__), "..", "art", "characters")
W, H = 200, 240
CX, CY = 100, 112

SKIN = {"light": "#c9a28a", "medium": "#b4876d", "olive": "#a7806a", "pale": "#d2b3a0", "ruddy": "#bf8f78"}


def head_points(rx, ry, jaw, chin_sq, cx=CX, cy=CY, n=72):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        s, c = math.sin(t), math.cos(t)
        k = 1.0
        if s > 0:  # lower half narrows toward the chin
            k = 1 - jaw * (s ** (2.0 - chin_sq))
        y = cy + ry * s * (1.04 if s > 0 else 1.0)
        pts.append((cx + rx * c * k, y))
    return pts


def path_from(pts, close=True):
    d = "M %.1f %.1f " % pts[0] + " ".join("L %.1f %.1f" % p for p in pts[1:])
    return d + (" Z" if close else "")


def shade(hex_color, f):
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    if f < 0:
        r, g, b = (int(v * (1 + f)) for v in (r, g, b))
    else:
        r, g, b = (int(v + (255 - v) * f) for v in (r, g, b))
    return "#%02x%02x%02x" % (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))


def portrait(p):
    skin = SKIN[p["skin"]]
    rx, ry = p.get("rx", 35), p.get("ry", 45)
    jaw, chin_sq = p.get("jaw", 0.25), p.get("chin_sq", 0.6)
    hair = p.get("hair_color", "#2b2420")
    sh = p.get("shoulders", 1.0)
    accent = p.get("accent", "#6f9fc8")
    head = path_from(head_points(rx, ry, jaw, chin_sq))
    o = []
    o.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
    o.append(f'''<defs>
<radialGradient id="bg" cx="0.42" cy="0.38" r="0.75"><stop offset="0" stop-color="#28323e"/><stop offset="0.6" stop-color="#141a22"/><stop offset="1" stop-color="#090c10"/></radialGradient>
<radialGradient id="rim" cx="0.95" cy="0.2" r="0.7"><stop offset="0" stop-color="{accent}" stop-opacity="0.32"/><stop offset="1" stop-color="{accent}" stop-opacity="0"/></radialGradient>
<linearGradient id="shadow" x1="0" y1="0" x2="1" y2="0"><stop offset="0.38" stop-color="#0c1422" stop-opacity="0"/><stop offset="0.72" stop-color="#0c1422" stop-opacity="0.5"/><stop offset="1" stop-color="#0a101c" stop-opacity="0.7"/></linearGradient>
<linearGradient id="key" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffd9a8" stop-opacity="0.22"/><stop offset="0.45" stop-color="#ffd9a8" stop-opacity="0"/></linearGradient>
<linearGradient id="bodyshade" x1="0" y1="0" x2="1" y2="0"><stop offset="0.3" stop-color="#05080d" stop-opacity="0"/><stop offset="1" stop-color="#05080d" stop-opacity="0.6"/></linearGradient>
<linearGradient id="floor" x1="0" y1="0" x2="0" y2="1"><stop offset="0.7" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.55"/></linearGradient>
<clipPath id="headclip"><path d="{head}"/></clipPath>
</defs>''')
    o.append(f'<rect width="{W}" height="{H}" fill="url(#bg)"/><rect width="{W}" height="{H}" fill="url(#rim)"/>')
    # Back hair (behind head)
    if p.get("back_hair"):
        o.append(p["back_hair"].format(hair=hair, dark=shade(hair, -0.3)))
    # Body
    body = f"M 0 240 L 0 {212 - 8 * (sh - 1):.0f} C {22 - 10 * (sh - 1):.0f} 190 {58 - 12 * (sh - 1):.0f} 179 82 171 L 118 171 C {142 + 12 * (sh - 1):.0f} 179 {178 + 10 * (sh - 1):.0f} 190 200 {212 - 8 * (sh - 1):.0f} L 200 240 Z"
    cloth = p["cloth"]
    o.append(f'<path d="{body}" fill="{cloth}"/>')
    o.append(p.get("outfit", "").format(cloth=cloth, dark=shade(cloth, -0.35), light=shade(cloth, 0.2), accent=accent))
    o.append(f'<path d="{body}" fill="url(#bodyshade)"/>')
    # Neck
    neck_w = p.get("neck", 17)
    o.append(f'<path d="M {CX - neck_w} 140 L {CX - neck_w + 1} 176 Q {CX} 186 {CX + neck_w - 1} 176 L {CX + neck_w} 140 Z" fill="{shade(skin, -0.28)}"/>')
    o.append(f'<path d="M {CX - neck_w} 150 Q {CX} 166 {CX + neck_w} 150 L {CX + neck_w} 140 L {CX - neck_w} 140 Z" fill="#000" opacity="0.25"/>')
    o.append(p.get("collar", "").format(cloth=cloth, dark=shade(cloth, -0.35), light=shade(cloth, 0.25), accent=accent))
    # Ears
    for side in (-1, 1):
        ex = CX + side * (rx - 2)
        o.append(f'<ellipse cx="{ex:.1f}" cy="{CY + 2}" rx="7" ry="11" fill="{shade(skin, -0.12 if side < 0 else -0.4)}"/>')
    # Head
    o.append(f'<path d="{head}" fill="{skin}"/>')
    o.append('<g clip-path="url(#headclip)">')
    # Cheek / jaw shading
    o.append(f'<ellipse cx="{CX}" cy="{CY + ry * 0.95:.0f}" rx="{rx * 0.9:.0f}" ry="16" fill="#000" opacity="0.16"/>')
    if p.get("stubble"):
        o.append(f'<path d="M {CX - rx} {CY + 12} Q {CX - rx * 0.6} {CY + ry + 6} {CX} {CY + ry + 6} Q {CX + rx * 0.6} {CY + ry + 6} {CX + rx} {CY + 12} L {CX + rx} {CY + 70} L {CX - rx} {CY + 70} Z" fill="#2a2522" opacity="{p["stubble"]}"/>')
        o.append(f'<ellipse cx="{CX}" cy="{CY + 32}" rx="13" ry="7" fill="{skin}" opacity="0.55"/>')
    o.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#key)"/>')
    o.append(f'<rect x="{CX - rx}" y="0" width="{rx * 2}" height="{H}" fill="url(#shadow)"/>')
    o.append('</g>')
    # Eyes
    ey = CY - 4 + p.get("eye_dy", 0)
    gap = p.get("eye_gap", 15)
    lid = "#1c1512"
    for side in (-1, 1):
        ex = CX + side * gap
        sc = 0.75 if side > 0 else 1.0
        o.append(f'<path d="M {ex - 7} {ey} Q {ex} {ey - 4.5} {ex + 7} {ey} Q {ex} {ey + 3} {ex - 7} {ey} Z" fill="{shade("#d8d2c8", -0.15 if side < 0 else -0.45)}"/>')
        o.append(f'<circle cx="{ex + p.get("look", 0)}" cy="{ey - 0.5}" r="2.6" fill="#1a1512"/>')
        o.append(f'<path d="M {ex - 7.5} {ey + 0.3} Q {ex} {ey - 5.3} {ex + 7.5} {ey + 0.3}" fill="none" stroke="{lid}" stroke-width="{p.get("lid_w", 1.8)}" stroke-linecap="round"/>')
        if p.get("heavy_lids"):
            o.append(f'<path d="M {ex - 7.5} {ey - 1} Q {ex} {ey - 5} {ex + 7.5} {ey - 1} L {ex + 7.5} {ey - 3.5} Q {ex} {ey - 7.5} {ex - 7.5} {ey - 3.5} Z" fill="{shade(skin, -0.25)}" opacity="0.8"/>')
        if p.get("bags"):
            o.append(f'<path d="M {ex - 6} {ey + 4} Q {ex} {ey + 7.5} {ex + 6} {ey + 4}" fill="none" stroke="{shade(skin, -0.4)}" stroke-width="1.4" opacity="{p["bags"]}"/>')
        # Brows
        bt = p.get("brow_tilt", 0) * side
        bw = p.get("brow_w", 3.0)
        by = ey - 10 + p.get("brow_dy", 0)
        o.append(f'<path d="M {ex - 9 * side if False else ex - 9} {by + bt + (1.5 if side < 0 else 0)} Q {ex} {by - 3} {ex + 9} {by - bt + (0 if side < 0 else 1.5)}" fill="none" stroke="{p.get("brow_color", hair)}" stroke-width="{bw}" stroke-linecap="round" opacity="{0.95 * sc}"/>')
    # Nose
    nl = p.get("nose_len", 22)
    nw = p.get("nose_w", 6)
    o.append(f'<path d="M {CX - 3} {ey + nl * 0.45} Q {CX - 4} {ey + nl * 0.75} {CX - nw} {ey + nl} Q {CX} {ey + nl + 4} {CX + nw} {ey + nl}" fill="none" stroke="{shade(skin, -0.42)}" stroke-width="1.4" stroke-linecap="round" opacity="0.7"/>')
    o.append(f'<path d="M {CX + 2} {ey + 4} L {CX + nw + 1} {ey + nl - 1} L {CX + 2} {ey + nl + 2} Z" fill="#0c1422" opacity="0.22"/>')
    # Mouth
    my = ey + nl + p.get("mouth_dy", 15)
    mw = p.get("mouth_w", 12)
    curve = p.get("mouth_curve", 0)
    o.append(f'<path d="M {CX - mw} {my} Q {CX} {my + curve} {CX + mw} {my}" fill="none" stroke="{shade(skin, -0.55)}" stroke-width="2.2" stroke-linecap="round"/>')
    o.append(f'<path d="M {CX - mw * 0.7} {my + 3} Q {CX} {my + 6} {CX + mw * 0.7} {my + 3}" fill="none" stroke="{shade(skin, -0.25)}" stroke-width="1.5" stroke-linecap="round" opacity="0.6"/>')
    if p.get("lips"):
        o.append(f'<path d="M {CX - mw} {my} Q {CX} {my - 3} {CX + mw} {my} Q {CX} {my + 5} {CX - mw} {my} Z" fill="{p["lips"]}" opacity="0.75"/>')
    # Age marks
    age = p.get("age_lines", 0)
    if age >= 1:
        for side in (-1, 1):
            o.append(f'<path d="M {CX + side * 9} {ey + nl - 2} Q {CX + side * 15} {my - 2} {CX + side * (mw + 4)} {my + 5}" fill="none" stroke="{shade(skin, -0.38)}" stroke-width="1.3" opacity="0.7"/>')
    if age >= 2:
        for k in range(3):
            yy = ey - 24 - k * 5
            o.append(f'<path d="M {CX - 16 + k * 2} {yy} Q {CX} {yy - 2} {CX + 16 - k * 2} {yy}" fill="none" stroke="{shade(skin, -0.3)}" stroke-width="1" opacity="0.55"/>')
        for side in (-1, 1):
            o.append(f'<path d="M {CX + side * (gap + 9)} {ey} l {side * 5} -2 M {CX + side * (gap + 9)} {ey + 2} l {side * 5} 2" stroke="{shade(skin, -0.35)}" stroke-width="0.9" opacity="0.6"/>')
    if p.get("scar"):
        o.append(f'<path d="M {CX - gap - 4} {ey - 16} L {CX - gap + 6} {ey - 3}" stroke="{shade(skin, 0.2)}" stroke-width="1.6" opacity="0.8"/>')
    # Moustache / beard
    if p.get("moustache"):
        mc = p.get("moustache_color", hair)
        o.append(f'<path d="M {CX - mw - 3} {my + 1} Q {CX - 6} {my - 9} {CX} {my - 5} Q {CX + 6} {my - 9} {CX + mw + 3} {my + 1} Q {CX} {my - 3} {CX - mw - 3} {my + 1} Z" fill="{mc}"/>')
    # Hair / headwear (front)
    o.append(p.get("hair", "").format(hair=hair, dark=shade(hair, -0.35), light=shade(hair, 0.25), accent=accent, cx=CX, cy=CY))
    if p.get("glasses"):
        g = p["glasses"]
        for side in (-1, 1):
            ex = CX + side * gap
            if g == "round":
                o.append(f'<circle cx="{ex}" cy="{ey}" r="9" fill="#9ab" fill-opacity="0.08" stroke="#15120f" stroke-width="2"/>')
            else:
                o.append(f'<rect x="{ex - 10}" y="{ey - 7}" width="20" height="13" rx="2" fill="#9ab" fill-opacity="0.08" stroke="#15120f" stroke-width="2"/>')
            o.append(f'<path d="M {ex - 5 * side} {ey - 4} l {3 * side} -1" stroke="#fff" stroke-opacity="0.35" stroke-width="1.2"/>')
        o.append(f'<path d="M {CX - gap + 9} {ey - 1} Q {CX} {ey - 4} {CX + gap - 9} {ey - 1}" fill="none" stroke="#15120f" stroke-width="2"/>')
    o.append(p.get("props", "").format(accent=accent, cloth=cloth))
    o.append(f'<rect width="{W}" height="{H}" fill="url(#floor)"/>')
    o.append("</svg>")
    return "\n".join(o)


COAT = '<path d="M 82 171 L 100 236 L 118 171 L 110 171 L 100 200 L 90 171 Z" fill="{dark}"/>' \
       '<path d="M 70 176 L 92 172 L 100 214 L 86 240 L 58 240 Z" fill="{light}" opacity="0.55"/>' \
       '<path d="M 130 176 L 108 172 L 100 214 L 114 240 L 142 240 Z" fill="{dark}" opacity="0.35"/>'
SCRUBS = '<path d="M 84 171 L 100 200 L 116 171" fill="none" stroke="{dark}" stroke-width="3"/>'
STETHO = '<path d="M 76 176 Q 70 210 92 222 M 124 176 Q 134 206 118 222" fill="none" stroke="#1d1f22" stroke-width="3.2" stroke-linecap="round"/><circle cx="104" cy="226" r="5" fill="#8a9095" stroke="#2a2d31" stroke-width="2"/>'
BADGE = '<rect x="126" y="196" width="22" height="13" rx="1" fill="#d8d0bc" opacity="0.85"/><rect x="129" y="199" width="6" height="7" fill="#556"/><path d="M 138 200 h 7 M 138 204 h 5" stroke="#556" stroke-width="1"/>'

CHARACTERS = {
    # Хирург, 47 — grey crop, stubble, heavy tired eyes, scrubs + cap pushed back, mask around neck.
    "doctor_volkov": dict(skin="ruddy", rx=36, ry=46, jaw=0.16, chin_sq=0.9, hair_color="#6d6a66", cloth="#355e5d",
        shoulders=1.15, neck=19, accent="#8fb3c9", stubble=0.5, heavy_lids=True, bags=0.9, age_lines=2,
        brow_tilt=1.5, brow_w=3.4, brow_color="#4a4643", nose_len=24, nose_w=7, mouth_w=12, mouth_curve=1.5,
        outfit=SCRUBS,
        collar='<path d="M 74 168 Q 100 186 126 168 L 128 178 Q 100 198 72 178 Z" fill="#9fb8b4" opacity="0.9"/><path d="M 74 172 Q 100 190 126 172" stroke="#6d8783" stroke-width="1.5" fill="none"/>',
        hair='<path d="M 66 96 Q 64 64 100 60 Q 136 62 135 96 Q 130 80 120 76 Q 100 70 80 76 Q 70 82 66 96 Z" fill="{hair}"/>'
             '<path d="M 68 82 Q 74 52 104 50 Q 132 52 134 80 Q 120 64 100 64 Q 80 64 68 82 Z" fill="#3f6d6b"/>'
             '<path d="M 70 80 Q 100 66 132 79" stroke="#2c4e4c" stroke-width="2" fill="none"/>'),
    # Кардиолог, 39 — dark hair pulled back, sharp brows, lips, stethoscope, white coat.
    "doctor_orlova": dict(skin="pale", rx=32, ry=44, jaw=0.32, chin_sq=0.2, hair_color="#1f1816", cloth="#cfd2d2",
        shoulders=0.92, neck=14, accent="#c98f8f", brow_tilt=-1.5, brow_w=2.6, nose_len=21, nose_w=5,
        mouth_w=10, mouth_curve=-1, lips="#8c5352", age_lines=1, eye_gap=14, look=1,
        back_hair='<ellipse cx="128" cy="92" rx="16" ry="14" fill="{dark}"/>',
        outfit=COAT + STETHO + BADGE,
        collar='<path d="M 86 170 L 100 186 L 114 170" fill="#3c4450"/>',
        hair='<path d="M 67 104 Q 62 62 100 58 Q 140 60 134 104 Q 130 82 118 74 Q 104 68 100 72 Q 94 68 82 74 Q 70 84 67 104 Z" fill="{hair}"/>'
             '<path d="M 100 72 Q 98 64 100 60" stroke="{light}" stroke-width="1" opacity="0.4"/>'),
    # Анестезиолог, 58 — bald top, grey sides, grey moustache, square glasses, coat.
    "doctor_gusev": dict(skin="light", rx=37, ry=45, jaw=0.2, chin_sq=0.5, hair_color="#a9a39b", cloth="#c8cbcb",
        shoulders=1.0, neck=18, accent="#a9b48f", glasses="square", moustache=True, moustache_color="#8f8a84",
        age_lines=2, bags=0.7, brow_tilt=0.5, brow_w=3.2, brow_color="#8f8a84", nose_len=25, nose_w=8,
        mouth_w=11, mouth_curve=2,
        outfit=COAT + BADGE,
        collar='<path d="M 86 170 L 100 186 L 114 170" fill="#e2e2dc"/><path d="M 96 178 L 100 214 L 104 178 L 100 174 Z" fill="#5a3030"/>',
        hair='<path d="M 64 112 Q 62 86 72 74 Q 70 92 72 112 Z" fill="{hair}"/><path d="M 136 112 Q 138 86 128 74 Q 130 92 128 112 Z" fill="{dark}"/>'
             '<ellipse cx="88" cy="70" rx="14" ry="5" fill="#fff" opacity="0.12" transform="rotate(-18 88 70)"/>'),
    # Интерн, 24 — young, messy longer hair, round glasses, coat a bit too big.
    "doctor_petrov": dict(skin="light", rx=33, ry=44, jaw=0.3, chin_sq=0.3, hair_color="#4a3a2c", cloth="#d4d6d6",
        shoulders=0.95, neck=15, accent="#9a9ad0", glasses="round", brow_tilt=-2.5, brow_w=2.4, brow_dy=-1,
        nose_len=20, nose_w=5, mouth_w=10, mouth_curve=-1.5, look=-1,
        outfit=COAT + BADGE,
        collar='<path d="M 86 170 L 100 186 L 114 170" fill="#8aa0b8"/>',
        hair='<path d="M 64 104 Q 56 60 96 52 Q 140 50 138 100 Q 134 84 126 80 L 128 92 Q 118 74 108 76 L 110 86 Q 98 72 86 78 L 86 88 Q 78 78 70 86 Z" fill="{hair}"/>'
             '<path d="M 80 60 Q 96 54 116 58" stroke="{light}" stroke-width="2" fill="none" opacity="0.35"/>'),
    # Старшая медсестра, 44 — hair in bun under a nurse cap, firm mouth, white uniform.
    "nurse_smirnova": dict(skin="medium", rx=35, ry=44, jaw=0.24, chin_sq=0.5, hair_color="#5b3a26", cloth="#d6d8d4",
        shoulders=1.0, neck=16, accent="#d0b48a", brow_tilt=0.5, brow_w=2.6, nose_len=21, nose_w=6,
        mouth_w=11, mouth_curve=0.5, lips="#7e4f45", age_lines=1, bags=0.4,
        back_hair='<circle cx="100" cy="62" r="16" fill="{dark}"/>',
        outfit='<path d="M 84 171 L 100 196 L 116 171" fill="none" stroke="#9a9c98" stroke-width="2"/><path d="M 92 200 h 16" stroke="#9a9c98" stroke-width="2"/>' + BADGE,
        hair='<path d="M 66 104 Q 62 64 100 62 Q 138 64 134 104 Q 128 80 100 78 Q 72 80 66 104 Z" fill="{hair}"/>'
             '<path d="M 70 78 L 74 58 Q 100 48 126 58 L 130 78 Q 100 70 70 78 Z" fill="#e8e8e2"/>'
             '<path d="M 70 78 Q 100 70 130 78" stroke="#a9aaa4" stroke-width="1.5" fill="none"/>'
             '<rect x="96" y="56" width="8" height="12" fill="#b3272c"/><rect x="94" y="58.5" width="12" height="7" fill="#b3272c"/>'
             '<rect x="98.5" y="58" width="3" height="8" fill="#f2e6e6" opacity="0"/>'),
    # Медсестра, 27 — bob haircut, big tired eyes, pale, lighter blue uniform.
    "nurse_lebedeva": dict(skin="pale", rx=32, ry=43, jaw=0.34, chin_sq=0.2, hair_color="#8a6a48", cloth="#a9c3cf",
        shoulders=0.9, neck=13, accent="#8fc9b8", brow_tilt=-2, brow_w=2.2, nose_len=19, nose_w=4.5,
        mouth_w=9, mouth_curve=-0.5, lips="#a06a68", bags=1.0, eye_gap=14,
        outfit='<path d="M 86 171 L 100 194 L 114 171" fill="none" stroke="#7f9aa6" stroke-width="2.5"/>' + BADGE,
        hair='<path d="M 62 140 Q 54 64 100 58 Q 146 64 138 140 L 128 140 Q 132 100 124 84 Q 106 92 84 82 Q 72 96 74 140 Z" fill="{hair}"/>'
             '<path d="M 80 70 Q 100 60 124 70" stroke="{light}" stroke-width="2" fill="none" opacity="0.35"/>'),
    # Санитар, 35 — buzz cut, broad, scar, grey-blue work jacket.
    "orderly_kozlov": dict(skin="medium", rx=38, ry=46, jaw=0.12, chin_sq=1.0, hair_color="#2e2824", cloth="#4b5867",
        shoulders=1.3, neck=22, accent="#a0a8b8", brow_tilt=1.8, brow_w=3.8, nose_len=22, nose_w=8,
        mouth_w=13, mouth_curve=0, scar=True, stubble=0.25, eye_gap=15,
        outfit='<path d="M 70 176 L 92 172 L 96 240 L 60 240 Z" fill="{light}" opacity="0.3"/><path d="M 100 186 L 100 240" stroke="{dark}" stroke-width="2"/>'
               '<circle cx="104" cy="205" r="2" fill="{dark}"/><circle cx="104" cy="225" r="2" fill="{dark}"/>',
        collar='<path d="M 76 168 L 100 182 L 124 168 L 128 178 L 100 196 L 72 178 Z" fill="{dark}"/><path d="M 88 176 L 100 188 L 112 176" fill="#3a3f45"/>',
        hair='<path d="M 63 100 Q 60 62 100 60 Q 140 62 137 100 Q 134 80 100 76 Q 66 80 63 100 Z" fill="{hair}" opacity="0.85"/>'),
    # Охранник, 52 — peaked uniform cap, thick moustache, heavy jaw, navy uniform with patch.
    "guard_tarasov": dict(skin="ruddy", rx=38, ry=46, jaw=0.1, chin_sq=1.0, hair_color="#4c4743", cloth="#26303d",
        shoulders=1.25, neck=21, accent="#b8a07a", moustache=True, moustache_color="#4a4440", age_lines=2,
        bags=0.6, brow_tilt=1.0, brow_w=3.6, nose_len=24, nose_w=8, mouth_w=12, mouth_curve=1, eye_dy=2,
        outfit='<path d="M 46 186 L 78 178 L 76 190 L 44 196 Z" fill="{light}"/><path d="M 154 186 L 122 178 L 124 190 L 156 196 Z" fill="{dark}"/>'
               '<rect x="50" y="200" width="16" height="20" rx="2" fill="#5b4a2a"/><path d="M 53 206 h 10 M 53 211 h 10" stroke="{accent}" stroke-width="1.4"/>',
        collar='<path d="M 82 168 L 100 184 L 118 168 L 120 176 L 100 194 L 80 176 Z" fill="#8a96a2"/><path d="M 97 182 L 100 220 L 103 182 Z" fill="#1a2028"/>',
        hair='<path d="M 62 90 Q 64 60 100 56 Q 136 60 138 90 Z" fill="#1d2530"/>'
             '<path d="M 56 88 Q 100 76 144 88 L 146 94 Q 100 84 54 94 Z" fill="#0f141a"/>'
             '<path d="M 64 92 Q 100 82 136 92 L 134 102 Q 100 94 66 102 Z" fill="#14181e"/>'
             '<circle cx="100" cy="74" r="6" fill="{accent}" opacity="0.9"/><circle cx="100" cy="74" r="2.5" fill="#6b1c1c"/>'
             '<path d="M 62 104 Q 64 112 66 118 M 138 104 Q 136 112 134 118" stroke="{hair}" stroke-width="5" opacity="0.8"/>'),
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k, p in CHARACTERS.items():
        with open(os.path.join(OUT, k + ".svg"), "w") as f:
            f.write(portrait(p))
    print(len(CHARACTERS), "portraits ->", os.path.abspath(OUT))
