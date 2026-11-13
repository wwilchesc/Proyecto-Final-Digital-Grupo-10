# Grupo 1 · Memoria externa

Controladores de las memorias externas de la consola y la persistencia de los récords.

## Integrantes

- Wilman Santiago Felipe Wilches Cristiano
- David Eduardo Quiroga Vega
- David Felipe Ibagué Arévalo

## Qué hace este grupo

_(Describir el periférico y su función dentro de la consola.)_

- Dispositivo(s): Flash SPI de la tarjeta (gráficos) y EEPROM I2C 24LC256 (récords que no se borran al apagar)
- Protocolo: SPI e I2C
- Dirección base en el mapa de memoria: `0x42_0000` Flash · `0x46_0000` I2C

## Tareas

- [x] Estudiar los protocolos SPI e I2C y las hojas de datos de las memorias
- [x] Definir los registros de cada controlador
- [x] Diagramas de flujo, de bloques y de tiempos
- [ ] Diseñar el controlador SPI (Flash de la tarjeta)
- [ ] Diseñar el controlador I2C (EEPROM 24LC256)
- [ ] Definir el formato de la tabla de récords
- [ ] Escribir los testbenches
- [ ] Probar en la placa

## Tareas y actividades

Las respuestas a las actividades (clasificación del protocolo, diagrama de funcionamiento, pines, registros y lista de precios) están en su propia carpeta:

**[Abrir la carpeta de tareas y actividades](tareas-y-actividades/)**

## Diseño

En esta tabla se encuentran todos los diagramas realizados para los controladores SPI e I2C. **Ver** abre la imagen en GitHub y **Editar** la abre en draw.io; al guardar en draw.io el cambio queda en este repositorio (POR FAVOR SI NO SON DEL GRUPO NO EDITAR LOS DRAW.IO).

| Paso | Diagrama | Archivos |
| --- | --- | --- |
| 1 | Caja negra (entradas y salidas) | SPI ([Ver](docs/diagramas/1-caja-negra/Grupo1_Caja_Negra_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F1-caja-negra%2FGrupo1_Caja_Negra_SPI.drawio.png))<br>I2C ([Ver](docs/diagramas/1-caja-negra/Grupo1_Caja_Negra_I2C.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F1-caja-negra%2FGrupo1_Caja_Negra_I2C.drawio.png)) |
| 2 | Diagrama de bloques | Bloques ([Ver](docs/diagramas/2-bloques/Grupo1_Diagrama_de_Bloques.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F2-bloques%2FGrupo1_Diagrama_de_Bloques.drawio.png)) |
| 3 | Diagrama de tiempos | Señales y tiempos ([Ver](docs/diagramas/3-tiempos/Grupo1_Senales_y_Tiempos.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F3-tiempos%2FGrupo1_Senales_y_Tiempos.drawio.png))<br>Diagramas de tiempos ([Ver](docs/diagramas/3-tiempos/Grupo1_Diagramas_de_Tiempo.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F3-tiempos%2FGrupo1_Diagramas_de_Tiempo.drawio.png)) |
| 4 | Diagrama de flujo | Vista del usuario ([Ver](docs/diagramas/4-flujo/Grupo1_Flujo_Usuario.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F4-flujo%2FGrupo1_Flujo_Usuario.drawio.png))<br>Lo que hace la máquina ([Ver](docs/diagramas/4-flujo/Grupo1_Flujo_Maquina.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F4-flujo%2FGrupo1_Flujo_Maquina.drawio.png))<br>Controladores SPI e I2C ([Ver](docs/diagramas/4-flujo/Grupo1_Flujo_Controladores_HW.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F4-flujo%2FGrupo1_Flujo_Controladores_HW.drawio.png)) |
| 5 | Flujo clasificado (control y datapath) | Pendiente |
| 6 | ASMD y tabla de transferencias | Pendiente |
| 7 | Bloques control / datapath | Pendiente |
| 8 | Máquina de estados (FSM) | Pendiente |

## Hojas de datos

- [EEPROM 24LC256 (Microchip, PDF)](docs/datasheets/24AA256-24LC256-24FC256-256K-I2C-Serial-EEPROM-DS20001203.pdf)
- [Carpeta con todas las hojas de datos](docs/datasheets/)

## Registros

| Desplazamiento | Nombre | Acceso | Descripción |
| --- | --- | --- | --- |
| 0x00 | | | |

## Pines

| Señal | Pin FPGA | Conector | Nota |
| --- | --- | --- | --- |
| | | | |

## Simulación

_(Cómo correr el testbench y qué se verificó. Archivos en `sim/`.)_

## Avances

| Fecha | Avance |
| --- | --- |
| 22/10/2026 | Diagramas de flujo del grupo: vista del usuario y lo que hace la máquina |
| 28/10/2026 | Tarea de actividades para todos los grupos: clasificación de SPI e I2C, diagrama de funcionamiento, mapa de pines, registros MMIO y lista de compras con precios |
| 05/11/2026 | Se descarta la SPI-RAM 23LC1024: los gráficos van directo de la Flash a la BRAM. Diagramas, pines (12 → 8), registros y lista de compras actualizados |
| 12/11/2026 | Diagrama de caja negra de SPI e I2C y espacios en este README para los demás diagramas del método de diseño |
| 12/11/2026 | Diagramas como imagen editable de draw.io en `docs/diagramas/` y tabla de Diseño con enlaces para ver y editar cada uno |

## Pendientes y problemas

-
