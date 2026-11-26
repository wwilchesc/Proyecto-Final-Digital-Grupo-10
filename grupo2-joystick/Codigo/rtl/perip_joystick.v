// ============================================================================
// perip_joystick.v : Periférico de joystick (ADC MCP3008 por SPI) para FemtoRV32
// ----------------------------------------------------------------------------
// Actúa como puente autónomo entre el bus del procesador (32 bits) y el ADC
// externo MCP3008 (4 canales de 10 bits: J1_X, J1_Y, J2_X, J2_Y) + 2 botones.
//
// PUNTOS CLAVE DE DISEÑO:
//   - No bloquea a la CPU: la FSM muestrea en segundo plano y la CPU solo lee
//     los últimos valores guardados en los registros.
//   - SPI Modo 0 (CPOL=0, CPHA=0), MSB primero, 24 pulsos de reloj por canal.
//   - Frecuencia SPI = f_clk / (2 * CLKDIV). A 27 MHz con CLKDIV=10 -> 1,35 MHz
//     (límite máximo del MCP3008 alimentado a 3,3 V).
// ============================================================================
module perip_joystick #(
    // Divisor de reloj por defecto tras el reset (medio periodo = 10 ciclos = 370 ns)
    parameter CLKDIV_RESET = 8'd10
) (
    // --- Interfaz con el bus del SoC (FemtoRV32) ---
    input  wire        clk,        // Reloj del sistema (27 MHz en Tang Nano 9K)
    input  wire        rst,        // Reset síncrono, activo en alto
    input  wire [31:0] d_in,       // Dato que escribe la CPU
    input  wire        cs,         // Chip Select del decodificador (0x0043_0000)
    input  wire [4:0]  addr,       // Desplazamiento interno del registro (mem_addr[4:0])
    input  wire        rd,         // Habilitación de lectura desde la CPU
    input  wire        wr,         // Habilitación de escritura desde la CPU
    output reg  [31:0] d_out,      // Dato leído hacia la CPU (latencia de 1 ciclo)

    // --- Interfaz SPI física hacia el MCP3008 ---
    output reg         mcp_cs_n,   // Chip Select del ADC (activo en bajo)
    output reg         mcp_sck,    // Reloj SPI (SCLK)
    output reg         mcp_mosi,   // Datos hacia el ADC (DIN del MCP3008)
    input  wire        mcp_miso,   // Datos desde el ADC (DOUT del MCP3008)

    // --- Entradas físicas de los pulsadores SW de los joysticks ---
    input  wire [1:0]  btn_n       // btn_n[0]=J1, btn_n[1]=J2 (activos en bajo, asíncronos)
);

    // ------------------------------------------------------------------
    // 1. MAPA DE REGISTROS Y ALMACENAMIENTO INTERNO
    // ------------------------------------------------------------------
    // Direcciones alineadas cada 4 bytes (palabras de 32 bits en RISC-V).
    localparam [4:0] OFS_CTRL    = 5'h00; // R/W: bit0=ENABLE, bit1=START
    localparam [4:0] OFS_STATUS  = 5'h04; // R  : bit0=BUSY,   bit1=VALID
    localparam [4:0] OFS_J1_X    = 5'h08; // R  : Eje X Joystick 1 (CH0, 10 bits)
    localparam [4:0] OFS_J1_Y    = 5'h0C; // R  : Eje Y Joystick 1 (CH1, 10 bits)
    localparam [4:0] OFS_J2_X    = 5'h10; // R  : Eje X Joystick 2 (CH2, 10 bits)
    localparam [4:0] OFS_J2_Y    = 5'h14; // R  : Eje Y Joystick 2 (CH3, 10 bits)
    localparam [4:0] OFS_BUTTONS = 5'h18; // R  : Pulsadores sincronizados (1=presionado)
    localparam [4:0] OFS_CLKDIV  = 5'h1C; // R/W: Divisor dinámico de velocidad SPI

    reg        enable;       // 1 = barrido continuo de los 4 canales
    reg        start_req;    // 1 = dispara un único barrido y se autolimpia al terminar
    reg        valid;        // Pasa a 1 tras completar al menos un barrido completo
    reg  [7:0] clkdiv;       // Valor actual del divisor de reloj SPI
    reg  [9:0] j1x, j1y, j2x, j2y; // Última muestra de 10 bits (0..1023) por eje
    reg  [1:0] buttons;      // Estado estable e invertido de los botones (lógica positiva)
    reg  [1:0] btn_ff1, btn_ff2;   // Cadena de 2 flip-flops contra metaestabilidad

    // ------------------------------------------------------------------
    // 2. DEFINICIÓN DEL MOTOR SPI Y TRAMA DEL MCP3008
    // ------------------------------------------------------------------
    // Estados de la Máquina de Estados Finitos (FSM) que controla el bus SPI.
    localparam [2:0] S_IDLE  = 3'd0, // En reposo esperando ENABLE o START
                     S_SETUP = 3'd1, // Tiempo de establecimiento de CS antes del primer SCLK
                     S_BIT   = 3'd2, // Envío/recepción de los 24 pulsos de reloj SPI
                     S_END   = 3'd3, // Cierre de trama (CS=1) y guardado del canal
                     S_GAP   = 3'd4; // Pausa obligatoria entre conversiones (t_CSH)

    reg  [2:0]  st;          // Estado actual de la FSM
    reg  [1:0]  ch;          // Canal activo del MCP3008 (0=J1X, 1=J1Y, 2=J2X, 3=J2Y)
    reg  [7:0]  tick;        // Contador de ciclos de 27 MHz para medir medio periodo SPI
    reg  [4:0]  n;           // Contador de flancos de subida de SCLK generados (0..24)
    reg  [23:0] rx;          // Registro de desplazamiento donde entran los bits de MISO

    // Pulso que indica cuándo ha transcurrido medio periodo de SCLK (~370 ns).
    wire        tick_done = (tick == clkdiv - 8'd1);

    // IMPORTANTE — Trama de 24 bits exigida por el datasheet del MCP3008:
    //   Bits [23:16] = 8'h01     -> 7 ceros + bit de inicio '1' en el pulso 8
    //   Bit  [15]    = 1'b1      -> SGL/DIFF = 1 (lectura single-ended)
    //   Bits [14:12] = {1'b0,ch} -> Selección de canal D2=0, D1=ch[1], D0=ch[0]
    //   Bits [11:0]  = 12'd0     -> Relleno mientras el ADC devuelve el bit nulo y B9..B0
    wire [23:0] tx_w      = {8'h01, 1'b1, 1'b0, ch, 4'b0000, 8'h00};

    // Bandera BUSY para el registro STATUS: vale 1 siempre que la FSM no esté en reposo.
    wire busy = (st != S_IDLE);

    // ------------------------------------------------------------------
    // 3. BLOQUE PRINCIPAL SECUENCIAL (Reset, Bus Write, Botones y FSM SPI)
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            // Estado seguro tras reset: periférico apagado, ejes centrados (512)
            // y líneas SPI en reposo (CS en alto, SCK en bajo).
            enable    <= 1'b0;
            start_req <= 1'b0;
            valid     <= 1'b0;
            clkdiv    <= CLKDIV_RESET;
            j1x <= 10'd512; j1y <= 10'd512; j2x <= 10'd512; j2y <= 10'd512;
            buttons   <= 2'b00;
            btn_ff1   <= 2'b11;  // 11 = botones sueltos (activos en bajo)
            btn_ff2   <= 2'b11;
            st        <= S_IDLE;
            ch        <= 2'd0;
            tick      <= 8'd0;
            n         <= 5'd0;
            rx        <= 24'd0;
            mcp_cs_n  <= 1'b1;
            mcp_sck   <= 1'b0;
            mcp_mosi  <= 1'b0;
        end else begin
            // --------------------------------------------------------------
            // 3A. ESCRITURA DESDE EL BUS DE LA CPU
            // --------------------------------------------------------------
            // Solo los registros CTRL y CLKDIV admiten escritura.
            if (cs && wr) begin
                case (addr)
                    OFS_CTRL: begin
                        enable <= d_in[0];               // Activa/desactiva modo continuo
                        if (d_in[1]) start_req <= 1'b1;  // Dispara un barrido único
                    end
                    OFS_CLKDIV: clkdiv <= d_in[7:0];     // Cambia velocidad SPI al vuelo
                    default: ;
                endcase
            end

            // --------------------------------------------------------------
            // 3B. SINCRONIZADOR DE PULSADORES (Anti-metaestabilidad)
            // --------------------------------------------------------------
            // Pasa las señales externas asíncronas por dos flip-flops en serie
            // y las invierte para que la CPU lea 1 = presionado, 0 = suelto.
            btn_ff1 <= btn_n;
            btn_ff2 <= btn_ff1;
            buttons <= ~btn_ff2;

            // --------------------------------------------------------------
            // 3C. GENERADOR DE BASE DE TIEMPO (Medio periodo de SCLK)
            // --------------------------------------------------------------
            // Mantiene el contador en 0 en reposo y lo reinicia cada vez que
            // alcanza clkdiv-1 para marcar el ritmo de todos los estados SPI.
            if (st == S_IDLE || tick_done)
                tick <= 8'd0;
            else
                tick <= tick + 8'd1;

            // --------------------------------------------------------------
            // 3D. MÁQUINA DE ESTADOS FINITOS (FSM) DEL CONTROLADOR SPI
            // --------------------------------------------------------------
            case (st)
                // Reposo: arranca si ENABLE
