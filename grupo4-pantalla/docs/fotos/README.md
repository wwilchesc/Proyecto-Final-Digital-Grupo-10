# Registro de evidencias de la pantalla HUB75E

Esta carpeta reúne **evidencia observable y verificable**. Los dibujos conceptuales editables se guardan en [`../diagramas/`](../diagramas/), no aquí.

## Organización

| Carpeta | Uso | Estado al crear estructura |
|---|---|---|
| [`01_identificacion_hardware/`](01_identificacion_hardware/) | Fotos de placa, serigrafía, conectores, modelo y CI | Cuatro fotos ya recibidas; sin mediciones |
| [`02_conexiones_electricas/`](02_conexiones_electricas/) | Montaje, cableado, buffers, fuente y conexiones | Sin evidencias aún |
| [`03_evidencia_simulacion/`](03_evidencia_simulacion/) | Capturas de Icarus/GTKWave y logs | Sin evidencias aún |
| [`04_evidencia_funcionamiento/`](04_evidencia_funcionamiento/) | Pruebas físicas: colores, filas, patrón, refresco | Sin evidencias aún |
| [`05_evidencia_integracion/`](05_evidencia_integracion/) | CPU/SoC, framebuffer, MMIO e integración | Sin evidencias aún |
| [`06_mediciones_validacion/`](06_mediciones_validacion/) | Multímetro, osciloscopio, frecuencia y corriente | Sin evidencias aún |

## Fotografías de identificación incorporadas

- [Vista posterior completa](01_identificacion_hardware/01-vista-posterior-completa.jpg)
- [Modelo y alimentación](01_identificacion_hardware/02-modelo-y-alimentacion.jpg)
- [Serigrafía conector HUB75E](01_identificacion_hardware/03-serigrafia-conector-hub75e.jpg)
- [Conector adicional](01_identificacion_hardware/04-conector-adicional.jpg)

## Registro mínimo por ensayo

Crear un pequeño Markdown junto a la foto o captura con:

1. **Código y objetivo:** ejemplo `PR-01`, verificar color rojo (no implica que se haya ejecutado).
2. **Responsable y fecha real.**
3. **Equipo:** placa, revisión, fuente, cableado y versión del bitstream.
4. **Método:** comandos/referencias Verilog y conexiones utilizadas.
5. **Resultado real:** pasa/falla/no concluyente; no sustituir mediciones con inferencias.
6. **Evidencia asociada:** foto, VCD/GTKWave, registro medido y commit que contiene el RTL.
7. **Observaciones y cambios pendientes.**

**Regla:** no colocar resultados generados ni capturas ilustrativas en carpetas de pruebas reales. Cuando una carpeta solo contenga `.gitkeep`, todavía no se han presentado evidencias de esa etapa.
