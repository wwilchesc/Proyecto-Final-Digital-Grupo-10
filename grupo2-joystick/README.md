# Grupo 2 · Joystick SPI

Receptor del Joystick: recibe la posición de los ejes y los botones que presiona el jugador y se los entrega al procesador.

## Integrantes

- Miguel Pardo
- Cristian Silva
- Sebastian Ochoa
- Arturo Tello

## Qué hace este grupo

Nuestro grupo implementa el periférico de joystick analógico de la consola de videojuegos. Su función es leer la posición de dos joysticks (ejes X e Y de cada uno) y el estado de sus pulsadores, y dejar esa información disponible para el procesador FemtoRV32, que la usa para controlar el juego (mover al personaje, navegar menús, etc.).

Cada joystick entrega dos voltajes analógicos, uno por eje, entre 0 y 3.3 V. Como la FPGA Tang Nano 9K solo trabaja con señales digitales, usamos un conversor analógico-digital MCP3008 con 4 canales activos (`CH0` a `CH3`, 10 bits, resolución de 3.22mV por paso). El ADC se comunica con la FPGA por SPI en modo 0, donde la FPGA actúa como maestro y el MCP3008 como esclavo.

- **Dispositivo(s):** Dos joysticks analógicos (KY-023) conectados a un MCP3008
- **Protocolo:** SPI Modo 0 (trama de 24 pulsos / 3 bytes por canal)
- **Módulo RTL:** `perip_joystick.v`
- **Dirección base en el mapa de memoria:** `0x0043_0000` (`cs[3]`)

## Tareas

[x] Estudiar el protocolo SPI y la trama del MCP3008
[x] 1. Caja negra + características
[x] 2. Bloques + señales
[x] 3. Diagrama de tiempos
[x] 4. Diagrama de flujo
[x] 5. Clasificación control/datapath
[x] 6. ASMD + tabla de transferencias
[ ] 7. Arquitectura control/datapath
[ ] 8. FSM
# 1. Terminología básica

En esta sección se explican los principales conceptos que se utilizan en el desarrollo del periférico. La idea es conocer primero los componentes, las señales y los términos relacionados con la comunicación entre dispositivos, para entender con mayor facilidad el funcionamiento del sistema y las etapas de implementación.

## 1.1. Descripción general del proyecto

El proyecto consiste en desarrollar un periférico que permita conectar dos joysticks analógicos a un procesador FemtoRV32 implementado en una FPGA Tang Nano 9K.

Cuando se mueve un joystick, sus ejes generan señales de voltaje que cambian según la posición de la palanca. Estas señales llegan al conversor MCP3008, que se encarga de transformarlas en valores digitales. Después, la FPGA recibe los datos mediante comunicación SPI y los guarda en registros para que el procesador pueda consultarlos.

## 1.2. Componentes principales

Antes de explicar la comunicación entre los dispositivos, es importante identificar la función que cumple cada uno dentro del proyecto.

| Término | Descripción |
|---|---|
| **Joystick analógico** | Es una palanca que permite detectar movimientos en dos direcciones, X y Y. Cada eje tiene un potenciómetro que modifica su voltaje dependiendo de la posición. En nuestro caso trabajamos con un rango de 0 a 3,3 V, por lo que en el centro se espera un valor cercano a 1,65 V. También cuenta con un botón (`SW`) que funciona como interruptor activo en bajo. |
| **Señal analógica** | Es una señal cuyo valor puede cambiar de manera continua dentro de un rango determinado. Por ejemplo, el voltaje que entrega un joystick cuando se mueve. |
| **Señal digital** | Es una señal que representa información mediante dos niveles lógicos, 0 y 1. Estos niveles permiten que los circuitos digitales procesen y transmitan información. |
| **FPGA (Tang Nano 9K)** | Es un dispositivo que permite configurar circuitos digitales según las necesidades del proyecto. La utilizamos para implementar el periférico y controlar la comunicación con el ADC. |
| **ADC (conversor analógico-digital)** | Es un circuito que convierte una señal analógica, como un voltaje, en un valor numérico que puede procesar un sistema digital. |
| **MCP3008** | Es el conversor ADC que utilizamos. Tiene ocho canales de entrada y una resolución de 10 bits. Se comunica con la FPGA mediante SPI. |
| **FemtoRV32** | Es un procesador basado en la arquitectura RISC-V. En nuestro sistema ejecuta el programa del juego y obtiene la información de los joysticks leyendo los registros del periférico. |
| **SoC (System on Chip)** | Es un sistema que integra un procesador y diferentes periféricos dentro de un mismo chip. En este proyecto, estos elementos se implementan en la FPGA. |
| **Periférico** | Es un módulo que realiza una función específica y se comunica con el procesador. En nuestro caso, permite obtener la posición de los joysticks y el estado de sus botones. |

## 1.3. Bits, resolución y representación de los datos

Como el MCP3008 convierte voltajes en números, necesitamos entender cómo se representan esos valores y qué significa trabajar con una resolución de 10 bits.

| Término | Descripción |
|---|---|
| **Bit** | Es la unidad más pequeña de información digital y puede tomar el valor de 0 o 1. |
| **Byte** | Es un conjunto de 8 bits. |
| **10 bits** | Significa que el resultado de una conversión puede representarse mediante 1024 valores diferentes, desde 0 hasta 1023. |
| **Resolución** | Indica el cambio de voltaje correspondiente a un paso del ADC. Si utilizamos una referencia de 3,3 V, cada paso equivale aproximadamente a 3,22 mV. |
| **Ejemplo de conversión** | Con una referencia de 3,3 V, una entrada de 0 V produce un valor de 0; una de 1,65 V produce aproximadamente 512, y una cercana a 3,3 V produce 1023. |
| **MSB (Most Significant Bit)** | Es el bit de mayor peso dentro de un número binario. En el formato de lectura que usamos, es el primer bit del resultado que transmite el ADC. |
| **LSB (Least Significant Bit)** | Es el bit de menor peso. En nuestro caso, corresponde al último bit del resultado transmitido. |
| **B9 a B0** | Son los diez bits que forman el resultado de la conversión. B9 es el más significativo y B0 el menos significativo. |
| **VREF (voltaje de referencia)** | Es el voltaje que establece el rango de medición del ADC. Para nuestro diseño utilizamos 3,3 V. |
| **Muestreo** | Es el momento en el que el ADC toma el valor de la señal analógica para realizar la medición. |
| **Conversión** | Es el proceso mediante el cual el ADC transforma el voltaje medido en un número digital de 10 bits. |

