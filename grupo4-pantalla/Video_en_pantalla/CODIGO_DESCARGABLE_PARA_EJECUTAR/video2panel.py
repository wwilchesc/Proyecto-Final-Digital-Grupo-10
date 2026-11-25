#!/usr/bin/env python3
"""Envia un video (o una imagen) al panel HUB75 64x64 por el UART de la Tang Nano 9K.

Como funciona:
    ffmpeg decodifica el video, lo escala a 64x64 y entrega los cuadros en bruto.
    Este script les aplica brillo y gamma, los convierte a RGB565 (o RGB888) y
    envia por el puerto serie:   0xAA 0x55  +  4096 pixeles (fila por fila).

Requisitos:
    ffmpeg en el PATH        (sudo apt install ffmpeg  /  https://ffmpeg.org)
    pip install pyserial

Ejemplos:
    python3 video2panel.py --listar                           # ver puertos serie
    python3 video2panel.py --barras -p /dev/ttyUSB1           # prueba del enlace
    python3 video2panel.py foto.png -p /dev/ttyUSB1           # una imagen
    python3 video2panel.py video.mp4 -p COM5 --loop           # video en bucle (Windows)
    python3 video2panel.py video.mp4 -p /dev/ttyUSB1 --fit    # sin recortar (bordes negros)
    python3 video2panel.py video.mp4 --dump salida.bin        # guardar el flujo, sin puerto

La velocidad (--baud) y el formato (--rgb888) deben coincidir con los del FPGA:
    make config BAUD=921600 BPP=2        <->   --baud 921600        (RGB565)
    make config BAUD=921600 BPP=3        <->   --baud 921600 --rgb888
"""
import argparse
import shutil
import subprocess
import sys
import time

W = H = 64
NPIX = W * H
HEADER = b"\xAA\x55"
RAW_SIZE = NPIX * 3          # un cuadro RGB24 que entrega ffmpeg


def tabla_brillo_gamma(brillo, gamma):
    """Tabla de 256 entradas: aplica gamma (el panel es lineal) y brillo."""
    brillo = max(0.0, min(1.0, brillo))
    return bytes(min(255, round(255 * brillo * (v / 255) ** gamma)) for v in range(256))


def convertir(cuadro_rgb24, tabla, rgb888):
    """RGB24 de ffmpeg -> bytes que espera el FPGA (sin la cabecera)."""
    c = cuadro_rgb24.translate(tabla)
    if rgb888:
        return c
    out = bytearray(NPIX * 2)
    for i in range(NPIX):
        r, g, b = c[3 * i], c[3 * i + 1], c[3 * i + 2]
        v = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)     # RGB565
        out[2 * i] = v >> 8
        out[2 * i + 1] = v & 0xFF
    return bytes(out)


