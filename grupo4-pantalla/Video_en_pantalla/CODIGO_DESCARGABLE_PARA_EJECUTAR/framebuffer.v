// framebuffer.v
// Memoria de imagen con DOBLE BUFFER y puerto de escritura.
//
//   - Cada pixel es RGB888 = {R[7:0], G[7:0], B[7:0]}.
//   - Hay DOS bancos (0 y 1): el panel lee de uno ('rd_bank') mientras el UART
//     escribe el siguiente cuadro en el otro ('wr_bank'). Asi nunca se ve un
//     cuadro a medias.
//   - La memoria se parte en mitad superior (mem_top) e inferior (mem_bot):
//     cada una tiene 1 puerto de lectura y 1 de escritura, que es lo que
//     ofrece la RAM del FPGA. (Una sola memoria necesitaria 3 puertos.)
//
// Direccion de lectura/escritura: {mitad, fila, columna}
//   mitad = 0 -> fila r       (mem_top)
//   mitad = 1 -> fila r + 32  (mem_bot)
// Dentro de cada memoria el indice es {banco, fila, columna}.
//
// La lectura es SINCRONA: la direccion en el ciclo N da el dato en el N+1.
module framebuffer #(
    parameter ADDR_W   = 12,                  // {mitad, fila, columna}
    parameter INIT_TOP = "image_top.hex",     // 4096 lineas: banco 0 (imagen) + banco 1 (negro)
    parameter INIT_BOT = "image_bot.hex"      // idem para la mitad inferior
) (
    input  wire              clk,

    // ---- lectura (la usa el datapath del panel) ----
    input  wire              rd_bank,
    input  wire [ADDR_W-1:0] addr_top,
    input  wire [ADDR_W-1:0] addr_bot,
    output reg  [23:0]       pix_top,
    output reg  [23:0]       pix_bot,

    // ---- escritura (la usa img_loader) ----
    input  wire              wr_bank,
    input  wire              we,
    input  wire [ADDR_W-1:0] waddr,
    input  wire [23:0]       wdata
);

    localparam HW = ADDR_W - 1;               // bits de {fila, columna}

    (* ram_style = "block" *) reg [23:0] mem_top [0:(1 << (HW + 1)) - 1];
    (* ram_style = "block" *) reg [23:0] mem_bot [0:(1 << (HW + 1)) - 1];

    // Los archivos .hex cubren la memoria COMPLETA (los dos bancos): las primeras
    // 2048 lineas son la imagen inicial (banco 0) y las ultimas 2048 son negro
    // (banco 1). Si solo se inicializara una parte, Yosys no podria usar la
    // BSRAM del FPGA y pasaria la memoria a LUTs, que no caben.
    // Tampoco se rellena con ceros antes: en Yosys eso sobreescribia $readmemh.
    initial begin
        if (INIT_TOP != "") $readmemh(INIT_TOP, mem_top);
        if (INIT_BOT != "") $readmemh(INIT_BOT, mem_bot);
    end

    always @(posedge clk) begin
        if (we && !waddr[ADDR_W-1]) mem_top[{wr_bank, waddr[HW-1:0]}] <= wdata;
        if (we &&  waddr[ADDR_W-1]) mem_bot[{wr_bank, waddr[HW-1:0]}] <= wdata;

        pix_top <= mem_top[{rd_bank, addr_top[HW-1:0]}];
        pix_bot <= mem_bot[{rd_bank, addr_bot[HW-1:0]}];
    end

endmodule
