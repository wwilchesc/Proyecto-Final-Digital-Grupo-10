# Pines y restricciones del Grupo 1

**Cómo se trabajó.** Primero todo se hizo para la **Tang Primer 25K** (GW5A-LV25MG121, reloj de 50 MHz), porque era la tarjeta que teníamos disponible: ahí se asignaron los pines, se compiló en Gowin y se hace la prueba en placa con video (`tang_primer_25k.cst`, `prueba_grupo1.v`). Después se pasó a la **Tang Nano 9K** (GW1NR-LV9QN88PC6/I5, reloj de 27 MHz), que es la placa del SoC, para la **versión final** (`tang_nano_9k.cst`, `prueba_grupo1_9k.v`). El RTL del grupo es el mismo en las dos: solo cambian el reloj, los pines y detalles de cada tarjeta.

| | Tang Primer 25K (pruebas) | Tang Nano 9K (versión final) |
| --- | --- | --- |
| Pines del bloque | [`tang_primer_25k.cst`](tang_primer_25k.cst) | [`tang_nano_9k.cst`](tang_nano_9k.cst) |
| Prueba en placa | [`prueba_grupo1.v`](prueba_grupo1.v) · [`.cst`](prueba_grupo1_25k.cst) · [`.sdc`](prueba_grupo1.sdc) | [`prueba_grupo1_9k.v`](prueba_grupo1_9k.v) · [`.cst`](prueba_grupo1_9k.cst) · [`.sdc`](prueba_grupo1_9k.sdc) |
| Simulación de la prueba | `make sim-prueba`: 8 comprobaciones, 0 errores | `make sim-prueba-9k`: 9 comprobaciones, 0 errores |
| Gowin (V1.9.11.03 Education) | 1683 LUT (8 %), Fmax 96,5 MHz con 50 MHz | 1669 LUT (20 %), Fmax 44,5 MHz con 27 MHz |
## Pines en la Tang Primer 25K

| Puerto | Pin | Va a | Nota |
| --- | --- | --- | --- |
| `clk` | E2 | Oscilador de 50 MHz de la tarjeta | |
| `spi_cs_n` | E6 | Flash NOR de 64 Mbit de la tarjeta | Pin MSPI |
| `spi_sck` | E7 | Flash de la tarjeta | Pin MSPI |
| `spi_mosi` | D6 | Flash de la tarjeta | Pin MSPI |
| `spi_miso` | E5 | Flash de la tarjeta | Pin MSPI |
| `spi_wp_n` | D5 | Flash de la tarjeta | Pin MSPI, fijo en 1 |
| `spi_hold_n` | E4 | Flash de la tarjeta | Pin MSPI, fijo en 1 |
| `i2c_scl` | K4 | 24LC256 pin 6 (SCL) | Pull-up de 4,7 kΩ a 3,3 V |
| `i2c_sda` | J4 | 24LC256 pin 5 (SDA) | Pull-up de 4,7 kΩ a 3,3 V |

Los pines de la Flash son los que usa la definición de la tarjeta en LiteX (`litex_boards/platforms/sipeed_tang_primer_25k.py`, recurso `spiflash`), que también activa los pines MSPI como E/S normales.

## Antes de sintetizar

1. En Gowin IDE (versión 1.9.9 Beta-4 o más nueva), elegir el dispositivo **GW5A-LV25MG121NC1/I0**.
2. Marcar **Project → Configuration → Place & Route → Dual-Purpose Pin → Use MSPI as regular IO**. Sin esto, los pines de la Flash quedan reservados para la configuración.
3. La Flash también guarda el bitstream al principio. Para escribir datos (récords) hay que usar direcciones altas, lejos del bitstream; leer el JEDEC ID y leer datos no lo afecta.

## Prueba en placa en la 25K: SPI e I2C juntos

