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
| Escritura | WREN (0x06) y PAGE PROGRAM (0x02) de un byte, y lectura de comprobación | RW = 1 |
| BUSY | Una escritura de registro con BUSY = 1 se ignora | we = cs ∧ wr ∧ ¬BUSY |
| CLK_DIV | Periodo de SCK = 2·(CLK_DIV+1) ciclos: 80 ns con CLK_DIV = 1 y 160 ns con CLK_DIV = 3 a 50 MHz | divisor |
| Reset en medio | Cancela la transacción y deja CS_n = 1 y STATUS = 0 | R |

Al final, el banco cuenta cuántas veces se ejecutó **cada fila de la tabla de transferencias** (H1, H2, T1 … T12) y falla si alguna no se ejecutó.

## Resultado

```
43 comprobaciones, 0 errores
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

