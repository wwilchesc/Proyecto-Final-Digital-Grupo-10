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
- [x] Diseñar el controlador SPI (Flash de la tarjeta)
- [x] Diseñar el controlador I2C (EEPROM 24LC256)
- [ ] Definir el formato de la tabla de récords
- [x] Escribir los testbenches
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
| 5 | Flujo clasificado (control y datapath) | SPI ([Ver](docs/diagramas/5-flujo-clasificado/Grupo1_Flujo_Clasificado_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F5-flujo-clasificado%2FGrupo1_Flujo_Clasificado_SPI.drawio.png))<br>I2C ([Ver](docs/diagramas/5-flujo-clasificado/Grupo1_Flujo_Clasificado_I2C.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F5-flujo-clasificado%2FGrupo1_Flujo_Clasificado_I2C.drawio.png)) |
| 6 | ASMD y tabla de transferencias | ASMD SPI ([Ver](docs/diagramas/6-asmd/Grupo1_ASMD_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F6-asmd%2FGrupo1_ASMD_SPI.drawio.png))<br>Tabla de transferencias SPI ([Ver](docs/diagramas/6-asmd/Grupo1_Tabla_Transferencias_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F6-asmd%2FGrupo1_Tabla_Transferencias_SPI.drawio.png))<br>ASMD I2C ([Ver](docs/diagramas/6-asmd/Grupo1_ASMD_I2C.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F6-asmd%2FGrupo1_ASMD_I2C.drawio.png)) <br>Tabla de transferencias I2C ([Ver](docs/diagramas/6-asmd/Grupo1_Tabla_Transferencias_I2C.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F6-asmd%2FGrupo1_Tabla_Transferencias_I2C.drawio.png)) |
| 7 | Bloques control / datapath | SPI ([Ver](docs/diagramas/7-control-datapath/Grupo1_Bloques_Control_Datapath_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F7-control-datapath%2FGrupo1_Bloques_Control_Datapath_SPI.drawio.png))<br>I2C ([Ver](docs/diagramas/7-control-datapath/Grupo1_Bloques_Control_Datapath_I2C.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F7-control-datapath%2FGrupo1_Bloques_Control_Datapath_I2C.drawio.png)) |
| 8 | Máquina de estados (FSM) | SPI ([Ver](docs/diagramas/8-maquinas-de-estado/Grupo1_FSM_SPI.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F8-maquinas-de-estado%2FGrupo1_FSM_SPI.drawio.png))<br>I2C ([Ver](docs/diagramas/8-maquinas-de-estado/Grupo1_FSM_I2C.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F8-maquinas-de-estado%2FGrupo1_FSM_I2C.drawio.png))|
| 9 | Testbench y simulación (casos sacados de la tabla de transferencias) | SPI ([Banco y resultados](sim/README.md) · [Ondas](sim/ondas_jedec_id.png))<br>I2C ([Banco y resultados](sim/README.md#simulación-del-controlador-i2c) · [Log](sim/perip_i2c_tb.log)) |

## Criterio B: integración al SoC

En esta tabla se encuentra lo que pide la guía `uart-riscv.pdf` para conectar los controladores SPI e I2C al procesador. **Ver** abre el archivo en GitHub y **Editar** lo abre en draw.io.

| Ítem | Qué es | Archivos |
| --- | --- | --- |
| 1 | Región del mapa y `cs` | Flash SPI `0x42_0000` · EEPROM I2C `0x46_0000` ([Ver](#qué-hace-este-grupo)) |
| 2 | Mapa de registros MMIO | SPI e I2C ([Ver](tareas-y-actividades/README.md#4-registros-de-control-mmio)) |
| 3 | Decodificador local (`addr[4:0]` → registro) | SPI: decodificador de registros en [`rtl/perip_spi.v`](rtl/perip_spi.v)<br>I2C: decodificador de registros en [`rtl/perip_i2c.v`](rtl/perip_i2c.v)<br>Diagrama del decodificador local y de los mapas de registros de los dos ([Ver](docs/diagramas/9-integracion/Grupo1_Decodificador_Local.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F9-integracion%2FGrupo1_Decodificador_Local.drawio.png)) |
| 4 | Diagrama del adaptador de bus (bus ↔ registros, mux de lectura a `d_out`) | Diagrama del adaptador de bus del FemtoRV32 ↔ SPI e I2C ([Ver](docs/diagramas/9-integracion/Grupo1_Adaptador_de_Bus.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F9-integracion%2FGrupo1_Adaptador_de_Bus.drawio.png))<br>Código: [`rtl/memoria_externa.v`](rtl/memoria_externa.v) |
| 5 | Semántica START / BUSY / DONE (DONE retenido hasta que la CPU lo lee) | SPI: BUSY = busy_core ∨ start y DONE retenido en [`rtl/perip_spi.v`](rtl/perip_spi.v)<br>I2C: BUSY = busy_core ∨ go y DONE retenido en [`rtl/perip_i2c.v`](rtl/perip_i2c.v)<br>Diagrama de START / BUSY / DONE de los dos ([Ver](docs/diagramas/9-integracion/Grupo1_Start_Busy_Done.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F9-integracion%2FGrupo1_Start_Busy_Done.drawio.png)) |
| 6 | Diagrama de tiempos del handshake bus ↔ core | SPI: lectura del JEDEC ID ([Ver](docs/diagramas/9-integracion/Grupo1_Tiempos_Handshake.drawio.png) · [Editar](https://app.diagrams.net/#Hwwilchesc%2FProyecto-Final-Digital-Grupo-10%2Fmain%2Fgrupo1-memoria-externa%2Fdocs%2Fdiagramas%2F9-integracion%2FGrupo1_Tiempos_Handshake.drawio.png))<br>simulación ([inicio](sim/ondas_handshake_inicio.png) · [fin](sim/ondas_handshake_fin.png)) |
| 7 | Verificación de registros y de SoC (testbench) | SPI: registros por el bus ([`sim/perip_spi_tb.v`](sim/perip_spi_tb.v))<br>I2C: registros por el bus ([`sim/perip_i2c_tb.v`](sim/perip_i2c_tb.v))<br>Bloque completo con las señales del bus del FemtoRV32 ([`sim/memoria_externa_tb.v`](sim/memoria_externa_tb.v) · [log](sim/memoria_externa_tb.log)): 10 comprobaciones, 0 errores<br>Prueba en placa sin SoC ([`fpga/prueba_grupo1.v`](fpga/prueba_grupo1.v)) simulada con los modelos ([`sim/prueba_grupo1_tb.v`](sim/prueba_grupo1_tb.v) · [log](sim/prueba_grupo1_tb.log)): 8 comprobaciones, 0 errores<br>SoC: lo prueba el grupo 6 al integrar |
| 8 | Pines y restricciones (`.cst`) | Tabla de pines ([Ver](tareas-y-actividades/README.md#3-mapa-de-hardware-y-conteo-de-pines)) · `.cst` de la Tang Primer 25K ([`fpga/tang_primer_25k.cst`](fpga/tang_primer_25k.cst)) · pines, opción MSPI y paso a la Tang Nano 9K ([Ver](fpga/README.md))<br>Prueba en placa: [`fpga/prueba_grupo1_25k.cst`](fpga/prueba_grupo1_25k.cst) (agrega UART, LEDs y botones del Dock) |

## Hojas de datos

- [EEPROM 24LC256 (Microchip, PDF)](docs/datasheets/24AA256-24LC256-24FC256-256K-I2C-Serial-EEPROM-DS20001203.pdf)
- [Carpeta con todas las hojas de datos](docs/datasheets/)

## Registros

| Desplazamiento | Nombre | Acceso | Descripción |
| --- | --- | --- | --- |
| **SPI** `0x42_0000` | | | |
| 0x00 | CONTROL | L/E | bit0 START · bit1 RW · bits 15:8 COMANDO · bit16 SIN_DIR · bits 18:17 NB · bit19 MANTENER · bit20 CONTINUAR |
| 0x04 | ADDR | L/E | Dirección de 24 bits |
| 0x08 | WDATA | L/E | Byte a escribir |
| 0x0C | RDATA | L | Dato leído (8 o 24 bits) |
| 0x10 | STATUS | L | bit0 BUSY · bit1 DONE (se limpia al leer) · bit2 CS_ACTIVO |
| 0x14 | CLK_DIV | L/E | SCK = f_clk / (2·(CLK_DIV+1)); reset 1 |
| **I2C** `0x46_0000` | | | |
| 0x00 | CONTROL | E | bit0 START · bit1 STOP · bit2 WRITE · bit3 READ · bit4 ACK_OUT (0 = ACK, 1 = NACK al leer). Prioridad START > WRITE > READ > STOP |
| 0x04 | TX_DATA | L/E | Byte a enviar |
| 0x08 | RX_DATA | L | Byte recibido |
| 0x0C | STATUS | L | bit0 BUSY · bit1 ACK_IN (0 = el esclavo respondió) · bit2 DONE (se limpia al leer) |
| 0x10 | CLK_DIV | L/E | SCL = f_clk / (4·(CLK_DIV+1)); reset 124 (≈ 97,8 kHz a 50 MHz) |

## Pines

| Señal | Pin FPGA | Conector | Nota |
| --- | --- | --- | --- |
| | | | |

## Simulación

**SPI**: `make sim` en `sim/` (Icarus Verilog). El banco `perip_spi_tb.v` usa el periférico por el bus con un modelo de la Flash y comprueba JEDEC ID, lecturas de 1, 3, 4 y 8 bytes (MANTENER + CONTINUAR, incluido CONTINUAR dos veces seguidas), T1n con y sin MANTENER, CONTINUAR con CS ya liberado, escritura, BUSY, DONE retenido, CLK_DIV y reset; además verifica que se ejecute cada fila de la tabla de transferencias. Resultado: **53 comprobaciones, 0 errores**. Detalle en [`sim/README.md`](sim/README.md).

**Bloque completo**: `make sim-mem` en `sim/`. El banco `memoria_externa_tb.v` usa `memoria_externa.v` con las señales del bus del FemtoRV32 y la Flash y la EEPROM conectadas a la vez, y comprueba el decodificador de región, el mux de lectura, el JEDEC ID, una escritura y lectura de la EEPROM y los dos periféricos trabajando al mismo tiempo. Resultado: 10 comprobaciones, 0 errores.

**I2C**: `make sim-i2c` en `sim/`. El banco `perip_i2c_tb.v` usa el periférico por el bus con un modelo de la EEPROM 24LC256 y pull-ups en SCL y SDA, y comprueba START/STOP, escritura de un byte, lectura aleatoria con START repetido, lectura secuencial con ACK y NACK, dirección sin respuesta, prioridad de órdenes, estiramiento de reloj, BUSY y reset; además cuenta que se ejecuten las 14 filas de la tabla de transferencias. Resultado: 36 comprobaciones, 0 errores.

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
| 18/11/2026 | ASMD del controlador I2C (paso 6): estados IDLE, ST_1 a ST_4 (START), B_1 a B_4 y B_END (byte de 9 bits con ACK), SP_1 a SP_4 (STOP), SCL_WAIT, WAIT y DONE, con las transferencias T1 a T7 (T1w, T1r y T1p según la orden) |
| 19/11/2026 | ASMD del SPI corregido (reemplaza la versión del 16/11): se define la fase (CMD, DIR, DAT) con su valor, número de bits y fase siguiente; MOSI = sh[31] en LOW y HIGH; IDLE ya no fuerza CS_n = 1, para que CONTINUAR funcione; se agrega T1n para cuando no hay datos que mover |
| 19/11/2026 | Tabla de transferencias del SPI corregida (reemplaza la del 16/11): agrega T1n, la condición CS_n en T1 y T1c, y la tabla "Definición de fase" con hay_datos, falta fase, MOSI y last, para que coincida con el ASMD |
| 19/11/2026 | Flujo clasificado del SPI (paso 5): cada bloque del flujo marcado como control o datapath, con la rama de CONTINUAR y hay_datos |
| 19/11/2026 | Bloques control / datapath del SPI (paso 7): registros MMIO, control (FSM de 9 estados) y datapath (divisor, mux de carga por fase, registro sh de 32 bits con MOSI = sh[31], contador de bits, registro rx), con las órdenes y banderas entre ellos y los pines WP_n y HOLD_n |
| 19/11/2026 | Máquina de estados del SPI (paso 8): 9 estados con las mismas transiciones del ASMD, incluidas T1c y T1n para CONTINUAR, y MOSI como salida de LOW y HIGH |
| 19/11/2026 | Tabla de transferencias por flanco del controlador I2C (paso 6): estado y condición, estado siguiente, registros que cambian en cada flanco, done y valor de `sda_bit` en cada bit |
| 22/11/2026 | Registros del SPI: STATUS agrega bit2 CS_ACTIVO, para que el software sepa si CS_n quedó en 0 por MANTENER antes de usar CONTINUAR |
| 22/11/2026 | RTL del datapath SPI (`rtl/spi_datapath.v`): divisor de tick, mux val(fase)/n(fase), registro sh de 32 bits con MOSI = sh[31], contador bits con last, registro rx de 24 bits y registros SCK y CS_n, todos actualizados en el flanco de subida |
| 22/11/2026 | RTL del control SPI (`rtl/spi_control.v`): FSM de 9 estados con el enfoque A de la guía (próximo estado y órdenes combinacionales, registros en subida); cada rama lleva el ID de su fila en la tabla de transferencias (H1, T1, T1c, T1n … T12) |
| 22/11/2026 | Periférico SPI (`rtl/perip_spi.v`): registros MMIO, decodificador local (escritura solo con BUSY = 0), DONE retenido hasta leer STATUS, lectura registrada para el bus del Quark e instancias del control y el datapath. `rtl/README.md` explica la correspondencia entre el código y la tabla de transferencias |
| 22/11/2026 | Modelo de simulación de la Flash W25Q64 en modo 0 (`sim/flash_model.v`): comandos 0x9F (JEDEC ID), 0x03 (lectura), 0x06 (WREN), 0x02 (page program) y 0x05 (status) |
| 22/11/2026 | Testbench del SPI (paso 9): `sim/perip_spi_tb.v` por el bus MMIO con el modelo de la Flash; 43 comprobaciones sin errores y cobertura de las 18 filas de la tabla de transferencias. Se suben el log, el Makefile y las imágenes de las ondas |
| 22/11/2026 | Firmware del SPI (`firmware/spi_flash.h` y `spi_flash_example.c`): registros con volatile y funciones para JEDEC ID, lectura, lectura en bloque con MANTENER y CONTINUAR y grabación de un byte. Falta compilarlo para RISC-V cuando esté el SoC del grupo 6 |
| 22/11/2026 | Diagrama de tiempos del handshake bus ↔ core del SPI (`docs/diagramas/9-integracion/`): lectura del JEDEC ID con escritura de CONTROL, sondeo de STATUS (BUSY, DONE retenido) y lectura de RDATA |
| 22/11/2026 | Handshake del SPI simulado: `sim/ondas_handshake_inicio.png` y `sim/ondas_handshake_fin.png` muestran la misma secuencia del diagrama (STATUS = 0x5 en curso, 0x2 al terminar, 0x0 después de leerlo y RDATA = 0xEF4017), tomada del VCD de `perip_spi_tb` |
| 22/11/2026 | Flujo clasificado del I2C (paso 5): órdenes START, WRITE/READ y STOP, con cada bloque marcado como control o datapath y la espera de SCL = 1 por estiramiento de reloj |
| 22/11/2026 | Bloques control / datapath del I2C (paso 7): registros MMIO, control (FSM de 17 estados con registros n, ret e is_read) y datapath (contador de cuarto, bcnt, tx, rx, ACK_IN, sincronizadores y salidas de drenador abierto) |
| 22/11/2026 | Máquina de estados del I2C (paso 8): 17 estados (IDLE, ST_1…ST_4, B_1…B_4, B_END, SP_1…SP_4, SCL_WAIT, WAIT y DONE) con las mismas transiciones del ASMD |
| 23/11/2026 | RTL del datapath I2C (`rtl/i2c_datapath.v`): contador de cuarto (tick), bcnt con bit_last, registro tx que desplaza, registro rx, ACK_IN, selector sda_bit, sincronizadores de 2 etapas para SCL y SDA y salidas de drenador abierto |
| 23/11/2026 | RTL del control I2C (`rtl/i2c_control.v`): FSM de 17 estados con el enfoque A de la guía; cada rama lleva el ID de su fila en la tabla de transferencias (H1, T1, T1w, T1r, T1p … T7), y los estados de acción usan WAIT y SCL_WAIT con los registros n y ret |
| 23/11/2026 | Periférico I2C (`rtl/perip_i2c.v`): registros MMIO (CONTROL, TX_DATA, RX_DATA, STATUS, CLK_DIV), decodificador local (escritura solo con BUSY = 0), DONE retenido, lectura registrada y pines de drenador abierto. `rtl/README.md` agrega la sección del I2C con la correspondencia con la tabla de transferencias y las decisiones de diseño |
| 23/11/2026 | Modelo de simulación de la EEPROM 24LC256 (`sim/eeprom_model.v`): dirección 0x50, escritura, lectura aleatoria con START repetido, lectura secuencial, ACK/NACK y estiramiento de reloj configurable |
| 23/11/2026 | Testbench del I2C (paso 9): `sim/perip_i2c_tb.v` por el bus MMIO con el modelo de la EEPROM; 36 comprobaciones sin errores y cobertura de las 14 filas de la tabla de transferencias. El Makefile de `sim/` agrega `make sim-i2c` y `make todo`, y `sim/README.md` agrega la sección del I2C |
| 23/11/2026 | Firmware del I2C (`firmware/i2c_eeprom.h` y `i2c_eeprom_example.c`): registros con volatile, funciones `i2c_cmd` (dar una orden y esperar BUSY = 0) e `i2c_send` (enviar un byte y devolver ACK_IN), `eeprom_write` con espera del ciclo de grabación (ACK polling) y `eeprom_read` con START repetido; el ejemplo comprueba la presencia de la EEPROM, graba 4 bytes y los lee de vuelta. Compila para RV32I; falta integrarlo al SoC |
| 25/11/2026 | Diagrama del decodificador local (criterio B, ítem 3): `addr[4:0]` elige el registro del SPI (CONTROL, ADDR, WDATA, RDATA, STATUS, CLK_DIV) o del I2C (CONTROL, TX_DATA, RX_DATA, STATUS, CLK_DIV), con escritura solo si BUSY = 0 |
| 25/11/2026 | Adaptador de bus (criterio B, ítem 4): diagrama y `rtl/memoria_externa.v`, el bloque que recibe el grupo 6. Decodifica la región (0x0042 → SPI, 0x0046 → I2C), saca `sel` para el mux global del SoC, arma `addr`, `d_in`, `wr = OR(mem_wmask)` y `rd = mem_rstrb`, y elige la respuesta con `sel_q` registrado porque la lectura llega un ciclo después |
| 25/11/2026 | Diagrama de la semántica START / BUSY / DONE del SPI y del I2C (criterio B, ítem 5): START es un pulso de un ciclo, BUSY = busy_core ∨ start para que la CPU no vea BUSY = 0 justo después de dar la orden, y DONE se retiene hasta que la CPU lee STATUS |
| 25/11/2026 | Testbench del bloque completo (`sim/memoria_externa_tb.v`): `memoria_externa.v` con las señales del bus del FemtoRV32, la Flash y la EEPROM conectadas a la vez; 10 comprobaciones sin errores. El Makefile agrega `make sim-mem` y `sim/README.md` la sección del bloque |
| 25/11/2026 | Testbench del SPI: casos nuevos para T1c y T1n, que antes tenían un solo caso cada una. Lectura de 8 bytes con dos CONTINUAR seguidos (el del medio con MANTENER), T1n con MANTENER seguido de un CONTINUAR que lee el byte siguiente, y CONTINUAR con CS ya liberado, que va por T1. Ahora T1c se ejecuta 4 veces y T1n 2; 53 comprobaciones sin errores |
| 25/11/2026 | Firmware del SPI compilado para RV32I (`clang --target=riscv32 -march=rv32i -mabi=ilp32 -ffreestanding -O2 -Wall -Wextra -c spi_flash_example.c`): compila sin advertencias; falta enlazarlo con el arranque y el mapa de memoria del SoC del grupo 6 |
| 25/11/2026 | Pines y restricciones (criterio B, ítem 8): `fpga/tang_primer_25k.cst` con el reloj de 50 MHz (E2), la Flash de la tarjeta en los pines MSPI (E6, E7, D6, E5, D5, E4) y la EEPROM en K4 y J4. `fpga/README.md` explica la opción "Use MSPI as regular IO" y qué cambia al pasar a la Tang Nano 9K (reloj de 27 MHz en el pin 52, Flash en 59 a 62 y CLK_DIV = 67 para el I2C) |
| 25/11/2026 | Prueba en placa (`fpga/prueba_grupo1.v`): módulo superior que prueba todo el bloque del grupo sin el SoC. Un secuenciador hace de CPU por el bus del FemtoRV32 sobre `memoria_externa.v` y prueba el SPI (JEDEC ID, borrado de sector, grabación y lectura, MANTENER + CONTINUAR) y el I2C (ACK de la EEPROM, grabación y lectura con START repetido); manda el reporte por UART y enciende un LED por cada parte que pasa. `sim/flash_model.v` agrega el borrado de sector (0x20) |
| 25/11/2026 | Testbench de la prueba en placa (`sim/prueba_grupo1_tb.v`): conecta `prueba_grupo1.v` con los modelos de la Flash y la EEPROM, decodifica la UART e imprime el reporte como saldría en la terminal; dos corridas (0x5A al arrancar y 0x5B con el botón), 8 comprobaciones sin errores. El Makefile agrega `make sim-prueba` |
| 25/11/2026 | Pines de la prueba en placa (`fpga/prueba_grupo1_25k.cst`): UART del depurador (C3), LEDs del Dock (E8 y D7), botones (H11 y H10), la Flash de la tarjeta y la EEPROM en el conector J3 (K4 y J4). `fpga/README.md` explica el cableado de la 24LC256, las opciones de pines de doble uso, los pasos en Gowin IDE y cómo se ve el reporte en la terminal |

## Pendientes y problemas

- Probar en la Tang Primer 25K con `fpga/prueba_grupo1.v` (pasos en [`fpga/README.md`](fpga/README.md#prueba-en-placa-spi-e-i2c-juntos)) y grabar el video como evidencia.
- Pasar a la Tang Nano 9K del SoC: cambiar el reloj (27 MHz, pin 52), los pines (Flash en 59 a 62) y `CLK_DIV` del I2C a 67, como explica [`fpga/README.md`](fpga/README.md).
- Definir con el grupo 5 el formato de la tabla de récords.
