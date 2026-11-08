# Pantalla RGB HUB75E — documentación de reconocimiento (fase 1)

> **Estado:** fase documental inicial, pendiente de validaciones físicas por el grupo.  
> **Fecha de estudio:** 2026-11-07.  
> **Alcance:** identificación visual del hardware, revisión bibliográfica, riesgos y plan de verificación. **No** acredita funcionamiento en FPGA, pruebas físicas o RTL implementado.

La intención es establecer una base verificable antes de diseñar el controlador para el panel LED RGB 64×64 y su integración con la Sipeed Tang Nano 9K. Los documentos se mantendrán en el **repositorio oficial**, dentro de `grupo4-pantalla/`.

## Índice de documentos

| Archivo | Contenido | Estado |
|---|---|---|
| [01-identificacion-panel.md](01-identificacion-panel.md) | Datos leídos de las fotografías y contraste con fabricantes | Estudio documental |
| [02-interfaz-hub75e-y-tang-nano9k.md](02-interfaz-hub75e-y-tang-nano9k.md) | Señales, temporización conceptual, compatibilidad y memoria | Propuesta sujeta a verificación |
| [03-riesgos-y-pruebas.md](03-riesgos-y-pruebas.md) | Matriz de riesgos, secuencia de ensayos y criterios de aceptación | Plan; pruebas no ejecutadas |
| [04-plan-y-trazabilidad.md](04-plan-y-trazabilidad.md) | Hitos, entregables, dependencias y pautas de Git | Propuesta de coordinación |
| [05-declaracion-uso-ia.md](05-declaracion-uso-ia.md) | Herramientas utilizadas y control humano del diseño | Declaración inicial |
| [06-pinout-fotografiado.md](06-pinout-fotografiado.md) | Pinout aclarado por el equipo: `C / NC` y diferencias con HUB75E estándar | Pendiente de verificación eléctrica |
| [07-revision-borrador-previo.md](07-revision-borrador-previo.md) | Revisión de las cuatro páginas manuscritas (sin adjuntar el PDF) | Antecedente, no diseño validado |
| [fotos/](fotos/) | Fotografías del reverso suministradas para el reconocimiento | Evidencia visual |

## Identificación de trabajo

- **Marcaje leído en PCB:** `P2.5-2121-64X64-32S-8H-M11` (última parte pendiente de cotejar en alta resolución).
- **Conector identificado por serigrafía:** HUB75E, 2×8 vías.
- **Observación literal:** el equipo aclaró que el rótulo corresponde a **`C` y `NC`**. La convención HUB75E utiliza **`C` y `D`** en esa fila. Falta comprobar eléctricamente la función del contacto `NC`.
- **Fabricante y hoja de datos exactos:** no verificados. Se enlaza documentación de un panel *comparable* Waveshare P2.5-64×64; no se presenta como el fabricante de esta placa.

## Acuerdos pendientes antes de escribir RTL

1. Registrar responsables y disponer de acceso al panel físico para verificaciones.
2. Confirmar foto nítida del modelo y de los circuitos integrados; preguntar fabricante/proveedor.
3. Resolver la interpretación eléctrica de **`C / NC`** y el tipo de barrido real.
4. Confirmar fuente, voltajes lógicos, adaptador de nivel, masa común y orientación de conectores.
5. Coordinar con integración el reloj, pines utilizables, mapa MMIO, formato de framebuffer y arbitraje de lectura/escritura.
6. Registrar el resultado en Git mediante commits individuales acompañados de evidencia auténtica.

**Nota:** Para cálculos se usa la Tang Nano 9K con reloj nominal de 27 MHz. Verificar la placa definitiva y sus bancos antes de asignar pines `.cst`; otros documentos del repositorio podrían reflejar versiones anteriores.
