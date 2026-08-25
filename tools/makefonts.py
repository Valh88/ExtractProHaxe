import os
from PIL import Image, ImageDraw, ImageFont

OUT = "client/res/font"
SRC = {
    "oswald": "tools/fonts_in/oswald.ttf",
    "inter":  "tools/fonts_in/inter.ttf",
}

# (family, weight, size, out_name)
CONFIGS = [
    ("oswald", 400, 14, "oswald_regular_14"),
    ("oswald", 500, 22, "oswald_medium_22"),
    ("oswald", 700, 18, "oswald_bold_18"),
    ("oswald", 700, 20, "oswald_bold_20"),
    ("oswald", 700, 22, "oswald_bold_22"),
    ("oswald", 700, 11, "oswald_bold_11"),
    ("inter",  400, 18, "inter_regular_18"),
    ("inter",  900, 72, "inter_black_72"),
]

CHARS = [chr(c) for c in range(32, 127)] + [chr(c) for c in range(0x400, 0x4FF + 1)]
ATLAS = 2048


def make_one(family, weight, size, name):
    font = ImageFont.truetype(SRC[family], size)
    axes = font.get_variation_axes()
    if axes is not None:
        if len(axes) == 1:
            font.set_variation_by_axes([weight])
        else:
            font.set_variation_by_axes([14, weight])  # [opsz, wght]

    ascent, descent = font.getmetrics()
    line_height = ascent + descent
    base = ascent

    atlas = Image.new("RGBA", (ATLAS, ATLAS), (0, 0, 0, 0))
    cx, cy, row_h = 1, 1, 0
    glyphs = []
    pad = 2
    cell_w = int(font.getlength("M")) + 4 + 2 * pad
    cell_h = ascent + descent + 2 * pad

    for ch in CHARS:
        adv = font.getlength(ch)
        canvas = Image.new("L", (cell_w, cell_h), 0)
        d = ImageDraw.Draw(canvas)
        d.text((pad, pad), ch, fill=255)
        bbox = canvas.getbbox()
        if bbox is None:
            glyphs.append((ch, 0, 0, 0, 0, 0, 0, adv))
            continue
        x0, y0, x1, y1 = bbox
        w, h = x1 - x0, y1 - y0
        if cx + w + 1 > ATLAS:
            cx, cy, row_h = 1, cy + row_h + 1, 0
        if cy + h + 1 > ATLAS:
            raise RuntimeError("atlas overflow for " + name)
        rgba = Image.new("RGBA", (w, h), (255, 255, 255, 0))
        rgba.putalpha(canvas.crop((x0, y0, x1, y1)))
        atlas.alpha_composite(rgba, (cx, cy))
        # xoffset/yoffset = glyph ink top-left relative to pen origin (0,0)
        glyphs.append((ch, cx, cy, w, h, x0 - pad, y0 - pad, adv))
        cx += w + 1
        if h > row_h:
            row_h = h

    atlas.save(os.path.join(OUT, name + ".png"))
    with open(os.path.join(OUT, name + ".fnt"), "w") as f:
        f.write('info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 aa=1 padding=0,0,0,0 spacing=1,1\n'
                % (family, size))
        f.write("common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0\n"
                % (line_height, base, ATLAS, ATLAS))
        f.write('page id=0 file="%s.png"\n' % name)
        f.write("chars count=%d\n" % len(glyphs))
        for (ch, gx, gy, w, h, ox, oy, adv) in glyphs:
            f.write("char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=0\n"
                    % (ord(ch), gx, gy, w, h, ox, oy, int(round(adv))))
    print("  %s: size=%d lineHeight=%d base=%d glyphs=%d" % (name, size, line_height, base, len(glyphs)))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for c in CONFIGS:
        print("Making", c[3])
        make_one(*c)
    print("=== done ===")
