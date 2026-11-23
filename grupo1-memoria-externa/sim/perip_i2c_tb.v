// perip_i2c_tb.v
// Banco de prueba del periferico I2C por el bus MMIO, con el modelo de la
// EEPROM 24LC256 y resistencias de pull-up en SCL y SDA.

`timescale 1ns/1ps
module perip_i2c_tb;

    reg clk = 1'b0;
    always #10 clk = ~clk;          // 50 MHz

    reg         rst = 1'b1;
    reg         cs = 1'b0, rd = 1'b0, wr = 1'b0;
    reg  [4:0]  addr = 5'd0;
    reg  [31:0] d_in = 32'd0;
    wire [31:0] d_out;

    wire i2c_scl, i2c_sda;
    pullup (i2c_scl);
    pullup (i2c_sda);

    perip_i2c dut (
        .clk(clk), .rst(rst),
        .cs(cs), .rd(rd), .wr(wr), .addr(addr), .d_in(d_in), .d_out(d_out),
        .i2c_scl(i2c_scl), .i2c_sda(i2c_sda)
    );

    eeprom_model eeprom (.scl(i2c_scl), .sda(i2c_sda));

    localparam CONTROL = 5'h00, TX_DATA = 5'h04, RX_DATA = 5'h08,
               STATUS = 5'h0C, CLK_DIV = 5'h10;
    localparam START = 32'h1, STOP = 32'h2, WRITE = 32'h4, READ = 32'h8,
               NACK = 32'h10;

    integer errors = 0, checks = 0;
    reg [31:0] rdata, st;

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
            d = d_out;
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

    // Da una orden y espera a que termine; devuelve STATUS
    task orden(input [31:0] c, output [31:0] s);
        integer guard;
        begin
            bus_write(CONTROL, c);
            s = 32'h1; guard = 0;
            while (s[0] && guard < 200000) begin
                bus_read(STATUS, s);
                guard = guard + 1;
            end
        end
    endtask

    task enviar(input [7:0] b, output [31:0] s);
        begin
            bus_write(TX_DATA, b);
            orden(WRITE, s);
        end
    endtask

    // Periodo de SCL
    integer scl_last = 0, scl_period = 0;
    always @(posedge i2c_scl) begin
        if (scl_last != 0) scl_period = $time - scl_last;
        scl_last = $time;
    end

    // ---------------- Cobertura de la tabla de transferencias ----------------
    localparam NT = 14;
    integer hits [0:NT-1];
    reg [8*4-1:0] tname [0:NT-1];
    integer k;
    initial begin
        tname[0]="H1"; tname[1]="T1"; tname[2]="T1w"; tname[3]="T1r"; tname[4]="T1p";
        tname[5]="T2"; tname[6]="T3"; tname[7]="T4";  tname[8]="H2";  tname[9]="T5";
        tname[10]="H3"; tname[11]="T6"; tname[12]="T6r"; tname[13]="T7";
        for (k = 0; k < NT; k = k + 1) hits[k] = 0;
    end
    wire [4:0] q  = dut.u_control.state;
    wire [4:0] qn = dut.u_control.state_next;
    always @(posedge clk) if (!rst) begin
        case (q)
            0:  if (qn == 0) hits[0] = hits[0] + 1;
                else if (qn == 1)  hits[1] = hits[1] + 1;
                else if (qn == 5 && !dut.u_control.rd_next) hits[2] = hits[2] + 1;
                else if (qn == 5)  hits[3] = hits[3] + 1;
                else if (qn == 10) hits[4] = hits[4] + 1;
            8:  if (!dut.u_control.bit_last) hits[6] = hits[6] + 1; else hits[7] = hits[7] + 1;
            16: if (!dut.u_control.scl_high) hits[8] = hits[8] + 1; else hits[9] = hits[9] + 1;
            15: if (!dut.u_control.tick) hits[10] = hits[10] + 1;
                else if (dut.u_control.n != 1) hits[11] = hits[11] + 1;
                else hits[12] = hits[12] + 1;
            14: hits[13] = hits[13] + 1;
            default: hits[5] = hits[5] + 1;             // estados de accion X
        endcase
    end

    integer t0, bytes_antes;

    initial begin
        $dumpfile("perip_i2c_tb.vcd");
        $dumpvars(0, perip_i2c_tb);

        repeat (3) @(negedge clk);
        rst = 0;
        repeat (3) @(negedge clk);

        $display("\n== Reset (R)");
        bus_read(CLK_DIV, rdata); check("CLK_DIV tras reset (100 kHz a 50 MHz)", rdata, 32'd124);
        bus_read(STATUS, rdata);  check("STATUS tras reset {DONE, ACK_IN, BUSY}", rdata, 32'h2);
        check("SCL y SDA sueltas", {i2c_scl, i2c_sda}, 2'b11);

        $display("\n== START + direccion 0xA0 a 100 kHz");
        orden(START, st);   check("STATUS tras START (DONE)", st, 32'h6);
        enviar(8'hA0, st);  check("ACK de la EEPROM (ACK_IN = 0)", st, 32'h4);
        // 4 cuartos de 125 ciclos = 500 ciclos (10 us), mas 1 ciclo por cada
        // estado de accion y la latencia del sincronizador de SCL: SCL queda
        // un poco por debajo de 100 kHz, dentro del limite del modo estandar.
        $display("      periodo de SCL medido: %0d ns (%0d Hz)", scl_period, 1000000000 / scl_period);
        check("SCL <= 100 kHz y a menos de 3 % (periodo entre 10000 y 10300 ns)",
              (scl_period >= 10000) && (scl_period <= 10300), 1);
        orden(STOP, st);
        check("bus libre tras STOP", {i2c_scl, i2c_sda}, 2'b11);

        bus_write(CLK_DIV, 32'd4);                     // SCL = 2,5 MHz para acelerar
        $display("\n== Escritura de un byte: 0x5C en 0x0012");
        orden(START, st);
        enviar(8'hA0, st);  check("ACK direccion de dispositivo", st[1], 0);
        enviar(8'h00, st);  check("ACK direccion alta", st[1], 0);
        enviar(8'h12, st);  check("ACK direccion baja", st[1], 0);
        enviar(8'h5C, st);  check("ACK dato", st[1], 0);
        orden(STOP, st);
        check("la EEPROM guardo 0x5C", eeprom.mem[16'h0012], 8'h5C);

        $display("\n== Lectura aleatoria de 0x0012 (START repetido y NACK)");
        orden(START, st);
        enviar(8'hA0, st);
        enviar(8'h00, st);
        enviar(8'h12, st);
        orden(START, st);                              // START repetido
        enviar(8'hA1, st);  check("ACK direccion de lectura", st[1], 0);
        orden(READ | NACK, st);
        orden(STOP, st);
        bus_read(RX_DATA, rdata); check("RX_DATA", rdata, 32'h5C);

        $display("\n== Lectura secuencial de 2 bytes (ACK y luego NACK)");
        eeprom.mem[16'h0020] = 8'h11; eeprom.mem[16'h0021] = 8'h22;
        orden(START, st); enviar(8'hA0, st); enviar(8'h00, st); enviar(8'h20, st);
        orden(START, st); enviar(8'hA1, st);
        orden(READ, st);           bus_read(RX_DATA, rdata); check("byte 1 (con ACK)", rdata, 32'h11);
        orden(READ | NACK, st);    bus_read(RX_DATA, rdata); check("byte 2 (con NACK)", rdata, 32'h22);
        orden(STOP, st);

        $display("\n== Direccion que no existe: NACK");
        orden(START, st);
        enviar(8'hB0, st);  check("ACK_IN = 1 (nadie respondio)", st, 32'h6);
        orden(STOP, st);

        $display("\n== Prioridad: START y WRITE en la misma orden -> solo START");
        bytes_antes = eeprom.bytes_rx;
        bus_write(TX_DATA, 32'hA0);
        orden(START | WRITE, st);
        check("no se envio ningun byte", eeprom.bytes_rx - bytes_antes, 0);
        orden(STOP, st);

        $display("\n== Estiramiento de reloj (SCL_WAIT)");
        eeprom.stretch_ns = 3000;
        orden(START, st);
        t0 = $time;
        enviar(8'hA0, st);
        enviar(8'h00, st);
        check("ACK con estiramiento", st[1], 0);
        eeprom.stretch_ns = 0;
        orden(STOP, st);

        $display("\n== Escritura con BUSY = 1 se ignora");
        bus_write(TX_DATA, 32'hA0);
        bus_write(CONTROL, START);
        bus_write(CLK_DIV, 32'd9);
        orden(STOP, st);
        bus_read(CLK_DIV, rdata); check("CLK_DIV no cambio", rdata, 32'd4);

        $display("\n== Reset en medio de una transaccion");
        orden(START, st);
        bus_write(TX_DATA, 32'hA0);
        bus_write(CONTROL, WRITE);
        repeat (30) @(negedge clk);
        rst = 1; @(negedge clk); rst = 0;
        repeat (3) @(negedge clk);
        check("el maestro suelta SCL y SDA tras reset",
              {dut.u_datapath.scl_oe, dut.u_datapath.sda_oe}, 2'b00);
        bus_read(STATUS, rdata); check("STATUS tras reset", rdata, 32'h2);

        $display("\n== Cobertura de la tabla de transferencias del I2C");
        for (k = 0; k < NT; k = k + 1) begin
            $display("   %4s : %0d", tname[k], hits[k]);
            checks = checks + 1;
            if (hits[k] == 0) begin
                errors = errors + 1;
                $display("FAIL  la fila %0s no se ejecuto", tname[k]);
            end
        end

        $display("\n%0d comprobaciones, %0d errores", checks, errors);
        if (errors == 0) $display("PASS: perip_i2c (MMIO, START/STOP, escritura y lectura de la EEPROM, ACK/NACK, prioridad, estiramiento de reloj, BUSY, reset)");
        else             $display("FAIL: perip_i2c");
        $finish;
    end
endmodule
