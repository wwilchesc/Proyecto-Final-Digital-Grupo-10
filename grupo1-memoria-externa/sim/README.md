# Simulación del controlador SPI

## Cómo correrla

Con Icarus Verilog, desde la carpeta `grupo1-memoria-externa`:

```
iverilog -g2012 -o perip_spi_tb.vvp sim/perip_spi_tb.v sim/flash_model.v \
         rtl/perip_spi.v rtl/spi_control.v rtl/spi_datapath.v
vvp perip_spi_tb.vvp
gtkwave perip_spi_tb.vcd
```

O con `make sim` desde esta carpeta.

## Qué se prueba

El banco `perip_spi_tb.v` usa el periférico **por el bus**, igual que lo haría la CPU: escribe y lee los registros MMIO con un acceso de un ciclo, y la lectura llega un ciclo después (lectura registrada). Al otro lado está `flash_model.v`, un modelo de una Flash W25Q64 en modo 0 que entiende los comandos 0x9F, 0x03, 0x06, 0x02 y 0x05.

| Caso | Qué comprueba | Filas de la tabla |
| --- | --- | --- |
| Reset | CLK_DIV = 1, STATUS = 0, CS_n = 1, WP_n = HOLD_n = 1 | R |
| JEDEC ID | Comando sin dirección y 3 bytes: RDATA = 0xEF4017; STATUS = 0x5 en curso, 0x2 al terminar y 0x0 después de leerlo (DONE retenido) | T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T11d, T12 |
| Lectura 0x03 de 1 y de 3 bytes | Comando + dirección de 24 bits + datos | T6 (CMD → DIR → DAT) |
| Lectura de 4 bytes | 3 bytes con MANTENER (CS sigue en 0, STATUS = 0x6) y 1 byte más con CONTINUAR | T8m, T1c |
| CONTINUAR sin datos | NB = 0 y RW = 0: termina sin pulsos de SCK y libera CS | T1n |
| CONTINUAR dos veces seguidas | 8 bytes en tres partes: MANTENER, luego CONTINUAR + MANTENER (CS sigue en 0) y CONTINUAR final que libera CS | T8m, T1c (2 veces) |
| CONTINUAR sin datos con MANTENER | T1n con MANTENER deja CS en 0 sin pulsos de SCK, y el siguiente CONTINUAR lee el byte que sigue (la Flash no perdió la posición) | T1n, T8m, T1c |
| CONTINUAR con CS_n = 1 | Rama "No" del rombo: si CS ya se liberó, CONTINUAR hace la transacción completa (T1) y se lee el JEDEC ID | T1 |
| Escritura | WREN (0x06) y PAGE PROGRAM (0x02) de un byte, y lectura de comprobación | RW = 1 |
| BUSY | Una escritura de registro con BUSY = 1 se ignora | we = cs ∧ wr ∧ ¬BUSY |
| CLK_DIV | Periodo de SCK = 2·(CLK_DIV+1) ciclos: 80 ns con CLK_DIV = 1 y 160 ns con CLK_DIV = 3 a 50 MHz | divisor |
| Reset en medio | Cancela la transacción y deja CS_n = 1 y STATUS = 0 | R |

Al final, el banco cuenta cuántas veces se ejecutó **cada fila de la tabla de transferencias** (H1, H2, T1 … T12) y falla si alguna no se ejecutó. Las filas menos usadas, T1c y T1n, se ejecutan 4 y 2 veces.

## Resultado

```
53 comprobaciones, 0 errores
PASS: perip_spi (MMIO, JEDEC, lectura, MANTENER/CONTINUAR, escritura, BUSY, DONE retenido, reset)
```

La salida completa está en `perip_spi_tb.log`. Las formas de onda están en `perip_spi_tb.vcd` (se abre con GTKWave), y en `ondas_jedec_id.png` y `ondas_jedec_inicio.png`, dibujadas con `vcd_a_png.py`.

## Handshake bus ↔ core