## 1.4. Comunicación SPI

Para intercambiar información entre la FPGA y el MCP3008 utilizamos el protocolo SPI. Este permite transmitir datos de manera serial, es decir, un bit a la vez.

La FPGA controla la comunicación y selecciona el canal que necesita leer, mientras que el MCP3008 realiza la conversión y devuelve el resultado.

| Término | Descripción |
|---|---|
| **SPI (Serial Peripheral Interface)** | Es un protocolo de comunicación serial que permite intercambiar datos entre dispositivos electrónicos. |
| **Maestro** | Es el dispositivo que controla la comunicación y genera la señal de reloj. En nuestro caso es la FPGA. |
| **Esclavo** | Es el dispositivo que responde a las instrucciones del maestro. En este proyecto corresponde al MCP3008. |
| **SCLK (`mcp_sck`)** | Es la señal de reloj que sincroniza la transmisión de datos. La genera la FPGA. |
| **CS (`mcp_cs_n`)** | Es la señal que permite seleccionar el ADC. Cuando está en 0, el MCP3008 puede recibir instrucciones. Cuando vuelve a 1, termina la comunicación. |
| **MOSI / DIN (`mcp_mosi`)** | Es la línea por la que la FPGA envía los bits de configuración al MCP3008, como la selección del canal que desea medir. |
| **MISO / DOUT (`mcp_miso`)** | Es la línea por la que el MCP3008 envía a la FPGA los bits correspondientes al resultado de la conversión. |
| **Flanco de subida** | Es el instante en que una señal digital cambia de 0 a 1. |
| **Flanco de bajada** | Es el instante en que una señal digital cambia de 1 a 0. |
| **Modo 0 (CPOL = 0, CPHA = 0)** | Es una configuración de SPI en la que el reloj permanece en 0 cuando no está transmitiendo datos. La información se lee en el flanco de subida y se actualiza en el de bajada. |
| **Alta impedancia (Hi-Z)** | Es un estado en el que una salida deja de controlar eléctricamente la línea. El MCP3008 utiliza este estado en DOUT cuando no está transmitiendo datos. |

## 1.5. Estructura de la trama SPI

Cada vez que necesitamos conocer el valor de un eje del joystick, la FPGA inicia una comunicación con el MCP3008. Primero envía los bits que indican qué canal debe medir y después recibe el resultado.

Para nuestro diseño implementamos la **trama estándar de 3 bytes (24 pulsos de reloj `mcp_sck`)**, alineada a bytes completos, que incluye 7 bits iniciales de relleno en `0`, el bit de inicio (`Start`), los 4 bits de configuración, el ciclo de muestreo, el *Null bit* y los 10 bits de la conversión.

| Término | Descripción |
|---|---|
| **Trama** | Es la secuencia de 24 bits que se transmite durante una comunicación por canal. Incluye la configuración del ADC y los datos de respuesta. |
| **Start bit** | Es un bit con valor 1 (en el pulso 8 de la trama de 24 pulsos) que indica al MCP3008 el inicio de una solicitud. |
| **SGL/DIFF** | Permite seleccionar el tipo de medición. Con valor 1 se utiliza el modo de entrada individual (*single-ended*), que mide cada canal respecto a tierra. Con valor 0 se utiliza el modo diferencial. En nuestro diseño usamos el valor 1. |
| **D2, D1 y D0** | Son tres bits que permiten seleccionar uno de los ocho canales del MCP3008. Por ejemplo, `000` corresponde a `CH0` y `001` a `CH1`. |
| **Canales CH0 a CH7** | Son las ocho entradas analógicas disponibles. Para los dos joysticks utilizamos cuatro canales, del `CH0` al `CH3`, uno por cada eje. |
| **Periodo de muestreo** | Es el intervalo durante el cual el ADC adquiere el valor del voltaje de entrada. Después de recibir los bits de selección, necesita un ciclo adicional de reloj para completar esta etapa. |
| **Null bit** | Es un bit con valor 0 que aparece antes de los diez bits del resultado. No forma parte del valor de la conversión, por lo que la FPGA debe ignorarlo. |

Después del bit nulo, el MCP3008 envía el resultado comenzando por `B9` y terminando en `B0`. Una vez recibidos los diez bits, la FPGA finaliza la comunicación y almacena el valor obtenido.

## 1.6. Parámetros de tiempo del MCP3008

Para que la comunicación funcione correctamente, debemos respetar los tiempos establecidos por el fabricante en el *datasheet* del MCP3008.

Estos parámetros determinan la velocidad a la que podemos transmitir información y los intervalos mínimos que deben existir entre algunas señales.

| Parámetro | Descripción |
|---|---|
| **fCLK (frecuencia de SCLK)** | Indica la velocidad del reloj utilizado en la comunicación. El fabricante especifica un máximo de 1,35 MHz para una alimentación de 2,7 V y de 3,6 MHz para 5 V. Como nuestro sistema funciona a 3,3 V, utilizamos 1,35 MHz como límite conservador de diseño. |
| **tHI / tLO** | Son los tiempos mínimos durante los cuales SCLK debe mantenerse en nivel alto y bajo. Según el *datasheet*, ambos deben ser de al menos 125 ns. |
| **tSUCS** | Es el tiempo mínimo que debe transcurrir entre la activación de CS y el primer flanco de subida del reloj. Su valor mínimo es 100 ns. |
| **tCSH** | Es el tiempo mínimo durante el cual CS debe permanecer en alto antes de iniciar una nueva comunicación. El valor indicado es 270 ns. |
| **ns (nanosegundo)** | Es una unidad de tiempo equivalente a una milmillonésima parte de un segundo 10 ns. |
| **µs (microsegundo)** | Es una unidad de tiempo equivalente a una millonésima parte de un segundo 10 μs. |
| **MHz (megahercio)** | Es una unidad de frecuencia que representa un millón de ciclos por segundo. |
| **ksps (kilomuestras por segundo)** | Indica cuántos miles de muestras puede realizar un ADC cada segundo. El MCP3008 tiene una capacidad especificada de 75 ksps a 2,7 V y 200 ksps a 5 V. |
| **Divisor de reloj** | Es un circuito que permite obtener una frecuencia menor a partir del reloj principal de la FPGA. En nuestro diseño dividimos el reloj de 27 MHz con `CLKDIV = 10` para generar `mcp_sck` a 1,35 MHz. |