`prueba_grupo1.v` es un módulo superior para probar en la tarjeta **todo el bloque del grupo**, sin necesitar el SoC. Instancia `rtl/memoria_externa.v` y un secuenciador que hace el papel de la CPU: escribe y lee los registros por las mismas señales del bus del FemtoRV32 (`mem_addr`, `mem_wdata`, `mem_wmask`, `mem_rstrb`, `mem_rdata`). Al terminar manda un reporte por la UART y enciende los LEDs.

| Prueba | Qué hace | Cuándo es OK |
| --- | --- | --- |
| SPI · JEDEC ID | Comando 0x9F, sin dirección, 3 bytes | La Flash responde algo distinto de 000000 y FFFFFF |
| SPI · borrar | WREN (0x06) y SECTOR ERASE (0x20) del último sector (0x7FF000), y lectura de 3 bytes | Lee FF FF FF |
| SPI · grabar | WREN y PAGE PROGRAM (0x02) del byte de prueba en 0x7FF000, y lectura | Lee el byte de prueba seguido de FF FF |
| SPI · MANTENER + CONTINUAR | Lee 3 bytes con MANTENER y el 4.º con CONTINUAR, sin repetir comando ni dirección | El 4.º byte es FF |
| I2C · ACK | Cada byte enviado a la EEPROM (dirección 0x50) | ACK_IN = 0 en todos |
| I2C · grabar y leer | Graba el byte de prueba en 0x0010 y lo lee con START repetido | Lee el byte de prueba |

El byte de prueba es 0x5A en la primera corrida y sube en uno con cada corrida, así se ve que los datos son nuevos y no quedaron de antes. Se usa el último sector de la Flash, lejos del bitstream, que está al principio.

### Conexiones y pines (`prueba_grupo1_25k.cst`)

| Puerto | Pin | En el Dock |
| --- | --- | --- |
| `clk` | E2 | Oscilador de 50 MHz |
| `btn_rst_n` | H11 | Botón 1: reset y nueva corrida desde cero |
| `btn_run_n` | H10 | Botón 2: repetir la prueba con el siguiente byte |
| `uart_tx` | C3 | UART del depurador USB (aparece como puerto COM en el PC) |
| `led[0]`, `led[1]` | E8, D7 | LEDs del Dock: SPI OK e I2C OK |
| Flash | E6, E7, D6, E5, D5, E4 | Flash de la tarjeta (no hay que cablear nada) |
| `i2c_scl`, `i2c_sda` | K4, J4 | Conector J3 de 40 pines, pines 5 y 6 |

La 24LC256 va en una protoboard: pin 6 (SCL) a K4, pin 5 (SDA) a J4, pin 8 a 3,3 V, pines 1, 2, 3, 4 y 7 a GND, un condensador de 100 nF entre 3,3 V y GND, y una resistencia de 4,7 kΩ de SCL y otra de SDA a 3,3 V. La alimentación se toma de los pines de 3,3 V y GND del mismo conector J3 (ver la serigrafía del Dock).

### Pasos

**Forma rápida (consola Tcl de Gowin).** En Gowin FPGA Designer, pestaña **Console** (abajo), pegar estas líneas una por una cambiando `D` por la carpeta donde está `grupo1-memoria-externa`:

```
create_project -name prueba_grupo1 -dir C:/Users/USUARIO/Desktop/prueba -pn GW5A-LV25MG121NC1/I0 -device_version A
set D C:/ruta/a/grupo1-memoria-externa
foreach f {fpga/prueba_grupo1.v rtl/memoria_externa.v rtl/perip_spi.v rtl/spi_control.v rtl/spi_datapath.v rtl/perip_i2c.v rtl/i2c_control.v rtl/i2c_datapath.v} {add_file -type verilog $D/$f}
add_file -type cst $D/fpga/prueba_grupo1_25k.cst
add_file -type sdc $D/fpga/prueba_grupo1.sdc
set_option -top_module prueba_grupo1 -verilog_std sysv2017 -use_mspi_as_gpio 1 -use_cpu_as_gpio 1 -use_ready_as_gpio 1 -use_done_as_gpio 1 -use_i2c_as_gpio 1
run all
```