`ondas_handshake_inicio.png` y `ondas_handshake_fin.png` muestran la simulación de la misma lectura del JEDEC ID que dibuja el diagrama `docs/diagramas/9-integracion/Grupo1_Tiempos_Handshake.drawio.png`:

1. La CPU escribe CONTROL = 0x79F01 (START, comando 0x9F, SIN_DIR, NB = 3). En el ciclo siguiente `start` vale 1, BUSY sube y CS_n baja.
2. Mientras la transacción está en curso, STATUS se lee como 0x5 (CS_ACTIVO y BUSY).
3. El core pasa por DONE (`done` de un ciclo). BUSY baja y STATUS.DONE queda en 1.
4. La CPU lee STATUS = 0x2 y DONE se limpia, así que la siguiente lectura da 0x0.
5. La CPU lee RDATA = 0xEF4017.

Para generar las imágenes: `python3 vcd_a_png.py perip_spi_tb.vcd salida.png t_ini t_fin "titulo" handshake`.


---

# Simulación del controlador I2C

## Cómo correrla

Con Icarus Verilog, desde la carpeta `grupo1-memoria-externa`:

```
iverilog -g2012 -o perip_i2c_tb.vvp sim/perip_i2c_tb.v sim/eeprom_model.v \
         rtl/perip_i2c.v rtl/i2c_control.v rtl/i2c_datapath.v
vvp perip_i2c_tb.vvp
gtkwave perip_i2c_tb.vcd
```

O con `make sim-i2c` desde esta carpeta (`make sim` sigue corriendo el SPI y `make todo` corre los dos).

## Qué se prueba

El banco `perip_i2c_tb.v` usa el periférico **por el bus**, igual que el del SPI: escribe y lee los registros MMIO con accesos de un ciclo y lectura registrada. SCL y SDA tienen resistencias de pull-up (`pullup`) y al otro lado está `eeprom_model.v`, un modelo de la 24LC256 (dirección 0x50) que entiende escritura, lectura aleatoria con START repetido y lectura secuencial, responde ACK/NACK y puede estirar el reloj.

| Caso | Qué comprueba | Filas de la tabla |
| --- | --- | --- |
| Reset | CLK_DIV = 124, STATUS = 0x2 (ACK_IN = 1), SCL y SDA sueltas | R |
| START + 0xA0 | DONE al terminar, ACK de la EEPROM (ACK_IN = 0), periodo de SCL medido (10 220 ns ≈ 97,8 kHz) y bus libre después del STOP | T1, T1w, T1p, T2 … T7 |
| Escritura de un byte | 0x5C en la dirección 0x0012: ACK en dispositivo, dirección alta, dirección baja y dato; la EEPROM lo guarda | T1w, T3, T4 |
| Lectura aleatoria | START repetido, 0xA1, lectura con NACK: RX_DATA = 0x5C | T1r, T3, T4 |
| Lectura secuencial | 2 bytes, el primero con ACK y el segundo con NACK: 0x11 y 0x22 | T1r |
| Dirección que no existe | Nadie responde: ACK_IN = 1 | T4 |
| Prioridad | START y WRITE en la misma orden: solo se hace START | T1 |
| Estiramiento de reloj | La EEPROM mantiene SCL en 0 3 µs después de cada ACK; el maestro espera en SCL_WAIT | H2, T5 |
| BUSY | Una escritura de CLK_DIV con BUSY = 1 se ignora | we = cs ∧ wr ∧ ¬BUSY |
| Reset en medio | Suelta SCL y SDA y deja STATUS = 0x2 | R |

Al final, el banco cuenta cuántas veces se ejecutó **cada fila de la tabla de transferencias del I2C** (H1, T1, T1w, T1r, T1p, T2, T3, T4, H2, T5, H3, T6, T6r, T7) y falla si alguna no se ejecutó.

## Resultado

```
36 comprobaciones, 0 errores
PASS: perip_i2c (MMIO, START/STOP, escritura y lectura de la EEPROM, ACK/NACK, prioridad, estiramiento de reloj, BUSY, reset)
```

