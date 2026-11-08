# Grupo de pantalla — Matriz LED RGB 64×64 (HUB75E)

**Proyecto final de Electrónica Digital 1 · Estado: estudio documental inicial (2026-11-07).**

## Integrantes del equipo de pantalla

- Gisela Barrera Florez
- Sandra Amaya Betancourt
- Erika Briyith Hueso Castro
- Sebastian Cespedes
- Juan Jose Mora
- Luis Felipe Cardenas

**Equipo conjunto de pantalla (grupos 4 y 5).** Esta lista documenta la composición comunicada por el equipo, sin asignar actividades individuales ni atribuir autorías de RTL, experimentos, diagramas o verificaciones técnicas. El reparto de responsabilidades y su alcance académico deben quedar registrados cuando se acuerden.

Este módulo estudia y desarrollará el controlador de visualización de una matriz LED RGB de **64×64 píxeles**, interfaz serigrafiada **HUB75E**, para su conexión a una FPGA **Tang Nano 9K**. El propósito es integrar posteriormente un framebuffer y el acceso del procesador **FemtoRV32** mediante MMIO.

> **Alcance demostrado a la fecha:** inspección de fotografías, consulta de documentación externa y propuesta de verificación. **Todavía no** se ha comprobado por nosotros el conexionado, el consumo, el funcionamiento físico, las simulaciones ni el RTL de la pantalla.

## Identificación del hardware

| Característica | Dato | Grado de verificación |
|---|---|---|
| Resolución | 64×64, 4096 píxeles | Marcaje PCB `64X64` |
| Referencia impresa | `P2.5-2121-64X64-32S-8H-M11` (sufijo por cotejar) | Fotografía |
| Paso | P2.5, nominal 2,5 mm | Inferencia del código |
| Área activa | ≈160×160 mm | Calculada, no medida |
| Interfaz | HUB75E, conector de 16 contactos | Fotografía |
| Barrido | Posible 1/32 (`32S`) | Hipótesis pendiente de prueba |
| Alimentación | Bornes separados `VCC`/`GND`; **tensión sin confirmar para esta PCB** | Fotografía |
| Driver, fabricante y hoja de datos exacta | No identificados | Investigación abierta |

### Particularidad que debe verificarse

El integrante que inspeccionó la placa aclaró la distribución de los contactos **`C` y `NC`**, por separado, en la sexta fila del conector. Por tanto, el **rótulo físico declarado es `NC` en la posición donde el HUB75E convencional utiliza `D`**. Aunque `NC` suele significar «sin conexión», **el comportamiento eléctrico del contacto no se ha comprobado** y el controlador de filas aún no está identificado. **No conectar ni asignar una señal `D` por analogía.** Ver [pinout completo del panel fotografiado](docs/06-pinout-fotografiado.md).

## Documentación del desarrollo

| Documento | Propósito |
|---|---|
| [Índice de la fase documental](docs/README.md) | Estado y navegación |
| [01 — Identificación del panel](docs/01-identificacion-panel.md) | Evidencia visual, marcajes y fuentes |
| [02 — HUB75E y Tang Nano 9K](docs/02-interfaz-hub75e-y-tang-nano9k.md) | Señales, temporización conceptual, lógica y memoria |
| [03 — Riesgos y procedimiento de pruebas](docs/03-riesgos-y-pruebas.md) | Seguridad, hipótesis, verificación y aceptación |
| [04 — Plan y trazabilidad](docs/04-plan-y-trazabilidad.md) | Hitos, responsables, commits y criterios |
| [05 — Declaración de uso de IA](docs/05-declaracion-uso-ia.md) | Apoyo de ChatGPT, límites y revisión humana |
| [06 — Pinout de la placa](docs/06-pinout-fotografiado.md) | Los 16 contactos tal como los confirmó el equipo, comparación con HUB75E estándar |
| [Fotografías de la PCB](docs/fotos/) | Evidencia original observada |

## Arquitectura preliminar (no implementada)

```text
FemtoRV32 / patrones de prueba
            |
     Bus y decodificador MMIO (por acordar)
            |
     Framebuffer en memoria FPGA (por definir)
            |
      FSM de barrido + generador de tiempos
            |
R1 G1 B1 / R2 G2 B2 / direcciones / CLK LAT OE
            |
     Adaptación de niveles, si se requiere
            |
          Panel RGB 64×64
```

La interfaz HUB75E **no es SPI**: usa datos RGB paralelos, selección multiplexada de filas y un reloj de desplazamiento. Se deben diferenciar el reloj de la FPGA, el reloj de desplazamiento y la tasa de refresco. Los registros `0x480000` (imagen) y `0x4C0000` (control) son **propuestas de integración**, no una implementación demostrada.

## Plan de trabajo

1. Confirmar proveedor, hoja de datos auténtica, alimentación, significado eléctrico del contacto `NC`, chips y orientación de conectores.
2. Definir pinout seguro, presupuesto de GPIO/BSRAM, memoria de imagen y contrato MMIO.
3. Crear diagramas `.drawio` de bloques, flujo de barrido y tiempos, coherentes con el diseño elegido.
4. Implementar una FSM mínima en Verilog y pruebas autoverificables (`sim/`, VCD y GTKWave).
5. Probar colores y filas en la placa con fuente verificada, registrar consumo, fotografías y vídeo.
6. Integrar framebuffer con FemtoRV32; medir refresco, utilización y funcionamiento completo.

**Registro académico:** cada integrante debe contribuir con commits individuales auténticos, describir pruebas que realmente haya ejecutado y poder sustentar cada decisión. Se trabajará directamente en `main` del repositorio oficial según el acuerdo del equipo, evitando mezclar modificaciones de otros módulos.

## Referencias técnicas

- [Sipeed Tang Nano 9K](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html)
- [Waveshare RGB Matrix P2.5 64×64 (solo referencia comparable)](https://www.waveshare.com/RGB-Matrix-P2.5-64x64.htm)
- [TI SN74AHCT245 (posible adaptación de nivel)](https://www.ti.com/product/SN74AHCT245)

Ninguna referencia comparable debe presentarse como el datasheet exacto de nuestra PCB.

## Entregables H2 — diagramas conceptuales

Se prepararon cinco diagramas editables de arquitectura, flujo, FSM, temporización y framebuffer. **Son propuestas de diseño y no pruebas de funcionamiento.** Cada uno tiene explicación técnica individual en [docs/diagramas/](docs/diagramas/README.md); existe además un índice de [fotografías y evidencias](docs/fotos/README.md). El contacto `NC` y el barrido real deben verificarse antes del conexionado definitivo y del RTL físico de filas.
