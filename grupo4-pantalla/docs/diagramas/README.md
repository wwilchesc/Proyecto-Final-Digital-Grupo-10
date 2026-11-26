# Diagramas de arquitectura y barrido — Fase H2

**Estado:** diseño conceptual, no implementado ni simulado. **Plataforma:** Tang Nano 9K (27 MHz). **Panel:** 64×64, rotulado HUB75E; contacto 12 serigrafiado `NC` (no identificado eléctricamente).  
**Fecha:** 2026-11-24. **Responsables reales:** por registrar en commits y evidencias; la autoría de la propuesta documental no equivale a la verificación del hardware.

# Diagramas del controlador HUB75E

Los diagramas describen las distintas etapas del diseño, desde la arquitectura de barrido hasta la interfaz MMIO. Los archivos editables se abren en [diagrams.net](https://app.diagrams.net/).

| Diagrama | Función |
|---|---|
| [Caja negra](1.Arquitectura/DiagramaCajaNegra.drawio.png) | Interfaz de hardware y señales |
| [Caja negra inicial](1.Arquitectura/Diagrama_cajanegra.png) | Arquitectura del panel |
| [Flujo de barrido](2.Barrido/Diagrama_Flujo_HUB75_64x64.pdf) | Secuencia de visualización del prototipo |
| [Temporización del panel](3.Tiempos/DiagramaTiempos.png) | Señales HUB75E |
| [Decodificador local](4.Decodificador_local/Decodificador_local.drawio) | Selección de registros en el diseño inicial |
| [Acceso a registros](4.Decodificador_local/ejemplos/decodificador_local_facil.drawio) | Ejemplos de lectura y escritura |
| [Diseño preliminar](5.Preliminar/hub75e-diseno-preliminar.drawio) | Arquitectura conceptual y alternativas iniciales |
| [ASMD](6.ASMD/asmd-rtl-hub75.drawio) | Diez estados de la FSM del prototipo |

La implementación RGB111 está descrita en el [manual de integración](../../integracion_mmio/README.md). El ASMD original corresponde al prototipo parametrizable; la instancia MMIO utiliza un único plano.

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