def cuadro_barras():
    """Imagen de prueba: barras de color arriba y rampa de grises abajo."""
    barras = [(255, 255, 255), (255, 255, 0), (0, 255, 255), (0, 255, 0),
              (255, 0, 255), (255, 0, 0), (0, 0, 255), (0, 0, 0)]
    out = bytearray()
    for y in range(H):
        for x in range(W):
            if y < H // 2:
                out += bytes(barras[x // 8])
            else:
                out += bytes([x * 255 // (W - 1)] * 3)
    return bytes(out)


def filtro_ffmpeg(args, fps):
    if args.fit:
        f = (f"scale={W}:{H}:force_original_aspect_ratio=decrease:flags=lanczos,"
             f"pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:black")
    else:
        f = f"crop=w='min(iw,ih)':h='min(iw,ih)',scale={W}:{H}:flags=lanczos"
    if args.espejo:
        f += ",hflip"
    if args.voltear:
        f += ",vflip"
    return f + f",fps={fps}"


def listar_puertos():
    try:
        from serial.tools import list_ports
    except ImportError:
        sys.exit("Falta pyserial:  pip install pyserial")
    puertos = list(list_ports.comports())
    if not puertos:
        print("No se encontro ningun puerto serie.")
    for p in puertos:
        print(f"{p.device:20s} {p.description}")
    print("\nLa Tang Nano 9K crea DOS puertos: uno es JTAG y el otro es el UART. "
          "Normalmente el UART es el segundo (p. ej. ttyUSB1 o el COM mayor).")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter,
                                 epilog=__doc__.split("\n", 1)[1])
    ap.add_argument("entrada", nargs="?", help="video o imagen (cualquier formato que lea ffmpeg)")
    ap.add_argument("-p", "--puerto", help="puerto serie (ej. /dev/ttyUSB1 o COM5)")
    ap.add_argument("--baud", type=int, default=921600, help="baudios (por defecto 921600)")
    ap.add_argument("--fps", type=float, default=None,
                    help="cuadros por segundo deseados (por defecto: el maximo que permite el enlace)")
    ap.add_argument("--brillo", type=float, default=0.5,
                    help="0.0 a 1.0 (por defecto 0.5; el panel a pleno brillo consume mucha corriente)")
    ap.add_argument("--gamma", type=float, default=2.2,
                    help="correccion gamma (por defecto 2.2; usa 1.0 para desactivarla)")
    ap.add_argument("--rgb888", action="store_true", help="3 bytes por pixel (por defecto RGB565, 2 bytes)")
    ap.add_argument("--fit", action="store_true", help="no recortar: mantiene proporcion con bordes negros")
    ap.add_argument("--espejo", action="store_true", help="voltear horizontalmente")
    ap.add_argument("--voltear", action="store_true", help="voltear verticalmente")
    ap.add_argument("--loop", action="store_true", help="repetir el video indefinidamente")
    ap.add_argument("--pausa", type=float, default=0.03,
                    help="segundos de silencio tras cada cuadro (debe ser MAYOR que el timeout del "
                         "FPGA, 20 ms por defecto)")
    ap.add_argument("--barras", action="store_true", help="enviar una imagen de prueba (sin ffmpeg)")
    ap.add_argument("--dump", metavar="ARCHIVO", help="escribir el flujo en un archivo en vez de usar el puerto")
    ap.add_argument("--listar", action="store_true", help="listar los puertos serie y salir")
    args = ap.parse_args()

    if args.listar:
        listar_puertos()
        return
    if not args.barras and not args.entrada:
        ap.error("indica un video/imagen, o usa --barras")
    if not args.dump and not args.puerto:
        ap.error("indica el puerto con -p (usa --listar para verlos) o usa --dump")

    # ---- limite de velocidad del enlace ----
    bytes_cuadro = len(HEADER) + NPIX * (3 if args.rgb888 else 2)
    t_envio = bytes_cuadro * 10 / args.baud            # 10 bits por byte (8N1)
    fps_max = 1.0 / (t_envio + args.pausa)
    fps = fps_max if args.fps is None else min(args.fps, fps_max)
    if args.fps is not None and args.fps > fps_max:
        print(f"Aviso: a {args.baud} baud el maximo es {fps_max:.1f} fps; se usara ese valor.")
    print(f"Cuadro de {bytes_cuadro} bytes -> {t_envio * 1000:.0f} ms de envio; {fps:.1f} fps")

    tabla = tabla_brillo_gamma(args.brillo, args.gamma)

    # ---- salida: puerto serie o archivo ----
    if args.dump:
        salida = open(args.dump, "wb")
        escribir = salida.write
        pausar = lambda: None
        cerrar = salida.close
    else:
        try:
            import serial
        except ImportError:
            sys.exit("Falta pyserial:  pip install pyserial")
        ser = serial.Serial(args.puerto, args.baud)
        def escribir(b):
            ser.write(b)
            ser.flush()
        pausar = lambda: time.sleep(args.pausa)
        cerrar = ser.close

    # ---- prueba de barras ----
    if args.barras:
        escribir(HEADER + convertir(cuadro_barras(), tabla, args.rgb888))
        cerrar()
        print("Imagen de barras enviada.")
        return

    # ---- video ----
    if not shutil.which("ffmpeg"):
        sys.exit("No encuentro ffmpeg en el PATH.")
    cmd = ["ffmpeg", "-loglevel", "error"]
    if args.loop:
        cmd += ["-stream_loop", "-1"]
    if not args.dump:
        cmd += ["-re"]                                  # entregar cuadros en tiempo real
    cmd += ["-i", args.entrada, "-vf", filtro_ffmpeg(args, fps),
            "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)

    enviados = 0
    t0 = time.monotonic()
    try:
        while True:
            cuadro = proc.stdout.read(RAW_SIZE)
            if len(cuadro) < RAW_SIZE:
                break
            escribir(HEADER + convertir(cuadro, tabla, args.rgb888))
            pausar()
            enviados += 1
            if enviados % 20 == 0:
                print(f"\r{enviados} cuadros, {enviados / (time.monotonic() - t0):.1f} fps reales", end="")
    except KeyboardInterrupt:
        pass
    finally:
        proc.terminate()
        cerrar()
    print(f"\nListo: {enviados} cuadros enviados.")


if __name__ == "__main__":
    main()
