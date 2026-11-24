# Grupo 4 · Entrega técnica B.3 — Decodificador local MMIO HUB75E

**Alcance:** diseño de propuesta de decodificación local y registros mínimos para la **región de control de pantalla**, con RTL sintetizable, diagrama y testbench autoverificable. **NO** constituye integración completa del periférico al SoC.

## 1. Origen de las decisiones y límites

Contratos consultados en `main` del repositorio `wwilchesc/Proyecto-Final-Digital-Grupo-10` (24-11-2026):

- `README.md` (raíz): contrato `clk,rst,cs,rd,wr,addr[4:0],d_in[31:0],d_out[31:0]` y regiones propuestas `0x0048_0000` (framebuffer) y `0x004C_0000` (control).
- `grupo1-memoria-externa/rtl/perip_spi.v`: patrón de decodificación local (`cs & wr & ...`) y lectura `d_out` registrada.
- `grupo4-pantalla/Prueba_de_funcionamiento/PRUEBA_2/hub75_control.v`: generación de `hub_oe`; NO expone todavía `frame_done`.
- `grupo4-pantalla/Prueba_de_funcionamiento/PRUEBA_2/framebuffer.v`: ROM de imagen inicial de 4096 píxeles RGB888 con dos lecturas síncronas, SIN escritura desde el procesador.

**Decisiones nuevas en esta propuesta, NO acuerdos definitivos:** offsets de registros, bit de habilitación de pantalla, semántica de lectura, contador de cuadros, tratamiento de `rd=wr=1`. Revisar con G6 antes de conectar el SoC. La base 0x004C_0000 es la propuesta del repositorio raíz, no una dirección ya implementada en un decodificador global.

## 2. Caja negra e interfaz

Módulo: `perip_hub75_ctrl`.

| Señal | Dirección | Bits | Significado |
| --- | --- | ---: | --- |
| `clk` | entrada | 1 | reloj de 27 MHz |
| `rst` | entrada | 1 | reset síncrono activo alto |
| `cs` | entrada | 1 | selección GLOBAL de la región 0x004C_0000, generada por G6 |
| `rd` / `wr` | entrada | 1 / 1 | lectura o escritura, mutuamente excluyentes |
| `addr` | entrada | 5 | **desplazamiento en bytes** dentro de la región; no es la dirección completa |
| `d_in` | entrada | 32 | valor escrito por CPU |
| `d_out` | salida | 32 | dato leído, **registrado al siguiente flanco** |
| `frame_done` | entrada | 1 | pulso de un ciclo por cuadro completo del barrido, aún no expuesto en RTL principal |
| `hub_oe_core` | entrada | 1 | señal OE generada por FSM del panel, activa en bajo |
| `hub_oe_panel` | salida | 1 | señal OE final (también activa en bajo) |
| `display_en` | salida | 1 | imagen habilitada por software |

## 3. Mapa local de registros (propuesto)

La región es `0x004C_0000` con offsets alineados a palabra de 32 bits.

| Dirección CPU | Offset (`addr`) | Registro | Acceso | Semántica |
| --- | --- | --- | --- | --- |
| `0x004C_0000` | `0x00` | CONTROL | R/W | bit 0 `DISPLAY_EN` (reset=1); demás bits leídos 0 |
| `0x004C_0004` | `0x04` | STATUS | R | bit 0 = estado de `DISPLAY_EN` (no es `BUSY`) |
| `0x004C_0008` | `0x08` | FRAMES | R | contador de eventos `frame_done` (32 bits) |

Las escrituras a registros de solo lectura se ignoran; las lecturas no definidas retornan cero. `rd=wr=1` es un acceso inválido y se ignora. `cs=0` impide todo acceso. Solo se implementan accesos de palabra completa; el byte-enable no está definido todavía con G6.

### 3.1. Ecuaciones de decodificación

Sea `R = cs ∧ rd ∧ ¬wr` y `W = cs ∧ wr ∧ ¬rd`:

- `wr_control = W ∧ (addr = 0x00)`
- `rd_control = R ∧ (addr = 0x00)`
- `rd_status  = R ∧ (addr = 0x04)`
- `rd_frames  = R ∧ (addr = 0x08)`

Todas esas señales son **combinacionales** (`wire`), pues resultan directamente de comparadores de igualdad y compuertas lógicas. La CPU no las genera: se generan **dentro** del periférico, utilizando la selección global `cs`.

