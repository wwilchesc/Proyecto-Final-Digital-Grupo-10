// memoria_externa_tb.v
// Banco del bloque memoria_externa con las senales del bus del FemtoRV32
// (mem_addr, mem_wdata, mem_wmask, mem_rstrb, mem_rdata), la Flash y la
// EEPROM. Comprueba el decodificador de region, el mux de lectura y que
// ambos perifericos funcionen a traves del mismo bus.

`timescale 1ns/1ps
module memoria_externa_tb;

    reg clk = 1'b0;
    always #10 clk = ~clk;

    reg         rst = 1'b1;
    reg  [31:0] mem_addr = 32'h0, mem_wdata = 32'h0;
    reg  [3:0]  mem_wmask = 4'h0;
    reg         mem_rstrb = 1'b0;
    wire [31:0] mem_rdata;
    wire        sel;

    wire spi_sck, spi_mosi, spi_cs_n, spi_wp_n, spi_hold_n, spi_miso;
    wire i2c_scl, i2c_sda;
    pullup (i2c_scl);
    pullup (i2c_sda);

    memoria_externa dut (
        .clk(clk), .rst(rst),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wmask(mem_wmask),
        .mem_rstrb(mem_rstrb), .mem_rdata(mem_rdata), .sel(sel),
        .spi_sck(spi_sck), .spi_mosi(spi_mosi), .spi_cs_n(spi_cs_n),
        .spi_wp_n(spi_wp_n), .spi_hold_n(spi_hold_n), .spi_miso(spi_miso),
        .i2c_scl(i2c_scl), .i2c_sda(i2c_sda)
    );

    flash_model  flash  (.sck(spi_sck), .cs_n(spi_cs_n), .mosi(spi_mosi), .miso(spi_miso));
    eeprom_model eeprom (.scl(i2c_scl), .sda(i2c_sda));

    localparam SPI = 32'h0042_0000, I2C = 32'h0046_0000;

    integer errors = 0, checks = 0;
    reg [31:0] r;

    task wr32(input [31:0] a, input [31:0] d);
        begin
            @(negedge clk); mem_addr = a; mem_wdata = d; mem_wmask = 4'hF;
            @(negedge clk); mem_wmask = 4'h0; mem_addr = 32'h0;
        end
    endtask

    task rd32(input [31:0] a, output [31:0] d);
        begin
            @(negedge clk); mem_addr = a; mem_rstrb = 1;
            @(negedge clk); mem_rstrb = 0; mem_addr = 32'h0;
            d = mem_rdata;          // lectura registrada
        end
    endtask

    task check(input [639:0] name, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL  %0s: leido 0x%08h, esperado 0x%08h", name, got, exp);
            end else
                $display("ok    %0s = 0x%08h", name, got);
        end
    endtask

    task wait_idle(input [31:0] status_addr);
        reg [31:0] s;
        integer guard;
        begin
            s = 1; guard = 0;
            while (s[0] && guard < 200000) begin rd32(status_addr, s); guard = guard + 1; end
        end
    endtask

    task i2c_cmd(input [31:0] c);
        begin wr32(I2C + 32'h00, c); wait_idle(I2C + 32'h0C); end
    endtask
    task i2c_send(input [7:0] b);
        begin wr32(I2C + 32'h04, b); i2c_cmd(32'h4); end
    endtask

    initial begin
        $dumpfile("memoria_externa_tb.vcd");
        $dumpvars(0, memoria_externa_tb);
        repeat (3) @(negedge clk); rst = 0; repeat (3) @(negedge clk);

        $display("\n== Decodificador de region y mux de lectura");
        @(negedge clk); mem_addr = SPI + 32'h14;
        #1 check("sel con 0x0042_xxxx", sel, 1);
        mem_addr = I2C + 32'h10;
        #1 check("sel con 0x0046_xxxx", sel, 1);
        mem_addr = 32'h0041_0000;
        #1 check("sel con otra region (0x0041)", sel, 0);
        mem_addr = 0;
        rd32(SPI + 32'h14, r); check("CLK_DIV del SPI", r, 1);
        rd32(I2C + 32'h10, r); check("CLK_DIV del I2C", r, 124);
        rd32(32'h0041_0014, r); check("otra region lee 0", r, 0);
        wr32(32'h0041_0000, 32'h0000_9F01);   // no debe disparar nada
        repeat (5) @(negedge clk);
        check("escritura en otra region no activa el SPI", spi_cs_n, 1);

        $display("\n== Flash por el bus: JEDEC ID");
        wr32(SPI + 32'h00, 32'h0007_9F01);    // START | CMD 0x9F | SIN_DIR | NB = 3
        wait_idle(SPI + 32'h10);
        rd32(SPI + 32'h0C, r); check("RDATA del SPI", r, 32'h00EF4017);

        $display("\n== EEPROM por el bus: escribir 0xA5 en 0x0003 y leerlo");
        wr32(I2C + 32'h10, 4);                // SCL mas rapido para la simulacion
        i2c_cmd(32'h1); i2c_send(8'hA0); i2c_send(8'h00); i2c_send(8'h03); i2c_send(8'hA5);
        i2c_cmd(32'h2);
        i2c_cmd(32'h1); i2c_send(8'hA0); i2c_send(8'h00); i2c_send(8'h03);
        i2c_cmd(32'h1); i2c_send(8'hA1);
        i2c_cmd(32'h8 | 32'h10);              // READ con NACK
        i2c_cmd(32'h2);
        rd32(I2C + 32'h08, r); check("RX_DATA del I2C", r, 32'hA5);

        $display("\n== Los dos a la vez: el SPI trabaja mientras el I2C termina un byte");
        wr32(I2C + 32'h00, 32'h1);            // START del I2C
        wr32(SPI + 32'h04, 32'h000010);
        wr32(SPI + 32'h00, 32'h0002_0301);    // START | CMD 0x03 | NB = 1
        wait_idle(SPI + 32'h10);
        wait_idle(I2C + 32'h0C);
        rd32(SPI + 32'h0C, r); check("RDATA del SPI (mem[0x10])", r, {24'b0, 8'h10 ^ 8'h5A});
        i2c_cmd(32'h2);

        $display("\n%0d comprobaciones, %0d errores", checks, errors);
        if (errors == 0) $display("PASS: memoria_externa (decodificador de region, mux de lectura, SPI e I2C por el bus del Quark)");
        else             $display("FAIL: memoria_externa");
        $finish;
    end
endmodule
