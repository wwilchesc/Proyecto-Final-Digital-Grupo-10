// img_loader.v
// Recibe cuadros de video por UART y los escribe en el framebuffer.
//
// Protocolo (el PC envia, byte a byte):
//     0xAA 0x55  +  4096 pixeles, fila por fila (fila 0 primero, 64 columnas)
//
//   BPP = 2 -> cada pixel son 2 bytes RGB565:
//               byte 1 = {R[4:0], G[5:3]}   byte 2 = {G[2:0], B[4:0]}
//   BPP = 3 -> cada pixel son 3 bytes: R, G, B (RGB888)
//
// El contador de pixeles 'idx' (0..4095) coincide con y*64 + x, que es
// justo la direccion {mitad, fila, columna} del framebuffer.
//
// Resincronizacion: si en medio de un cuadro pasan TIMEOUT_CLKS ciclos sin
// recibir ningun byte, se descarta el cuadro a medias y se vuelve a buscar
// la cabecera. Por eso el PC debe dejar una pausa mayor que ese tiempo
// entre un cuadro y el siguiente (el script ya lo hace).
module img_loader #(
    parameter BPP          = 2,
    parameter TIMEOUT_CLKS = 540000        // 20 ms a 27 MHz (maximo 2^20 - 1)
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,              // byte nuevo desde uart_rx
    input  wire [7:0]  data,

    output reg         we,                 // escribir 'wdata' en 'waddr'
    output reg  [11:0] waddr,              // {mitad, fila, columna}
    output reg  [23:0] wdata,              // {R8, G8, B8}
    output reg         frame_start,        // pulso: empieza un cuadro valido
    output reg         frame_end           // pulso: el cuadro llego completo
);

    localparam [1:0] S_SYNC0 = 2'd0,       // esperando 0xAA
                     S_SYNC1 = 2'd1,       // esperando 0x55
                     S_PIX   = 2'd2;       // recibiendo pixeles

    reg [1:0]  st   = S_SYNC0;
    reg [1:0]  n    = 2'd0;                // numero de byte dentro del pixel
    reg [7:0]  b0   = 8'd0, b1 = 8'd0;
    reg [11:0] idx  = 12'd0;
    reg [19:0] idle = 20'd0;               // ciclos sin recibir bytes

    // ---- ensamblado del pixel ----
    // RGB565 -> RGB888 repitiendo los bits altos en los bajos (31 -> 255)
    wire [4:0]  r5 = b0[7:3];
    wire [5:0]  g6 = {b0[2:0], data[7:5]};
    wire [4:0]  b5 = data[4:0];
    wire [23:0] px565 = {r5, r5[4:2], g6, g6[5:4], b5, b5[4:2]};
    wire [23:0] px888 = {b0, b1, data};
    wire [23:0] px    = (BPP == 2) ? px565 : px888;

    always @(posedge clk) begin
        we          <= 1'b0;
        frame_start <= 1'b0;
        frame_end   <= 1'b0;

        // contador de inactividad (se detiene al llegar al limite)
        if (valid)                    idle <= 20'd0;
        else if (idle != TIMEOUT_CLKS) idle <= idle + 1'b1;

        if (rst) begin
            st <= S_SYNC0;
        end else if (valid) begin
            case (st)
                S_SYNC0: if (data == 8'hAA) st <= S_SYNC1;

                S_SYNC1: if (data == 8'h55) begin
                             st          <= S_PIX;
                             n           <= 2'd0;
                             idx         <= 12'd0;
                             frame_start <= 1'b1;
                         end else if (data != 8'hAA)
                             st <= S_SYNC0;      // (AA AA 55 tambien sincroniza)

                S_PIX: begin
                    if (n == BPP - 1) begin      // ultimo byte: el pixel esta completo
                        we    <= 1'b1;
                        waddr <= idx;
                        wdata <= px;
                        n     <= 2'd0;
                        idx   <= idx + 1'b1;
                        if (idx == 12'd4095) begin
                            st        <= S_SYNC0;
                            frame_end <= 1'b1;
                        end
                    end else begin
                        if (n == 2'd0) b0 <= data;
                        else           b1 <= data;
                        n <= n + 1'b1;
                    end
                end

                default: st <= S_SYNC0;
            endcase
        end else if (idle == TIMEOUT_CLKS && st != S_SYNC0) begin
            st <= S_SYNC0;                       // cuadro a medias: descartar
        end
    end

endmodule
