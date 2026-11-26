// ============================================================================
// perip_joystick.v : periférico de joystick (MCP3008 por SPI) para la consola
// ----------------------------------------------------------------------------
// Propuesta de integración del Grupo 6 sobre el mapa del Grupo 2.
// Base en el bus: 0x0043_0000 (cs[3] en chip_select.v).
//
// Funcionamiento:
//   - Con ENABLE=1 el periférico recorre sin parar los canales CH0..CH3 del
//     MCP3008 y guarda cada resultado en J1_X, J1_Y, J2_X, J2_Y.
//   - Con START=1 hace un solo barrido y luego se limpia solo.
//   - El procesador nunca espera a una conversión: solo lee registros.
//
// Trama SPI (modo 0, MSB primero, 24 pulsos de SCLK):
//   byte 0 = 0000 0001     bit de inicio (cae en el pulso 8)
//   byte 1 = 1 0 D1 D0 xxxx  SGL/DIFF=1 (single-ended), canal en D1 D0
//   byte 2 = xxxx xxxx      el MCP3008 saca B9..B0 en los pulsos 15..24
//   El bit nulo sale en el pulso 14 y se descarta.
//
// Reloj SPI: 27 MHz / (2 * CLKDIV) con CLKDIV = 10 -> 1,35 MHz (límite del
// MCP3008 a 3,3 V). Los tiempos mínimos del datasheet (125 ns en alto y en
// bajo, 100 ns CS a primer flanco) quedan cubiertos con medio periodo de 370 ns.
// ============================================================================
module perip_joystick #(
    parameter CLKDIV_RESET = 8'd10
) (
    input  wire        clk,
    input  wire        rst,        // activo en alto
    input  wire [31:0] d_in,       // dato escrito por la CPU
    input  wire        cs,         // selección del bloque (cs[3])
    input  wire [4:0]  addr,       // desplazamiento del registro (cada 4 bytes)
    input  wire        rd,
    input  wire        wr,
    output reg  [31:0] d_out,      // dato leído, registrado (1 ciclo)

    // Pines hacia el MCP3008
    output reg         mcp_cs_n,
    output reg         mcp_sck,
    output reg         mcp_mosi,
    input  wire        mcp_miso,

    // Pulsadores de los joysticks, activos en bajo, sin sincronizar
    input  wire [1:0]  btn_n       // btn_n[0] = J1, btn_n[1] = J2
);

    // ------------------------------------------------------------------
    // Registros del bus
    // ------------------------------------------------------------------
    localparam [4:0] OFS_CTRL    = 5'h00;
    localparam [4:0] OFS_STATUS  = 5'h04;
    localparam [4:0] OFS_J1_X    = 5'h08;
    localparam [4:0] OFS_J1_Y    = 5'h0C;
    localparam [4:0] OFS_J2_X    = 5'h10;
    localparam [4:0] OFS_J2_Y    = 5'h14;
    localparam [4:0] OFS_BUTTONS = 5'h18;
    localparam [4:0] OFS_CLKDIV  = 5'h1C;

    reg        enable;       // CTRL bit 0
    reg        start_req;    // CTRL bit 1 (se limpia al terminar el barrido)
    reg        valid;        // STATUS bit 1
    reg  [7:0] clkdiv;
    reg  [9:0] j1x, j1y, j2x, j2y;
    reg  [1:0] buttons;      // bit0 = J1, bit1 = J2 (1 = presionado)
    reg  [1:0] btn_ff1, btn_ff2;

    // ------------------------------------------------------------------
    // Motor SPI
    // ------------------------------------------------------------------
    localparam [2:0] S_IDLE  = 3'd0,
                     S_SETUP = 3'd1,
                     S_BIT   = 3'd2,
                     S_END   = 3'd3,
                     S_GAP   = 3'd4;

    reg  [2:0]  st;
    reg  [1:0]  ch;          // canal en curso (0..3)
    reg  [7:0]  tick;        // cuenta de ciclos de reloj dentro de medio periodo
    reg  [4:0]  n;           // flancos de subida ya generados (0..24)
    reg  [23:0] rx;          // muestras de MISO (MSB primero)

    wire        tick_done = (tick == clkdiv - 8'd1);
    wire [23:0] tx_w      = {8'h01, 1'b1, 1'b0, ch, 4'b0000, 8'h00};

    wire busy = (st != S_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            enable    <= 1'b0;
            start_req <= 1'b0;
            valid     <= 1'b0;
            clkdiv    <= CLKDIV_RESET;
            j1x <= 10'd512; j1y <= 10'd512; j2x <= 10'd512; j2y <= 10'd512;
            buttons   <= 2'b00;
            btn_ff1   <= 2'b11;
            btn_ff2   <= 2'b11;
            st        <= S_IDLE;
            ch        <= 2'd0;
            tick      <= 8'd0;
            n         <= 5'd0;
            rx        <= 24'd0;
            mcp_cs_n  <= 1'b1;
            mcp_sck   <= 1'b0;
            mcp_mosi  <= 1'b0;
        end else begin
            // --------------------------------------------------------------
            // Escritura desde el bus
            // --------------------------------------------------------------
            if (cs && wr) begin
                case (addr)
                    OFS_CTRL: begin
                        enable <= d_in[0];
                        if (d_in[1]) start_req <= 1'b1;
                    end
                    OFS_CLKDIV: clkdiv <= d_in[7:0];
                    default: ;
                endcase
            end

            // Botones: dos flancos de sincronización
            btn_ff1 <= btn_n;
            btn_ff2 <= btn_ff1;
            buttons <= ~btn_ff2;

            // --------------------------------------------------------------
            // Contador de medio periodo de SCLK
            // --------------------------------------------------------------
            if (st == S_IDLE || tick_done)
                tick <= 8'd0;
            else
                tick <= tick + 8'd1;

            // --------------------------------------------------------------
            // Secuencia de conversión
            // --------------------------------------------------------------
            case (st)
                S_IDLE: begin
                    mcp_cs_n <= 1'b1;
                    mcp_sck  <= 1'b0;
                    if (enable || start_req || ch != 2'd0) begin
                        mcp_cs_n <= 1'b0;
                        n        <= 5'd0;
                        mcp_mosi <= tx_w[23];
                        st       <= S_SETUP;
                    end
                end

                // Medio periodo con CS bajo antes del primer pulso (tSUCS)
                S_SETUP: begin
                    if (tick_done) st <= S_BIT;
                end

                // 24 pulsos: subida muestrea MISO, bajada actualiza MOSI
                S_BIT: begin
                    if (tick_done) begin
                        if (!mcp_sck) begin
                            mcp_sck <= 1'b1;
                            rx      <= {rx[22:0], mcp_miso};
                            n       <= n + 5'd1;
                        end else begin
                            mcp_sck <= 1'b0;
                            if (n == 5'd24)
                                st <= S_END;
                            else
                                mcp_mosi <= tx_w[23 - n];
                        end
                    end
                end

                // CS en alto y guardar el resultado de 10 bits
                S_END: begin
                    mcp_cs_n <= 1'b1;
                    if (tick_done) begin
                        case (ch)
                            2'd0: j1x <= rx[9:0];
                            2'd1: j1y <= rx[9:0];
                            2'd2: j2x <= rx[9:0];
                            2'd3: j2y <= rx[9:0];
                        endcase
                        ch <= ch + 2'd1;
                        st <= S_GAP;
                    end
                end

                // Pausa de un medio periodo entre conversiones; al cerrar el
                // barrido (ch vuelve a 0) se marca VALID y se limpia START.
                S_GAP: begin
                    if (tick_done) begin
                        if (ch == 2'd0) begin
                            valid     <= 1'b1;
                            start_req <= 1'b0;
                        end
                        st <= S_IDLE;
                    end
                end

                default: st <= S_IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Lectura desde el bus (registrada, 1 ciclo)
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            d_out <= 32'd0;
        else if (cs && rd) begin
            case (addr)
                OFS_CTRL:    d_out <= {30'd0, start_req, enable};
                OFS_STATUS:  d_out <= {30'd0, valid, busy};
                OFS_J1_X:    d_out <= {22'd0, j1x};
                OFS_J1_Y:    d_out <= {22'd0, j1y};
                OFS_J2_X:    d_out <= {22'd0, j2x};
                OFS_J2_Y:    d_out <= {22'd0, j2y};
                OFS_BUTTONS: d_out <= {30'd0, buttons};
                OFS_CLKDIV:  d_out <= {24'd0, clkdiv};
                default:     d_out <= 32'd0;
            endcase
        end else
            d_out <= 32'd0;
    end

endmodule
