# Guía de Integración del Periférico Joystick (`perip_joystick.v`) en el SoC (FemtoRV32)

Este documento describe paso a paso cómo integrar el periférico de joystick basado en el ADC **MCP3008** (`perip_joystick.v`) dentro de un **System-on-Chip (SoC)** existente con el procesador **FemtoRV32** en la **Tang Nano 9K**, sin interferir con otros periféricos ya presentes (UART, GPIO, multiplicador, pantalla HUB75, audio, etc.).

---

## 1. Archivos importantes para la integración

Para llevar el joystick al SoC completo necesitas únicamente **un archivo Verilog propio del periférico** y realizar modificaciones puntuales en **cinco archivos** del proyecto destino:

| Archivo | Origen | Rol en la integración |
| :--- | :--- | :--- |
| **`perip_joystick.v`** | **Copiar de este repo** | Módulo RTL autocontenido (controlador SPI Modo 0, sincronizador de botones e interfaz MMIO de 32 bits). Es el único archivo nuevo obligatorio para sintetizar. |
| **`chip_select.v`** | Proyecto destino (verificar/editar) | Decodificador de direcciones del bus. Asigna la dirección base **`0x0043_0000`** (`cs[3]`) y enruta la salida `chip3_dout` hacia `mem_rdata`. |
| **`SOC.v`** | Proyecto destino (editar) | Bus central donde se declaran los puertos del joystick, se enlaza `joy_dout` al `chip_select` y se instancia `perip_joystick`. |
| **`top.v`** | Proyecto destino (editar) | Envoltorio físico de la Tang Nano 9K que saca los 6 pines externos del joystick desde `SOC` hacia los pines de la FPGA. |
| **`top.cst`** *(o el `.cst` del SoC)* | Proyecto destino (editar) | Asigna los números de pin físicos de la Tang Nano 9K, el estándar eléctrico `$3.3\text{ V}$` (`LVCMOS33`) y las resistencias *pull-up* internas. |
| **`Makefile`** *(de síntesis)* | Proyecto destino (editar) | Debe incluir `perip_joystick.v` en la lista de archivos Verilog que compila Yosys para generar el bitstream (`.fs`). |

> **Nota sobre archivos de referencia:** Los archivos `SOC_con_joystick.v`, `top_con_joystick.v` y `chip_select.v` de este repositorio son únicamente **ejemplos de referencia** ya integrados. Si tu proyecto ya tiene otros periféricos (pantalla, audio, etc.), **no los sobrescribas**; copia únicamente los bloques de código indicados en las secciones siguientes.

---

## 2. Integración en el SoC (`SOC.v`) y asignación en el bus

En la arquitectura del SoC con FemtoRV32, cada periférico se controla mediante **entrada/salida mapeada en memoria (MMIO)**. A partir del diseño de referencia (`SOC_con_joystick.v`), al periférico del joystick se le determinó la siguiente asignación en el bus:

* **Dirección base en memoria:** `0x0043_0000` (rango útil `0x0043_0000` a `0x0043_001C`).
* **Línea de selección (*Chip Select*):** `cs[3]` (`wire cs_chip3 = cs[3];`).
* **Bus de salida hacia el procesador:** `wire [31:0] joy_dout;` conectado a la entrada `.chip3_dout(joy_dout)` de `chip_select`.

Para integrar el periférico dentro de `SOC.v`, realiza exactamente los **4 pasos** siguientes:

### Paso 2.1: Agregar los puertos físicos del joystick en `module SOC`

Añade las 4 líneas del bus SPI hacia el MCP3008 y las 2 entradas de los pulsadores SW de los módulos KY-023 al encabezado de `module SOC`:

```verilog
module SOC (
    input             clk,        // reloj de 27 MHz
    input             resetn,     // reset (activo en bajo)
    // ... tus puertos existentes (botones, LEDS, RXD, TXD, HUB75, audio, etc.) ...

    // ---- joystick MCP3008 por SPI ----
    output            mcp_cs_n,   // Chip Select hacia el MCP3008 (activo en bajo)
    output            mcp_sck,    // Reloj SPI (1.35 MHz por defecto)
    output            mcp_mosi,   // Datos FPGA -> MCP3008 (DIN)
    input             mcp_miso,   // Datos MCP3008 -> FPGA (DOUT)
    input      [1:0]  joy_sw_n    // Pulsadores SW de los joysticks (J1, J2), activos en bajo
);
```

