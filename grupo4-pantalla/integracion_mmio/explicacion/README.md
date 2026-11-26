# Explicación de los módulos RTL

El controlador de pantalla recibe imágenes mediante MMIO y genera autónomamente las señales HUB75E. Esta guía explica los cinco módulos que forman el periférico integrado, desde la interfaz con el bus hasta los pines del panel.

## Orden de lectura

| Módulo | Función principal |
|---|---|
| [perip_hub75.md](perip_hub75.md) | Adaptador MMIO, validación de accesos e instanciación de los bloques. |
| [perip_hub75_ctrl.md](perip_hub75_ctrl.md) | Decodificación local, registros y handshake. |
| [framebuffer_rgb111.md](framebuffer_rgb111.md) | Almacenamiento y acceso a los dos bancos de imagen. |
| [hub75_datapath.md](hub75_datapath.md) | Contadores, direcciones y selección de bits RGB. |
| [hub75_control.md](hub75_control.md) | Máquina de estados y coordinación temporal del barrido. |

La lógica combinacional calcula condiciones y órdenes a partir de las señales presentes. Los bloques `always @(posedge clk)` actualizan registros en el flanco positivo del reloj; las asignaciones `<=` toman los valores anteriores al flanco. Esta distinción permite interpretar correctamente el flujo entre memoria, control y datapath.

[Mapa de registros, contrato de bus y simulación](../README.md).
