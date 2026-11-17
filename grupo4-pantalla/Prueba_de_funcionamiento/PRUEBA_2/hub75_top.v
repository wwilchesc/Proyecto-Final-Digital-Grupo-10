// hub75_top.v
// Modulo superior: conecta control, datapath y framebuffer, y expone los pines
// HUB75 del panel.
//
//   framebuffer --pix_top/pix_bot--> datapath <--ordenes/condiciones--> control
//
// Parametros por defecto: panel 64x64, escaneo 1/32, 8 bit-planes.
// COLS y HALF_ROWS deben ser potencias de 2 (la direccion es {mitad,fila,col}).
module hub75_top #(
    parameter COLS      = 64,
    parameter HALF_ROWS = 32,
    parameter PLANES    = 8,
    parameter T_BASE    = 8,
    parameter TIMER_W   = 16,
    parameter INIT_FILE = "image.hex"
) (
    input  wire       clk,       // reloj de la placa (27 MHz en la Tang Nano 9K)
    input  wire       rst,       // reset externo, activo en alto

    // ---- pines HUB75 ----
    output wire       r1, g1, b1,    // color mitad superior
    output wire       r2, g2, b2,    // color mitad inferior
    output wire [4:0] addr,          // A, B, C, D, E
    output wire       hub_clk,       // CLK
    output wire       hub_lat,       // LAT
    output wire       hub_oe         // OE
);

    // Anchos de los contadores, calculados a partir de los parametros
    localparam CW = (COLS      > 1) ? $clog2(COLS)      : 1;   // 64 -> 6 bits
    localparam RW = (HALF_ROWS > 1) ? $clog2(HALF_ROWS) : 1;   // 32 -> 5 bits
    localparam PW = (PLANES    > 1) ? $clog2(PLANES)    : 1;   //  8 -> 3 bits
    localparam AW = 1 + RW + CW;                               // 12 bits de direccion

    // ------------------------------------------------------------------
    // Reset de encendido: mantiene el circuito en reset los primeros 15
    // ciclos aunque no se toque el boton. El contador arranca en 0.
    // ------------------------------------------------------------------
    reg [3:0] por_cnt = 4'd0;
    wire      por     = ~&por_cnt;              // 1 mientras por_cnt != 15
    always @(posedge clk)
        if (por) por_cnt <= por_cnt + 4'd1;

    wire rst_i = rst | por;                     // reset interno

    // ------------------------------------------------------------------
    // Conexiones internas
    // ------------------------------------------------------------------
    wire          load_rgb, inc_col, clr_col, inc_row, clr_row;
    wire          inc_plane, clr_plane, load_addr, clr_timer, inc_timer;
    wire          col_last, row_last, plane_last, timer_done;
    wire [AW-1:0] fb_addr_top, fb_addr_bot;
    wire [23:0]   pix_top, pix_bot;
    wire [RW-1:0] addr_dp;

    assign addr = addr_dp;                      // se rellena con ceros si RW < 5

    // ------------------------------------------------------------------
    // Instancias
    // ------------------------------------------------------------------
    framebuffer #(
        .ADDR_W    (AW),
        .INIT_FILE (INIT_FILE)
    ) fb (
        .clk      (clk),
        .addr_top (fb_addr_top),
        .addr_bot (fb_addr_bot),
        .pix_top  (pix_top),
        .pix_bot  (pix_bot)
    );

    hub75_datapath #(
        .COLS      (COLS),
        .HALF_ROWS (HALF_ROWS),
        .PLANES    (PLANES),
        .T_BASE    (T_BASE),
        .TIMER_W   (TIMER_W),
        .CW        (CW),
        .RW        (RW),
        .PW        (PW)
    ) datapath (
        .clk         (clk),
        .rst         (rst_i),
        .load_rgb    (load_rgb),
        .inc_col     (inc_col),
        .clr_col     (clr_col),
        .inc_row     (inc_row),
        .clr_row     (clr_row),
        .inc_plane   (inc_plane),
        .clr_plane   (clr_plane),
        .load_addr   (load_addr),
        .clr_timer   (clr_timer),
        .inc_timer   (inc_timer),
        .fb_addr_top (fb_addr_top),
        .fb_addr_bot (fb_addr_bot),
        .pix_top     (pix_top),
        .pix_bot     (pix_bot),
        .col_last    (col_last),
        .row_last    (row_last),
        .plane_last  (plane_last),
        .timer_done  (timer_done),
        .r1 (r1), .g1 (g1), .b1 (b1),
        .r2 (r2), .g2 (g2), .b2 (b2),
        .addr        (addr_dp)
    );

    hub75_control controller (
        .clk        (clk),
        .rst        (rst_i),
        .col_last   (col_last),
        .row_last   (row_last),
        .plane_last (plane_last),
        .timer_done (timer_done),
        .load_rgb   (load_rgb),
        .inc_col    (inc_col),
        .clr_col    (clr_col),
        .inc_row    (inc_row),
        .clr_row    (clr_row),
        .inc_plane  (inc_plane),
        .clr_plane  (clr_plane),
        .load_addr  (load_addr),
        .clr_timer  (clr_timer),
        .inc_timer  (inc_timer),
        .hub_clk    (hub_clk),
        .hub_lat    (hub_lat),
        .hub_oe     (hub_oe)
    );

endmodule