### Paso 2.2: Declarar los cables de selección (`cs_chip3`) y salida (`joy_dout`)

En la sección de declaraciones del `chip_select` dentro de `SOC.v`, verifica que exista la señal de selección `cs_chip3` y declara el bus de 32 bits `joy_dout` por donde el joystick devolverá sus registros leídos hacia la CPU:

```verilog
  // Selección del bloque 3 (0x0043_0000) para el joystick
  wire cs_chip3 = cs[3];   // 0x0043_0000 joystick MCP3008

  // Cable de salida de datos desde perip_joystick hacia chip_select
  wire [31:0] joy_dout;
```

### Paso 2.3: Conectar `joy_dout` en la instancia de `chip_select`

En la instanciación de `chip_select` dentro de `SOC.v`, reemplaza `32'b0` en `.chip3_dout(...)` por `joy_dout`:

```verilog
  chip_select chip_select (
      .mem_addr  (mem_addr),
      .chip0_dout(uart_dout),   // 0x0040_0000 UART
      .chip1_dout(gpio_dout),   // 0x0041_0000 GPIO
      .chip2_dout(mult_dout),   // 0x0042_0000 multiplicador
      .chip3_dout(joy_dout),    // 0x0043_0000 joystick MCP3008  <-- CONECTAR AQUÍ
      .chip4_dout(32'b0),       // 0x0044_0000 libre (u otro periférico)
      .chip5_dout(32'b0),       // 0x0045_0000 libre (u otro periférico)
      .chip6_dout(RAM_rdata),   // RAM por defecto
      // ... otros chips de tu SoC (ej. chip7_dout HUB75, etc.) ...
      .cs        (cs),
      .mem_rdata (mem_rdata)
  );
```

### Paso 2.4: Instanciar `perip_joystick` en `SOC.v`

Asegúrate de que en `SOC.v` existan las señales estándar del bus `wire wr = |mem_wmask;` y `wire rd = mem_rstrb;` (ya presentes en el SoC base del FemtoRV32) e instancia el periférico:

```verilog
  //##########################################################
  //### JOYSTICK MCP3008 en 0x0043_0000                    ###
  //##########################################################
  // Los pulsadores joy_sw_n corresponden al pin SW de cada joystick KY-023
  // (activos en bajo). No reemplazan a los botones S1/S2 de la placa en GPIO.
  perip_joystick joy (
      .clk     (clk),
      .rst     (!resetn),        // IMPORTANTE: SOC usa resetn activo en bajo; el módulo usa rst activo en alto
      .d_in    (mem_wdata),      // Dato de 32 bits escrito por FemtoRV32
      .cs      (cs_chip3),       // Habilitación desde chip_select (cs[3])
      .addr    (mem_addr[4:0]),  // IMPORTANTE: conectar solo los 5 bits bajos del bus de direcciones
      .rd      (rd),             // Pulso de lectura (mem_rstrb)
      .wr      (wr),             // Pulso de escritura (|mem_wmask)
      .d_out   (joy_dout),       // Salida de 32 bits hacia chip3_dout de chip_select
      .mcp_cs_n(mcp_cs_n),       // Pines SPI hacia el exterior del SOC
      .mcp_sck (mcp_sck),
      .mcp_mosi(mcp_mosi),
      .mcp_miso(mcp_miso),
      .btn_n   (joy_sw_n)        // Botones físicos SW de los joysticks (activos en bajo)
  );
```

#### Tres puntos críticos al instanciar en `SOC.v`

1. **Polaridad del reset (`.rst(!resetn)`):** `SOC.v` trabaja con `resetn` activo en bajo, mientras que `perip_joystick.v` espera `rst` activo en alto. Si omites la negación `!`, el periférico quedará congelado en reset permanentemente.
2. **Ancho de dirección (`.addr(mem_addr[4:0])`):** El bus del procesador `mem_addr` es de $32\text{ bits}$, pero el mapa interno del joystick abarca 8 registros alineados cada 4 bytes (`0x00` a `0x1C`), por lo que el puerto `addr` es de $5\text{ bits}$. Pasa explícitamente `mem_addr[4:0]`.
3. **Separación de botones (`joy_sw_n` vs. `botones`):** `joy_sw_n[1:0]` son los pulsadores integrados en los joysticks KY-023 y se sincronizan e invierten dentro de `perip_joystick.v`. Los botones integrados en la Tang Nano 9K (`S1`/`S2`) permanecen conectados al periférico `perip_gpio`.

