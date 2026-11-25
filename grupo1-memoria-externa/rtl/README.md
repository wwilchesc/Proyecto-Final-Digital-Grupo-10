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

---

# RTL del controlador I2C

Mismo **Enfoque A** que el SPI: el control calcula el próximo estado y las órdenes en `always @(*)`, y todos los registros (los del control y los del datapath) se actualizan en el flanco de subida con reset síncrono activo alto.

| Archivo | Bloque del diagrama `7-control-datapath` |
| --- | --- |
| `i2c_control.v` | CONTROL: FSM de 17 estados (IDLE, ST_1…ST_4, B_1…B_4, B_END, SP_1…SP_4, SCL_WAIT, WAIT y DONE), registros `n`, `ret` e `is_read`, `busy` y `done` |
| `i2c_datapath.v` | DATAPATH: contador de cuarto (`tick`), contador `bcnt` con `bit_last = (bcnt = 8)`, registro `tx` de 8 bits que desplaza, registro `rx`, registro `ACK_IN`, selector `sda_bit`, sincronizadores de 2 etapas para SCL y SDA y salidas de drenador abierto `scl_oe`, `sda_oe` |
| `perip_i2c.v` | Registros MMIO (CONTROL, TX_DATA, RX_DATA, STATUS, CLK_DIV), decodificador local, DONE retenido, lectura registrada y pines `i2c_scl`, `i2c_sda`; instancia el control y el datapath |

## Correspondencia con la tabla de transferencias

Cada rama del `case` de `i2c_control.v` lleva el ID de la fila que implementa:

| ID | Estado y condición | Próximo estado | Órdenes que pone el control | Lo que hace el datapath en el flanco |
| --- | --- | --- | --- | --- |
| H1 | IDLE, go = 0 | IDLE | — | — |
| T1 | IDLE, go ∧ START | ST_1 | — | — |
| T1w | IDLE, go ∧ ¬START ∧ WRITE | B_1 | `bclr`, `load_tx`; is_read ← 0 | bcnt ← 0, tx ← TX_DATA |
| T1r | IDLE, go ∧ ¬START ∧ ¬WRITE ∧ READ | B_1 | `bclr`; is_read ← 1 | bcnt ← 0 |
| T1p | IDLE, go y solo STOP | SP_1 | — | — |
| T2 | Estado de acción X | WAIT o SCL_WAIT | orden de X (ver tabla siguiente); n ← k, ret ← siguiente; `tclr` si va a WAIT | SCL o SDA cambian; cuarto ← 0 |
| T3 | B_4, ¬bit_last | WAIT | `sample`, `binc`, `tclr`; n ← 1, ret ← B_1 | READ: rx ← {rx, SDA}; WRITE: tx ← tx << 1; bcnt ← bcnt + 1 |
| T4 | B_4, bit_last | WAIT | `sample`, `tclr`; n ← 1, ret ← B_END | WRITE: ACK_IN ← SDA |
| H2 | SCL_WAIT, SCL = 0 | SCL_WAIT | — | — |
| T5 | SCL_WAIT, SCL = 1 | WAIT | `tclr` | cuarto ← 0 |
| H3 | WAIT, tick = 0 | WAIT | — | el contador de cuarto avanza |
| T6 | WAIT, tick ∧ n > 1 | WAIT | n ← n − 1 | — |
| T6r | WAIT, tick ∧ n = 1 | ret | — | — |
| T7 | DONE | IDLE | `done` = 1 (un ciclo) | — |

Acción de cada estado X en T2 (la misma tabla del ASMD):

| Estado X | Orden | Acción | k (cuartos) | Siguiente | Espera |
| --- | --- | --- | --- | --- | --- |
| ST_1 | `sda_rel` | SDA ← 1 | 1 | ST_2 | WAIT |
| ST_2 | `scl_rel` | SCL ← 1 | 2 | ST_3 | SCL_WAIT |
| ST_3 | `sda_pull` | SDA ← 0 (START) | 2 | ST_4 | WAIT |
| ST_4 | `scl_pull` | SCL ← 0 | 1 | DONE | WAIT |
| B_1 | `scl_pull` | SCL ← 0 | 1 | B_2 | WAIT |
| B_2 | `sda_put` | SDA ← sda_bit | 1 | B_3 | WAIT |
| B_3 | `scl_rel` | SCL ← 1 | 1 | B_4 | SCL_WAIT |
| B_END | `scl_pull` | SCL ← 0 | 1 | DONE | WAIT |
| SP_1 | `scl_pull` | SCL ← 0 | 1 | SP_2 | WAIT |
| SP_2 | `sda_pull` | SDA ← 0 | 1 | SP_3 | WAIT |
| SP_3 | `scl_rel` | SCL ← 1 | 2 | SP_4 | SCL_WAIT |
| SP_4 | `sda_rel` | SDA ← 1 (STOP) | 2 | DONE | WAIT |

`sda_bit`: en WRITE es `tx[7]` en los bits 1 a 8 y 1 (soltar) en el bit 9; en READ es 1 (soltar) en los bits 1 a 8 y `ACK_OUT` en el bit 9.

## Decisiones que hay que poder explicar

- **Un bit son 4 cuartos**: B_1 (SCL ← 0), B_2 (SDA cambia con SCL en 0), B_3 (SCL ← 1) y B_4 (se lee SDA a la mitad del nivel alto). Por eso SCL = f_clk / (4·(CLK_DIV + 1)).
- **`tick` no es un reloj**: es una habilitación de un ciclo que el contador de cuarto genera cada `CLK_DIV + 1` ciclos; `tclr` lo reinicia al empezar cada espera.
- **Drenador abierto**: el maestro nunca pone un 1 en SCL ni en SDA. `scl_oe = 1` / `sda_oe = 1` bajan la línea; con 0 la línea queda suelta y la resistencia de pull-up de 4,7 kΩ la lleva a 1.
- **Sincronizadores de 2 etapas**: SCL y SDA vienen de afuera, así que pasan por dos flip-flops antes de usarse. Esa latencia, más el ciclo de cada estado de acción, hace que un bit dure 511 ciclos en vez de 500: con CLK_DIV = 124 a 50 MHz, SCL ≈ 97,8 kHz (dentro del modo estándar, ≤ 100 kHz). A 27 MHz, CLK_DIV = 65 da ≈ 98 kHz (4·66 + 11 = 275 ciclos por bit).
- **SCL_WAIT**: después de soltar SCL, el control espera a ver SCL = 1 antes de contar el cuarto. Así funciona si el esclavo estira el reloj (la 24LC256 no lo hace, pero el banco lo prueba).
- **Una orden por escritura de CONTROL**: si llegan varios bits a la vez, la prioridad es START > WRITE > READ > STOP. Con START repetido se hace la lectura aleatoria de la EEPROM.
- **ACK_IN**: solo se actualiza en WRITE (bit 9) y vale 1 después del reset; 0 significa que el esclavo respondió.
- **BUSY = busy_core ∨ go** y **DONE retenido**, igual que en el SPI: las escrituras con BUSY = 1 se ignoran, y STATUS.DONE se limpia al leer STATUS o al dar una orden nueva. `STATUS = {DONE, ACK_IN, BUSY}`; CONTROL es solo escritura y se lee como 0.
