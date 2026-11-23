// i2c_control.v
// Control del maestro I2C (Grupo 1, memoria externa: EEPROM 24LC256).
//
// Enfoque A de la guia del curso: proximo estado y ordenes combinacionales
// (always @(*), =) y registros del control en el flanco de subida
// (always @(posedge clk), <=). Reset sincrono activo alto.
//
// Los nombres de las transiciones son los de la tabla de transferencias
// del I2C (docs/diagramas/6-asmd/): R, H1, T1, T1w, T1r, T1p, T2, T3, T4,
// H2, T5, H3, T6, T6r, T7.
//
// Cada estado de accion X (ST_1..ST_4, B_1..B_3, B_END, SP_1..SP_4) hace
// su accion sobre SCL o SDA y pasa a WAIT (espera n = k cuartos) o a
// SCL_WAIT (espera a que SCL sea 1, por si el esclavo estira el reloj);
// ret guarda el estado al que se vuelve.

module i2c_control (
    input  wire       clk,
    input  wire       rst,

    // Ordenes desde los registros MMIO
    input  wire       go,          // pulso de un ciclo
    input  wire       start,
    input  wire       stop,
    input  wire       write,
    input  wire       read,

    // Banderas desde el datapath
    input  wire       tick,        // fin de un cuarto de periodo de SCL
    input  wire       scl_high,    // SCL sincronizada = 1
    input  wire       bit_last,    // bcnt = 8 (bit 9, el del ACK)

    // Ordenes hacia el datapath
    output reg        tclr,        // cuarto <- 0
    output reg        scl_pull,    // SCL <- 0
    output reg        scl_rel,     // SCL <- 1 (soltar)
    output reg        sda_pull,    // SDA <- 0
    output reg        sda_rel,     // SDA <- 1 (soltar)
    output reg        sda_put,     // SDA <- sda_bit
    output reg        bclr,        // bcnt <- 0
    output reg        binc,        // bcnt <- bcnt + 1
    output reg        load_tx,     // tx <- TX_DATA
    output reg        sample,      // en B_4: T3 o T4 segun bit_last
    output wire       is_read,

    output reg        busy,
    output reg        done
);

    localparam [4:0] IDLE     = 5'd0,
                     ST_1     = 5'd1,  ST_2 = 5'd2,  ST_3 = 5'd3,  ST_4 = 5'd4,
                     B_1      = 5'd5,  B_2  = 5'd6,  B_3  = 5'd7,  B_4  = 5'd8,
                     B_END    = 5'd9,
                     SP_1     = 5'd10, SP_2 = 5'd11, SP_3 = 5'd12, SP_4 = 5'd13,
                     DONE     = 5'd14,
                     WAIT     = 5'd15,
                     SCL_WAIT = 5'd16;

    reg [4:0] state, state_next;
    reg [4:0] ret,   ret_next;
    reg [1:0] n,     n_next;
    reg       rd_q,  rd_next;

    assign is_read = rd_q;

    // T2: accion del estado X, k y siguiente segun la tabla del ASMD
    task automatic accion;
        input [4:0] siguiente;
        input [1:0] k;
        input       por_scl_wait;   // 1: E = SCL_WAIT, 0: E = WAIT
        begin
            n_next   = k;
            ret_next = siguiente;
            if (por_scl_wait)
                state_next = SCL_WAIT;
            else begin
                tclr       = 1'b1;   // cuarto <- 0 si va a WAIT
                state_next = WAIT;
            end
        end
    endtask

    always @(*) begin
        state_next = state;
        ret_next   = ret;
        n_next     = n;
        rd_next    = rd_q;

        tclr = 1'b0; scl_pull = 1'b0; scl_rel = 1'b0;
        sda_pull = 1'b0; sda_rel = 1'b0; sda_put = 1'b0;
        bclr = 1'b0; binc = 1'b0; load_tx = 1'b0; sample = 1'b0;
        done = 1'b0;

        busy = (state != IDLE);

        case (state)
            IDLE: begin
                if (go) begin
                    if (start)                                   // T1
                        state_next = ST_1;
                    else if (write) begin                        // T1w
                        bclr = 1'b1; load_tx = 1'b1; rd_next = 1'b0;
                        state_next = B_1;
                    end else if (read) begin                     // T1r
                        bclr = 1'b1; rd_next = 1'b1;
                        state_next = B_1;
                    end else                                     // T1p (STOP)
                        state_next = SP_1;
                end                                              // H1
            end

            // ---- T2: estados de accion ----
            ST_1:  begin sda_rel  = 1'b1; accion(ST_2,  2'd1, 1'b0); end
            ST_2:  begin scl_rel  = 1'b1; accion(ST_3,  2'd2, 1'b1); end
            ST_3:  begin sda_pull = 1'b1; accion(ST_4,  2'd2, 1'b0); end   // START
            ST_4:  begin scl_pull = 1'b1; accion(DONE,  2'd1, 1'b0); end
            B_1:   begin scl_pull = 1'b1; accion(B_2,   2'd1, 1'b0); end
            B_2:   begin sda_put  = 1'b1; accion(B_3,   2'd1, 1'b0); end   // SDA <- sda_bit
            B_3:   begin scl_rel  = 1'b1; accion(B_4,   2'd1, 1'b1); end
            B_END: begin scl_pull = 1'b1; accion(DONE,  2'd1, 1'b0); end
            SP_1:  begin scl_pull = 1'b1; accion(SP_2,  2'd1, 1'b0); end
            SP_2:  begin sda_pull = 1'b1; accion(SP_3,  2'd1, 1'b0); end
            SP_3:  begin scl_rel  = 1'b1; accion(SP_4,  2'd2, 1'b1); end
            SP_4:  begin sda_rel  = 1'b1; accion(DONE,  2'd2, 1'b0); end   // STOP

            B_4: begin
                sample = 1'b1;  tclr = 1'b1;  n_next = 2'd1;
                if (!bit_last) begin                             // T3
                    binc     = 1'b1;
                    ret_next = B_1;
                end else                                         // T4
                    ret_next = B_END;
                state_next = WAIT;
            end

            SCL_WAIT: begin
                if (scl_high) begin                              // T5
                    tclr       = 1'b1;
                    state_next = WAIT;
                end                                              // H2
            end

            WAIT: begin
                if (tick) begin
                    if (n == 2'd1)                               // T6r
                        state_next = ret;
                    else                                         // T6
                        n_next = n - 2'd1;
                end                                              // H3
            end

            DONE: begin                                          // T7
                done       = 1'b1;
                state_next = IDLE;
            end

            default: state_next = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin                                           // R
            state <= IDLE;
            ret   <= IDLE;
            n     <= 2'd0;
            rd_q  <= 1'b0;
        end else begin
            state <= state_next;
            ret   <= ret_next;
            n     <= n_next;
            rd_q  <= rd_next;
        end
    end

endmodule
