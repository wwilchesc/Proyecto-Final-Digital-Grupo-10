// hub75_datapath.v
// DATAPATH: guarda y procesa los datos. NO decide cuando hacer cada cosa;
// solo ejecuta las ordenes que le manda el control y le devuelve condiciones.
//
// Registros (las "variables" del diagrama de flujo):
//   col, row, plane, timer   -> contadores
//   r1 g1 b1 r2 g2 b2        -> bits de color que van al panel
//   addr                     -> direccion de fila A-E
module hub75_datapath #(
    parameter COLS      = 64,   // columnas del panel
    parameter HALF_ROWS = 32,   // pares de filas (escaneo 1/32)
    parameter PLANES    = 8,    // bit-planes (bits por color)
    parameter T_BASE    = 8,    // ciclos del plano 0; el plano p dura T_BASE * 2^p
    parameter TIMER_W   = 16,
    parameter CW        = 6,    // bits de col
    parameter RW        = 5,    // bits de row
    parameter PW        = 3     // bits de plane
) (
    input  wire              clk,
    input  wire              rst,        // reset sincrono, activo en alto

    // ---- ordenes del control (una por cada transferencia de la tabla) ----
    input  wire              load_rgb,   // r1..b2 <- bit[plane] de los pixeles leidos
    input  wire              inc_col,
    input  wire              clr_col,
    input  wire              inc_row,
    input  wire              clr_row,
    input  wire              inc_plane,
    input  wire              clr_plane,
    input  wire              load_addr,  // addr <- row
    input  wire              clr_timer,
    input  wire              inc_timer,

    // ---- hacia / desde el framebuffer ----
    output wire [RW+CW:0]    fb_addr_top,
    output wire [RW+CW:0]    fb_addr_bot,
    input  wire [23:0]       pix_top,
    input  wire [23:0]       pix_bot,

    // ---- condiciones hacia el control (los rombos del flujo) ----
    output wire              col_last,    // col   = COLS - 1   (63)
    output wire              row_last,    // row   = HALF_ROWS - 1 (31)
    output wire              plane_last,  // plane = PLANES - 1 (7)
    output wire              timer_done,  // timer = T

    // ---- salidas hacia el panel ----
    output reg               r1, g1, b1,
    output reg               r2, g2, b2,
    output reg  [RW-1:0]     addr
);

    // ------------------------------------------------------------------
    // Registros
    // ------------------------------------------------------------------
    reg [CW-1:0]      col;
    reg [RW-1:0]      row;
    reg [PW-1:0]      plane;
    reg [TIMER_W-1:0] timer;

    // ------------------------------------------------------------------
    // Logica combinatoria: direcciones, T y comparadores
    // ------------------------------------------------------------------
    // Direccion de memoria = {mitad, fila, columna}. Sin multiplicadores.
    assign fb_addr_top = {1'b0, row, col};
    assign fb_addr_bot = {1'b1, row, col};

    // Tiempo de encendido del plano actual: T = T_BASE * 2^plane
    wire [TIMER_W-1:0] t_limit = T_BASE << plane;

    // Comparadores: producen las condiciones de los rombos
    assign col_last   = (col   == COLS      - 1);
    assign row_last   = (row   == HALF_ROWS - 1);
    assign plane_last = (plane == PLANES    - 1);
    assign timer_done = (timer == t_limit);

    // ------------------------------------------------------------------
    // Registros: se actualizan en el flanco de subida segun las ordenes.
    // Si no hay orden, el registro conserva su valor.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            col   <= 0;
            row   <= 0;
            plane <= 0;
            timer <= 0;
            r1 <= 1'b0; g1 <= 1'b0; b1 <= 1'b0;
            r2 <= 1'b0; g2 <= 1'b0; b2 <= 1'b0;
            addr  <= 0;
        end else begin
            // Contadores (clear tiene prioridad sobre incremento)
            if      (clr_col)   col   <= 0;
            else if (inc_col)   col   <= col + 1'b1;

            if      (clr_row)   row   <= 0;
            else if (inc_row)   row   <= row + 1'b1;

            if      (clr_plane) plane <= 0;
            else if (inc_plane) plane <= plane + 1'b1;

            if      (clr_timer) timer <= 0;
            else if (inc_timer) timer <= timer + 1'b1;

            // "Sacar bits del plano": se toma el bit numero 'plane' de cada color
            // pix = {R[7:0], G[7:0], B[7:0]} -> R en [23:16], G en [15:8], B en [7:0]
            if (load_rgb) begin
                r1 <= pix_top[16 + plane];
                g1 <= pix_top[8  + plane];
                b1 <= pix_top[0  + plane];
                r2 <= pix_bot[16 + plane];
                g2 <= pix_bot[8  + plane];
                b2 <= pix_bot[0  + plane];
            end

            // Direccion de fila A-E
            if (load_addr) addr <= row;
        end
    end

endmodule
