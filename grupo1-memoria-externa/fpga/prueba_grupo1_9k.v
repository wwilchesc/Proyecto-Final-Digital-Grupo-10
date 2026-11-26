// prueba_grupo1_9k.v
// Prueba en placa del Grupo 1 (memoria externa) en la Tang Nano 9K: SPI con
// la Flash de 32 Mbit de la tarjeta e I2C con la EEPROM 24LC256, los dos a traves de memoria_externa.v
// y con las mismas senales del bus del FemtoRV32.
//
// Un secuenciador hace el papel de la CPU: recorre un programa de accesos al
// bus (escribir registro, leer registro, esperar BUSY = 0, esperar un tiempo)
// y al final manda un reporte por UART (115200 8N1) y enciende los LEDs:
//   led[0] = 1 si todas las pruebas del SPI pasaron
//   led[1] = 1 si todas las pruebas del I2C pasaron
// La prueba corre sola despues del reset y otra vez con cada pulsacion de
// btn_run_n. Cada corrida usa un byte de prueba distinto (0x5A + corrida).
//
// Pruebas del SPI: JEDEC ID; WREN y borrado del ultimo sector (0x3FF000);
// lectura de 3 bytes (FF FF FF); WREN y PAGE PROGRAM de un byte; lectura con
// MANTENER y el 4.o byte con CONTINUAR.
// Antes de todo se pone CLK_DIV = 67 en el I2C (99,3 kHz con 27 MHz).
// Pruebas del I2C: escritura de un byte en 0x0010 (ACK de cada byte) y
// lectura aleatoria con START repetido.
//
// Las instrucciones y el texto del reporte se generan desde una tabla; cada
// instruccion es {operacion, destino, usa_byte_de_prueba, direccion, dato}.

