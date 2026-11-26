# perip_hub75_ctrl — Control MMIO y handshake

**Código:** [`rtl/perip_hub75_ctrl.v`](../rtl/perip_hub75_ctrl.v)

## 1. Propósito

Decodifica los registros del periférico, controla la habilitación del panel, cuenta los barridos y administra el cambio de banco del framebuffer. La FSM de barrido funciona independientemente de las solicitudes del procesador.

## 2. Entradas y salidas

| Señal | Función |
|---|---|
| `cs`, `rd`, `wr`, `addr[4:0]` | Selección local y operación MMIO. |
| `d_in[31:0]`, `d_out[31:0]` | Dato de escritura y dato leído registrado. |
| `clk`, `rst` | Reloj y reset síncrono activo en alto. |
| `frame_done` | Indica el final de un barrido de la FSM. |
| `hub_oe_core`, `hub_oe_panel` | Habilitación del núcleo y habilitación física protegida. |
| `display_en`, `busy`, `done`, `disp_bank`, `front_valid` | Configuración, estado del intercambio y selector del banco. |

## 3. Decodificador local

```verilog
wire bus_read   = cs && rd && !wr;
wire bus_write  = cs && wr && !rd;
wire wr_control = bus_write && (addr == 5'h00);
wire rd_control = bus_read  && (addr == 5'h00);
wire rd_status  = bus_read  && (addr == 5'h04);
wire rd_frames  = bus_read  && (addr == 5'h08);
```

Estas ecuaciones son combinacionales: la selección depende de las señales actuales. `rd=wr=1` no es una operación válida. Una escritura a STATUS o FRAMES no modifica los registros. El módulo superior filtra previamente los bits altos del offset.

| Offset | Registro | Bits |
|---|---|---|
| `0x00` | CONTROL (R/W) | [0] DISPLAY_EN, [1] START (orden, se lee 0). |
| `0x04` | STATUS (R) | [0] DISPLAY_EN, [1] BUSY, [2] DONE, [3] FRONT_VALID. |
| `0x08` | FRAMES (R) | Contador de 32 bits de barridos completos. |

## 4. Registros y reset

Con `rst=1`, en el flanco positivo `r_display_en=1`, `r_frames=0`, `busy=0`, `done=0`, `disp_bank=0`, `front_valid=0`. Aunque DISPLAY_EN sea 1, la salida física permanece apagada hasta que se publique el primer banco.

Una escritura válida a CONTROL actualiza `r_display_en` con `d_in[0]`, incluso cuando BUSY está activo. Cada pulso `frame_done` incrementa `r_frames`; cuenta barridos aunque no haya un nuevo cuadro ni estén encendidos los LED. El contador desborda módulo 2^32.

## 5. Handshake de intercambio

```verilog
wire start_req = wr_control && d_in[1] && !busy;
```

START es una orden, no un registro persistente. El bloque secuencial realiza estas operaciones en el flanco positivo:

| Condición antes del flanco | Efecto después del flanco |
|---|---|
| `busy && frame_done` | `disp_bank` se invierte; BUSY=0, DONE=1, FRONT_VALID=1. |
| Si no se cumple lo anterior y `start_req=1` | BUSY=1, DONE=0; el banco no cambia. |
| Ninguna condición | Se conservan los registros del intercambio. |

El software llena los 4096 píxeles cuando BUSY=0, escribe CONTROL=3 y espera DONE=1. Durante BUSY se bloquean escrituras de píxeles en el módulo superior. Un START adicional no se encola. Si llega START con BUSY=0 justo cuando `frame_done=1`, espera el siguiente límite de barrido; si BUSY ya era 1, solo se completa el intercambio anterior. DONE permanece activo hasta el próximo START aceptado o reset.

FRONT_VALID señala que ya hubo un intercambio; no verifica que todos los píxeles hayan sido escritos.

## 6. Lectura y protección de OE

El multiplexor de lectura se registra con `always @(posedge clk)`. Devuelve CONTROL, STATUS o FRAMES según `rd_*`, o cero si no hay lectura válida. Si el registro cambia en el mismo flanco de lectura, se devuelve el valor anterior al flanco.

```verilog
assign hub_oe_panel = hub_oe_core | ~r_display_en | ~front_valid | rst;
```

OE es activo en bajo. Cualquiera de las cuatro condiciones fuerza el apagado: blanking de la FSM, DISPLAY_EN=0, ausencia de un banco publicado o reset.

## 7. Ejemplo de STATUS

Con DISPLAY_EN=1, los valores esperados son `0x01` tras reset, `0x03` al aceptar el primer START y `0x0D` al completar el intercambio. Con un nuevo START y el banco ya válido, STATUS pasa a `0x0B` hasta el siguiente intercambio.

**En síntesis:** este módulo recibe órdenes del procesador, espera el momento seguro para cambiar la imagen y confirma que el cambio se realizó. No desplaza directamente los datos RGB.
