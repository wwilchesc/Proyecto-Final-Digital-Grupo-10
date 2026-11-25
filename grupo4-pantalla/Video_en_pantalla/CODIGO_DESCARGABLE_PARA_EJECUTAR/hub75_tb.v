`timescale 1ns/1ps

// Testbench autoverificable con un panel REDUCIDO para ver todo en pocos ciclos:
//   4 columnas, 2 pares de filas, 2 planos, T_BASE = 1
// Con estos valores una fila del plano 0 dura 26 ciclos (igual que el diagrama de tiempo).
//
// Comprueba, ciclo a ciclo:
//   - los bits RGB que hay en cada pulso de CLK_P son los de la imagen
//   - CLK_P solo sube con los LEDs apagados (Oe = 1) y dura 1 ciclo
//   - lat llega despues de exactamente COLS pulsos de CLK_P
//   - la direccion solo cambia con Oe = 1 y es la fila correcta
//   - los LEDs permanecen encendidos T + 1 ciclos
//   - el fotograma completo dura el numero de ciclos esperado
module hub75_tb;

    localparam COLS      = 4;
    localparam HALF_ROWS = 2;
    localparam PLANES    = 2;
    localparam T_BASE    = 1;
    localparam RW        = 1;
    localparam CW        = 2;
    localparam FRAMES    = 3;

    reg clk = 1'b0;
    reg rst = 1'b1;

    wire       r1, g1, b1, r2, g2, b2;
    wire [4:0] addr;
    wire       hub_clk, hub_lat, hub_oe;

    // INIT_TOP/INIT_BOT vacios: la imagen la escribe este testbench.
    // Sin carga de video: las entradas de escritura van a 0.
    hub75_top #(
        .COLS(COLS), .HALF_ROWS(HALF_ROWS), .PLANES(PLANES),
        .T_BASE(T_BASE), .INIT_TOP(""), .INIT_BOT("")
    ) dut (
        .clk(clk), .rst(rst),
        .we(1'b0), .waddr({(1 + RW + CW){1'b0}}), .wdata(24'd0),
        .frame_start(1'b0), .frame_end(1'b0),
        .r1(r1), .g1(g1), .b1(b1), .r2(r2), .g2(g2), .b2(b2),
        .addr(addr), .hub_clk(hub_clk), .hub_lat(hub_lat), .hub_oe(hub_oe)
    );

    always #5 clk = ~clk;      // 100 MHz, solo para simular

    // ------------------------------------------------------------------
    // Imagen de prueba (se escribe un instante despues del inicio)
    // ------------------------------------------------------------------
    integer i;
    initial begin
        #1;
        // i = {mitad, fila, columna}; la memoria se indexa {banco, fila, columna}
        // y el banco que se muestra al arrancar es el 0.
        for (i = 0; i < (1 << (1 + RW + CW)); i = i + 1)
            if (i < (1 << (RW + CW))) dut.fb.mem_top[i] = i * 32'h35A7C1 + 32'h19B3D5;
            else                      dut.fb.mem_bot[i - (1 << (RW + CW))] = i * 32'h35A7C1 + 32'h19B3D5;
    end

    // ------------------------------------------------------------------
    // Reset
    // ------------------------------------------------------------------
    initial begin
        repeat (3) @(negedge clk);
        rst = 1'b0;
    end

    // ------------------------------------------------------------------
    // Ciclos esperados por fotograma:
    //   por (plano, fila): 5*COLS + 3 (L1,L0,AD) + (T+1) (SHOW) + 1 (BLANK)
    // ------------------------------------------------------------------
    integer p;
    integer frame_cycles;
    initial begin
        frame_cycles = 0;
        for (p = 0; p < PLANES; p = p + 1)
            frame_cycles = frame_cycles + HALF_ROWS * (5*COLS + 3 + (T_BASE << p) + 1 + 1);
    end

    // ------------------------------------------------------------------
    // Observador: muestrea en el flanco de bajada (las senales ya estan estables)
    // ------------------------------------------------------------------
    reg        started   = 1'b0;
    reg        prev_clk  = 1'b0;
    reg        prev_lat  = 1'b0;
    reg        prev_oe   = 1'b1;
    reg  [4:0] prev_addr = 5'd0;

    integer cycle         = 0;
    integer lat_count     = 0;   // latches vistos = indice de la fila que se esta cargando
    integer pix_count     = 0;   // pulsos de CLK_P desde el ultimo latch
    integer oe_low_cycles = 0;
    integer lat_cycle [0:63];
    integer exp_row, exp_plane, exp_t, lat_idx;
    reg [23:0] exp_top, exp_bot;

    always @(negedge clk) begin
        if (!started) begin
            if (dut.rst_i === 1'b0) begin
                started   = 1'b1;
                prev_clk  = hub_clk;
                prev_lat  = hub_lat;
                prev_oe   = hub_oe;
                prev_addr = addr;
                cycle     = 0;
            end
        end else begin
            cycle = cycle + 1;

            // ---- subida de CLK_P: comprobar los datos ----
            if (hub_clk && !prev_clk) begin
                if (hub_oe !== 1'b1)  $fatal(1, "CLK_P subio con los LEDs encendidos");
                if (hub_lat !== 1'b0) $fatal(1, "CLK_P subio mientras lat estaba activo");
                if (pix_count >= COLS) $fatal(1, "Demasiados pulsos de CLK_P en la fila");

                exp_row   = lat_count % HALF_ROWS;
                exp_plane = (lat_count / HALF_ROWS) % PLANES;
                exp_top   = dut.fb.mem_top[{1'b0, exp_row[RW-1:0], pix_count[CW-1:0]}];
                exp_bot   = dut.fb.mem_bot[{1'b0, exp_row[RW-1:0], pix_count[CW-1:0]}];

                if (r1 !== exp_top[16 + exp_plane]) $fatal(1, "R1 incorrecto: fila %0d col %0d plano %0d", exp_row, pix_count, exp_plane);
                if (g1 !== exp_top[8  + exp_plane]) $fatal(1, "G1 incorrecto: fila %0d col %0d plano %0d", exp_row, pix_count, exp_plane);
                if (b1 !== exp_top[0  + exp_plane]) $fatal(1, "B1 incorrecto: fila %0d col %0d plano %0d", exp_row, pix_count, exp_plane);
                if (r2 !== exp_bot[16 + exp_plane]) $fatal(1, "R2 incorrecto: fila %0d col %0d plano %0d", exp_row, pix_count, exp_plane);
                if (g2 !== exp_bot[8  + exp_plane]) $fatal(1, "G2 incorrecto: fila %0d col %0d plano %0d", exp_row, pix_count, exp_plane);
                if (b2 !== exp_bot[0  + exp_plane]) $fatal(1, "B2 incorrecto: fila %0d col %0d plano %0d", exp_row, pix_count, exp_plane);

                pix_count = pix_count + 1;
            end

            // CLK_P dura un solo ciclo
            if (hub_clk && prev_clk) $fatal(1, "CLK_P duro mas de un ciclo");

            // ---- subida de lat ----
            if (hub_lat && !prev_lat) begin
                if (pix_count !== COLS) $fatal(1, "lat llego tras %0d pulsos de CLK_P (se esperaban %0d)", pix_count, COLS);
                if (hub_oe !== 1'b1)    $fatal(1, "lat subio con los LEDs encendidos");
                if (hub_clk !== 1'b0)   $fatal(1, "lat subio junto con CLK_P");

                lat_cycle[lat_count] = cycle;
                if (lat_count >= HALF_ROWS * PLANES) begin
                    if (cycle - lat_cycle[lat_count - HALF_ROWS * PLANES] !== frame_cycles)
                        $fatal(1, "Fotograma de %0d ciclos (se esperaban %0d)",
                               cycle - lat_cycle[lat_count - HALF_ROWS * PLANES], frame_cycles);
                end
                lat_count = lat_count + 1;
                pix_count = 0;
            end

            if (hub_lat && prev_lat) $fatal(1, "lat duro mas de un ciclo");

            // ---- direccion: solo cambia con los LEDs apagados ----
            if (addr !== prev_addr && hub_oe !== 1'b1)
                $fatal(1, "La direccion cambio con los LEDs encendidos");

            // ---- LEDs encendidos ----
            lat_idx = lat_count - 1;                 // fila ya guardada en el panel
            if (hub_oe === 1'b0) begin
                if (lat_count == 0) $fatal(1, "LEDs encendidos antes del primer latch");
                if (addr !== (lat_idx % HALF_ROWS)) $fatal(1, "Direccion incorrecta con LEDs encendidos");
                oe_low_cycles = oe_low_cycles + 1;
            end else if (prev_oe === 1'b0) begin
                // acaba de apagarse: comprobar cuanto tiempo estuvo encendido
                exp_t = T_BASE << ((lat_idx / HALF_ROWS) % PLANES);
                if (oe_low_cycles !== exp_t + 1)
                    $fatal(1, "LEDs encendidos %0d ciclos (se esperaban T+1 = %0d)", oe_low_cycles, exp_t + 1);
                oe_low_cycles = 0;

                if (lat_count == HALF_ROWS * PLANES * FRAMES) begin
                    $display("PASS: %0d fotogramas correctos, %0d ciclos por fotograma", FRAMES, frame_cycles);
                    $finish;
                end
            end

            prev_clk  = hub_clk;
            prev_lat  = hub_lat;
            prev_oe   = hub_oe;
            prev_addr = addr;
        end
    end

    // ---- archivo de ondas para GTKWave ----
    initial begin
        $dumpfile("hub75_tb.vcd");
        $dumpvars(0, hub75_tb);
    end

    // ---- seguridad: evita que la simulacion corra para siempre ----
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end

endmodule
