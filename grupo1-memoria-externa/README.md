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

## Criterio A: flujo de diseño del periférico

En esta tabla se encuentran todos los diagramas realizados para los controladores SPI e I2C. **Ver** abre la imagen en GitHub y **Editar** la abre en draw.io; al guardar en draw.io el cambio queda en este repositorio (POR FAVOR SI NO SON DEL GRUPO NO EDITAR LOS DRAW.IO).

| Paso | Diagrama | Archivos |
| --- | --- | --- |
| 1 | Caja negra (entradas y salidas) | SPI ([Ver](docs/diagramas/1-caja-negra/Grupo1_Caja_Negra_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F1-caja-negra%2FGrupo1_Caja_Negra_SPI.drawio.png))<br>I2C ([Ver](docs/diagramas/1-caja-negra/Grupo1_Caja_Negra_I2C.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F1-caja-negra%2FGrupo1_Caja_Negra_I2C.drawio.png)) |
| 2 | Diagrama de bloques | Bloques ([Ver](docs/diagramas/2-bloques/Grupo1_Diagrama_de_Bloques.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F2-bloques%2FGrupo1_Diagrama_de_Bloques.drawio.png)) |
| 3 | Diagrama de tiempos | Señales y tiempos ([Ver](docs/diagramas/3-tiempos/Grupo1_Senales_y_Tiempos.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F3-tiempos%2FGrupo1_Senales_y_Tiempos.drawio.png))<br>Diagramas de tiempos ([Ver](docs/diagramas/3-tiempos/Grupo1_Diagramas_de_Tiempo.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F3-tiempos%2FGrupo1_Diagramas_de_Tiempo.drawio.png)) |
| 4 | Diagrama de flujo | Vista del usuario ([Ver](docs/diagramas/4-flujo/Grupo1_Flujo_Usuario.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F4-flujo%2FGrupo1_Flujo_Usuario.drawio.png))<br>Lo que hace la máquina ([Ver](docs/diagramas/4-flujo/Grupo1_Flujo_Maquina.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F4-flujo%2FGrupo1_Flujo_Maquina.drawio.png))<br>Controladores SPI e I2C ([Ver](docs/diagramas/4-flujo/Grupo1_Flujo_Controladores_HW.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F4-flujo%2FGrupo1_Flujo_Controladores_HW.drawio.png)) |
| 5 | Flujo clasificado (control y datapath) | SPI ([Ver](docs/diagramas/5-flujo-clasificado/Grupo1_Flujo_Clasificado_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F5-flujo-clasificado%2FGrupo1_Flujo_Clasificado_SPI.drawio.png)) |
| 6 | ASMD y tabla de transferencias | ASMD SPI ([Ver](docs/diagramas/6-asmd/Grupo1_ASMD_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F6-asmd%2FGrupo1_ASMD_SPI.drawio.png))<br>Tabla de transferencias SPI ([Ver](docs/diagramas/6-asmd/Grupo1_Tabla_Transferencias_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F6-asmd%2FGrupo1_Tabla_Transferencias_SPI.drawio.png))<br>ASMD I2C ([Ver](docs/diagramas/6-asmd/Grupo1_ASMD_I2C.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F6-asmd%2FGrupo1_ASMD_I2C.drawio.png)) <br>Tabla de transferencias I2C ([Ver](docs/diagramas/6-asmd/Grupo1_Tabla_Transferencias_I2C.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F6-asmd%2FGrupo1_Tabla_Transferencias_I2C.drawio.png)) |
| 7 | Bloques control / datapath | SPI ([Ver](docs/diagramas/7-control-datapath/Grupo1_Bloques_Control_Datapath_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F7-control-datapath%2FGrupo1_Bloques_Control_Datapath_SPI.drawio.png)) |
| 8 | Máquina de estados (FSM) | SPI ([Ver](docs/diagramas/8-maquinas-de-estado/Grupo1_FSM_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F8-maquinas-de-estado%2FGrupo1_FSM_SPI.drawio.png)) |
| 9 | Testbench y simulación (casos sacados de la tabla de transferencias) | Pendiente |

## Criterio B: integración al SoC

En esta tabla se encuentra lo que pide la guía `uart-riscv.pdf` para conectar los controladores SPI e I2C al procesador. **Ver** abre el archivo en GitHub y **Editar** lo abre en draw.io.

