# Diagramas de la interfaz MMIO HUB75E

[Archivo editable en draw.io](Integracion_MMIO_HUB75E_diagramas.drawio).

| Página | Contenido |
|---|---|
| 00 | Índice de diagramas |
| 01 | Decodificación de accesos y escritura de píxeles |
| 02 | CONTROL, STATUS, FRAMES y handshake START/BUSY/DONE |
| 03 | Lectura y escritura del framebuffer de doble banco |
| 04 | Instancias y conexiones RTL |
| 05 | Temporización lógica de la interfaz MMIO |

Los rombos describen las condiciones booleanas del adaptador. Las operaciones registradas se aplican en el flanco positivo de `clk`. La página de temporización representa el comportamiento lógico del RTL; las formas de onda se obtienen con `make vcd`.

Consultar el [contrato de interfaz MMIO](../../../integracion_mmio/README.md) y el [índice general](../README.md).
