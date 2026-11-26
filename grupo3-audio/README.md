# Grupo 3 · Audio

Periférico de sonido de la consola retro: genera los efectos y la música de los juegos y los envía al amplificador por I2S.

## Integrantes

- John Fernando Franco Rojas
- Yury Tatiana Muños Perdomo
- Gabriel Andrés Arenas Carmona

## Qué hace este grupo

Este subsistema se encarga de la generación, síntesis y reproducción del audio de la consola retro en la FPGA.

- Diseña una **matriz de sonidos**: tabla de frecuencias, duraciones y tipos de onda para los efectos SFX y la música de fondo estilo chiptune.
- Implementa en Verilog el **transmisor I2S**, que convierte las muestras en audio serie.
- Reproduce los sonidos de los juegos **Pac-Man** y **Snake**.

## Resumen técnico

- **Dispositivo:** amplificador DAC Clase D MAX98357A (3.2 W) + parlante de 8 Ω (1–3 W)
- **Protocolo:** I2S (Inter-IC Sound)
- **Tarjeta:** Tang Nano 9K (reloj de 27 MHz)
- **Procesador:** FemtoRV (RISC-V)
- **Dirección base en el mapa de memoria:** `0x47_0000`
- **Pines hacia el MAX98357A:**
  - `BCLK` → GPIO 35
  - `LRCK` → GPIO 36
  - `SDIN` → GPIO 37

## Protocolo I2S

El protocolo I2S (Inter-IC Sound) es un estándar de comunicación síncrono diseñado específicamente para la transferencia de audio digital.

- **Naturaleza síncrona:** es síncrono y unidireccional; la FPGA (maestro) comparte una señal de reloj dedicada con el DAC MAX98357A (esclavo).
- **Señales del bus:**
  - **BCLK (Bit Clock):** reloj de bits a 1.35 MHz, generado al dividir el reloj base de la FPGA (27 MHz) entre 20. Marca el ritmo de envío de cada bit.
  - **LRCK / WS (Word Select):** selecciona el canal y fija la frecuencia de muestreo ($f_s = 42.1875\text{ kHz}$).
  - **DIN / SDIN (Data In):** línea de datos serie con muestras de 16 bits con signo, enviando primero el bit más significativo (MSB).
- **Formato de trama:** cada trama completa dura 32 ciclos de BCLK (16 bits para el canal mono).

## Estructura del repositorio

```
grupo3-audio/
├── Diagramas/
├── docs/
├── Implementacion/
│   └── soc_Peri_Audio/
│       ├── boards/
│       ├── build/
│       ├── firmware/
│       ├── rtl/
│       ├── sim/
│       └── Makefile
├── Tests/
│   ├── i2s/
│   └── I2S audio prueba/
├── rtl/
├── sim/
└── README.md
```

## Diagramas/

Diagramas de diseño del periférico de audio.

- Caja negra y diagrama de bloques
- Diagrama de flujo
- FSM y ASMD
- Control–datapath
- Diagrama de tiempos
- Tabla de transiciones y clasificación

## docs/

Documentación de apoyo.

- `MAX98357_ALLDATASHEET.pdf`: datasheet del amplificador MAX98357A
- `Diagrama_de_Flujo.md`: enlace al diagrama de flujo en draw.io
- `caja_negra.png`: caja negra del periférico

## Tests/

Pruebas iniciales del transmisor I2S en la Tang Nano 9K, antes de integrarlo al SoC.

- **`i2s/`**
  - `i2s_transmitter.v`: transmisor I2S
  - `top.v`: generador de melodía para la Tang Nano 9K (con LED de heartbeat)
  - `top_tb.v`: testbench
  - `top.cst`: asignación de pines
  - `Makefile` y `build/`: síntesis y bitstream
- **`I2S audio prueba/`**
  - `i2s_melody_peripheral.v`: periférico con secuenciador de melodías y síntesis DDS
  - `i2s_tx_core.v`: núcleo transmisor I2S
  - `pacman_songs.mem`: ROM de canciones
  - `top_test_hw.v`: top para probar en hardware
  - `tb_i2s_melody.v` e `i2s_test.vcd`: testbench y formas de onda

## Implementacion/soc_Peri_Audio/

SoC completo basado en FemtoRV con el periférico de audio integrado.

- **`rtl/`**: fuentes Verilog del SoC
  - `SOC.v`: módulo principal que conecta CPU, memoria y periféricos
  - `chip_select.v`: decodificación de direcciones del mapa de memoria
  - `perip_audio.v`: periférico MMIO de audio (secuenciador + DDS)
  - `perip_i2s_core.v`: transmisor I2S de 16 bits mono
  - `cpu/`, `memory/`, `mult/`, `uart/`: núcleo FemtoRV, memoria, multiplicador y UART
  - `pacman_songs.mem`: tabla de sonidos de Pac-Man y Snake
- **`firmware/`**: programas en C para el procesador
  - `audio_test.c`: prueba de la lista de sonidos del periférico
  - `soc.h`: direcciones de registros
  - `crt0.S` y `linker.ld`: arranque y mapa de memoria
  - `tools/bin2hex.py`: conversión del binario a `.hex`
  - Programas de ejemplo del curso: `hola.c`, `parpadeo.c`, `gpio.c`, `gpio_aventura.c`
- **`boards/`**: archivos por tarjeta
  - `tangnano9k/`: top y pines (`.cst`)
  - `colorlight/`: top y pines (`.lpf`)
- **`sim/`**: `tb_soc.v`, testbench del SoC completo
- **`build/`**: archivos generados (firmware compilado, bitstream, logs de síntesis)
- **`Makefile`**: automatiza el flujo de trabajo (ver sección siguiente)
- **`firmware.hex`** y **`pacman_songs.mem`**: programa y ROM de sonidos cargados en el SoC

## Cómo usarlo

Desde `Implementacion/soc_Peri_Audio/`:

- `make sim PROG=audio_test`: compila el programa y simula el SoC
- `make syn BOARD=tangnano9k PROG=audio_test`: sintetiza para la Tang Nano 9K
- `make config BOARD=tangnano9k`: configura la FPGA
- `make terminal BOARD=tangnano9k`: abre la terminal serial (salir con `Ctrl-a Ctrl-x`)

## Carpetas reservadas

- `rtl/` y `sim/` en la raíz de `grupo3-audio` solo contienen `.gitkeep`. El código vigente está en `Implementacion/soc_Peri_Audio/`.