module prueba_grupo1_9k #(
    parameter CLK_HZ    = 27_000_000,      // reloj de la Tang Nano 9K (pin 52)
    parameter BAUD      = 115_200,
    parameter T_INICIO  = CLK_HZ / 10,       // 100 ms antes de la primera corrida
    parameter T_BORRAR  = CLK_HZ / 2,        // 500 ms: borrado de un sector
    parameter T_GRABAR  = CLK_HZ / 200,      // 5 ms: page program
    parameter T_EEPROM  = CLK_HZ / 1000 * 6, // 6 ms: ciclo de grabacion de la EEPROM
    parameter LED_ACTIVO_BAJO = 1            // los LEDs de la Tang Nano 9K encienden con 0
) (
    input  wire       clk,
    input  wire       btn_rst_n,    // boton de reset (activo en 0)
    input  wire       btn_run_n,    // boton para repetir la prueba (activo en 0)
    output wire       uart_tx,
    output wire [1:0] led,

    output wire       spi_sck,
    output wire       spi_mosi,
    output wire       spi_cs_n,
    input  wire       spi_miso,     // WP y HOLD de la Flash no llegan a la FPGA en la 9K

    inout  wire       i2c_scl,
    inout  wire       i2c_sda
);

    // ---------------- Reset y botones ----------------
    reg [2:0] rst_s = 3'b000, run_s = 3'b111;
    always @(posedge clk) begin
        rst_s <= {rst_s[1:0], btn_rst_n};
        run_s <= {run_s[1:0], btn_run_n};
    end
    wire rst = ~rst_s[2];

    // Antirrebote del boton de repetir: 10 ms estable en 0
    reg [19:0] db_cnt;
    reg        run_ok, run_q;
    always @(posedge clk) begin
        if (rst) begin db_cnt <= 0; run_ok <= 1'b0; run_q <= 1'b0; end
        else begin
            if (run_s[2]) db_cnt <= 0;
            else if (db_cnt != CLK_HZ / 100) db_cnt <= db_cnt + 1;
            run_ok <= (db_cnt == CLK_HZ / 100);
            run_q  <= run_ok;
        end
    end
    wire run_press = run_ok & ~run_q;

    // ---------------- Bloque del Grupo 1 ----------------
    reg  [31:0] mem_addr, mem_wdata;
    reg  [3:0]  mem_wmask;
    reg         mem_rstrb;
    wire [31:0] mem_rdata;
    wire        sel;
    wire        spi_wp_n, spi_hold_n;   // sin pin en la Tang Nano 9K

    memoria_externa u_mem (
        .clk(clk), .rst(rst),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wmask(mem_wmask),
        .mem_rstrb(mem_rstrb), .mem_rdata(mem_rdata), .sel(sel),
        .spi_sck(spi_sck), .spi_mosi(spi_mosi), .spi_cs_n(spi_cs_n),
        .spi_wp_n(spi_wp_n), .spi_hold_n(spi_hold_n), .spi_miso(spi_miso),
        .i2c_scl(i2c_scl), .i2c_sda(i2c_sda)
    );

    // ---------------- Programa de prueba ----------------
    localparam OP_WR = 3'd0, OP_RD = 3'd1, OP_WAIT = 3'd2, OP_DELAY = 3'd3, OP_END = 3'd4;
    localparam NPROG = 64;

    reg  [7:0]  pc;
    reg  [70:0] ins;
    always @(*) begin
        case (pc)
              0: ins = {3'd0, 3'd0, 1'b0, 32'h00460010, 32'h00000043};   // I2C: CLK_DIV = 67 -> SCL de 99,3 kHz con 27 MHz
              1: ins = {3'd0, 3'd0, 1'b0, 32'h00420000, 32'h00079F01};   // SPI: JEDEC ID (0x9F, sin direccion, 3 bytes)
              2: ins = {3'd2, 3'd0, 1'b0, 32'h00420010, 32'h00000000};
              3: ins = {3'd1, 3'd0, 1'b0, 32'h0042000C, 32'h00000000};
              4: ins = {3'd0, 3'd0, 1'b0, 32'h00420000, 32'h00010601};   // SPI: WREN (0x06)
              5: ins = {3'd2, 3'd0, 1'b0, 32'h00420010, 32'h00000000};
              6: ins = {3'd0, 3'd0, 1'b0, 32'h00420004, 32'h003FF000};   // SPI: borrar el ultimo sector de 4 KB (0x20 en 0x3FF000)
              7: ins = {3'd0, 3'd0, 1'b0, 32'h00420000, 32'h00002001};
              8: ins = {3'd2, 3'd0, 1'b0, 32'h00420010, 32'h00000000};
              9: ins = {3'd3, 3'd0, 1'b0, 32'h00000000, 32'h00000001};   // esperar el borrado
             10: ins = {3'd0, 3'd0, 1'b0, 32'h00420000, 32'h00060301};   // SPI: leer 3 bytes (deben ser FF FF FF)
             11: ins = {3'd2, 3'd0, 1'b0, 32'h00420010, 32'h00000000};
             12: ins = {3'd1, 3'd1, 1'b0, 32'h0042000C, 32'h00000000};
             13: ins = {3'd0, 3'd0, 1'b0, 32'h00420000, 32'h00010601};   // SPI: WREN y grabar el byte de prueba (0x02)
             14: ins = {3'd2, 3'd0, 1'b0, 32'h00420010, 32'h00000000};
             15: ins = {3'd0, 3'd0, 1'b1, 32'h00420008, 32'h00000000};
             16: ins = {3'd0, 3'd0, 1'b0, 32'h00420000, 32'h00000203};
             17: ins = {3'd2, 3'd0, 1'b0, 32'h00420010, 32'h00000000};
             18: ins = {3'd3, 3'd0, 1'b0, 32'h00000000, 32'h00000002};   // esperar la grabacion
             19: ins = {3'd0, 3'd0, 1'b0, 32'h00420000, 32'h000E0301};   // SPI: leer 3 bytes con MANTENER (CS sigue en 0)
             20: ins = {3'd2, 3'd0, 1'b0, 32'h00420010, 32'h00000000};
             21: ins = {3'd1, 3'd2, 1'b0, 32'h0042000C, 32'h00000000};
             22: ins = {3'd0, 3'd0, 1'b0, 32'h00420000, 32'h00120001};   // SPI: 4.o byte con CONTINUAR (sin comando ni direccion)
             23: ins = {3'd2, 3'd0, 1'b0, 32'h00420010, 32'h00000000};
             24: ins = {3'd1, 3'd3, 1'b0, 32'h0042000C, 32'h00000000};
             25: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000001};   // I2C: escribir el byte de prueba en 0x0010
             26: ins = {3'd2, 3'd0, 1'b0, 32'h0046000C, 32'h00000000};
             27: ins = {3'd0, 3'd0, 1'b0, 32'h00460004, 32'h000000A0};
             28: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000004};
             29: ins = {3'd2, 3'd4, 1'b0, 32'h0046000C, 32'h00000002};
             30: ins = {3'd0, 3'd0, 1'b0, 32'h00460004, 32'h00000000};
             31: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000004};
             32: ins = {3'd2, 3'd4, 1'b0, 32'h0046000C, 32'h00000002};
             33: ins = {3'd0, 3'd0, 1'b0, 32'h00460004, 32'h00000010};
             34: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000004};
             35: ins = {3'd2, 3'd4, 1'b0, 32'h0046000C, 32'h00000002};
             36: ins = {3'd0, 3'd0, 1'b1, 32'h00460004, 32'h00000000};
             37: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000004};
             38: ins = {3'd2, 3'd4, 1'b0, 32'h0046000C, 32'h00000002};
             39: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000002};
             40: ins = {3'd2, 3'd0, 1'b0, 32'h0046000C, 32'h00000000};
             41: ins = {3'd3, 3'd0, 1'b0, 32'h00000000, 32'h00000003};   // esperar el ciclo de grabacion de la EEPROM
             42: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000001};   // I2C: lectura aleatoria de 0x0010 con START repetido
             43: ins = {3'd2, 3'd0, 1'b0, 32'h0046000C, 32'h00000000};
             44: ins = {3'd0, 3'd0, 1'b0, 32'h00460004, 32'h000000A0};
             45: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000004};
             46: ins = {3'd2, 3'd5, 1'b0, 32'h0046000C, 32'h00000002};
             47: ins = {3'd0, 3'd0, 1'b0, 32'h00460004, 32'h00000000};
             48: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000004};
             49: ins = {3'd2, 3'd5, 1'b0, 32'h0046000C, 32'h00000002};
             50: ins = {3'd0, 3'd0, 1'b0, 32'h00460004, 32'h00000010};
             51: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000004};
             52: ins = {3'd2, 3'd5, 1'b0, 32'h0046000C, 32'h00000002};
             53: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000001};
             54: ins = {3'd2, 3'd0, 1'b0, 32'h0046000C, 32'h00000000};
             55: ins = {3'd0, 3'd0, 1'b0, 32'h00460004, 32'h000000A1};
             56: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000004};
             57: ins = {3'd2, 3'd5, 1'b0, 32'h0046000C, 32'h00000002};
             58: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000018};
             59: ins = {3'd2, 3'd0, 1'b0, 32'h0046000C, 32'h00000000};
             60: ins = {3'd0, 3'd0, 1'b0, 32'h00460000, 32'h00000002};
             61: ins = {3'd2, 3'd0, 1'b0, 32'h0046000C, 32'h00000000};
             62: ins = {3'd1, 3'd6, 1'b0, 32'h00460008, 32'h00000000};
             63: ins = {3'd4, 3'd0, 1'b0, 32'h00000000, 32'h00000000};
            default: ins = {OP_END, 3'd0, 1'b0, 32'h0, 32'h0};
        endcase
    end
    wire [2:0]  i_op   = ins[70:68];
    wire [2:0]  i_dest = ins[67:65];
    wire        i_v    = ins[64];
    wire [31:0] i_addr = ins[63:32];
    wire [31:0] i_data = ins[31:0];

    // ---------------- Resultados ----------------
    reg  [7:0]  run;                    // numero de corrida
    wire [7:0]  vv = 8'h5A + run;       // byte de prueba de esta corrida
    reg  [31:0] r0, r1, r2, r3, r4, r5, r6;

    wire ok_id     = (r0[23:0] != 24'h000000) && (r0[23:0] != 24'hFFFFFF);
    wire ok_borrar = (r1[23:0] == 24'hFFFFFF);
    wire ok_grabar = (r2[23:0] == {vv, 16'hFFFF});
    wire ok_cont   = (r3[7:0]  == 8'hFF);
    wire ok_ack    = !r4[1] && !r5[1];  // ACK_IN = 0 en todos los bytes
    wire ok_eeprom = (r6[7:0]  == vv);
    wire ok_spi    = ok_id && ok_borrar && ok_grabar && ok_cont;
    wire ok_i2c    = ok_ack && ok_eeprom;

    // ---------------- Secuenciador ----------------
    localparam S_INICIO = 3'd0, S_FETCH = 3'd1, S_BUS = 3'd2, S_CAP = 3'd3,
               S_DELAY = 3'd4, S_REPORTE = 3'd5, S_LISTO = 3'd6;
    reg [2:0]  st;
    reg [31:0] cnt;
    reg        mostrar;                 // LEDs con el resultado

    function [31:0] t_delay(input [1:0] k);
        case (k)
            2'd0: t_delay = T_INICIO;
            2'd1: t_delay = T_BORRAR;
            2'd2: t_delay = T_GRABAR;
            default: t_delay = T_EEPROM;
        endcase
    endfunction

    // UART y reporte
    localparam NREP = 448;
    reg  [9:0] ridx;
    reg        tx_go;
    wire       tx_busy;
    reg  [7:0] car;
    reg  [7:0] tx_byte;

    always @(posedge clk) begin
        if (rst) begin
            st <= S_INICIO; cnt <= 0; pc <= 0; run <= 0; mostrar <= 1'b0;
            mem_addr <= 0; mem_wdata <= 0; mem_wmask <= 0; mem_rstrb <= 1'b0;
            ridx <= 0; tx_go <= 1'b0; tx_byte <= 8'h20;
            r0 <= 0; r1 <= 0; r2 <= 0; r3 <= 0; r4 <= 0; r5 <= 0; r6 <= 0;
        end else begin
            mem_wmask <= 4'b0000;
            mem_rstrb <= 1'b0;
            tx_go     <= 1'b0;
            case (st)
                S_INICIO: begin
                    if (cnt == T_INICIO) begin
                        cnt <= 0; pc <= 0; r4 <= 0; r5 <= 0; mostrar <= 1'b0;
                        st  <= S_FETCH;
                    end else cnt <= cnt + 1;
                end

                S_FETCH: begin
                    case (i_op)
                        OP_WR: begin
                            mem_addr  <= i_addr;
                            mem_wdata <= i_v ? (i_data | {24'b0, vv}) : i_data;
                            mem_wmask <= 4'b1111;
                            st <= S_BUS;
                        end
                        OP_RD, OP_WAIT: begin
                            mem_addr  <= i_addr;
                            mem_rstrb <= 1'b1;
                            st <= S_BUS;
                        end
                        OP_DELAY: begin cnt <= 0; st <= S_DELAY; end
                        default: begin ridx <= 0; st <= S_REPORTE; end   // OP_END
                    endcase
                end

                S_BUS: st <= S_CAP;      // la lectura llega un ciclo despues

                S_CAP: begin
                    st <= S_FETCH;
                    case (i_op)
                        OP_RD: begin
                            case (i_dest)
                                3'd0: r0 <= mem_rdata;
                                3'd1: r1 <= mem_rdata;
                                3'd2: r2 <= mem_rdata;
                                3'd3: r3 <= mem_rdata;
                                default: r6 <= mem_rdata;
                            endcase
                            pc <= pc + 1;
                        end
                        OP_WAIT: begin
                            if (!mem_rdata[0]) begin            // BUSY = 0
                                if (i_dest == 3'd4) r4 <= r4 | (mem_rdata & i_data);
                                if (i_dest == 3'd5) r5 <= r5 | (mem_rdata & i_data);
                                pc <= pc + 1;
                            end                                  // si no, se vuelve a leer
                        end
                        default: pc <= pc + 1;                   // OP_WR
                    endcase
                end

                S_DELAY: begin
                    if (cnt == t_delay(i_data[1:0])) begin cnt <= 0; pc <= pc + 1; st <= S_FETCH; end
                    else cnt <= cnt + 1;
                end

                S_REPORTE: begin
                    if (ridx == NREP) begin
                        mostrar <= 1'b1;
                        st <= S_LISTO;
                    end else if (!tx_busy && !tx_go) begin
                        tx_go   <= 1'b1;
                        tx_byte <= car;
                        ridx    <= ridx + 1;
                    end
                end

                S_LISTO: begin
                    if (run_press) begin
                        run <= run + 1; pc <= 0; r4 <= 0; r5 <= 0; mostrar <= 1'b0;
                        st  <= S_FETCH;
                    end
                end

                default: st <= S_INICIO;
            endcase
        end
    end

    wire [1:0] led_on = mostrar ? {ok_i2c, ok_spi} : 2'b00;
    assign led = LED_ACTIVO_BAJO ? ~led_on : led_on;

    // ---------------- Texto del reporte ----------------
    function [7:0] hex(input [3:0] n);
        hex = (n < 4'd10) ? (8'h30 + n) : (8'h41 + n - 4'd10);
    endfunction

    function [7:0] okf(input ok, input [2:0] k);   // "OK   " o "FALLA"
        case (k)
            3'd0: okf = ok ? "O" : "F";
            3'd1: okf = ok ? "K" : "A";
            3'd2: okf = ok ? " " : "L";
            3'd3: okf = ok ? " " : "L";
            default: okf = ok ? " " : "A";
        endcase
    endfunction

    always @(*) begin
        case (ridx)
              0: car = 8'h0D;   // \r
              1: car = 8'h0A;   // \n
              2: car = 8'h3D;   // =
              3: car = 8'h3D;   // =
              4: car = 8'h3D;   // =
              5: car = 8'h20;   //  
              6: car = 8'h47;   // G
              7: car = 8'h72;   // r
              8: car = 8'h75;   // u
              9: car = 8'h70;   // p
             10: car = 8'h6F;   // o
             11: car = 8'h20;   //  
             12: car = 8'h31;   // 1
             13: car = 8'h20;   //  
             14: car = 8'h2D;   // -
             15: car = 8'h20;   //  
             16: car = 8'h6D;   // m
             17: car = 8'h65;   // e
             18: car = 8'h6D;   // m
             19: car = 8'h6F;   // o
             20: car = 8'h72;   // r
             21: car = 8'h69;   // i
             22: car = 8'h61;   // a
             23: car = 8'h20;   //  
             24: car = 8'h65;   // e
             25: car = 8'h78;   // x
             26: car = 8'h74;   // t
             27: car = 8'h65;   // e
             28: car = 8'h72;   // r
             29: car = 8'h6E;   // n
             30: car = 8'h61;   // a
             31: car = 8'h20;   //  
             32: car = 8'h7C;   // |
             33: car = 8'h20;   //  
             34: car = 8'h70;   // p
             35: car = 8'h72;   // r
             36: car = 8'h75;   // u
             37: car = 8'h65;   // e
             38: car = 8'h62;   // b
             39: car = 8'h61;   // a
             40: car = 8'h20;   //  
             41: car = 8'h65;   // e
             42: car = 8'h6E;   // n
             43: car = 8'h20;   //  
             44: car = 8'h70;   // p
             45: car = 8'h6C;   // l
             46: car = 8'h61;   // a
             47: car = 8'h63;   // c
             48: car = 8'h61;   // a
             49: car = 8'h20;   //  
             50: car = 8'h7C;   // |
             51: car = 8'h20;   //  
             52: car = 8'h63;   // c
             53: car = 8'h6F;   // o
             54: car = 8'h72;   // r
             55: car = 8'h72;   // r
             56: car = 8'h69;   // i
             57: car = 8'h64;   // d
             58: car = 8'h61;   // a
             59: car = 8'h20;   //  
             60: car = 8'h23;   // #
             61: car = hex(run[7:4]);
             62: car = hex(run[3:0]);
             63: car = 8'h20;   //  
             64: car = 8'h3D;   // =
             65: car = 8'h3D;   // =
             66: car = 8'h3D;   // =
             67: car = 8'h0D;   // \r
             68: car = 8'h0A;   // \n
             69: car = 8'h5B;   // [
             70: car = 8'h53;   // S
             71: car = 8'h50;   // P
             72: car = 8'h49;   // I
             73: car = 8'h5D;   // ]
             74: car = 8'h20;   //  
             75: car = 8'h4A;   // J
             76: car = 8'h45;   // E
             77: car = 8'h44;   // D
             78: car = 8'h45;   // E
             79: car = 8'h43;   // C
             80: car = 8'h20;   //  
             81: car = 8'h49;   // I
             82: car = 8'h44;   // D
             83: car = 8'h20;   //  
             84: car = 8'h28;   // (
             85: car = 8'h30;   // 0
             86: car = 8'h78;   // x
             87: car = 8'h39;   // 9
             88: car = 8'h46;   // F
             89: car = 8'h29;   // )
             90: car = 8'h20;   //  
             91: car = 8'h20;   //  
             92: car = 8'h20;   //  
             93: car = 8'h20;   //  
             94: car = 8'h20;   //  
             95: car = 8'h20;   //  
             96: car = 8'h20;   //  
             97: car = 8'h20;   //  
             98: car = 8'h20;   //  
             99: car = 8'h20;   //  
            100: car = 8'h20;   //  
            101: car = 8'h20;   //  
            102: car = 8'h20;   //  
            103: car = 8'h20;   //  
            104: car = 8'h20;   //  
            105: car = 8'h20;   //  
            106: car = 8'h20;   //  
            107: car = 8'h20;   //  
            108: car = 8'h3A;   // :
            109: car = 8'h20;   //  
            110: car = hex(r0[23:20]);
            111: car = hex(r0[19:16]);
            112: car = hex(r0[15:12]);
            113: car = hex(r0[11:8]);
            114: car = hex(r0[7:4]);
            115: car = hex(r0[3:0]);
            116: car = 8'h20;   //  
            117: car = 8'h20;   //  
            118: car = 8'h20;   //  
            119: car = okf(ok_id, 3'd0);
            120: car = okf(ok_id, 3'd1);
            121: car = okf(ok_id, 3'd2);
            122: car = okf(ok_id, 3'd3);
            123: car = okf(ok_id, 3'd4);
            124: car = 8'h0D;   // \r
            125: car = 8'h0A;   // \n
            126: car = 8'h5B;   // [
            127: car = 8'h53;   // S
            128: car = 8'h50;   // P
            129: car = 8'h49;   // I
            130: car = 8'h5D;   // ]
            131: car = 8'h20;   //  
            132: car = 8'h62;   // b
            133: car = 8'h6F;   // o
            134: car = 8'h72;   // r
            135: car = 8'h72;   // r
            136: car = 8'h61;   // a
            137: car = 8'h72;   // r
            138: car = 8'h20;   //  
            139: car = 8'h73;   // s
            140: car = 8'h65;   // e
            141: car = 8'h63;   // c
            142: car = 8'h74;   // t
            143: car = 8'h6F;   // o
            144: car = 8'h72;   // r
            145: car = 8'h20;   //  
            146: car = 8'h30;   // 0
            147: car = 8'h78;   // x
            148: car = 8'h33;   // 3
            149: car = 8'h46;   // F
            150: car = 8'h46;   // F
            151: car = 8'h30;   // 0
            152: car = 8'h30;   // 0
            153: car = 8'h30;   // 0
            154: car = 8'h20;   //  
            155: car = 8'h28;   // (
            156: car = 8'h30;   // 0
            157: car = 8'h78;   // x
            158: car = 8'h32;   // 2
            159: car = 8'h30;   // 0
            160: car = 8'h29;   // )
            161: car = 8'h20;   //  
            162: car = 8'h20;   //  
            163: car = 8'h20;   //  
            164: car = 8'h20;   //  
            165: car = 8'h3A;   // :
            166: car = 8'h20;   //  
            167: car = hex(r1[23:20]);
            168: car = hex(r1[19:16]);
            169: car = hex(r1[15:12]);
            170: car = hex(r1[11:8]);
            171: car = hex(r1[7:4]);
            172: car = hex(r1[3:0]);
            173: car = 8'h20;   //  
            174: car = 8'h20;   //  
            175: car = 8'h20;   //  
            176: car = okf(ok_borrar, 3'd0);
            177: car = okf(ok_borrar, 3'd1);
            178: car = okf(ok_borrar, 3'd2);
            179: car = okf(ok_borrar, 3'd3);
            180: car = okf(ok_borrar, 3'd4);
            181: car = 8'h0D;   // \r
            182: car = 8'h0A;   // \n
            183: car = 8'h5B;   // [
            184: car = 8'h53;   // S
            185: car = 8'h50;   // P
            186: car = 8'h49;   // I
            187: car = 8'h5D;   // ]
            188: car = 8'h20;   //  
            189: car = 8'h67;   // g
            190: car = 8'h72;   // r
            191: car = 8'h61;   // a
            192: car = 8'h62;   // b
            193: car = 8'h61;   // a
            194: car = 8'h72;   // r
            195: car = 8'h20;   //  
            196: car = hex(vv[7:4]);
            197: car = hex(vv[3:0]);
            198: car = 8'h20;   //  
            199: car = 8'h65;   // e
            200: car = 8'h6E;   // n
            201: car = 8'h20;   //  
            202: car = 8'h30;   // 0
            203: car = 8'h78;   // x
            204: car = 8'h33;   // 3
            205: car = 8'h46;   // F
            206: car = 8'h46;   // F
            207: car = 8'h30;   // 0
            208: car = 8'h30;   // 0
            209: car = 8'h30;   // 0
            210: car = 8'h20;   //  
            211: car = 8'h79;   // y
            212: car = 8'h20;   //  
            213: car = 8'h6C;   // l
            214: car = 8'h65;   // e
            215: car = 8'h65;   // e
            216: car = 8'h72;   // r
            217: car = 8'h20;   //  
            218: car = 8'h20;   //  
            219: car = 8'h20;   //  
            220: car = 8'h20;   //  
            221: car = 8'h20;   //  
            222: car = 8'h3A;   // :
            223: car = 8'h20;   //  
            224: car = hex(r2[23:20]);
            225: car = hex(r2[19:16]);
            226: car = hex(r2[15:12]);
            227: car = hex(r2[11:8]);
            228: car = hex(r2[7:4]);
            229: car = hex(r2[3:0]);
            230: car = 8'h20;   //  
            231: car = 8'h20;   //  
            232: car = 8'h20;   //  
            233: car = okf(ok_grabar, 3'd0);
            234: car = okf(ok_grabar, 3'd1);
            235: car = okf(ok_grabar, 3'd2);
            236: car = okf(ok_grabar, 3'd3);
            237: car = okf(ok_grabar, 3'd4);
            238: car = 8'h0D;   // \r
            239: car = 8'h0A;   // \n
            240: car = 8'h5B;   // [
            241: car = 8'h53;   // S
            242: car = 8'h50;   // P
            243: car = 8'h49;   // I
            244: car = 8'h5D;   // ]
            245: car = 8'h20;   //  
            246: car = 8'h34;   // 4
            247: car = 8'h2E;   // .
            248: car = 8'h6F;   // o
            249: car = 8'h20;   //  
            250: car = 8'h62;   // b
            251: car = 8'h79;   // y
            252: car = 8'h74;   // t
            253: car = 8'h65;   // e
            254: car = 8'h20;   //  
            255: car = 8'h63;   // c
            256: car = 8'h6F;   // o
            257: car = 8'h6E;   // n
            258: car = 8'h20;   //  
            259: car = 8'h4D;   // M
            260: car = 8'h41;   // A
            261: car = 8'h4E;   // N
            262: car = 8'h54;   // T
            263: car = 8'h45;   // E
            264: car = 8'h4E;   // N
            265: car = 8'h45;   // E
            266: car = 8'h52;   // R
            267: car = 8'h2B;   // +
            268: car = 8'h43;   // C
            269: car = 8'h4F;   // O
            270: car = 8'h4E;   // N
            271: car = 8'h54;   // T
            272: car = 8'h49;   // I
            273: car = 8'h4E;   // N
            274: car = 8'h55;   // U
            275: car = 8'h41;   // A
            276: car = 8'h52;   // R
            277: car = 8'h20;   //  
            278: car = 8'h20;   //  
            279: car = 8'h3A;   // :
            280: car = 8'h20;   //  
            281: car = hex(r3[7:4]);
            282: car = hex(r3[3:0]);
            283: car = 8'h20;   //  
            284: car = 8'h20;   //  
            285: car = 8'h20;   //  
            286: car = 8'h20;   //  
            287: car = 8'h20;   //  
            288: car = 8'h20;   //  
            289: car = 8'h20;   //  
            290: car = okf(ok_cont, 3'd0);
            291: car = okf(ok_cont, 3'd1);
            292: car = okf(ok_cont, 3'd2);
            293: car = okf(ok_cont, 3'd3);
            294: car = okf(ok_cont, 3'd4);
            295: car = 8'h0D;   // \r
            296: car = 8'h0A;   // \n
            297: car = 8'h5B;   // [
            298: car = 8'h49;   // I
            299: car = 8'h32;   // 2
            300: car = 8'h43;   // C
            301: car = 8'h5D;   // ]
            302: car = 8'h20;   //  
            303: car = 8'h6C;   // l
            304: car = 8'h61;   // a
            305: car = 8'h20;   //  
            306: car = 8'h45;   // E
            307: car = 8'h45;   // E
            308: car = 8'h50;   // P
            309: car = 8'h52;   // R
            310: car = 8'h4F;   // O
            311: car = 8'h4D;   // M
            312: car = 8'h20;   //  
            313: car = 8'h30;   // 0
            314: car = 8'h78;   // x
            315: car = 8'h35;   // 5
            316: car = 8'h30;   // 0
            317: car = 8'h20;   //  
            318: car = 8'h72;   // r
            319: car = 8'h65;   // e
            320: car = 8'h73;   // s
            321: car = 8'h70;   // p
            322: car = 8'h6F;   // o
            323: car = 8'h6E;   // n
            324: car = 8'h64;   // d
            325: car = 8'h65;   // e
            326: car = 8'h20;   //  
            327: car = 8'h41;   // A
            328: car = 8'h43;   // C
            329: car = 8'h4B;   // K
            330: car = 8'h20;   //  
            331: car = 8'h20;   //  
            332: car = 8'h20;   //  
            333: car = 8'h20;   //  
            334: car = 8'h20;   //  
            335: car = 8'h20;   //  
            336: car = 8'h3A;   // :
            337: car = 8'h20;   //  
            338: car = 8'h2D;   // -
            339: car = 8'h2D;   // -
            340: car = 8'h20;   //  
            341: car = 8'h20;   //  
            342: car = 8'h20;   //  
            343: car = 8'h20;   //  
            344: car = 8'h20;   //  
            345: car = 8'h20;   //  
            346: car = 8'h20;   //  
            347: car = okf(ok_ack, 3'd0);
            348: car = okf(ok_ack, 3'd1);
            349: car = okf(ok_ack, 3'd2);
            350: car = okf(ok_ack, 3'd3);
            351: car = okf(ok_ack, 3'd4);
            352: car = 8'h0D;   // \r
            353: car = 8'h0A;   // \n
            354: car = 8'h5B;   // [
            355: car = 8'h49;   // I
            356: car = 8'h32;   // 2
            357: car = 8'h43;   // C
            358: car = 8'h5D;   // ]
            359: car = 8'h20;   //  
            360: car = 8'h67;   // g
            361: car = 8'h72;   // r
            362: car = 8'h61;   // a
            363: car = 8'h62;   // b
            364: car = 8'h61;   // a
            365: car = 8'h72;   // r
            366: car = 8'h20;   //  
            367: car = hex(vv[7:4]);
            368: car = hex(vv[3:0]);
            369: car = 8'h20;   //  
            370: car = 8'h65;   // e
            371: car = 8'h6E;   // n
            372: car = 8'h20;   //  
            373: car = 8'h30;   // 0
            374: car = 8'h78;   // x
            375: car = 8'h30;   // 0
            376: car = 8'h30;   // 0
            377: car = 8'h31;   // 1
            378: car = 8'h30;   // 0
            379: car = 8'h20;   //  
            380: car = 8'h79;   // y
            381: car = 8'h20;   //  
            382: car = 8'h6C;   // l
            383: car = 8'h65;   // e
            384: car = 8'h65;   // e
            385: car = 8'h72;   // r
            386: car = 8'h20;   //  
            387: car = 8'h20;   //  
            388: car = 8'h20;   //  
            389: car = 8'h20;   //  
            390: car = 8'h20;   //  
            391: car = 8'h20;   //  
            392: car = 8'h20;   //  
            393: car = 8'h3A;   // :
            394: car = 8'h20;   //  
            395: car = hex(r6[7:4]);
            396: car = hex(r6[3:0]);
            397: car = 8'h20;   //  
            398: car = 8'h20;   //  
            399: car = 8'h20;   //  
            400: car = 8'h20;   //  
            401: car = 8'h20;   //  
            402: car = 8'h20;   //  
            403: car = 8'h20;   //  
            404: car = okf(ok_eeprom, 3'd0);
            405: car = okf(ok_eeprom, 3'd1);
            406: car = okf(ok_eeprom, 3'd2);
            407: car = okf(ok_eeprom, 3'd3);
            408: car = okf(ok_eeprom, 3'd4);
            409: car = 8'h0D;   // \r
            410: car = 8'h0A;   // \n
            411: car = 8'h52;   // R
            412: car = 8'h45;   // E
            413: car = 8'h53;   // S
            414: car = 8'h55;   // U
            415: car = 8'h4C;   // L
            416: car = 8'h54;   // T
            417: car = 8'h41;   // A
            418: car = 8'h44;   // D
            419: car = 8'h4F;   // O
            420: car = 8'h20;   //  
            421: car = 8'h20;   //  
            422: car = 8'h20;   //  
            423: car = 8'h53;   // S
            424: car = 8'h50;   // P
            425: car = 8'h49;   // I
            426: car = 8'h3A;   // :
            427: car = 8'h20;   //  
            428: car = okf(ok_spi, 3'd0);
            429: car = okf(ok_spi, 3'd1);
            430: car = okf(ok_spi, 3'd2);
            431: car = okf(ok_spi, 3'd3);
            432: car = okf(ok_spi, 3'd4);
            433: car = 8'h20;   //  
            434: car = 8'h20;   //  
            435: car = 8'h20;   //  
            436: car = 8'h49;   // I
            437: car = 8'h32;   // 2
            438: car = 8'h43;   // C
            439: car = 8'h3A;   // :
            440: car = 8'h20;   //  
            441: car = okf(ok_i2c, 3'd0);
            442: car = okf(ok_i2c, 3'd1);
            443: car = okf(ok_i2c, 3'd2);
            444: car = okf(ok_i2c, 3'd3);
            445: car = okf(ok_i2c, 3'd4);
            446: car = 8'h0D;   // \r
            447: car = 8'h0A;   // \n
            default: car = 8'h20;
        endcase
    end

    // ---------------- Transmisor UART (8N1) ----------------
    localparam DIV = CLK_HZ / BAUD;
    reg [15:0] bcnt;
    reg [3:0]  nbit;
    reg [9:0]  tsh = 10'h3FF;
    reg        tbusy;
    assign tx_busy = tbusy;
    assign uart_tx = tsh[0];

    always @(posedge clk) begin
        if (rst) begin
            tsh <= 10'h3FF; tbusy <= 1'b0; bcnt <= 0; nbit <= 0;
        end else if (tx_go && !tbusy) begin
            tsh <= {1'b1, tx_byte, 1'b0}; tbusy <= 1'b1; bcnt <= 0; nbit <= 0;
        end else if (tbusy) begin
            if (bcnt == DIV - 1) begin
                bcnt <= 0;
                tsh  <= {1'b1, tsh[9:1]};
                if (nbit == 4'd9) tbusy <= 1'b0;
                nbit <= nbit + 1;
            end else bcnt <= bcnt + 1;
        end
    end

endmodule
