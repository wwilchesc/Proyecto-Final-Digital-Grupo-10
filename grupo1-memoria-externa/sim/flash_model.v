// flash_model.v
// Modelo de comportamiento de una Flash SPI tipo W25Q64 (modo 0), SOLO para
// simulacion. Atiende los comandos que usa el proyecto:
//   0x9F  JEDEC ID          -> responde EF 40 17
//   0x03  READ (dir 24 bits)-> entrega bytes seguidos mientras CS_n = 0
//   0x06  WRITE ENABLE
//   0x02  PAGE PROGRAM      -> graba bytes (solo si se dio 0x06 antes)
//   0x05  READ STATUS 1     -> bit1 = WEL
//   0x20  SECTOR ERASE      -> deja la memoria del modelo en 0xFF (solo si
//                              se dio 0x06 antes)
// Muestrea MOSI en la subida de SCK y cambia MISO en la bajada (modo 0).

`timescale 1ns/1ps
module flash_model #(
    parameter MEM_BYTES = 256
) (
    input  wire sck,
    input  wire cs_n,
    input  wire mosi,
    output reg  miso
);
    reg [7:0]  mem [0:MEM_BYTES-1];
    reg [7:0]  cmd;
    reg [23:0] addr;
    reg [7:0]  in_byte;
    reg [7:0]  out_byte;
    integer    bit_cnt;      // bits recibidos desde que CS_n bajo
    integer    out_cnt;      // bits enviados del byte actual
    reg        wel;          // write enable latch
    reg        data_phase;   // ya paso comando (y direccion si aplica)

    integer i;
    initial begin
        for (i = 0; i < MEM_BYTES; i = i + 1) mem[i] = i[7:0] ^ 8'h5A;
        miso = 1'b0;
        wel  = 1'b0;
    end

    // Inicio de una transaccion
    always @(negedge cs_n) begin
        bit_cnt    = 0;
        out_cnt    = 0;
        data_phase = 1'b0;
        cmd        = 8'h00;
        addr       = 24'h0;
    end

    // Fin de una transaccion
    always @(posedge cs_n) begin
        if (cmd == 8'h02 || cmd == 8'h20) wel = 1'b0;   // grabar y borrar consumen WEL
        miso = 1'b0;
    end

    function [7:0] next_out;
        input dummy;
        begin
            case (cmd)
                8'h9F: case ((bit_cnt - 8) / 8)
                           0: next_out = 8'hEF;
                           1: next_out = 8'h40;
                           2: next_out = 8'h17;
                           default: next_out = 8'h00;
                       endcase
                8'h03: next_out = mem[addr % MEM_BYTES];
                8'h05: next_out = {6'b0, wel, 1'b0};
                default: next_out = 8'h00;
            endcase
        end
    endfunction

    // Subida de SCK: muestrear MOSI
    always @(posedge sck) if (!cs_n) begin
        in_byte = {in_byte[6:0], mosi};
        bit_cnt = bit_cnt + 1;

        if (bit_cnt == 8) begin
            cmd = in_byte;
            if (cmd == 8'h06) wel = 1'b1;
            if (cmd == 8'h9F || cmd == 8'h05) data_phase = 1'b1;
        end else if (bit_cnt > 8 && bit_cnt <= 32 &&
                     (cmd == 8'h03 || cmd == 8'h02 || cmd == 8'h20)) begin
            addr = {addr[22:0], mosi};
            if (bit_cnt == 32) data_phase = 1'b1;
            if (bit_cnt == 32 && cmd == 8'h20 && wel)
                for (i = 0; i < MEM_BYTES; i = i + 1) mem[i] = 8'hFF;
        end else if (bit_cnt > 32 && cmd == 8'h02 && ((bit_cnt - 32) % 8 == 0)) begin
            if (wel) mem[addr % MEM_BYTES] = in_byte;
            addr = addr + 1;
        end
    end

    // Bajada de SCK: poner el siguiente bit en MISO
    always @(negedge sck) if (!cs_n && data_phase &&
                              (cmd == 8'h9F || cmd == 8'h03 || cmd == 8'h05)) begin
        if (out_cnt == 0) out_byte = next_out(1'b0);
        miso     = out_byte[7];
        out_byte = {out_byte[6:0], 1'b0};
        out_cnt  = out_cnt + 1;
        if (out_cnt == 8) begin
            out_cnt = 0;
            if (cmd == 8'h03) addr = addr + 1;
        end
    end
endmodule
