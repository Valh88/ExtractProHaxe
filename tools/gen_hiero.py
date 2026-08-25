import os, subprocess, sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS_IN = os.path.join(ROOT, "tools", "fonts_in")
HIERO_DIR = os.path.join(ROOT, "tools", "hiero")
STATIC_DIR = os.path.join(HIERO_DIR, "_static")
OUT_DIR = os.path.join(ROOT, "client", "res", "font")
JAR = os.path.join(ROOT, "tools", "runnable-hiero.jar")

# (name, family, weight, size)
CONFIGS = [
    ("oswald_regular_14", "oswald", 400, 14),
    ("oswald_medium_22",  "oswald", 500, 22),
    ("oswald_bold_18",    "oswald", 700, 18),
    ("oswald_bold_20",    "oswald", 700, 20),
    ("oswald_bold_22",    "oswald", 700, 22),
    ("oswald_bold_11",    "oswald", 700, 11),
    ("inter_regular_18",  "inter",  400, 18),
    ("inter_black_72",    "inter",  900, 72),
]

SRC = {
    "oswald": os.path.join(FONTS_IN, "oswald.ttf"),
    "inter":  os.path.join(FONTS_IN, "inter.ttf"),
}

CHARS = [chr(c) for c in range(32, 127)] + [chr(c) for c in range(0x400, 0x4FF + 1)]
# single line: hiero's parser splits on '=' and breaks on multi-line glyph.text
GLYPH_TEXT = "".join(CHARS)


def make_static(family, weight, name):
    out = os.path.join(STATIC_DIR, name + ".ttf")
    if os.path.exists(out):
        return out
    f = TTFont(SRC[family])
    if "fvar" in f:
        axes = {a.axisTag: a for a in f["fvar"].axes}
        inst = {"wght": weight}
        if "opsz" in axes:
            inst["opsz"] = max(axes["opsz"].minValue, min(22, axes["opsz"].maxValue))
        instantiateVariableFont(f, inst, inplace=True)
    os.makedirs(STATIC_DIR, exist_ok=True)
    f.save(out)
    return out


def write_conf(name, ttf, size):
    p = os.path.join(HIERO_DIR, name + ".hiero")
    text = []
    text.append("font.name=%s" % name)
    text.append("font.size=%d" % size)
    text.append("font.bold=false")
    text.append("font.italic=false")
    text.append("font.gamma=1.8")
    text.append("font.mono=false")
    text.append("font2.file=%s" % ttf.replace("\\", "/"))
    text.append("font2.use=true")
    text.append("pad.top=1\npad.right=1\npad.bottom=1\npad.left=1")
    text.append("pad.advance.x=0\npad.advance.y=0")
    text.append("glyph.native.rendering=false")
    text.append("glyph.page.width=2048\nglyph.page.height=2048")
    text.append("glyph.text=%s" % GLYPH_TEXT)
    text.append("render_type=0")
    text.append("effect.class=com.badlogic.gdx.tools.hiero.unicodefont.effects.ColorEffect")
    text.append("effect.Color=ffffff")
    with open(p, "w", encoding="cp1251") as fh:
        fh.write("\n".join(text) + "\n")
    return p


def main():
    gen_dir = os.path.join(HIERO_DIR, "out")
    if os.path.exists(gen_dir):
        for f in os.listdir(gen_dir):
            os.remove(os.path.join(gen_dir, f))
    os.makedirs(gen_dir, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    for (name, family, weight, size) in CONFIGS:
        print("== %s (size %d) ==" % (name, size))
        ttf = make_static(family, weight, name)
        conf = write_conf(name, ttf, size)
        out_base = os.path.join(gen_dir, name)
        subprocess.run(
            ["java", "-jar", JAR, "--input", conf, "--output", out_base, "--batch"],
            check=True,
        )
        # copy generated .fnt and all page pngs into client/res/font
        import glob
        for src in glob.glob(out_base + "*"):
            dst = os.path.join(OUT_DIR, os.path.basename(src))
            if os.path.exists(dst):
                os.remove(dst)
            import shutil
            shutil.move(src, dst)
    print("done")


if __name__ == "__main__":
    main()