En nuestro caso, no necesitamos realizar conversiones a una velocidad tan alta, ya que los movimientos de los joysticks son relativamente lentos. Lo importante es que las lecturas se realicen con suficiente frecuencia para detectar los cambios de posición sin retrasos perceptibles durante el juego.

## 1.7. Conceptos para la implementación del periférico

Finalmente, hay algunos términos que utilizamos al desarrollar el circuito en Verilog y conectarlo con el procesador FemtoRV32.

| Término | Descripción |
|---|---|
| **Registro** | Es un conjunto de bits que permite almacenar información dentro de un circuito digital. Utilizamos 8 registros MMIO para configurar el periférico y conservar los valores de los ejes y botones. |
| **Mapa de memoria** | Es la organización de las direcciones que utiliza el procesador para acceder a la memoria y a los periféricos. |
| **Dirección base (`0x0043_0000`)** | Es la dirección asignada a nuestro periférico dentro del mapa de memoria del sistema (`cs[3]`). A partir de ella se definen las posiciones donde el procesador consulta los datos. |
| **Verilog** | Es un lenguaje de descripción de hardware que utilizamos para diseñar los circuitos digitales que se implementarán en la FPGA. |
| **FSM (máquina de estados finitos)** | Es una forma de organizar el funcionamiento de un circuito mediante estados definidos. En nuestro diseño permite controlar los pasos de comunicación SPI, desde la activación de CS hasta la recepción de los datos. |
| **Testbench** | Es un entorno de simulación que permite comprobar el funcionamiento de un circuito antes de implementarlo físicamente. Lo utilizamos para simular las respuestas del MCP3008 y verificar que la FPGA interprete correctamente los datos. |

Con estos conceptos podemos entender el recorrido de la información dentro del sistema: los joysticks generan los voltajes, el MCP3008 los convierte en números digitales y la FPGA se encarga de recibirlos y almacenarlos. Finalmente, el procesador FemtoRV32 consulta esos registros para utilizar los movimientos y botones dentro del juego.

---

# 2. Protocolo SPI y funcionamiento con el MCP3008

## 2.1 La idea general

SPI es una conversación entre dos chips: **un maestro** que manda y **un esclavo** que obedece. Nos ayuda imaginarlo como un walkie-talkie con metrónomo:

- El maestro (la FPGA) **marca el ritmo** con un reloj (`mcp_sck`).
- En cada tick, **un bit sale del maestro hacia el esclavo** y **un bit sale del esclavo hacia el maestro**, al mismo tiempo.
- Cada chip tiene un **registro de desplazamiento**: una fila de casillas donde, en cada tick, todos los bits se corren un lugar, entra uno nuevo por un extremo y sale otro por el otro.

Después de **24 ticks** (3 bytes), la FPGA habrá enviado su comando y habrá recibido el número de 10 bits alineado en los últimos 10 pulsos.

> **Regla de oro:** el esclavo nunca habla por su cuenta. Solo responde mientras el maestro tenga `mcp_cs_n` en bajo y mande pulsos de `mcp_sck`.

## 2.2 Las 4 líneas y cómo se conectan

La FPGA y el MCP3008 se unen con cuatro líneas:

| Línea (`perip_joystick`) | Dirección | Pin del MCP3008 | Conexión |
|---|---|---|---|
| **SCLK (`mcp_sck`)** | FPGA → ADC | 13 (CLK) | Reloj generado por la FPGA |
| **MOSI (`mcp_mosi`)** | FPGA → ADC | 11 (DIN) | Comando que envía la FPGA |
| **MISO (`mcp_miso`)** | ADC → FPGA | 12 (DOUT) | Resultado que envía el ADC |
| **CS (`mcp_cs_n`)** | FPGA → ADC | 10 (CS/SHDN) | Selección del chip, activa en bajo |

Además, el chip necesita alimentación y las entradas de los joysticks:

| Pin | Nombre | Conectar a |
|---|---|---|
| 16 | VDD | 3.3 V |
| 15 | VREF | 3.3 V (define que 3.3 V = 1023) |
| 14 | AGND | GND |
| 9 | DGND | GND |
| 1 a 4 | CH0 a CH3 | Ejes X e Y de los dos joysticks (3.3 V arriba, GND abajo, cada eje a su canal) |

Todos los GND deben ir unidos. Sin tierra común, SPI no funciona.

## 2.3 Reglas del modo 0: quién cambia y quién lee, y cuándo

En modo 0, `mcp_sck` **descansa en 0**. En cada pulso hay dos momentos:

| Momento | Qué pasa |
|---|---|
| **Flanco de subida** (0 → 1) | Se **leen** los bits: el ADC lee MOSI y la FPGA lee MISO. |
| **Flanco de bajada** (1 → 0) | Se **cambian** los bits: la FPGA pone el siguiente bit en MOSI y el ADC pone el siguiente bit en MISO. |

Con esta división nadie lee una línea mientras está cambiando. Cada bit se prepara en la bajada y se lee estable en la subida siguiente.

## 2.4 Límites de tiempo que tenemos que respetar

Estos valores salen del datasheet de Microchip MCP3004/3008:

