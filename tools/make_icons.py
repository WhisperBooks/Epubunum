"""The EpubUnum icons, one set: EpubReader, EpubBuilder, BookManager.

Every icon: the same navy rounded tile, cream books, and an amber badge
(cut out by a navy ring) in the lower right whose sign says what the
program does:
  EpubReader   an open book of text, one word highlighted amber; badge: play
  EpubBuilder  an open book - text on the left page, a sound wave on the
               right (audio made into a book that reads along); badge: a gear
  BookManager  books on a shelf; badge: arrows up (sent) and down (fetched)

Run from the repository root (Pillow):
  python3 tools/make_icons.py [preview.png]
It writes demos/EpubReader/EpubReader_Icon.ico,
demos/EpubBuilder/EpubBuilder_Icon.ico and
demos/BookManager/BookManager_Icon.ico (16, 24, 32, 48, 64, 128, 256 px),
and, when given, a preview sheet of every size on light and dark grounds.

Android (EpubReader, zip 322), in demos/EpubReader/android: the launcher
icons LauncherIcon_36.png ... _192.png (the tile as it is: Android 7 and
older), and the adaptive icon of Android 8 on as vector drawables -
AdaptiveIcon_Background.xml (the navy), AdaptiveIcon_Foreground.xml (the
book and the badge, inside the middle 66 of 108 dp that every launcher's
mask leaves) and AdaptiveIcon_Monochrome.xml (the same in one colour:
Android 13's themed icons); and the picture shown while the app starts
(zip 326) - Splash.xml (the whole icon, 144 dp: before Android 12) and
SplashV31.xml (the same inside the circle Android 12 on shows it in),
each with a ...Dark.xml for the dark theme (the same picture: the navy
tile stands on white and on black; a file each because the project has
a setting each).
And the TV banner TvBanner_320x180.png (zip 381: Android TV's home
screen; the name in DejaVu Sans Bold, else Arial Bold).
EpubReader.dproj names them.

Drawn 4x larger and scaled down. Small sizes are simpler: no lines on the
pages or spines at 24 px and below; at 16 px each badge has one bold sign.
"""
import math
import os
import sys
from PIL import Image, ImageDraw

NAVY = (28, 52, 84, 255)
DARK = (12, 42, 87, 255)
CREAM = (251, 247, 239, 255)
CREAM2 = (236, 230, 218, 255)
GREY = (151, 151, 151, 255)
AMBER = (255, 190, 40, 255)

SIZES = [16, 24, 32, 48, 64, 128, 256]
SS = 4  # supersampling

# the badge: centre and radius (a fraction of the tile), the same in all three
BADGE_X, BADGE_Y = 0.72, 0.70


def badge_radius(size):
    return 0.25 if size <= 16 else 0.22 if size <= 24 else 0.20


