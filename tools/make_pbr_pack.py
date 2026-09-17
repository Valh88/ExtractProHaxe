#!/usr/bin/env python3
"""
Pack separate PBR textures into a single PropsTexture-compatible RGB image.

Heaps PropsTexture reads:
  R = metalness
  G = sqrt(1 - roughness)   (perceptual roughness encoding: shader does 1-g*g)
  B = occlusion
  A = 1.0 (unused, emissive controlled by scalar)

Usage:
  python tools/make_pbr_pack.py
  python tools/make_pbr_pack.py --dir client/res/models/main_weapons/ak-74m --prefix AK
"""
import argparse, os, sys
from PIL import Image

def main():
    p = argparse.ArgumentParser(description="Pack metallic+roughness+AO into PropsTexture PNG")
    p.add_argument("--dir", default="client/res/models/main_weapons/ak-74m",
                   help="Directory containing the source textures")
    p.add_argument("--prefix", default="AK",
                   help="Filename prefix (e.g. AK → AK_metallic.png, AK_roughness.png, AK_ao.png)")
    args = p.parse_args()

    d = args.dir
    prefix = args.prefix

    metallic_path  = os.path.join(d, f"{prefix}_metallic.png")
    roughness_path = os.path.join(d, f"{prefix}_roughness.png")
    ao_path        = os.path.join(d, f"{prefix}_ao.png")
    out_path       = os.path.join(d, f"{prefix}_pbr.png")

    for path in [metallic_path, roughness_path, ao_path]:
        if not os.path.isfile(path):
            print(f"ERROR: missing {path}", file=sys.stderr)
            sys.exit(1)

    metal  = Image.open(metallic_path).convert("L")
    rough  = Image.open(roughness_path).convert("L")
    ao     = Image.open(ao_path).convert("L")

    # All must be same size
    size = metal.size
    if rough.size != size or ao.size != size:
        print(f"ERROR: size mismatch — metallic={metal.size}, roughness={rough.size}, ao={ao.size}", file=sys.stderr)
        sys.exit(1)

    w, h = size
    out = Image.new("RGB", (w, h))

    for y in range(h):
        for x in range(w):
            m = metal.getpixel((x, y)) / 255.0   # 0..1
            r = rough.getpixel((x, y)) / 255.0    # 0..1
            a = ao.getpixel((x, y)) / 255.0        # 0..1

            # PropsTexture: roughness_out = 1 - g*g
            # To get desired roughness r: g = sqrt(1 - r)
            import math
            g = math.sqrt(max(0.0, min(1.0, 1.0 - r)))

            out.putpixel((x, y), (
                int(m * 255 + 0.5),
                int(g * 255 + 0.5),
                int(a * 255 + 0.5),
            ))

    out.save(out_path, "PNG")
    print(f"PBR pack: {out_path} ({w}x{h})")

if __name__ == "__main__":
    main()
