// B.3 - Decodificador local MMIO de control HUB75E (propuesta verificable)
// Region del SoC reservada/propuesta: 0x004C_0000 (cs_ctrl externo).
// Contrato igual al de los periféricos del Grupo 1:
//   cs, rd, wr, addr[4:0], d_in[31:0], d_out[31:0] registrado a 1 ciclo.
// Se presupone que rd y wr son excluyentes y que addr es un offset EN BYTES.
//
// Tabla propuesta (pendiente acuerdo con Grupo 6):
// 0x00 CONTROL R/W bit0 DISPLAY_EN (reset = 1, comportamiento actual)
// 0x04 STATUS  R   bit0 DISPLAY_EN (solo estado elemental, NO BUSY/DONE)
// 0x08 FRAMES  R   contador de pulsos frame_done del motor de barrido
//
// NO IMPLEMENTA START/BUSY/DONE ni el framebuffer MMIO 0x0048_0000.
// frame_done debe ser generado por la FSM del panel e interconectado en
// una fase posterior; durante pruebas puede venir del testbench.
module perip_hub75_ctrl (
    input  wire        clk,
    input  wire        rst,
    input  wire        cs,
    input  wire        rd,
    input  wire        wr,
    input  wire [4:0]  addr,
    input  wire [31:0] d_in,
    output reg  [31:0] d_out,
    input  wire        frame_done,
    input  wire        hub_oe_core,
    output wire        hub_oe_panel,
    output wire        display_en
);
    localparam [4:0] A_CONTROL = 5'h00;
    localparam [4:0] A_STATUS  = 5'h04;
    localparam [4:0] A_FRAMES  = 5'h08;

    // B.3: decodificador combinacional local. Ninguna salida es registro.
    // Las operaciones simultaneas rd=wr=1 se ignoran (acceso invalido).
    wire bus_read  = cs && rd && !wr;
    wire bus_write = cs && wr && !rd;
    wire wr_control = bus_write && (addr == A_CONTROL);
    wire rd_control = bus_read  && (addr == A_CONTROL);
    wire rd_status  = bus_read  && (addr == A_STATUS);
    wire rd_frames  = bus_read  && (addr == A_FRAMES);

    // Registro de configuracion y contador de cuadros: elementos auxiliares
    // para hacer observable y comprobable la decodificacion.
    reg        r_display_en;
    reg [31:0] r_frames;

    assign display_en = r_display_en;
    // OE de HUB75 es activo en bajo: el cero habilita los LED.
    // Cuando DISPLAY_EN=0 forzamos un uno para mantenerlos apagados.
    assign hub_oe_panel = hub_oe_core | ~r_display_en;

    always @(posedge clk) begin
        if (rst) begin
            r_display_en <= 1'b1;  // mantiene la salida habilitable al arrancar
            r_frames     <= 32'd0;
        end else begin
            if (wr_control)
                r_display_en <= d_in[0];
            if (frame_done)
                r_frames <= r_frames + 32'd1;
        end
    end

    // Contrato de lectura registrada: dato valido DESPUES del flanco activo.
    // En direcciones desconocidas se lee cero. Las escrituras a RO se ignoran.
    always @(posedge clk) begin
        if (rst)
            d_out <= 32'd0;
        else if (rd_control)
            d_out <= {31'd0, r_display_en};
        else if (rd_status)
            d_out <= {31'd0, r_display_en};
        else if (rd_frames)
            d_out <= r_frames;
        else
            d_out <= 32'd0;
    end
endmodule
