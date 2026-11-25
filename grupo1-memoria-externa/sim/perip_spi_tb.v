// perip_spi_tb.v
// Banco de prueba del periferico SPI por el bus MMIO, con el modelo de la
// Flash. Cada caso sale de una fila de la tabla de transferencias o de la
// semantica START / BUSY / DONE. Al final imprime PASS o FAIL.
//
// Compilar y simular (Icarus Verilog):
//   iverilog -g2012 -o perip_spi_tb.vvp sim/perip_spi_tb.v sim/flash_model.v \
//            rtl/perip_spi.v rtl/spi_control.v rtl/spi_datapath.v
//   vvp perip_spi_tb.vvp
//   gtkwave perip_spi_tb.vcd

`timescale 1ns/1ps
module perip_spi_tb;

    // Reloj de 50 MHz
    reg clk = 1'b0;
    always #10 clk = ~clk;

    reg         rst = 1'b1;
    reg         cs = 1'b0, rd = 1'b0, wr = 1'b0;
    reg  [4:0]  addr = 5'd0;
    reg  [31:0] d_in = 32'd0;
    wire [31:0] d_out;

    wire spi_sck, spi_mosi, spi_cs_n, spi_wp_n, spi_hold_n, spi_miso;

    perip_spi dut (
        .clk(clk), .rst(rst),
        .cs(cs), .rd(rd), .wr(wr), .addr(addr), .d_in(d_in), .d_out(d_out),
        .spi_sck(spi_sck), .spi_mosi(spi_mosi), .spi_cs_n(spi_cs_n),
        .spi_wp_n(spi_wp_n), .spi_hold_n(spi_hold_n), .spi_miso(spi_miso)
    );

    flash_model flash (.sck(spi_sck), .cs_n(spi_cs_n), .mosi(spi_mosi), .miso(spi_miso));

    // Direcciones de los registros
    localparam CONTROL = 5'h00, ADDR = 5'h04, WDATA = 5'h08,
               RDATA = 5'h0C, STATUS = 5'h10, CLK_DIV = 5'h14;

    // Campos de CONTROL
    localparam START = 32'h1, RW = 32'h2, SIN_DIR = 32'h1_0000,
               MANTENER = 32'h8_0000, CONTINUAR = 32'h10_0000;
    function [31:0] CMD;  input [7:0] c; CMD = {16'b0, c, 8'b0}; endfunction
    function [31:0] NB;   input [1:0] n; NB  = {13'b0, n, 17'b0}; endfunction

    integer errors = 0;
    integer checks = 0;
    reg [31:0] rdata;

    // ---------------- Tareas del bus (un ciclo por acceso) ----------------
    task bus_write(input [4:0] a, input [31:0] d);
        begin
            @(negedge clk); cs = 1; wr = 1; addr = a; d_in = d;
            @(negedge clk); cs = 0; wr = 0; d_in = 0;
        end
    endtask

    task bus_read(input [4:0] a, output [31:0] d);
        begin
            @(negedge clk); cs = 1; rd = 1; addr = a;
            @(negedge clk); cs = 0; rd = 0;
            d = d_out;                 // lectura registrada: un ciclo despues
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

    // Sondea STATUS hasta BUSY = 0 y devuelve el valor de STATUS
    task wait_idle(output [31:0] st);
        integer guard;
        begin
            guard = 0;
            st = 32'h1;
            while (st[0] && guard < 100000) begin
                bus_read(STATUS, st);
                guard = guard + 1;
            end
        end
    endtask

    // Contador de ciclos de una transaccion (de START a done)
    integer t_start, t_done;
    always @(posedge clk) begin
        if (dut.start)      t_start <= $time;
        if (dut.done_core)  t_done  <= $time;
    end

    // Periodo de SCK
    integer sck_last = 0, sck_period = 0;
    always @(posedge spi_sck) begin
        if (sck_last != 0) sck_period = $time - sck_last;
        sck_last = $time;
    end


    // ---------------- Cobertura de la tabla de transferencias ----------------
    // Cada flanco se clasifica con el ID de la fila de la tabla que se ejecuta.
    localparam S_IDLE = 0, S_CS_SETUP = 1, S_LOAD = 2, S_LOW = 3, S_HIGH = 4,
               S_FIN = 5, S_CS_HOLD = 6, S_CS_REST = 7, S_DONE = 8;
    localparam NT = 18;
    integer hits [0:NT-1];
    reg [8*5-1:0] tname [0:NT-1];
    integer k;
    initial begin
        tname[0]="H1";  tname[1]="T1";  tname[2]="T1c"; tname[3]="T1n"; tname[4]="H2";
        tname[5]="T2";  tname[6]="T3";  tname[7]="T4";  tname[8]="T5";  tname[9]="T6";
        tname[10]="T7"; tname[11]="T8"; tname[12]="T8m";tname[13]="T9"; tname[14]="T10";
        tname[15]="T11";tname[16]="T11d";tname[17]="T12";
        for (k = 0; k < NT; k = k + 1) hits[k] = 0;
    end

    wire [3:0] q  = dut.u_control.state;
    wire [3:0] qn = dut.u_control.state_next;
    wire       tk = dut.u_control.tick;
    wire       hf = dut.u_control.half;
    always @(posedge clk) if (!rst) begin
        case (q)
            S_IDLE:     if (qn == S_IDLE) hits[0] = hits[0] + 1;
                        else if (qn == S_CS_SETUP) hits[1] = hits[1] + 1;
                        else if (qn == S_LOAD) hits[2] = hits[2] + 1;
                        else if (qn == S_FIN) hits[3] = hits[3] + 1;
            S_CS_SETUP: if (!tk) hits[4] = hits[4] + 1; else hits[5] = hits[5] + 1;
            S_LOAD:     hits[6] = hits[6] + 1;
            S_LOW:      if (!tk) hits[4] = hits[4] + 1; else hits[7] = hits[7] + 1;
            S_HIGH:     if (!tk) hits[4] = hits[4] + 1;
                        else if (qn == S_LOW) hits[8] = hits[8] + 1;
                        else if (qn == S_LOAD) hits[9] = hits[9] + 1;
                        else hits[10] = hits[10] + 1;
            S_FIN:      if (qn == S_CS_HOLD) hits[11] = hits[11] + 1; else hits[12] = hits[12] + 1;
            S_CS_HOLD:  if (!tk) hits[4] = hits[4] + 1;
                        else if (!hf) hits[13] = hits[13] + 1; else hits[14] = hits[14] + 1;
            S_CS_REST:  if (!tk) hits[4] = hits[4] + 1;
                        else if (!hf) hits[15] = hits[15] + 1; else hits[16] = hits[16] + 1;
            S_DONE:     hits[17] = hits[17] + 1;
        endcase
    end

    task report_coverage;
        begin
            $display("\n== Cobertura de la tabla de transferencias (veces que se ejecuto cada fila)");
            for (k = 0; k < NT; k = k + 1) begin
                $display("   %5s : %0d", tname[k], hits[k]);
                checks = checks + 1;
                if (hits[k] == 0) begin
                    errors = errors + 1;
                    $display("FAIL  la fila %0s no se ejecuto", tname[k]);
                end
            end
        end
    endtask

    reg [31:0] st;
    integer ciclos;

    initial begin
        $dumpfile("perip_spi_tb.vcd");
        $dumpvars(0, perip_spi_tb);

        repeat (3) @(negedge clk);
        rst = 0;

        // ---- Reset (R) ----
        $display("\n== Reset (R)");
        bus_read(CLK_DIV, rdata);  check("CLK_DIV tras reset", rdata, 32'd1);
        bus_read(STATUS,  rdata);  check("STATUS tras reset", rdata, 32'd0);
        check("CS_n tras reset", spi_cs_n, 1);
        check("WP_n y HOLD_n en 1", {spi_wp_n, spi_hold_n}, 2'b11);

        // ---- JEDEC ID: 0x9F, SIN_DIR, NB = 3 (T1, T2, T3..T7, T8..T12) ----
        $display("\n== JEDEC ID (0x9F, sin direccion, 3 bytes)");
        bus_write(CONTROL, START | CMD(8'h9F) | SIN_DIR | NB(3));
        bus_read(STATUS, rdata);
        check("STATUS en curso {CS_ACTIVO, DONE, BUSY}", rdata, 32'h5);
        wait_idle(st);
        check("STATUS al terminar (DONE = 1, BUSY = 0)", st, 32'h2);
        bus_read(STATUS, rdata);
        check("DONE se limpia al leer STATUS", rdata, 32'h0);
        bus_read(RDATA, rdata);
        check("RDATA = JEDEC ID", rdata, 32'h00EF4017);
        check("periodo de SCK con CLK_DIV = 1 (ns)", sck_period, 80);

        // ---- Lectura 0x03 de 1 byte en la direccion 0x10 ----
        $display("\n== Lectura 0x03, 1 byte en 0x000010");
        bus_write(ADDR, 32'h000010);
        bus_write(CONTROL, START | CMD(8'h03) | NB(1));
        wait_idle(st);
        bus_read(RDATA, rdata);
        check("RDATA = mem[0x10]", rdata, {24'b0, 8'h10 ^ 8'h5A});

        // ---- Lectura 0x03 de 3 bytes y conteo de ciclos ----
        $display("\n== Lectura 0x03, 3 bytes en 0x000020");
        bus_write(ADDR, 32'h000020);
        bus_write(CONTROL, START | CMD(8'h03) | NB(3));
        wait_idle(st);
        bus_read(RDATA, rdata);
        check("RDATA = mem[0x20..0x22]", rdata,
              {8'b0, 8'h20 ^ 8'h5A, 8'h21 ^ 8'h5A, 8'h22 ^ 8'h5A});
        ciclos = (t_done - t_start) / 20;
        $display("      ciclos de reloj de START a done: %0d (ticks = %0d con CLK_DIV = 1)",
                 ciclos, ciclos / 2);

        // ---- Lectura de 4 bytes: MANTENER + CONTINUAR (T8m, T1c) ----
        $display("\n== Lectura de 4 bytes en 0x000040 con MANTENER y CONTINUAR");
        bus_write(ADDR, 32'h000040);
        bus_write(CONTROL, START | CMD(8'h03) | NB(3) | MANTENER);
        wait_idle(st);
        check("STATUS tras MANTENER (CS sigue activo)", st, 32'h6);
        check("CS_n sigue en 0", spi_cs_n, 0);
        $display("      parte 1 (comando + direccion + 3 bytes): %0d ciclos", (t_done - t_start) / 20);
        bus_read(RDATA, rdata);
        check("bytes 1 a 3", rdata,
              {8'b0, 8'h40 ^ 8'h5A, 8'h41 ^ 8'h5A, 8'h42 ^ 8'h5A});
        bus_write(CONTROL, START | NB(1) | CONTINUAR);
        wait_idle(st);
        check("STATUS tras CONTINUAR sin MANTENER (CS liberado)", st, 32'h2);
        $display("      parte 2 (CONTINUAR, 1 byte + liberar CS): %0d ciclos", (t_done - t_start) / 20);
        check("CS_n vuelve a 1", spi_cs_n, 1);
        bus_read(RDATA, rdata);
        check("byte 4", rdata, {24'b0, 8'h43 ^ 8'h5A});

        // ---- T1n: CONTINUAR sin datos (NB = 0, RW = 0) ----
        $display("\n== T1n: CONTINUAR sin datos que mover");
        bus_write(CONTROL, START | CMD(8'h03) | NB(1) | MANTENER);
        wait_idle(st);
        sck_last = 0;
        bus_write(CONTROL, START | NB(0) | CONTINUAR);
        wait_idle(st);
        check("T1n termina sin pulsos de SCK", sck_last, 0);
        check("y libera CS_n", spi_cs_n, 1);

        // ---- Escritura: 0x06 (WREN) y 0x02 (PAGE PROGRAM) de un byte ----
        $display("\n== Escritura: WREN (0x06) y PAGE PROGRAM (0x02) en 0x000005");
        bus_write(CONTROL, START | CMD(8'h06) | SIN_DIR);           // solo comando
        wait_idle(st);
        bus_write(ADDR,  32'h000005);
        bus_write(WDATA, 32'h000000C3);
        bus_write(CONTROL, START | CMD(8'h02) | RW);
        wait_idle(st);
        bus_write(CONTROL, START | CMD(8'h03) | NB(1));
        wait_idle(st);
        bus_read(RDATA, rdata);
        check("lectura de comprobacion = 0xC3", rdata, 32'h000000C3);

        // ---- Escrituras ignoradas con BUSY = 1 ----
        $display("\n== Escritura con BUSY = 1 se ignora");
        bus_write(CONTROL, START | CMD(8'h9F) | SIN_DIR | NB(3));
        bus_write(CLK_DIV, 32'd7);                                  // ocupado
        wait_idle(st);
        bus_read(CLK_DIV, rdata);
        check("CLK_DIV no cambio", rdata, 32'd1);

        // ---- CLK_DIV = 3: SCK = 50 MHz / 8 ----
        $display("\n== CLK_DIV = 3");
        bus_write(CLK_DIV, 32'd3);
        bus_write(CONTROL, START | CMD(8'h9F) | SIN_DIR | NB(3));
        wait_idle(st);
        check("periodo de SCK con CLK_DIV = 3 (ns)", sck_period, 160);
        bus_read(RDATA, rdata);
        check("RDATA = JEDEC ID", rdata, 32'h00EF4017);

        // ---- Reset a mitad de una transaccion ----
        $display("\n== Reset en medio de una transaccion");
        bus_write(CONTROL, START | CMD(8'h9F) | SIN_DIR | NB(3));
        repeat (40) @(negedge clk);
        rst = 1; @(negedge clk); rst = 0;
        check("CS_n en 1 tras reset", spi_cs_n, 1);
        bus_read(STATUS, rdata);
        check("STATUS = 0 tras reset", rdata, 32'h0);

        report_coverage;

        // ---- Resultado ----
        $display("\n%0d comprobaciones, %0d errores", checks, errors);
        if (errors == 0) $display("PASS: perip_spi (MMIO, JEDEC, lectura, MANTENER/CONTINUAR, escritura, BUSY, DONE retenido, reset)");
        else             $display("FAIL: perip_spi");
        $finish;
    end

endmodule
