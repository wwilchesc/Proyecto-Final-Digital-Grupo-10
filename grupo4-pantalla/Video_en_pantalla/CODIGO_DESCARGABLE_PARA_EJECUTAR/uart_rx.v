// uart_rx.v
// Receptor UART 8N1 (8 bits de datos, sin paridad, 1 bit de parada).
//
// Idea: se espera el flanco de bajada del bit de inicio, se avanza media
// duracion de bit para quedar en el CENTRO del bit, y de ahi en adelante se
// muestrea una vez cada CLKS_PER_BIT ciclos. Los datos llegan LSB primero.
//
//   CLKS_PER_BIT = reloj / baudios   (27 MHz / 921600 = 29.3 -> 29)
module uart_rx #(
    parameter CLKS_PER_BIT = 29
) (
    input  wire       clk,
    input  wire       rx,        // linea serie (reposo = 1)
    output reg        valid,     // pulso de 1 ciclo: 'data' es un byte nuevo
    output reg  [7:0] data
);

    // La linea rx es asincrona respecto a clk: se pasa por 2 flip-flops
    // para evitar metaestabilidad antes de usarla.
    reg [1:0] sync = 2'b11;
    always @(posedge clk) sync <= {sync[0], rx};
    wire rxs = sync[1];

    localparam [1:0] S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;

    reg [1:0]  st   = S_IDLE;
    reg [15:0] cnt  = 16'd0;
    reg [2:0]  bitn = 3'd0;
    reg [7:0]  sh   = 8'd0;

    always @(posedge clk) begin
        valid <= 1'b0;
        case (st)
            S_IDLE: if (!rxs) begin                 // flanco de inicio
                cnt <= CLKS_PER_BIT / 2;
                st  <= S_START;
            end

            S_START: if (cnt == 0) begin            // centro del bit de inicio
                if (!rxs) begin
                    cnt  <= CLKS_PER_BIT - 1;
                    bitn <= 3'd0;
                    st   <= S_DATA;
                end else
                    st <= S_IDLE;                   // fue un glitch, no un inicio
            end else cnt <= cnt - 1'b1;

            S_DATA: if (cnt == 0) begin             // centro de cada bit de datos
                sh   <= {rxs, sh[7:1]};             // LSB primero
                cnt  <= CLKS_PER_BIT - 1;
                bitn <= bitn + 1'b1;
                if (bitn == 3'd7) st <= S_STOP;
            end else cnt <= cnt - 1'b1;

            S_STOP: if (cnt == 0) begin             // centro del bit de parada
                data  <= sh;
                valid <= 1'b1;
                st    <= S_IDLE;
            end else cnt <= cnt - 1'b1;
        endcase
    end

endmodule
