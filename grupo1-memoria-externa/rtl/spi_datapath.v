// spi_datapath.v
// Datapath del controlador SPI (Grupo 1, memoria externa).
//
// Recursos (docs/diagramas/7-control-datapath/):
//   - divisor que genera tick (una habilitacion de un ciclo, no un reloj)
//   - mux de carga val(fase) y n(fase)
//   - registro sh de 32 bits, MOSI = sh[31]
//   - contador bits de 6 bits y comparador last = (bits = 1)
//   - registro rx de 24 bits
//   - registros SCK y CS_n; WP_n = HOLD_n = 1
//
// Todos los registros se actualizan en el flanco de subida de clk, segun
// las ordenes que calcula spi_control.

module spi_datapath (
    input  wire        clk,
    input  wire        rst,

    // Ordenes desde el control
    input  wire        div_run,
    input  wire        load,
    input  wire [1:0]  sel,        // fase: 0 CMD, 1 DIR, 2 DAT
    input  wire        sck_rise,
    input  wire        sck_fall,
    input  wire        rx_en,
    input  wire        rx_clr,
    input  wire        cs_low,
    input  wire        cs_high,

    // Datos desde los registros MMIO
    input  wire        rw,
    input  wire [1:0]  nb,
    input  wire [7:0]  cmd,
    input  wire [23:0] addr,
    input  wire [7:0]  wdata,
    input  wire [7:0]  clk_div,

    // Banderas hacia el control
    output reg         tick,
    output wire        last,
    output wire        cs_n,

    // Dato leido hacia RDATA
    output reg  [23:0] rx,

    // Pines de la Flash
    output wire        spi_sck,
    output wire        spi_mosi,
    output wire        spi_cs_n,
    output wire        spi_wp_n,
    output wire        spi_hold_n,
    input  wire        spi_miso
);

    localparam [1:0] CMD = 2'd0,
                     DIR = 2'd1,
                     DAT = 2'd2;

    // ---------------- Divisor: tick cada (CLK_DIV + 1) ciclos ----------------
    // SCK = f_clk / (2 * (CLK_DIV + 1)), porque SCK cambia en cada tick.
    reg [7:0] div_cnt;

    always @(posedge clk) begin
        if (rst || !div_run) begin
            div_cnt <= 8'd0;
            tick    <= 1'b0;
        end else if (div_cnt == clk_div) begin
            div_cnt <= 8'd0;
            tick    <= 1'b1;
        end else begin
            div_cnt <= div_cnt + 8'd1;
            tick    <= 1'b0;
        end
    end

    // ---------------- Mux de carga: val(fase) y n(fase) ----------------
    reg [31:0] val;
    reg [5:0]  n;

    always @(*) begin
        case (sel)
            CMD:     begin val = {cmd,  24'b0}; n = 6'd8;  end
            DIR:     begin val = {addr,  8'b0}; n = 6'd24; end
            default: begin                                     // DAT
                if (rw) begin val = {wdata, 24'b0}; n = 6'd8;          end
                else    begin val = 32'b0;          n = {1'b0, nb, 3'b0}; end  // 8*NB
            end
        endcase
    end

    // ---------------- Registros sh, bits, rx, SCK, CS_n ----------------
    reg [31:0] sh;
    reg [5:0]  bits;
    reg        sck_q;
    reg        cs_n_q;

    assign last = (bits == 6'd1);

    always @(posedge clk) begin
        if (rst) begin                                   // R
            sh     <= 32'b0;
            bits   <= 6'd0;
            rx     <= 24'b0;
            sck_q  <= 1'b0;
            cs_n_q <= 1'b1;
        end else begin
            if (load) begin                              // T3
                sh   <= val;
                bits <= n;
            end
            if (sck_rise)                                // T4
                sck_q <= 1'b1;
            if (rx_en)                                   // T4, fase = DAT y RW = 0
                rx <= {rx[22:0], spi_miso};
            if (rx_clr)                                  // T1, T1c, T1n
                rx <= 24'b0;
            if (sck_fall) begin                          // T5, T6, T7
                sck_q <= 1'b0;
                if (!last) begin                         // solo T5 desplaza
                    sh   <= {sh[30:0], 1'b0};
                    bits <= bits - 6'd1;
                end
            end
            if (cs_low)                                  // T1
                cs_n_q <= 1'b0;
            if (cs_high)                                 // T10
                cs_n_q <= 1'b1;
        end
    end

    assign cs_n       = cs_n_q;
    assign spi_sck    = sck_q;
    assign spi_mosi   = sh[31];
    assign spi_cs_n   = cs_n_q;
    assign spi_wp_n   = 1'b1;
    assign spi_hold_n = 1'b1;

endmodule
