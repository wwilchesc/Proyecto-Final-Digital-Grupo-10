# Criterio A — Grupo 2: Joystick SPI

Documento para incorporar al README del Grupo 2. Los literales A.7 y A.8 se derivan de `perip_joystick.v`, tanto del archivo suministrado en `fragmentos.zip` como de la lógica publicada en [Codigo/rtl/perip_joystick.v](https://github.com/wwilchesc/Proyecto-Final-Digital-Grupo-10/blob/main/grupo2-joystick/Codigo/rtl/perip_joystick.v). No se propone modificar el RTL para estos diagramas.

## A.7. Arquitectura de control y datapath

El periférico se divide funcionalmente en una unidad de control y una ruta de datos. La primera determina las operaciones que deben ejecutarse y el siguiente estado; la segunda almacena los datos, genera las señales SPI, cuenta los pulsos y suministra las condiciones de decisión. El adaptador MMIO permite configurar el periférico y consultar los resultados. Los tres bloques son síncronos con `clk` (27 MHz), con reset síncrono activo en alto. La separación es funcional: el RTL original agrupa varias operaciones en un mismo bloque `always`.

```mermaid
flowchart TB
    CPU["Bus FemtoRV32: cs, rd, wr (1 bit c/u); addr (5); d_in (32)"]
    subgraph P["perip_joystick"]
      direction TB
      subgraph MMIO["Interfaz MMIO"]
        W["Decodificador de escritura"]
        CMD["enable, start_req (1 bit c/u)"]
        MUX["MUX de lectura + d_out (32 bits)"]
      end
      subgraph C["Unidad de control"]
        FSM["Lógica de estado y órdenes + st (3 bits)"]
      end
      subgraph D["Ruta de datos (datapath)"]
        direction TB
        DIV["clkdiv (8) + tick (8) + comparador"]
        N["Contador n (5) + comparador n=24"]
        CH["Contador ch (2) + comparador ch=0"]
        TX["Generador combinacional tx_w (24) + selector de bit"]
        OUT["Registros SPI: CS, SCK, MOSI (1 bit c/u)"]
        RX["Registro de desplazamiento rx (24)"]
        BANK["J1_X, J1_Y, J2_X, J2_Y (10 bits c/u)"]
        BTN["btn_ff1, btn_ff2, buttons (2 bits c/u)"]
        V["Registro valid (1)"]
        CH -->|ch 2| TX
        N -->|n 5| TX
        TX -->|bit TX 1| OUT
        RX -->|rx 9:0 — 10| BANK
        CH -->|selección 2| BANK
      end
      W --> CMD
      W -->|clkdiv 8| DIV
      CMD -->|enable, start_req 2| FSM
      FSM -->|clear_start 1| CMD
      FSM -->|div_clr, div_inc| DIV
      DIV -->|tick_done 1| FSM
      FSM -->|n_clr, n_inc| N
      N -->|n_eq24 1| FSM
      FSM -->|ch_inc| CH
      CH -->|ch_eq0 1| FSM
      FSM -->|cs_lo, cs_hi, sck_hi, sck_lo, mosi_init, upd_mosi| OUT
      OUT -->|mcp_sck 1| FSM
      FSM -->|sh_rx| RX
      FSM -->|ld_res| BANK
      FSM -->|set_valid| V
      CMD --> MUX
      DIV -->|clkdiv 8| MUX
      FSM -->|busy 1| MUX
      V -->|valid 1| MUX
      BANK -->|4 x 10| MUX
      BTN -->|buttons 2| MUX
    end
    CPU --> W
    CPU -->|cs, rd, addr| MUX
    MUX -->|d_out 32| CPU
    OUT -->|CS, SCK, MOSI| ADC[MCP3008]
    ADC -->|MISO 1| RX
    SW["Pulsadores SW activos en bajo"] -->|btn_n 2| BTN
```

**Figura A.7.** Arquitectura funcional del periférico. Todos los registros se actualizan con `clk`; `mcp_sck` es una salida registrada, no un reloj interno. Los nombres de órdenes son señales conceptuales de diseño derivadas de las asignaciones del RTL, no nuevos puertos ni cables declarados en el módulo.

### Recursos de la ruta de datos

| Recurso | Ancho (bits) | Función |
|---|---:|---|
| `clkdiv`, `tick` | 8 cada uno | Divisor programable y contador de semiperiodo. |
| `n` | 5 | Cuenta los flancos de subida de 0 a 24. |
| `ch` | 2 | Selección del canal, módulo 4. |
| `tx_w` | 24 | Palabra combinacional de transmisión; no es un registro de desplazamiento TX. |
| `rx` | 24 | Registro de desplazamiento de recepción; solo `rx[9:0]` se conserva. |
| `mcp_cs_n`, `mcp_sck`, `mcp_mosi` | 1 cada uno | Salidas registradas del maestro SPI. |
| `j1x`, `j1y`, `j2x`, `j2y` | 10 cada uno | Último resultado por canal. |
| `btn_ff1`, `btn_ff2`, `buttons` | 2 cada uno | Sincronización e inversión de los pulsadores, con salida registrada. |
| `valid` | 1 | Indicador retenido de que terminó al menos un barrido. |
| `d_out` | 32 | Registro de salida MMIO. |

Los registros `enable` y `start_req` pertenecen a la interfaz de órdenes; `st[2:0]` es el registro de estado de la unidad de control. `busy` es una señal combinacional (`st != S_IDLE`).

### Órdenes de control hacia el datapath

Cada orden tiene ancho lógico de un bit. Las órdenes agrupadas en una fila son independientes.

| Orden | Transferencia u operación | Condición de activación (sin reset) |
|---|---|---|
| `div_clr` | `tick ← 0` | `S_IDLE` o `tick_done` |
| `div_inc` | `tick ← tick + 1` | Fuera de `S_IDLE` y sin `tick_done` |
| `cs_hi` | `mcp_cs_n ← 1` | `S_END` o `S_IDLE` sin solicitud |
| `cs_lo` | `mcp_cs_n ← 0` | `S_IDLE` con solicitud |
| `n_clr`, `mosi_init` | `n ← 0`; `mcp_mosi ← tx_w[23]` | `S_IDLE` con solicitud |
| `sck_hi`, `sh_rx`, `n_inc` | `mcp_sck ← 1`; `rx ← {rx[22:0], mcp_miso}`; `n ← n+1` | `S_BIT`, `tick_done=1`, `mcp_sck=0` |
| `sck_lo` | `mcp_sck ← 0` | `S_IDLE` o `S_BIT`, `tick_done=1`, `mcp_sck=1` |
| `upd_mosi` | `mcp_mosi ← tx_w[23-n]` | `S_BIT`, `tick_done=1`, `mcp_sck=1`, `n!=24` |
| `ld_res`, `ch_inc` | Eje seleccionado ← `rx[9:0]`; `ch ← ch+1` módulo 4 | `S_END`, `tick_done=1` |
| `set_valid`, `clear_start` | `valid ← 1`; `start_req ← 0` | `S_GAP`, `tick_done=1`, `ch=0` |

### Condiciones que recibe el control

| Condición | Ancho | Expresión o fuente |
|---|---:|---|
| `enable` | 1 | CTRL[0] |
| `start_req` | 1 | CTRL[1] |
| `tick_done` | 1 | `tick == clkdiv - 1` |
| `n_eq24` | 1 | `n == 24` |
| `ch_eq0` | 1 | `ch == 0` |
| `mcp_sck` | 1 | Nivel registrado del reloj SPI |

La solicitud de inicio es `enable || start_req || !ch_eq0`. La palabra de transmisión se construye como `{8'h01, 1'b1, 1'b0, ch, 12'b0}`. Con `clkdiv=10`, SCLK vale 27 MHz / (2 × 10) = 1,35 MHz. Los botones no dependen de la FSM SPI: se actualizan en cada ciclo de `clk`.

## A.8. Máquina de estados finitos (FSM)

La FSM tiene cinco estados codificados en tres bits. Reutiliza la misma secuencia para cada canal, en lugar de duplicar máquinas de estados para los dos joysticks. La siguiente figura muestra transiciones condicionadas por el estado actual, el contador de tiempo y las condiciones del datapath. Las transferencias se ejecutan en el flanco de subida de `clk`, no en un dominio de reloj SPI independiente.

```mermaid
stateDiagram-v2
    direction LR
    state "S_IDLE / 000" as IDLE
    state "S_SETUP / 001" as SETUP
    state "S_BIT / 010" as BIT
    state "S_END / 011" as END
    state "S_GAP / 100" as GAP
    [*] --> IDLE: rst
    IDLE --> IDLE: !req
    IDLE --> SETUP: req / CS bajo, n=0, MOSI inicial
    SETUP --> SETUP: !tick_done
    SETUP --> BIT: tick_done
    BIT --> BIT: !tick_done
    BIT --> BIT: tick_done y SCK=0 / SCK=1, desplazar rx, n++
    BIT --> BIT: tick_done y SCK=1 y n!=24 / SCK=0, actualizar MOSI
    BIT --> END: tick_done y SCK=1 y n=24 / SCK=0
    END --> END: !tick_done / CS alto
    END --> GAP: tick_done / CS alto, guardar eje, ch++
    GAP --> GAP: !tick_done
    GAP --> IDLE: tick_done y ch!=0
    GAP --> IDLE: tick_done y ch=0 / VALID=1, START=0
```

**Figura A.8.** FSM única del controlador SPI. `req = enable || start_req || (ch != 0)`. El reset síncrono lleva a `S_IDLE` desde cualquier estado. Las codificaciones no usadas `101`, `110`, `111` también retornan a `S_IDLE` por la rama `default` del RTL.

### Tabla de transición y operaciones

| Estado actual | Condición | Estado siguiente | Operaciones principales |
|---|---|---|---|
| `S_IDLE` 000 | Sin solicitud | `S_IDLE` | CS=1, SCK=0 |
| `S_IDLE` 000 | Con solicitud | `S_SETUP` | CS=0, SCK=0, n=0, MOSI=tx_w[23] |
| `S_SETUP` 001 | `tick_done=0` | `S_SETUP` | Conservar señales SPI |
| `S_SETUP` 001 | `tick_done=1` | `S_BIT` | Habilitar la fase de transferencia |
| `S_BIT` 010 | `tick_done=0` | `S_BIT` | Conservar señales SPI |
| `S_BIT` 010 | `tick_done=1`, SCK=0 | `S_BIT` | SCK=1, desplazar rx, incrementar n |
| `S_BIT` 010 | `tick_done=1`, SCK=1, n!=24 | `S_BIT` | SCK=0, seleccionar MOSI siguiente |
| `S_BIT` 010 | `tick_done=1`, SCK=1, n=24 | `S_END` | SCK=0 |
| `S_END` 011 | `tick_done=0` | `S_END` | CS=1 |
| `S_END` 011 | `tick_done=1` | `S_GAP` | CS=1, almacenar rx[9:0] según ch, incrementar ch |
| `S_GAP` 100 | `tick_done=0` | `S_GAP` | Mantener la pausa |
| `S_GAP` 100 | `tick_done=1`, ch!=0 | `S_IDLE` | Conservar VALID y START |
| `S_GAP` 100 | `tick_done=1`, ch=0 | `S_IDLE` | VALID=1, START=0 |

### Interpretación y restricciones de la versión actual

- Cada conversión contiene 24 pulsos completos. Se permanece en `S_BIT` durante todos ellos; no se requieren 24 estados ni una FSM por canal. Al cerrar CH3, el contador de dos bits vuelve a cero.
- `BUSY` baja durante `S_IDLE`, incluso entre canales del mismo barrido; no representa un barrido completo en curso.
- `VALID` permanece alto después del primer barrido y solo se borra con reset. No es una bandera de nueva muestra. Los ejes se escriben individualmente, no como un conjunto atómico de cuatro valores.
- `START` se limpia al completar el barrido; una orden nueva coincidente con su limpieza puede perderse. Para un barrido único inequívoco, solicitarlo cuando `ENABLE=0` y `ch=0` en reposo.
- `CLKDIV` no tiene protección frente a escrituras durante una transferencia ni valores demasiado pequeños. Para documentar este diseño se conserva el valor por defecto 10; conviene restringir el software o corregir el RTL en una revisión futura.
- El banco de pruebas publicado reporta PASS. No se ha reproducido la simulación en esta revisión; se debe comprobar la cobertura de las transiciones con Icarus Verilog y GTKWave.

