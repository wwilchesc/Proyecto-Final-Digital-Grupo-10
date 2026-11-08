# Diagramas de arquitectura y barrido — Fase H2

**Estado:** diseño conceptual, no implementado ni simulado. **Plataforma:** Tang Nano 9K (27 MHz). **Panel:** 64×64, rotulado HUB75E; contacto 12 serigrafiado `NC` (no identificado eléctricamente).  
**Fecha:** 2026-11-07. **Responsables reales:** por registrar en commits y evidencias; la autoría de la propuesta documental no equivale a la verificación del hardware.

## Archivos editables y vistas previas

Abrir [hub75e-diseno-preliminar.drawio](hub75e-diseno-preliminar.drawio) en https://app.diagrams.net/ (cinco páginas editables con rectángulos, conectores y formas independientes).

| N.º | Diagrama | Imagen | Explicación técnica |
|---|---|---|---|
| 01 | Arquitectura general | [PNG](01-arquitectura.png) · [SVG](01-arquitectura.svg) | [01-arquitectura.md](01-arquitectura.md) |
| 02 | Flujo de barrido | [PNG](02-flujo-barrido.png) · [SVG](02-flujo-barrido.svg) | [02-flujo-barrido.md](02-flujo-barrido.md) |
| 03 | Máquina de estados | [PNG](03-fsm.png) · [SVG](03-fsm.svg) | [03-fsm.md](03-fsm.md) |
| 04 | Temporización conceptual | [PNG](04-temporizacion.png) · [SVG](04-temporizacion.svg) | [04-temporizacion.md](04-temporizacion.md) |
| 05 | Formato de framebuffer | [PNG](05-framebuffer.png) · [SVG](05-framebuffer.svg) | [05-framebuffer.md](05-framebuffer.md) |

## Decisiones para esta versión

1. **Prueba inicial:** colores básicos RGB111, un bit por componente. PWM/BCM y profundidad de color superior se estudiarán después.
2. **Framebuffer propuesto:** 4096 píxeles × 3 bits = 12 288 bits. Integración MMIO futura, no operativa.
3. **Reloj base:** 27 MHz del oscilador de la Tang Nano 9K; no se supone que ese sea directamente el reloj `CLK` del panel.
4. **Secuencia conservadora:** `OE=1` durante el desplazamiento y cambio de dirección; después `LAT` y `OE=0` durante el tiempo de encendido.
5. **Selección física de filas:** bloque **abstracto**. No se ha demostrado 1/32 ni determinado la función eléctrica de `NC`. Los ejemplos con fila+32 son hipótesis propias del HUB75E convencional.
6. **Verificación:** por ahora solo revisión documental y consistencia geométrica de los diagramas; no hay un testbench ni una prueba de pantalla validada.

## Qué debe cambiar cuando conozcamos el driver real

- Identificar si el panel usa A–E convencional o direccionamiento especial por pulsos en las líneas de fila.
- Definir setup/hold de RGB, CLK, LAT y OE, polaridades reales, retardos y configuración inicial de drivers.
- Confirmar la alimentación y los niveles de entrada antes del primer encendido.
- Elegir la organización BRAM, arbitraje de lectura/escritura, formato MMIO y pines `.cst`.
- Agregar RTL, simulación con Icarus/GTKWave y fotografías de ensayos a sus carpetas de evidencia respectivas.

## Fuentes técnicas de referencia, no datasheet de nuestra PCB

- Sipeed, Tang Nano 9K: https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html
- Waveshare, guía HUB75: https://docs.waveshare.com/LED
- SmartMatrix, variantes de direccionamiento especial: https://github-wiki-see.page/m/pixelmatix/SmartMatrix/wiki/HUB75-Panels

**Declaración de IA:** el diseño y su texto se elaboraron con asistencia de ChatGPT; validar humanamente las decisiones y documentar de forma independiente las pruebas posteriores. Ver [declaración del proyecto](../05-declaracion-uso-ia.md).
