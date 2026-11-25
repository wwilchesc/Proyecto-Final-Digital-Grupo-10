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
