# Diagramas simplificados para la sustentación B.3

## Vista 1 — Escritura de CONTROL

1. CPU coloca dirección 0x004C0000, dato 0, y solicita escritura.
2. Grupo 6 **deberá** identificar la región y activar cs=1 (integración pendiente).
3. El decodificador local B.3 evalúa `cs && wr && !rd && addr == 5'h00` y activa `wr_control`.
4. En el siguiente flanco positivo, CONTROL almacena `DISPLAY_EN=0`.
5. La salida física obedece `hub_oe_panel = hub_oe_core | ~DISPLAY_EN`; por tanto, OE=1, pantalla apagada.

Las flechas muestran el **flujo lógico** de una petición, no todos los cables reales del bus: la dirección y los datos deben llegar al adaptador, no necesariamente atravesar físicamente el decodificador global.

## Vista 2 — Lectura de registros

`addr[4:0]` permite escoger los offsets `0x00` (CONTROL), `0x04` (STATUS) y `0x08` (FRAMES). La señal de selección `rd_control`, `rd_status` o `rd_frames` elige qué valor se almacena en `d_out` en un flanco positivo de reloj. El SoC deberá esperar esa latencia.

## Límites importantes

- No implementa el framebuffer MMIO de píxeles de 0x00480000.
- No implementa START/BUSY/DONE.
- `STATUS` solo reporta `DISPLAY_EN`.
- `FRAMES` está implementado como contador, pero `frame_done` todavía requiere conexión desde el controlador HUB75E.
- La decodificación global de 0x004C0000 corresponde al Grupo 6 y sigue pendiente.
- El diseño fue preparado con apoyo de IA y debe revisarse y verificarse antes de atribuir autoría o decir que está integrado.
