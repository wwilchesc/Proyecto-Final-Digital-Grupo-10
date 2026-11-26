// ============================================================================
// Módulo: i2s_melody_peripheral.v
// Descripción: Periférico MMIO para FemtoRV con ROM externa ($readmemh),
//              secuenciador de melodías, sintetizador DDS y núcleo I2S TX.
// ============================================================================

module i2s_melody_peripheral #(
    parameter MEM_FILE = "pacman_songs.mem"
)(
    input  wire        clk,     // 27 MHz
    input  wire        rst,     // Síncrono activo alto
    // Bus MMIO (FemtoRV - Base 0x47_0000)
    input  wire        cs,
    input  wire        wr,
    input  wire        rd,
    input  wire [3:0]  addr,
    input  wire [31:0] d_in,
    output reg  [31:0] d_out,
    // Pines físicos hacia MAX98357A
    output wire        bclk,    // GPIO 35
    output wire        lrck,    // GPIO 36
    output wire        sdin     // GPIO 37
);

    // Amplitud segura para bocina de 8 ohms con MAX98357A (evita saturación)
    localparam signed [15:0] AMP_POS = 16'sh1800;
    localparam signed [15:0] AMP_NEG = -16'sh1800;

    // ------------------------------------------------------------------------
    // Memoria ROM externa cargada desde pacman_songs.mem
    // ------------------------------------------------------------------------
    reg [31:0] song_rom [0:255];

    initial begin
        $readmemh(MEM_FILE, song_rom);
    end

    // ------------------------------------------------------------------------
    // Registros de Control MMIO
    // Offset 0x0 (addr[3:2] == 2'b00):
    //   Escritura: [3:0] song_id | [4] start_pulse | [5] loop_en | [6] stop
    //   Lectura:   {30'd0, song_playing, tx_busy}
    // ------------------------------------------------------------------------
    reg [3:0] song_id;
    reg       loop_en;
    reg       cmd_play;
    reg       cmd_stop;

    always @(posedge clk) begin
        if (rst) begin
            song_id  <= 4'd0;
            loop_en  <= 1'b0;
            cmd_play <= 1'b0;
            cmd_stop <= 1'b0;
        end else begin
            cmd_play <= 1'b0;
            cmd_stop <= 1'b0;

            if (cs && wr && (addr[3:2] == 2'b00)) begin
                song_id  <= d_in[3:0];
                loop_en  <= d_in[5];
                cmd_play <= d_in[4];
                cmd_stop <= d_in[6];
            end
        end
    end

    // ------------------------------------------------------------------------
    // Secuenciador de Partituras y Generador de Muestras PCM (42.1875 kHz)
    // ------------------------------------------------------------------------
    localparam [2:0] SEQ_IDLE       = 3'd0,
                     SEQ_FETCH_PTR  = 3'd1,
                     SEQ_WAIT_PTR   = 3'd2,
                     SEQ_FETCH_NOTE = 3'd3,
                     SEQ_WAIT_NOTE  = 3'd4,
                     SEQ_PLAY_NOTE  = 3'd5;

    reg [2:0]  seq_state;
    reg [7:0]  rom_addr;
    reg [31:0] rom_data;

    // Lectura síncrona de ROM (infiere BSRAM en Gowin Tang Nano)
    always @(posedge clk) begin
        rom_data <= song_rom[rom_addr];
    end

    // Parámetros de la nota activa
    reg [15:0] half_period;     // Semiperíodo en muestras (42.1875 kHz)
    reg [15:0] half_cnt;        // Contador de semiperíodo
    reg        wave_sign;       // Polaridad de onda cuadrada
    reg [23:0] dur_samples_rem; // Muestras restantes de la nota actual

    // Señales hacia el núcleo I2S TX
    wire        tx_busy;
    wire        tx_done;
    reg         tx_start;
    wire [15:0] pcm_sample;

    // Si half_period == 0 (silencio) o en reposo, envía 0; si no, onda cuadrada
    assign pcm_sample = (seq_state != SEQ_PLAY_NOTE || half_period == 16'd0) ? 16'd0 :
                        (wave_sign ? AMP_POS : AMP_NEG);

    // 1 ms a 42.1875 kHz equivale aproximadamente a 42 muestras
    wire [23:0] note_total_samples = rom_data[15:0] * 24'd42;

    always @(posedge clk) begin
        if (rst || cmd_stop) begin
            seq_state       <= SEQ_IDLE;
            rom_addr        <= 8'd0;
            half_period     <= 16'd0;
            half_cnt        <= 16'd0;
            wave_sign       <= 1'b0;
            dur_samples_rem <= 24'd0;
            tx_start        <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            case (seq_state)
                SEQ_IDLE: begin
                    if (cmd_play) begin
                        rom_addr  <= {4'd0, song_id}; // Busca vector en 0x00..0x0F
                        seq_state <= SEQ_FETCH_PTR;
                    end
                end

                SEQ_FETCH_PTR: begin
                    // Ciclo de latencia de lectura síncrona de ROM
                    seq_state <= SEQ_WAIT_PTR;
                end

                SEQ_WAIT_PTR: begin
                    // rom_data[7:0] contiene la dirección base de la melodía
                    rom_addr  <= rom_data[7:0];
                    seq_state <= SEQ_FETCH_NOTE;
                end

                SEQ_FETCH_NOTE: begin
                    seq_state <= SEQ_WAIT_NOTE;
                end

                SEQ_WAIT_NOTE: begin
                    if (rom_data == 32'hFFFF_FFFF) begin
                        // Fin de melodía encontrado
                        if (loop_en) begin
                            rom_addr  <= {4'd0, song_id};
                            seq_state <= SEQ_FETCH_PTR;
                        end else begin
                            seq_state <= SEQ_IDLE;
                        end
                    end else begin
                        // Carga nueva nota: [31:16] semiperiodo, [15:0] ms
                        half_period     <= rom_data[31:16];
                        half_cnt        <= 16'd0;
                        wave_sign       <= 1'b1;
                        dur_samples_rem <= note_total_samples;
                        seq_state       <= SEQ_PLAY_NOTE;
                    end
                end

                SEQ_PLAY_NOTE: begin
                if (cmd_play) begin
                    tx_start  <= 1'b0;
                    rom_addr  <= {4'd0, song_id};
                    seq_state <= SEQ_FETCH_PTR;
                end else begin
                    tx_start <= 1'b1;

                    // Cuando el TX avisa que capturó/terminó trama, prepara la siguiente muestra
                    if (tx_done) begin
                        if (half_period != 16'd0) begin
                            if (half_cnt >= half_period - 16'd1) begin
                                half_cnt  <= 16'd0;
                                wave_sign <= ~wave_sign;
                            end else begin
                                half_cnt <= half_cnt + 16'd1;
                            end
                        end

                        if (dur_samples_rem <= 24'd1) begin
                            tx_start  <= 1'b0;
                            rom_addr  <= rom_addr + 8'd1;
                            seq_state <= SEQ_FETCH_NOTE;
                        end else begin
                            dur_samples_rem <= dur_samples_rem - 24'd1;
                        end
                    end
                end
            end

                default: seq_state <= SEQ_IDLE;
            endcase
        end
    end

    // Lectura MMIO para que FemtoRV consulte si sigue sonando
    wire song_playing = (seq_state != SEQ_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            d_out <= 32'd0;
        end else if (cs && rd) begin
            d_out <= {30'd0, song_playing, tx_busy};
        end
    end

    // Instancia del núcleo transmisor I2S (Control + Datapath)
    i2s_tx_core u_i2s_core (
        .clk      (clk),
        .rst      (rst),
        .tx_start (tx_start),
        .data_in  (pcm_sample),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done),
        .bclk     (bclk),
        .lrck     (lrck),
        .sdin     (sdin)
    );

endmodule
