// perip_i2c.v
// Periferico I2C completo (Grupo 1): registros MMIO + i2c_control +
// i2c_datapath. Region 0x0046_0000 del mapa del SoC. Mismo contrato de bus
// que perip_spi.v (lectura registrada, escrituras solo con BUSY = 0,
// DONE retenido hasta leer STATUS o dar una orden nueva).
//
// Mapa de registros:
//   0x00 CONTROL  (solo escritura) bit0 START, bit1 STOP, bit2 WRITE,
//                 bit3 READ, bit4 ACK_OUT (0 = ACK, 1 = NACK al leer)
//                 go = START | STOP | WRITE | READ
//                 prioridad START > WRITE > READ > STOP
//   0x04 TX_DATA  byte a enviar
//   0x08 RX_DATA  byte recibido (solo lectura)
//   0x0C STATUS   bit0 BUSY, bit1 ACK_IN (0 = el esclavo respondio), bit2 DONE
//   0x10 CLK_DIV  SCL = f_clk / (4 * (CLK_DIV + 1)); reset 124 -> 100 kHz a 50 MHz

module perip_i2c (
    input  wire        clk,
    input  wire        rst,

    input  wire        cs,
    input  wire        rd,
    input  wire        wr,
    input  wire [4:0]  addr,
    input  wire [31:0] d_in,
    output reg  [31:0] d_out,

    inout  wire        i2c_scl,
    inout  wire        i2c_sda
);

    localparam [4:0] A_CONTROL = 5'h00,
                     A_TX_DATA = 5'h04,
                     A_RX_DATA = 5'h08,
                     A_STATUS  = 5'h0C,
                     A_CLK_DIV = 5'h10;

    reg        r_start, r_stop, r_write, r_read, r_ack_out;
    reg [7:0]  r_tx_data;
    reg [7:0]  r_clk_div;
    reg        r_done;
    reg        go;

    wire       busy_core, done_core;
    wire [7:0] rx;
    wire       ack_in;

    wire busy = busy_core | go;

    wire orden      = |d_in[3:0];
    wire we_control = cs & wr & ~busy & (addr == A_CONTROL);
    wire we_tx_data = cs & wr & ~busy & (addr == A_TX_DATA);
    wire we_clk_div = cs & wr & ~busy & (addr == A_CLK_DIV);
    wire rd_status  = cs & rd & (addr == A_STATUS);

    always @(posedge clk) begin
        if (rst) begin
            r_start <= 1'b0; r_stop <= 1'b0; r_write <= 1'b0; r_read <= 1'b0;
            r_ack_out <= 1'b0;
            r_tx_data <= 8'h00;
            r_clk_div <= 8'd124;
            go        <= 1'b0;
            r_done    <= 1'b0;
        end else begin
            go <= 1'b0;
            if (we_control) begin
                r_start   <= d_in[0];
                r_stop    <= d_in[1];
                r_write   <= d_in[2];
                r_read    <= d_in[3];
                r_ack_out <= d_in[4];
                go        <= orden;
            end
            if (we_tx_data) r_tx_data <= d_in[7:0];
            if (we_clk_div) r_clk_div <= d_in[7:0];

            if (done_core)
                r_done <= 1'b1;
            else if (rd_status || (we_control && orden))
                r_done <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (rst)
            d_out <= 32'h0;
        else if (cs & rd) begin
            case (addr)
                A_TX_DATA: d_out <= {24'b0, r_tx_data};
                A_RX_DATA: d_out <= {24'b0, rx};
                A_STATUS:  d_out <= {29'b0, r_done, ack_in, busy};
                A_CLK_DIV: d_out <= {24'b0, r_clk_div};
                default:   d_out <= 32'h0;           // CONTROL es solo escritura
            endcase
        end else
            d_out <= 32'h0;
    end

    // ---------------- Pines de drenador abierto ----------------
    wire scl_oe, sda_oe;
    assign i2c_scl = scl_oe ? 1'b0 : 1'bz;
    assign i2c_sda = sda_oe ? 1'b0 : 1'bz;

    // ---------------- Control y datapath ----------------
    wire tclr, scl_pull, scl_rel, sda_pull, sda_rel, sda_put;
    wire bclr, binc, load_tx, sample, is_read;
    wire tick, scl_high, bit_last;

    i2c_control u_control (
        .clk(clk), .rst(rst),
        .go(go), .start(r_start), .stop(r_stop), .write(r_write), .read(r_read),
        .tick(tick), .scl_high(scl_high), .bit_last(bit_last),
        .tclr(tclr), .scl_pull(scl_pull), .scl_rel(scl_rel),
        .sda_pull(sda_pull), .sda_rel(sda_rel), .sda_put(sda_put),
        .bclr(bclr), .binc(binc), .load_tx(load_tx), .sample(sample),
        .is_read(is_read), .busy(busy_core), .done(done_core)
    );

    i2c_datapath u_datapath (
        .clk(clk), .rst(rst),
        .tclr(tclr), .scl_pull(scl_pull), .scl_rel(scl_rel),
        .sda_pull(sda_pull), .sda_rel(sda_rel), .sda_put(sda_put),
        .bclr(bclr), .binc(binc), .load_tx(load_tx), .sample(sample),
        .is_read(is_read),
        .tx_data(r_tx_data), .ack_out(r_ack_out), .clk_div(r_clk_div),
        .tick(tick), .scl_high(scl_high), .bit_last(bit_last),
        .rx(rx), .ack_in(ack_in),
        .scl_oe(scl_oe), .sda_oe(sda_oe),
        .scl_in(i2c_scl), .sda_in(i2c_sda)
    );

endmodule
