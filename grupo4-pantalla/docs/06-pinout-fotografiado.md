# 06 — Identificación de contactos HUB75E en nuestra PCB

**Fecha de registro:** 2026-11-07  
**Fuente primaria:** transcripción explícita del integrante que examina las fotografías del panel.  
**Estado:** identificación de etiquetas; **sin medidas de continuidad ni validación de señales**.

## 1. Transcripción exacta de las ocho filas

La serigrafía se lee, en dos columnas:

```text
R1   G1
B1   GND
R2   G2
B2   E
A    B
C    NC
CLK  LAT
OE   GND
```

La sexta fila tiene dos etiquetas **independientes: `C` y `NC`**. No existe una señal denominada `CNC` en el material declarado. Se mantiene la designación `NC` sin sustituirla silenciosamente por `D`.

## 2. Tabla de contactos con numeración HUB75E convencional

| Fila | Izquierda (número convencional) | Derecha (número convencional) | Observación |
|---:|---|---|---|
| 1 | 1 — R1 | 2 — G1 | Datos RGB superiores |
| 2 | 3 — B1 | 4 — GND | Azul superior y tierra |
| 3 | 5 — R2 | 6 — G2 | Datos RGB inferiores |
| 4 | 7 — B2 | 8 — E | Azul inferior y señal E |
| 5 | 9 — A | 10 — B | Selección de filas |
| 6 | 11 — C | **12 — NC** | Diferencia crítica frente a HUB75E estándar (**D** en pin 12) |
| 7 | 13 — CLK | 14 — LAT | Desplazamiento y latch |
| 8 | 15 — OE | 16 — GND | Habilitación de salidas y tierra |

**Advertencia:** los números se asignan siguiendo la **convención habitual de pinout de conector 2×8**. La geometría del conector en la fotografía no valida por sí sola la orientación de pin 1, la existencia de llaves o las señales eléctricas. Se debe confirmar antes de confeccionar el cable.

## 3. Qué está probado y qué no

- **Confirmado por el equipo:** las 16 etiquetas impresas y su organización de ocho parejas; la PCB dice `HUB75E`.
- **Sugerido por la inscripción del modelo:** 64×64 y posiblemente barrido 1/32 (código `32S`).
- **No comprobado:** si el contacto **`NC`** realmente está abierto, conectado a un CI o implementa otra función; qué esquema de selección de filas usan los controladores de esta versión; si el resto coincide con la convención eléctrica.
- **Referencia de contraste:** un HUB75E de 64×64 con barrido 1/32 típico utiliza **A, B, C, D y E**, cinco bits para 32 direcciones. La placa fotografiada solo rotula **A, B, C, E** y **NC**, de modo que **no queda demostrado que se pueda utilizar una FSM estándar de 5 bits**.

## 4. Validaciones prioritarias antes de cablear

1. Fotografiar nítidamente el conector 2×8, sus marcas de orientación y el conector de entrada `IN`.
2. Obtener la hoja de datos *del fabricante real* o consultar al vendedor el esquema de dirección de filas; preguntar expresamente por `NC`.
3. Con la placa **desenergizada**, identificar con multímetro el contacto de la fila `C / NC` y comprobar continuidad con GND y/o pistas accesibles. Registrar observaciones, **no inferir por una sola medida**.
4. Identificar y documentar las referencias legibles de los CI de filas y sus posibles terminales de dirección.
5. No asignar GPIO de la Tang Nano a `D` ni aplicar señales al supuesto `NC` hasta cerrar la investigación; confirmar también polaridad, tensión de panel y adaptador lógico.

## 5. Fuentes de comparación externa (no son la ficha de nuestra PCB)

- Raspberry Pi Foundation, ejemplo HUB75E con pin 12 `D`: https://github.com/raspberrypi/pico-examples/blob/master/pio/hub75/Readme.md
- Waveshare, matriz 64×64 P2.5 con barrido 1/32: https://www.waveshare.com/wiki/RGB-Matrix-P2.5-64x64
- Panel comercial comparable, requiere 5 V/4 A **para ese modelo**: https://www.waveshare.com/RGB-Matrix-P2.5-64x64.htm
