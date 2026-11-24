`timescale 1ns/1ps

// Testbench de extremo a extremo: UART -> uart_rx -> img_loader -> framebuffer
// (doble banco) -> panel HUB75 de 64x64 completo.
//
// El "PC" de este testbench envia cuadros por la linea serie. Un observador
// comprueba CADA bit RGB que sale por los pines del panel y lo compara con
// el cuadro que deberia estar mostrandose en ese momento.
//
// Escenarios:
//   1. El panel muestra la imagen inicial (banco 0) mientras llega el cuadro A.
//   2. A se muestra completo (banco 1); luego llega B (banco 0).
//   3. Cuadro TRUNCADO (faltan bytes) + pausa > timeout + cuadro bueno D:
//      el truncado nunca debe mostrarse y D debe recibirse bien.
//   4. Dos cuadros SEGUIDOS sin pausa (E, F): se acepta un cambio transitorio
//      de un fotograma, pero el resultado final debe ser F, completo.
//
// Parametros (se pueden cambiar con -P en iverilog):
//   CLKS = ciclos por bit de UART      BPP = 2 (RGB565) o 3 (RGB888)
module video_tb;

    parameter CLKS    = 8;
    parameter BPP     = 2;
    parameter TIMEOUT = 20000;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rx_line = 1'b1;
    reg s_rst   = 1'b0;                  // reset activo en alto

    // ---------------- DUT: mismo cableado que tang_nano_9k_top ----------------
    wire       rx_valid;
    wire [7:0] rx_data;
    uart_rx #(.CLKS_PER_BIT(CLKS)) rx (.clk(clk), .rx(rx_line), .valid(rx_valid), .data(rx_data));

    wire        we, frame_start, frame_end;
    wire [11:0] waddr;
    wire [23:0] wdata;
    img_loader #(.BPP(BPP), .TIMEOUT_CLKS(TIMEOUT)) loader (
        .clk(clk), .rst(s_rst), .valid(rx_valid), .data(rx_data),
        .we(we), .waddr(waddr), .wdata(wdata),
        .frame_start(frame_start), .frame_end(frame_end));

    wire r1, g1, b1, r2, g2, b2, hub_clk, hub_lat, hub_oe;
    wire [4:0] addr;
    hub75_top #(.COLS(64), .HALF_ROWS(32), .PLANES(8), .T_BASE(8),
                .INIT_TOP(""), .INIT_BOT("")) dut (
        .clk(clk), .rst(s_rst),
        .we(we), .waddr(waddr), .wdata(wdata),
        .frame_start(frame_start), .frame_end(frame_end),
        .r1(r1), .g1(g1), .b1(b1), .r2(r2), .g2(g2), .b2(b2),
        .addr(addr), .hub_clk(hub_clk), .hub_lat(hub_lat), .hub_oe(hub_oe));

    // ---------------- modelo de lo esperado: {banco, indice 0..4095} ----------------
    reg [23:0] model [0:8191];
    integer i;
    initial begin
        #1;
        // Imagen inicial en el banco 0 (patron conocido)
        for (i = 0; i < 4096; i = i + 1) begin
            model[i] = i * 32'h35A7C1 + 32'h19B3D5;
            if (i < 2048) dut.fb.mem_top[i]        = model[i];
            else          dut.fb.mem_bot[i - 2048] = model[i];
        end
    end

    // ---------------- "PC": envio por UART ----------------
    task send_byte(input [7:0] b);
        integer k;
        begin
            rx_line = 1'b0;                       repeat (CLKS) @(negedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                rx_line = b[k];                   repeat (CLKS) @(negedge clk);
            end
            rx_line = 1'b1;                       repeat (CLKS) @(negedge clk);
        end
    endtask

    integer seed = 12345;
    reg [31:0] rnd;
    reg [4:0]  r5, b5;
    reg [5:0]  g6;
    reg [7:0]  r8, g8, b8;

    // Envia cabecera + 'npix' pixeles aleatorios. Si npix == 4096 el cuadro es
    // completo y se guarda en el modelo del banco 'bank'.
    task send_frame(input integer npix, input integer bank);
        integer p;
        begin
            send_byte(8'hAA);
            send_byte(8'h55);
            for (p = 0; p < npix; p = p + 1) begin
                rnd = $random(seed);
                if (BPP == 2) begin
                    r5 = rnd[15:11]; g6 = rnd[10:5]; b5 = rnd[4:0];
                    send_byte({r5, g6[5:3]});
                    send_byte({g6[2:0], b5});
                    r8 = (r5 << 3) | (r5 >> 2);
                    g8 = (g6 << 2) | (g6 >> 4);
                    b8 = (b5 << 3) | (b5 >> 2);
                end else begin
                    r8 = rnd[23:16]; g8 = rnd[15:8]; b8 = rnd[7:0];
                    send_byte(r8); send_byte(g8); send_byte(b8);
                end
                if (npix == 4096) model[bank * 4096 + p] = {r8, g8, b8};
            end
        end
    endtask

    // ---------------- observador del panel ----------------
    reg        check_en = 1'b0;     // el testbench lo activa en las fases estrictas
    reg        synced   = 1'b0;
    reg        fd_d     = 1'b0;
    reg        prev_clk = 1'b0, prev_lat = 1'b0;
    integer    cur_bank = 0;
    integer    lat_count = 0, pix_count = 0;
    integer    frames_checked = 0;
    integer    n_frame_end = 0;
    integer    exp_row, exp_plane;
    reg [23:0] et, eb;

    always @(posedge clk) begin
        fd_d <= dut.frame_done;
        if (frame_end) n_frame_end <= n_frame_end + 1;
    end

    always @(negedge clk) begin
        if (!check_en) synced = 1'b0;

        if (fd_d) begin                          // empieza un fotograma nuevo del panel
            if (synced) begin
                if (lat_count !== 256) $fatal(1, "Fotograma con %0d latches (se esperaban 256)", lat_count);
                frames_checked = frames_checked + 1;
            end
            synced    = check_en;
            lat_count = 0;
            pix_count = 0;
            cur_bank  = dut.disp_bank;
        end else if (synced) begin
            if (hub_clk && !prev_clk) begin
                exp_row   = lat_count % 32;
                exp_plane = lat_count / 32;
                et = model[cur_bank * 4096 + exp_row * 64 + pix_count];
                eb = model[cur_bank * 4096 + (exp_row + 32) * 64 + pix_count];
                if (r1 !== et[16 + exp_plane] || g1 !== et[8 + exp_plane] || b1 !== et[exp_plane] ||
                    r2 !== eb[16 + exp_plane] || g2 !== eb[8 + exp_plane] || b2 !== eb[exp_plane])
                    $fatal(1, "Pixel incorrecto: banco %0d fila %0d col %0d plano %0d (t=%0t)",
                           cur_bank, exp_row, pix_count, exp_plane, $time);
                pix_count = pix_count + 1;
            end
            if (hub_lat && !prev_lat) begin
                if (pix_count !== 64) $fatal(1, "lat tras %0d pulsos de CLK (se esperaban 64)", pix_count);
                lat_count = lat_count + 1;
                pix_count = 0;
            end
        end
        prev_clk = hub_clk;
        prev_lat = hub_lat;
    end

    // ---------------- guion de pruebas ----------------
    task wait_frames(input integer n);
        begin repeat (n) @(posedge dut.frame_done); end
    endtask

    // Espera a que el cuadro nuevo se muestre (banco 'b' en pantalla, sin pendientes)
    task wait_shown(input integer b);
        begin
            while (!(dut.pend === 1'b0 && dut.disp_bank === b[0])) @(posedge dut.frame_done);
        end
    endtask

    initial begin
        // reset inicial
        s_rst = 1'b1; repeat (4) @(negedge clk); s_rst = 1'b0;
        repeat (30) @(negedge clk);

        // 1) imagen inicial
        check_en = 1'b1;
        wait_frames(3);
        $display("[1] imagen inicial correcta (%0d fotogramas verificados)", frames_checked);

        // 2) cuadro A (banco 1), con el panel verificando la imagen inicial todo el tiempo
        send_frame(4096, 1);
        wait_shown(1);
        wait_frames(3);
        $display("[2] cuadro A mostrado correctamente (%0d fotogramas verificados)", frames_checked);

        // cuadro B (banco 0)
        send_frame(4096, 0);
        wait_shown(0);
        wait_frames(3);
        $display("[2] cuadro B mostrado correctamente (%0d fotogramas verificados)", frames_checked);

        // 3) cuadro truncado + pausa > timeout + cuadro bueno D
        send_frame(100, 1);
        repeat (TIMEOUT + 5000) @(negedge clk);
        wait_frames(2);
        if (dut.disp_bank !== 1'b0 || dut.pend !== 1'b0)
            $fatal(1, "El cuadro truncado llego a mostrarse");
        $display("[3] el cuadro truncado se descarto");
        send_frame(4096, 1);
        wait_shown(1);
        wait_frames(3);
        $display("[3] cuadro D (tras resincronizar) mostrado correctamente (%0d fotogramas verificados)", frames_checked);

        // 4) dos cuadros seguidos, sin pausa: la verificacion se pausa durante el envio
        check_en = 1'b0;
        send_frame(4096, 0);                     // E -> banco 0
        send_frame(4096, 1);                     // F -> banco 1 (el que quedara final)
        repeat (3) @(posedge dut.frame_done);
        check_en = 1'b1;
        wait_shown(1);
        wait_frames(3);
        $display("[4] tras dos cuadros seguidos queda F, completo (%0d fotogramas verificados)", frames_checked);

        // cuadros completos recibidos: A, B, D, E, F (el truncado no cuenta)
        if (n_frame_end !== 5) $fatal(1, "frame_end se emitio %0d veces (se esperaban 5)", n_frame_end);

        $display("PASS: video_tb (CLKS=%0d, BPP=%0d), %0d fotogramas del panel verificados bit a bit",
                 CLKS, BPP, frames_checked);
        $finish;
    end

    initial begin
        #4000000000;
        $fatal(1, "Timeout del testbench");
    end

endmodule
