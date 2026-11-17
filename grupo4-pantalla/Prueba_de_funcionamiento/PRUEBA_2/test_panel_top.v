// test_panel_top.v
// Prueba MINIMA del panel HUB75 64x64 en Tang Nano 9K.
// No usa framebuffer, ni image.hex, ni la FSM del proyecto: solo envia
// un patron fijo para comprobar cableado, alimentacion y panel.
//
// Patron: TODOS los pixeles en ROJO (solo canal R), para consumir poca corriente
// y no sobrecargar una fuente de 5 V / 3 A. Para otro color cambia COLOR_MASK:
//   3'b100 = rojo, 3'b010 = verde, 3'b001 = azul, 3'b111 = blanco (consume mucho)
//
// Usa los mismos nombres de puerto que tang_nano_9k.cst.
module test_panel_top #(
    parameter [2:0] COLOR_MASK = 3'b111,   // {R, G, B}
    parameter       ON_TICKS   = 200       // tiempo de encendido por fila (ticks de 148 ns)
) (
    input  wire       clk,       // 27 MHz
    input  wire       s1,        // boton S1: 1 = suelto, 0 = pulsado (reset)

    output wire       r1, g1, b1,
    output wire       r2, g2, b2,
    output reg  [4:0] addr,
    output reg        hub_clk,
    output reg        hub_lat,
    output reg        hub_oe
);

    // Color fijo en las dos mitades del panel
    assign r1 = COLOR_MASK[2];
    assign g1 = COLOR_MASK[1];
    assign b1 = COLOR_MASK[0];
    assign r2 = COLOR_MASK[2];
    assign g2 = COLOR_MASK[1];
    assign b2 = COLOR_MASK[0];

    // Un "tick" cada 4 ciclos de reloj (6,75 MHz): CLK_P queda a ~1,7 MHz
    reg [1:0] div = 2'd0;
    wire tick = (div == 2'd3);
    always @(posedge clk) div <= div + 2'd1;

    localparam [2:0] SH_HI  = 3'd0,   // CLK = 1
                     SH_CHK = 3'd1,   // CLK = 0, cuenta columnas
                     LAT    = 3'd2,   // fin de LAT, pone direccion
                     ON     = 3'd3,   // OE = 0
                     ONW    = 3'd4;   // espera tiempo de encendido

    reg [2:0]  st  = SH_HI;
    reg [6:0]  n   = 7'd0;      // pulsos de CLK ya dados en la fila
    reg [15:0] t   = 16'd0;
    reg [4:0]  row = 5'd0;

    initial begin
        addr    = 5'd0;
        hub_clk = 1'b0;
        hub_lat = 1'b0;
        hub_oe  = 1'b1;       // LEDs apagados
    end

    always @(posedge clk) begin
        if (!s1) begin
            st      <= SH_HI;
            n       <= 7'd0;
            t       <= 16'd0;
            row     <= 5'd0;
            addr    <= 5'd0;
            hub_clk <= 1'b0;
            hub_lat <= 1'b0;
            hub_oe  <= 1'b1;
        end else if (tick) begin
            case (st)
                // Sube CLK: el panel toma el pixel actual
                SH_HI: begin
                    hub_clk <= 1'b1;
                    n       <= n + 7'd1;
                    st      <= SH_CHK;
                end

                // Baja CLK. Si ya van 64 pulsos, da el pulso de LAT
                SH_CHK: begin
                    hub_clk <= 1'b0;
                    if (n == 7'd64) begin
                        n       <= 7'd0;
                        hub_lat <= 1'b1;
                        st      <= LAT;
                    end else begin
                        st <= SH_HI;
                    end
                end

                // Termina LAT y pone la fila (con los LEDs aun apagados)
                LAT: begin
                    hub_lat <= 1'b0;
                    addr    <= row;
                    st      <= ON;
                end

                // Enciende los LEDs
                ON: begin
                    hub_oe <= 1'b0;
                    t      <= 16'd0;
                    st     <= ONW;
                end

                // Espera y apaga; pasa a la fila siguiente
                ONW: begin
                    if (t == ON_TICKS) begin
                        hub_oe <= 1'b1;
                        row    <= row + 5'd1;
                        st     <= SH_HI;
                    end else begin
                        t <= t + 16'd1;
                    end
                end

                default: st <= SH_HI;
            endcase
        end
    end

endmodule
