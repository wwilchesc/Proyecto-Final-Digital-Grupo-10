// ============================================================================
// HUB75_CONTROL - FSM original del prototipo de video del Grupo 4
// ============================================================================
// Controla CUÁNDO se ejecuta cada transferencia del datapath (T1 a T14).
// No almacena la imagen; coordina el framebuffer, el datapath y los pines.
// always @(*) calcula órdenes combinacionales y próximos valores (=).
// always @(posedge clk) registra el estado y CLK/LAT/OE (<=).
// Los estados duran un ciclo, salvo S_SHOW que repite mientras espera el timer.
//
// Recorrido por columna: S_READ -> S_WAIT -> S_BITS -> S_CLK1 -> S_CLK0.
// Al llegar a la última columna: S_LAT1 -> S_LAT0 -> S_ADDR -> S_SHOW.
// Luego S_BLANK decide siguiente fila, plano o fotograma completo.
//
// El nombre del estado describe el intervalo de trabajo: por ejemplo, durante
// S_CLK1 el pin hub_clk está alto y se prepara su bajada para el próximo flanco.
// En la integración RGB111 se usa un único plano, por lo que plane_last=1
// con plane=0. La FSM sigue siendo compatible con el diseño RGB888 de 8 planos.
// frame_done es el aviso de fin de barrido usado por el handshake, no DONE.
// La lógica original se conserva; solo se amplían/aclaran comentarios.
module hub75_control (
    input  wire clk,
    input  wire rst,            // reset sincrono, activo en alto

    // ---- condiciones desde el datapath (resultado de los rombos) ----
    input  wire col_last,
    input  wire row_last,
    input  wire plane_last,
    input  wire timer_done,

    // ---- ordenes hacia el datapath ----
    output reg  load_rgb,
    output reg  inc_col,
    output reg  clr_col,
    output reg  inc_row,
    output reg  clr_row,
    output reg  inc_plane,
    output reg  clr_plane,
    output reg  load_addr,
    output reg  clr_timer,
    output reg  inc_timer,

    // ---- senales de control del panel (registradas) ----
    output reg  hub_clk,        // CLK_P
    output reg  hub_lat,        // lat
    output reg  hub_oe,         // Oe: 1 = LEDs apagados, 0 = LEDs encendidos

    // ---- aviso para el doble buffer ----
    // Pulso de 1 ciclo en el ultimo estado de un fotograma (T14). El estado
    // siguiente ya empieza el fotograma nuevo, asi que es el momento limpio
    // para cambiar de banco de memoria.
    output wire frame_done
);

    // ------------------------------------------------------------------
    // Estados
    // ------------------------------------------------------------------
    localparam [3:0] S_READ  = 4'd0,
                     S_WAIT  = 4'd1,
                     S_BITS  = 4'd2,
                     S_CLK1  = 4'd3,
                     S_CLK0  = 4'd4,
                     S_LAT1  = 4'd5,
                     S_LAT0  = 4'd6,
                     S_ADDR  = 4'd7,
                     S_SHOW  = 4'd8,
                     S_BLANK = 4'd9;

    // state: estado actual almacenado. next_state: resultado de la lógica
    // combinacional que será almacenado en el próximo flanco.
    reg [3:0] state;
    reg [3:0] next_state;

    // Pulso combinacional durante T14: última pareja de filas del último plano,
    // con la iluminación deshabilitada. El MMIO lo muestrea al siguiente flanco.
    // Para RGB111: row=31 y plane=0; no se exige que BUSY esté activo.
    assign frame_done = (state == S_BLANK) && row_last && plane_last;

    // Proximos valores de las salidas registradas
    reg hub_clk_next;
    reg hub_lat_next;
    reg hub_oe_next;

    // ------------------------------------------------------------------
    // Parte combinatoria: tabla de transferencias T1 a T14
    // Primero valores por defecto; el case solo sustituye lo que cambia.
    // ------------------------------------------------------------------
    always @(*) begin
        // Valores por defecto: conservar estado y pines; órdenes desactivadas.
        // Cada rama solo cambia las señales necesarias. Evita inferir latches.
        next_state   = state;
        hub_clk_next = hub_clk;
        hub_lat_next = hub_lat;
        hub_oe_next  = hub_oe;
        load_rgb  = 1'b0;
        inc_col   = 1'b0;
        clr_col   = 1'b0;
        inc_row   = 1'b0;
        clr_row   = 1'b0;
        inc_plane = 1'b0;
        clr_plane = 1'b0;
        load_addr = 1'b0;
        clr_timer = 1'b0;
        inc_timer = 1'b0;

        case (state)
            // T1: las direcciones ya proceden combinacionalmente del datapath.
            // En el flanco al salir de S_READ, la RAM registra ambos píxeles.
            S_READ: begin
                next_state = S_WAIT;
            end

            // T2: los datos de la lectura síncrona ya están disponibles.
            // load_rgb permite registrarlos en el datapath al salir de S_WAIT.
            // Sin esta separación, podría capturarse el dato de la dirección previa.
            S_WAIT: begin
                load_rgb   = 1'b1;
                next_state = S_BITS;
            end

            // T3: los seis bits RGB ya están registrados. La subida de CLK
            // se produce al salir de S_BITS; el panel desplaza los datos.
            S_BITS: begin
                hub_clk_next = 1'b1;
                next_state   = S_CLK1;
            end

            // T4: durante S_CLK1, CLK está alto. Preparar su bajada para
            // completar un pulso de un período del reloj principal.
            S_CLK1: begin
                hub_clk_next = 1'b0;
                next_state   = S_CLK0;
            end

            // CLK ya está bajo. Decidir si se enviaron las 64 columnas.
            // col_last se evalúa con el contador actual, antes del flanco.
            S_CLK0: begin
                if (col_last) begin
                    // T6: todos los bits de la pareja de filas ya se desplazaron.
                    // Mantener/deshabilitar la iluminación y subir LAT para
                    // capturar los datos en los registros de salida del panel.
                    hub_oe_next  = 1'b1;
                    hub_lat_next = 1'b1;
                    next_state   = S_LAT1;
                end else begin
                    // T5: incrementar columna en el siguiente flanco y volver
                    // a leer los dos píxeles de la nueva dirección.
                    inc_col    = 1'b1;
                    next_state = S_READ;
                end
            end

            // T7: LAT está alto durante S_LAT1. Al salir, baja LAT y se
            // reinicia col; el panel conserva el patrón recién capturado.
            S_LAT1: begin
                hub_lat_next = 1'b0;
                clr_col      = 1'b1;
                next_state   = S_LAT0;
            end

            // T8: cargar addr <= row en el datapath. Las líneas A-E cambian
            // con los LED apagados para evitar mostrar datos en otra fila.
            S_LAT0: begin
                load_addr  = 1'b1;
                next_state = S_ADDR;
            end

            // T9: al salir de S_ADDR, OE del núcleo baja y timer vuelve a cero.
            // OE físico puede seguir alto si el control MMIO bloquea el panel.
            S_ADDR: begin
                hub_oe_next = 1'b0;
                clr_timer   = 1'b1;
                next_state  = S_SHOW;
            end

            // S_SHOW: mantener la pareja de filas durante el umbral programado.
            // El timer se inicia en cero; se sale cuando ya vale t_limit.
            // Incluida la transición de salida, OE_core permanece bajo T+1 ciclos.
            S_SHOW: begin
                if (timer_done) begin
                    // T11: se cumplio el tiempo -> apagar LEDs
                    hub_oe_next = 1'b1;
                    next_state  = S_BLANK;
                end else begin
                    // T10: seguir esperando
                    inc_timer = 1'b1;
                end
            end

            // S_BLANK: OE del núcleo ya está alto. Las decisiones sobre fila
            // y plano son combinacionales dentro de este mismo estado.
            S_BLANK: begin
                next_state = S_READ;
                if (!row_last) begin
                    // T12: siguiente fila
                    inc_row = 1'b1;
                    clr_col = 1'b1;
                end else if (!plane_last) begin
                    // T13: siguiente plano
                    inc_plane = 1'b1;
                    clr_row   = 1'b1;
                    clr_col   = 1'b1;
                end else begin
                    // T14: reiniciar todos los contadores de recorrido.
                    // frame_done está alto; el MMIO puede cambiar de banco
                    // en este flanco sin mezclar cuadros en el barrido.
                    clr_plane = 1'b1;
                    clr_row   = 1'b1;
                    clr_col   = 1'b1;
                end
            end

            default: next_state = S_READ;
        endcase
    end

    // ------------------------------------------------------------------
    // Parte secuencial: guarda state y las salidas hacia el panel
    // ------------------------------------------------------------------
    // Las órdenes al datapath también se consumen en este flanco, pero
    // sus registros se encuentran en hub75_datapath, no en la FSM.
    always @(posedge clk) begin
        if (rst) begin
            state   <= S_READ;
            hub_clk <= 1'b0;
            hub_lat <= 1'b0;
            hub_oe  <= 1'b1;     // LEDs apagados al arrancar
        end else begin
            state   <= next_state;
            hub_clk <= hub_clk_next;
            hub_lat <= hub_lat_next;
            hub_oe  <= hub_oe_next;
        end
    end

endmodule
