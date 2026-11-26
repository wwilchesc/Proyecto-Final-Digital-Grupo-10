// ============================================================================
// Módulo: i2s_tx_core.v
// Descripción: Transmisor Philips I2S 16-bit Mono (Control + Datapath + BCLK)
// Reloj: 27 MHz | BCLK: 1.35 MHz (div 20) | Fs: 42.1875 kHz (32 BCLK)
// ============================================================================

module i2s_tx_core (
    input  wire        clk,       // 27 MHz
    input  wire        rst,       // Síncrono activo alto
    input  wire        tx_start,  // Pulso inicio de trama
    input  wire [15:0] data_in,   // Muestra PCM 16-bit mono
    output wire        tx_busy,   // 1 durante transmisión
    output wire        tx_done,   // Pulso 1 ciclo al terminar trama
    output wire        bclk,      // 1.35 MHz -> GPIO 35
    output wire        lrck,      // 42.1875 kHz -> GPIO 36
    output wire        sdin       // Datos serie -> GPIO 37
);

    // Señales internas de interconexión Control <-> Datapath
    wire       bclk_tick;
    wire       load_data;
    wire [1:0] cnt_op;
    wire [1:0] sdin_sel;
    wire [1:0] lrck_op;
    wire       last_bit;
    wire       toggle_lrck;

    // 1. Generador de BCLK (27 MHz / 20 = 1.35 MHz) y bclk_tick
    i2s_clock_gen u_clk_gen (
        .clk       (clk),
        .rst       (rst),
        .bclk      (bclk),
        .bclk_tick (bclk_tick)
    );

    // 2. Unidad de Control (FSM de 5 estados)
    i2s_controller u_controller (
        .clk         (clk),
        .rst         (rst),
        .bclk_tick   (bclk_tick),
        .tx_start    (tx_start),
        .last_bit    (last_bit),
        .toggle_lrck (toggle_lrck),
        .load_data   (load_data),
        .cnt_op      (cnt_op),
        .sdin_sel    (sdin_sel),
        .lrck_op     (lrck_op),
        .tx_busy     (tx_busy),
        .tx_done     (tx_done)
    );

    // 3. Ruta de Datos (Datapath)
    i2s_datapath u_datapath (
        .clk         (clk),
        .rst         (rst),
        .data_in     (data_in),
        .load_data   (load_data),
        .cnt_op      (cnt_op),
        .sdin_sel    (sdin_sel),
        .lrck_op     (lrck_op),
        .last_bit    (last_bit),
        .toggle_lrck (toggle_lrck),
        .sdin        (sdin),
        .lrck        (lrck)
    );

endmodule