### 3.2. Conexión funcional mínima

La FSM HUB75E existente continúa realizando el barrido. Este módulo **no reemplaza** su FSM ni su datapath. Solo añade una habilitación de visualización y un contador observable por CPU.

`hub_oe_panel = hub_oe_core | ~DISPLAY_EN`

Esta operación es válida porque `OE` del panel está activo en bajo: `DISPLAY_EN=0` fuerza OE=1 (apagado); con `DISPLAY_EN=1`, la salida sigue a la FSM sin modificar su secuencia.

`FRAMES` incrementa con cada pulso de `frame_done`. **Pendiente:** exponer esa señal en la jerarquía `hub75_control.v` → `hub75_top.v` → adaptador. El registro funciona en la prueba aislada, donde el testbench genera los pulsos.

## 4. Diagrama editable

Ver `docs/arquitectura.png` o `docs/arquitectura.svg`. El archivo fuente `docs/arquitectura.dot` es editable con Graphviz (`dot -Tpng ...`).

El bloque **decodificador global** representa una dependencia del Grupo 6 todavía no implementada. El **decodificador local B.3** sí está desarrollado en el RTL anexo.

## 5. Simulación y verificación

En Linux Mint, con `iverilog` y `vvp` instalados:

```bash
make sim
```

El banco `sim/perip_hub75_ctrl_tb.v` comprueba: reset, lectura de CONTROL/STATUS/FRAMES, escritura de habilitación, OR de OE, rechazo de escrituras a solo lectura, offsets inexistentes/desalineados, rechazo sin CS, rechazo de RD/WR simultáneos, incremento del contador `FRAMES` con tres pulsos externos y lectura registrada.

**Estado de la evidencia:** este paquete contiene el testbench ejecutable, pero en el entorno de preparación no estaba disponible Icarus Verilog; por tanto, **no se declara PASS ejecutado**. El resultado esperado al ejecutar la simulación, si no detecta fallos, es `PASS: <N> comprobaciones B.3, sin errores`. Guardar el resultado real y una captura de GTKWave si se ejecuta.

## 6. Qué no está implementado

1. **B.5 — START/BUSY/DONE:** no se asignan arbitrariamente esas señales a un barrido continuo. Una futura operación `SWAP_REQUEST` entre bancos sí puede requerir handshake; habrá que definirla con G6 y el equipo de juego.
2. **Framebuffer `0x0048_0000`:** no forma parte de este decodificador de registros. Para 4096 píxeles empaquetados en una palabra de 32 bits cada uno, se necesitan 16384 bytes de ventana y una dirección de **12 bits de índice de píxel** (`offset[13:2]`), no `addr[4:0]`. Además, hace falta un puerto real de escritura y resolver la concurrencia con la lectura del panel.
3. **B.4/B.6/B.7 globales:** todavía falta el adaptador de bus completo, el handshake final acordado y una simulación conjunta FemtoRV32 + framebuffer + HUB75E.
4. **Síntesis y placa:** no ejecutadas con este archivo; no declarar uso real de GPIO ni cambios a `tang_nano_9k_top.v`.

## 7. Integración propuesta sin romper el código actual

- G6 genera `cs_ctrl` a partir de la dirección completa de CPU para la región `0x004C_0000`.
- G6 entrega a este módulo `addr = dirección_CPU[4:0]`, `rd`, `wr`, `d_in` y enruta `d_out` en el mux del bus.
- G4 expone un pulso `frame_done` de la FSM; el RTL actual no lo tiene en sus puertos.
- G4 conecta `hub_oe_core` (antes iba directamente al GPIO) hacia este adaptador, y solo `hub_oe_panel` hacia el GPIO final.
- Antes de comprometer esta conexión: acordar con G6 si la latencia de lectura de un ciclo es compatible con la espera de la CPU y si los accesos de escritura son pulsos de un ciclo.

## 8. Evidencia y autoría individual

Revisar manualmente diagrama, ecuaciones, tabla y RTL; ejecutar el banco; discutir los supuestos con G6. Registrar el uso de IA como apoyo de redacción y generación inicial de código, y consignar cuáles decisiones, modificaciones, pruebas y observaciones hizo realmente cada integrante. El commit en GitHub acredita el aporte registrado, **no** demuestra por sí solo comprensión, funcionamiento físico ni integración.
