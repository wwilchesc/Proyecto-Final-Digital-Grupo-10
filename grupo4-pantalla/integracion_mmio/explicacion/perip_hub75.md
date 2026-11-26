# perip_hub75 — Interfaz superior del periférico

**Código:** [`rtl/perip_hub75.v`](../rtl/perip_hub75.v)

## 1. Propósito

Es el módulo que se conecta al SoC. Reúne los otros cuatro módulos y adapta las operaciones del bus a las señales internas. El procesador escribe los colores y solicita su publicación; la FPGA genera CLK, LAT, OE y A–E sin intervención del software durante el barrido.

## 2. Interfaz

| Señal | Ancho | Función |
|---|---:|---|
| `clk`, `rst` | 1 cada una | Reloj común y reset activo en alto. |
| `cs_fb`, `cs_ctrl` | 1 cada una | Selección de las regiones 0x0048 y 0x004C, realizada fuera del módulo. |
| `rd`, `wr` | 1 cada una | Solicitud de lectura o escritura de un ciclo, excluyentes. |
| `addr` | 16 | Desplazamiento en bytes dentro de la región. |
| `d_in`, `d_out` | 32 cada una | Dato de escritura y respuesta registrada de control. |
| `r1,g1,b1,r2,g2,b2` | 6 en total | Bits de color de dos píxeles. |
| `hub_addr` | 5 | Selección física de filas A–E. |
| `hub_clk`, `hub_lat`, `hub_oe` | 1 cada una | Desplazamiento, captura y habilitación activa en bajo. |

## 3. Decodificación de accesos

El decodificador global del SoC identifica la región de memoria. Este módulo valida el offset antes de entregar la solicitud a los bloques internos.

```verilog
wire sel_ctrl = cs_ctrl && !cs_fb && (addr[15:5] == 11'd0);
wire we = !rst && cs_fb && !cs_ctrl && wr && !rd && !busy &&
          (addr[15:14] == 2'b00) && (addr[1:0] == 2'b00);
```

- `sel_ctrl` exige que solo esté seleccionada la región de control y que el offset esté entre 0 y 31 bytes. Evita que `0x004C0020` se confunda con `CONTROL`, ya que ambos tienen los mismos cinco bits inferiores.
- `we` exige una escritura válida, sin reset ni intercambio pendiente. `[15:14] = 0` restringe el framebuffer a 16 KiB de espacio de direcciones; `[1:0] = 0` exige alineación de palabra.
- El control recibe `addr[4:0]`; el framebuffer recibe `addr[13:2]` como índice de píxel y `d_in[2:0]` como RGB111.

El SoC debe filtrar las escrituras parciales: este módulo no recibe `mem_wmask`. Las lecturas del framebuffer no están implementadas.

## 4. Instancias y comunicación

| Instancia | Módulo | Función |
|---|---|---|
| `ctrl_mmio` | `perip_hub75_ctrl` | Registra configuración y estado, decide el banco visible y devuelve `d_out`. |
| `fb` | `framebuffer_rgb111` | Escribe el banco posterior y lee dos píxeles del visible. |
| `datapath` | `hub75_datapath` | Genera direcciones, contadores y RGB. |
| `controller` | `hub75_control` | Coordina el barrido y genera `frame_done`, CLK, LAT y OE del núcleo. |

`frame_done` y `hub_oe_core` viajan desde la FSM al control MMIO. `disp_bank` viaja desde el control MMIO hacia la memoria. FSM y datapath se comunican mediante órdenes y comparadores. `hub_oe` físico procede del control MMIO, no directamente de la FSM.

## 5. Adaptación de RGB111

La memoria devuelve tres bits por píxel, pero el datapath original recibe 24. Cada bit se replica ocho veces dentro de su canal:

```verilog
wire [23:0] pix_top_rgb888 = {{8{pix_top[2]}}, {8{pix_top[1]}}, {8{pix_top[0]}}};
```

Por ejemplo, `3'b101` se convierte en `24'hFF00FF` (magenta). La instancia utiliza `PLANES=1`, por lo que solo toma el bit cero de cada canal. Esta adaptación conserva la interfaz original sin aumentar la cantidad de colores.

## 6. Ejemplo de escritura

Para escribir verde (`3'b010`) en el píxel `(5,3)`, el índice es `3*64+5 = 197`. La dirección es `0x00480000 + 4*197 = 0x00480314`. Si `cs_fb=1`, `cs_ctrl=0`, `wr=1`, `rd=0`, `rst=0` y `busy=0`, el adaptador activa `we` y el dato se almacena en el banco posterior en el próximo flanco positivo.

**En síntesis:** este módulo es el punto de conexión entre el bus y el controlador de pantalla. Filtra solicitudes, conecta los bloques y adapta los datos; no contiene la secuencia de estados del barrido.