- Velocidad de SCLK: 3.6 MHz como máximo a 5 V y 1.35 MHz a 2.7 V. Como trabajamos a 3.3 V, usamos **1.35 MHz** por defecto (`CLKDIV = 10` con reloj de 27 MHz), que es el valor seguro.
- SCLK en alto y en bajo (t_HI, t_LO): al menos 125 ns cada uno. Con `CLKDIV = 10`, cada semiperiodo dura **370 ns**.
- De bajar CS al primer flanco de subida (t_SUCS): al menos 100 ns. En nuestro RTL el tiempo medido es **$\approx 740\text{ ns}$**.
- CS en alto entre conversiones (t_CSH): al menos 270 ns.

## 2.5 Una transacción completa, pulso a pulso (trama de 24 pulsos / 3 bytes)

Llamamos **transacción** a una conversación completa: `mcp_cs_n` baja, se envían **24 pulsos** (3 bytes) y `mcp_cs_n` sube.

**Estado de reposo (siempre antes y después):** `mcp_cs_n = 1`, `mcp_sck = 0`, `mcp_mosi = 0`.

**Secuencia implementada en `perip_joystick.v`:**

1. **Bajamos `mcp_cs_n`** a 0 y esperamos el tiempo de setup (`S_SETUP`, ≥ 100 ns).
2. **Transmitimos 24 pulsos de `mcp_sck`** (3 bytes): en cada flanco de subida se muestrea `mcp_miso` y en cada flanco de bajada se actualiza `mcp_mosi`.
3. **Después del pulso 24**, dejamos `mcp_sck` en 0.
4. **Subimos `mcp_cs_n`** a 1 y lo mantenemos ≥ 270 ns antes de la siguiente transacción.
5. **Guardamos** los 10 bits recibidos (pulsos 15 a 24) en el registro correspondiente al canal (`J1_X`, `J1_Y`, `J2_X` o `J2_Y`).

### Trama de 24 pulsos (3 bytes)

| Pulso | Byte | DIN (`mcp_mosi`, FPGA → ADC) | DOUT (`mcp_miso`, ADC → FPGA) |
|---|---|---|---|
| 1 a 7 | Byte 1 (`0x01`) | `0` (relleno) | Alta impedancia |
| 8 | Byte 1 (`0x01`) | **Start = 1** | Alta impedancia |
| 9 | Byte 2 (`0x80`–`0xB0`) | **SGL/DIFF = 1** | Alta impedancia |
| 10 | Byte 2 | **D2** | Alta impedancia |
| 11 | Byte 2 | **D1** | Alta impedancia |
| 12 | Byte 2 | **D0** | Alta impedancia |
| 13 | Byte 2 | `0` (no importa) | Alta impedancia (muestreo) |
| 14 | Byte 2 | `0` (no importa) | **Null bit = 0** |
| 15 a 16 | Byte 2 | `0` (no importa) | **B9, B8** |
| 17 a 24 | Byte 3 (`0x00`) | `0` (no importa) | **B7, B6, …, B0** |

### Comandos CH0 a CH3 (single-ended)

Los 4 bits del comando son `{SGL/DIFF, D2, D1, D0}`.

| Canal | Eje asignado | Comando | Byte 1 | Byte 2 | Byte 3 |
|---|---|---|---|---|---|
| `CH0` | `J1_X` (Jugador 1 X) | `1000` | `0x01` | `0x80` | `0x00` |
| `CH1` | `J1_Y` (Jugador 1 Y) | `1001` | `0x01` | `0x90` | `0x00` |
| `CH2` | `J2_X` (Jugador 2 X) | `1010` | `0x01` | `0xA0` | `0x00` |
| `CH3` | `J2_Y` (Jugador 2 Y) | `1011` | `0x01` | `0xB0` | `0x00` |

## 2.6 Ejemplo completo: leer el eje Y del jugador 1 (`CH1`)

Para verlo con números, suponemos que el eje mide **2.18 V**. Como 2.18 / 3.22mV = 677, el ADC devuelve **677 = `10 1010 0101` en binario (`0x2A5`)**.

La FPGA envía los 3 bytes **`0x01`**, **`0x90`** (`1 001 0000`) y **`0x00`**:

| Byte | Se envía (`mcp_mosi`) | Se recibe (`mcp_miso`) | Qué hace la FPGA |
|---|---|---|---|
| 1 (pulsos 1–8) | `0x01` (`0000_0001`) | Alta impedancia | Ignora |
| 2 (pulsos 9–16) | `0x90` (`1001_0000`) | Hi-Z, muestreo, `0` (null), **`10`** (`B9`, `B8`) | Guarda `rx2[1:0] = 10` |
| 3 (pulsos 17–24) | `0x00` (`0000_0000`) | **`1010_0101`** (`B7` a `B0`, `0xA5`) | Guarda `rx3 = 0xA5` |

Al unir los 10 bits recibidos: `valor = {rx2[1:0], rx3} = 10'b10_1010_0101 = 0x2A5 = 677`.

## 2.7 Leer varios canales

El MCP3008 mide **un solo canal por transacción**. Para leer X e Y de dos jugadores hacemos 4 transacciones seguidas (**96 pulsos de `mcp_sck` en total**, 76 μs a 1.35 MHz):

1. `CH0` → registro `J1_X` (eje X del jugador 1).
2. `CH1` → registro `J1_Y` (eje Y del jugador 1).
3. `CH2` → registro `J2_X` (eje X del jugador 2).
4. `CH3` → registro `J2_Y` (eje Y del jugador 2).

Entre una y otra, `mcp_cs_n` sube y espera ≥ 270 ns. Cuando `CTRL.ENABLE = 1`, el ciclo se repite de forma continua y el procesador siempre encuentra el último valor leído en los registros.

## 2.8 Cómo lo traducimos a un circuito en la FPGA

Para implementarlo necesitamos 4 bloques sencillos:

