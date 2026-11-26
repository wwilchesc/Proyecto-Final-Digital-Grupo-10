# Grupo 3 · Audio

Periférico de sonido: genera los efectos de la consola y los envía al amplificador.

## Integrantes

- John Fernando Franco Rojas
- Yury Tatiana Muños Perdomo
- Gabriel Andrés Arenas Carmona

## Qué hace este grupo

Este subsistema se encarga de la generación, síntesis y reproducción del audio de la consola retro en la FPGA. La función principal del grupo es diseñar e implementar una matriz de sonidos (tabla de frecuencias, duraciones y tipos de onda para los efectos SFX y la música de fondo estilo chiptune), así como el módulo transmisor I2S en Verilog que convierte los datos en audio serie para reproducir los sonidos de los juegos Pac-Man y Snake.

- Dispositivo(s): Amplificador DAC Clase D MAX98357A (3.2 W) + parlante de 8 Ω (1–3 W)
- Protocolo: I2S (Inter-IC Sound)
- Dirección base en el mapa de memoria: `0x47_0000` 

## Protocolo I2S

El protocolo I2S (Inter-IC Sound) es un estándar de comunicación síncrono diseñado específicamente para la transferencia de audio digital.

* **Naturaleza síncrona:** Es un protocolo síncrono y unidireccional que comparte una señal de reloj dedicada entre la FPGA (maestro) y el DAC MAX98357A (esclavo).
* **Señales del bus:**
  * **BCLK (Bit Clock):** Reloj de bits a 1.35 MHz, generado al dividir el reloj base de la FPGA (27 MHz) entre 20. Marca el ritmo de envío de cada bit individual.
  * **LRCK / WS (Word Select):** Reloj de selección de canal que establece la frecuencia de muestreo de audio ($f_s = 42.1875\text{ kHz}$). Determina si el dato en tránsito pertenece al canal izquierdo o al derecho.
  * **DIN (Data In):** Línea de datos serie donde se transmiten las muestras de 16 bits con signo, enviando siempre el bit más significativo primero (MSB).
* **Formato de trama:** Cada trama completa dura 32 ciclos de BCLK (16 bits para el canal mono).

## Diagramas

Diagramas de diseño del periférico de audio: caja negra, diagrama de bloques, diagrama de flujo, FSM, ASMD, control–datapath, tiempos, tabla de transiciones y clasificación.

## docs

Documentación de apoyo: datasheet del amplificador MAX98357A (MAX98357_ALLDATASHEET.pdf), el diagrama de flujo en draw.io (Diagrama_de_Flujo.md) y la caja negra del periférico.

## Tests

Pruebas iniciales del transmisor I2S en la Tang Nano 9K, antes de integrarlo al SoC.

i2s/: transmisor I2S (i2s_transmitter.v) con un top.v que genera una melodía, su testbench (top_tb.v), restricciones de pines (top.cst), Makefile y archivos de síntesis en build/.
I2S audio prueba/: versión con periférico de melodías (i2s_melody_peripheral.v), núcleo I2S (i2s_tx_core.v), ROM de canciones (pacman_songs.mem), top para hardware, testbench (tb_i2s_melody.v) y forma de onda de simulación (i2s_test.vcd).
Implementacion/soc_Peri_Audio/

## SoC completo basado en FemtoRV con el periférico de audio integrado (base 0x47_0000).

rtl/: fuentes Verilog del SoC.
SOC.v: módulo principal que conecta CPU, memoria y periféricos.
chip_select.v: decodificación de direcciones del mapa de memoria.
perip_audio.v: periférico MMIO de audio (secuenciador de melodías + síntesis DDS).
perip_i2s_core.v: transmisor I2S de 16 bits mono (control + datapath).
cpu/, memory/, mult/, uart/: núcleo FemtoRV, memoria, multiplicador y UART.
pacman_songs.mem: tabla de sonidos/melodías de Pac-Man y Snake.
firmware/: programas en C para el procesador (audio_test.c prueba los 16 sonidos), junto con soc.h (direcciones de registros), crt0.S, linker.ld y tools/bin2hex.py. Incluye también programas de ejemplo del curso (hola.c, parpadeo.c, gpio.c, gpio_aventura.c).
boards/: archivos específicos por tarjeta: tangnano9k/ (top y pines .cst) y colorlight/ (top y pines .lpf).
sim/: testbench del SoC completo (tb_soc.v).
build/: archivos generados (firmware compilado, bitstream .fs, logs de síntesis).
Makefile: automatiza simulación (make sim), síntesis (make syn), programación de la FPGA (make config) y terminal serial (make terminal).
firmware.hex y pacman_songs.mem: programa y ROM de sonidos cargados en el SoC.