---

## 3. Otros archivos donde declarar variables y conexiones

Para que el sistema sintetice y funcione físicamente en la Tang Nano 9K, además de `SOC.v` debes revisar o modificar estos cuatro archivos:

### 3.1 Decodificador de direcciones (`chip_select.v`)

Verifica que tu `chip_select.v` tenga declarada la entrada `chip3_dout`, el parámetro de dirección `16'h0043` y el multiplexor correspondiente en `mem_rdata`:

```verilog
module chip_select (
    input  wire [31:0] mem_addr,
    // ...
    input  wire [31:0] chip3_dout,   // 0x0043_0000 joystick MCP3008
    // ...
    output reg  [8:0]  cs,
    output reg  [31:0] mem_rdata
);

  localparam [15:0] CHIP3ADDR = 16'h0043;
  localparam [8:0]  CHIP3CS   = 9'b000001000;

  // Decodificador sobre los 16 bits altos de la dirección
  always @(*) begin
    case (mem_addr[31:16])
      // ...
      CHIP3ADDR: cs = CHIP3CS;   // Habilita cs[3] en 0x0043_xxxx
      // ...
      default:   cs = CHIP6CS;   // RAM por defecto
    endcase
  end

  // Multiplexor de lectura hacia el procesador FemtoRV32
  always @(*) begin
    case (cs)
      // ...
      CHIP3CS: mem_rdata = chip3_dout;
      // ...
    endcase
  end
```

> **¿Qué hacer si tu proyecto ya ocupa `0x0043_0000` con otro periférico?**
> `perip_joystick.v` no tiene la dirección base fija en su código; solo depende de la señal `cs`. Si `cs[3]` ya está ocupado (por ejemplo, por audio), puedes conectarlo a cualquier bloque libre (como `cs[4]` en `0x0044_0000` o `cs[5]` en `0x0045_0000`), conectar `joy_dout` a `chip4_dout` o `chip5_dout` y actualizar la dirección base en tu firmware en C.

---

### 3.2 Envoltorio físico de la FPGA (`top.v`)

En el módulo superior `top` (el que representa los pines reales de la Tang Nano 9K) debes hacer **dos cambios**: declarar los 6 pines externos del joystick y conectarlos directamente a la instancia de `SOC`:

```verilog
module top (
    input        clk,       // 27 MHz (pin 52)
    input  [1:0] btn,       // S1 y S2 de la placa
    output [5:0] led,       // LEDs de la placa
    output       uart_tx,
    input        uart_rx,
    // ... tus otros puertos externos (HUB75, audio, etc.) ...

    // 1. DECLARAR LOS 6 PINES DEL JOYSTICK (MCP3008 + SW)
    output       mcp_cs_n,
    output       mcp_sck,
    output       mcp_mosi,
    input        mcp_miso,
    input  [1:0] joy_sw_n   // SW de J1 y J2, activos en bajo
);

    // ... lógica de reset de encendido (resetn) existente ...

    SOC soc (
        .clk     (clk),
        .resetn  (resetn),
        .botones (~btn),
        .LEDS    (leds_pos),
        .RXD     (uart_rx),
        .TXD     (uart_tx),
        // ... conexiones de tus demás periféricos ...

        // 2. CONECTAR LOS PINES DEL JOYSTICK AL SOC
        .mcp_cs_n(mcp_cs_n),
        .mcp_sck (mcp_sck),
        .mcp_mosi(mcp_mosi),
        .mcp_miso(mcp_miso),
        .joy_sw_n(joy_sw_n) // NO invertir aquí: perip_joystick.v ya sincroniza e invierte btn_n
    );

    assign led = ~leds_pos;

endmodule
```

> **Advertencia:** A diferencia de `btn` (que se niega como `.botones(~btn)`), la señal `joy_sw_n` se pasa **sin negar** (`.joy_sw_n(joy_sw_n)`), porque `perip_joystick.v` ya incluye la cadena anti-metaestabilidad (`btn_ff1` $\rightarrow$ `btn_ff2`) y la inversión interna (`buttons <= ~btn_ff2;`).

---

### 3.3 Restricciones de pines físicos (`.cst` para Tang Nano 9K)

Agrega al final de tu archivo `.cst` (por ejemplo, `top.cst`) las líneas siguientes, reemplazando `PIN_*` por los números de pin físicos libres de tu placa Tang Nano 9K:

