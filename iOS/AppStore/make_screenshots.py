#!/usr/bin/env python3
"""
App Store screenshots for UmpireClicker v1.4+ — the iOS app is now a full
umpire tool, so the iPhone/iPad shots lead with the live Game screen.

Sizes:
    iPhone 6.5"      1242 x 2688
    iPad 13"         2064 x 2752
    Apple Watch       422 x  514

Opaque RGB PNGs, written to ./screenshots/ next to this script.
Requires Pillow. Fonts: Arial/Helvetica on macOS, DejaVu on Linux.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "screenshots")
os.makedirs(OUTDIR, exist_ok=True)

NAVY_TOP    = (16, 28, 56)
NAVY_BOTTOM = (8, 18, 38)
CARD_TOP    = (20, 34, 66)
CARD_BOT    = (12, 22, 44)
ROW_BG      = (26, 42, 78)
IVORY       = (244, 245, 240)
LABEL_GREY  = (150, 165, 195)
DIM_GREY    = (120, 135, 165)
GREEN       = (74, 190, 120)
YELLOW      = (235, 200, 80)
RED         = (225, 90, 80)
AMBER       = (230, 170, 60)
BLUE        = (100, 150, 235)
WHITE       = (248, 250, 252)

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
    raise RuntimeError("No suitable font found; install Arial or DejaVu.")

_BOLD = _resolve(_BOLD_CANDIDATES)
_REG  = _resolve(_REG_CANDIDATES)

def font(bold, size):
    path, idx = _BOLD if bold else _REG
    return ImageFont.truetype(path, size, index=idx)

def vgrad(draw, x0, y0, x1, y1, c_top, c_bot):
    h = y1 - y0
    for i in range(h):
        t = i / max(1, h - 1)
        draw.line([(x0, y0 + i), (x1, y0 + i)], fill=(
            int(c_top[0]*(1-t) + c_bot[0]*t),
            int(c_top[1]*(1-t) + c_bot[1]*t),
            int(c_top[2]*(1-t) + c_bot[2]*t)))

def ctext(draw, cx, y, text, fnt, fill, spacing=0):
    if spacing:
        widths = [draw.textlength(ch, font=fnt) for ch in text]
        total = sum(widths) + spacing*(len(text)-1)
        x = cx - total/2
        for ch, w in zip(text, widths):
            draw.text((x, y), ch, font=fnt, fill=fill)
            x += w + spacing
        return
    draw.text((cx - draw.textlength(text, font=fnt)/2, y), text, font=fnt, fill=fill)

def ltext(draw, x, y, text, fnt, fill):
    draw.text((x, y), text, font=fnt, fill=fill)

def rounded(draw, box, radius, **kw):
    draw.rounded_rectangle(box, radius=radius, **kw)

def card(img, box, radius):
    x0, y0, x1, y1 = box
    inner = Image.new("RGB", (x1-x0, y1-y0), CARD_TOP)
    vgrad(ImageDraw.Draw(inner), 0, 0, x1-x0, y1-y0, CARD_TOP, CARD_BOT)
    mask = Image.new("L", (x1-x0, y1-y0), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, x1-x0-1, y1-y0-1], radius=radius, fill=255)
    img.paste(inner, (x0, y0), mask)
    return ImageDraw.Draw(img)

# ------------------------------------------------------------ Game screen card
def draw_game_screen(img, d, x0, y0, x1, s=1.0):
    """Render the iOS Game screen (scoreboard, count cells, clock).
    The card is sized to its content; returns the card bottom y."""
    content_h = int(1040*s) + int(44*s)   # sections + bottom padding
    y1 = y0 + content_h
    d = card(img, (x0, y0, x1, y1), int(46*s))
    pad = int(44*s)

    # nav title
    ltext(d, x0+pad, y0+int(34*s), "Umpire", font(True, int(56*s)), WHITE)
    end_f = font(True, int(30*s))
    d.text((x1-pad-d.textlength("End", font=end_f), y0+int(52*s)), "End", font=end_f, fill=RED)

    # ---- scoreboard card ----
    sb_y0 = y0 + int(126*s); sb_y1 = sb_y0 + int(240*s)
    rounded(d, [x0+pad, sb_y0, x1-pad, sb_y1], int(26*s), fill=ROW_BG)
    third = (x1 - x0 - 2*pad) // 3
    away_cx = x0 + pad + third//2
    mid_cx  = x0 + pad + third + third//2
    home_cx = x0 + pad + 2*third + third//2
    ctext(d, away_cx, sb_y0+int(24*s), "Away", font(True, int(34*s)), WHITE)
    ctext(d, away_cx, sb_y0+int(66*s), "3", font(True, int(110*s)), WHITE)
    ctext(d, away_cx, sb_y0+int(190*s), "AT BAT", font(True, int(24*s)), GREEN, spacing=int(2*s))
    ctext(d, mid_cx, sb_y0+int(46*s), "\u25B2", font(True, int(44*s)), GREEN)
    ctext(d, mid_cx, sb_y0+int(110*s), "Inning 5", font(True, int(36*s)), WHITE)
    ctext(d, home_cx, sb_y0+int(24*s), "Home", font(False, int(34*s)), DIM_GREY)
    ctext(d, home_cx, sb_y0+int(66*s), "2", font(True, int(110*s)), DIM_GREY)

    # ---- count cells ----
    cc_y0 = sb_y1 + int(34*s); cc_h = int(300*s)
    gap = int(24*s)
    cw = (x1 - x0 - 2*pad - 2*gap) // 3
    cells = [("BALLS", "2", GREEN, 3), ("STRIKES", "1", YELLOW, 2), ("OUTS", "2", RED, 2)]
    for i, (lab, val, col, pips) in enumerate(cells):
        cx0 = x0 + pad + i*(cw+gap)
        tint = (col[0]//5+16, col[1]//5+16, col[2]//5+16)
        rounded(d, [cx0, cc_y0, cx0+cw, cc_y0+cc_h], int(24*s), fill=tint)
        ctext(d, cx0+cw//2, cc_y0+int(26*s), lab, font(True, int(30*s)), col, spacing=int(2*s))
        ctext(d, cx0+cw//2, cc_y0+int(68*s), val, font(True, int(150*s)), WHITE)
        pr = int(11*s); total_w = pips*2*pr + (pips-1)*int(12*s)
        px = cx0 + cw//2 - total_w//2 + pr
        for p in range(pips):
            filled = p < int(val)
            d.ellipse([px-pr, cc_y0+cc_h-int(46*s)-pr, px+pr, cc_y0+cc_h-int(46*s)+pr],
                      fill=col if filled else (col[0]//3, col[1]//3, col[2]//3))
            px += 2*pr + int(12*s)

    # ---- clock card ----
    ck_y0 = cc_y0 + cc_h + int(34*s); ck_y1 = ck_y0 + int(180*s)
    rounded(d, [x0+pad, ck_y0, x1-pad, ck_y1], int(26*s), fill=ROW_BG)
    ccx, ccy, crr = x0+pad+int(52*s), ck_y0+int(52*s), int(22*s)
    d.ellipse([ccx-crr, ccy-crr, ccx+crr, ccy+crr], outline=AMBER, width=max(2, int(4*s)))
    d.line([(ccx, ccy), (ccx, ccy-int(12*s))], fill=AMBER, width=max(2, int(4*s)))
    d.line([(ccx, ccy), (ccx+int(9*s), ccy+int(4*s))], fill=AMBER, width=max(2, int(4*s)))
    ltext(d, ccx+crr+int(16*s), ck_y0+int(28*s), "Ball Game", font(True, int(38*s)), AMBER)
    t_f = font(True, int(64*s))
    d.text((x1-pad-int(30*s)-d.textlength("07:41", font=t_f), ck_y0+int(18*s)), "07:41", font=t_f, fill=AMBER)
    ltext(d, x0+pad+int(30*s), ck_y0+int(112*s), "Elapsed 52:19", font(False, int(30*s)), DIM_GREY)
    btn_f = font(True, int(30*s))
    bw = d.textlength("Pause", font=btn_f) + int(56*s)
    rounded(d, [x1-pad-int(30*s)-bw, ck_y0+int(102*s), x1-pad-int(30*s), ck_y0+int(156*s)],
            int(16*s), outline=BLUE, width=max(2, int(3*s)))
    ctext(d, x1-pad-int(30*s)-bw//2, ck_y0+int(112*s), "Pause", btn_f, BLUE)

    # ---- end-half button ----
    eh_y0 = ck_y1 + int(30*s); eh_y1 = eh_y0 + int(96*s)
    rounded(d, [x0+pad, eh_y0, x1-pad, eh_y1], int(22*s), outline=BLUE, width=max(2, int(3*s)))
    ctext(d, (x0+x1)//2, eh_y0+int(24*s), "End half-inning", font(True, int(36*s)), BLUE)
    return y1

# ------------------------------------------------------------ iPhone
def make_iphone():
    W, H = 1242, 2688
    img = Image.new("RGB", (W, H), NAVY_BOTTOM)
    d = ImageDraw.Draw(img)
    vgrad(d, 0, 0, W, H, NAVY_TOP, NAVY_BOTTOM)

    ctext(d, W//2, 130, "Umpire From Your Phone.", font(True, 84), WHITE)
    ctext(d, W//2, 250, "Balls \u00B7 Strikes \u00B7 Outs \u00B7 Innings \u00B7 Tournament clock",
          font(False, 42), LABEL_GREY)

    card_bottom = draw_game_screen(img, d, 121, 400, 1121, s=1.35)
    d = ImageDraw.Draw(img)

    # feature strip fills the space under the game card
    feats = [("alert", "Haptic alerts", "Buzzes at both\ntimer thresholds"),
             ("sun", "Stays awake", "Screen never sleeps\nduring a game"),
             ("list", "Auto history", "Every game saved\nwith line score")]
    fy0 = card_bottom + 70; fh = 300
    gap = 30; fw = (1000 - 2*gap)//3
    for i, (icon, title, sub) in enumerate(feats):
        fx0 = 121 + i*(fw+gap)
        rounded(d, [fx0, fy0, fx0+fw, fy0+fh], 24, fill=ROW_BG)
        icx, icy = fx0+fw//2, fy0+62
        if icon == "alert":
            # bell-ish: circle with "!" plus two vibration arcs
            d.ellipse([icx-26, icy-26, icx+26, icy+26], outline=AMBER, width=4)
            ctext(d, icx, icy-22, "!", font(True, 40), AMBER)
            d.arc([icx-44, icy-44, icx+44, icy+44], 300, 340, fill=AMBER, width=4)
            d.arc([icx-44, icy-44, icx+44, icy+44], 200, 240, fill=AMBER, width=4)
        elif icon == "sun":
            d.ellipse([icx-18, icy-18, icx+18, icy+18], outline=AMBER, width=4)
            import math as _m
            for a in range(0, 360, 45):
                r = _m.radians(a)
                d.line([(icx+26*_m.cos(r), icy+26*_m.sin(r)),
                        (icx+38*_m.cos(r), icy+38*_m.sin(r))], fill=AMBER, width=4)
        else:  # list
            for j in range(3):
                yy = icy - 20 + j*20
                d.ellipse([icx-34, yy-4, icx-26, yy+4], fill=AMBER)
                d.line([(icx-16, yy), (icx+36, yy)], fill=AMBER, width=5)
        ctext(d, fx0+fw//2, fy0+122, title, font(True, 38), WHITE)
        for j, line in enumerate(sub.split("\n")):
            ctext(d, fx0+fw//2, fy0+180+j*40, line, font(False, 28), DIM_GREY)

    ctext(d, W//2, fy0+fh+70, "Also on Apple Watch", font(True, 38), LABEL_GREY)
    img.save(os.path.join(OUTDIR, "iphone_1242x2688.png"))

# ------------------------------------------------------------ iPad
def draw_history_panel(img, d, x0, y0, x1, y1, s=1.0):
    d = card(img, (x0, y0, x1, y1), int(46*s))
    pad = int(44*s)
    ltext(d, x0+pad, y0+int(36*s), "History", font(True, int(52*s)), WHITE)
    ltext(d, x0+pad, y0+int(102*s), "12 games called", font(False, int(26*s)), DIM_GREY)
    rows = [
        ("Away 7 \u2013 5 Home", "Sun 24 May \u00B7 1h 02m", "Final", GREEN),
        ("Away 4 \u2013 4 Home", "Sat 23 May \u00B7 0h 58m", "Time", AMBER),
        ("Away 9 \u2013 2 Home", "Wed 20 May \u00B7 0h 47m", "Run rule", RED),
        ("Away 3 \u2013 6 Home", "Sun 17 May \u00B7 1h 05m", "Final", GREEN),
        ("Away 5 \u2013 1 Home", "Sat 16 May \u00B7 0h 51m", "Time", AMBER),
        ("Away 2 \u2013 8 Home", "Wed 13 May \u00B7 0h 44m", "Run rule", RED),
        ("Away 6 \u2013 3 Home", "Sun 10 May \u00B7 1h 09m", "Final", GREEN),
        ("Away 1 \u2013 2 Home", "Sat 09 May \u00B7 0h 55m", "Final", GREEN),
        ("Away 8 \u2013 0 Home", "Wed 06 May \u00B7 0h 41m", "Run rule", RED),
        ("Away 3 \u2013 3 Home", "Sun 03 May \u00B7 1h 00m", "Time", AMBER),
        ("Away 5 \u2013 4 Home", "Sat 02 May \u00B7 1h 03m", "Final", GREEN),
    ]
    ry = y0 + int(160*s); rh = int(128*s)
    for (score, meta, reason, col) in rows:
        if ry + rh > y1 - int(20*s): break
        rounded(d, [x0+int(28*s), ry, x1-int(28*s), ry+rh-int(18*s)], int(20*s), fill=ROW_BG)
        rounded(d, [x0+int(28*s), ry, x0+int(40*s), ry+rh-int(18*s)], int(6*s), fill=col)
        ltext(d, x0+int(62*s), ry+int(18*s), score, font(True, int(38*s)), WHITE)
        ltext(d, x0+int(62*s), ry+int(70*s), meta, font(False, int(25*s)), DIM_GREY)
        bf = font(True, int(23*s)); bw = d.textlength(reason, font=bf) + int(52*s)
        bx1 = x1-int(46*s); bx0 = int(bx1-bw)
        rounded(d, [bx0, ry+int(28*s), bx1, ry+int(72*s)], int(22*s),
                fill=(col[0]//4+18, col[1]//4+18, col[2]//4+18), outline=col, width=max(1, int(2*s)))
        ctext(d, (bx0+bx1)//2, ry+int(34*s), reason, bf, col)
        ry += rh

def make_ipad():
    W, H = 2064, 2752
    img = Image.new("RGB", (W, H), NAVY_BOTTOM)
    d = ImageDraw.Draw(img)
    vgrad(d, 0, 0, W, H, NAVY_TOP, NAVY_BOTTOM)

    ctext(d, W//2, 140, "The Complete Umpire Toolkit", font(True, 100), WHITE)
    ctext(d, W//2, 285, "Call the game on iPhone, iPad or Apple Watch \u2014 every result saved to History.",
          font(False, 46), LABEL_GREY)

    margin = 110; gap = 70
    top = 450; bot = H-240
    game_w = int((W - 2*margin - gap) * 0.55)
    game_bottom = draw_game_screen(img, d, margin, top, margin+game_w, s=1.15)
    d = ImageDraw.Draw(img)
    # dial motif card fills the space under the game screen
    m_y0 = game_bottom + gap
    d = card(img, (margin, m_y0, margin+game_w, bot), 46)
    ctext(d, margin+game_w//2, m_y0+44, "Final count on the wrist", font(True, 46), WHITE)
    cr = 105
    centres = [margin+game_w//2 - int(2.6*cr), margin+game_w//2, margin+game_w//2 + int(2.6*cr)]
    dial_cy = m_y0 + (bot-m_y0)//2 + 40
    for cxc, lab, val in zip(centres, ["BALLS", "STRIKES", "OUTS"], ["3", "2", "3"]):
        draw_count_cell(img, d, cxc, dial_cy, cr, lab, val)
    d = ImageDraw.Draw(img)
    ctext(d, margin+game_w//2, bot-90, "Counts sync from the watch automatically",
          font(False, 32), DIM_GREY)
    draw_history_panel(img, d, margin+game_w+gap, top, W-margin, bot, s=1.05)
    d = ImageDraw.Draw(img)

    ctext(d, W//2, H-170, "Live game \u00B7 Tournament clock \u00B7 Haptic timer alerts \u00B7 History",
          font(False, 44), DIM_GREY)
    img.save(os.path.join(OUTDIR, "ipad_2064x2752.png"))

# ------------------------------------------------------------ Watch (unchanged design)
def draw_count_cell(img, draw, cx, cy, r, label, value):
    CHROME = (212, 220, 232); RIM = (60, 78, 108); NUM = (24, 32, 54)
    PIN = (198, 56, 46); PIN_D = (120, 30, 25); SHADE = (214, 216, 209)
    draw.ellipse([cx-r-int(r*0.07), cy-r-int(r*0.07), cx+r+int(r*0.07), cy+r+int(r*0.07)],
                 outline=CHROME, width=max(2, r//22))
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=IVORY, outline=RIM, width=max(2, r//30))
    shade = Image.new("RGBA", (2*r, 2*r), (0, 0, 0, 0))
    ImageDraw.Draw(shade).ellipse([0, int(r*0.9), 2*r, 2*r], fill=(*SHADE, 80))
    img.paste(shade, (cx-r, cy-r), shade)
    for ang in (90, 0, 270, 180):
        a = math.radians(ang)
        draw.line([(cx+(r-int(r*0.10))*math.cos(a), cy-(r-int(r*0.10))*math.sin(a)),
                   (cx+(r-int(r*0.21))*math.cos(a), cy-(r-int(r*0.21))*math.sin(a))],
                  fill=RIM, width=max(2, r//40))
    ctext(draw, cx, cy-int(r*0.62), label, font(True, int(r*0.26)), LABEL_GREY, spacing=int(r*0.02))
    nf = font(True, int(r*1.15))
    bb = draw.textbbox((0, 0), value, font=nf)
    draw.text((cx - draw.textlength(value, font=nf)/2, cy-(bb[3]-bb[1])/2-bb[1]+int(r*0.12)),
              value, font=nf, fill=NUM)
    pr = max(2, int(r*0.08))
    draw.ellipse([cx-pr, cy-r+int(r*0.12)-pr, cx+pr, cy-r+int(r*0.12)+pr], fill=PIN, outline=PIN_D, width=1)

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
    rounded(d, [W//2-39, 52, W//2+39, 98], 12, fill=(34, 50, 86))
    ctext(d, W//2, 56, "\u25B2", font(True, 18), GREEN)
    ctext(d, W//2, 72, "4", font(True, 22), WHITE)
    for x, lab, val in zip([92, W//2, W-92], ["BALLS", "STRIKES", "OUTS"], ["2", "1", "2"]):
        draw_count_cell(img, d, x, 232, 58, lab, val)
    d = ImageDraw.Draw(img)
    rounded(d, [W//2-125, 392, W//2+125, 476], 20, fill=(22, 36, 68), outline=AMBER, width=3)
    ccx, ccy, cr = W//2-81, 434, 22
    d.ellipse([ccx-cr, ccy-cr, ccx+cr, ccy+cr], outline=AMBER, width=4)
    d.line([(ccx, ccy), (ccx, ccy-12)], fill=AMBER, width=4)
    d.line([(ccx, ccy), (ccx+9, ccy+4)], fill=AMBER, width=4)
    ltext(d, W//2-43, 410, "47:12", font(True, 50), WHITE)
    img.save(os.path.join(OUTDIR, "watch_422x514.png"))

if __name__ == "__main__":
    make_iphone()
    make_ipad()
    make_watch()
    print("Wrote screenshots to", OUTDIR)
    for f in ("iphone_1242x2688.png", "ipad_2064x2752.png", "watch_422x514.png"):
        print("  -", f)
