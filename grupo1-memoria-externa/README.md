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

Diagramas de flujo (clic para abrirlos en draw.io):

- [Diagrama de flujo desde el punto de vista del usuario](https://app.diagrams.net/#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2FGrupo1_Flujo_Usuario.drawio)
- [Diagrama de flujo de lo que hace la máquina](https://app.diagrams.net/#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2FGrupo1_Flujo_Maquina.drawio)

- [Diagrama de bloques, señales y tiempos](https://app.diagrams.net/#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2FGrupo1_Diagrama_Funcionamiento.drawio)

### Diagramas del método de diseño (guía de la UART)

En esta tabla se encuentran todos los diagramas realizados para los controladores SPI e I2C. Para abrir cualquiera, solo hay que darle clic al enlace.

| Paso | Diagrama | Archivo en `docs/` | Estado |
| --- | --- | --- | --- |
| 1 | Caja negra (entradas y salidas) | `Grupo1_Caja_Negra.drawio` | [Subido](https://app.diagrams.net/#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2FGrupo1_Caja_Negra.drawio) |
| 2 | Diagrama de tiempos | `Grupo1_Diagramas_de_Tiempo.drawio` | Pendiente |
| 3 | Diagrama de flujo | `Grupo1_Flujo_Maquina.drawio` | [Subido](https://app.diagrams.net/#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2FGrupo1_Flujo_Maquina.drawio) |
| 4 | Flujo clasificado (control y datapath) | `Grupo1_Flujo_Clasificado.drawio` | Pendiente |
| 5 | ASMD y tabla de transferencias | `Grupo1_ASMD_Transferencias.drawio` | Pendiente |
| 6 | Bloques control / datapath | `Grupo1_Bloques_Control_Datapath.drawio` | Pendiente |
| 7 | Máquina de estados (FSM) | `Grupo1_Maquinas_de_Estado.drawio` | Pendiente |

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

## Pendientes y problemas

-
