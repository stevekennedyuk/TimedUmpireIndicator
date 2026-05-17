#!/usr/bin/env python3
"""
Generate the UmpireClicker app icon (1024x1024 PNG).

Design: a stylised umpire indicator. Four labelled dials in a 2x2 grid:

    BALLS    STRIKES
    OUTS     INNING

The displayed counts (2-1-2-3) imitate a real mid-inning snapshot so the
icon doesn't read as "off / empty" at small sizes.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
OUTPUT = "icon-1024.png"

# Colour palette
NAVY_TOP    = (16, 28, 56)
NAVY_BOTTOM = (8,  18, 38)
RIM_OUTER   = (212, 220, 232)
RIM_INNER   = (60,  78, 108)
DIAL_FACE   = (244, 245, 240)         # ivory plastic dial face
DIAL_SHADE  = (210, 212, 205)         # subtle shading at bottom
NUMBER      = (24,  32,  54)
LABEL       = (96,  110, 138)
PIP_ACTIVE  = (190, 50,  40)          # tiny red pin/tick on each dial

# ---------- canvas ----------
icon = Image.new("RGB", (SIZE, SIZE), NAVY_BOTTOM)
draw = ImageDraw.Draw(icon)

# Vertical gradient background
for y in range(SIZE):
    t = y / (SIZE - 1)
    r = int(NAVY_TOP[0] * (1 - t) + NAVY_BOTTOM[0] * t)
    g = int(NAVY_TOP[1] * (1 - t) + NAVY_BOTTOM[1] * t)
    b = int(NAVY_TOP[2] * (1 - t) + NAVY_BOTTOM[2] * t)
    draw.line([(0, y), (SIZE, y)], fill=(r, g, b))

# Subtle vignette darkening at corners
vignette = Image.new("L", (SIZE, SIZE), 0)
vd = ImageDraw.Draw(vignette)
vd.ellipse([-200, -200, SIZE + 200, SIZE + 200], fill=255)
vignette = vignette.filter(ImageFilter.GaussianBlur(180))
# composite vignette onto icon
icon = Image.composite(icon, Image.new("RGB", (SIZE, SIZE), (0, 0, 0)), vignette)
draw = ImageDraw.Draw(icon)

# ---------- fonts ----------
def font(path, size):
    return ImageFont.truetype(path, size)

NUM_FONT   = font("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 240)
LABEL_FONT = font("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 50)

# ---------- dial layout ----------
# Keep the dials well inside the safe area so the watchOS circular mask
# (and any iOS rounded-rect clip) doesn't clip them.
SAFE_INSET = 110
GAP        = 80
diam       = (SIZE - 2 * SAFE_INSET - GAP) // 2
radius     = diam // 2

# Centres of each dial (TL, TR, BL, BR)
centres = [
    (SAFE_INSET + radius,             SAFE_INSET + radius),
    (SIZE - SAFE_INSET - radius,      SAFE_INSET + radius),
    (SAFE_INSET + radius,             SIZE - SAFE_INSET - radius),
    (SIZE - SAFE_INSET - radius,      SIZE - SAFE_INSET - radius),
]
labels = ["BALLS", "STRIKES", "OUTS", "INNING"]
values = ["2",     "1",       "2",    "3"]

def draw_dial(cx, cy, label, value):
    r = radius
    # Outer chrome rim (slight glow)
    draw.ellipse(
        [cx - r - 16, cy - r - 16, cx + r + 16, cy + r + 16],
        outline=RIM_OUTER, width=10,
    )
    # Dial face
    draw.ellipse(
        [cx - r, cy - r, cx + r, cy + r],
        fill=DIAL_FACE, outline=RIM_INNER, width=6,
    )
    # Subtle bottom-shadow inside the dial
    shade = Image.new("RGBA", (diam, diam), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.ellipse([0, int(diam * 0.45), diam, diam], fill=(*DIAL_SHADE, 70))
    icon.paste(shade, (cx - r, cy - r), shade)

    # Tick marks at 12, 3, 6, 9 o'clock
    for ang_deg in (90, 0, 270, 180):
        import math
        a = math.radians(ang_deg)
        x1 = cx + (r - 18) * math.cos(a)
        y1 = cy - (r - 18) * math.sin(a)
        x2 = cx + (r - 38) * math.cos(a)
        y2 = cy - (r - 38) * math.sin(a)
        draw.line([(x1, y1), (x2, y2)], fill=RIM_INNER, width=5)

    # Label (small caps near the top of the face)
    lb = draw.textbbox((0, 0), label, font=LABEL_FONT)
    lw = lb[2] - lb[0]
    lh = lb[3] - lb[1]
    draw.text((cx - lw // 2, cy - r + 60 - lb[1]),
              label, font=LABEL_FONT, fill=LABEL)

    # Big number, vertically a touch below centre to leave room for the label above
    nb = draw.textbbox((0, 0), value, font=NUM_FONT)
    nw = nb[2] - nb[0]
    nh = nb[3] - nb[1]
    nx = cx - nw // 2 - nb[0]
    ny = cy - nh // 2 - nb[1] + 30
    draw.text((nx, ny), value, font=NUM_FONT, fill=NUMBER)

    # Tiny red pin at the 12-o'clock indicator slot to read as a mechanical dial
    pin_r = 14
    draw.ellipse(
        [cx - pin_r, cy - r + 22 - pin_r, cx + pin_r, cy - r + 22 + pin_r],
        fill=PIP_ACTIVE, outline=(120, 30, 25), width=2,
    )

for centre, lbl, val in zip(centres, labels, values):
    draw_dial(centre[0], centre[1], lbl, val)

# ---------- subtle baseball seam stitch under the dials, just for character ----------
SEAM_Y1 = SIZE // 2 - 4
SEAM_Y2 = SIZE // 2 + 4
# very faint horizontal divider line
draw.line([(SAFE_INSET + 40, SIZE // 2), (SIZE - SAFE_INSET - 40, SIZE // 2)],
          fill=(38, 52, 84), width=4)

icon.save(OUTPUT, "PNG", optimize=True)
print(f"Wrote {OUTPUT} ({icon.size[0]}x{icon.size[1]})")
