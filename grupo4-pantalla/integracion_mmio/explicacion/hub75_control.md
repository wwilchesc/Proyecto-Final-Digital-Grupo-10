# hub75_control — Máquina de estados del panel HUB75E

**Código:** [`rtl/hub75_control.v`](../rtl/hub75_control.v)

## 1. Propósito y estructura

La FSM coordina el barrido de la pantalla. Define diez estados (`S_READ` a `S_BLANK`) y ordena al datapath cuándo cargar RGB, incrementar o reiniciar contadores y seleccionar filas. Genera directamente `hub_clk`, `hub_lat` y `hub_oe` del núcleo.

- `always @(*)`: calcula `next_state`, las órdenes combinacionales y los valores `hub_*_next`. Los valores por defecto conservan estado y pines y desactivan órdenes, evitando latches.
- `always @(posedge clk)`: registra el estado y las salidas. Con reset, `state=S_READ`, CLK=LAT=0 y OE=1. Las órdenes al datapath se consumen en ese mismo flanco.

## 2. Señales principales

| Grupo | Señales |
|---|---|
| Entradas | `clk`, `rst`, `col_last`, `row_last`, `plane_last`, `timer_done`. |
| Órdenes al datapath | `load_rgb`, `inc_col`, `clr_col`, `inc_row`, `clr_row`, `inc_plane`, `clr_plane`, `load_addr`, `clr_timer`, `inc_timer`. |
| Salidas de control | `hub_clk`, `hub_lat`, `hub_oe`, `frame_done`. |

## 3. Estados y transferencias

Las operaciones registradas de la tabla ocurren **al salir del estado**, en el flanco positivo. Las órdenes y condiciones son combinacionales durante el estado.

| Estado | Transferencia y acción | Siguiente estado |
|---|---|---|
| `S_READ` | T1: direcciones disponibles; la memoria registra los píxeles. | S_WAIT |
| `S_WAIT` | T2: `load_rgb=1`; el datapath captura los seis bits válidos. | S_BITS |
| `S_BITS` | T3: `hub_clk_next=1`; sube CLK con los bits RGB estables. | S_CLK1 |
| `S_CLK1` | T4: `hub_clk_next=0`; baja CLK y termina el pulso. | S_CLK0 |
| `S_CLK0` | T5 si `!col_last`: `inc_col=1`. T6 si `col_last`: `hub_oe_next=1`, `hub_lat_next=1`. | S_READ o S_LAT1 |
| `S_LAT1` | T7: `hub_lat_next=0`, `clr_col=1`. | S_LAT0 |
| `S_LAT0` | T8: `load_addr=1`; se registra `addr=row`. | S_ADDR |
| `S_ADDR` | T9: `hub_oe_next=0`, `clr_timer=1`. | S_SHOW |
| `S_SHOW` | T10 si `!timer_done`: `inc_timer=1`. T11 si `timer_done`: `hub_oe_next=1`. | S_SHOW o S_BLANK |
| `S_BLANK` | T12 si `!row_last`: `inc_row`, `clr_col`; T13 si última fila pero no último plano: `inc_plane`, `clr_row`, `clr_col`; T14 si ambos son últimos: `clr_plane`, `clr_row`, `clr_col`. | S_READ |

## 4. Secuencia de barrido

Para cada columna se ejecutan los cinco primeros estados. S_READ y S_WAIT separan la lectura síncrona de memoria de la captura RGB, para no usar el dato anterior. La salida CLK sube al salir de S_BITS y baja al salir de S_CLK1. Tras 64 pulsos se captura el patrón en los registros de salida del panel mediante LAT. Después se selecciona la pareja de filas y se permite iluminarla con OE en bajo.

En S_SHOW el temporizador parte de cero y aumenta hasta `t_limit`. Incluyendo el flanco de salida, OE del núcleo permanece bajo `t_limit+1` ciclos. Con T_BASE=1024, PLANES=1 y reloj de 27 MHz, son aproximadamente 38 microsegundos por intervalo de iluminación del núcleo. El OE físico puede permanecer alto si MMIO bloquea la visualización.

S_BLANK avanza a la siguiente pareja de filas, al siguiente plano o al comienzo de otro barrido. En RGB111 solo hay un plano, de modo que `plane_last=1` desde reset y no se ejecuta T13 en el funcionamiento normal. Cada barrido tiene 32 parejas y 64 pulsos CLK por pareja, es decir, 2048 pulsos y 32 pulsos LAT.

## 5. Señal frame_done y comunicación con MMIO

```verilog
assign frame_done = (state == S_BLANK) && row_last && plane_last;
```

Es una señal combinacional de un ciclo que aparece durante el último S_BLANK. En el flanco que termina ese estado se reinician los contadores; `perip_hub75_ctrl` incrementa FRAMES y, si BUSY estaba activo, intercambia los bancos. La siguiente secuencia S_READ obtiene los nuevos píxeles. `frame_done` no depende de START ni equivale a DONE: se produce en cada barrido, exista o no una solicitud de intercambio.

## 6. Ejemplo de transición

Con `state=S_CLK0` y `col_last=1`, se prepara `hub_lat_next=1` y `next_state=S_LAT1`. En el siguiente flanco, LAT sube y el estado pasa a S_LAT1. Durante ese estado se prepara su bajada; en el flanco siguiente LAT vuelve a cero y la columna se reinicia. El pulso dura un período del reloj principal (aproximadamente 37 ns a 27 MHz).

**En síntesis:** la máquina de estados coordina todas las operaciones necesarias para enviar los datos de una pareja de filas, capturarlos, mostrarlos y avanzar. Su aviso de fin de barrido permite publicar una nueva imagen sin mezclar bancos durante el recorrido.
