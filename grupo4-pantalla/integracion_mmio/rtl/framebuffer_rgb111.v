// ============================================================================
// FRAMEBUFFER_RGB111 - Memoria de imagen con doble banco (ping-pong)
// ============================================================================
// Cada píxel usa tres bits {R,G,B}: 8 colores. Cada cuadro tiene 64*64=4096
// píxeles; los dos bancos requieren 24576 bits útiles (3 KiB), sin sobrecarga.
//
// Dos RAM físicas/lógicas separadas por mitades para permitir dos lecturas
// simultáneas (una por mitad) más la escritura en la mitad seleccionada.
// Cada RAM: 4096 palabras de 3 bits = 2 bancos * 2048 píxeles por mitad.
//   Dirección de píxel [11:0] = {mitad, row[4:0], col[5:0]}.
//   Dirección interna de RAM = {banco, row[4:0], col[5:0]}.
//   mitad=0: filas 0..31; mitad=1: filas 32..63.
//   disp_bank selecciona lectura; ~disp_bank selecciona escritura.
//
// El software escribe un cuadro completo antes de START. El selector cambia
// solo al terminar un barrido (en perip_hub75_ctrl); no se copia memoria.
// No se borra la RAM al reset para facilitar inferencia de BSRAM. Hasta el
// primer swap, el control MMIO fuerza OE alto. No garantiza inicialización si
// el software publica un cuadro incompleto. La ocupación física se debe medir.
module framebuffer_rgb111 (
    input  wire        clk,
    // Banco visible actual, controlado por el handshake.
    input  wire        disp_bank,
    // Lecturas síncronas de los dos píxeles solicitados por el datapath.
    input  wire [11:0] addr_top, addr_bot,
    output reg  [2:0]  pix_top, pix_bot,
    // Escritura de un píxel por flanco cuando we=1; validada por el adaptador.
    input  wire        we,
    input  wire [11:0] waddr,
    input  wire [2:0]  wdata
);
    // Atributo de síntesis: solicita RAM de bloque, no garantiza su inferencia.
    (* ram_style = "block" *) reg [2:0] mem_top [0:4095];
    (* ram_style = "block" *) reg [2:0] mem_bot [0:4095];
    // Banco posterior siempre opuesto al visible; un cambio de disp_bank
    // intercambia ambos roles automáticamente.
    wire wr_bank = ~disp_bank;
    // Ambos puertos de lectura se actualizan cada flanco. Las asignaciones
    // no bloqueantes permiten al datapath capturar estos datos un ciclo después.
    always @(posedge clk) begin
        // El bit 11 selecciona RAM superior/inferior; los 11 inferiores
        // seleccionan el píxel dentro de la mitad. Solo se escribe una RAM.
        if (we && !waddr[11]) mem_top[{wr_bank, waddr[10:0]}] <= wdata;
        if (we &&  waddr[11]) mem_bot[{wr_bank, waddr[10:0]}] <= wdata;
        // Leer ambas mitades del banco visible. Durante el flanco de swap
        // aún se lee el banco anterior; S_READ deja que la nueva lectura
        // esté disponible antes de S_WAIT/load_rgb.
        pix_top <= mem_top[{disp_bank, addr_top[10:0]}];
        pix_bot <= mem_bot[{disp_bank, addr_bot[10:0]}];
    end
endmodule
