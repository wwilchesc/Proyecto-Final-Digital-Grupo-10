/* spi_flash.h
 * Acceso desde C al periferico SPI del Grupo 1 (memoria externa), region
 * 0x0042_0000 del mapa del SoC. Las direcciones y los bits coinciden con
 * rtl/perip_spi.v y con el mapa de registros del README.
 *
 * volatile obliga al compilador a hacer cada lectura y escritura en el bus:
 * sin el, podria guardar STATUS en un registro de la CPU y nunca ver que
 * BUSY cambio a 0.
 */
#ifndef SPI_FLASH_H
#define SPI_FLASH_H

#include <stdint.h>

#define SPI_BASE        0x00420000u

#define SPI_CONTROL     (*(volatile uint32_t *)(SPI_BASE + 0x00u))
#define SPI_ADDR        (*(volatile uint32_t *)(SPI_BASE + 0x04u))
#define SPI_WDATA       (*(volatile uint32_t *)(SPI_BASE + 0x08u))
#define SPI_RDATA       (*(volatile uint32_t *)(SPI_BASE + 0x0Cu))
#define SPI_STATUS      (*(volatile uint32_t *)(SPI_BASE + 0x10u))
#define SPI_CLK_DIV     (*(volatile uint32_t *)(SPI_BASE + 0x14u))

/* Campos de CONTROL */
#define SPI_START       (1u << 0)
#define SPI_RW          (1u << 1)              /* 1 = escribir en la Flash  */
#define SPI_CMD(c)      (((uint32_t)(c) & 0xFFu) << 8)
#define SPI_SIN_DIR     (1u << 16)             /* comando sin direccion     */
#define SPI_NB(n)       (((uint32_t)(n) & 0x3u) << 17)  /* bytes a leer 0-3 */
#define SPI_MANTENER    (1u << 19)             /* dejar CS_n en 0           */
#define SPI_CONTINUAR   (1u << 20)             /* seguir sin comando ni dir */

/* Campos de STATUS */
#define SPI_BUSY        (1u << 0)
#define SPI_DONE        (1u << 1)              /* se limpia al leer STATUS  */
#define SPI_CS_ACTIVO   (1u << 2)

/* Comandos de la Flash (W25Q64) */
#define FLASH_READ      0x03u
#define FLASH_PROGRAM   0x02u
#define FLASH_WREN      0x06u
#define FLASH_STATUS1   0x05u
#define FLASH_JEDEC_ID  0x9Fu

/* Espera a que el periferico termine (sondeo de BUSY, sin interrupciones) */
static inline uint32_t spi_wait(void)
{
    uint32_t st;
    do {
        st = SPI_STATUS;
    } while (st & SPI_BUSY);
    return st;
}

/* JEDEC ID: 0x9F sin direccion, 3 bytes. Debe dar 0xEF4017 en una W25Q64 */
static inline uint32_t spi_jedec_id(void)
{
    SPI_CONTROL = SPI_START | SPI_CMD(FLASH_JEDEC_ID) | SPI_SIN_DIR | SPI_NB(3);
    spi_wait();
    return SPI_RDATA & 0xFFFFFFu;
}

/* Lee n bytes (1 a 3) desde la direccion addr de la Flash */
static inline uint32_t spi_read(uint32_t addr, uint32_t n)
{
    SPI_ADDR    = addr & 0xFFFFFFu;
    SPI_CONTROL = SPI_START | SPI_CMD(FLASH_READ) | SPI_NB(n);
    spi_wait();
    return SPI_RDATA;
}

/* Lee len bytes seguidos en buf usando MANTENER y CONTINUAR:
 * la primera orden manda comando y direccion; las siguientes solo datos. */
static inline void spi_read_block(uint32_t addr, uint8_t *buf, uint32_t len)
{
    uint32_t i = 0;
    int primera = 1;

    while (i < len) {
        uint32_t n = (len - i >= 3u) ? 3u : (len - i);
        uint32_t ultima = (i + n == len);
        uint32_t orden = SPI_START | SPI_NB(n) | (ultima ? 0u : SPI_MANTENER);

        if (primera) {
            SPI_ADDR = addr & 0xFFFFFFu;
            orden |= SPI_CMD(FLASH_READ);
            primera = 0;
        } else {
            orden |= SPI_CONTINUAR;
        }
        SPI_CONTROL = orden;
        spi_wait();

        uint32_t d = SPI_RDATA;               /* el primer byte llego primero */
        for (uint32_t k = 0; k < n; k++)
            buf[i + k] = (uint8_t)(d >> (8u * (n - 1u - k)));
        i += n;
    }
}

/* Graba un byte: WREN y luego PAGE PROGRAM */
static inline void spi_write_byte(uint32_t addr, uint8_t dato)
{
    SPI_CONTROL = SPI_START | SPI_CMD(FLASH_WREN) | SPI_SIN_DIR;
    spi_wait();
    SPI_ADDR    = addr & 0xFFFFFFu;
    SPI_WDATA   = dato;
    SPI_CONTROL = SPI_START | SPI_CMD(FLASH_PROGRAM) | SPI_RW;
    spi_wait();

    /* La Flash tarda en grabar: sondear el bit WIP (bit0 de STATUS1) */
    do {
        SPI_CONTROL = SPI_START | SPI_CMD(FLASH_STATUS1) | SPI_SIN_DIR | SPI_NB(1);
        spi_wait();
    } while (SPI_RDATA & 0x1u);
}

#endif /* SPI_FLASH_H */
