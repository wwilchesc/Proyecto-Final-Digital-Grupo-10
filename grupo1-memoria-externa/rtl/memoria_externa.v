// memoria_externa.v
// Bloque del Grupo 1 para el SoC: adaptador entre el bus de memoria del
// FemtoRV32 Quark y los perifericos perip_spi (Flash) y perip_i2c (EEPROM).
// Sigue el diagrama docs/diagramas/9-integracion/Grupo1_Adaptador_de_Bus.
//
//   cs_spi = (mem_addr[31:16] == 0x0042)
//   cs_i2c = (mem_addr[31:16] == 0x0046)
//   sel    = cs_spi | cs_i2c        -> al SoC, para su mux global de lectura
//   addr = mem_addr[4:0], d_in = mem_wdata, wr = OR(mem_wmask), rd = mem_rstrb
//   mux de lectura con sel_q registrado (la respuesta llega un ciclo despues)

module memoria_externa (
    input  wire        clk,
    input  wire        rst,

    // Bus de memoria del FemtoRV32
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wmask,
    input  wire        mem_rstrb,
    output reg  [31:0] mem_rdata,
    output wire        sel,

    // Flash SPI
    output wire        spi_sck,
    output wire        spi_mosi,
    output wire        spi_cs_n,
    output wire        spi_wp_n,
    output wire        spi_hold_n,
    input  wire        spi_miso,

    // EEPROM I2C (drenador abierto, con pull-up externo)
    inout  wire        i2c_scl,
    inout  wire        i2c_sda
);

    // Decodificador de region
    wire cs_spi = (mem_addr[31:16] == 16'h0042);
    wire cs_i2c = (mem_addr[31:16] == 16'h0046);
    assign sel  = cs_spi | cs_i2c;

    // Senales del contrato
    wire [4:0] addr = mem_addr[4:0];
    wire       wr   = |mem_wmask;
    wire       rd   = mem_rstrb;

    wire [31:0] d_out_spi, d_out_i2c;

    perip_spi u_spi (
        .clk(clk), .rst(rst),
        .cs(cs_spi), .rd(rd), .wr(wr), .addr(addr), .d_in(mem_wdata), .d_out(d_out_spi),
        .spi_sck(spi_sck), .spi_mosi(spi_mosi), .spi_cs_n(spi_cs_n),
        .spi_wp_n(spi_wp_n), .spi_hold_n(spi_hold_n), .spi_miso(spi_miso)
    );

    perip_i2c u_i2c (
        .clk(clk), .rst(rst),
        .cs(cs_i2c), .rd(rd), .wr(wr), .addr(addr), .d_in(mem_wdata), .d_out(d_out_i2c),
        .i2c_scl(i2c_scl), .i2c_sda(i2c_sda)
    );

    // Mux de lectura: sel_q = {cs_i2c & rd, cs_spi & rd}, registrado
    reg [1:0] sel_q;
    always @(posedge clk) begin
        if (rst) sel_q <= 2'b00;
        else     sel_q <= {cs_i2c & rd, cs_spi & rd};
    end

    always @(*) begin
        case (sel_q)
            2'b01:   mem_rdata = d_out_spi;
            2'b10:   mem_rdata = d_out_i2c;
            default: mem_rdata = 32'h0;
        endcase
    end

endmodule
