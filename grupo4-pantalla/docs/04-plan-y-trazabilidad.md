# 04 — Plan de trabajo y trazabilidad individual

**Plan inicial del módulo de pantalla para el repositorio oficial.** Se documentará el avance real mediante commits directos a `main`, según la organización indicada por el equipo. Las fechas y responsabilidades se completarán cuando se asignen tareas y se disponga de las pruebas.

## Equipo conjunto de pantalla (grupos 4 y 5)

- **Gisela Barrera Florez**
- **Sandra Amaya Betancourt**
- **Erika Briyith Hueso Castro**
- **Sebastian Cespedes**
- **Juan Jose Mora**
- **Luis Felipe Cardenas**

La composición del equipo se registró con base en los nombres comunicados por sus integrantes. **Las responsabilidades técnicas, revisores y autorías se asignarán y verificarán individualmente** en el historial Git y en la evidencia de las pruebas; figurar en esta lista no demuestra un aporte específico.

## 1. Fases y entregables verificables

| Hito | Objetivo | Entregables | Criterio de cierre |
|---|---|---|---|
| H0 — Alcance | Establecer responsables y estructura del repositorio oficial | Lista de miembros, responsabilidades reales y plataforma definitiva | Alcance documentado y aceptado por el equipo |
| H1 — Reconocimiento | Identificar el panel y compatibilidad eléctrica | Esta documentación, fotos, ficha auténtica o constancia de ausencia, verificación del contacto `NC` | Lista de conexión segura revisada |
| H2 — Arquitectura | Definir controlador y framebuffer | Diagramas de bloques y flujo, interfaces, tabla pinout `.cst` propuesta, timing por señales | Diseño revisado por el grupo |
| H3 — RTL mínimo | Barrer panel sin CPU | Generador de señales Verilog, testbench autoverificante, VCD/GTKWave | Simulación PASS reproducible |
| H4 — Patrón físico | Primer encendido | Fuente y adaptador verificados, video patrón RGB/filas, consumo documentado | Panel probado físicamente |
| H5 — Framebuffer/MMIO | Recibir datos del SoC | RAM, mapa de registros acordado, interfaz bus, simulación CPU/periférico | Leer/escribir y refrescar sin errores |
| H6 — Integración | Escena final y sustentación | Bitstream, scripts de build, pruebas integrales, reportes de recursos/timing, video | Demostración real y comprensión individual |

## 2. Arquitectura prevista para debatir en H2

```
CPU / SoC FemtoRV32 (o generador de patrón)
    | bus / MMIO — por acordar
    v
Framebuffer dual-port o acceso arbitrado (resolución 64x64)
    | lectura de dos píxeles por columna / dirección de fila
    v
Generador de tiempos y FSM de barrido
    | R1 G1 B1 / R2 G2 B2 | A B C [D?] E | CLK LAT OE
    v
Adaptador lógico 3,3V -> niveles compatibles con el panel
    v
Panel HUB75E 64x64, alimentación separada
```

**No es todavía un diagrama validado**: servirá como punto de partida del próximo `.drawio`. La serigrafía declarada es `C / NC`; verificar la función eléctrica del contacto `NC`, la posible ausencia de `D` y la asignación real de pines.

## 3. Asignación de responsables (por completar sin inventar autorías)

| Actividad | Responsable | Revisor | Estado | Referencia Git |
|---|---|---|---|---|
| Identificación y fuente de alimentación | Por acordar | Por acordar | Borrador | Pendiente |
| Pinout `NC` + conexión Tang Nano | Por acordar | Por acordar | Bloqueado por verificación eléctrica | Pendiente |
| Diagramas y contratos del periférico | Por acordar | Por acordar | Por hacer | Pendiente |
| RTL de barrido + FSM | Por acordar | Por acordar | Por hacer | Pendiente |
| Testbench + GTKWave | Por acordar | Por acordar | Por hacer | Pendiente |
| Framebuffer y MMIO | Por acordar | Por acordar | Por hacer | Pendiente |
| Ensayo físico y video | Por acordar | Por acordar | Por hacer | Pendiente |

Cada estudiante debe ejecutar y explicar los commits de su propio aporte. Una coautoría solo procede cuando refleja colaboración real; la generación por IA no equivale a trabajo experimental o aprendizaje demostrado.

## 4. Reglas prácticas para Git y para la evaluación

1. Trabajar directamente en `main` del repositorio oficial, **sin PR**, según el acuerdo actual; sincronizar antes de cada entrega y limitar los cambios a `grupo4-pantalla/`.
2. Un commit por cambio coherente (identificación, circuito de adaptación, diagrama, testbench, pruebas…), sin fabricar historial.
3. Guardar datos de pruebas auténticos y artefactos reproducibles; no subir resultados falsos ni declarar funcionamiento que no se haya comprobado.
4. En cada mensaje de commit y registro de avance describir **qué se cambió, por qué, cómo se comprobó y qué falta**.
5. En la sustentación explicar: reloj de sistema vs reloj de panel; barrido 1/32; `CLK/LAT/OE`; dirección de filas; formato de píxel; sincronización de memoria; fuentes y niveles de tensión.
6. Mantener `grupo4-pantalla/` del repositorio oficial como fuente de verdad documental y técnica; evitar trabajos duplicados y preservar aportes de los distintos integrantes.
7. Registrar la placa FPGA efectiva y actualizar la documentación general cuando el grupo confirme las definiciones; evitar afirmaciones incompatibles entre README y diseños.

## 5. Próximas acciones concretas

- **A1:** identificar a los responsables efectivos de hardware, RTL, simulación e integración en el equipo de pantalla.
- **A2:** obtener la ficha del vendedor y fotografía macro nítida de los CI.
- **A3:** comprobar eléctricamente, sin alimentación, los dos contactos asociados al rótulo `C / NC`, en particular el que podría ser `NC`.
- **A4:** confirmar placa definitiva y pines 3,3V del banco correspondiente.
- **A5:** diseñar diagramas `.drawio` de bloques, FSM de barrido y tiempos (separado), con trazabilidad al Verilog real.
- **A6:** escribir primer testbench y simular antes del encendido del panel.

## 6. Dependencias externas

- Integrantes que disponen del panel: acceso al hardware, identificación del proveedor, fotografías y verificaciones eléctricas.
- Integración/SoC: formato MMIO, latencia del bus, mapa de memoria, clocks, pines, BRAM disponible.
- Docente: criterios de evaluación individual y alcance académico confirmado.

## Seguimiento H2 — documentación de arquitectura

- **Preparado (pendiente de revisión humana):** cinco diagramas conceptuales y sus explicaciones, en [diagramas/](diagramas/README.md).
- **Evidencia fotográfica:** organizada por identificación, conexión, simulación, funcionamiento, integración y mediciones. Véase [fotos/README.md](fotos/README.md).
- **No realizado todavía:** validación de `NC`, RTL, testbench, conexión eléctrica y pruebas físicas.
- **Responsables efectivos y revisiones:** completar según commits y evidencias reales, sin atribución automática a los seis integrantes.
