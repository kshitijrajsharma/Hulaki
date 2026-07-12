"""Renders the Hulaki mark to every raster the app and the stores need.

One geometry, defined once here, so the Flutter widget, the app icon, the Play
assets and the website can never drift apart. Run from the repo root:

    python3 tool/render_brand.py
"""

import subprocess
import tempfile
from pathlib import Path

INK = "#15181B"
WHITE = "#FFFFFF"
TAGLINE = "An offline-first, privacy-focused field mapping app."

# The mark, in its 100x84 space. The summit splits into the twin peak of
# Machhapuchhre; the three dots below read as the trail.
PEAK = "46,13 50,23 54,13 72,58 50,46 28,58"
DOTS = [(35, 74), (50, 74), (65, 74)]
DOT_R = 6.2

# The ink the mark actually occupies, not its nominal 100x84 canvas. Padding the
# canvas instead would leave the glyph swimming in empty space.
INK_X, INK_Y = 28.0, 13.0
MARK_W, MARK_H = 44.0, 67.2


def square_svg(fill: str, margin: float, bg: str | None = None) -> str:
    """The mark centred on a square canvas, with [margin] clear on every side.

    Icons must be square, so the canvas is squared here rather than by scaling
    the artwork, which would distort it.
    """
    side = max(MARK_W, MARK_H) + margin * 2
    x = (side - MARK_W) / 2 - INK_X
    y = (side - MARK_H) / 2 - INK_Y
    dots = "".join(
        f'<circle cx="{cx}" cy="{cy}" r="{DOT_R}" fill="{fill}"/>'
        for cx, cy in DOTS
    )
    rect = (
        f'<rect width="{side}" height="{side}" fill="{bg}"/>' if bg else ""
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'width="{side}" height="{side}" viewBox="0 0 {side} {side}">'
        f"{rect}"
        f'<g transform="translate({x} {y})">'
        f'<polygon points="{PEAK}" fill="{fill}"/>'
        f"{dots}"
        f"</g></svg>"
    )


def render(svg: str, out: Path, side: int) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg)
        src = f.name
    subprocess.run(
        [
            "magick",
            "-background",
            "none",
            "-density",
            "600",
            src,
            "-resize",
            f"{side}x{side}!",
            str(out),
        ],
        check=True,
        capture_output=True,
    )
    print(f"{out.relative_to(Path.cwd())}  {side}x{side}")


def feature_graphic(root: Path, out: Path) -> None:
    """The 1024x500 banner Play shows above the listing.

    Play crops the edges on some surfaces, so the artwork stays well inside.
    """
    from PIL import Image, ImageDraw, ImageFont

    width, height = 1024, 500
    canvas = Image.new("RGB", (width, height), INK)

    mark_px = 128
    mark_file = out.parent / "_mark_tmp.png"
    render(square_svg(WHITE, margin=0), mark_file, mark_px)
    mark = Image.open(mark_file).convert("RGBA")
    mark_file.unlink()

    font_path = str(root / "assets/fonts/HankenGrotesk.ttf")
    title = ImageFont.truetype(font_path, 96)
    title.set_variation_by_name("ExtraBold")
    tagline = ImageFont.truetype(font_path, 30)
    tagline.set_variation_by_name("Regular")

    draw = ImageDraw.Draw(canvas)
    gap = 34
    title_w = draw.textlength("Hulaki", font=title)
    block_w = mark_px + gap + title_w
    x = (width - block_w) / 2
    mid = height / 2 - 30

    canvas.paste(mark, (int(x), int(mid - mark_px / 2)), mark)
    draw.text(
        (x + mark_px + gap, mid),
        "Hulaki",
        font=title,
        fill=WHITE,
        anchor="lm",
    )
    draw.text(
        (width / 2, mid + 140),
        TAGLINE,
        font=tagline,
        fill="#8C887F",
        anchor="mm",
    )
    canvas.save(out)
    print(f"{out.relative_to(Path.cwd())}  {width}x{height}")


def main() -> None:
    root = Path(__file__).resolve().parent.parent

    # The app icon: white mark on the ink square.
    render(
        square_svg(WHITE, margin=17, bg=INK),
        root / "assets/icon/app_icon.png",
        1024,
    )

    # Android adaptive foreground: the launcher masks and zooms it, so the mark
    # sits well inside a transparent square.
    render(
        square_svg(WHITE, margin=30),
        root / "assets/icon/app_icon_foreground.png",
        1024,
    )

    icon = square_svg(WHITE, margin=17, bg=INK)
    render(icon, root / "pages/icon-512.png", 512)

    favicon = root / "pages/favicon.svg"
    favicon.write_text(icon)
    print(f"{favicon.relative_to(Path.cwd())}  svg")

    feature_graphic(
        root,
        root / "pages/feature-graphic.png",
    )


if __name__ == "__main__":
    main()
