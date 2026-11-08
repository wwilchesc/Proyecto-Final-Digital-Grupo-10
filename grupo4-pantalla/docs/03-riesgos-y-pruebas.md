# 03 — Matriz de riesgos y procedimiento de validación

**Estado inicial:** todas las verificaciones físicas y RTL están pendientes. No marcar como superadas por la mera preparación de este documento.

## 1. Riesgos priorizados

| ID | Riesgo | Impacto | Acción preventiva / criterio de cierre |
|---|---|---|---|
| R01 | Fila rotulada `C / NC` (confirmación verbal del equipo), mientras el estándar emplea `C / D` | **Crítico** | Identificar contactos 11/12, obtener esquema o trazado físico del posible D y verificar direccionamiento; NO asumir mapeo estándar |
| R02 | Polaridad de alimentación invertida | **Crítico** | Verificar por serigrafía y continuidad sin energizar; doble comprobación de GND/VCC antes de conectar |
| R03 | Fuente con corriente insuficiente, cableado fino o 5 V desde la FPGA | **Crítico** | Fuente 5 V regulada externa *tras validar la ficha real*, cables adecuados, protección, límites de corriente y polaridad comprobados |
| R04 | Nivel lógico 3,3 V insuficiente para entradas a 5 V | Alto | Medir/consultar VIH del chip real; evaluar buffer AHCT y test con baja velocidad |
| R05 | Pin `.cst` incorrecto, banco de 1,8 V o pin compartido | **Crítico** | Revisar esquema y herramienta FPGA; registrar tabla pin–banco–voltaje–función antes de cablear |
| R06 | Cable IDC invertido o salida OUT confundida con entrada IN | Alto | Identificar dirección de flujo y llave/conector; verificación de continuidad sin energía |
| R07 | Barrido de filas o latencia LAT/OE no acordes con el controlador | Alto | Probar patrón por fila, capturar señales en analizador lógico/oscilo y corregir FSM |
| R08 | Parpadeo y brillo irregular por refresco insuficiente | Medio/alto | Medir cuadro completo, ajustar CLK_PANEL y permanencia OE; captura en video no sustituye medida |
| R09 | Imagen con colores permutados o filas espejadas | Medio | Patrón de seis canales R1/G1/B1/R2/G2/B2 y esquinas; comprobar orden físico |
| R10 | Conflictos de BRAM/lecturas MMIO con CPU | Alto | Contrato de bus y pruebas de lectura/escritura concurrente; verificar síntesis y timing |
| R11 | Desfase de cambio de imagen a mitad del barrido (tearing) | Medio | Acordar actualización por fin de cuadro o doble buffer según recursos disponibles |
| R12 | Falta de trazabilidad individual | Alto académico | Commits de avance propio, diario de diseño, testbench, GTKWave y videos auténticos |
| R13 | Duplicación del trabajo del equipo de pantalla (posible repositorio externo) | Alto organizativo | Compartir borrador, inventariar su estado real y asignar responsables antes de modificar RTL |

## 2. Secuencia de pruebas propuesta

### V0 — Documentación y seguridad, SIN energizar

- [ ] Registrar modelo, fotos nítidas del conector, chips y fuente.
- [ ] Confirmar `GND/VCC`, conector de entrada, pin 1, función del contacto `NC` y si existe direccionamiento especial.
- [ ] Confirmar esquema de tensión y pines de Tang Nano 9K.
- [ ] Registrar foto de interconexión y lista de materiales aprobada por el equipo.

**Evidencia:** fotos fechadas, tabla de verificación y referencias técnicas. **Criterio:** ningún pin crítico incierto para la primera conexión.

### V1 — Simulación de controlador aislado

- [ ] Especificar FSM de barrido (`BLANK`, `ADDRESS`, `SHIFT`, `LATCH`, `DISPLAY`, `NEXT_ROW`) como **propuesta**, no estados implementados.
- [ ] Escribir testbench con reloj/reinicio y contar los 64 desplazamientos por dirección.
- [ ] Verificar que OE permanece deshabilitado en cambios de dirección y durante LAT si el panel lo requiere.
- [ ] Guardar VCD y captura de GTKWave; comprobar orden de RGB y direcciones.

**Evidencia:** `rtl/*.v`, `sim/tb_*.v`, `sim/*.gtkw` y capturas/registro de ejecución. **Criterio:** aserciones completadas sin errores.

### V2 — Encendido controlado y patrón RGB

**Solo cuando V0 esté cerrado, con fuente adecuada y supervisión de quien controla el hardware.**

- [ ] Comenzar con contenido oscuro y habilitación de brillo reducida.
- [ ] Colores sólidos rojo, verde, azul; luego blanco a brillo restringido.
- [ ] Patrón de franjas y esquinas para validar orientación y asignación de filas.
- [ ] Registrar consumo bajo varios patrones con instrumento apropiado; parar ante calentamiento/olor/fallo.

**Evidencia:** fotografías, consumo medido, video y versión del bitstream. **Criterio:** patrón correcto, sin fallo eléctrico.

### V3 — Integración de framebuffer (sin juegos)

- [ ] Escribir patrón por bus MMIO y leerlo de vuelta cuando esté implementado.
- [ ] Confirmar formato de píxel, direcciones, latencias y estado de transacción.
- [ ] Verificar que la pantalla no deja de refrescar al escribir la imagen.
- [ ] Medir refresco y, si aplica, efecto de doble buffer o swap por fin de cuadro.

**Evidencia:** testbench SoC, trazas de bus, captura real y tabla de resultados.

### V4 — Validación conjunta

- [ ] Vincular con generación de imagen/firmware real.
- [ ] Verificar cambios de escena, texto y movimientos, sin bloqueos ni parpadeo visible.
- [ ] Reportar utilización real LUT/FF/BSRAM, frecuencia lograda y restricciones de timing.

## 3. Formato obligatorio para registrar cada prueba

```text
ID / Fecha / Responsable / Rama+commit:
Objetivo:
Condiciones iniciales (hardware, cableado, fuente, versión bitstream):
Procedimiento:
Señales o registros observados:
Resultado medido (PASS/FAIL/BLOQUEADO):
Evidencia (foto, video, VCD, GTKWave, consola):
Problema abierto / próxima acción:
```

No declarar un ensayo como aprobado únicamente porque el proyecto compile.
