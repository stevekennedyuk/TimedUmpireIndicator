#!/usr/bin/env python3
"""
Android / Wear OS adaptive-icon layers from icon-1024.png (run make_icon.py first).

Adaptive icons are masked to a circle, squircle or square depending on the
launcher, and only the central 66 dp circle of the 108 dp canvas is always
visible. So the four dials go on a transparent foreground layer, scaled to fit
that circle, over a plain navy gradient background layer.

Writes into ../Android/{app,wear}/src/main/res/drawable-nodpi/.
"""

import math
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "icon-1024.png")
OUT_SIZE = 432  # 108 dp at xxxhdpi; nodpi so every density scales from it

# Must match make_icon.py
SIZE, SAFE_INSET, GAP = 1024, 110, 80
DIAM = (SIZE - 2 * SAFE_INSET - GAP) // 2
R = DIAM // 2
RIM = R + 22  # dial face + chrome rim
CENTRES = [
    (SAFE_INSET + R, SAFE_INSET + R), (SIZE - SAFE_INSET - R, SAFE_INSET + R),
    (SAFE_INSET + R, SIZE - SAFE_INSET - R), (SIZE - SAFE_INSET - R, SIZE - SAFE_INSET - R),
]
NAVY_TOP, NAVY_BOTTOM = (16, 28, 56), (8, 18, 38)


def foreground() -> Image.Image:
    icon = Image.open(SRC).convert("RGBA")
    # Anti-aliased mask of the four dials (drawn 4x, then reduced).
    big = Image.new("L", (SIZE * 4, SIZE * 4), 0)
    d = ImageDraw.Draw(big)
    for cx, cy in CENTRES:
        d.ellipse([(cx - RIM) * 4, (cy - RIM) * 4, (cx + RIM) * 4, (cy + RIM) * 4], fill=255)
    icon.putalpha(big.resize((SIZE, SIZE), Image.LANCZOS))

    # Farthest dial edge from the centre must sit inside the 33 dp safe radius.
    far = math.hypot(CENTRES[0][0] - SIZE / 2, CENTRES[0][1] - SIZE / 2) + RIM
    scale = (33 / 54) * (SIZE / 2) / far * 0.98
    art = icon.resize((round(SIZE * scale), round(SIZE * scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.paste(art, ((SIZE - art.width) // 2, (SIZE - art.height) // 2), art)
    return canvas.resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)


def background() -> Image.Image:
    bg = Image.new("RGB", (OUT_SIZE, OUT_SIZE))
    d = ImageDraw.Draw(bg)
    for y in range(OUT_SIZE):
        t = y / (OUT_SIZE - 1)
        d.line([(0, y), (OUT_SIZE, y)], fill=tuple(int(a * (1 - t) + b * t) for a, b in zip(NAVY_TOP, NAVY_BOTTOM)))
    return bg


if __name__ == "__main__":
    fg, bg = foreground(), background()
    for module in ("app", "wear"):
        out = os.path.join(HERE, "..", "Android", module, "src", "main", "res", "drawable-nodpi")
        os.makedirs(out, exist_ok=True)
        fg.save(os.path.join(out, "ic_launcher_foreground.png"), optimize=True)
        bg.save(os.path.join(out, "ic_launcher_background.png"), optimize=True)
        print("Wrote", os.path.normpath(out))
    # A preview of the icon as a circle-masked launcher would show it.
    preview = bg.convert("RGBA")
    preview.alpha_composite(fg)
    mask = Image.new("L", (OUT_SIZE, OUT_SIZE), 0)
    m = OUT_SIZE / 108
    ImageDraw.Draw(mask).ellipse([18 * m, 18 * m, 90 * m, 90 * m], fill=255)
    preview.putalpha(mask)
    preview.crop((int(18 * m), int(18 * m), int(90 * m), int(90 * m))).save(os.path.join(HERE, "android-preview-round.png"))