class Pen:
    """Drawing in fractions of the tile."""

    def __init__(self, size):
        self.size = size
        self.S = size * SS
        self.im = Image.new('RGBA', (self.S, self.S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def f(self, v):
        return round(v * self.S)

    def box(self, x0, y0, x1, y1):
        return [self.f(x0), self.f(y0), self.f(x1), self.f(y1)]

    def pts(self, pts):
        return [(self.f(x), self.f(y)) for x, y in pts]

    def done(self):
        return self.im.resize((self.size, self.size), Image.LANCZOS)


def tile(p):
    p.d.rounded_rectangle(p.box(0.04, 0.04, 0.96, 0.96), radius=p.f(0.18), fill=NAVY)


def badge(p):
    """The amber disc with its navy ring; returns its centre and radius."""
    r = badge_radius(p.size)
    ring = 0.03
    cx, cy = BADGE_X, BADGE_Y
    p.d.ellipse(p.box(cx - r - ring, cy - r - ring, cx + r + ring, cy + r + ring), fill=NAVY)
    p.d.ellipse(p.box(cx - r, cy - r, cx + r, cy + r), fill=AMBER)
    return cx, cy, r


def open_book(p, right_page):
    """An open book, the left page with text lines; right_page draws the
    right one's content (x0, x1, top, bottom)."""
    small = p.size <= 24
    # high in the tile: the right page's content stays clear of the badge
    top, bottom = 0.16, 0.70
    # the two pages, a slight fold in the middle
    p.d.polygon(p.pts([(0.12, top), (0.48, top + 0.03), (0.48, bottom + 0.03), (0.12, bottom)]), fill=CREAM)
    p.d.polygon(p.pts([(0.52, top + 0.03), (0.88, top), (0.88, bottom), (0.52, bottom + 0.03)]), fill=CREAM)
    # the spine's shadow
    p.d.polygon(p.pts([(0.48, top + 0.03), (0.52, top + 0.03), (0.52, bottom + 0.03), (0.48, bottom + 0.03)]),
                fill=CREAM2)
    if not small:
        for i in range(4):
            y = top + 0.08 + i * 0.10
            p.d.rectangle(p.box(0.18, y, 0.42, y + 0.035), fill=GREY)
    right_page(0.58, 0.82, top + 0.03, bottom)


def reader():
    p = Pen(sizes_now)
    tile(p)
    small = p.size <= 24

    def page(x0, x1, top, bottom):
        if small:
            return
        # lines, the second with a highlighted (amber) word
        for i in range(3):
            y = top + 0.06 + i * 0.10
            if i == 1:
                p.d.rectangle(p.box(x0, y, x0 + 0.06, y + 0.035), fill=GREY)
                p.d.rounded_rectangle(p.box(x0 + 0.08, y - 0.01, x1, y + 0.045), radius=p.f(0.015), fill=AMBER)
            else:
                p.d.rectangle(p.box(x0, y, x1, y + 0.035), fill=GREY)

    open_book(p, page)
    cx, cy, r = badge(p)
    # play: a triangle, its weight centred in the disc
    t = r * (0.62 if p.size <= 16 else 0.55)
    p.d.polygon(p.pts([(cx - t * 0.55, cy - t), (cx - t * 0.55, cy + t), (cx + t * 0.95, cy)]), fill=DARK)
    return p.done()


def builder():
    p = Pen(sizes_now)
    tile(p)
    small = p.size <= 24

    def page(x0, x1, top, bottom):
        # the sound wave: bars of a waveform across the right page
        heights = [0.08, 0.17, 0.24, 0.13, 0.20, 0.09] if not small else [0.10, 0.22, 0.14]
        n = len(heights)
        mid = top + 0.15
        step = (x1 - x0) / n
        bw = step * (0.55 if not small else 0.6)
        for i, h in enumerate(heights):
            x = x0 + i * step + (step - bw) / 2
            col = AMBER if (i == 2 and not small) else GREY
            p.d.rounded_rectangle(p.box(x, mid - h / 2, x + bw, mid + h / 2), radius=p.f(bw / 2.2), fill=col)

    open_book(p, page)
    cx, cy, r = badge(p)
    # a gear: teeth around a disc, a hole in the middle
    teeth = 6 if p.size <= 16 else 8
    ro = r * 0.72   # to the teeth's ends
    ri = r * 0.52   # the gear's body
    tw = math.pi / teeth * 0.55  # half a tooth's angle
    pts = []
    for k in range(teeth):
        a = 2 * math.pi * k / teeth
        for da, rad in ((-tw * 1.5, ri), (-tw, ro), (tw, ro), (tw * 1.5, ri)):
            pts.append((cx + rad * math.cos(a + da), cy + rad * math.sin(a + da)))
    p.d.polygon(p.pts(pts), fill=DARK)
    p.d.ellipse(p.box(cx - ri, cy - ri, cx + ri, cy + ri), fill=DARK)
    hole = r * (0.18 if p.size <= 16 else 0.22)
    p.d.ellipse(p.box(cx - hole, cy - hole, cx + hole, cy + hole), fill=AMBER)
    return p.done()


def manager():
    p = Pen(sizes_now)
    tile(p)
    small = p.size <= 24
    # the shelf
    p.d.rounded_rectangle(p.box(0.13, 0.76, 0.87, 0.82), radius=p.f(0.015), fill=CREAM2)
    # the books: x, width, top, colour
    books = [(0.16, 0.14, 0.24, CREAM), (0.32, 0.12, 0.32, CREAM2), (0.46, 0.15, 0.20, CREAM)]
    for i, (x, w, top, col) in enumerate(books):
        p.d.rounded_rectangle(p.box(x, top, x + w, 0.76), radius=p.f(0.02), fill=col)
        if not small:
            # bands on the spines (the middle book's amber, as the reader's word)
            band = AMBER if i == 1 else GREY
            for y in (top + 0.07, 0.76 - 0.10):
                p.d.rectangle(p.box(x + 0.025, y, x + w - 0.025, y + 0.035), fill=band)
    cx, cy, r = badge(p)
    if p.size <= 16:
        # one arrow, a head at each end (two did not read at 16 px)
        t, hw, hh = r * 0.78, r * 0.52, r * 0.42
        p.d.polygon(p.pts([(cx, cy - t), (cx - hw, cy - t + hh), (cx + hw, cy - t + hh)]), fill=DARK)
        p.d.polygon(p.pts([(cx, cy + t), (cx - hw, cy + t - hh), (cx + hw, cy + t - hh)]), fill=DARK)
        p.d.rectangle(p.box(cx - r * 0.17, cy - t + hh - 0.01, cx + r * 0.17, cy + t - hh + 0.01), fill=DARK)
        return p.done()
    # up (sent) at the left, down (fetched) at the right
    aw = r * (0.30 if not small else 0.34)
    sw = r * (0.11 if not small else 0.15)
    h = r * 0.62
    for ax, up in ((cx - r * 0.33, True), (cx + r * 0.33, False)):
        if up:
            tip, base = cy - h, cy - h + aw * 1.25
            p.d.polygon(p.pts([(ax, tip), (ax - aw, base), (ax + aw, base)]), fill=DARK)
            p.d.rectangle(p.box(ax - sw, base - 0.005, ax + sw, cy + h), fill=DARK)
        else:
            tip, base = cy + h, cy + h - aw * 1.25
            p.d.polygon(p.pts([(ax, tip), (ax - aw, base), (ax + aw, base)]), fill=DARK)
            p.d.rectangle(p.box(ax - sw, cy - h, ax + sw, base + 0.005), fill=DARK)
    return p.done()


sizes_now = 256

ICONS = [
    ('EpubReader', 'demos/EpubReader/EpubReader_Icon.ico', reader),
    ('EpubBuilder', 'demos/EpubBuilder/EpubBuilder_Icon.ico', builder),
    ('BookManager', 'demos/BookManager/BookManager_Icon.ico', manager),
]


# --- Android -----------------------------------------------------------

ANDROID_FOLDER = 'demos/EpubReader/android'
ANDROID_LAUNCHER = [36, 48, 72, 96, 144, 192]
# an adaptive icon is 108 dp square; a launcher's mask (circle, squircle)
# is sure to leave the middle 66. The tile's art is put in ART dp there.
ADAPTIVE = 108
ART = 58


def hexcolor(c):
    return '#FF%02X%02X%02X' % c[:3]


class Vector:
    """An Android vector drawable, drawn in fractions of the tile."""

    def __init__(self, viewport=ADAPTIVE, art=ART):
        """The tile's art art units wide in the middle of a viewport
        square."""
        self.paths = []
        self.viewport = viewport
        self.art = art
        self.off = (viewport - art) / 2

    def num(self, v):
        return ('%.2f' % v).rstrip('0').rstrip('.')

    def n(self, v):
        return self.num(self.off + v * self.art)

    def tile(self):
        """The navy rounded tile, as tile() draws it."""
        x0, y0, x1, y1, r = 0.04, 0.04, 0.96, 0.96, 0.18
        rr = self.num(r * self.art)
        arc = ' A%s,%s 0 0,1 ' % (rr, rr)
        n = self.n
        return ('M%s,%s L%s,%s' % (n(x0 + r), n(y0), n(x1 - r), n(y0)) + arc + '%s,%s' % (n(x1), n(y0 + r)) +
                ' L%s,%s' % (n(x1), n(y1 - r)) + arc + '%s,%s' % (n(x1 - r), n(y1)) +
                ' L%s,%s' % (n(x0 + r), n(y1)) + arc + '%s,%s' % (n(x0), n(y1 - r)) +
                ' L%s,%s' % (n(x0), n(y0 + r)) + arc + '%s,%s Z' % (n(x0 + r), n(y0)))

    def poly(self, pts):
        return 'M' + ' L'.join('%s,%s' % (self.n(x), self.n(y)) for x, y in pts) + ' Z'

    def rect(self, x0, y0, x1, y1):
        return self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])

    def disc(self, cx, cy, r):
        rr = self.num(r * self.art)
        return 'M%s,%s A%s,%s 0 1,0 %s,%s A%s,%s 0 1,0 %s,%s Z' % (
            self.n(cx - r), self.n(cy), rr, rr, self.n(cx + r), self.n(cy), rr, rr, self.n(cx - r), self.n(cy))

    def add(self, data, color, even_odd=False):
        self.paths.append((data, color, even_odd))

    def xml(self):
        out = ['<?xml version="1.0" encoding="utf-8"?>',
               '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
               '    android:width="%ddp"' % self.viewport,
               '    android:height="%ddp"' % self.viewport,
               '    android:viewportWidth="%d"' % self.viewport,
               '    android:viewportHeight="%d">' % self.viewport]
        for data, color, even_odd in self.paths:
            out.append('    <path')
            out.append('        android:fillColor="%s"' % hexcolor(color))
            if even_odd:
                out.append('        android:fillType="evenOdd"')
            out.append('        android:pathData="%s" />' % data)
        out.append('</vector>')
        return '\n'.join(out) + '\n'


