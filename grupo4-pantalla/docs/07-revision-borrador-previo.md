# 07 — Evaluación crítica del borrador previo de pantalla

**Documento analizado:** `proyecto.pdf`, cuatro páginas manuscritas.  
**Uso:** antecedente conceptual de trabajo. **No se adjunta el PDF original** a este paquete; se conserva fuera del repositorio oficial salvo decisión posterior del equipo.  
**Limitación:** el documento no incluye, en lo examinado, RTL ejecutable, simulación reproducible, testbench, formas de onda medidas ni hoja de datos del panel real. No se puede acreditar funcionamiento de hardware con estos apuntes.

## 1. Revisión página por página

| Página | Ideas presentes en el borrador | Qué se aprovecha | Qué NO debe darse por probado |
|---:|---|---|---|
| 1 | Matriz 64×64; canales R1/G1/B1 y R2/G2/B2; señales CLK, LAT, OE; dirección A–E | Descripción básica del multiplexado y dos bancos RGB | El supuesto de **cinco líneas físicas A–E** contradice la serigrafía actual **`C / NC`** en vez de C / D; hace falta identificar el controlador real |
| 2 | Diagrama FPGA → interfaz HUB75E → panel, y un dibujo interno de registros/control de filas | Separación lógica entre fuente de imagen y señalización del panel | No se ve un contrato de framebuffer, mapa MMIO, asignación GPIO, temporización ni esquema verificado de la placa |
| 3 | Intento de tabla binaria de direcciones y de tamaños de datos | Idea de usar un contador de filas y direcciones binarias | Los anchos de `info_juego`, `pos_filas` y el conteo de píxeles son esbozos **sin derivación ni interfaz definida**. No copiarlos a RTL |
| 4 | Objetivo de mostrar un color fijo y secuencia preliminar IDLE → SHIFT → LATCH → DISPLAY → NEXT ROW | Buen primer escenario de prueba y esqueleto conceptual de una FSM | Faltan condiciones de avance, recuento preciso de 64 desplazamientos, señal de apagado durante cambios, periodos de OE, reset, errores y testbench |

## 2. Aclaraciones técnicas necesarias

### Dos mitades de datos RGB

Un HUB75E 64×64 de **barrido 1/32 convencional** recibe, para cada dirección de fila, **64 muestras RGB de la mitad superior y 64 muestras RGB de la inferior, en paralelo**. Por ello:

- 64 columnas × 32 direcciones = **2048 pulsos de desplazamiento de columna** por ciclo de barrido base, si hay un bit de color por canal.
- 64 columnas × 2 filas simultáneas × 32 direcciones = **4096 posiciones de píxel** cubiertas en ese ciclo.
- Si se usan varios planos de bits, el número de operaciones y el tiempo de exposición por plano cambian. **Esto es el modelo convencional; falta probar si coincide con el panel `C / NC`.**

### La fuente física no es el mapa MMIO

El borrador presenta entradas genéricas como `info_juego` y `pos_filas`, sin especificar generador de datos, unidades ni anchos de bus. Para un diseño integrable será necesario definir memoria de imagen, dirección de píxel, latencia, arbitraje de acceso, sincronización y control de refresco. Las direcciones propuestas por el proyecto (`0x480000`, `0x4C0000`) no constituyen aún un módulo RTL funcionando.

### Diferencia entre esquema y evidencia

Una FSM dibujada **no** acredita simulación, funcionamiento físico ni que las señales tengan los tiempos correctos. Para la evaluación del profesor se requiere relación directa diagrama ↔ Verilog ↔ testbench ↔ VCD/GTKWave ↔ prueba en la Tang Nano.

## 3. Decisión documental del equipo

**Reutilizar** los conceptos básicos de bancos RGB, CLK/LAT/OE, selección de filas, patrón de color sólido y ciclo de refresco; **revisar** las direcciones reales del panel antes de emplear el esquema A–E; **no incorporar** el PDF como fuente técnica definitiva ni como evidencia de simulación.

Este registro reconoce que existe trabajo conceptual previo, sin atribuirlo a personas concretas ni presentar contenido no validado como resultado propio.
