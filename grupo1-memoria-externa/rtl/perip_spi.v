// perip_spi.v
// Periferico SPI completo (Grupo 1, memoria externa): registros MMIO +
// spi_control + spi_datapath. Region 0x0042_0000 del mapa del SoC.
//
// Contrato con el bus (docs/diagramas/9-integracion/):
//   - addr[4:0] elige el registro; wr = OR(mem_wmask); rd = mem_rstrb
//   - escritura:  we_R = cs & wr & ~BUSY & (addr == R)
//   - lectura registrada: d_out se entrega un ciclo despues de cs & rd
//   - STATUS = {CS_ACTIVO, DONE, BUSY}; DONE se retiene hasta que la CPU
//     lee STATUS o da una orden nueva
//
// Mapa de registros:
//   0x00 CONTROL  bit0 START, bit1 RW, bits15:8 COMANDO, bit16 SIN_DIR,
//                 bits18:17 NB, bit19 MANTENER, bit20 CONTINUAR
//   0x04 ADDR     direccion de 24 bits
//   0x08 WDATA    byte a escribir
//   0x0C RDATA    dato leido (8 o 24 bits), solo lectura
//   0x10 STATUS   bit0 BUSY, bit1 DONE, bit2 CS_ACTIVO, solo lectura
//   0x14 CLK_DIV  SCK = f_clk / (2 * (CLK_DIV + 1)); reset 1

module perip_spi (
    input  wire        clk,
    input  wire        rst,

    // Bus (contrato comun)
    input  wire        cs,
    input  wire        rd,
    input  wire        wr,
    input  wire [4:0]  addr,
    input  wire [31:0] d_in,
    output reg  [31:0] d_out,

    // Pines de la Flash
    output wire        spi_sck,
    output wire        spi_mosi,
    output wire        spi_cs_n,
    output wire        spi_wp_n,
    output wire        spi_hold_n,
    input  wire        spi_miso
);

    localparam [4:0] A_CONTROL = 5'h00,
                     A_ADDR    = 5'h04,
                     A_WDATA   = 5'h08,
                     A_RDATA   = 5'h0C,
                     A_STATUS  = 5'h10,
                     A_CLK_DIV = 5'h14;

    // ---------------- Registros MMIO ----------------
    reg        r_rw, r_sin_dir, r_mantener, r_continuar;
    reg [7:0]  r_cmd;
    reg [1:0]  r_nb;
    reg [23:0] r_addr;
    reg [7:0]  r_wdata;
    reg [7:0]  r_clk_div;
    reg        r_done;
    reg        start;          // pulso de un ciclo hacia el control

    // Senales del core
    wire        busy_core, done_core;
    wire        cs_n_core;
    wire [23:0] rx;

    // BUSY = busy_core OR orden (la orden aceptada ya cuenta como ocupado)
    wire busy = busy_core | start;

    // Decodificador local
    wire we_control = cs & wr & ~busy & (addr == A_CONTROL);
    wire we_addr    = cs & wr & ~busy & (addr == A_ADDR);
    wire we_wdata   = cs & wr & ~busy & (addr == A_WDATA);
    wire we_clk_div = cs & wr & ~busy & (addr == A_CLK_DIV);
    wire rd_status  = cs & rd & (addr == A_STATUS);

    always @(posedge clk) begin
        if (rst) begin
            r_rw        <= 1'b0;
            r_cmd       <= 8'h00;
            r_sin_dir   <= 1'b0;
            r_nb        <= 2'd0;
            r_mantener  <= 1'b0;
            r_continuar <= 1'b0;
            r_addr      <= 24'h0;
            r_wdata     <= 8'h00;
            r_clk_div   <= 8'd1;
            start       <= 1'b0;
            r_done      <= 1'b0;
        end else begin
            start <= 1'b0;                       // START es un pulso

            if (we_control) begin
                r_rw        <= d_in[1];
                r_cmd       <= d_in[15:8];
                r_sin_dir   <= d_in[16];
                r_nb        <= d_in[18:17];
                r_mantener  <= d_in[19];
                r_continuar <= d_in[20];
                start       <= d_in[0];
            end
            if (we_addr)    r_addr    <= d_in[23:0];
            if (we_wdata)   r_wdata   <= d_in[7:0];
            if (we_clk_div) r_clk_div <= d_in[7:0];

            // DONE retenido: se pone en 1 con el pulso done del core y se
            // limpia cuando la CPU lee STATUS o da una orden nueva
            if (done_core)
                r_done <= 1'b1;
            else if (rd_status || (we_control && d_in[0]))
                r_done <= 1'b0;
        end
    end

    // ---------------- Lectura registrada ----------------
    always @(posedge clk) begin
        if (rst)
            d_out <= 32'h0;
        else if (cs & rd) begin
            case (addr)
                A_CONTROL: d_out <= {11'b0, r_continuar, r_mantener, r_nb,
                                     r_sin_dir, r_cmd, 6'b0, r_rw, 1'b0};
                A_ADDR:    d_out <= {8'b0, r_addr};
                A_WDATA:   d_out <= {24'b0, r_wdata};
                A_RDATA:   d_out <= {8'b0, rx};
                A_STATUS:  d_out <= {29'b0, ~cs_n_core, r_done, busy};
                A_CLK_DIV: d_out <= {24'b0, r_clk_div};
                default:   d_out <= 32'h0;
            endcase
        end else
            d_out <= 32'h0;
    end

    // ---------------- Control y datapath ----------------
    wire       div_run, load, sck_rise, sck_fall, rx_en, rx_clr, cs_low, cs_high;
    wire [1:0] sel;
    wire       tick, last;

    spi_control u_control (
        .clk(clk), .rst(rst),
        .start(start), .rw(r_rw), .nb(r_nb), .sin_dir(r_sin_dir),
        .mantener(r_mantener), .continuar(r_continuar),
        .tick(tick), .last(last), .cs_n(cs_n_core),
        .div_run(div_run), .load(load), .sel(sel),
        .sck_rise(sck_rise), .sck_fall(sck_fall),
        .rx_en(rx_en), .rx_clr(rx_clr), .cs_low(cs_low), .cs_high(cs_high),
        .busy(busy_core), .done(done_core)
    );

    spi_datapath u_datapath (
        .clk(clk), .rst(rst),
        .div_run(div_run), .load(load), .sel(sel),
        .sck_rise(sck_rise), .sck_fall(sck_fall),
        .rx_en(rx_en), .rx_clr(rx_clr), .cs_low(cs_low), .cs_high(cs_high),
        .rw(r_rw), .nb(r_nb), .cmd(r_cmd), .addr(r_addr), .wdata(r_wdata),
        .clk_div(r_clk_div),
        .tick(tick), .last(last), .cs_n(cs_n_core), .rx(rx),
        .spi_sck(spi_sck), .spi_mosi(spi_mosi), .spi_cs_n(spi_cs_n),
        .spi_wp_n(spi_wp_n), .spi_hold_n(spi_hold_n), .spi_miso(spi_miso)
    );

endmodule
