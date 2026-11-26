// ==========================================================
// i2s_transmitter.v - Transmisor I2S (Sintetizable)
// ==========================================================
module i2s_transmitter (
    input  wire        clk,          // Reloj 27 MHz (Tang Nano 9K)
    input  wire        rst,          // Reset activo en alto
    input  wire [15:0] sample_left,  // Muestra canal izquierdo (16 bits)
    input  wire [15:0] sample_right, // Muestra canal derecho (16 bits)
    output reg         bclk,         // Bit Clock (2.7 MHz)
    output reg         lrck,         // Word Select (42.1875 kHz)
    output reg         sdin          // Serial Data Out
);

    // 1. Divisor para BCLK: 27 MHz / 10 = 2.7 MHz (Conmuta cada 5 ciclos)
    reg [3:0] bclk_div;
    wire bclk_tick = (bclk_div == 4'd4);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bclk_div <= 4'd0;
            bclk     <= 1'b0;
        end else if (bclk_tick) begin
            bclk_div <= 4'd0;
            bclk     <= ~bclk;
        end else begin
            bclk_div <= bclk_div + 1'b1;
        end
    end

    // Detectar flanco de bajada de BCLK
    wire bclk_falling = (bclk_tick && (bclk == 1'b1));

    reg [4:0]  bit_cnt;
    reg [31:0] shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bit_cnt   <= 5'd31;
            lrck      <= 1'b1;
            sdin      <= 1'b0;      // Corregido: asignación binaria válida (1 bit en 0)
            shift_reg <= 32'd0;
        end else if (bclk_falling) begin
            if (bit_cnt == 5'd31) begin
                bit_cnt <= 5'd0;
                lrck    <= ~lrck; // Alterna canal Izquierdo (0) y Derecho (1)
                sdin    <= 1'b0;  // Retardo de 1 BCLK (Estándar I2S Philips)
                
                if (lrck == 1'b1)
                    shift_reg <= {sample_left, 16'd0};
                else
                    shift_reg <= {sample_right, 16'd0};
            end else begin
                bit_cnt   <= bit_cnt + 5'd1;
                sdin      <= shift_reg[31];
                shift_reg <= {shift_reg[30:0], 1'b0};
            end
        end
    end

endmodule
