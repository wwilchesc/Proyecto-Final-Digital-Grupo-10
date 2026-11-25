# Integración 1ª etapa: SoC del Lab 4 + panel HUB75 (Grupo 4) + juego (Grupo 5)

## Qué se hizo

| Pieza | Origen | Dónde queda en el Grupo 6 |
|---|---|---|
| FemtoRV32 + RAM + UART + mult + GPIO | `Lab4/soc/` y `Lab4/rtl/perip_gpio.v` | `soc/` y `rtl/perip_gpio.v` (copia) |
| Controlador HUB75 (datapath y FSM) | `grupo4-pantalla/.../PRUEBA_2/` | `rtl/hub75/hub75_datapath.v`, `hub75_control.v` (copia sin cambios) |
| Framebuffer con puerto de escritura | nuevo (basado en `framebuffer.v` del Grupo 4) | `rtl/hub75/hub75_fb.v` |
| Panel con framebuffer del bus | nuevo (basado en `hub75_top.v` del Grupo 4) | `rtl/hub75/hub75_panel.v` |
| Periférico MMIO del panel | nuevo | `rtl/perip_hub75.v` |
| Decodificador con bloques HUB75 | `Lab4/soc/chip_select.v` ampliado | `soc/chip_select.v` |
| Motor de juego y menú | `grupo5-juego-menu/firmware/` | **no se copia**: `soc/Makefile` y `soc/firmware/build_firmware.sh` lo compilan desde la carpeta del Grupo 5 |
| Arranque, adaptador de plataforma | nuevo | `soc/firmware/main.c`, `crt0.S` y `linker.ld` (Lab4), `minilib.c` |

Las carpetas `grupo4-pantalla/` y `grupo5-juego-menu/` no se modificaron.

## Mapa de memoria

| Dirección | Bloque | Estado |
|---|---|---|
| `0x0000_0000`–`0x0000_7FFF` | RAM 32 KB: programa, datos y pila (pila en `0x8000`) | Simulado y sintetizado |
| `0x0040_0000` | UART | Del Lab 4, sin cambios |
| `0x0041_0000` | GPIO: `LEDS` en `+0x04`, `BOTONES` en `+0x08` | Del Lab 4. Ver conflicto abajo |
| `0x0042_0000` | Multiplicador | Del Lab 4 |
| `0x0043_0000`–`0x0045_0000` | Libres | Reservados (`0x0043`: joystick del Grupo 2 según la propuesta) |
| `0x0048_0000`–`0x0048_3FFC` | **Framebuffer HUB75** (solo escritura) | Implementado y simulado |
| `0x004C_0000` | Control HUB75 | Reservado: lectura `0`, escritura ignorada |

Las direcciones del panel son las que propuso el Grupo 5 en `docs/contratos-MMIO.md` (`0x480000` y `0x4C0000`). Para que el decodificador las vea, `chip_select` pasó de 7 a 9 selecciones.

### Contrato del framebuffer

- Una **palabra de 32 bits por píxel**. Pixel `(x, y)` está en `base + 4*(y*64 + x)`.
- Solo se usan los bits `[2:0]` = `{R, G, B}`, que es el formato lógico del Grupo 5 (8 colores). El hardware lo expande a RGB888 (`1` → `0xFF`, `0` → `0x00`).
- Escritura sin máscara de bytes necesaria. La lectura siempre devuelve `0`.
- Sin doble buffer ni arbitraje. La CPU y el barrido comparten reloj de 27 MHz; puede verse rasgado mientras se dibuja un cuadro.
- Un cuadro completo son 4096 escrituras.

Esto responde a las preguntas abiertas 1 del contrato del Grupo 5 (un píxel = una palabra, sin escritura por byte, sin doble buffer por ahora). Hay que confirmarlo con el Grupo 4.

## Decisiones de esta etapa

