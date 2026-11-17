// framebuffer.v
// Memoria con la imagen. Cada posicion guarda un pixel RGB888 = {R[7:0], G[7:0], B[7:0]}.
//
// Se leen DOS pixeles a la vez (mitad superior e inferior del panel), por eso
// hay dos direcciones y dos salidas.
//
// La lectura es SINCRONA: si la direccion se presenta en el ciclo N, el dato
// aparece en el ciclo N+1. Esa es la razon del estado WAIT en la FSM.
//
// Organizacion de la direccion: {mitad, fila, columna}
//   mitad = 0 -> fila  r        (pix_top)
//   mitad = 1 -> fila  r + 32   (pix_bot)
module framebuffer #(
    parameter ADDR_W    = 12,           // 2^12 = 4096 pixeles (64 x 64)
    parameter INIT_FILE = "image.hex"   // archivo con un pixel por linea, en hexadecimal
) (
    input  wire              clk,
    input  wire [ADDR_W-1:0] addr_top,
    input  wire [ADDR_W-1:0] addr_bot,
    output reg  [23:0]       pix_top,
    output reg  [23:0]       pix_bot
);

    reg [23:0] mem [0:(1 << ADDR_W) - 1];

    // Se carga la imagen directamente, sin rellenar antes con ceros:
    // en Yosys el bucle de ceros sobreescribia $readmemh y la memoria
    // quedaba vacia (panel apagado).
    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) begin
        pix_top <= mem[addr_top];
        pix_bot <= mem[addr_bot];
    end

endmodule
