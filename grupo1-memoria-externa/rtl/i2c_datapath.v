// i2c_datapath.v
// Datapath del maestro I2C (Grupo 1).
//
// Recursos (docs/diagramas/7-control-datapath/, bloque I2C):
//   - contador de cuarto que genera tick cada (CLK_DIV + 1) ciclos
//     -> SCL = f_clk / (4 * (CLK_DIV + 1))
//   - contador bcnt (0 a 8) y comparador bit_last = (bcnt = 8)
//   - registro tx de 8 bits (desplaza), registro rx de 8 bits, registro ACK_IN
//   - selector sda_bit
//   - sincronizadores de 2 etapas para SCL y SDA
//   - salidas de drenador abierto: el pin se baja (oe = 1) o se suelta
//     (oe = 0, la resistencia de pull-up lo lleva a 1)

module i2c_datapath (
    input  wire       clk,
    input  wire       rst,

    // Ordenes desde el control
    input  wire       tclr,
    input  wire       scl_pull,
    input  wire       scl_rel,
    input  wire       sda_pull,
    input  wire       sda_rel,
    input  wire       sda_put,
    input  wire       bclr,
    input  wire       binc,
    input  wire       load_tx,
    input  wire       sample,
    input  wire       is_read,

    // Datos desde los registros MMIO
    input  wire [7:0] tx_data,
    input  wire       ack_out,
    input  wire [7:0] clk_div,

    // Banderas hacia el control
    output reg        tick,
    output wire       scl_high,
    output wire       bit_last,

    // Resultados hacia los registros MMIO
    output reg  [7:0] rx,
    output reg        ack_in,

    // Bus I2C (drenador abierto)
    output reg        scl_oe,     // 1 = baja SCL
    output reg        sda_oe,     // 1 = baja SDA
    input  wire       scl_in,
    input  wire       sda_in
);

    // ---------------- Contador de cuarto ----------------
    reg [7:0] cuarto;
    always @(posedge clk) begin
        if (rst || tclr) begin
            cuarto <= 8'd0;
            tick   <= 1'b0;
        end else if (cuarto == clk_div) begin
            cuarto <= 8'd0;
            tick   <= 1'b1;
        end else begin
            cuarto <= cuarto + 8'd1;
            tick   <= 1'b0;
        end
    end

    // ---------------- Sincronizadores ----------------
    reg [1:0] scl_s, sda_s;
    always @(posedge clk) begin
        scl_s <= {scl_s[0], scl_in};
        sda_s <= {sda_s[0], sda_in};
    end
    assign scl_high = scl_s[1];
    wire   sda_now  = sda_s[1];

    // ---------------- bcnt, tx, rx, ACK_IN ----------------
    reg [3:0] bcnt;
    reg [7:0] tx;
    assign bit_last = (bcnt == 4'd8);

    // sda_bit: WRITE: tx[7] en los bits 1 a 8 y 1 (soltar) en el bit 9
    //          READ:  1 (soltar) en los bits 1 a 8 y ACK_OUT en el bit 9
    wire sda_bit = is_read ? (bit_last ? ack_out : 1'b1)
                           : (bit_last ? 1'b1    : tx[7]);

    always @(posedge clk) begin
        if (rst) begin                                   // R
            bcnt   <= 4'd0;
            tx     <= 8'd0;
            rx     <= 8'd0;
            ack_in <= 1'b1;
            scl_oe <= 1'b0;                              // SCL y SDA sueltas
            sda_oe <= 1'b0;
        end else begin
            if (bclr)    bcnt <= 4'd0;
            if (binc)    bcnt <= bcnt + 4'd1;
            if (load_tx) tx   <= tx_data;

            if (sample) begin
                if (!bit_last) begin                     // T3
                    if (is_read) rx <= {rx[6:0], sda_now};
                    else         tx <= {tx[6:0], 1'b0};
                end else if (!is_read)                   // T4
                    ack_in <= sda_now;
            end

            if (scl_pull) scl_oe <= 1'b1;
            if (scl_rel)  scl_oe <= 1'b0;
            if (sda_pull) sda_oe <= 1'b1;
            if (sda_rel)  sda_oe <= 1'b0;
            if (sda_put)  sda_oe <= ~sda_bit;            // 0 -> bajar, 1 -> soltar
        end
    end

endmodule