def reader_vector(mono, v=None):
    """EpubReader's art (open_book, reader's page, badge) as a vector:
    in its colours, or in one (mono) with the play sign cut out. v: the
    vector to draw on (the adaptive icon's when None)."""
    if v is None:
        v = Vector()
    top, bottom = 0.16, 0.70
    white = (255, 255, 255, 255)
    left = [(0.12, top), (0.48, top + 0.03), (0.48, bottom + 0.03), (0.12, bottom)]
    right = [(0.52, top + 0.03), (0.88, top), (0.88, bottom), (0.52, bottom + 0.03)]
    r, ring = 0.20, 0.03
    cx, cy = BADGE_X, BADGE_Y
    t = r * 0.55
    play = v.poly([(cx - t * 0.55, cy - t), (cx - t * 0.55, cy + t), (cx + t * 0.95, cy)])
    if mono:
        # one colour: the ring round the badge is a gap in the right page -
        # the page's outer and inner edges down to the ring, and the
        # ring's arc between them
        v.add(v.poly(left), white)
        rr = r + ring
        y_out = cy - math.sqrt(rr * rr - (0.88 - cx) ** 2)
        y_in = cy - math.sqrt(rr * rr - (0.52 - cx) ** 2)
        arc = v.num(rr * v.art)
        v.add('M%s,%s L%s,%s L%s,%s A%s,%s 0 0,0 %s,%s Z' % (
            v.n(0.52), v.n(top + 0.03), v.n(0.88), v.n(top), v.n(0.88), v.n(y_out), arc, arc, v.n(0.52),
            v.n(y_in)), white)
        v.add(v.disc(cx, cy, r) + ' ' + play, white, True)
        return v.xml()
    v.add(v.poly(left), CREAM)
    v.add(v.poly(right), CREAM)
    v.add(v.rect(0.48, top + 0.03, 0.52, bottom + 0.03), CREAM2)
    for i in range(4):
        y = top + 0.08 + i * 0.10
        v.add(v.rect(0.18, y, 0.42, y + 0.035), GREY)
    x0, x1, ptop = 0.58, 0.82, top + 0.03
    for i in range(3):
        y = ptop + 0.06 + i * 0.10
        if i == 1:
            v.add(v.rect(x0, y, x0 + 0.06, y + 0.035), GREY)
            v.add(v.rect(x0 + 0.08, y - 0.01, x1, y + 0.045), AMBER)
        else:
            v.add(v.rect(x0, y, x1, y + 0.035), GREY)
    v.add(v.disc(cx, cy, r + ring), NAVY)
    v.add(v.disc(cx, cy, r), AMBER)
    v.add(play, DARK)
    return v.xml()


