/* spi_flash_example.c
 * Ejemplo pequeno para el FemtoRV32 Quark: lee el JEDEC ID de la Flash y
 * un bloque de 8 bytes con MANTENER y CONTINUAR. Los resultados quedan en
 * variables globales para verlos en la simulacion del SoC.
 *
 * Pendiente: compilar con la cadena RISC-V (RV32I/ILP32) del proyecto base
 * femtoriscv-basic y agregarlo a OBJECTS en firmware/c-code/Makefile.
 */
#include <stdint.h>
#include "spi_flash.h"

volatile uint32_t jedec_id;
volatile uint8_t  bloque[8];
volatile uint32_t resultado;   /* 1 = JEDEC correcto, 0 = error */

int main(void)
{
    SPI_CLK_DIV = 1;                       /* SCK = f_clk / 4 */

    jedec_id  = spi_jedec_id();
    resultado = (jedec_id == 0xEF4017u);

    uint8_t tmp[8];
    spi_read_block(0x000000u, tmp, 8u);
    for (int i = 0; i < 8; i++)
        bloque[i] = tmp[i];

    for (;;) { }                           /* fin del programa */
    return 0;
}
