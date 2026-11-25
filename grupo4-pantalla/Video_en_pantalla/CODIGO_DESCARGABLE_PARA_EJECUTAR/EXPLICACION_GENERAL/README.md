# Controlador HUB75 64x64 + video por UART - Tang Nano 9K

El panel se refresca solo (unos 182 Hz). Los cuadros nuevos llegan del PC por el
puerto USB de la placa (UART) y se guardan en una memoria con **doble buffer**:
el panel muestra un banco mientras el siguiente cuadro se escribe en el otro,
y el cambio se hace entre dos fotogramas del panel. Nunca se ve un cuadro a medias.

```
video.mp4 -> ffmpeg -> video2panel.py --USB/UART--> uart_rx -> img_loader -> framebuffer (2 bancos) -> panel HUB75
                                                                                 ^
                                                          hub75_control + hub75_datapath (refresco)
```

## Archivos (todos en esta carpeta)
| Archivo | Que hace |
|---|---|
| `framebuffer.v` | Memoria de imagen: 2 bancos, lectura para el panel y escritura desde el UART |
| `hub75_datapath.v` | Contadores (col, row, plane, timer), registros RGB y direccion de fila |
| `hub75_control.v` | FSM de 10 estados; ademas emite `frame_done` al terminar cada fotograma |
| `hub75_top.v` | Une todo y controla el cambio de banco (`disp_bank`, `wr_bank`, `pend`) |
| `uart_rx.v` | Receptor UART 8N1 (bytes desde el PC) |
| `img_loader.v` | Cabecera `AA 55` + pixeles -> escrituras en el framebuffer (RGB565 o RGB888) |
| `tang_nano_9k_top.v` | Modulo superior de la placa: S1 = reset, parametros `BAUD` y `BPP` |
| `tang_nano_9k.cst` | Pines (incluye `uart_rx` = pin 18) |
| `video2panel.py` | Script del PC: video/imagen -> flujo serie |
| `img2hexpp.py` | Imagen -> `image.hex` (imagen inicial que se ve al encender) |
| `hub75_tb.v`, `video_tb.v` | Testbenches (panel solo / extremo a extremo con UART) |
| `image.hex` | Imagen inicial 64x64. `image_top.hex` e `image_bot.hex` se generan de ella |

## Uso rapido
```
make config                      # sintetiza y carga a la SRAM (se pierde al apagar)
python3 video2panel.py --listar  # ver puertos serie (la placa crea DOS: JTAG y UART)
python3 video2panel.py --barras -p /dev/ttyUSB1          # prueba del enlace
python3 video2panel.py video.mp4 -p /dev/ttyUSB1 --loop  # video
```
Requisitos del PC: `ffmpeg` y `pip install pyserial`.
En Windows el puerto es del estilo `COM5`. Si no pasa nada con un puerto, prueba el otro.

Atajo: `make play VIDEO=video.mp4 PORT=/dev/ttyUSB1`

## Opciones del script
| Opcion | Efecto |
|---|---|
| `--brillo 0.5` | 0.0 a 1.0. A pleno brillo el panel consume mucha corriente |
| `--gamma 2.2` | El panel es lineal; 2.2 hace que el video se vea natural (1.0 la desactiva) |
| `--fit` | No recorta: mantiene proporcion con bordes negros (por defecto recorta al centro) |
| `--espejo` / `--voltear` | Voltear horizontal / vertical (segun el cableado del panel) |
| `--fps N` | Por defecto usa el maximo que permite el enlace |
| `--loop` | Repite el video |
| `--rgb888` | 3 bytes por pixel en vez de 2 (debe coincidir con `BPP=3` en el FPGA) |
| `--dump archivo` | Guarda el flujo en un archivo en vez de enviarlo |

## Velocidad
Cada cuadro RGB565 son 8194 bytes (RGB888: 12290). Con la pausa de 30 ms entre cuadros:

| Baudios | RGB565 | RGB888 |
|---|---|---|
| 115200 | ~1,4 fps | ~0,9 fps |
| 460800 | ~4,8 fps | ~3,2 fps |
| 921600 | ~8,4 fps | ~5,5 fps |
| 2000000 | ~14 fps | ~9,5 fps |

`BAUD` y `BPP` del FPGA deben coincidir con el script: `make config BAUD=460800 BPP=2`
y `--baud 460800`. Si la imagen sale corrida o con basura, baja los baudios.

## Protocolo
`0xAA 0x55` y despues 4096 pixeles, fila por fila (fila 0 primero).
- RGB565: 2 bytes por pixel, `{R[4:0],G[5:3]}` y `{G[2:0],B[4:0]}`.
- RGB888: 3 bytes por pixel: R, G, B.

Si pasan 20 ms sin recibir ningun byte en medio de un cuadro, el FPGA lo descarta
y vuelve a buscar la cabecera. Por eso el script deja 30 ms de silencio tras cada cuadro.

## Simulacion
    make sim          # panel solo (debe imprimir PASS)
    make sim-video    # UART + doble buffer + panel completo (~1 min, debe imprimir PASS)

`make sim-video` envia cuadros por UART y comprueba cada bit que sale por los pines
HUB75. Cubre: cuadro nuevo durante el refresco, cuadro truncado + resincronizacion
y dos cuadros seguidos sin pausa.

## Conexiones y precauciones
Igual que antes (pines 25-30, 33-35, 40-42, 51, 53, reloj 52, S1 = pin 4), mas el UART:
pin 18 = `uart_rx` (FPGA_RX del puente USB). No hay que cablear nada: va por el USB de la placa.

- El panel se alimenta con una fuente de 5 V (4 A o mas) APARTE. Nunca desde la placa.
- Une todas las masas: fuente, FPGA y pines GND (4 y 16) del conector HUB75.
- Los pines de la FPGA son de 3.3 V y NO toleran 5 V.
- Si hay colores erroneos o parpadeo, usa un buffer 74HCT245 o 74AHCT245 (alimentado a 5 V).
- No uses los pines 79-88, 69-75, 36-39, 3-4 (excepto S1), 10-16.

## Notas
- Al encender se ve `image.hex` hasta que llegue el primer cuadro. S1 no recarga la imagen.
- Si llegan cuadros sin pausa entre ellos, durante un fotograma del panel (~5,5 ms) las primeras
  filas pueden mostrar contenido del cuadro siguiente. Con la pausa del script no ocurre.
- La memoria usa 12 de los 26 bloques BSRAM (se fuerza con `ram_style = "block"`; sin eso Yosys
  la convierte en LUTs y no cabe).
