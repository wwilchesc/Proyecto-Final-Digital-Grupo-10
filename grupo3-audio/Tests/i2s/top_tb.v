// ==========================================================
// top_tb.v - Testbench para Simulación (Icarus / GTKWave)
// ==========================================================
`timescale 1ns / 1ps

module top_tb;

    reg clk;
    reg rst_n;

    wire bclk;
    wire lrck;
    wire sdin;

    // Instancia de la Unidad Bajo Prueba (UUT)
    top uut (
        .clk(clk),
        .rst_n(rst_n),
        .bclk(bclk),
        .lrck(lrck),
        .sdin(sdin)
    );

    // Reloj de 27 MHz (Período ≈ 37.037 ns)
    always #18.5185 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;

        // Generar archivo VCD para visualización gráfica
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

        // Liberar Reset tras 100 ns
        #100;
        rst_n = 1'b1;

        // Simular 2 ms para capturar múltiples tramas I2S y el cambio del tono
        #2000000;

        $finish;
    end

endmodule
