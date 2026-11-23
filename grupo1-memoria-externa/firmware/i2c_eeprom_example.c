/* i2c_eeprom_example.c
 * Ejemplo pequeno para el FemtoRV32 Quark: comprueba que la EEPROM 24LC256
 * responde, graba 4 bytes de prueba y los lee de vuelta. Los resultados
 * quedan en variables globales para verlos en la simulacion del SoC.
 *
 * Usa solo las funciones de i2c_eeprom.h (equivalente I2C de
 * spi_flash_example.c).
 *
 * Pendiente: compilar con la cadena RISC-V (RV32I/ILP32) del proyecto base
 * femtoriscv-basic y agregarlo a OBJECTS en firmware/c-code/Makefile.
 */
#include <stdint.h>
#include "i2c_eeprom.h"

#define DIR_PRUEBA  0x7FF0u            /* ultimas posiciones de la EEPROM,
                                          lejos de la tabla de records   */

volatile uint32_t presente;            /* 1 = la EEPROM respondio ACK     */
volatile uint32_t nack_escritura;      /* 0 = todas las escrituras con ACK */
volatile uint8_t  leidos[4];
volatile uint32_t resultado;           /* 1 = lo leido es lo escrito      */

int main(void)
{
    static const uint8_t patron[4] = { 0xA5u, 0x5Au, 0x3Cu, 0xC3u };

    I2C_CLK_DIV = 124u;                /* SCL ~ 100 kHz con reloj de 50 MHz
                                          (65 si el reloj es de 27 MHz)   */

    /* 1. Presencia: START, direccion 0xA0 y STOP; ACK_IN = 0 si responde */
    i2c_cmd(I2C_START);
    presente = (i2c_send((uint8_t)(EEPROM_ADDR << 1)) == 0u);
    i2c_cmd(I2C_STOP);

    /* 2. Escritura de 4 bytes, uno por uno (cada uno espera el ciclo de
     *    grabacion de 5 ms con ACK polling dentro de eeprom_write) */
    nack_escritura = 0u;
    for (uint16_t i = 0; i < 4u; i++)
        nack_escritura |= eeprom_write((uint16_t)(DIR_PRUEBA + i), patron[i]);

    /* 3. Lectura aleatoria de los mismos 4 bytes y comparacion */
    resultado = presente && (nack_escritura == 0u);
    for (uint16_t i = 0; i < 4u; i++) {
        leidos[i] = eeprom_read((uint16_t)(DIR_PRUEBA + i));
        if (leidos[i] != patron[i])
            resultado = 0u;
    }

    for (;;) { }                       /* fin del programa */
    return 0;
}
