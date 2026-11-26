// ============================================================================
// PERIP_HUB75 - Adaptador MMIO y módulo superior del periférico de pantalla G4
// ============================================================================
// Integra cuatro bloques: control MMIO, framebuffer, datapath y FSM de barrido.
// El procesador NO genera CLK, LAT, OE ni las direcciones A-E del panel: esos
// pines se gobiernan autónomamente mediante la FSM y el datapath.
//
// CONTRATO CON EL SoC (decodificador global externo):
//   cs_fb   = región 0x0048xxxx: escritura de píxeles (no admite lectura).
//   cs_ctrl = región 0x004Cxxxx: registros de configuración y estado.
//   addr[15:0] = desplazamiento EN BYTES dentro de la región seleccionada.
//   d_in/d_out: palabra de 32 bits; rd/wr: pulsos excluyentes de un ciclo.
//   CONTROL: 0x004C0000; STATUS: 0x004C0004; FRAMES: 0x004C0008.
//   Píxel (x,y): 0x00480000 + 4*(64*y+x), con RGB111 en d_in[2:0].
//   Último píxel: 0x00483FFC. El SoC debe filtrar accesos subpalabra:
//   este módulo no recibe mem_wmask ni implementa escrituras parciales.
//
// PROTOCOLO DE ACTUALIZACIÓN (software):
//   Esperar BUSY=0 -> llenar los 4096 píxeles del banco posterior ->
//   escribir CONTROL=3 (DISPLAY_EN=1, START=1) -> esperar DONE=1.
//   START pide intercambiar bancos, NO iniciar el barrido (ya es continuo).
//   Durante BUSY=1 se ignoran escrituras de píxeles; no hay ready/stall.
//   Las lecturas de control responden después de un flanco de clk.
//
// Se conserva el datapath y la FSM parametrizables del prototipo de video.
// Aquí se usa un solo plano de color (RGB111, 8 colores), no RGB888 real.
module perip_hub75 #(
    // Umbral del temporizador de iluminación en ciclos del reloj de la FPGA.
    // TIMER_W debe representar dicho umbral; el TB reduce T_BASE a 8.
    parameter T_BASE = 1024,
    parameter TIMER_W = 16
)(
    // Reloj común del SoC y reset síncrono activo en alto.
    input  wire clk, rst,
    // Selecciones de región generadas FUERA de este módulo.
    input  wire cs_fb, cs_ctrl,
    // Operación del bus y offset local de 16 bits, en bytes.
    input  wire rd, wr,
    input  wire [15:0] addr,
    input  wire [31:0] d_in,
    output wire [31:0] d_out,
    // Interfaz física HUB75: dos píxeles RGB, fila A-E, reloj, captura y OE.
    output wire r1, g1, b1, r2, g2, b2,
    output wire [4:0] hub_addr,
    output wire hub_clk, hub_lat, hub_oe
);
    // Estado interno del control MMIO y señal de fin de barrido proveniente de la FSM.
    // hub_oe_core: salida de la FSM; hub_oe: salida final tras las protecciones.
    wire busy, done, disp_bank, front_valid, display_en, frame_done, hub_oe_core;
    // Órdenes de la FSM al datapath: habilitar cargas, incrementar o reiniciar contadores.
    wire load_rgb, inc_col, clr_col, inc_row, clr_row;
    wire inc_plane, clr_plane, load_addr, clr_timer, inc_timer;
    // Condiciones que vuelven del datapath a la FSM (comparadores).
    wire col_last, row_last, plane_last, timer_done;
    // Direcciones de lectura de los dos píxeles de una misma columna.
    // El framebuffer devuelve solo 3 bits por píxel.
    wire [11:0] fb_addr_top, fb_addr_bot;
    wire [2:0] pix_top, pix_bot;
    // Adaptar RGB111 al puerto de 24 bits del datapath original: repetir cada
    // canal 8 veces (0x00 o 0xFF). No se añade profundidad de color real.
    // Con PLANES=1 el datapath siempre toma el bit 0 de cada canal.
    wire [23:0] pix_top_rgb888 = {{8{pix_top[2]}}, {8{pix_top[1]}}, {8{pix_top[0]}}};
    wire [23:0] pix_bot_rgb888 = {{8{pix_bot[2]}}, {8{pix_bot[1]}}, {8{pix_bot[0]}}};
    // Decodificación de offset: el control solo admite los primeros 32 bytes.
    // Si addr=0x0020, addr[4:0] sería 0x00; sel_ctrl evita ese alias.
    // El decodificador local descarta offsets distintos de 0,4,8.
    wire sel_ctrl = cs_ctrl && !cs_fb && (addr[15:5] == 11'd0);
    // Escritura de framebuffer: región correcta, solo escritura, sin reset
    // ni intercambio pendiente. Bits [15:14]=0 limitan el espacio a 16 KiB;
    // bits [1:0]=0 exigen alineación a palabras de 4 bytes.
    // addr[13:2] será el índice de píxel (0..4095), no una dirección en bytes.
    wire we = !rst && cs_fb && !cs_ctrl && wr && !rd && !busy &&
              (addr[15:14] == 2'b00) && (addr[1:0] == 2'b00);

    // 1. Control MMIO: registra DISPLAY_EN, BUSY, DONE, FRONT_VALID y FRAMES.
    // Decide disp_bank al recibir frame_done y protege la salida física OE.
    // La respuesta de lectura d_out procede únicamente de este bloque.
    perip_hub75_ctrl ctrl_mmio (
        .clk(clk), .rst(rst), .cs(sel_ctrl), .rd(rd), .wr(wr),
        .addr(addr[4:0]), .d_in(d_in), .d_out(d_out),
        .frame_done(frame_done), .hub_oe_core(hub_oe_core), .hub_oe_panel(hub_oe),
        .display_en(display_en), .busy(busy), .done(done),
        .disp_bank(disp_bank), .front_valid(front_valid)
    );

    // 2. Memoria: lectura del banco visible y escritura del banco opuesto.
    // d_in[2:0] contiene R,G,B; los otros 29 bits se descartan.
    framebuffer_rgb111 fb (
        .clk(clk), .disp_bank(disp_bank),
        .addr_top(fb_addr_top), .addr_bot(fb_addr_bot),
        .pix_top(pix_top), .pix_bot(pix_bot),
        .we(we), .waddr(addr[13:2]), .wdata(d_in[2:0])
    );

    // 3. Datapath: calcula direcciones, temporización y los seis bits RGB.
    // Parámetros explícitos para 64 columnas, 32 pares de filas y UN plano.
    // PW=1 permite representar plane=0 sin declarar un vector de ancho cero.
    hub75_datapath #(
        .COLS(64), .HALF_ROWS(32), .PLANES(1), .T_BASE(T_BASE),
        .TIMER_W(TIMER_W), .CW(6), .RW(5), .PW(1)
    ) datapath (
        .clk(clk), .rst(rst), .load_rgb(load_rgb), .inc_col(inc_col), .clr_col(clr_col),
        .inc_row(inc_row), .clr_row(clr_row), .inc_plane(inc_plane), .clr_plane(clr_plane),
        .load_addr(load_addr), .clr_timer(clr_timer), .inc_timer(inc_timer),
        .fb_addr_top(fb_addr_top), .fb_addr_bot(fb_addr_bot),
        .pix_top(pix_top_rgb888), .pix_bot(pix_bot_rgb888),
        .col_last(col_last), .row_last(row_last), .plane_last(plane_last), .timer_done(timer_done),
        .r1(r1), .g1(g1), .b1(b1), .r2(r2), .g2(g2), .b2(b2), .addr(hub_addr)
    );

    // 4. FSM: decide cuándo capturar RGB, emitir CLK/LAT/OE y avanzar.
    // frame_done marca el límite de un barrido y cierra el handshake MMIO.
    hub75_control controller (
        .clk(clk), .rst(rst), .col_last(col_last), .row_last(row_last),
        .plane_last(plane_last), .timer_done(timer_done), .load_rgb(load_rgb),
        .inc_col(inc_col), .clr_col(clr_col), .inc_row(inc_row), .clr_row(clr_row),
        .inc_plane(inc_plane), .clr_plane(clr_plane), .load_addr(load_addr),
        .clr_timer(clr_timer), .inc_timer(inc_timer),
        .hub_clk(hub_clk), .hub_lat(hub_lat), .hub_oe(hub_oe_core), .frame_done(frame_done)
    );
endmodule
