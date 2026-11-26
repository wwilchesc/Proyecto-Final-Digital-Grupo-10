`timescale 1ns/1ps
// Prueba integral: bus de 32 bits -> MMIO -> RAM doble banco -> FSM -> pines.
// No instancia CPU; el TB simula las transacciones del SoC y su decoder global.
// ============================================================================
// TESTBENCH - Verificación integral autocorrectiva (no sintetizable)
// Simula el maestro del bus y reconstruye las señales de un panel ideal.
// No prueba el núcleo FemtoRV32, los niveles eléctricos ni los recursos FPGA.
// ============================================================================
module perip_hub75_tb;
    // Bases del mapa MMIO de la consola.
    localparam [31:0] FB = 32'h00480000, CTL = 32'h004C0000;
    reg clk=0, rst=1;
    // Reloj de simulación: período 10 ns (100 MHz), NO el de placa 27 MHz.
    always #5 clk=~clk;
    reg rd=0, wr=0;
    reg [31:0] bus_addr=0, d_in=0;
    // Modelo mínimo del decodificador global; el DUT filtra el offset local.
    wire cs_fb = bus_addr[31:16] == 16'h0048;
    wire cs_ctrl = bus_addr[31:16] == 16'h004C;
    wire [31:0] d_out;
    wire r1,g1,b1,r2,g2,b2,hub_clk,hub_lat,hub_oe;
    wire [4:0] hub_addr;
    // T_BASE reducido para agilizar la simulacion; geometria real 64x64.
    perip_hub75 #(.T_BASE(8)) dut (
        .clk(clk),.rst(rst),.cs_fb(cs_fb),.cs_ctrl(cs_ctrl),.rd(rd),.wr(wr),
        .addr(bus_addr[15:0]),.d_in(d_in),.d_out(d_out),
        .r1(r1),.g1(g1),.b1(b1),.r2(r2),.g2(g2),.b2(b2),
        .hub_addr(hub_addr),.hub_clk(hub_clk),.hub_lat(hub_lat),.hub_oe(hub_oe)
    );

    // Aserción: falla también si condition contiene X o Z. $fatal detiene
    // inmediatamente la simulación con código de error.
    task check(input condition, input [8*100-1:0] message);
        begin
            if (condition !== 1'b1) $fatal(1,"FAIL: %0s (t=%0t)",message,$time);
        end
    endtask
    // Escritura de palabra: se presentan dirección/dato en flanco negativo,
    // el DUT los consume en el positivo y wr se desactiva en el negativo
    // siguiente. #1 deja que terminen las asignaciones no bloqueantes.
    task write32(input [31:0] a, input [31:0] v);
        begin
            @(negedge clk); bus_addr=a; d_in=v; rd=0; wr=1;
            @(posedge clk); #1;
            @(negedge clk); wr=0;
        end
    endtask
    // Lectura: misma temporización, pero rd=1. Se captura d_out después del
    // flanco positivo porque la respuesta del periférico está registrada.
    task read32(input [31:0] a, output [31:0] v);
        begin
            @(negedge clk); bus_addr=a; rd=1; wr=0;
            @(posedge clk); #1; v=d_out;
            @(negedge clk); rd=0;
        end
    endtask
    // Patrón de colores conocido: depende de mitad, columna, fila y banco.
    // Los bancos tienen patrones complementarios, para detectar confusiones.
    function [2:0] pixel(input [11:0] i, input bank);
        reg [2:0] p;
        begin
            p = {~i[11], i[0], i[11]^i[6]};
            pixel = bank ? p : ~p;
        end
    endfunction
    // Enviar 4096 palabras consecutivas al banco posterior. El argumento
    // bank elige el patrón esperado, no selecciona directamente la RAM.
    task fill_frame(input bank);
        integer k;
        begin
            for(k=0;k<4096;k=k+1)
                write32(FB+4*k,{29'd0,pixel(k[11:0],bank)});
        end
    endtask

    // Modelo del panel: reconstruye las 64 muestras RGB de cada LAT.
    // Verifica orden de columnas y las dos mitades en cada fila mostrada.
    reg [5:0] shifted[0:63], latched[0:63];
    integer shifts=0, lats=0, checked_rows=0, checked_bank0=0, checked_bank1=0;
    integer j, k;
    // Cada flanco ascendente de CLK del panel captura los seis bits de una
    // columna en el modelo del TB; no confundir con el clk principal.
    always @(posedge hub_clk) if (!rst) begin
        check(shifts<64,"mas de 64 pulsos CLK antes de LAT");
        shifted[shifts]={r1,g1,b1,r2,g2,b2};
        shifts=shifts+1;
    end
    // LAT debe aparecer después de exactamente 64 muestras. El TB copia
    // su registro de desplazamiento conceptual al de salida y comprueba OE.
    always @(posedge hub_lat) if (!rst) begin
        check(shifts==64,"LAT debe ocurrir despues de 64 pulsos CLK");
        for(j=0;j<64;j=j+1) latched[j]=shifted[j];
        shifts=0;
        lats=lats+1;
        #1; check(hub_oe===1'b1,"OE debe estar alto durante LAT");
    end
    // Cuando el núcleo habilita una pareja de filas y existe banco válido,
    // comparar los 64 patrones RGB superiores e inferiores con la referencia.
    // Se observa OE del núcleo para comprobar datos aunque MMIO apague el panel.
    always @(negedge dut.hub_oe_core) if (!rst && dut.front_valid) begin
        for(k=0;k<64;k=k+1) begin
            check(latched[k][5:3] === pixel({1'b0,hub_addr,k[5:0]},dut.disp_bank),"RGB superior incorrecto");
            check(latched[k][2:0] === pixel({1'b1,hub_addr,k[5:0]},dut.disp_bank),"RGB inferior incorrecto");
        end
        checked_rows=checked_rows+1;
        if(dut.disp_bank) checked_bank1=checked_bank1+1;
        else checked_bank0=checked_bank0+1;
    end

    // Comprueba atomicidad del intercambio, conteo de frames y proteccion BUSY.
    reg old_bank, old_busy, boundary;
    reg [31:0] expected_frames=0;
    always @(posedge clk) begin
        if(rst) expected_frames=0;
        else begin
            // Guardar estado ANTES del flanco; después de #1 comparar con
            // los nuevos valores. Solo se permite swap si BUSY y frame_done
            // estaban activos simultáneamente antes de ese flanco.
            old_bank=dut.disp_bank; old_busy=dut.busy; boundary=dut.frame_done;
            if(boundary) expected_frames=expected_frames+1;
            if(old_busy) check(!dut.we,"escritura habilitada mientras BUSY=1");
            #1;
            check(dut.disp_bank === (old_bank ^ (old_busy && boundary)),"banco cambio fuera del handshake");
            check(dut.ctrl_mmio.r_frames === expected_frames,"contador FRAMES incorrecto");
            if(old_busy && boundary) check(dut.done && !dut.busy,"DONE/BUSY incorrectos al completar swap");
        end
    end

    reg [31:0] value;
    initial begin
        if($test$plusargs("vcd")) begin
            $dumpfile("build/perip_hub75_tb.vcd"); $dumpvars(0,perip_hub75_tb);
        end
        // Fase 1: reset y comprobaciones del mapa de registros.
        repeat(4) @(negedge clk); rst=0;
        read32(CTL,value); check(value==1,"CONTROL tras reset");
        read32(CTL+4,value); check(value==1,"STATUS tras reset");
        check(hub_oe===1'b1,"panel debe iniciar apagado hasta primer swap");
        // Intentos inválidos: alias, escrituras a RO, otra región y rd/wr juntos.
        write32(CTL+32,0); read32(CTL,value); check(value==1,"alias de CONTROL");
        write32(CTL+4,0); write32(CTL+8,0); read32(CTL,value); check(value==1,"escritura a RO");
        read32(CTL+32,value); check(value==0,"lectura alias");
        read32(32'h00420000,value); check(value==0,"seleccion de region ajena");
        @(negedge clk); bus_addr=CTL; d_in=0; wr=1; rd=1;
        @(negedge clk); wr=0; rd=0;
        read32(CTL,value); check(value==1,"rd y wr simultaneos deben ignorarse");

        // Banco posterior 1. Debe conservar su contenido ante accesos invalidos.
        // Fase 2: escribir primer cuadro y verificar bloqueo de direcciones inválidas.
        fill_frame(1'b1);
        write32(FB+16'h4000,0); write32(FB+1,0);
        write32(32'h00490000,0);
        read32(FB,value); check(value==0,"framebuffer solo escritura");
        // Sincroniza la prueba con el comienzo de un barrido para medir BUSY sin carreras.
        @(posedge dut.frame_done); @(negedge clk);
        // Pedir swap: STATUS=0x03 (BUSY y EN). El banco no cambia de inmediato.
        write32(CTL,3); read32(CTL+4,value); check(value==3,"START debe activar BUSY y borrar DONE");
        check(dut.disp_bank==0,"START no debe cambiar banco inmediatamente");
        // Se bloquea el píxel y se ignora el nuevo START; DISPLAY_EN se
        // actualiza normalmente (se vuelve a escribir 1, sin cambio visible).
        write32(FB,0); write32(CTL,3); // intentos durante BUSY
        // Al completar el barrido, STATUS=0x0D: FRONT_VALID, DONE y EN.
        wait(dut.done); @(negedge clk);
        read32(CTL+4,value); check(value==13,"STATUS tras swap: valid DONE EN");
        read32(CTL+8,value); check(value==expected_frames && value>0,"lectura de FRAMES");
        read32(CTL,value); check(value==1,"START no se almacena");
        // Fase 3: llenar el banco opuesto mientras el primer cuadro se barre.
        // Otro START borra DONE y conserva FRONT_VALID: STATUS=0x0B.
        fill_frame(1'b0);
        check(checked_bank1>0,"primer cuadro no visible");
        @(posedge dut.frame_done); @(negedge clk);
        write32(CTL,3); read32(CTL+4,value); check(value==11,"nuevo START limpia DONE y activa BUSY");
        wait(dut.done); @(negedge clk);
        read32(CTL+4,value); check(value==13,"segundo swap completado");
        check(dut.disp_bank==0,"segundo swap vuelve a banco 0");
        wait(checked_bank0>=32); @(negedge clk);
        // Fase 4: apagar y reactivar la salida física mediante DISPLAY_EN.
        // El motor de barrido sigue funcionando, y DONE permanece latente.
        write32(CTL,0); wait(dut.hub_oe_core==0); #1;
        check(hub_oe==1,"DISPLAY_EN=0 debe forzar OE alto");
        read32(CTL+4,value); check(value==12,"STATUS con display deshabilitado");
        write32(CTL,1); wait(dut.hub_oe_core==0); #1;
        check(hub_oe==0,"DISPLAY_EN=1 permite visualizacion");
        read32(CTL+4,value); check(value==13,"DONE permanece hasta nuevo START");
        check(checked_bank1>=32 && checked_bank0>=32,"faltan filas verificadas de ambos bancos");
        $display("PASS: MMIO CONTROL/STATUS/FRAMES, START/BUSY/DONE, doble buffer y barrido RGB111; filas=%0d LAT=%0d frames=%0d",checked_rows,lats,expected_frames);
        $finish;
    end
    // Límite de 3 ms de tiempo simulado: detecta bloqueos (por ejemplo, DONE
    // nunca se activa) para que un wait no deje la simulación indefinida.
    initial begin #3000000; $fatal(1,"FAIL: timeout"); end
endmodule
