// ============================================================================
// tb_perip_joystick.v : Banco de pruebas (Testbench) para perip_joystick
// ----------------------------------------------------------------------------
// Este archivo NO se sintetiza en la FPGA; solo corre en simulación (Icarus).
// Simula simultáneamente:
//   1. Al procesador FemtoRV32 escribiendo y leyendo registros por el bus.
//   2. Al conversor ADC externo MCP3008 respondiendo por protocolo SPI Modo 0.
//   3. A los pulsadores físicos de los joysticks (activos en bajo).
// ============================================================================

// Define la unidad de tiempo de simulación (1 ns) y su precisión mínima (1 ps).
// Así, un retardo como #200 equivale exactamente a 200 nanosegundos.
`timescale 1ns/1ps

// El módulo de un testbench no tiene puertos de entrada/salida porque genera sus propios estímulos internos.
module tb_perip_joystick;

    // ------------------------------------------------------------------
    // 1. DECLARACIÓN DE SEÑALES DE CONEXIÓN AL PERIFÉRICO
    // ------------------------------------------------------------------
    // Las ENTRADAS del módulo bajo prueba (DUT) se declaran como 'reg'
    // porque el testbench les asignará valores dentro de bloques procedurales.
    reg         clk = 0;         // Reloj del sistema (inicia en 0)
    reg         rst = 1;         // Reset activo en alto (inicia en reset)
    reg  [31:0] d_in = 0;        // Bus de datos que la "CPU" escribe al periférico
    reg         cs = 0;          // Chip Select: selecciona este periférico
    reg         rd = 0, wr = 0;  // Señales de lectura y escritura del bus
    reg  [4:0]  addr = 0;        // Dirección interna del registro (0x00 a 0x1C)
    reg  [1:0]  btn_n = 2'b11;   // Pulsadores J1 y J2 (11 = ambos sin presionar)

    // Las SALIDAS del módulo bajo prueba se declaran como 'wire'
    // porque solo son observadas/leídas por el testbench.
    wire [31:0] d_out;           // Dato de 32 bits devuelto hacia la "CPU"
    wire        mcp_cs_n;        // Chip Select SPI hacia el MCP3008 (activo en 0)
    wire        mcp_sck;         // Reloj SPI generado por el periférico (1,35 MHz)
    wire        mcp_mosi;        // Datos enviados del periférico al MCP3008
    wire        mcp_miso;        // Datos devueltos del MCP3008 al periférico

    // Arreglo de 4 registros de 10 bits (0..1023) que simulan el voltaje
    // analógico digitalizado de cada potenciómetro del joystick (CH0..CH3).
    reg [9:0] canal [0:3];

    // ------------------------------------------------------------------
    // 2. INSTANCIACIÓN DEL DUT (Device Under Test)
    // ------------------------------------------------------------------
    // Conecta el módulo real 'perip_joystick' con los cables del testbench.
    perip_joystick dut (
        .clk(clk), .rst(rst), .d_in(d_in), .cs(cs), .addr(addr),
        .rd(rd), .wr(wr), .d_out(d_out),
        .mcp_cs_n(mcp_cs_n), .mcp_sck(mcp_sck), .mcp_mosi(mcp_mosi),
        .mcp_miso(mcp_miso), .btn_n(btn_n)
    );

    // ------------------------------------------------------------------
    // 3. GENERADOR DE RELOJ (27 MHz)
    // ------------------------------------------------------------------
    // Invierte 'clk' cada 18.5 ns -> periodo total = 37 ns -> ~27.02 MHz,
    // replicando el oscilador físico de la Tang Nano 9K.
    always #18.5 clk = ~clk;

    // ------------------------------------------------------------------
    // 4. MODELO CONDUCTUAL DEL ADC MCP3008 (Esclavo SPI Modo 0)
    // ------------------------------------------------------------------
    // Emula cómo se comporta el chip físico MCP3008 ante una trama de 24 bits.
    integer   k;                 // Contador de flancos de subida de SCLK (1..24)
    reg       d1, d0;            // Bits del número de canal recibidos por MOSI
    reg [9:0] val;               // Valor de 10 bits seleccionado del arreglo 'canal'
    reg       miso_r;            // Registro interno que maneja la línea MISO
    assign mcp_miso = miso_r;    // Conecta el registro interno al cable mcp_miso

    // Cuando el maestro baja CS (inicia una conversión SPI), reinicia la cuenta.
    always @(negedge mcp_cs_n) begin
        k = 0;
        miso_r = 0;
    end

    // En SPI Modo 0, el esclavo muestrea MOSI en cada FLANCO DE SUBIDA de SCLK.
    // En la trama de 24 pulsos:
    //   Pulso 8 = bit de inicio (1), Pulso 9 = SGL (1), Pulso 10 = D2 (0),
    //   Pulso 11 = D1, Pulso 12 = D0.
    always @(posedge mcp_sck) begin
        if (!mcp_cs_n) begin
            k = k + 1;
            if (k == 11) d1 = mcp_mosi;       // Captura bit MSB del canal (D1)
            if (k == 12) begin
                d0  = mcp_mosi;               // Captura bit LSB del canal (D0)
                val = canal[{d1, d0}];        // Busca el dato simulado del canal
            end
        end
    end

    // El MCP3008 actualiza su salida DOUT (MISO) en cada FLANCO DE BAJADA de SCLK
    // para que el dato esté estable cuando el maestro lo lea en el siguiente flanco de subida.
    always @(negedge mcp_sck) begin
        if (!mcp_cs_n) begin
            // Tras el flanco k=14 (bit nulo), saca B9 (val[9]) para el pulso 15;
            // tras k=23, saca B0 (val[0]) para el pulso 24.
            if (k >= 14 && k <= 23)
                miso_r = val[23 - k];
            else
                miso_r = 0;                   // Fuera de la ventana de datos mantiene 0
        end
    end

    // ------------------------------------------------------------------
    // 5. TAREAS AUXILIARES (Emulación del bus del FemtoRV32 y verificación)
    // ------------------------------------------------------------------

    // Simula una escritura síncrona de la CPU: coloca dirección y dato,
    // activa CS y WR durante exactamente 1 ciclo de reloj y los desactiva.
    task bus_write(input [4:0] a, input [31:0] v);
        begin
            @(posedge clk);
            addr <= a; d_in <= v; cs <= 1; wr <= 1;
            @(posedge clk);
            cs <= 0; wr <= 0;
        end
    endtask

    // Simula una lectura síncrona de la CPU: activa CS y RD durante 1 ciclo
    // y espera un ciclo adicional para capturar d_out (salida registrada).
    task bus_read(input [4:0] a, output [31:0] v);
        begin
            @(posedge clk);
            addr <= a; cs <= 1; rd <= 1;
            @(posedge clk);
            cs <= 0; rd <= 0;
            @(posedge clk);
            v = d_out;
        end
    endtask

    integer    errores = 0;      // Acumulador de fallas detectadas en la prueba
    reg [31:0] lectura;          // Variable temporal para leer CTRL o STATUS

    // Espera 800 µs (4 x 200,000 ns) para dar margen sobrado a que el periférico
    // complete un barrido de los 4 canales (~76 µs reales a 1,35 MHz).
    task esperar_barrido;
        integer i;
        begin
            for (i = 0; i < 4; i = i + 1)
                #200000;
        end
    endtask

    // Lee el registro en la dirección 'a' y compara estrictamente ('!==')
    // contra el valor 'esperado' (detecta también estados indefinidos X o Z).
    task comprobar(input [4:0] a, input [31:0] esperado, input [8*12-1:0] nombre);
        reg [31:0] v;
        begin
            bus_read(a, v);
            if (v !== esperado) begin
                $display("FALLA %0s: leido=%0d esperado=%0d", nombre, v, esperado);
                errores = errores + 1;
            end else
                $display("OK    %0s = %0d", nombre, v);
        end
    endtask

    // ------------------------------------------------------------------
    // 6. SECUENCIA PRINCIPAL DE PRUEBAS (Se ejecuta una sola vez en t = 0)
    // ------------------------------------------------------------------
    initial begin
        // Configura la exportación de todas las señales del testbench y del DUT
        // al archivo .vcd para visualizar las formas de onda en GTKWave.
        $dumpfile("ondas_joystick.vcd");
        $dumpvars(0, tb_perip_joystick);

        // Carga valores de prueba conocidos para los 4 ejes analógicos (0..1023)
        canal[0] = 10'd512;    // J1_X centrado
        canal[1] = 10'd1023;   // J1_Y arriba al tope
        canal[2] = 10'd0;      // J2_X a la izquierda
        canal[3] = 10'd291;    // J2_Y valor intermedio arbitrario

        // Mantiene el reset activo durante 200 ns, luego lo libera y espera 200 ns
        #200 rst = 0;
        #200;

        // --- PRUEBA 1: Modo continuo (ENABLE = 1) ---
        // Escribe bit 0 en CTRL (0x00) para iniciar barridos automáticos continuos.
        bus_write(5'h00, 32'h1);
        esperar_barrido;

        // Verifica que los cuatro registros de ejes coincidan con los valores del modelo
        comprobar(5'h08, 512,  "J1_X");
        comprobar(5'h0C, 1023, "J1_Y");
        comprobar(5'h10, 0,    "J2_X");
        comprobar(5'h14, 291,  "J2_Y");

        // Lee STATUS (0x04) y comprueba que el bit 1 (VALID) esté en 1
        bus_read(5'h04, lectura);
        if (lectura[1] !== 1'b1) begin
            $display("FALLA STATUS.VALID no activo"); errores = errores + 1;
        end

        // --- PRUEBA 2: Pulsadores físicos (activos en bajo) ---
        // Simula presionar el botón de J1 (bit 0 baja a 0) y espera 2 µs
        // para que la señal atraviese el sincronizador de doble flip-flop.
        btn_n = 2'b10;
        #2000;
        comprobar(5'h18, 1, "BUTTONS");  // Debe leerse invertido: bit 0 = 1
        btn_n = 2'b11;                   // Suelta el botón

        // --- PRUEBA 3: Barrido único por demanda (START = 1, sin ENABLE) ---
        bus_write(5'h00, 32'h0);         // Apaga el modo continuo (ENABLE = 0)
        canal[0] = 10'd100;              // Cambia la posición simulada de J1_X
        esperar_barrido;                 // Espera a que termine el barrido previo en curso

        // Escribe bit 1 en CTRL (0x00) para disparar una sola lectura completa
        bus_write(5'h00, 32'h2);
        esperar_barrido;

        // Comprueba que J1_X se actualizó al nuevo valor (100)
        comprobar(5'h08, 100, "J1_X tras START");

        // Verifica que el bit START (bit 1 de CTRL) se limpió automáticamente a 0
        bus_read(5'h00, lectura);
        if (lectura[1] !== 1'b0) begin
            $display("FALLA START no se limpio"); errores = errores + 1;
        end else
            $display("OK    START se limpio solo");

        // --- RESULTADO FINAL DE LA SIMULACIÓN ---
        if (errores == 0) $display("PASS: perip_joystick");
        else              $display("FAIL: %0d errores", errores);
        $finish;                         // Detiene el simulador vvp
    end

endmodule
