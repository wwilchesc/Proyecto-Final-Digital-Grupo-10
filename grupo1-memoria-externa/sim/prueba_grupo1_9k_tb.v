// prueba_grupo1_9k_tb.v
// Banco de la prueba en placa (fpga/prueba_grupo1_9k.v) con los modelos de la
// Flash y de la EEPROM. Los tiempos de espera se acortan y la UART va mas
// rapido para que la simulacion termine pronto; el resto es igual a la placa.
// El banco decodifica la UART e imprime el reporte tal como saldria en la
// terminal, y comprueba los LEDs y el contenido de las dos memorias.

`timescale 1ns/1ps
module prueba_grupo1_9k_tb;

    localparam CLK_HZ = 27_000_000;
    localparam BAUD   = 2_700_000;          // en la placa: 115200
    localparam DIV    = CLK_HZ / BAUD;

    reg clk = 1'b0;
    always #18.518 clk = ~clk;              // 27 MHz

    reg btn_rst_n = 1'b0, btn_run_n = 1'b1;
    wire uart_tx;
    wire [1:0] led;
    wire spi_sck, spi_mosi, spi_cs_n, spi_wp_n, spi_hold_n, spi_miso;
    wire i2c_scl, i2c_sda;
    pullup (i2c_scl);
    pullup (i2c_sda);

    prueba_grupo1_9k #(
        .CLK_HZ(CLK_HZ), .BAUD(BAUD),
        .T_INICIO(100), .T_BORRAR(200), .T_GRABAR(200), .T_EEPROM(200)
    ) dut (
        .clk(clk), .btn_rst_n(btn_rst_n), .btn_run_n(btn_run_n),
        .uart_tx(uart_tx), .led(led),
        .spi_sck(spi_sck), .spi_mosi(spi_mosi), .spi_cs_n(spi_cs_n),
        .spi_miso(spi_miso),
        .i2c_scl(i2c_scl), .i2c_sda(i2c_sda)
    );

    flash_model  flash  (.sck(spi_sck), .cs_n(spi_cs_n), .mosi(spi_mosi), .miso(spi_miso));
    eeprom_model eeprom (.scl(i2c_scl), .sda(i2c_sda));

    // ---------------- Receptor UART: imprime el reporte ----------------
    integer k, nfalla = 0;
    reg [7:0] rx;
    reg [8*5-1:0] ult5 = 0;                 // ultimos 5 caracteres recibidos
    always begin
        @(negedge uart_tx);
        repeat (DIV / 2) @(posedge clk);     // mitad del bit de inicio
        for (k = 0; k < 8; k = k + 1) begin
            repeat (DIV) @(posedge clk);
            rx[k] = uart_tx;
        end
        repeat (DIV) @(posedge clk);         // bit de parada
        if (rx != 8'h0D) $write("%c", rx);
        ult5 = {ult5[31:0], rx};
        if (ult5 == "FALLA") nfalla = nfalla + 1;
    end

    // ---------------- Comprobaciones ----------------
    integer checks = 0, errors = 0;
    task check(input [639:0] name, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL  %0s = 0x%08h (esperado 0x%08h)", name, got, exp);
            end else
                $display("ok    %0s = 0x%08h", name, got);
        end
    endtask

    initial begin
        $dumpfile("prueba_grupo1_9k_tb.vcd");
        $dumpvars(0, prueba_grupo1_9k_tb);

        repeat (5) @(posedge clk);
        btn_rst_n = 1'b1;

        // ---- Corrida 0: arranca sola despues del reset ----
        wait (dut.st == 3'd6);               // S_LISTO
        repeat (20) @(posedge clk);
        $display("\n== Corrida 0");
        check("LEDs {I2C, SPI} (encienden con 0)", led, 2'b00);
        check("Flash: byte grabado (0x5A)", flash.mem[0], 8'h5A);
        check("EEPROM: byte en 0x0010 (0x5A)", eeprom.mem[16], 8'h5A);
        check("JEDEC ID leido", dut.r0[23:0], 24'hEF4017);
        check("CLK_DIV del I2C = 67 (99,3 kHz a 27 MHz)", dut.u_mem.u_i2c.r_clk_div, 67);

        // ---- Corrida 1: con el boton, byte de prueba 0x5B ----
        btn_run_n = 1'b0;
        repeat (CLK_HZ / 100 + 10) @(posedge clk);   // antirrebote de 10 ms
        btn_run_n = 1'b1;
        wait (dut.st == 3'd2 || dut.st == 3'd1);
        wait (dut.st == 3'd6);
        repeat (20) @(posedge clk);
        $display("\n== Corrida 1");
        check("LEDs {I2C, SPI} (encienden con 0)", led, 2'b00);
        check("Flash: byte grabado (0x5B)", flash.mem[0], 8'h5B);
        check("EEPROM: byte en 0x0010 (0x5B)", eeprom.mem[16], 8'h5B);
        check("FALLA en el reporte", nfalla, 0);

        $display("\n%0d comprobaciones, %0d errores", checks, errors);
        if (errors == 0) $display("PASS: prueba_grupo1_9k (SPI e I2C por memoria_externa, reporte por UART y LEDs)");
        else             $display("FAIL: prueba_grupo1_9k");
        $finish;
    end

endmodule