Con Gowin V1.9.11.03 Education esto genera `impl/pnr/prueba_grupo1.fs` sin errores: usa 1683 LUT (8 %) y 472 registros (3 %), y la frecuencia máxima es 96,5 MHz para un reloj de 50 MHz (`prueba_grupo1.sdc`), así que cumple tiempos. Todos los pines quedan donde dice el `.cst`.

**Forma con ventanas**, si se prefiere:

1. Crear un proyecto en Gowin IDE con el dispositivo **GW5A-LV25MG121NC1/I0** y agregar `fpga/prueba_grupo1.v`, los 7 archivos de `rtl/` (`memoria_externa.v`, `perip_spi.v`, `spi_control.v`, `spi_datapath.v`, `perip_i2c.v`, `i2c_control.v`, `i2c_datapath.v`), `fpga/prueba_grupo1_25k.cst` y `fpga/prueba_grupo1.sdc`. El módulo superior es `prueba_grupo1`.
2. En **Project → Configuration → Place & Route → Dual-Purpose Pin**, marcar *Use MSPI*, *Use CPU*, *Use READY*, *Use DONE* y *Use I2C as regular IO*.
3. Sintetizar, hacer place & route y programar **en SRAM** (no en la Flash, para no tocar la Flash mientras se prueba).
4. Abrir una terminal serie (PuTTY, la de Arduino o la de VS Code) en el puerto COM de la tarjeta a **115200 8N1**.
5. Presionar el botón 1. Sale el reporte y los dos LEDs encienden si todo pasó. Presionar el botón 2 para repetir con otro byte.

Si los LEDs se ven al revés (prendidos cuando debería estar apagados), poner `LED_ACTIVO_BAJO = 1` en `prueba_grupo1.v`. El JEDEC ID depende del fabricante de la Flash de la tarjeta: una Winbond W25Q64 responde EF4017.

Así se ve el reporte en la terminal (simulación con los modelos de la Flash y la EEPROM, `sim/prueba_grupo1_tb.log`):

```
=== Grupo 1 - memoria externa | prueba en placa | corrida #00 ===
[SPI] JEDEC ID (0x9F)                  : EF4017   OK
[SPI] borrar sector 0x7FF000 (0x20)    : FFFFFF   OK
[SPI] grabar 5A en 0x7FF000 y leer     : 5AFFFF   OK
[SPI] 4.o byte con MANTENER+CONTINUAR  : FF       OK
[I2C] la EEPROM 0x50 responde ACK      : --       OK
[I2C] grabar 5A en 0x0010 y leer       : 5A       OK
RESULTADO   SPI: OK      I2C: OK
```

Si la EEPROM no está conectada, las dos líneas del I2C dicen FALLA, el LED del I2C queda apagado y el SPI sigue funcionando; así se ve que cada parte se prueba por separado.

La versión de esta prueba para la Tang Nano 9K está en la sección siguiente.

## Versión final: Tang Nano 9K

### Qué cambia frente a la 25K

| | Tang Primer 25K | Tang Nano 9K |
| --- | --- | --- |
| Reloj | 50 MHz, pin E2 | 27 MHz, pin 52 |
| SCK del SPI con `CLK_DIV = 1` | 12,5 MHz | 6,75 MHz (no hay que cambiar nada) |
| SCL del I2C | `CLK_DIV = 124` → ~100 kHz | `CLK_DIV = 67` → ~99,3 kHz (el firmware y la prueba lo escriben al arrancar) |
| Flash | 64 Mbit, también guarda el bitstream | P25Q32 de 32 Mbit; el bitstream va en la Flash interna de la FPGA, así que esta queda libre |
| Pines de la Flash | E7 (SCK), E6 (CS), D6 (MOSI), E5 (MISO), D5, E4 | 59 (SCK), 60 (CS), 61 (MOSI), 62 (MISO) |
| `spi_wp_n`, `spi_hold_n` | D5, E4 | Sin pin: en la 9K no llegan a la FPGA, se dejan sin conectar |
| EEPROM | K4 (SCL), J4 (SDA) | 31 (SCL), 32 (SDA) |
| LEDs de la prueba | Encienden con 1 | Encienden con 0 (`LED_ACTIVO_BAJO = 1`) |
| Sector de prueba de la Flash | 0x7FF000 | 0x3FF000 (último sector de 4 KB) |

