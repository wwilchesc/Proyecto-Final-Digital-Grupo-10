module top_test_hw (
    input  wire clk,      // Reloj onboard 27 MHz (Pin 52)
    input  wire rst_n,    // Boton S1 (Pin 4)
    output wire bclk,     // Pin 35 -> BCLK del MAX98357A
    output wire lrck,     // Pin 36 -> LRC del MAX98357A
    output wire sdin      // Pin 37 -> DIN del MAX98357A
);

    // Sincronizador y retardo de encendido (Power-On Reset automatico)
    reg [15:0] por_cnt = 16'd0;
    wire por_done = (por_cnt == 16'hFFFF);

    always @(posedge clk) begin
        if (!rst_n)
            por_cnt <= 16'd0;
        else if (!por_done)
            por_cnt <= por_cnt + 16'd1;
    end

    wire rst = ~por_done;

    // ------------------------------------------------------------------
    // Secuenciador de prueba: reproduce los IDs 0..15 uno por uno, 1 vez
    // cada uno, y reinicia el ciclo al terminar el ID 15.
    // Cada ranura dura (duracion de la pista + 800 ms de silencio).
    // ------------------------------------------------------------------
    localparam [14:0] CLKS_PER_MS = 15'd26999; // 27000 ciclos - 1
    localparam [12:0] GAP_MS      = 13'd800;

    // Duracion total de cada pista en ms (suma de sus notas y silencios)
    function [12:0] song_ms;
        input [3:0] id;
        begin
            case (id)
                4'd0:    song_ms = 13'd3840; // Intro Pac-Man
                4'd1:    song_ms = 13'd82;   // Waka "wa"
                4'd2:    song_ms = 13'd454;  // Comer fantasma
                4'd3:    song_ms = 13'd2110; // Muerte Pac-Man
                4'd4:    song_ms = 13'd74;   // Snake arriba
                4'd5:    song_ms = 13'd160;  // Snake manzana
                4'd6:    song_ms = 13'd530;  // Snake inicio / nivel
                4'd7:    song_ms = 13'd720;  // Snake game over
                4'd8:    song_ms = 13'd74;   // Snake abajo
                4'd9:    song_ms = 13'd68;   // Snake izquierda
                4'd10:   song_ms = 13'd68;   // Snake derecha
                4'd11:   song_ms = 13'd82;   // Waka "ka"
                4'd12:   song_ms = 13'd640;  // Sirena
                4'd13:   song_ms = 13'd224;  // Fantasmas asustados
                4'd14:   song_ms = 13'd422;  // Fruta
                default: song_ms = 13'd470;  // 15: Vida extra / moneda
            endcase
        end
    endfunction

    reg [3:0]  id;        // pista actual
    reg [14:0] clk_cnt;   // divisor a 1 ms
    reg [12:0] ms_cnt;    // milisegundos transcurridos en la ranura
    reg        first;     // dispara la primera pista tras el reset
    reg        cs_pulse;  // pulso de escritura de 1 ciclo

    wire [12:0] slot_ms = song_ms(id) + GAP_MS;

    always @(posedge clk) begin
        if (rst) begin
            id       <= 4'd0;
            clk_cnt  <= 15'd0;
            ms_cnt   <= 13'd0;
            first    <= 1'b1;
            cs_pulse <= 1'b0;
        end else begin
            cs_pulse <= 1'b0;
            if (first) begin
                first    <= 1'b0;
                cs_pulse <= 1'b1;            // dispara ID 0
                clk_cnt  <= 15'd0;
                ms_cnt   <= 13'd0;
            end else if (clk_cnt == CLKS_PER_MS) begin
                clk_cnt <= 15'd0;
                if (ms_cnt == slot_ms - 13'd1) begin
                    ms_cnt   <= 13'd0;
                    id       <= id + 4'd1;   // 15 -> 0 (da la vuelta solo)
                    cs_pulse <= 1'b1;        // dispara la siguiente pista
                end else begin
                    ms_cnt <= ms_cnt + 13'd1;
                end
            end else begin
                clk_cnt <= clk_cnt + 15'd1;
            end
        end
    end

    // Comando: bit4 = play, bit5 = loop (0 = una sola vez), [3:0] = song_id
    wire [31:0] cmd = {26'd0, 2'b01, id};

    i2s_melody_peripheral #(
        .MEM_FILE("pacman_songs.mem")
    ) u_audio (
        .clk   (clk),
        .rst   (rst),
        .cs    (cs_pulse),
        .wr    (cs_pulse),
        .rd    (1'b0),
        .addr  (4'd0),
        .d_in  (cmd),
        .d_out (),
        .bclk  (bclk),
        .lrck  (lrck),
        .sdin  (sdin)
    );

endmodule
