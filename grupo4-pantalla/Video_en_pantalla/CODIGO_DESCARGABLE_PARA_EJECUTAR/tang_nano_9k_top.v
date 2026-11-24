// tang_nano_9k_top.v
// Modulo superior ESPECIFICO de la placa Tang Nano 9K.
//   - Adapta pines: el boton S1 es activo en bajo, el reset de hub75_top es activo en alto.
//   - Recibe video del PC por el puente USB-UART de la placa (pin 18) y lo
//     escribe en el framebuffer.
// Los nombres de los puertos deben coincidir con los de tang_nano_9k.cst
module tang_nano_9k_top #(
    parameter BAUD = 921600,   // debe coincidir con --baud del script del PC
    parameter BPP  = 2         // 2 = RGB565 (rapido), 3 = RGB888 (colores completos)
) (
    input  wire       clk,       // reloj de 27 MHz (pin 52)
    input  wire       s1,        // boton S1: 1 = suelto, 0 = pulsado
    input  wire       uart_rx,   // desde el PC (pin 18, FPGA_RX del puente BL702)

    output wire       r1, g1, b1,    // HUB75: color mitad superior
    output wire       r2, g2, b2,    // HUB75: color mitad inferior
    output wire [4:0] addr,          // HUB75: A, B, C, D, E
    output wire       hub_clk,       // HUB75: CLK
    output wire       hub_lat,       // HUB75: LAT
    output wire       hub_oe         // HUB75: OE
);

    localparam CLK_HZ = 27_000_000;
    localparam CLKS_PER_BIT = (CLK_HZ + BAUD / 2) / BAUD;   // redondeado

    // ---- UART -> bytes ----
    wire       rx_valid;
    wire [7:0] rx_data;
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) rx (
        .clk(clk), .rx(uart_rx), .valid(rx_valid), .data(rx_data)
    );

    // ---- bytes -> pixeles ----
    wire        we, frame_start, frame_end;
    wire [11:0] waddr;
    wire [23:0] wdata;
    img_loader #(.BPP(BPP)) loader (
        .clk(clk), .rst(~s1),
        .valid(rx_valid), .data(rx_data),
        .we(we), .waddr(waddr), .wdata(wdata),
        .frame_start(frame_start), .frame_end(frame_end)
    );

    // ---- panel ----
    hub75_top #(
        .COLS      (64),
        .HALF_ROWS (32),
        .PLANES    (8),
        .T_BASE    (8),
        .INIT_TOP  ("image_top.hex"),
        .INIT_BOT  ("image_bot.hex")
    ) panel (
        .clk     (clk),
        .rst     (~s1),          // pulsar S1 = reset
        .we(we), .waddr(waddr), .wdata(wdata),
        .frame_start(frame_start), .frame_end(frame_end),
        .r1 (r1), .g1 (g1), .b1 (b1),
        .r2 (r2), .g2 (g2), .b2 (b2),
        .addr    (addr),
        .hub_clk (hub_clk),
        .hub_lat (hub_lat),
        .hub_oe  (hub_oe)
    );

endmodule
