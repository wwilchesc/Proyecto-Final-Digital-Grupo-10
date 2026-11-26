// ============================================================================
// HUB75_DATAPATH - Camino de datos original del prototipo de video G4
// ============================================================================
// Ejecuta las órdenes de la FSM (load, inc, clr) y devuelve las condiciones
// de los contadores. Sus registros guardan columna, fila, plano, timer, RGB
// y la dirección A-E. No decide por sí mismo la secuencia de barrido.
//
// Dos píxeles por columna: uno en la fila row y otro en row+32. La memoria
// responde de forma síncrona; load_rgb captura el bit seleccionado de cada
// canal cuando los datos son válidos. Los seis bits quedan estables hasta
// la próxima carga. El reloj del panel lo genera hub75_control.
//
// El módulo conserva su interfaz RGB888 y sus parámetros originales.
// La instancia MMIO usa PLANES=1, PW=1 y T_BASE=1024; recibe los colores
// RGB111 expandidos a RGB888 únicamente para reutilizar esta interfaz.
// Con PLANES=1, plane siempre es 0 y plane_last se cumple desde reset.
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
    output wire              plane_last,  // plane = PLANES - 1 (0 en RGB111; 7 en RGB888)
    output wire              timer_done,  // timer = T

    // ---- salidas hacia el panel ----
    output reg               r1, g1, b1,
    output reg               r2, g2, b2,
    output reg  [RW-1:0]     addr
);

    // ------------------------------------------------------------------
    // Registros
    // ------------------------------------------------------------------
    // col: 0..63 (6 bits); row: 0..31 (5 bits); plane: plano de color;
    // timer: ciclos de iluminación transcurridos. Sus anchos son parámetros.
    reg [CW-1:0]      col;
    reg [RW-1:0]      row;
    reg [PW-1:0]      plane;
    reg [TIMER_W-1:0] timer;

    // ------------------------------------------------------------------
    // Logica combinatoria: direcciones, T y comparadores
    // ------------------------------------------------------------------
    // Concatenar {mitad,row,col} genera un índice de píxel, no un offset
    // en bytes. Para 64x64, top = row*64+col y bot = top+2048.
    // Ejemplo: row=3, col=5 -> píxeles (5,3) y (5,35).
    assign fb_addr_top = {1'b0, row, col};
    assign fb_addr_bot = {1'b1, row, col};

    // Umbral del temporizador: T = T_BASE * 2^plane. El desplazamiento
    // permite BCM con varios planos; con RGB111 (plane=0), T=T_BASE.
    // El ancho TIMER_W debe poder representar el umbral sin truncarlo.
    wire [TIMER_W-1:0] t_limit = T_BASE << plane;

    // Comparadores combinacionales: retroalimentan la FSM. No modifican
    // contadores; solo informan de si se alcanzó cada límite.
    assign col_last   = (col   == COLS      - 1);
    assign row_last   = (row   == HALF_ROWS - 1);
    assign plane_last = (plane == PLANES    - 1);
    assign timer_done = (timer == t_limit);

    // ------------------------------------------------------------------
    // Registros: se actualizan en el flanco de subida segun las ordenes.
    // Si no hay orden, el registro conserva su valor.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        // Reinicio síncrono: coordenadas y timer a cero, RGB y A-E a cero.
        if (rst) begin
            col   <= 0;
            row   <= 0;
            plane <= 0;
            timer <= 0;
            r1 <= 1'b0; g1 <= 1'b0; b1 <= 1'b0;
            r2 <= 1'b0; g2 <= 1'b0; b2 <= 1'b0;
            addr  <= 0;
        end else begin
            // Cada contador cambia solo si recibe una orden de la FSM.
            // Si coinciden clr e inc, clr tiene prioridad. Sin orden conserva
            // su valor; <= aplica todos los cambios después del flanco.
            if      (clr_col)   col   <= 0;
            else if (inc_col)   col   <= col + 1'b1;

            if      (clr_row)   row   <= 0;
            else if (inc_row)   row   <= row + 1'b1;

            if      (clr_plane) plane <= 0;
            else if (inc_plane) plane <= plane + 1'b1;

            if      (clr_timer) timer <= 0;
            else if (inc_timer) timer <= timer + 1'b1;

            // Seleccionar el bit del plano actual de cada canal RGB888.
            // R=[23:16], G=[15:8], B=[7:0]; plane desplaza el índice.
            // En RGB111 se toma siempre el bit 0 de cada canal expandido.
            // Se capturan 6 bits juntos (3 superiores y 3 inferiores).
            if (load_rgb) begin
                r1 <= pix_top[16 + plane];
                g1 <= pix_top[8  + plane];
                b1 <= pix_top[0  + plane];
                r2 <= pix_bot[16 + plane];
                g2 <= pix_bot[8  + plane];
                b2 <= pix_bot[0  + plane];
            end

            // Registrar A-E solo con load_addr. row puede avanzar antes de
            // actualizar los pines; mantenerlos estables evita seleccionar
            // otra pareja durante el envío de datos.
            if (load_addr) addr <= row;
        end
    end

endmodule
