#!/usr/bin/env python3
"""Convierte una imagen (PNG, JPG, etc.) a image.hex para el panel 64x64.

Uso:
    python3 img2hex.py foto.png                    # genera image.hex
    python3 img2hex.py foto.png -b 0.5             # al 50 % de brillo (menos consumo)
    python3 img2hex.py foto.png -o otra.hex --fit  # sin deformar: bordes negros

Formato de salida: 4096 lineas RRGGBB, fila por fila (fila 0 primero, 64 columnas cada una).
Requiere Pillow:  pip install pillow
"""
import argparse
from PIL import Image

SIZE = 64


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("entrada", help="imagen de entrada")
    ap.add_argument("-o", "--salida", default="image.hex", help="archivo de salida (por defecto image.hex)")
    ap.add_argument("-b", "--brillo", type=float, default=1.0,
                    help="factor de brillo de 0.0 a 1.0 (por defecto 1.0)")
    ap.add_argument("--fit", action="store_true",
                    help="mantiene la proporcion y rellena con negro; sin esto recorta al centro")
    args = ap.parse_args()

    img = Image.open(args.entrada).convert("RGBA")

    # Fondo negro para las zonas transparentes
    fondo = Image.new("RGBA", img.size, (0, 0, 0, 255))
    img = Image.alpha_composite(fondo, img).convert("RGB")

    if args.fit:
        # Cabe completa dentro de 64x64, con bordes negros
        img.thumbnail((SIZE, SIZE), Image.LANCZOS)
        lienzo = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
        lienzo.paste(img, ((SIZE - img.width) // 2, (SIZE - img.height) // 2))
        img = lienzo
    else:
        # Recorta al centro con proporcion 1:1 y escala a 64x64
        lado = min(img.size)
        izq = (img.width - lado) // 2
        arr = (img.height - lado) // 2
        img = img.crop((izq, arr, izq + lado, arr + lado)).resize((SIZE, SIZE), Image.LANCZOS)

    k = max(0.0, min(1.0, args.brillo))
    with open(args.salida, "w") as f:
        for y in range(SIZE):
            for x in range(SIZE):
                r, g, b = img.getpixel((x, y))
                f.write("%02X%02X%02X\n" % (round(r * k), round(g * k), round(b * k)))

    print("Listo: %s (%d lineas)" % (args.salida, SIZE * SIZE))


if __name__ == "__main__":
    main()