1. **Framebuffer de 3 bits por píxel, no RGB888.** Con 24 bits por píxel el SoC necesitaba 30 bloques BSRAM y la GW1N-9 solo tiene 26. Con 4 bits por palabra (3 usados) baja a 20. La expansión a color es combinacional, así que la latencia de lectura del barrido no cambia.
2. **Entradas.** Los pulsadores S1 y S2 hacen de J1 y J2. Los ejes de los joysticks van centrados. El menú solo responde a los pulsadores hasta que el Grupo 2 conecte el MCP3008.
3. **Temporización.** El SoC no tiene timer. El paso de lógica del juego usa un bucle de retardo (`FRAME_DELAY_LOOPS` en `main.c`) con un valor provisional. Hay que calibrarlo en la placa.
4. **Sonido.** No conectado (`play_sound = NULL`).
5. **Sin copia del motor del juego.** Cualquier cambio del Grupo 5 se compila aquí directamente.

## Resultados de verificación

| Comprobación | Resultado |
|---|---|
| `make firmware` (riscv64-unknown-elf-gcc, `-std=c11 -Wall -Wextra`) | OK: programa de 12 064 bytes con el splash y el menú actuales (9 208 bytes en la primera integración) |
| `make sim CICLOS=2000000` (Icarus sobre el SoC aplanado) | **PASS**: 4096 escrituras al framebuffer, 982 píxeles distintos de cero |
| `make syn` (Yosys + nextpnr + gowin_pack) | OK: `build/top.fs` generado |
| Uso GW1N-9 | LUT4 2409/8640 (27 %), DFF 712/6480 (10 %), BSRAM 20/26 (76 %; el Lab 4 usaba 18) |
| Frecuencia máxima | 57.8 MHz (la placa usa 27 MHz) |

### Qué NO está verificado

Actualización del 24/11/2026: el panel sí muestra el splash y el menú en la placa, con el bitstream de la versión actual. Lo que sigue sin verificar:

- Fila D del conector: la serigrafía dice `C / NC` en la fila 6. El SoC conecta `addr[3]` al pin 35, que supone D cableado. Hay que medirlo sin energía.
- Niveles de tensión: la FPGA entrega 3,3 V y el Grupo 4 recomienda un 74AHCT245 para el panel. Ese buffer no está en la conexión actual.
- Fuente de 5 V: la corriente real no está medida.
- La velocidad de juego (retardo sin calibrar).
- Los joysticks reales y el sonido.

## Problemas encontrados (para no repetirlos)

- **nextpnr solo lee la primera sentencia de cada línea del `.cst`.** Si `IO_LOC` e `IO_PORT` van en la misma línea, el `IO_PORT` se ignora y el gowin_pack falla con `Different IO standard for bank 2`. Cada sentencia debe ir en su línea.
- **Un SoC con el framebuffer en RGB888 no cabe en la GW1N-9** (BSRAM 30/26). Por eso el almacenamiento es de 3 bits.

## Conflictos con la tabla de direcciones del Grupo 5

`docs/contratos-MMIO.md` (Grupo 5) propone otra asignación en varias bases que el Lab 4 ya ocupa:

| Base propuesta | Propuesta del Grupo 5 | Lo que hay en el Lab 4 |
|---|---|---|
| `0x410000` | SPI-RAM (Grupo 1) | GPIO |
| `0x420000` | SPI-Flash (Grupo 1) | Multiplicador |

Hace falta decidir si el GPIO y el multiplicador se mueven o si el Grupo 1 usa otras bases. Esta etapa mantiene las del Lab 4.

## Pendientes

- [ ] Confirmar con el Grupo 4 el contrato del framebuffer (palabra por píxel, bits `[2:0]`, sin doble buffer) y definir qué hace el registro de control `0x4C0000`.
- [ ] Prueba física de colores y filas con la fuente de 5 V y el adaptador de nivel. Confirmar el pin `NC`.
- [ ] Añadir un timer MMIO y sustituir el bucle de retardo.
- [ ] Conectar el joystick MCP3008 del Grupo 2 en `read_inputs()` (`soc/firmware/main.c`).
- [ ] Resolver el conflicto de direcciones `0x410000` / `0x420000`.
- [ ] Sonido y récords en EEPROM (Grupos 3 y 1).
