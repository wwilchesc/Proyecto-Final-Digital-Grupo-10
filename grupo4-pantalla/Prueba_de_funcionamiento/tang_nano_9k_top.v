// tang_nano_9k_top.v
// Modulo superior ESPECIFICO de la placa Tang Nano 9K.
// Solo adapta pines: el boton S1 es activo en bajo, el reset de hub75_top es activo en alto.
// Los nombres de los puertos deben coincidir con los de constraints/tang_nano_9k.cst
module tang_nano_9k_top (
    input  wire       clk,       // reloj de 27 MHz (pin 52)
    input  wire       s1,        // boton S1: 1 = suelto, 0 = pulsado

    output wire       r1, g1, b1,    // HUB75: color mitad superior
    output wire       r2, g2, b2,    // HUB75: color mitad inferior
    output wire [4:0] addr,          // HUB75: A, B, C, D, E
    output wire       hub_clk,       // HUB75: CLK
    output wire       hub_lat,       // HUB75: LAT
    output wire       hub_oe         // HUB75: OE
);

    hub75_top #(
        .COLS      (64),
        .HALF_ROWS (32),
        .PLANES    (8),
        .T_BASE    (8),
        .INIT_FILE ("image.hex")
    ) panel (
        .clk     (clk),
        .rst     (~s1),          // pulsar S1 = reset
        .r1 (r1), .g1 (g1), .b1 (b1),
        .r2 (r2), .g2 (g2), .b2 (b2),
        .addr    (addr),
        .hub_clk (hub_clk),
        .hub_lat (hub_lat),
        .hub_oe  (hub_oe)
    );

endmodule
