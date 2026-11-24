`timescale 1ns/1ps
// Testbench autoverificable del decodificador local B.3.
// Prueba solo el adaptador, NO el SoC ni el panel HUB75E físico.
module perip_hub75_ctrl_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst = 1'b1;
    reg cs = 1'b0, rd = 1'b0, wr = 1'b0;
    reg [4:0] addr = 5'd0;
    reg [31:0] d_in = 32'd0;
    reg frame_done = 1'b0;
    reg hub_oe_core = 1'b1;
    wire [31:0] d_out;
    wire hub_oe_panel, display_en;
    integer checks = 0;

    perip_hub75_ctrl dut (
        .clk(clk), .rst(rst), .cs(cs), .rd(rd), .wr(wr),
        .addr(addr), .d_in(d_in), .d_out(d_out),
        .frame_done(frame_done), .hub_oe_core(hub_oe_core),
        .hub_oe_panel(hub_oe_panel), .display_en(display_en)
    );

    task automatic check32;
        input [31:0] got, wanted;
        input [255:0] what;
        begin
            checks = checks + 1;
            if (got !== wanted)
                $fatal(1,"ERROR %0s: got=%08h expected=%08h", what, got, wanted);
        end
    endtask

    // Las operaciones del bus se presentan en el flanco negativo;
    // el dispositivo las captura en el siguiente flanco positivo.
    task automatic buswrite;
        input [4:0] offset;
        input [31:0] val;
        begin
            @(negedge clk);
            cs=1; wr=1; rd=0; addr=offset; d_in=val;
            @(posedge clk); #1;
            @(negedge clk);
            cs=0; wr=0;
        end
    endtask

    task automatic busread;
        input [4:0] offset;
        input [31:0] expected;
        begin
            @(negedge clk);
            cs=1; wr=0; rd=1; addr=offset;
            @(posedge clk); #1;
            check32(d_out, expected,"lectura local");
            @(negedge clk);
            cs=0; rd=0;
        end
    endtask

    task automatic framepulse;
        begin
            @(negedge clk); frame_done=1;
            @(posedge clk); #1;
            @(negedge clk); frame_done=0;
        end
    endtask

    initial begin
        $dumpfile("perip_hub75_ctrl_tb.vcd");
        $dumpvars(0, perip_hub75_ctrl_tb);
        repeat (3) @(negedge clk);
        rst=0;
        #1;
        check32({31'd0,display_en},32'd1,"reset DISPLAY_EN=1");
        check32({31'd0,hub_oe_panel},32'd1,"OE no activo al inicio");

        busread(5'h00,32'd1); // CONTROL
        busread(5'h04,32'd1); // STATUS
        busread(5'h08,32'd0); // FRAMES

        buswrite(5'h00,32'd0); // Deshabilitar imagen
        check32({31'd0,display_en},32'd0,"CONTROL escritura 0");
        hub_oe_core=0;
        #1;
        check32({31'd0,hub_oe_panel},32'd1,"OE forzado a apagado");
        busread(5'h00,32'd0);
        busread(5'h04,32'd0);

        // Escritura a STATUS: ignorada (registro solo lectura).
        buswrite(5'h04,32'hFFFFFFFF);
        busread(5'h00,32'd0);

        // Offset no definido, aunque alineado: sin efecto.
        buswrite(5'h0C,32'd1);
        busread(5'h0C,32'd0);
        busread(5'h00,32'd0);

        // Offset no alineado: no coincide con ninguno.
        buswrite(5'h01,32'd1);
        busread(5'h01,32'd0);
        busread(5'h00,32'd0);

        // Sin cs no se puede escribir.
        @(negedge clk);
        cs=0; wr=1; rd=0; addr=5'h00; d_in=32'd1;
        @(posedge clk); #1;
        check32({31'd0,display_en},32'd0,"sin CS no se escribe");
        @(negedge clk); wr=0;

        // Lectura y escritura simultaneas: ninguna aceptada.
        @(negedge clk);
        cs=1; wr=1; rd=1; addr=5'h00; d_in=32'd1;
        @(posedge clk); #1;
        check32(d_out,32'd0,"RD+WR simultaneos, sin lectura");
        check32({31'd0,display_en},32'd0,"RD+WR simultaneos, sin escritura");
        @(negedge clk); cs=0; rd=0; wr=0;

        // Reconexión del habilitador y prueba de OE normal.
        buswrite(5'h00,32'd1);
        check32({31'd0,display_en},32'd1,"CONTROL escritura 1");
        #1;
        check32({31'd0,hub_oe_panel},32'd0,"OE sigue al core habilitado");
        hub_oe_core=1; #1;
        check32({31'd0,hub_oe_panel},32'd1,"OE core apaga el panel");

        framepulse(); framepulse(); framepulse();
        busread(5'h08,32'd3);
        busread(5'h04,32'd1);
        $display("PASS: %0d comprobaciones B.3, sin errores",checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1,"Timeout en testbench B.3");
    end
endmodule
