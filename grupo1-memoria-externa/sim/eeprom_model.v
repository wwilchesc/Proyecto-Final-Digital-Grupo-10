// eeprom_model.v
// Modelo de comportamiento de una EEPROM I2C 24LC256 (direccion 0x50,
// A2 = A1 = A0 = 0), SOLO para simulacion.
//   - escritura: START, 0xA0, dir alta, dir baja, datos..., STOP
//   - lectura aleatoria: START, 0xA0, dir alta, dir baja, START, 0xA1,
//     datos (el maestro responde ACK para seguir y NACK en el ultimo), STOP
//   - stretch_ns > 0: despues de cada ACK el modelo mantiene SCL en 0 ese
//     tiempo, para probar el estiramiento de reloj (SCL_WAIT)
// Muestrea SDA en la subida de SCL y cambia SDA en la bajada.

`timescale 1ns/1ps
module eeprom_model #(
    parameter MEM_BYTES = 1024
) (
    inout wire scl,
    inout wire sda
);
    reg sda_drv = 1'b0;   // 1 = baja SDA
    reg scl_drv = 1'b0;   // 1 = baja SCL (estiramiento)
    assign sda = sda_drv ? 1'b0 : 1'bz;
    assign scl = scl_drv ? 1'b0 : 1'bz;

    integer stretch_ns = 0;

    reg [7:0]  mem [0:MEM_BYTES-1];
    localparam S_IDLE = 0, S_DEV = 1, S_AH = 2, S_AL = 3, S_DW = 4, S_DR = 5;
    integer    st = S_IDLE;
    integer    k = 0;            // subidas de SCL dentro del byte (1 a 9)
    reg [7:0]  shreg, out;
    reg [14:0] addr = 0;
    reg        mack;
    integer    bytes_rx = 0;     // bytes recibidos con ACK (para el banco)

    wire scl_v = (scl !== 1'b0);
    wire sda_v = (sda !== 1'b0);

    integer i;
    initial for (i = 0; i < MEM_BYTES; i = i + 1) mem[i] = 8'hFF;

    // START y STOP: SDA cambia con SCL en 1
    always @(negedge sda) if (scl_v) begin
        st = S_DEV; k = 0; sda_drv = 1'b0;
    end
    always @(posedge sda) if (scl_v) begin
        st = S_IDLE; k = 0; sda_drv = 1'b0;
    end

    always @(posedge scl) if (st != S_IDLE) begin
        k = k + 1;
        if (st != S_DR && k <= 8) shreg = {shreg[6:0], sda_v};
        if (st == S_DR && k == 9) mack = sda_v;
    end

    reg stretch_req = 1'b0;
    always @(posedge stretch_req) begin
        scl_drv = 1'b1;
        #(stretch_ns);
        scl_drv = 1'b0;
        stretch_req = 1'b0;
    end

    always @(negedge scl) if (st != S_IDLE) begin
        if (st != S_DR) begin
            if (k == 8) begin                    // byte completo: decidir ACK
                case (st)
                    S_DEV: if (shreg[7:1] == 7'h50) sda_drv = 1'b1; else st = S_IDLE;
                    S_AH:  begin addr[14:8] = shreg[6:0]; sda_drv = 1'b1; end
                    S_AL:  begin addr[7:0]  = shreg;      sda_drv = 1'b1; end
                    S_DW:  begin mem[addr % MEM_BYTES] = shreg; addr = addr + 1; sda_drv = 1'b1; end
                endcase
                if (sda_drv) bytes_rx = bytes_rx + 1;
            end else if (k == 9) begin           // fin del ACK
                sda_drv = 1'b0;
                k = 0;
                if (stretch_ns > 0) stretch_req = 1'b1;
                case (st)
                    S_DEV: if (shreg[0]) begin
                               st = S_DR;
                               out = mem[addr % MEM_BYTES];
                               sda_drv = ~out[7];
                           end else st = S_AH;
                    S_AH:  st = S_AL;
                    S_AL:  st = S_DW;
                    default: ;
                endcase
            end
        end else begin                           // S_DR: el esclavo envia
            if (k >= 1 && k <= 7)
                sda_drv = ~out[7 - k];
            else if (k == 8)
                sda_drv = 1'b0;                  // soltar para el ACK del maestro
            else if (k == 9) begin
                k = 0;
                if (!mack) begin                 // ACK: siguiente byte
                    addr = addr + 1;
                    out  = mem[addr % MEM_BYTES];
                    sda_drv = ~out[7];
                end else
                    st = S_IDLE;                 // NACK: esperar STOP
            end
        end
    end
endmodule
