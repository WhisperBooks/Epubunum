"""BookManager's icon: EpubReader's family (navy rounded square, cream
books, an amber badge) - books on a shelf, the badge's arrows up and down:
sent to EpubBuilder, fetched from it. Writes an .ico (16 - 256 px) and a
preview sheet.

Run from the repository root:
  python3 tools/make_bookmanager_icon.py demos/BookManager/BookManager_Icon.ico preview.png
(Pillow). 16 px: one arrow with a head at each end (two arrows did not
read at that size); 24 px and up: the arrows apart, bands on the spines."""
import sys
from PIL import Image, ImageDraw

NAVY = (28, 52, 84, 255)
DARK = (12, 42, 87, 255)
CREAM = (251, 247, 239, 255)
CREAM2 = (236, 230, 218, 255)
GREY = (151, 151, 151, 255)
AMBER = (255, 190, 40, 255)

SS = 4  # supersampling


def draw(size):
    S = size * SS
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = lambda v: round(v * S)
    small = size <= 24
    # the tile
    d.rounded_rectangle([f(0.04), f(0.04), f(0.96), f(0.96)], radius=f(0.18), fill=NAVY)
    # the shelf
    d.rounded_rectangle([f(0.13), f(0.76), f(0.87), f(0.82)], radius=f(0.015), fill=CREAM2)
    # the books: x, width, top, colour
    books = [(0.16, 0.14, 0.24, CREAM), (0.32, 0.12, 0.32, CREAM2), (0.46, 0.15, 0.20, CREAM)]
    for i, (x, w, top, col) in enumerate(books):
        d.rounded_rectangle([f(x), f(top), f(x + w), f(0.76)], radius=f(0.02), fill=col)
        if not small:
            # bands on the spine (the middle book's: amber, as the reader's word)
            band = AMBER if i == 1 else GREY
            for y in (top + 0.07, 0.76 - 0.10):
                d.rectangle([f(x + 0.025), f(y), f(x + w - 0.025), f(y + 0.035)], fill=band)
    # the badge: amber, cut out of the books by a navy ring
    cx, cy, r = 0.72, 0.68, (0.25 if size <= 16 else 0.22 if small else 0.20)
    ring = 0.03
    d.ellipse([f(cx - r - ring), f(cy - r - ring), f(cx + r + ring), f(cy + r + ring)], fill=NAVY)
    d.ellipse([f(cx - r), f(cy - r), f(cx + r), f(cy + r)], fill=AMBER)
    # two arrows: up (sent) on the left, down (fetched) on the right
    aw = r * (0.30 if not small else 0.34)  # head half-width
    sw = r * (0.11 if not small else 0.15)  # shaft half-width
    h = r * 0.62                              # half height
    if size <= 16:
        # 16 px: one arrow, a head at each end (both ways), bold
        t = r * 0.78
        hw = r * 0.52
        hh = r * 0.42
        d.polygon([(f(cx), f(cy - t)), (f(cx - hw), f(cy - t + hh)), (f(cx + hw), f(cy - t + hh))], fill=DARK)
        d.polygon([(f(cx), f(cy + t)), (f(cx - hw), f(cy + t - hh)), (f(cx + hw), f(cy + t - hh))], fill=DARK)
        d.rectangle([f(cx - r * 0.17), f(cy - t + hh - 0.01), f(cx + r * 0.17), f(cy + t - hh + 0.01)], fill=DARK)
        return im.resize((size, size), Image.LANCZOS)
    for ax, up in ((cx - r * 0.33, True), (cx + r * 0.33, False)):
        if up:
            tip, base = cy - h, cy - h + aw * 1.25
            d.polygon([(f(ax), f(tip)), (f(ax - aw), f(base)), (f(ax + aw), f(base))], fill=DARK)
            d.rectangle([f(ax - sw), f(base - 0.005), f(ax + sw), f(cy + h)], fill=DARK)
        else:
            tip, base = cy + h, cy + h - aw * 1.25
            d.polygon([(f(ax), f(tip)), (f(ax - aw), f(base)), (f(ax + aw), f(base))], fill=DARK)
            d.rectangle([f(ax - sw), f(cy - h), f(ax + sw), f(base + 0.005)], fill=DARK)
    return im.resize((size, size), Image.LANCZOS)


def main(ico, sheet):
    sizes = [16, 24, 32, 48, 64, 128, 256]
    imgs = {s: draw(s) for s in sizes}
    imgs[256].save(ico, format='ICO', sizes=[(s, s) for s in sizes],
                   append_images=[imgs[s] for s in sizes if s != 256])
    # preview: every size on light and dark grounds
    W = sum(sizes) + 20 * (len(sizes) + 1)
    pv = Image.new('RGBA', (W, 2 * 276), (240, 240, 240, 255))
    pd = ImageDraw.Draw(pv)
    pd.rectangle([0, 276, W, 552], fill=(40, 40, 40, 255))
    for row in (0, 276):
        x = 20
        for s in sizes:
            pv.alpha_composite(imgs[s], (x, row + 138 - s // 2))
            x += s + 20
    pv.save(sheet)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