```text
// MCP3008, SPI modo 0 (bancos de 3.3 V)
IO_LOC  "mcp_cs_n" PIN_CS;
IO_PORT "mcp_cs_n" IO_TYPE=LVCMOS33 PULL_MODE=UP;

IO_LOC  "mcp_sck"  PIN_SCK;
IO_PORT "mcp_sck"  IO_TYPE=LVCMOS33;

IO_LOC  "mcp_mosi" PIN_MOSI;
IO_PORT "mcp_mosi" IO_TYPE=LVCMOS33;

IO_LOC  "mcp_miso" PIN_MISO;
IO_PORT "mcp_miso" IO_TYPE=LVCMOS33 PULL_MODE=UP;

// Pulsadores SW de los joysticks KY-023 (activos en bajo, con pull-up interno)
IO_LOC  "joy_sw_n[0]" PIN_SW1;
IO_PORT "joy_sw_n[0]" IO_TYPE=LVCMOS33 PULL_MODE=UP;

IO_LOC  "joy_sw_n[1]" PIN_SW2;
IO_PORT "joy_sw_n[1]" IO_TYPE=LVCMOS33 PULL_MODE=UP;
```

#### Reglas importantes al elegir los pines en la Tang Nano 9K

* **Solo bancos de $3.3\text{ V}$ (`LVCMOS33`):** Tanto el MCP3008 como los potenciómetros del KY-023 deben alimentarse a $3.3\text{ V}$ (nunca a $5\text{ V}$) para no dañar las entradas de la FPGA.
* **Evitar conflictos de pines:** No selecciones pines ya usados por `clk` (pin 52), `btn` (pines 3 y 4), `led`, `uart_tx`/`uart_rx` (pines 17 y 18), tu pantalla HUB75, audio ni los pines reservados de MSPI/arranque.
* **Una sentencia por línea:** `nextpnr-himbaechel` exige que cada directiva `IO_LOC` e `IO_PORT` vaya en su propia línea separada.
* **`PULL_MODE=UP` en entradas activas en bajo y MISO:** Evita lecturas flotantes si un joystick está desconectado durante pruebas.

---

### 3.4 Archivo `Makefile` de síntesis del proyecto destino

En el `Makefile` con el que sintetizas tu SoC completo (Yosys + `nextpnr-himbaechel` + `gowin_pack`), agrega `perip_joystick.v` a la lista de fuentes Verilog del diseño (la variable suele llamarse `DESIGN`, `OBJS`, `VERILOG_SRC` o similar):

```makefile
# El módulo superior de síntesis SIEMPRE debe ser el top del SoC (nunca perip_joystick)
top = top

# Agrega la ruta de perip_joystick.v junto al resto de módulos de tu SoC
DESIGN = top.v \
         SOC.v \
         chip_select.v \
         femtorv32_quark.v \
         Memory.v \
         peripheral_uart.v \
         perip_gpio.v \
         rtl/perip_joystick.v
         # ... añade aquí tus otros periféricos (HUB75, audio, etc.) ...
```

> **Importante:** Nunca configures `top = perip_joystick` para sintetizar en la Tang Nano 9K, ya que sus buses de entrada y salida de $32\text{ bits}$ (`d_in` y `d_out`) exceden los pines físicos disponibles en la FPGA. Siempre debe sintetizarse a través de `top` $\rightarrow$ `SOC` $\rightarrow$ `perip_joystick`.

---

## 4. Mapa de registros MMIO y uso desde software (C / RISC-V)

Una vez sintetizado el SoC, el procesador **FemtoRV32** controla y lee el joystick mediante accesos directos a memoria a partir de `0x0043_0000`. El periférico arranca apagado tras el reset (`ENABLE = 0`), por lo que el firmware debe habilitarlo antes de leer los ejes.

### Mapa de registros (Base `0x0043_0000`)

