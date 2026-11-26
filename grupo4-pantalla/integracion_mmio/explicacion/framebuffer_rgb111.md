# framebuffer_rgb111 — Memoria de imagen de doble banco

**Código:** [`rtl/framebuffer_rgb111.v`](../rtl/framebuffer_rgb111.v)

## 1. Propósito

Almacena dos imágenes de 64 × 64 píxeles, con tres bits por píxel (`{R,G,B}`). El panel lee una imagen mientras el procesador escribe la otra. El cambio de banco se decide en `perip_hub75_ctrl`, al terminar un barrido.

## 2. Organización de memoria

Un cuadro contiene 4096 píxeles × 3 bits = 12 288 bits (1,5 KiB). Dos cuadros requieren 24 576 bits útiles (3 KiB). La ocupación física en BSRAM depende de la síntesis.

```verilog
(* ram_style = "block" *) reg [2:0] mem_top [0:4095];
(* ram_style = "block" *) reg [2:0] mem_bot [0:4095];
wire wr_bank = ~disp_bank;
```

Cada RAM contiene dos bancos de 2048 píxeles de una mitad de pantalla. `mem_top` corresponde a filas 0–31; `mem_bot`, a filas 32–63. La separación permite dos lecturas simultáneas y una escritura en la mitad seleccionada. El atributo `ram_style` solicita memoria de bloque, pero no garantiza su inferencia.

## 3. Direcciones y señales

| Señal | Ancho | Función |
|---|---:|---|
| `clk` | 1 | Reloj de lectura y escritura. |
| `disp_bank` | 1 | Banco visible; el opuesto recibe escrituras. |
| `addr_top`, `addr_bot` | 12 cada una | Índices de los píxeles que solicita el datapath. |
| `pix_top`, `pix_bot` | 3 cada una | Píxeles leídos de forma síncrona. |
| `we` | 1 | Autoriza escribir un píxel. |
| `waddr` | 12 | Índice del píxel que se escribe. |
| `wdata` | 3 | Valor RGB111. |

La dirección de píxel es `{mitad,row[4:0],col[5:0]}`. El bit 11 indica la mitad; los 11 bits inferiores indican el píxel dentro de esa mitad. Dentro de cada RAM, el índice es `{banco,posición[10:0]}`. El bit superior de este índice ya no indica mitad: indica banco.

## 4. Escritura y lectura síncrona

```verilog
always @(posedge clk) begin
    if (we && !waddr[11]) mem_top[{wr_bank, waddr[10:0]}] <= wdata;
    if (we &&  waddr[11]) mem_bot[{wr_bank, waddr[10:0]}] <= wdata;
    pix_top <= mem_top[{disp_bank, addr_top[10:0]}];
    pix_bot <= mem_bot[{disp_bank, addr_bot[10:0]}];
end
```

En un flanco positivo, si `we=1`, se escribe una sola RAM del banco posterior. Independientemente de la escritura, se registran dos píxeles del banco visible. Los datos de lectura están disponibles después del flanco; el estado S_WAIT permite que el datapath los capture después.

## 5. Ejemplo de direccionamiento

El píxel `(5,35)` tiene índice `35*64+5 = 2245 = 0x8C5`. `waddr[11]=1` selecciona `mem_bot`; los bits inferiores representan 197, la posición `(5,3)` dentro de la mitad inferior. Si `disp_bank=0`, `wr_bank=1`, de modo que se escribe la posición interna `2048+197=2245` de `mem_bot`.

Al invertir `disp_bank`, la lectura pasa a ese banco y la escritura al otro. No se copian píxeles. En el flanco del intercambio todavía se lee el banco anterior; S_READ permite obtener los datos del nuevo banco antes de cargar RGB.

## 6. Inicialización y límites

No hay borrado ni inicialización de RAM por reset en este módulo. La protección `FRONT_VALID` del control mantiene apagado el panel antes del primer intercambio. El software debe escribir todo el cuadro antes de START; publicar un cuadro incompleto puede mostrar datos sin inicializar o datos anteriores.

**En síntesis:** la memoria funciona como dos hojas de dibujo: el controlador muestra una mientras el software prepara la otra, y después intercambia sus funciones.
