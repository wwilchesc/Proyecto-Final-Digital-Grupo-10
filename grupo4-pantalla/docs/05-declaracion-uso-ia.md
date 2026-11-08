# 05 — Declaración de uso de inteligencia artificial

## Alcance de esta entrega (2026-11-07)

Se utilizó **ChatGPT (OpenAI)** como herramienta de apoyo para:

1. Organizar el estudio preliminar de fotografías del reverso del panel.
2. Comparar el marcaje observado con referencias técnicas publicadas de HUB75E, paneles 64×64 P2.5 y Tang Nano 9K.
3. Formular una matriz inicial de riesgos eléctricos, temporales y de integración; registrar la aclaración posterior del equipo: el rótulo corresponde a dos contactos, `C` y `NC`.
4. Preparar borradores de documentación técnica, planificación y criterios de prueba para revisión humana.
5. Señalar explícitamente las limitaciones de la evidencia disponible y las verificaciones pendientes.

**No** se utilizó IA para afirmar que se ejecutaron pruebas físicas, simulaciones o mediciones. **No** se ha desarrollado ni verificado RTL del periférico como parte de esta fase documental. Los diagramas detallados, el código, las formas de onda y los resultados de prueba están pendientes.

## Declaración de fuentes

La información se separa en:

- **Observaciones directas:** letras y componentes visibles en fotografías aportadas por los estudiantes.
- **Información de terceros:** fichas y guías enlazadas abajo; sus parámetros corresponden a los equipos de cada fabricante, no necesariamente a nuestra placa.
- **Hipótesis/decisiones por validar:** escaneo 1/32, tensión real del panel, necesidad de conversión de nivel, significado eléctrico del contacto `NC` (aunque su rótulo fue confirmado por el equipo), asignación GPIO y arquitectura final del framebuffer.

| Fuente | Para qué se utilizó | URL |
|---|---|---|
| Sipeed — Tang Nano 9K | Reloj y recursos generales de placa | https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html |
| Waveshare — RGB Matrix P2.5-64×64 | Ejemplo de dimensiones, tensión y escaneo **no idéntico** | https://www.waveshare.com/RGB-Matrix-P2.5-64x64.htm |
| Waveshare — documentación de matrices | Secuencia típica de barrido y dirección | https://www.waveshare.com/wiki/RGB-Matrix-P2.5-64x64 |
| Raspberry Pi — HUB75 example | Referencia de señalización HUB75E y distribución estándar | https://github.com/raspberrypi/pico-examples/blob/master/pio/hub75/Readme.md |
| Texas Instruments — SN74AHCT245 | Ejemplo de buffer de entradas TTL compatibles | https://www.ti.com/product/SN74AHCT245 |
| Adafruit — HUB75 Bonnet | Ejemplo práctico de adaptación 3,3→5 V con AHCT | https://learn.adafruit.com/adafruit-triple-led-matrix-bonnet-for-raspberry-pi-with-hub75?view=all |

## Revisión humana requerida antes de presentar

- [X] Un estudiante revisó cada afirmación de hardware contra la fotografía o fuente original.
- [ ] Los integrantes verificaron la exactitud de los enlaces y el marcaje del panel.
- [ ] Se corrigieron los supuestos que no coincidan con la placa física.
- [ ] Los autores pueden explicar sin ayuda qué hace `CLK`, `LAT`, `OE`, cómo funciona la dirección de filas y qué significa la incompatibilidad 3,3/5 V.
- [ ] Quedó registrado por separado **quién** efectuó pruebas y **cuál** fue la evidencia, cuando existan.

La responsabilidad académica y técnica por el contenido, el diseño final, la seguridad eléctrica y la sustentación corresponde a los estudiantes. El uso de IA debe ajustarse a las reglas del docente y de la universidad; no sustituye el aprendizaje ni la experimentación real.

## Actualización H2 — diagramas editables

Se utilizó **ChatGPT (OpenAI)** para proponer y redactar la arquitectura del controlador HUB75E, el algoritmo de barrido, una máquina de estados, la temporización conceptual y una organización mínima de framebuffer RGB111. También ayudó a generar **dibujos editables `.drawio` y vistas previas PNG/SVG**, explicaciones Markdown y la estructura documental de evidencias.

Estos artefactos son **propuestas**, no RTL implementado ni resultados de simulación o medición. Los cálculos de refresco son ejemplos hipotéticos explícitos. El equipo debe contrastar la información contra el hardware, justificar los cambios, diseñar y ejecutar por sí mismo las verificaciones y registrar responsables individuales. No se ha confirmado el esquema físico de selección de filas del panel (`NC`).
