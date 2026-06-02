#!/usr/bin/env python3
"""
Generate App Store Connect marketing screenshots for UmpireClicker at the
exact required pixel dimensions:

    iPhone 6.5"      1242 x 2688
    iPad 13"         2064 x 2752
    Apple Watch       422 x  514

Output is opaque RGB PNG (no alpha), written next to this script in
./screenshots/. Requires Pillow (the same dependency icon-source/make_icon.py
uses):  pip3 install pillow

Fonts resolve automatically: Arial/Helvetica on macOS, DejaVu on Linux.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "screenshots")
os.makedirs(OUTDIR, exist_ok=True)

# ---------- palette (matches the app icon) ----------
NAVY_TOP    = (16, 28, 56)
NAVY_BOTTOM = (8, 18, 38)
CARD_TOP    = (20, 34, 66)
CARD_BOT    = (12, 22, 44)
IVORY       = (244, 245, 240)
DIAL_SHADE  = (214, 216, 209)
NUMBER      = (24, 32, 54)
LABEL_GREY  = (150, 165, 195)
DIM_GREY    = (120, 135, 165)
CHROME      = (212, 220, 232)
RIM_INNER   = (60, 78, 108)
RED         = (198, 56, 46)
RED_DARK    = (120, 30, 25)
GREEN       = (74, 190, 120)
AMBER       = (230, 170, 60)
WHITE       = (248, 250, 252)

# ---------- cross-platform font resolution ----------
_BOLD_CANDIDATES = [
    ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 0),
    ("/Library/Fonts/Arial Bold.ttf", 0),
    ("/System/Library/Fonts/Helvetica.ttc", 1),
    ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 0),
]
_REG_CANDIDATES = [
    ("/System/Library/Fonts/Supplemental/Arial.ttf", 0),
    ("/Library/Fonts/Arial.ttf", 0),
    ("/System/Library/Fonts/Helvetica.ttc", 0),
    ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 0),
]

def _resolve(cands):
    for path, idx in cands:
        if os.path.exists(path):
            return path, idx
    raise RuntimeError("No suitable system font found; install Arial or DejaVu.")

_BOLD = _resolve(_BOLD_CANDIDATES)
_REG  = _resolve(_REG_CANDIDATES)

def font(bold, size):
    path, idx = _BOLD if bold else _REG
    return ImageFont.truetype(path, size, index=idx)

# ---------- drawing helpers ----------
def vgrad(draw, x0, y0, x1, y1, c_top, c_bot):
    h = y1 - y0
    for i in range(h):
        t = i / max(1, h - 1)
        r = int(c_top[0]*(1-t) + c_bot[0]*t)
        g = int(c_top[1]*(1-t) + c_bot[1]*t)
        b = int(c_top[2]*(1-t) + c_bot[2]*t)
        draw.line([(x0, y0+i), (x1, y0+i)], fill=(r, g, b))

def ctext(draw, cx, y, text, fnt, fill, spacing=0):
    if spacing:
        widths = [draw.textlength(ch, font=fnt) for ch in text]
        total = sum(widths) + spacing*(len(text)-1)
        x = cx - total/2
        for ch, w in zip(text, widths):
            draw.text((x, y), ch, font=fnt, fill=fill)
            x += w + spacing
        return
    w = draw.textlength(text, font=fnt)
    draw.text((cx - w/2, y), text, font=fnt, fill=fill)

def ltext(draw, x, y, text, fnt, fill):
    draw.text((x, y), text, font=fnt, fill=fill)

def rounded(draw, box, radius, **kw):
    draw.rounded_rectangle(box, radius=radius, **kw)

def draw_count_cell(img, draw, cx, cy, r, label, value, active_pin=True):
    draw.ellipse([cx-r-int(r*0.07), cy-r-int(r*0.07), cx+r+int(r*0.07), cy+r+int(r*0.07)],
                 outline=CHROME, width=max(2, r//22))
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=IVORY, outline=RIM_INNER, width=max(2, r//30))
    shade = Image.new("RGBA", (2*r, 2*r), (0,0,0,0))
    sd = ImageDraw.Draw(shade)
    sd.ellipse([0, int(r*0.9), 2*r, 2*r], fill=(*DIAL_SHADE, 80))
    img.paste(shade, (cx-r, cy-r), shade)
    for ang in (90, 0, 270, 180):
        a = math.radians(ang)
        x1 = cx + (r-int(r*0.10))*math.cos(a); y1 = cy - (r-int(r*0.10))*math.sin(a)
        x2 = cx + (r-int(r*0.21))*math.cos(a); y2 = cy - (r-int(r*0.21))*math.sin(a)
        draw.line([(x1,y1),(x2,y2)], fill=RIM_INNER, width=max(2, r//40))
    lf = font(True, int(r*0.26))
    ctext(draw, cx, cy - int(r*0.62), label, lf, LABEL_GREY, spacing=int(r*0.02))
    nf = font(True, int(r*1.15))
    bb = draw.textbbox((0,0), value, font=nf)
    nh = bb[3]-bb[1]
    draw.text((cx - draw.textlength(value, font=nf)/2, cy - nh/2 - bb[1] + int(r*0.12)),
              value, font=nf, fill=NUMBER)
    if active_pin:
        pr = max(2, int(r*0.08))
        py = cy - r + int(r*0.12)
        draw.ellipse([cx-pr, py-pr, cx+pr, py+pr], fill=RED, outline=RED_DARK, width=1)

# ---------------------------------------------------------------- WATCH 422x514
def make_watch():
    W, H = 422, 514
    img = Image.new("RGB", (W, H), NAVY_BOTTOM)
    d = ImageDraw.Draw(img)
    vgrad(d, 0, 0, W, H, NAVY_TOP, NAVY_BOTTOM)

    away_x, home_x = 92, W-92
    ctext(d, away_x, 16, "AWAY", font(True, 22), LABEL_GREY, spacing=1)
    ctext(d, home_x, 16, "HOME", font(True, 22), LABEL_GREY, spacing=1)
    ctext(d, away_x, 40, "3", font(True, 74), WHITE)
    ctext(d, home_x, 40, "5", font(True, 74), WHITE)
    pill_w, pill_h = 78, 46
    px0 = W//2 - pill_w//2; py0 = 52
    rounded(d, [px0, py0, px0+pill_w, py0+pill_h], 12, fill=(34, 50, 86))
    ctext(d, W//2, py0+4, "\u25B2", font(True, 18), GREEN)
    ctext(d, W//2, py0+20, "4", font(True, 22), WHITE)

    r = 58
    cy = 232
    xs = [92, W//2, W-92]
    for x, lab, val in zip(xs, ["BALLS","STRIKES","OUTS"], ["2","1","2"]):
        draw_count_cell(img, d, x, cy, r, lab, val)
    d = ImageDraw.Draw(img)

    tw, th = 250, 84
    tx0 = W//2 - tw//2; ty0 = 392
    rounded(d, [tx0, ty0, tx0+tw, ty0+th], 20, fill=(22, 36, 68), outline=AMBER, width=3)
    ccx, ccy, cr = tx0+44, ty0+th//2, 22
    d.ellipse([ccx-cr, ccy-cr, ccx+cr, ccy+cr], outline=AMBER, width=4)
    d.line([(ccx, ccy), (ccx, ccy-12)], fill=AMBER, width=4)
    d.line([(ccx, ccy), (ccx+9, ccy+4)], fill=AMBER, width=4)
    ltext(d, tx0+82, ty0+18, "47:12", font(True, 50), WHITE)

    img.save(os.path.join(OUTDIR, "watch_422x514.png"))

# ---------------------------------------------------------------- iOS history card
def draw_ios_history(img, d, x0, y0, x1, y1, scale=1.0):
    rad = int(46*scale)
    rounded(d, [x0, y0, x1, y1], rad, fill=CARD_TOP)
    inner = Image.new("RGB", (x1-x0, y1-y0), CARD_TOP)
    id_ = ImageDraw.Draw(inner)
    vgrad(id_, 0, 0, x1-x0, y1-y0, CARD_TOP, CARD_BOT)
    mask = Image.new("L", (x1-x0, y1-y0), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0,0,x1-x0-1,y1-y0-1], radius=rad, fill=255)
    img.paste(inner, (x0, y0), mask)
    d = ImageDraw.Draw(img)

    padx = int(48*scale)
    ltext(d, x0+padx, y0+int(40*scale), "History", font(True, int(58*scale)), WHITE)
    ltext(d, x0+padx, y0+int(112*scale), "12 games called", font(False, int(26*scale)), DIM_GREY)

    rows = [
        ("Eagles", 7, "Hawks", 5, "Sun 24 May", "1h 02m", "Final", GREEN),
        ("Tigers", 4, "Bears", 4, "Sat 23 May", "0h 58m", "Time", AMBER),
        ("Sox", 9, "Jays", 2, "Wed 20 May", "0h 47m", "Run rule", RED),
        ("Cubs", 3, "Reds", 6, "Sun 17 May", "1h 05m", "Final", GREEN),
        ("Aces", 5, "Kings", 1, "Sat 16 May", "0h 51m", "Time", AMBER),
        ("Owls", 2, "Larks", 8, "Wed 13 May", "0h 44m", "Run rule", RED),
        ("Foxes", 6, "Wolves", 3, "Sun 10 May", "1h 09m", "Final", GREEN),
        ("Rams", 1, "Colts", 2, "Sat 09 May", "0h 55m", "Final", GREEN),
        ("Jets", 8, "Stars", 0, "Wed 06 May", "0h 41m", "Run rule", RED),
        ("Bolts", 3, "Gulls", 3, "Sun 03 May", "1h 00m", "Time", AMBER),
        ("Pumas", 5, "Lynx", 4, "Sat 02 May", "1h 03m", "Final", GREEN),
        ("Crabs", 2, "Seals", 7, "Wed 29 Apr", "0h 49m", "Run rule", RED),
    ]
    ry = y0 + int(168*scale)
    rh = int(132*scale)
    for (a, asc, h, hsc, date, dur, reason, col) in rows:
        if ry + rh > y1 - int(20*scale):
            break
        rounded(d, [x0+int(28*scale), ry, x1-int(28*scale), ry+rh-int(18*scale)],
                int(20*scale), fill=(26, 42, 78))
        rounded(d, [x0+int(28*scale), ry, x0+int(40*scale), ry+rh-int(18*scale)],
                int(6*scale), fill=col)
        score = f"{a} {asc} \u2013 {hsc} {h}"
        ltext(d, x0+int(64*scale), ry+int(20*scale), score, font(True, int(40*scale)), WHITE)
        ltext(d, x0+int(64*scale), ry+int(72*scale), f"{date}  \u00B7  {dur}",
              font(False, int(26*scale)), DIM_GREY)
        bw = d.textlength(reason, font=font(True, int(24*scale))) + int(56*scale)
        bx1 = x1-int(48*scale); bx0 = int(bx1-bw)
        rounded(d, [bx0, ry+int(30*scale), bx1, ry+int(74*scale)], int(22*scale),
                fill=(col[0]//4+18, col[1]//4+18, col[2]//4+18), outline=col, width=max(1,int(2*scale)))
        ctext(d, (bx0+bx1)//2, ry+int(36*scale), reason, font(True, int(24*scale)), col)
        ry += rh

# ---------------------------------------------------------------- iPhone 1242x2688
def make_iphone():
    W, H = 1242, 2688
    img = Image.new("RGB", (W, H), NAVY_BOTTOM)
    d = ImageDraw.Draw(img)
    vgrad(d, 0, 0, W, H, NAVY_TOP, NAVY_BOTTOM)
    ctext(d, W//2, 150, "Every Call. On the Clock.", font(True, 82), WHITE)
    ctext(d, W//2, 270, "Balls \u00B7 Strikes \u00B7 Outs \u00B7 Innings \u00B7 Game timer",
          font(False, 42), LABEL_GREY)
    draw_ios_history(img, d, 121, 430, 1121, 2360, scale=1.0)
    d = ImageDraw.Draw(img)
    ctext(d, W//2, 2470, "Designed for softball & baseball umpires",
          font(False, 40), DIM_GREY)
    img.save(os.path.join(OUTDIR, "iphone_1242x2688.png"))

# ---------------------------------------------------------------- iPad 2064x2752
def draw_linescore_panel(img, d, x0, y0, x1, y1):
    rad = 50
    rounded(d, [x0, y0, x1, y1], rad, fill=CARD_TOP)
    inner = Image.new("RGB", (x1-x0, y1-y0), CARD_TOP)
    vgrad(ImageDraw.Draw(inner), 0, 0, x1-x0, y1-y0, CARD_TOP, CARD_BOT)
    mask = Image.new("L", (x1-x0, y1-y0), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0,0,x1-x0-1,y1-y0-1], radius=rad, fill=255)
    img.paste(inner, (x0, y0), mask)
    d = ImageDraw.Draw(img)

    padx = 70
    ltext(d, x0+padx, y0+50, "Eagles 7 \u2013 5 Hawks", font(True, 70), WHITE)
    ltext(d, x0+padx, y0+150, "Final \u00B7 7 innings \u00B7 1h 02m", font(False, 38), DIM_GREY)

    innings = list(range(1, 8))
    away = [0,2,0,1,3,1,0]; home = [1,0,2,0,0,2,0]
    gx0 = x0+padx; gy0 = y0+260
    label_col = 130
    grid_x0 = gx0 + label_col
    cellw = (x1-padx - grid_x0) // (len(innings)+1)
    cellh = 92
    headf = font(True, 34); cellf = font(True, 40); namef = font(True, 38)

    for i, inn in enumerate(innings):
        ctext(d, grid_x0 + i*cellw + cellw//2, gy0+24, str(inn), headf, DIM_GREY)
    ctext(d, grid_x0 + len(innings)*cellw + cellw//2, gy0+24, "R", font(True,34), AMBER)

    def row(ry, name, vals, total, col):
        ltext(d, gx0+8, ry+20, name, namef, WHITE)
        for i, v in enumerate(vals):
            ctext(d, grid_x0 + i*cellw + cellw//2, ry+20, str(v), cellf,
                  WHITE if v else DIM_GREY)
        ctext(d, grid_x0 + len(vals)*cellw + cellw//2, ry+20, str(total), cellf, col)

    row(gy0+cellh, "AWY", away, sum(away), GREEN)
    d.line([(gx0, gy0+2*cellh+6), (x1-padx, gy0+2*cellh+6)], fill=(40,56,92), width=2)
    row(gy0+2*cellh+12, "HOM", home, sum(home), WHITE)

    chip_y = gy0+3*cellh+60
    rounded(d, [gx0, chip_y, gx0+360, chip_y+76], 24, fill=(20,60,40), outline=GREEN, width=3)
    ctext(d, gx0+180, chip_y+16, "Eagles win", font(True, 40), GREEN)

    motif_y = chip_y + 230
    ltext(d, gx0, motif_y - 86, "Final count on the wrist", font(True, 40), WHITE)
    cr = 96
    spacing = (x1 - padx - gx0 - 2*cr) // 2
    centres = [gx0+cr, gx0+cr+spacing, gx0+cr+2*spacing]
    for cxc, lab, val in zip(centres, ["BALLS","STRIKES","OUTS"], ["3","2","3"]):
        draw_count_cell(img, d, cxc, motif_y+cr, cr, lab, val)
    d = ImageDraw.Draw(img)
    ltext(d, gx0, motif_y + 2*cr + 40,
          "Counts, outs and innings sync automatically.",
          font(False, 32), DIM_GREY)

def make_ipad():
    W, H = 2064, 2752
    img = Image.new("RGB", (W, H), NAVY_BOTTOM)
    d = ImageDraw.Draw(img)
    vgrad(d, 0, 0, W, H, NAVY_TOP, NAVY_BOTTOM)
    ctext(d, W//2, 150, "The Complete Umpire Indicator", font(True, 104), WHITE)
    ctext(d, W//2, 300, "Track the count and the clock on Apple Watch \u2014 review every game on iPad.",
          font(False, 46), LABEL_GREY)

    margin = 110; gap = 70
    top = 470; bot = H-260
    list_w = int((W - 2*margin - gap) * 0.52)
    lx0, lx1 = margin, margin+list_w
    rx0, rx1 = lx1+gap, W-margin
    draw_ios_history(img, d, lx0, top, lx1, bot, scale=1.05)
    d = ImageDraw.Draw(img)
    draw_linescore_panel(img, d, rx0, top, rx1, bot)
    d = ImageDraw.Draw(img)
    ctext(d, W//2, H-190, "Indicator \u00B7 Timer \u00B7 Line score \u00B7 History",
          font(False, 44), DIM_GREY)
    img.save(os.path.join(OUTDIR, "ipad_2064x2752.png"))

if __name__ == "__main__":
    make_watch()
    make_iphone()
    make_ipad()
    print("Wrote screenshots to", OUTDIR)
    for f in ("watch_422x514.png", "iphone_1242x2688.png", "ipad_2064x2752.png"):
        print("  -", f)