// ----------------------------------------------------------------------------
// Generador de Reloj BCLK (Módulo 20: 0..19) y pulso bclk_tick en flanco bajada
// ----------------------------------------------------------------------------
module i2s_clock_gen (
    input  wire clk,
    input  wire rst,
    output reg  bclk,
    output wire bclk_tick
);
    reg [4:0] div_cnt;

    always @(posedge clk) begin
        if (rst) begin
            div_cnt <= 5'd0;
            bclk    <= 1'b0;
        end else begin
            if (div_cnt == 5'd19) begin
                div_cnt <= 5'd0;
                bclk    <= 1'b0; // Flanco de bajada de BCLK
            end else begin
                div_cnt <= div_cnt + 5'd1;
                if (div_cnt == 5'd9)
                    bclk <= 1'b1; // Flanco de subida (50% duty cycle)
            end
        end
    end

    // Pulso de 1 ciclo de CLK justo cuando BCLK cae (div_cnt == 19)
    assign bclk_tick = (div_cnt == 5'd19);

endmodule

// ----------------------------------------------------------------------------
// CONTROLLER: Máquina de Estados Finitos (FSM) y Lógica de Órdenes
// ----------------------------------------------------------------------------
module i2s_controller (
    input  wire       clk,
    input  wire       rst,
    input  wire       bclk_tick,
    input  wire       tx_start,
    input  wire       last_bit,     // i == 0
    input  wire       toggle_lrck,  // i == 1
    output reg        load_data,    // Carga D <- data_in
    output reg  [1:0] cnt_op,       // 00: hold, 01: load 15, 10: load 14, 11: dec
    output reg  [1:0] sdin_sel,     // 00: hold, 01: 0, 10: D[15], 11: D[i-1]
    output reg  [1:0] lrck_op,      // 00: hold, 01: LRCK<-0, 10: LRCK<-1
    output wire       tx_busy,
    output reg        tx_done
);

    // Codificación de los 5 estados
    localparam [2:0] IDLE        = 3'd0,
                     WAIT_TICK   = 3'd1,
                     DELAY_1BCLK = 3'd2,
                     LEFT_DATA   = 3'd3,
                     RIGHT_PAD   = 3'd4;

    // Operaciones del Datapath
    localparam [1:0] CNT_HOLD   = 2'b00,
                     CNT_LOAD15 = 2'b01,
                     CNT_LOAD14 = 2'b10,
                     CNT_DEC    = 2'b11;

    localparam [1:0] SDIN_HOLD  = 2'b00,
                     SDIN_ZERO  = 2'b01,
                     SDIN_D15   = 2'b10,
                     SDIN_PREV  = 2'b11;

    localparam [1:0] LRCK_HOLD  = 2'b00,
                     LRCK_LOW   = 2'b01,
                     LRCK_HIGH  = 2'b10;

    reg [2:0] state, next_state;
    reg       done_next;

    // Registro de estado y salida registrada tx_done
    always @(posedge clk) begin
        if (rst) begin
            state   <= IDLE;
            tx_done <= 1'b0;
        end else begin
            state   <= next_state;
            tx_done <= done_next;
        end
    end

    // tx_busy es 0 únicamente en IDLE
    assign tx_busy = (state != IDLE);

    // Lógica combinacional de próximo estado y órdenes al Datapath
    always @(*) begin
        next_state = state;
        load_data  = 1'b0;
        cnt_op     = CNT_HOLD;
        sdin_sel   = SDIN_HOLD;
        lrck_op    = LRCK_HOLD;
        done_next  = 1'b0;

        case (state)
            IDLE: begin
                if (tx_start) begin
                    // Transición T1: Captura muestra y pasa a WAIT_TICK
                    load_data  = 1'b1;
                    next_state = WAIT_TICK;
                end
            end

            WAIT_TICK: begin
                if (bclk_tick) begin
                    // Transición T2: Baja LRCK e inicia retardo de 1 BCLK
                    lrck_op    = LRCK_LOW;
                    sdin_sel   = SDIN_ZERO;
                    next_state = DELAY_1BCLK;
                end
            end

            DELAY_1BCLK: begin
                if (bclk_tick) begin
                    // Transición T3: Carga índice 15 y saca MSB D[15]
                    cnt_op     = CNT_LOAD15;
                    sdin_sel   = SDIN_D15;
                    next_state = LEFT_DATA;
                end
            end

            LEFT_DATA: begin
                if (bclk_tick) begin
                    if (last_bit) begin
                        // Transición T6 (i == 0): Inicia 15 ciclos de relleno derecho
                        cnt_op     = CNT_LOAD14;
                        sdin_sel   = SDIN_ZERO;
                        next_state = RIGHT_PAD;
                    end else if (toggle_lrck) begin
                        // Transición T5 (i == 1): Saca D[0] y sube LRCK 1 BCLK antes
                        cnt_op     = CNT_DEC;
                        sdin_sel   = SDIN_PREV;
                        lrck_op    = LRCK_HIGH;
                        next_state = LEFT_DATA;
                    end else begin
                        // Transición T4 (i > 1): Decrementa i y saca D[i-1]
                        cnt_op     = CNT_DEC;
                        sdin_sel   = SDIN_PREV;
                        next_state = LEFT_DATA;
                    end
                end
            end

            RIGHT_PAD: begin
                if (bclk_tick) begin
                    if (last_bit) begin
                        // Transición T8 (i == 0): Fin de trama (32 BCLK exactos)
                        done_next = 1'b1;
                        if (tx_start) begin
                            // Encadena inmediatamente la siguiente trama sin ciclo extra
                            load_data  = 1'b1;
                            lrck_op    = LRCK_LOW;
                            sdin_sel   = SDIN_ZERO;
                            next_state = DELAY_1BCLK;
                        end else begin
                            next_state = IDLE;
                        end
                    end else begin
                        // Transición T7 (i > 0): Decrementa relleno en 0
                        cnt_op     = CNT_DEC;
                        sdin_sel   = SDIN_ZERO;
                        next_state = RIGHT_PAD;
                    end
                end
            end 

            default: next_state = IDLE;
        endcase
    end

endmodule

// ----------------------------------------------------------------------------
// DATAPATH: Registro D, Contador i, Comparadores, Mux 16:1 y FFs de salida
// ----------------------------------------------------------------------------
module i2s_datapath (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] data_in,
    input  wire        load_data,
    input  wire [1:0]  cnt_op,
    input  wire [1:0]  sdin_sel,
    input  wire [1:0]  lrck_op,
    output wire        last_bit,
    output wire        toggle_lrck,
    output reg         sdin,
    output reg         lrck
);

    reg [15:0] reg_d;
    reg [3:0]  cnt_i;

    // Comparadores de estado del índice
    assign last_bit    = (cnt_i == 4'd0);
    assign toggle_lrck = (cnt_i == 4'd1);

    // Multiplexor 16:1 indexado en (i - 1) para transiciones T4 y T5
    wire [3:0] prev_idx = cnt_i - 4'd1;
    wire       mux_d_prev = reg_d[prev_idx];

    // Registro D (retención de muestra mono de 16 bits)
    always @(posedge clk) begin
        if (rst)
            reg_d <= 16'd0;
        else if (load_data)
            reg_d <= data_in;
    end

    // Contador descendente i de 4 bits (15..0 izq / 14..0 der)
    always @(posedge clk) begin
        if (rst) begin
            cnt_i <= 4'd0;
        end else begin
            case (cnt_op)
                2'b01:   cnt_i <= 4'd15;        // load 15
                2'b10:   cnt_i <= 4'd14;        // load 14
                2'b11:   cnt_i <= cnt_i - 4'd1; // decrementar
                default: cnt_i <= cnt_i;        // mantener
            endcase
        end
    end

    // Flip-Flop de salida SDIN con multiplexor de selección
    always @(posedge clk) begin
        if (rst) begin
            sdin <= 1'b0;
        end else begin
            case (sdin_sel)
                2'b01:   sdin <= 1'b0;       // Cero (retardo / relleno)
                2'b10:   sdin <= reg_d[15];  // MSB D[15]
                2'b11:   sdin <= mux_d_prev; // D[i-1]
                default: sdin <= sdin;       // Mantener
            endcase
        end
    end

    // Flip-Flop de salida LRCK (Reset = 1 según tabla fila R)
    always @(posedge clk) begin
        if (rst) begin
            lrck <= 1'b1;
        end else begin
            case (lrck_op)
                2'b01:   lrck <= 1'b0;
                2'b10:   lrck <= 1'b1;
                default: lrck <= lrck;
            endcase
        end
    end

endmodule
