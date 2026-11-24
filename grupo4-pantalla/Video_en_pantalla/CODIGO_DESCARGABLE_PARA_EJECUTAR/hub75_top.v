// hub75_top.v
// Modulo superior: conecta control, datapath y framebuffer, y expone los pines
// HUB75 del panel.
//
//   framebuffer --pix_top/pix_bot--> datapath <--ordenes/condiciones--> control
//        ^
//        +-- we/waddr/wdata (desde img_loader) + logica de cambio de banco
//
// Parametros por defecto: panel 64x64, escaneo 1/32, 8 bit-planes.
// COLS y HALF_ROWS deben ser potencias de 2 (la direccion es {mitad,fila,col}).
//
// DOBLE BUFFER: el panel lee el banco 'disp_bank'. El cuadro nuevo se escribe
// en el otro banco; cuando esta completo (frame_end) se pide el cambio y este
// se hace justo al terminar un fotograma del panel (frame_done).
module hub75_top #(
    parameter COLS      = 64,
    parameter HALF_ROWS = 32,
    parameter PLANES    = 8,
    parameter T_BASE    = 8,
    parameter TIMER_W   = 16,
    parameter INIT_TOP  = "image_top.hex",
    parameter INIT_BOT  = "image_bot.hex"
) (
    input  wire       clk,       // reloj de la placa (27 MHz en la Tang Nano 9K)
    input  wire       rst,       // reset externo, activo en alto

    // ---- escritura de cuadros nuevos (desde img_loader; poner a 0 si no se usa) ----
    input  wire                                           we,
    input  wire [1 + $clog2(HALF_ROWS) + $clog2(COLS) - 1:0] waddr,
    input  wire [23:0]                                    wdata,
    input  wire       frame_start,   // empieza un cuadro nuevo
    input  wire       frame_end,     // el cuadro nuevo esta completo

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
    wire          col_last, row_last, plane_last, timer_done, frame_done;
    wire [AW-1:0] fb_addr_top, fb_addr_bot;
    wire [23:0]   pix_top, pix_bot;
    wire [RW-1:0] addr_dp;

    assign addr = addr_dp;                      // se rellena con ceros si RW < 5

    // ------------------------------------------------------------------
    // Doble buffer
    //   disp_bank : banco que el panel esta leyendo ahora
    //   pend      : hay un cuadro completo esperando para mostrarse
    //   show_bank : banco donde esta ese cuadro
    //   wr_bank   : banco donde se esta escribiendo el cuadro en curso
    //   latest    : banco con el cuadro mas reciente (el que se vera)
    // El cuadro nuevo siempre se escribe en el banco OPUESTO a 'latest'.
    // Los bancos no se reinician con el reset: conservan la ultima imagen.
    // ------------------------------------------------------------------
    reg  disp_bank = 1'b0;
    reg  show_bank = 1'b0;
    reg  wr_bank   = 1'b1;
    reg  pend      = 1'b0;
    wire latest    = pend ? show_bank : disp_bank;

    always @(posedge clk) begin
        if (frame_start) wr_bank <= ~latest;

        if (frame_end) begin
            show_bank <= wr_bank;
            pend      <= 1'b1;
        end else if (frame_done && pend) begin
            disp_bank <= show_bank;             // cambio de banco entre fotogramas
            pend      <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // Instancias
    // ------------------------------------------------------------------
    framebuffer #(
        .ADDR_W   (AW),
        .INIT_TOP (INIT_TOP),
        .INIT_BOT (INIT_BOT)
    ) fb (
        .clk      (clk),
        .rd_bank  (disp_bank),
        .addr_top (fb_addr_top),
        .addr_bot (fb_addr_bot),
        .pix_top  (pix_top),
        .pix_bot  (pix_bot),
        .wr_bank  (wr_bank),
        .we       (we),
        .waddr    (waddr),
        .wdata    (wdata)
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
        .hub_oe     (hub_oe),
        .frame_done (frame_done)
    );

endmodule
