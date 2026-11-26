# hub75_datapath — Camino de datos del barrido

**Código:** [`rtl/hub75_datapath.v`](../rtl/hub75_datapath.v)

## 1. Propósito

Ejecuta las órdenes de la FSM, conserva las coordenadas y el temporizador, genera las direcciones de lectura y prepara los seis bits RGB. No determina cuándo avanzar de estado: devuelve condiciones a `hub75_control` para que este tome las decisiones.

## 2. Registros y parámetros

| Registro | Función en la integración RGB111 |
|---|---|
| `col` | Columna 0–63; 6 bits. |
| `row` | Pareja de filas 0–31; 5 bits. |
| `plane` | Plano de bits; 1 bit de registro, permanece en cero con PLANES=1. |
| `timer` | Contador de ciclos de iluminación; TIMER_W=16 por defecto en el periférico. |
| `r1,g1,b1,r2,g2,b2` | Seis bits RGB registrados. |
| `addr` | Dirección física de fila A–E, registrada. |

Los parámetros del datapath original admiten ocho planos; `perip_hub75` lo instancia con 64 columnas, 32 parejas, un plano y `T_BASE=1024` por defecto. El testbench usa `T_BASE=8`.

## 3. Direcciones y comparadores combinacionales

```verilog
assign fb_addr_top = {1'b0, row, col};
assign fb_addr_bot = {1'b1, row, col};
assign col_last   = (col   == COLS      - 1);
assign row_last   = (row   == HALF_ROWS - 1);
assign plane_last = (plane == PLANES    - 1);
assign timer_done = (timer == t_limit);
```

Para `row=3`, `col=5`, los índices son 197 y 2245: corresponden a los píxeles `(5,3)` y `(5,35)`. Los comparadores son señales informativas, no incrementan los contadores ni almacenan valores.

El límite temporal es `t_limit = T_BASE << plane`, equivalente a T_BASE × 2^plane si cabe en TIMER_W. En RGB111 `plane=0`, por lo que `t_limit=T_BASE`.

## 4. Actualización secuencial

En `always @(posedge clk)`, `rst` reinicia los contadores y las salidas a cero. Sin reset, las órdenes de la FSM controlan las operaciones. Por ejemplo:

```verilog
if      (clr_col) col <= 0;
else if (inc_col) col <= col + 1'b1;
```

La misma estructura se usa para fila, plano y temporizador. Si se activan `clr` e `inc` simultáneamente para un contador, el reinicio tiene prioridad. Si no se activa ninguna orden, conserva el valor anterior.

## 5. Extracción de RGB y dirección de filas

Cuando `load_rgb=1`, se registran los bits del plano seleccionado de los píxeles de 24 bits:

```verilog
r1 <= pix_top[16 + plane];
g1 <= pix_top[8  + plane];
b1 <= pix_top[0  + plane];
```

Se realiza lo mismo para la mitad inferior con `pix_bot`. El módulo superior expande RGB111 a RGB888 repitiendo cada bit, de modo que con `plane=0` se recuperan los tres bits originales de cada píxel. Los seis bits permanecen estables hasta la siguiente carga.

`if (load_addr) addr <= row;` actualiza A–E únicamente cuando lo ordena la FSM. `row` identifica los datos que se están preparando; `addr` selecciona las filas físicas. Pueden diferir temporalmente durante el barrido.

## 6. Ejemplo

Si el píxel superior es rojo (`100`) y el inferior es azul (`001`), tras `load_rgb` los seis bits son `100001`. La FSM espera a que estén registrados y genera después la subida de CLK del panel para desplazarlos.

**En síntesis:** el datapath es el conjunto de registros y operaciones que prepara los datos; la FSM decide cuándo ejecutar cada operación.
