#!/usr/bin/env python3
"""
Genera los iconos de BlackReader a partir de una sola imagen fuente.

USO:
    python tools/make_icons.py            # regenera desde branding/app_icon_source.png
    dart run flutter_launcher_icons       # luego, los iconos nativos
    dart run flutter_native_splash:create # y el splash nativo

QUÉ SALE DE AQUÍ (nada de esto se edita a mano):

    branding/icon_master.png     -> flutter_launcher_icons.image_path
    branding/icon_adaptive.png   -> flutter_launcher_icons.adaptive_icon_foreground
    branding/splash_master.png   -> flutter_native_splash.image
    assets/branding/app_icon.png -> el cubo que pinta BrandTitle dentro de la app

POR QUÉ CADA TAMAÑO (medido, no a ojo):

  * `branding/` NO está en la sección `assets:` del pubspec, así que esos tres
    archivos se usan al generar y NO viajan dentro del APK. El único que se
    empaqueta es `assets/branding/app_icon.png`, y por eso va a 512 px: lo pinta
    `_Cube` a 22–72 px lógicos (216 px físicos a 3x), de sobra.

  * El adaptativo va al 62 % porque Android recorta el icono con una máscara
    (círculo, squircle, lo que ponga el launcher) y solo garantiza el 66 %
    central. Al 88 % se le comerían las esquinas al cubo.

  * El splash va al 60 % y SIN canal alfa, aplanado sobre el mismo off-white de
    fondo. Android lo pinta dentro de una casilla de tamaño fijo, así que se ve
    igual de grande venga al 60 % o al 88 %, pero al 88 % son 2,6x más píxeles
    de textura que comprimir: probado, eran 7 MB más de APK para idéntico
    resultado en pantalla. El alfa es caro por la misma razón (la sombra
    difuminada no comprime), y como el fondo del splash es exactamente este
    color, aplanarlo no cambia nada de lo que se ve.
"""

import pathlib
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit('Falta Pillow:  pip install Pillow')

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'branding' / 'app_icon_source.png'

CANVAS = 1254

#: Mismo off-white que AppTheme.background y que flutter_native_splash.color.
SPLASH_BACKGROUND = (0xFA, 0xF8, 0xF4)


def cube() -> Image.Image:
    """La fuente, recortada al cubo.

    El recorte va por `alfa > 10` a propósito: alrededor del cubo hay un halo
    de sombra casi invisible que llega hasta el borde del lienzo y que, si se
    tomara como contenido, se comería todo el margen útil.
    """
    src = Image.open(SOURCE).convert('RGBA')
    mask = src.getchannel('A').point(lambda v: 255 if v > 10 else 0)
    return src.crop(mask.getbbox())


def square(art: Image.Image, canvas: int, fill: float) -> Image.Image:
    """Centra [art] en un lienzo cuadrado transparente ocupando [fill] del lado."""
    width, height = art.size
    scale = (canvas * fill) / max(width, height)
    small = art.resize((round(width * scale), round(height * scale)), Image.LANCZOS)
    out = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    out.paste(small, ((canvas - small.width) // 2, (canvas - small.height) // 2), small)
    return out


def flatten(image: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    """Quita el canal alfa componiendo sobre [color]."""
    out = Image.new('RGB', image.size, color)
    out.paste(image, (0, 0), image)
    return out


def main() -> None:
    if not SOURCE.exists():
        sys.exit(f'No encuentro la fuente: {SOURCE}')

    art = cube()
    print(f'fuente {SOURCE.name}: cubo recortado a {art.size[0]}x{art.size[1]}')

    outputs = {
        ROOT / 'branding' / 'icon_master.png': square(art, CANVAS, 0.88),
        ROOT / 'branding' / 'icon_adaptive.png': square(art, CANVAS, 0.62),
        ROOT / 'branding' / 'splash_master.png':
            flatten(square(art, CANVAS, 0.60), SPLASH_BACKGROUND),
        ROOT / 'assets' / 'branding' / 'app_icon.png': square(art, 512, 0.88),
    }
    for path, image in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path, optimize=True)
        kb = path.stat().st_size / 1024
        print(f'  {path.relative_to(ROOT).as_posix():38s} {image.size[0]:4d}px '
              f'{image.mode:5s} {kb:7.0f} KB')

    print('\nAhora:  dart run flutter_launcher_icons'
          '  &&  dart run flutter_native_splash:create')


if __name__ == '__main__':
    main()
