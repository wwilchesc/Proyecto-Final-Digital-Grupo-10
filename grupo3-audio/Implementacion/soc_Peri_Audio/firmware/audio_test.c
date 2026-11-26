#include "soc.h"

// Retardo aproximado por software (a 27 MHz)
static void esperar_ms(uint32_t ms) {
  for (uint32_t i = 0; i < ms * 2700; i++) {
    __asm__ volatile("nop");
  }
}

typedef struct {
  uint8_t id;
  uint8_t repeticiones;
  const char *nombre;
} PruebaSonido;

static const PruebaSonido lista_sonidos[16] = {
    {0,  1, "Intro Pac-Man (Google)"},
    {1,  2, "Waka 'wa' (Google Pac-Man)"},
    {2,  2, "Comer fantasma"},
    {3,  1, "Muerte Pac-Man"},
    {4,  2, "Snake arriba (Google)"},
    {5,  2, "Snake comer manzana (Google)"},
    {6,  1, "Snake inicio / nivel (Google)"},
    {7,  1, "Snake choque / game over"},
    {8,  2, "Snake abajo (Google)"},
    {9,  2, "Snake izquierda (Google)"},
    {10, 2, "Snake derecha (Google)"},
    {11, 2, "Waka 'ka' (Google Pac-Man)"},
    {12, 2, "Sirena de fondo Pac-Man"},
    {13, 2, "Fantasmas asustados (Power Pellet)"},
    {14, 1, "Fruta / bonus Pac-Man"},
    {15, 2, "Vida extra / moneda"}
};

int main(void) {
  esperar_ms(1000);

  while (1) {
    imprimir("\r\n================================================\r\n");
    imprimir("   PRUEBA COMPLETA: PAC-MAN Y SNAKE (GOOGLE)    \r\n");
    imprimir("================================================\r\n");

    for (uint8_t i = 0; i < 16; i++) {
      uint8_t id   = lista_sonidos[i].id;
      uint8_t reps = lista_sonidos[i].repeticiones;

      imprimir("[ID ");
      if (id < 10) imprimir("0");
      imprimir_dec(id);
      imprimir("] ");
      imprimir(lista_sonidos[i].nombre);
      imprimir(" -> (x");
      imprimir_dec(reps);
      imprimir(")\r\n");

      for (uint8_t r = 0; r < reps; r++) {
        audio_play(id, 0);
        while (audio_is_playing()) {}
        if (r + 1 < reps) {
          esperar_ms(220);
        }
      }

      esperar_ms(650);
    }

    imprimir("\r\n--- Fin de la secuencia. Reiniciando en 3 s ---\r\n");
    esperar_ms(3000);
  }
}
