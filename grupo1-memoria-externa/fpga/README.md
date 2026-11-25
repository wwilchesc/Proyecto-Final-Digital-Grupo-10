# Pines y restricciones del Grupo 1

`tang_primer_25k.cst` asigna los pines de `rtl/memoria_externa.v` en la **Tang Primer 25K** (GW5A-LV25MG121, reloj de 50 MHz). Con esta tarjeta se hace la primera prueba en físico; después se pasa a la Tang Nano 9K del SoC (ver la última sección).

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

## Paso a la Tang Nano 9K

El RTL no cambia. Solo cambian el reloj y los pines:

| Puerto | Tang Primer 25K | Tang Nano 9K |
| --- | --- | --- |
| `clk` | E2 (50 MHz) | 52 (27 MHz) |
| `spi_sck` | E7 | 59 (MCLK) |
| `spi_cs_n` | E6 | 60 (MCS_N) |
| `spi_mosi` | D6 | 61 (MO) |
| `spi_miso` | E5 | 62 (MI) |
| `spi_wp_n`, `spi_hold_n` | D5, E4 | sin pin (fijos en la tarjeta; confirmar en el esquemático) |
| `i2c_scl`, `i2c_sda` | K4, J4 | dos pines libres de la lista del grupo 6 |

Con 27 MHz: el SPI queda en 6,75 MHz con `CLK_DIV = 1` (no hay que cambiar nada) y el I2C necesita `CLK_DIV = 67` para unos 99,3 kHz. La Flash de la Nano 9K es de 32 Mbit y de otro fabricante, así que el JEDEC ID que responde no es 0xEF4017; los comandos 0x9F, 0x03, 0x06, 0x02 y 0x05 son los mismos.

## Prueba en placa: SPI e I2C juntos

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

1. Crear un proyecto en Gowin IDE con el dispositivo **GW5A-LV25MG121NC1/I0** y agregar `fpga/prueba_grupo1.v`, los 7 archivos de `rtl/` (`memoria_externa.v`, `perip_spi.v`, `spi_control.v`, `spi_datapath.v`, `perip_i2c.v`, `i2c_control.v`, `i2c_datapath.v`) y `fpga/prueba_grupo1_25k.cst`. El módulo superior es `prueba_grupo1`.
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

Para pasar la prueba a la Tang Nano 9K basta con poner `CLK_HZ = 27_000_000` y cambiar los pines como dice la tabla de arriba (y `CLK_DIV = 67` en el I2C, o dejar 124 y aceptar unos 54 kHz).
