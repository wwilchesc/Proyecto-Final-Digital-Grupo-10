// hub75_control.v
// CONTROL: maquina de estados (FSM). Decide QUE operacion se hace y CUANDO.
// Cada estado dura exactamente un ciclo de reloj (salvo SHOW, que espera).
//
// Estructura (como en la guia de la UART):
//   - always @(*)       : calcula next_state, las ordenes y los proximos valores
//                         de las salidas (logica combinatoria, asignacion con =)
//   - always @(posedge) : guarda state y las salidas hacia el panel (con <=)
//
// Correspondencia estado <-> cajas del diagrama de flujo:
//   S_READ   leer pix_top y pix_bot
//   S_WAIT   esperar 1 ciclo (latencia de la memoria)
//   S_BITS   sacar bits del plano
//   S_CLK1   CLK_P = 1
//   S_CLK0   CLK_P = 0   + rombo "col = 63?"
//   S_LAT1   Oe = 1, lat = 1
//   S_LAT0   lat = 0, col = 0
//   S_ADDR   addr = row
//   S_SHOW   Oe = 0, timer = 0  + rombo "timer = T?"
//   S_BLANK  Oe = 1             + rombos "row = 31?" y "plane = 7?"
module hub75_control (
    input  wire clk,
    input  wire rst,            // reset sincrono, activo en alto

    // ---- condiciones desde el datapath (resultado de los rombos) ----
    input  wire col_last,
    input  wire row_last,
    input  wire plane_last,
    input  wire timer_done,

    // ---- ordenes hacia el datapath ----
    output reg  load_rgb,
    output reg  inc_col,
    output reg  clr_col,
    output reg  inc_row,
    output reg  clr_row,
    output reg  inc_plane,
    output reg  clr_plane,
    output reg  load_addr,
    output reg  clr_timer,
    output reg  inc_timer,

    // ---- senales de control del panel (registradas) ----
    output reg  hub_clk,        // CLK_P
    output reg  hub_lat,        // lat
    output reg  hub_oe,         // Oe: 1 = LEDs apagados, 0 = LEDs encendidos

    // ---- aviso para el doble buffer ----
    // Pulso de 1 ciclo en el ultimo estado de un fotograma (T14). El estado
    // siguiente ya empieza el fotograma nuevo, asi que es el momento limpio
    // para cambiar de banco de memoria.
    output wire frame_done
);

    // ------------------------------------------------------------------
    // Estados
    // ------------------------------------------------------------------
    localparam [3:0] S_READ  = 4'd0,
                     S_WAIT  = 4'd1,
                     S_BITS  = 4'd2,
                     S_CLK1  = 4'd3,
                     S_CLK0  = 4'd4,
                     S_LAT1  = 4'd5,
                     S_LAT0  = 4'd6,
                     S_ADDR  = 4'd7,
                     S_SHOW  = 4'd8,
                     S_BLANK = 4'd9;

    reg [3:0] state;
    reg [3:0] next_state;

    assign frame_done = (state == S_BLANK) && row_last && plane_last;

    // Proximos valores de las salidas registradas
    reg hub_clk_next;
    reg hub_lat_next;
    reg hub_oe_next;

    // ------------------------------------------------------------------
    // Parte combinatoria: tabla de transferencias T1 a T14
    // Primero valores por defecto; el case solo sustituye lo que cambia.
    // ------------------------------------------------------------------
    always @(*) begin
        // Por defecto: conservar estado y salidas, ninguna orden activa
        next_state   = state;
        hub_clk_next = hub_clk;
        hub_lat_next = hub_lat;
        hub_oe_next  = hub_oe;
        load_rgb  = 1'b0;
        inc_col   = 1'b0;
        clr_col   = 1'b0;
        inc_row   = 1'b0;
        clr_row   = 1'b0;
        inc_plane = 1'b0;
        clr_plane = 1'b0;
        load_addr = 1'b0;
        clr_timer = 1'b0;
        inc_timer = 1'b0;

        case (state)
            // T1: la memoria recibe la direccion (row, col)
            S_READ: begin
                next_state = S_WAIT;
            end

            // T2: la memoria ya entrego el pixel; se sacan los bits del plano
            S_WAIT: begin
                load_rgb   = 1'b1;
                next_state = S_BITS;
            end

            // T3: datos RGB estables -> sube CLK_P
            S_BITS: begin
                hub_clk_next = 1'b1;
                next_state   = S_CLK1;
            end

            // T4: baja CLK_P (pulso de un ciclo)
            S_CLK1: begin
                hub_clk_next = 1'b0;
                next_state   = S_CLK0;
            end

            // Rombo "col = 63?"  (se evalua con el valor ANTES del flanco)
            S_CLK0: begin
                if (col_last) begin
                    // T6: fila completa -> apagar LEDs y activar lat
                    hub_oe_next  = 1'b1;
                    hub_lat_next = 1'b1;
                    next_state   = S_LAT1;
                end else begin
                    // T5: siguiente pixel
                    inc_col    = 1'b1;
                    next_state = S_READ;
                end
            end

            // T7: fin del pulso lat y col vuelve a 0
            S_LAT1: begin
                hub_lat_next = 1'b0;
                clr_col      = 1'b1;
                next_state   = S_LAT0;
            end

            // T8: poner la direccion de fila (con los LEDs apagados)
            S_LAT0: begin
                load_addr  = 1'b1;
                next_state = S_ADDR;
            end

            // T9: encender LEDs y empezar a contar el tiempo
            S_ADDR: begin
                hub_oe_next = 1'b0;
                clr_timer   = 1'b1;
                next_state  = S_SHOW;
            end

            // Rombo "timer = T?"
            S_SHOW: begin
                if (timer_done) begin
                    // T11: se cumplio el tiempo -> apagar LEDs
                    hub_oe_next = 1'b1;
                    next_state  = S_BLANK;
                end else begin
                    // T10: seguir esperando
                    inc_timer = 1'b1;
                end
            end

            // Rombos "row = 31?" y "plane = 7?" (no suman ciclos)
            S_BLANK: begin
                next_state = S_READ;
                if (!row_last) begin
                    // T12: siguiente fila
                    inc_row = 1'b1;
                    clr_col = 1'b1;
                end else if (!plane_last) begin
                    // T13: siguiente plano
                    inc_plane = 1'b1;
                    clr_row   = 1'b1;
                    clr_col   = 1'b1;
                end else begin
                    // T14: fotograma completo, volver a empezar
                    clr_plane = 1'b1;
                    clr_row   = 1'b1;
                    clr_col   = 1'b1;
                end
            end

            default: next_state = S_READ;
        endcase
    end

    // ------------------------------------------------------------------
    // Parte secuencial: guarda state y las salidas hacia el panel
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state   <= S_READ;
            hub_clk <= 1'b0;
            hub_lat <= 1'b0;
            hub_oe  <= 1'b1;     // LEDs apagados al arrancar
        end else begin
            state   <= next_state;
            hub_clk <= hub_clk_next;
            hub_lat <= hub_lat_next;
            hub_oe  <= hub_oe_next;
        end
    end

endmodule