def background_vector():
    out = Vector()
    out.add('M0,0 L%d,0 L%d,%d L0,%d Z' % (ADAPTIVE, ADAPTIVE, ADAPTIVE, ADAPTIVE), NAVY)
    return out.xml()


# the picture shown while the app starts: the whole icon, tile and all.
# Before Android 12 it is drawn at its own size in the middle of the
# screen; from 12 on the system shows it in a circle 2/3 of its width, so
# the tile is drawn inside that.
SPLASH = 144
SPLASH_V31 = 108
SPLASH_V31_TILE = 56


def splash_vector(viewport, art):
    v = Vector(viewport, art)
    v.add(v.tile(), NAVY)
    return reader_vector(False, v)


def android():
    """EpubReader's Android icons (see the top)."""
    global sizes_now
    os.makedirs(ANDROID_FOLDER, exist_ok=True)
    for s in ANDROID_LAUNCHER:
        sizes_now = s
        path = '%s/LauncherIcon_%d.png' % (ANDROID_FOLDER, s)
        reader().save(path)
        print('wrote', path)
    for name, text in (('AdaptiveIcon_Background', background_vector()),
                       ('AdaptiveIcon_Foreground', reader_vector(False)),
                       ('AdaptiveIcon_Monochrome', reader_vector(True)),
                       ('Splash', splash_vector(SPLASH, SPLASH)),
                       ('SplashDark', splash_vector(SPLASH, SPLASH)),
                       ('SplashV31', splash_vector(SPLASH_V31, SPLASH_V31_TILE)),
                       ('SplashV31Dark', splash_vector(SPLASH_V31, SPLASH_V31_TILE))):
        path = '%s/%s.xml' % (ANDROID_FOLDER, name)
        with open(path, 'w', encoding='ascii', newline='\n') as f:
            f.write(text)
        print('wrote', path)
    banner = tv_banner()
    path = '%s/TvBanner_320x180.png' % ANDROID_FOLDER
    if banner is None:
        print('no bold font found:', path, 'left as it is')
    else:
        banner.save(path)
        print('wrote', path)


