`timescale 1ns / 1ps

module tb_i2s_melody;

    reg         clk = 0;
    reg         rst = 1;
    reg         cs  = 0;
    reg         wr  = 0;
    reg         rd  = 0;
    reg  [3:0]  addr = 4'd0;
    reg  [31:0] d_in = 32'd0;
    wire [31:0] d_out;

    wire bclk;
    wire lrck;
    wire sdin;

    // Reloj de 27 MHz (período = 37.037 ns -> semiperíodo = 18.518 ns)
    always #18.518 clk = ~clk;

    // Instancia del periférico completo
    i2s_melody_peripheral #(
        .MEM_FILE("pacman_songs.mem")
    ) dut (
        .clk   (clk),
        .rst   (rst),
        .cs    (cs),
        .wr    (wr),
        .rd    (rd),
        .addr  (addr),
        .d_in  (d_in),
        .d_out (d_out),
        .bclk  (bclk),
        .lrck  (lrck),
        .sdin  (sdin)
    );

    initial begin
        $dumpfile("i2s_test.vcd");
        $dumpvars(0, tb_i2s_melody);

        // 1. Mantener reset por 100 ns
        #100;
        rst = 0;
        #100;

        // 2. Simular escritura MMIO del FemtoRV: play song_id = 0, loop = 0
        // Bit 4 = 1 (play), Bits [3:0] = 0 (Intro Pac-Man)
        @(posedge clk);
        cs   <= 1'b1;
        wr   <= 1'b1;
        addr <= 4'h0;
        d_in <= 32'h0000_0010;

        @(posedge clk);
        cs   <= 1'b0;
        wr   <= 1'b0;
        d_in <= 32'd0;

        // 3. Simular durante 2 ms para ver varias tramas I2S y cambio de polaridad de onda
        #2_000_000;
        $finish;
    end

endmodule