| Bloque | Función |
|---|---|
| **Divisor de reloj** | Cuenta ciclos del reloj de sistema (27 MHz) según `CLKDIV` (por defecto `10`) y genera el tick para `mcp_sck` a 1.35 MHz. |
| **Contador de pulsos** | Cuenta los **24 pulsos** de la trama (0 a 23) para saber en qué bit de los 3 bytes vamos. |
| **Registros de desplazamiento** | Uno envía la trama de 24 bits por `mcp_mosi` y otro captura los 10 bits útiles (`B9` a `B0`) por `mcp_miso`. |
| **FSM (máquina de estados)** | Coordina el barrido de los 4 canales: `IDLE → S_SETUP → TRANSFERENCIA_24_PULSOS → CS_SUBE → ESPERA → SIGUIENTE_CANAL`. |

Una buena práctica que seguimos es **no usar SCLK como reloj interno** de la FPGA. Mantenemos todo en el reloj de sistema (`clk` de 27 MHz) y generamos `mcp_sck` como una señal normal que cambia cuando llega el tick del divisor. Así evitamos problemas de sincronización.

## 2.9 Errores comunes y cómo reconocerlos

Esta tabla nos sirve para depurar cuando probemos el diseño en hardware:

| Síntoma | Causa probable |
|---|---|
| Siempre lee 0 | MISO desconectado, CS nunca baja, o el comando está mal formado. |
| Siempre lee 1023 | VREF o VDD sin alimentar, o MISO flotante en alto. |
| Valores a la mitad o al doble de lo esperado | Un bit de desfase: se leyó un pulso antes o después. Revisar dónde se descarta el null bit. |
| Valores ruidosos o erráticos | SCLK demasiado rápido, cables largos, o falta de tierra común. |
| Canal equivocado | Bits D2 D1 D0 mal ordenados. D2 sale primero. |
| Funciona en simulación, falla en la placa | Tiempos (t_SUCS, t_CSH) no respetados, o modo SPI equivocado. |
| Solo cambia un bit del resultado | Se está usando el flanco de bajada para leer MISO. |

**Prueba de sanidad para hacer en la placa:**

- Entrada a GND → resultado 0.
- Entrada a 3.3 V → resultado 1023.
- Joystick centrado → resultado 512.

## 2.10 Lista de verificación antes de simular o probar

- [x] En reposo: `mcp_cs_n = 1`, `mcp_sck = 0`.
- [x] `mcp_sck` ≤1.35 MHz y semiperiodo > 125 ns (medido: 370 ns).
- [x] `mcp_cs_n` baja ≥ 100 ns antes del primer pulso (medido: 740 ns).
- [x] `mcp_mosi` cambia en las bajadas y `mcp_miso` se lee en las subidas.
- [x] Se descarta el null bit, y `B9` es el primer bit guardado.
- [x] El comando de cada canal es correcto (`CH0 = 0x80`, `CH1 = 0x90`, `CH2 = 0xA0`, `CH3 = 0xB0`).
- [x] `mcp_cs_n` en alto ≥ 270 ns entre transacciones.
- [ ] En placa: todas las tierras unidas, y `VDD = VREF = 3.3 V`.

---

# 3. Diseño

En esta sección se detalla la arquitectura interna del controlador Verilog (`perip_joystick.v`), el funcionamiento de la máquina de estados (FSM) que gestiona la comunicación SPI y el cálculo de división de reloj.

## 3.1 Arquitectura General y Diagrama de Bloques

El módulo se compone de cuatro sub-bloques funcionales diseñados para operar de forma síncrona con el reloj principal de la FPGA (27 MHz) y abstraer la complejidad del protocolo SPI al procesador:

* **Generador de Reloj (`clk_divider`):** Toma el reloj del sistema de la FPGA (27 MHz) y genera impulsos de habilitación usando el divisor `CLKDIV` (por defecto `10`) para obtener `mcp_sck` a 1.35 MHz.
* **Máquina de Estados Principal (`spi_fsm`):** Coordina los ciclos de lectura secuencial de los 4 canales (`CH0` a `CH3`) con tramas de 24 pulsos y controla los tiempos de espera de Chip Select (t_SUCS y t_CSH).
* **Registros de Desplazamiento (`shift_registers`):**
  * *Registro de Transmisión (Tx):* Envía la trama de 24 bits (3 bytes: `0x01`, byte de canal `0x80`–`0xB0`, `0x00`) por la línea `mcp_mosi`.
  * *Registro de Recepción (Rx):* Captura en serie los bits que entrega el ADC por la línea `mcp_miso`, descartando los bits iniciales y el *null bit*, y acumulando los 10 bits de datos (`B9` a `B0`).
* **Banco de Registros e Interfaz de Bus (`reg_file`):** Mantiene almacenados los valores actualizados de los ejes (`J1_X`, `J1_Y`, `J2_X`, `J2_Y`), sincroniza los pulsadores (`BUTTONS`) y gestiona las lecturas/escrituras del procesador FemtoRV32.

## 3.2 Clasificación control/datapath
Ahora vamos a presentar la separación del periférico en dos partes: el **datapath** que es el encargado de guardar y mover los datos y la **unidad de control** (La maquina de estados), esta decide que se hace en cada momento.

