// ============================================================================
// PERIP_HUB75_CTRL - Decodificador local y registros de control del panel
// ============================================================================
// El SoC selecciona este bloque con cs. El módulo superior ya ha comprobado
// los bits altos del offset; aquí se reciben únicamente addr[4:0] (en bytes).
//
// MAPA DE REGISTROS (base 0x004C0000):
//   0x00 CONTROL R/W: bit 0 DISPLAY_EN; bit 1 START (orden al escribir 1).
//        START no se almacena; al leer CONTROL, bit 1 siempre vale cero.
//        CONTROL=3 habilita el panel y pide swap; CONTROL=0 lo deshabilita.
//        Toda escritura a CONTROL actualiza DISPLAY_EN, incluso si BUSY=1.
//   0x04 STATUS R: [3] FRONT_VALID, [2] DONE, [1] BUSY, [0] DISPLAY_EN.
//        FRONT_VALID indica que se completó al menos un swap desde reset;
//        NO certifica que el software haya escrito todos los píxeles.
//   0x08 FRAMES R: contador de barridos completos de la FSM (32 bits).
//        Cuenta incluso con el panel apagado; no cuenta solicitudes START.
//
// HANDSHAKE: START aceptado -> BUSY=1 y DONE=0 -> esperar frame_done ->
// invertir disp_bank, BUSY=0, DONE=1 y FRONT_VALID=1. DONE se mantiene hasta
// el siguiente START aceptado o reset. No se encolan órdenes adicionales.
// El barrido nunca espera al software; el software debe respetar BUSY.
module perip_hub75_ctrl (
    input  wire        clk, rst,
    input  wire        cs, rd, wr,
    input  wire [4:0]  addr,
    input  wire [31:0] d_in,
    output reg  [31:0] d_out,
    input  wire        frame_done,
    input  wire        hub_oe_core,
    output wire        hub_oe_panel,
    output wire        display_en,
    output reg         busy, done, disp_bank, front_valid
);
    // DECODIFICADOR COMBINACIONAL: compara las señales actuales, sin memoria.
    // rd y wr simultáneamente activos son una solicitud inválida.
    // Conserva las ecuaciones del decodificador local original.
    wire bus_read   = cs && rd && !wr;
    wire bus_write  = cs && wr && !rd;
    wire wr_control = bus_write && (addr == 5'h00);
    wire rd_control = bus_read  && (addr == 5'h00);
    wire rd_status  = bus_read  && (addr == 5'h04);
    wire rd_frames  = bus_read  && (addr == 5'h08);
    // Registros secuenciales: conservan su valor entre flancos de reloj.
    reg r_display_en;
    reg [31:0] r_frames;
    // START es una solicitud, no un bit persistente. Solo se acepta estando libre.
    // Si START coincide con frame_done y BUSY=0, queda pendiente para el
    // siguiente límite de barrido; las decisiones usan valores previos al flanco.
    wire start_req = wr_control && d_in[1] && !busy;

    assign display_en = r_display_en;
    // OE físico activo en bajo: 1 deshabilita los LED. Cualquiera de las
    // cuatro condiciones fuerza el apagado: FSM en blanking, DISPLAY_EN=0,
    // ningún banco publicado todavía o reset. FRONT_VALID no inicializa RAM.
    assign hub_oe_panel = hub_oe_core | ~r_display_en | ~front_valid | rst;

    // Actualización simultánea de todos los registros mediante <=.
    // Reset: banco visible 0, banco de escritura 1, sin cuadro válido ni swap.
    always @(posedge clk) begin
        if (rst) begin
            r_display_en <= 1'b1;
            r_frames <= 32'd0;
            busy <= 1'b0;
            done <= 1'b0;
            disp_bank <= 1'b0;
            front_valid <= 1'b0;
        end else begin
            // DISPLAY_EN modifica la visualización, pero no detiene la FSM.
            if (wr_control) r_display_en <= d_in[0];
            // Sumar una unidad por pulso de fin de barrido (desborda módulo 2^32).
            if (frame_done) r_frames <= r_frames + 32'd1;
            // Si ya había una solicitud y termina el barrido, realizar el swap.
            // Cambiar solo el selector evita copiar los 4096 píxeles de un banco a otro.
            // Un START durante BUSY=1 no inicia otro swap, ni siquiera en el
            // flanco que completa el anterior (DISPLAY_EN sí puede actualizarse).
            if (busy && frame_done) begin
                disp_bank <= ~disp_bank;
                busy <= 1'b0;
                done <= 1'b1;
                front_valid <= 1'b1;
            // Registrar la solicitud: el banco visible todavía no cambia.
            end else if (start_req) begin
                busy <= 1'b1;
                done <= 1'b0;
            end
        end
    end

    // MUX DE LECTURA REGISTRADO: en cada flanco selecciona el registro solicitado.
    // d_out contiene el valor anterior al flanco si un registro cambia a la vez.
    // Ejemplos STATUS (hex): 0x01 inicial; 0x03 primer swap pendiente;
    // 0x0D completado; 0x0B otro swap pendiente con imagen ya válida.
    // START se lee como cero; sin lectura válida, d_out vuelve a cero.
    always @(posedge clk) begin
        if (rst)              d_out <= 32'd0;
        else if (rd_control) d_out <= {31'd0, r_display_en};
        else if (rd_status)  d_out <= {28'd0, front_valid, done, busy, r_display_en};
        else if (rd_frames)  d_out <= r_frames;
        else                 d_out <= 32'd0;
    end
endmodule
