# RTL del controlador SPI

El código sigue el **Enfoque A** de la guía del curso (`uart_2.pdf`):

- **Cálculo (`always @(*)`, asignación `=`)**: el control decide el próximo estado y las órdenes hacia el datapath a partir del estado actual y de las banderas.
- **Memoria (`always @(posedge clk)`, asignación `<=`)**: los registros del control (`state`, `fase`, `half`) y del datapath (`sh`, `bits`, `rx`, `SCK`, `CS_n`, divisor) se actualizan todos en el flanco de subida.
- Reset síncrono activo alto.

| Archivo | Bloque del diagrama `7-control-datapath` |
| --- | --- |
| `spi_control.v` | CONTROL: FSM de 9 estados, registro de fase, contador `half`, `busy` y `done` |
| `spi_datapath.v` | DATAPATH: divisor (`tick`), mux `val(fase)` / `n(fase)`, `sh` de 32 bits con `MOSI = sh[31]`, contador `bits` con `last = (bits = 1)`, `rx` de 24 bits, registros `SCK` y `CS_n` |
| `perip_spi.v` | Registros MMIO, decodificador local, DONE retenido y lectura registrada; instancia el control y el datapath |

## Correspondencia con la tabla de transferencias

Cada rama del `case` de `spi_control.v` lleva el ID de la fila que implementa:

| ID | Estado y condición | Próximo estado | Órdenes que pone el control | Lo que hace el datapath en el flanco |
| --- | --- | --- | --- | --- |
| H1 | IDLE, START = 0 | IDLE | — | — |
| T1 | IDLE, START ∧ (¬CONTINUAR ∨ CS_n) | CS_SETUP | `cs_low`, `rx_clr` | CS_n ← 0, rx ← 0 |
| T1c | IDLE, START ∧ CONTINUAR ∧ ¬CS_n ∧ hay_datos | LOAD | `rx_clr`; fase ← DAT | rx ← 0 |
| T1n | IDLE, START ∧ CONTINUAR ∧ ¬CS_n ∧ ¬hay_datos | FIN | `rx_clr`; fase ← DAT | rx ← 0 |
| H2 | estado con espera y tick = 0 | el mismo | — | — |
| T2 | CS_SETUP, tick | LOAD | fase ← CMD | — |
| T3 | LOAD | LOW | `load` | sh ← val(fase), bits ← n(fase) |
| T4 | LOW, tick | HIGH | `sck_rise`; `rx_en` si fase = DAT ∧ RW = 0 | SCK ← 1; rx ← {rx, MISO} |
| T5 | HIGH, tick ∧ ¬last | LOW | `sck_fall` | SCK ← 0, sh ← sh << 1, bits ← bits − 1 |
| T6 | HIGH, tick ∧ last ∧ falta fase | LOAD | `sck_fall`; fase ← sig(fase) | SCK ← 0 |
| T7 | HIGH, tick ∧ last ∧ no falta fase | FIN | `sck_fall` | SCK ← 0 |
| T8 | FIN, ¬MANTENER | CS_HOLD | half ← 0 | — |
| T8m | FIN, MANTENER | DONE | — | CS_n sigue en 0 |
| T9 | CS_HOLD, tick ∧ ¬half | CS_HOLD | half ← 1 | — |
| T10 | CS_HOLD, tick ∧ half | CS_REST | `cs_high`; half ← 0 | CS_n ← 1 |
| T11 | CS_REST, tick ∧ ¬half | CS_REST | half ← 1 | — |
| T11d | CS_REST, tick ∧ half | DONE | — | — |
| T12 | DONE | IDLE | `done` = 1 (un ciclo) | — |

En T5, T6 y T7 el control da la misma orden (`sck_fall`). El datapath solo desplaza `sh` y resta en `bits` si `last = 0`, que es justo el caso de T5.

## Decisiones que hay que poder explicar

- **`tick` no es un reloj**: es una habilitación de un ciclo que el divisor genera cada `CLK_DIV + 1` ciclos. SCK cambia en cada tick, por eso SCK = f_clk / (2·(CLK_DIV + 1)).
- **IDLE no toca CS_n**: CS_n es un registro que solo cambian T1 (`cs_low`), T10 (`cs_high`) y el reset. Así MANTENER deja CS en 0 al volver a IDLE, y CONTINUAR puede seguir leyendo.
- **Modo 0**: MOSI = sh[31] queda listo antes de la subida de SCK (T4), y la Flash cambia MISO en la bajada. Por eso `rx` toma MISO en T4.
- **BUSY = busy_core ∨ start**: la orden aceptada ya cuenta como ocupado en el ciclo siguiente, y mientras BUSY = 1 las escrituras de registros se ignoran.
- **DONE retenido**: el pulso `done` del core (T12) pone STATUS.DONE en 1, que se mantiene hasta que la CPU lee STATUS o da una orden nueva.
- **STATUS bit2 = CS_ACTIVO**: permite que el software sepa si CS quedó en 0 por MANTENER; `STATUS = {CS_ACTIVO, DONE, BUSY}`.