|Elemento|Parte|Función|
|---|---|---|
| Divisor `tick` y comparación `tick_done = (tick == clkdiv − 1)` | Datapath | Es el encargado de contar los ciclos de 27 MHz y da un ¨tick¨ o un pulso de corta duración cada medio periodo del reloj del SPI `mcp_sck` |
| Registro `CLKDIV` | Datapath | Guarda el divisor (10 despues del reset)
| Contador de pulsos `n` y comparación `n == 24` | Datapath | Lleva la cuenta de los 24 pulsos|
| Palabra de transmisión `tx_w` (24 bits) | Datapath | Arma la trama con el canal: `{8'h01, 1'b1, 1'b0, ch[1:0], 4'b0000, 8'h00}`. En cada bajada sale el bit `tx_w[23 − n]` por `mcp_mosi` |
| Registro de recepción `rx` (10 bits) | Datapath | En cada subida corre sus bits y mete el que llega por `mcp_miso` |
| Contador de canal `ch` (2 bits) | Datapath | Recorre `CH0` a `CH3` |
| `j1x`, `j1y`, `j2x`, `j2y` (10 bits, reset 512) | Datapath | Guardan el último valor de cada canal (registros `J1_X`, `J1_Y`, `J2_X`, `J2_Y`) |
| `mcp_sck` | Datapath | Reloj SPI hacia el ADC. Marca el ritmo: en cada pulso viaja un bit en cada sentido |
| `mcp_cs_n` | Datapath | *Chip Select*, activo en bajo (por eso la "_n"). En 0 el ADC escucha; al subir termina la lectura |
| `mcp_mosi` | Datapath | *Master Out, Slave In*: lleva el comando de la FPGA al ADC |
| `mcp_miso` | Datapath | *Master In, Slave Out*: trae el resultado del ADC, del bit de más peso al de menos |
| Sincronizador de botones (`btn_ff1`, `btn_ff2`) | Datapath | El botón puede cambiar en cualquier momento; con dos flip-flops la FPGA siempre lo lee como un 0 o un 1 claro. `buttons = ~btn_ff2`, así 1 = presionado |
| Multiplexor de lectura (`addr[4:0]`) | Datapath | Pone en `d_out` el registro que pide el procesador |
| FSM (`S_IDLE`, `S_SETUP`, `S_BIT`, `S_END`, `S_GAP`) | **Control** | Lleva la secuencia de cada lectura |
| Bits `enable` y `start_req` de `CTRL` | Control | `ENABLE`: barrido continuo. `START`: un solo barrido, se borra solo |
| Bit `valid` de `STATUS` | Control | Indica que ya se completó un barrido y los ejes no son los 512 del reset |
| `busy` | Control | Vale 1 cuando la FSM no está en `S_IDLE` |
 
Órdenes que manda la FSM al datapath:
 
| Señal | Efecto |
|---|---|
| `tick_clr` | `tick ← 0`, reinicia el conteo de tiempo |
| `sck_hi` / `sck_lo` | Sube o baja `mcp_sck` (cada flanco del reloj SPI) |
| `sh_rx` | Mete `mcp_miso` en `rx` y hace `cnt ← cnt + 1` |
| `upd_mosi` | Carga en `mcp_mosi` el bit que toca del comando |
| `cs_lo` / `cs_hi` | Baja o sube `mcp_cs_n`: empieza o termina la lectura |
| `ld_res` | Copia `rx` al registro del canal `ch` |
| `ch_inc` | `ch ← ch + 1`, pasa al siguiente eje |
 
## 3.3 ASMD + tabla de transferencia
Estados:
- `S_IDLE`: esperando. `busy = 0`, `mcp_cs_n = 1`, `mcp_sck = 0`.
- `S_SETUP`: CS ya está abajo y el primer bit del comando ya está en MOSI; se espera medio periodo.
- `S_BIT`: los 24 pulsos. En la subida se lee `mcp_miso`; en la bajada se cambia `mcp_mosi`.
- `S_END`: CS sube; al cumplirse el medio periodo se guarda el resultado y avanza el canal.
- `S_GAP`: medio periodo más con CS arriba; aquí se decide si el barrido terminó.
Como la primera subida de `mcp_sck` llega un medio periodo después de salir de `S_SETUP`, entre la bajada de CS y ese flanco pasan dos medios periodos. Lo mismo pasa con CS en alto. Los dos superan con holgura tSUCS = 100 ns y tCSH = 270 ns.

```mermaid
flowchart TD
    S0["S_IDLE<br/>busy=0, cs_n=1, sck=0"]
    S1["S_SETUP<br/>espera tSUCS"]
    S2["S_BIT<br/>24 pulsos"]
    S3["S_END<br/>cs_n=1"]
    S4["S_GAP<br/>espera tCSH"]
    S0 --> D0{"enable o start_req<br/>o ch distinto de 0"}
    D0 -- no --> S0
    D0 -- sí --> O0(["cs_n ← 0, n ← 0, tick ← 0<br/>mosi ← tx_w[23]"]) --> S1
    S1 --> D1{"tick_done"}
    D1 -- no --> O3(["tick ← tick+1"]) --> S2
    D2 -- sí --> D3{"sck"}
    D3 -- 0 --> O4(["sck ← 1, rx ← {rx[22:0], miso}<br/>n ← n+1, tick ← 0"]) --> S2
    D3 -- 1 --> D4{"n = 24"}
    D4 -- no --> O5(["sck ← 0, mosi ← tx_w[23−n]<br/>tick ← 0"]) --> S2
    D4 -- sí --> O6(["sck ← 0, cs_n ← 1<br/>tick ← 0"]) --> S3
    S3 --> D5{"tick_done"}
    D5 -- no --> O7(["tick ← tick+1"]) --> S3
    D5 -- sí --> O8(["res[ch] ← rx[9:0]<br/>ch ← ch+1, tick ← 0"]) --> S4
    S4 --> D6{"tick_done"}
    D6 -- no --> O9(["tick ← tick+1"]) --> S4
    D6 -- sí --> D7{"ch = 0"}
    D7 -- no --> O10(["tick ← 0"]) --> S0
    D7 -- sí --> O11(["valid ← 1, start_req ← 0<br/>tick ← 0"]) --> S0
 ```
Despues de esto podemos construir l tabla de transferencias:
| Estado | Condición | Transferencias | Siguiente |
|---|---|---|---|
| `S_IDLE` | `enable ∨ start_req ∨ ch≠0` | `cs_n←0; n←0; tick←0; mosi←tx_w[23]` | `S_SETUP` |
| `S_IDLE` | si no | — | `S_IDLE` |
| `S_SETUP` | `tick_done=0` | `tick←tick+1` | `S_SETUP` |
| `S_SETUP` | `tick_done=1` | `tick←0` | `S_BIT` |
| `S_BIT` | `tick_done=0` | `tick←tick+1` | `S_BIT` |
| `S_BIT` | `tick_done=1 ∧ sck=0` | `sck←1; rx←{rx[22:0],miso}; n←n+1; tick←0` | `S_BIT` |
| `S_BIT` | `tick_done=1 ∧ sck=1 ∧ n<24` | `sck←0; mosi←tx_w[23−n]; tick←0` | `S_BIT` |
| `S_BIT` | `tick_done=1 ∧ sck=1 ∧ n=24` | `sck←0; cs_n←1; tick←0` | `S_END` |
| `S_END` | `tick_done=0` | `tick←tick+1` | `S_END` |
| `S_END` | `tick_done=1` | `res[ch]←rx[9:0]; ch←ch+1; tick←0` | `S_GAP` |
| `S_GAP` | `tick_done=0` | `tick←tick+1` | `S_GAP` |
| `S_GAP` | `tick_done=1 ∧ ch≠0` | `tick←0` | `S_IDLE` |
| `S_GAP` | `tick_done=1 ∧ ch=0` | `valid←1; start_req←0; tick←0` | `S_IDLE` |