# the TV banner (zip 381): Android TV's home screen shows it, 320 x 180
# (xhdpi), the name in it; deployed by EpubReader.dproj to
# res/drawable-xhdpi/tv_banner.png, the manifest's android:banner
TV_BANNER = (320, 180)
# a bold sans for the name, the first one found (the PNG is in the
# repository: a machine without any of them leaves it as it is)
BANNER_FONTS = ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
                '/Library/Fonts/Arial Bold.ttf',
                '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
                'C:/Windows/Fonts/arialbd.ttf']


def tv_banner():
    """The TV banner: the navy ground, the reader's tile on the left, the
    name on the right ("epubunum", "reader" under it in amber); None
    when no font is found."""
    global sizes_now
    from PIL import ImageFont
    font = next((f for f in BANNER_FONTS if os.path.exists(f)), None)
    if font is None:
        return None
    w, h = TV_BANNER
    im = Image.new('RGBA', (w * SS, h * SS), NAVY)
    d = ImageDraw.Draw(im)
    # the tile, as the launcher's (its navy is the ground's)
    sizes_now = 256
    icon = reader().resize((112 * SS, 112 * SS), Image.LANCZOS)
    im.alpha_composite(icon, (10 * SS, (h * SS - icon.height) // 2))
    x = 124 * SS
    room = w * SS - x - 14 * SS
    # the name as large as fits beside the tile
    size = 40
    big = ImageFont.truetype(font, size * SS)
    while size > 16 and d.textlength('epubunum', font=big) > room:
        size -= 1
        big = ImageFont.truetype(font, size * SS)
    small = ImageFont.truetype(font, round(size * 0.62) * SS)
    top = (h * SS - (size + round(size * 0.62) + 8) * SS) // 2
    d.text((x, top), 'epubunum', font=big, fill=CREAM, anchor='la')
    d.text((x + SS, top + (size + 8) * SS), 'reader', font=small, fill=AMBER, anchor='la')
    return im.resize((w, h), Image.LANCZOS)


def render(fn):
    global sizes_now
    out = {}
    for s in SIZES:
        sizes_now = s
        out[s] = fn()
    return out


def main(preview=None):
    sets = []
    for name, path, fn in ICONS:
        imgs = render(fn)
        imgs[256].save(path, format='ICO', sizes=[(s, s) for s in SIZES],
                       append_images=[imgs[s] for s in SIZES if s != 256])
        sets.append(imgs)
        print('wrote', path)
    android()
    if preview:
        gap = 16
        row_w = sum(SIZES) + gap * (len(SIZES) + 1)
        H = 276
        pv = Image.new('RGBA', (row_w * 2, H * len(sets)), (240, 240, 240, 255))
        d = ImageDraw.Draw(pv)
        d.rectangle([row_w, 0, row_w * 2, H * len(sets)], fill=(40, 40, 40, 255))
        for r, imgs in enumerate(sets):
            for col in (0, row_w):
                x = col + gap
                for s in SIZES:
                    pv.alpha_composite(imgs[s], (x, r * H + H // 2 - s // 2))
                    x += s + gap
        pv.save(preview)
        print('wrote', preview)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else None)