| Dirección | Offset | Registro | Acceso | Descripción de bits |
| :---: | :---: | :--- | :---: | :--- |
| `0x0043_0000` | `0x00` | **`CTRL`** | R/W | `bit 0 = ENABLE` ($1$: barrido continuo). `bit 1 = START` ($1$: dispara 1 barrido y se autolimpia). |
| `0x0043_0004` | `0x04` | **`STATUS`** | R | `bit 0 = BUSY` ($1$: conversión SPI en curso). `bit 1 = VALID` ($1$: al menos 1 barrido completo listo). |
| `0x0043_0008` | `0x08` | **`J1_X`** | R | `bits [9:0]`: Lectura de $10\text{ bits}$ ($0\text{..}1023$) del canal `CH0` (Eje X Joystick 1). |
| `0x0043_000C` | `0x0C` | **`J1_Y`** | R | `bits [9:0]`: Lectura de $10\text{ bits}$ ($0\text{..}1023$) del canal `CH1` (Eje Y Joystick 1). |
| `0x0043_0010` | `0x10` | **`J2_X`** | R | `bits [9:0]`: Lectura de $10\text{ bits}$ ($0\text{..}1023$) del canal `CH2` (Eje X Joystick 2). |
| `0x0043_0014` | `0x14` | **`J2_Y`** | R | `bits [9:0]`: Lectura de $10\text{ bits}$ ($0\text{..}1023$) del canal `CH3` (Eje Y Joystick 2). |
| `0x0043_0018` | `0x18` | **`BUTTONS`** | R | `bit 0 = SW_J1`, `bit 1 = SW_J2` (lógica positiva: $1 =$ presionado, $0 =$ suelto). |
| `0x0043_001C` | `0x1C` | **`CLKDIV`** | R/W | `bits [7:0]`: Divisor SPI ($f_{\text{SCLK}} = \frac{f_{\text{clk}}}{2 \cdot \text{CLKDIV}}$; por defecto `10` $\rightarrow 1.35\text{ MHz}$ a $27\text{ MHz}$). |

### Ejemplo mínimo de lectura en C (Firmware FemtoRV32)

```c
#include <stdint.h>

#define JOY_BASE     0x00430000u
#define JOY_CTRL     (*(volatile uint32_t *)(JOY_BASE + 0x00u))
#define JOY_STATUS   (*(volatile uint32_t *)(JOY_BASE + 0x04u))
#define JOY_J1_X     (*(volatile uint32_t *)(JOY_BASE + 0x08u))
#define JOY_J1_Y     (*(volatile uint32_t *)(JOY_BASE + 0x0Cu))
#define JOY_J2_X     (*(volatile uint32_t *)(JOY_BASE + 0x10u))
#define JOY_J2_Y     (*(volatile uint32_t *)(JOY_BASE + 0x14u))
#define JOY_BUTTONS  (*(volatile uint32_t *)(JOY_BASE + 0x18u))

void joystick_init(void) {
    JOY_CTRL = 1u;                         // Activa barrido continuo (ENABLE = 1)
    while ((JOY_STATUS & 0x2u) == 0u) {}   // Espera primer barrido válido (~76 us)
}

void leer_joysticks(uint32_t *j1x, uint32_t *j1y, uint32_t *btn) {
    *j1x = JOY_J1_X & 0x3FFu;              // 0..1023 (~512 en reposo)
    *j1y = JOY_J1_Y & 0x3FFu;
    *btn = JOY_BUTTONS & 0x3u;             // bit0 = J1, bit1 = J2 (1 = presionado)
}
```

---

## 5. Lista de verificación rápida antes de sintetizar

Antes de ejecutar `make syn` en tu proyecto final, confirma cada punto:

- [ ] `perip_joystick.v` fue copiado al proyecto y añadido a la lista de fuentes del `Makefile`.
- [ ] `chip_select.v` decodifica `16'h0043` en `cs[3]` y enruta `chip3_dout` hacia `mem_rdata` (o hacia el slot libre que hayas elegido).
- [ ] `SOC.v` declara los puertos `mcp_cs_n`, `mcp_sck`, `mcp_mosi`, `mcp_miso` y `joy_sw_n[1:0]`, conecta `.chip3_dout(joy_dout)` e instancia `perip_joystick` con `.rst(!resetn)` y `.addr(mem_addr[4:0])`.
- [ ] `top.v` expone los 6 pines físicos del joystick y conecta `.joy_sw_n(joy_sw_n)` sin negación.
- [ ] El archivo `.cst` asigna pines libres de $3.3\text{ V}$ (`LVCMOS33`) con `PULL_MODE=UP` en `mcp_cs_n`, `mcp_miso` y `joy_sw_n[1:0]`, usando una sentencia por línea.
- [ ] El firmware del FemtoRV32 escribe `1` en `0x0043_0000` (`CTRL.ENABLE`) al arrancar para iniciar el muestreo automático.