## 3.4 Diagramas y Archivos Adjuntos

* Esquema detallado de bloques y diagrama de estados de la FSM: [Ver diagramas](./docs/Diagramas.md)
* Especificaciones eléctricas y de tiempos del ADC: [Ver datasheet](./docs/Datasheet_MCP3008.md)

---

### Arquitectura control/datapath (7)

Se presenta la arquitectura interna del periférico
MCP3008, identificando la unidad de control, el datapath,
los registros, los contadores, las órdenes de control
y las condiciones de decisión, de acuerdo con el código
Verilog implementado.

### Máquina de estados finitos (8)

Se presenta la FSM de cinco estados: S_IDLE, S_SETUP,
S_BIT, S_END y S_GAP, junto con su codificación binaria
y la tabla de transiciones.

[diagramas de los literales 7 y 8](./docs/Literales_7_y_8.md)

## 4. Registros

El periférico `perip_joystick.v` se integra al bus MMIO del procesador **FemtoRV32** a partir de la dirección base **`0x0043_0000`** (rango útil `0x0043_0000` a `0x0043_001C`), habilitado por la señal `cs[3]` en `chip_select.v`. Implementa **8 registros de 32 bits** alineados a palabra (offsets de 4 en 4 bytes, decodificados con `mem_addr[4:0]`). Los valores de 10 bits del ADC ocupan `bits [9:0]` y el resto se lee en `0`.

### 4.1 Mapa de registros (Base `0x0043_0000`)

| Dirección | Offset | Registro | Acceso | Descripción de bits |
| :---: | :---: | :--- | :---: | :--- |
| `0x0043_0000` | `0x00` | **`CTRL`** | R/W | `bit 0 = ENABLE` (`1`: barrido continuo de los 4 canales). `bit 1 = START` (`1`: dispara 1 barrido único y se autolimpia al terminar). |
| `0x0043_0004` | `0x04` | **`STATUS`** | R | `bit 0 = BUSY` (`1`: conversión SPI en curso). `bit 1 = VALID` (`1`: al menos 1 barrido completo listo). |
| `0x0043_0008` | `0x08` | **`J1_X`** | R | `bits [9:0]`: Lectura de 10 bits (`0..1023`) del canal `CH0` (Eje X Joystick 1). Valor tras reset: `512`. |
| `0x0043_000C` | `0x0C` | **`J1_Y`** | R | `bits [9:0]`: Lectura de 10 bits (`0..1023`) del canal `CH1` (Eje Y Joystick 1). Valor tras reset: `512`. |
| `0x0043_0010` | `0x10` | **`J2_X`** | R | `bits [9:0]`: Lectura de 10 bits (`0..1023`) del canal `CH2` (Eje X Joystick 2). Valor tras reset: `512`. |
| `0x0043_0014` | `0x14` | **`J2_Y`** | R | `bits [9:0]`: Lectura de 10 bits (`0..1023`) del canal `CH3` (Eje Y Joystick 2). Valor tras reset: `512`. |
| `0x0043_0018` | `0x18` | **`BUTTONS`** | R | `bit 0 = SW_J1`, `bit 1 = SW_J2` (lógica positiva: `1` = presionado, `0` = suelto; sincronizados e invertidos internamente desde `btn_n`). |
| `0x0043_001C` | `0x1C` | **`CLKDIV`** | R/W | `bits [7:0]`: Divisor SPI (f_tSCLK = f_clk / 2 * CLKDIV; por defecto `10` → 1.35 MHz con reloj de 27 MHz). |

### 4.2 Funcionamiento e integración con el SoC

* **Arranque seguro tras reset:** El módulo inicia apagado (`ENABLE = 0`, `VALID = 0`) con los cuatro ejes centrados en `512`. El firmware debe escribir `1` en `0x0043_0000` (`CTRL.ENABLE`) para activar el muestreo automático y esperar a que `STATUS[1]` (`VALID`) pase a `1` (76 μ para el primer barrido de los 4 canales).
* **Barrido autónomo:** La FSM realiza secuencialmente la lectura de `CH0`, `CH1`, `CH2` y `CH3` mediante tramas SPI Modo 0 de **24 pulsos** y actualiza `J1_X`, `J1_Y`, `J2_X` y `J2_Y` de forma transparente para el procesador.
* **Pulsadores sincronizados:** Las entradas físicas `joy_sw_n[1:0]` (activas en bajo) pasan por un sincronizador anti-metaestabilidad de doble flip-flop (`btn_ff1` → `btn_ff2`) y se invierten internamente antes de exponerse en `BUTTONS`.
* **Puntos clave de instanciación en `SOC.v`:** Conectar `.rst(!resetn)` (el SoC usa reset activo en bajo y `perip_joystick` activo en alto), `.addr(mem_addr[4:0])`, `.cs(cs_chip3)` y enrutar `joy_dout` a `.chip3_dout(joy_dout)` en `chip_select.v`.

> Para ver el código de integración completo en `SOC.v`, `chip_select.v`, `top.v`, `Makefile` y el ejemplo de lectura en C, consultar la guía detallada en [`./Codigo/rtl/README.md`](./Codigo/rtl/README.md).

---

## 5. Pines

