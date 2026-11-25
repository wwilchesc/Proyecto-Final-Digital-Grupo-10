/* i2c_eeprom.h
 * Acceso desde C al periferico I2C del Grupo 1 (EEPROM 24LC256), region
 * 0x0046_0000. Coincide con rtl/perip_i2c.v.
 */
#ifndef I2C_EEPROM_H
#define I2C_EEPROM_H

#include <stdint.h>

#define I2C_BASE      0x00460000u
#define I2C_CONTROL   (*(volatile uint32_t *)(I2C_BASE + 0x00u))
#define I2C_TX_DATA   (*(volatile uint32_t *)(I2C_BASE + 0x04u))
#define I2C_RX_DATA   (*(volatile uint32_t *)(I2C_BASE + 0x08u))
#define I2C_STATUS    (*(volatile uint32_t *)(I2C_BASE + 0x0Cu))
#define I2C_CLK_DIV   (*(volatile uint32_t *)(I2C_BASE + 0x10u))

#define I2C_START     (1u << 0)
#define I2C_STOP      (1u << 1)
#define I2C_WRITE     (1u << 2)
#define I2C_READ      (1u << 3)
#define I2C_NACK      (1u << 4)    /* ACK_OUT = 1: ultimo byte de una lectura */

#define I2C_BUSY      (1u << 0)
#define I2C_ACK_IN    (1u << 1)    /* 1 = nadie respondio */
#define I2C_DONE      (1u << 2)

#define EEPROM_ADDR   0x50u        /* 1010 A2 A1 A0, con A2 = A1 = A0 = 0 */

static inline uint32_t i2c_cmd(uint32_t c)
{
    uint32_t st;
    I2C_CONTROL = c;
    do { st = I2C_STATUS; } while (st & I2C_BUSY);
    return st;
}

/* Envia un byte; devuelve 0 si el esclavo respondio ACK */
static inline uint32_t i2c_send(uint8_t b)
{
    I2C_TX_DATA = b;
    return i2c_cmd(I2C_WRITE) & I2C_ACK_IN;
}

/* Escribe un byte en la EEPROM. Devuelve 0 si todo respondio ACK */
static inline uint32_t eeprom_write(uint16_t addr, uint8_t dato)
{
    uint32_t nack = 0;
    i2c_cmd(I2C_START);
    nack |= i2c_send((uint8_t)(EEPROM_ADDR << 1));
    nack |= i2c_send((uint8_t)(addr >> 8));
    nack |= i2c_send((uint8_t)addr);
    nack |= i2c_send(dato);
    i2c_cmd(I2C_STOP);
    /* La 24LC256 tarda hasta 5 ms en grabar: esperar a que responda ACK */
    do {
        i2c_cmd(I2C_START);
    } while (i2c_send((uint8_t)(EEPROM_ADDR << 1)));
    i2c_cmd(I2C_STOP);
    return nack;
}

/* Lee un byte (lectura aleatoria con START repetido) */
static inline uint8_t eeprom_read(uint16_t addr)
{
    i2c_cmd(I2C_START);
    i2c_send((uint8_t)(EEPROM_ADDR << 1));
    i2c_send((uint8_t)(addr >> 8));
    i2c_send((uint8_t)addr);
    i2c_cmd(I2C_START);
    i2c_send((uint8_t)((EEPROM_ADDR << 1) | 1u));
    i2c_cmd(I2C_READ | I2C_NACK);
    i2c_cmd(I2C_STOP);
    return (uint8_t)I2C_RX_DATA;
}

#endif /* I2C_EEPROM_H */
