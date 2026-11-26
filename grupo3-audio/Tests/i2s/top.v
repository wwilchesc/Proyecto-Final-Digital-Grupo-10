// ==========================================================
// top.v - Generador de Melodía I2S en Verilog para Tang Nano 9K
// ==========================================================
module top (
    input  wire clk,           // Reloj nativo 27 MHz (Pin 52)
    output wire bclk,          // Bit Clock (Pin 35)
    output wire lrck,          // Word Select (Pin 36)
    output wire sdin,          // Serial Data (Pin 37)
    output wire led_heartbeat  // LED 1 de la Tang Nano (Pin 10)
);

    // 1. Auto-Reset de Encendido (Power-On Reset)
    reg [7:0] por_cnt = 8'd0;
    wire rst = (por_cnt != 8'hFF);
    always @(posedge clk) begin
        if (rst) por_cnt <= por_cnt + 1'b1;
    end

    // 2. Parpadeo del LED 1 (~0.8 Hz) para monitorear funcionamiento
    reg [24:0] heartbeat_cnt = 25'd0;
    always @(posedge clk) heartbeat_cnt <= heartbeat_cnt + 1'b1;
    assign led_heartbeat = ~heartbeat_cnt[24];

    // 3. Temporizador a frecuencia de muestreo de audio (fs ≈ 42.1875 kHz)
    reg lrck_d;
    always @(posedge clk) lrck_d <= lrck;
    wire sample_tick = (lrck && !lrck_d);

    // ------------------------------------------------------
    // 4. Tablas de Frecuencias de Notas (Valores de semi-período)
    // ------------------------------------------------------
    localparam P_OFF = 7'd0;   // Silencio
    localparam P_G4  = 7'd54;  // Sol4 (~392 Hz)
    localparam P_C5  = 7'd40;  // Do5  (~523 Hz)
    localparam P_E5  = 7'd32;  // Mi5  (~659 Hz)
    localparam P_G5  = 7'd27;  // Sol5 (~784 Hz)

    // ------------------------------------------------------
    // 5. ROM de Melodía (Secuenciador de 12 pasos)
    // ------------------------------------------------------
    reg [3:0] note_idx;
    reg [6:0] current_period;
    reg [3:0] current_dur;

    always @(*) begin
        case (note_idx)
            4'd0:  begin current_period = P_E5;  current_dur = 4'd1; end // Mi5 (125 ms)
            4'd1:  begin current_period = P_OFF; current_dur = 4'd1; end // Silencio
            4'd2:  begin current_period = P_E5;  current_dur = 4'd1; end // Mi5
            4'd3:  begin current_period = P_OFF; current_dur = 4'd1; end // Silencio
            4'd4:  begin current_period = P_E5;  current_dur = 4'd1; end // Mi5
            4'd5:  begin current_period = P_OFF; current_dur = 4'd1; end // Silencio
            4'd6:  begin current_period = P_C5;  current_dur = 4'd1; end // Do5
            4'd7:  begin current_period = P_E5;  current_dur = 4'd2; end // Mi5 (250 ms)
            4'd8:  begin current_period = P_G5;  current_dur = 4'd3; end // Sol5 (375 ms)
            4'd9:  begin current_period = P_OFF; current_dur = 4'd3; end // Silencio
            4'd10: begin current_period = P_G4;  current_dur = 4'd3; end // Sol4 (375 ms)
            4'd11: begin current_period = P_OFF; current_dur = 4'd4; end // Pausa entre repeticiones
            default: begin current_period = P_OFF; current_dur = 4'd1; end
        endcase
    end

    // ------------------------------------------------------
    // 6. Contador de Tiempo de Nota (Tempo = 125 ms por unidad)
    // ------------------------------------------------------
    // 42187.5 Hz * 0.125 s = 5273 muestras por unidad de tempo
    reg [12:0] sample_cnt;
    reg [3:0]  dur_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sample_cnt <= 13'd0;
            dur_cnt    <= 4'd1;
            note_idx   <= 4'd0;
        end else if (sample_tick) begin
            if (sample_cnt == 13'd5272) begin
                sample_cnt <= 13'd0;
                if (dur_cnt >= current_dur) begin
                    dur_cnt  <= 4'd1;
                    note_idx <= (note_idx == 4'd11) ? 4'd0 : note_idx + 4'd1;
                end else begin
                    dur_cnt <= dur_cnt + 4'd1;
                end
            end else begin
                sample_cnt <= sample_cnt + 13'd1;
            end
        end
    end

    // ------------------------------------------------------
    // 7. Generador de Onda para la Nota Activa
    // ------------------------------------------------------
    reg [6:0] tone_cnt;
    reg       tone_state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tone_cnt   <= 7'd0;
            tone_state <= 1'b0;
        end else if (sample_tick) begin
            if (current_period == P_OFF) begin
                tone_cnt   <= 7'd0;
                tone_state <= 1'b0;
            end else if (tone_cnt >= (current_period - 1'b1)) begin
                tone_cnt   <= 7'd0;
                tone_state <= ~tone_state;
            end else begin
                tone_cnt <= tone_cnt + 7'd1;
            end
        end
    end

    // Muestra de audio de 16 bits en complemento a dos
    wire [15:0] audio_sample = (tone_state && current_period != P_OFF) ? 16'sh4000 : 
                               (!tone_state && current_period != P_OFF) ? 16'shC000 : 16'sh0000;

    // Transmisor I2S Instanciado
    i2s_transmitter u_i2s (
        .clk(clk),
        .rst(rst),
        .sample_left(audio_sample),
        .sample_right(audio_sample),
        .bclk(bclk),
        .lrck(lrck),
        .sdin(sdin)
    );

endmodule