El módulo expone **6 pines físicos** en `top.v` para la **Tang Nano 9K** (4 líneas SPI Modo 0 hacia el MCP3008 y 2 entradas digitales para los pulsadores `SW` de los joysticks KY-023), todos configurados en bancos de **$3.3\text{ V}$ (`LVCMOS33`)**.

| Señal (`top.v` / `.cst`) | Pin FPGA | Conector / Destino | Nota |
| :--- | :---: | :--- | :--- |
| **`mcp_cs_n`** | `PIN_CS` *(libre 3.3 V)* | MCP3008 Pin 10 (`CS/SHDN`) | Salida activa en bajo. `IO_TYPE=LVCMOS33 PULL_MODE=UP`. |
| **`mcp_sck`** | `PIN_SCK` *(libre 3.3 V)* | MCP3008 Pin 13 (`CLK`) | Salida reloj SPI Modo 0 ($1.35\text{ MHz}$ por defecto). `IO_TYPE=LVCMOS33`. |
| **`mcp_mosi`** | `PIN_MOSI` *(libre 3.3 V)* | MCP3008 Pin 11 (`DIN`) | Salida de comandos FPGA $\rightarrow$ ADC. `IO_TYPE=LVCMOS33`. |
| **`mcp_miso`** | `PIN_MISO` *(libre 3.3 V)* | MCP3008 Pin 12 (`DOUT`) | Entrada de datos ADC $\rightarrow$ FPGA. `IO_TYPE=LVCMOS33 PULL_MODE=UP`. |
| **`joy_sw_n[0]`** | `PIN_SW1` *(libre 3.3 V)* | Joystick 1 (KY-023) Pin `SW` | Entrada activa en bajo. `IO_TYPE=LVCMOS33 PULL_MODE=UP`. No negar en `top.v`. |
| **`joy_sw_n[1]`** | `PIN_SW2` *(libre 3.3 V)* | Joystick 2 (KY-023) Pin `SW` | Entrada activa en bajo. `IO_TYPE=LVCMOS33 PULL_MODE=UP`. No negar en `top.v`. |

### Restricciones físicas para el archivo `.cst`

* **Alimentación estricta a 3.3 V:** Tanto el MCP3008 (`VDD` y `VREF`) como los potenciómetros de los joysticks deben alimentarse a 3.3 V (nunca a 5 V) con tierra común (`AGND` = `DGND` = `GND`).
* **Pines a evitar:** No asignar pines reservados por `clk` (pin 52), `btn` (pines 3 y 4), `led`, `uart_tx`/`uart_rx` (pines 17 y 18), pantalla HUB75, audio ni pines de arranque/MSPI.
* **Sintaxis para `nextpnr-himbaechel`:** Escribir cada directiva `IO_LOC` e `IO_PORT` en líneas separadas (plantilla completa en [`./Codigo/rtl/README.md`](./Codigo/rtl/README.md)). Los `PIN_*` se reemplazan por los números físicos libres al integrar el `.cst` final del SoC.

---

## 6. Simulación

La verificación funcional del periférico se realizó de forma unitaria con **`Codigo/sim/tb_perip_joystick.v`** y **`Codigo/rtl/perip_joystick.v`**. El testbench genera un reloj de 27 MHz, emula las lecturas y escrituras síncronas del bus del FemtoRV32, modela conductualmente el ADC **MCP3008** (SPI Modo 0) y simula los pulsadores físicos activos en bajo.

### 6.1 Cómo ejecutar el testbench

Con el entorno **OSS CAD Suite** activado previamente en la terminal (`source /ruta/a/tu/oss-cad-suite/environment`), se puede correr la simulación desde `grupo2-joystick/` con:

```bash
iverilog -g2005 -o tb_joy.vvp Codigo/sim/tb_perip_joystick.v Codigo/rtl/perip_joystick.v
vvp -n tb_joy.vvp
gtkwave ondas_joystick.vcd &
```

*(También está documentada la regla portable `make sim-joystick` para integrarla en cualquier `Makefile` dentro de [`./Codigo/sim/README.md`](./Codigo/sim/README.md).)*

### 6.2 Qué se verificó

1. **Verificación automática en consola:** El testbench valida el barrido continuo (`ENABLE = 1`), la lectura sincronizada de los pulsadores (`BUTTONS`) y el disparo de barrido único (`START = 1` con autolimpieza), arrojando la salida:

   ```text
   OK    J1_X = 512
   OK    J1_Y = 1023
   OK    J2_X = 0
   OK    J2_Y = 291
   OK    BUTTONS = 1
   OK    J1_X tras START = 100
   OK    START se limpio solo
   PASS: perip_joystick
   ```

2. **Análisis de tiempos y protocolo SPI Modo 0 en GTKWave:**

![Simulación de arranque SPI de perip_joystick en GTKWave](./Codigo/sim/Simulacion.png)

| Parámetro / Evento | Valor medido en `Simulacion.png` | Requisito del MCP3008 ($3.3\text{ V}$) | Estado |
| :--- | :---: | :---: | :---: |
| Fin de reset (`rst` → `0`) | 200 ns (ejes inicializados en `512`) | — | Correcto |
| Activación de `enable` por bus (`CTRL`) |  462 ns | 1 ciclo de escritura | Correcto |
| Duración de `S_SETUP` (`st = 001`) | 370 ns (10 ciclos de 27 MHz) | ≥ 100 ns | Cumple |
| Tiempo real t_{SUCS} (`mcp_cs_n` ↓ a 1.er `mcp_sck` ↑) | 740ns | ≥ 100 ns | Cumple con holgura |
| Ancho en alto de `mcp_sck` (t_HI) | 370 ns (f_SCLK = 1.35 MHz) | ≥ 125 ns | Cumple |
| Trama SPI y barrido completo | 24 pulsos por canal (76 μs los 4 canales) | SPI Modo 0 | Correcto |

> Para ver la guía completa de señales recomendadas en GTKWave, configuración de `Makefile` y el análisis pulso a pulso de la captura, consultar [`./Codigo/sim/README.md`](./Codigo/sim/README.md).