La salida completa está en `perip_i2c_tb.log`. Las formas de onda quedan en `perip_i2c_tb.vcd` (no se sube al repositorio; se genera al correr la simulación).

**Nota sobre la frecuencia**: con CLK_DIV = 124 a 50 MHz, SCL queda en ≈ 97,8 kHz y no en 100 kHz exactos, porque cada estado de acción gasta un ciclo y el sincronizador de SCL agrega unos más (511 ciclos por bit en vez de 500). Sigue dentro del modo estándar (≤ 100 kHz).

---

# Simulación del bloque completo (`memoria_externa`)

## Cómo correrla

`make sim-mem` desde esta carpeta, o desde `grupo1-memoria-externa`:

```
iverilog -g2012 -o mem.vvp sim/memoria_externa_tb.v sim/flash_model.v sim/eeprom_model.v \
         rtl/memoria_externa.v rtl/perip_spi.v rtl/spi_control.v rtl/spi_datapath.v \
         rtl/perip_i2c.v rtl/i2c_control.v rtl/i2c_datapath.v
vvp mem.vvp
```

## Qué se prueba

El banco `memoria_externa_tb.v` maneja el bloque con **las mismas señales del bus del FemtoRV32 Quark** (`mem_addr`, `mem_wdata`, `mem_wmask`, `mem_rstrb`, `mem_rdata`), con la Flash y la EEPROM conectadas a la vez:

| Caso | Qué comprueba | Diagrama |
| --- | --- | --- |
| Decodificador de región | `sel` = 1 con 0x0042_xxxx y 0x0046_xxxx, y 0 con otra región | Decodificador local |
| Mux de lectura | CLK_DIV del SPI (1) y del I2C (124) por la misma `mem_rdata`; otra región lee 0 | Adaptador de bus |
| Escritura en otra región | No llega a ningún periférico | Adaptador de bus |
| Flash por el bus | JEDEC ID = 0xEF4017 | START / BUSY / DONE |
| EEPROM por el bus | Escribir 0xA5 en 0x0003 y leerlo | START / BUSY / DONE |
| Los dos a la vez | El SPI lee mientras el I2C termina un byte, sin mezclar respuestas | Adaptador de bus |

## Resultado

```
10 comprobaciones, 0 errores
PASS: memoria_externa (decodificador de region, mux de lectura, SPI e I2C por el bus del Quark)
```

La salida completa está en `memoria_externa_tb.log`.

---

# Simulación de la prueba en placa (`fpga/prueba_grupo1.v`)

`make sim-prueba` desde esta carpeta. El banco `prueba_grupo1_tb.v` conecta la prueba en placa con los modelos de la Flash y de la EEPROM, acorta las esperas y sube la velocidad de la UART para que la simulación termine pronto. Decodifica la UART e imprime el reporte tal como saldría en la terminal.

Hace dos corridas: la que arranca sola después del reset (byte de prueba 0x5A) y otra con el botón de repetir (0x5B). En cada una comprueba los LEDs, el byte que quedó grabado en la Flash y en la EEPROM, y que el reporte no diga FALLA. Para esta prueba, `flash_model.v` también entiende el borrado de sector (0x20).

```
8 comprobaciones, 0 errores
PASS: prueba_grupo1 (SPI e I2C por memoria_externa, reporte por UART y LEDs)
```

La salida completa, con los dos reportes, está en `prueba_grupo1_tb.log`. Si se quita la EEPROM del banco, las dos líneas del I2C dicen FALLA y el LED del I2C queda apagado, mientras el SPI sigue en OK.

## Versión para la Tang Nano 9K

`make sim-prueba-9k` simula `fpga/prueba_grupo1_9k.v` con un reloj de 27 MHz. Además de lo mismo que la versión de la 25K, comprueba que la prueba deja `CLK_DIV = 67` en el I2C (unos 99,3 kHz) y que los LEDs encienden con 0. Resultado: **9 comprobaciones, 0 errores** (`prueba_grupo1_9k_tb.log`).