Los pines de la Flash son los del esquemático de Sipeed (MCLK, MCS_N, MO y MI de la FPGA) y los de la definición de la tarjeta en LiteX; son de doble uso (MSPI), así que hay que activar **Use MSPI as regular IO** (`-use_mspi_as_gpio 1`). Los pines 31 y 32 de la EEPROM están en el banco de 3,3 V y no los usa ningún otro grupo según la tabla de pines del grupo 6; **no se deben usar pines del 3 al 20 ni del 79 al 88**, que son de 1,8 V. La Flash de la 9K es de otro fabricante, así que su JEDEC ID no es 0xEF4017; los comandos 0x9F, 0x03, 0x06, 0x02, 0x05 y 0x20 son los mismos.

### Prueba en placa en la 9K

| Puerto | Pin | En la tarjeta |
| --- | --- | --- |
| `clk` | 52 | Oscilador de 27 MHz |
| `btn_rst_n` | 4 | Botón S1: reset y nueva corrida |
| `btn_run_n` | 3 | Botón S2: repetir con el siguiente byte |
| `uart_tx` | 17 | UART del USB de la tarjeta |
| `led[0]`, `led[1]` | 10, 11 | LEDs 0 y 1: SPI OK e I2C OK |
| Flash | 59, 60, 61, 62 | Flash de la tarjeta |
| `i2c_scl`, `i2c_sda` | 31, 32 | Header lateral, hacia la EEPROM |

La EEPROM se cablea igual que en la 25K: pin 6 (SCL) al pin 31, pin 5 (SDA) al pin 32, pin 8 a 3,3 V, pines 1, 2, 3, 4 y 7 a GND, pull-ups de 4,7 kΩ a 3,3 V y un condensador de 100 nF entre los pines 8 y 4.

Comandos para la consola Tcl de Gowin (`D` es la carpeta `grupo1-memoria-externa`):

```
create_project -name prueba_grupo1_9k -dir C:/Users/USUARIO/Desktop/prueba9k -pn GW1NR-LV9QN88PC6/I5 -device_version C
set D C:/ruta/a/grupo1-memoria-externa
foreach f {fpga/prueba_grupo1_9k.v rtl/memoria_externa.v rtl/perip_spi.v rtl/spi_control.v rtl/spi_datapath.v rtl/perip_i2c.v rtl/i2c_control.v rtl/i2c_datapath.v} {add_file -type verilog $D/$f}
add_file -type cst $D/fpga/prueba_grupo1_9k.cst
add_file -type sdc $D/fpga/prueba_grupo1_9k.sdc
set_option -top_module prueba_grupo1_9k -verilog_std sysv2017 -use_mspi_as_gpio 1
run all
```

Con Gowin V1.9.11.03 Education compila sin errores: 1669 LUT (20 %) y 472 registros (8 %), Fmax de 44,5 MHz para el reloj de 27 MHz, y todos los pines donde dice el `.cst`. Se programa en SRAM con Gowin Programmer y el reporte sale por el puerto COM de la 9K a 115200 8N1.

### Para el SoC (grupo 6)

- `tang_nano_9k.cst` tiene los pines del bloque para copiar en `soc/top.cst`.
- En `soc/top.v` no hace falta sacar `spi_wp_n` ni `spi_hold_n` como puertos: en la 9K no tienen pin.
- Hay que activar los pines MSPI como E/S (en el flujo libre, la opción equivalente de `gowin_pack`).
- El firmware tiene que escribir `CLK_DIV = 67` en el I2C (0x0046_0010) al arrancar.
