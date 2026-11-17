# Controlador HUB75 64x64 (FPGA) - Tang Nano 9K

Derivado del diagrama de flujo corregido (estados T1-T14).

## Archivos
- `rtl/framebuffer.v`         memoria de imagen (2 lecturas sincronas)
- `rtl/hub75_datapath.v`      contadores, registros RGB y direccion
- `rtl/hub75_control.v`       FSM de 10 estados
- `rtl/hub75_top.v`           modulo superior generico (pines HUB75)
- `rtl/tang_nano_9k_top.v`    modulo superior de la PLACA (boton S1 -> reset)
- `constraints/tang_nano_9k.cst`  asignacion de pines
- `constraints/tang_nano_9k.sdc`  reloj de 27 MHz
- `tb/hub75_tb.v`             testbench autoverificable (panel reducido)
- `tools/img2hex.py`          imagen -> image.hex
- `image.hex`                 imagen de prueba 64x64

## Conexiones (FPGA -> conector HUB75 del panel)

| Pin HUB75 | Senal | Pin FPGA | Puerto Verilog |
|---|---|---|---|
| 1  | R1  | 25 | r1 |
| 2  | G1  | 26 | g1 |
| 3  | B1  | 27 | b1 |
| 4  | GND | GND | - |
| 5  | R2  | 28 | r2 |
| 6  | G2  | 29 | g2 |
| 7  | B2  | 30 | b2 |
| 8  | E   | 41 | addr[4] |
| 9  | A   | 33 | addr[0] |
| 10 | B   | 34 | addr[1] |
| 11 | C   | 40 | addr[2] |
| 12 | D   | 35 | addr[3] |
| 13 | CLK | 42 | hub_clk |
| 14 | LAT | 51 | hub_lat |
| 15 | OE  | 53 | hub_oe |
| 16 | GND | GND | - |

Los 14 pines estan en un bloque contiguo del mismo header (25 26 27 28 29 30 33 34 40 35 41 42 51 53).
Reloj: pin 52 (27 MHz). Reset: boton S1, pin 4 (activo en bajo).

## Precauciones electricas
- El panel se alimenta con una fuente de 5 V (4 A o mas) APARTE. Nunca desde la placa.
- Une todas las masas: fuente, FPGA y pines GND (4 y 16) del conector HUB75.
- Los pines de la FPGA son de 3.3 V y NO toleran 5 V.
- Si hay colores erroneos o parpadeo, usa un buffer 74HCT245 o 74AHCT245 (alimentado a 5 V).
- No uses los pines 79-88 (banco de 1.8 V), 69-75 (HDMI), 36-39 (ranura TF), 3-4 (botones), 10-16 (LEDs).

## Simular (Icarus Verilog + GTKWave)
    mkdir -p build
    iverilog -g2012 -Wall -s hub75_tb -o build/hub75_tb \
        rtl/framebuffer.v rtl/hub75_datapath.v rtl/hub75_control.v rtl/hub75_top.v tb/hub75_tb.v
    vvp build/hub75_tb          # debe imprimir PASS
    gtkwave build/hub75_tb.vcd

## Sintetizar con Gowin EDA
1. New Project -> dispositivo GW1NR-9C, parte GW1NR-LV9QN88PC6/I5.
2. Anadir `rtl/framebuffer.v`, `hub75_datapath.v`, `hub75_control.v`, `hub75_top.v`, `tang_nano_9k_top.v`.
3. Anadir `constraints/tang_nano_9k.cst` y `tang_nano_9k.sdc`, y copiar `image.hex` a la carpeta del proyecto.
4. Fijar `tang_nano_9k_top` como modulo superior.
5. Synthesize -> Place & Route -> Programmer (SRAM para probar, Flash para dejarlo grabado).

## Usar otra imagen
    pip install pillow
    python3 tools/img2hex.py mi_foto.png image.hex
