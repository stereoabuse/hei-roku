# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow"]
# ///
"""Regenerate the channel icon and splash:  uv run tools/make_images.py"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "images"
BG, ACCENT, MUTED = "#0B0B0D", "#F5C518", "#9A978F"


def font(size, bold=True):
    for name in (["arialbd.ttf", "DejaVuSans-Bold.ttf"] if bold else ["arial.ttf", "DejaVuSans.ttf"]):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    raise SystemExit("No usable TrueType font found")


def draw(width, height, scale):
    img = Image.new("RGB", (width, height), BG)
    d = ImageDraw.Draw(img)
    cx, cy = width / 2, height / 2
    d.text((cx, cy - 46 * scale), "HEI", font=font(round(130 * scale)), fill=ACCENT, anchor="mm")
    d.text((cx, cy + 58 * scale), "NETWORK", font=font(round(62 * scale)), fill=ACCENT, anchor="mm")
    d.text((cx, cy + 120 * scale), "UNOFFICIAL", font=font(round(26 * scale), bold=False), fill=MUTED, anchor="mm")
    return img


OUT.mkdir(exist_ok=True)
draw(540, 405, 1.0).save(OUT / "icon_fhd.png")
draw(290, 218, 0.54).save(OUT / "icon_hd.png")
draw(1920, 1080, 1.6).save(OUT / "splash_fhd.png")
print("wrote", *sorted(p.name for p in OUT.glob("*.png")))