| Ítem | Qué es | Archivos |
| --- | --- | --- |
| 1 | Región del mapa y `cs` | Flash SPI `0x42_0000` · EEPROM I2C `0x46_0000` ([Ver](#qué-hace-este-grupo)) |
| 2 | Mapa de registros MMIO | SPI e I2C ([Ver](tareas-y-actividades/README.md#4-registros-de-control-mmio)) |
| 3 | Decodificador local (`addr[4:0]` → registro) | Pendiente |
| 4 | Diagrama del adaptador de bus (bus ↔ registros, mux de lectura a `d_out`) | Pendiente |
| 5 | Semántica START / BUSY / DONE (DONE retenido hasta que la CPU lo lee) | Pendiente |
| 6 | Diagrama de tiempos del handshake bus ↔ core | Pendiente |
| 7 | Verificación de registros y de SoC (testbench) | Pendiente |
| 8 | Pines y restricciones (`.cst`) | Tabla de pines ([Ver](tareas-y-actividades/README.md#3-mapa-de-hardware-y-conteo-de-pines)) · `.cst` pendiente |

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
| 12/11/2026 | Diagrama de caja negra de SPI e I2C separados y espacios en este README para los demás diagramas del método de diseño propuesto en el documento compartido por el profe|
| 12/11/2026 | Diagramas como imagen editable de draw.io en `docs/diagramas/` y tabla de Diseño con enlaces para ver y editar cada uno |
| 16/11/2026 | ASMD del controlador SPI: estados IDLE, CS_SETUP, LOAD, LOW, HIGH, FIN, CS_HOLD, CS_REST y DONE, con las transferencias T1 a T12, incluida T1c para continuar una lectura sin volver a mandar el comando |
| 16/11/2026 | Tabla de transferencias por flanco del controlador SPI: estado y condición, estado siguiente, registros que cambian en cada flanco y salida done |
| 17/11/2026 | Registros del SPI: se agregan MANTENER (bit19) y CONTINUAR (bit20) al registro CONTROL, en tareas y actividades |
| 17/11/2026 | README: la tabla de diseño queda como criterio A (con el paso 9, testbench) y se agrega la tabla del criterio B, integración al SoC |
| 19/11/2026 | ASMD del SPI corregido (reemplaza la versión del 16/11): se define la fase (CMD, DIR, DAT) con su valor, número de bits y fase siguiente; MOSI = sh[31] en LOW y HIGH; IDLE ya no fuerza CS_n = 1, para que CONTINUAR funcione; se agrega T1n para cuando no hay datos que mover |
| 19/11/2026 | Tabla de transferencias del SPI corregida (reemplaza la del 16/11): agrega T1n, la condición CS_n en T1 y T1c, y la tabla "Definición de fase" con hay_datos, falta fase, MOSI y last, para que coincida con el ASMD |
| 19/11/2026 | Flujo clasificado del SPI (paso 5): cada bloque del flujo marcado como control o datapath, con la rama de CONTINUAR y hay_datos |
| 19/11/2026 | Bloques control / datapath del SPI (paso 7): registros MMIO, control (FSM de 9 estados) y datapath (divisor, mux de carga por fase, registro sh de 32 bits con MOSI = sh[31], contador de bits, registro rx), con las órdenes y banderas entre ellos y los pines WP_n y HOLD_n |
| 19/11/2026 | Máquina de estados del SPI (paso 8): 9 estados con las mismas transiciones del ASMD, incluidas T1c y T1n para CONTINUAR, y MOSI como salida de LOW y HIGH |
| 22/11/2026 | Registros del SPI: STATUS agrega bit2 CS_ACTIVO, para que el software sepa si CS_n quedó en 0 por MANTENER antes de usar CONTINUAR |
| 22/11/2026 | RTL del datapath SPI (`rtl/spi_datapath.v`): divisor de tick, mux val(fase)/n(fase), registro sh de 32 bits con MOSI = sh[31], contador bits con last, registro rx de 24 bits y registros SCK y CS_n, todos actualizados en el flanco de subida |
| 22/11/2026 | RTL del control SPI (`rtl/spi_control.v`): FSM de 9 estados con el enfoque A de la guía (próximo estado y órdenes combinacionales, registros en subida); cada rama lleva el ID de su fila en la tabla de transferencias (H1, T1, T1c, T1n … T12) |

## Pendientes y problemas

-
