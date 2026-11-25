// spi_control.v
// Control del controlador SPI (Grupo 1, memoria externa).
//
// Enfoque A de la guia del curso (uart_2.pdf): el proximo estado y las
// ordenes se calculan de forma combinacional (always @(*), asignacion =)
// y los registros del control (estado, fase, half) se actualizan en el
// flanco de subida (always @(posedge clk), asignacion <=).
//
// Cada transicion lleva el mismo nombre que en el ASMD y en la tabla de
// transferencias (docs/diagramas/6-asmd/): R, H1, H2, T1, T1c, T1n, T2 ... T12.

module spi_control (
    input  wire       clk,
    input  wire       rst,        // reset sincrono activo alto (R)

    // Ordenes desde los registros MMIO
    input  wire       start,      // pulso de un ciclo
    input  wire       rw,         // 1 = escribir en la Flash
    input  wire [1:0] nb,         // bytes a leer (0 a 3)
    input  wire       sin_dir,    // el comando no lleva direccion
    input  wire       mantener,   // dejar CS_n en 0 al terminar
    input  wire       continuar,  // seguir con los datos sin comando ni direccion

    // Banderas desde el datapath
    input  wire       tick,
    input  wire       last,       // bits = 1
    input  wire       cs_n,       // valor actual del registro CS_n

    // Ordenes hacia el datapath
    output reg        div_run,
    output reg        load,
    output wire [1:0] sel,        // sel = fase
    output reg        sck_rise,
    output reg        sck_fall,
    output reg        rx_en,
    output reg        rx_clr,
    output reg        cs_low,
    output reg        cs_high,

    // Estado hacia los registros MMIO
    output reg        busy,
    output reg        done
);

    // ---------------- Codificacion de estados (FSM de 9 estados) ----------------
    localparam [3:0] IDLE     = 4'd0,
                     CS_SETUP = 4'd1,
                     LOAD     = 4'd2,
                     LOW      = 4'd3,   // SCK = 0, espera el tick para subir
                     HIGH     = 4'd4,   // SCK = 1, espera el tick para bajar
                     FIN      = 4'd5,
                     CS_HOLD  = 4'd6,
                     CS_REST  = 4'd7,
                     DONE     = 4'd8;

    // ---------------- Codificacion de la fase ----------------
    localparam [1:0] CMD = 2'd0,
                     DIR = 2'd1,
                     DAT = 2'd2;

    // Registros del control
    reg [3:0] state, state_next;
    reg [1:0] fase,  fase_next;
    reg       half,  half_next;

    assign sel = fase;

    // Condiciones de la tabla "Definicion de fase"
    wire hay_datos  = rw | (nb != 2'd0);
    wire falta_fase = ((fase == CMD) & (~sin_dir | hay_datos)) |
                      ((fase == DIR) & hay_datos);

    // sig(fase): CMD -> DIR si SIN_DIR = 0, DAT si no; DIR -> DAT
    wire [1:0] sig_fase = (fase == CMD) ? (sin_dir ? DAT : DIR) : DAT;

    // ---------------- Calculo combinacional (=) ----------------
    always @(*) begin
        // Por defecto: mantener (H1, H2) y ninguna orden activa
        state_next = state;
        fase_next  = fase;
        half_next  = half;

        load     = 1'b0;
        sck_rise = 1'b0;
        sck_fall = 1'b0;
        rx_en    = 1'b0;
        rx_clr   = 1'b0;
        cs_low   = 1'b0;
        cs_high  = 1'b0;
        done     = 1'b0;

        // Salidas Moore
        busy    = (state != IDLE);
        div_run = (state != IDLE) && (state != DONE);

        case (state)
            IDLE: begin
                if (start) begin
                    if (!continuar || cs_n) begin            // T1
                        cs_low     = 1'b1;
                        rx_clr     = 1'b1;
                        state_next = CS_SETUP;
                    end else if (hay_datos) begin            // T1c
                        rx_clr     = 1'b1;
                        fase_next  = DAT;
                        state_next = LOAD;
                    end else begin                           // T1n
                        rx_clr     = 1'b1;
                        fase_next  = DAT;
                        state_next = FIN;
                    end
                end                                          // H1: mantener
            end

            CS_SETUP: begin
                if (tick) begin                              // T2
                    fase_next  = CMD;
                    state_next = LOAD;
                end                                          // H2: mantener
            end

            LOAD: begin                                      // T3
                load       = 1'b1;   // sh <- val(fase), bits <- n(fase)
                state_next = LOW;
            end

            LOW: begin
                if (tick) begin                              // T4
                    sck_rise   = 1'b1;
                    rx_en      = (fase == DAT) && !rw;
                    state_next = HIGH;
                end
            end

            HIGH: begin
                if (tick) begin
                    sck_fall = 1'b1;  // el datapath desplaza solo si last = 0
                    if (!last)                               // T5
                        state_next = LOW;
                    else if (falta_fase) begin               // T6
                        fase_next  = sig_fase;
                        state_next = LOAD;
                    end else                                 // T7
                        state_next = FIN;
                end
            end

            FIN: begin
                if (mantener)                                // T8m
                    state_next = DONE;
                else begin                                   // T8
                    half_next  = 1'b0;
                    state_next = CS_HOLD;
                end
            end

            CS_HOLD: begin
                if (tick) begin
                    if (!half)                               // T9
                        half_next = 1'b1;
                    else begin                               // T10
                        cs_high    = 1'b1;
                        half_next  = 1'b0;
                        state_next = CS_REST;
                    end
                end
            end

            CS_REST: begin
                if (tick) begin
                    if (!half)                               // T11
                        half_next = 1'b1;
                    else                                     // T11d
                        state_next = DONE;
                end
            end

            DONE: begin                                      // T12
                done       = 1'b1;
                state_next = IDLE;
            end

            default: state_next = IDLE;
        endcase
    end

    // ---------------- Memoria del control (<=) ----------------
    always @(posedge clk) begin
        if (rst) begin                                       // R
            state <= IDLE;
            fase  <= CMD;
            half  <= 1'b0;
        end else begin
            state <= state_next;
            fase  <= fase_next;
            half  <= half_next;
        end
    end

endmodule
