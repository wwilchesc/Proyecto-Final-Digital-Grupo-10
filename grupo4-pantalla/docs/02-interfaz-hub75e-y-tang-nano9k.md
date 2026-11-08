# 02 — HUB75E y compatibilidad con Tang Nano 9K

> Referencia de diseño, **no** pinout verificado del panel. El equipo aclaró que la fila está rotulada `C / NC`; la función eléctrica del contacto `NC` sigue pendiente de verificación. **No energizar** antes de confirmar polaridad de potencia y tensión nominal.

## 1. HUB75E no es SPI

Es una interfaz **paralela, síncrona y multiplexada** de datos RGB y selección de filas. Usa `CLK` para desplazar bits, `LAT` para cargarlos a la salida y `OE` para habilitar/apagar la iluminación. Las señales R/G/B se transmiten en dos bancos simultáneos (mitad superior e inferior). La placa debe refrescarse constantemente: un fotograma no queda retenido como en una pantalla SPI con memoria de imagen propia.

Secuencia **típica** (sujeta a verificar en este modelo):

1. `OE = 1` (salidas apagadas durante el cambio; OE activo bajo en HUB75 habitual).
2. Seleccionar una dirección de fila mediante las líneas **realmente disponibles**; el patrón convencional es `A...E`, pero la pareja `C / NC` difiere del estándar y requiere comprobación antes de asumir `D`.
3. Desplazar **64 columnas** mediante `CLK` mientras se presentan `R1/G1/B1` y `R2/G2/B2`.
4. Emitir pulso `LAT` con los datos estabilizados.
5. `OE = 0` durante un intervalo de iluminación controlado; después `OE = 1`.
6. Pasar a la siguiente dirección y repetir sin interrupción.

No asumir flancos ni tiempos absolutos para esta PCB sin documentación/medida. Algunas familias de controladores requieren inicialización o formato de señales específico.

## 2. Pinout de referencia HUB75E de 16 pines

| Pin estándar | Señal estándar | Función | Evidencia de nuestro PCB |
|---:|---|---|---|
| 1 | R1 | Datos rojo, mitad superior | R1 impreso |
| 2 | G1 | Verde superior | G1 impreso |
| 3 | B1 | Azul superior | B1 impreso |
| 4 | GND | Masa lógica | GND impreso |
| 5 | R2 | Rojo inferior | R2 impreso |
| 6 | G2 | Verde inferior | G2 impreso |
| 7 | B2 | Azul inferior | B2 impreso |
| 8 | E | Dirección más significativa, 1/32 | E impreso |
| 9 | A | Dirección | A impreso |
| 10 | B | Dirección | B impreso |
| 11 | C | Dirección estándar | Rótulo `C` confirmado por el equipo |
| **12** | **D** | Dirección estándar | **PCB rotula `NC` en este contacto (según el equipo); función eléctrica NO comprobada** |
| 13 | CLK | Reloj de desplazamiento | CLK impreso |
| 14 | LAT | Latch | LAT impreso |
| 15 | OE | Habilitación, normalmente activa baja | OE impreso |
| 16 | GND | Masa lógica | GND impreso |

**Numeración y orientación de cables: pendiente de verificar en la placa física.** El listado anterior compara la **convención** de HUB75E con las etiquetas físicas, no autoriza a deducir pin 1 mirando la fotografía desde atrás. El [pinout registrado del panel](06-pinout-fotografiado.md) conserva expresamente `NC` en vez de reemplazarlo por `D`.

Referencias: https://github.com/raspberrypi/pico-examples/blob/master/pio/hub75/Readme.md y https://www.waveshare.com/wiki/RGB-Matrix-P2.5-64x64

## 3. Recursos Tang Nano 9K

Documentación oficial de Sipeed para Tang Nano 9K: FPGA GW1NR-LV9QN88PC6/I5, cristal de **27 MHz**, **8640 LUT4**, **6480 FF**, **468 Kbits** de BSRAM y **dos PLL**.

- Documentación de la placa: https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html
- Esquemático oficial (enlace para consultar, no validado pin a pin aquí): https://dl.sipeed.com/fileList/TANG/Nano%209K/2_Schematic/Tang_Nano_9k_3672_Schematic.pdf

No inferir que todos los pines tienen la misma tensión: el esquemático de la placa distingue bancos y funciones dedicadas. **La selección exacta de GPIO y `.cst` es un entregable posterior**, tras contrastar voltajes de banco, pines libres, arranque/JTAG y periféricos utilizados por los demás equipos.

## 4. Riesgos eléctricos y adaptación de nivel

- Los módulos comparables son alimentados con **5 V**, pero **la corriente de 4 A se refiere a la ficha Waveshare**, no a una medida de nuestro módulo. No alimentar el panel desde USB ni desde un GPIO de Tang Nano 9K.
- Prever **fuente regulada independiente**, capacidad de corriente con margen, protección ante cortocircuito y cable de sección suficiente; validar la corriente real con instrumento adecuado.
- Conectar **masa de referencia común** entre la FPGA y el panel/adaptador; no unir 5 V directamente a GPIO 3,3 V.
- La compatibilidad de entradas de 3,3 V con un panel a 5 V **no se puede asumir**. Solución habitual: dos `SN74AHCT245` o equivalentes de entradas TTL compatibles, alimentados a 5 V, para convertir hasta 16 señales en dirección FPGA → panel. Validar tensión admitida, estado de alta impedancia, sentido de DIR, /OE y desacoplo con las hojas de datos del fabricante.
- La tarjeta adaptadora de Adafruit para HUB75 emplea `74AHCT245` para resolver esta interfaz de 3,3 V a 5 V: https://learn.adafruit.com/adafruit-triple-led-matrix-bonnet-for-raspberry-pi-with-hub75?view=all
- Ficha del buffer sugerido: https://www.ti.com/product/SN74AHCT245

## 5. Presupuesto de GPIO y RAM, sujeto a integración

- HUB75E típico: **6 datos RGB + 5 selección A...E + CLK/LAT/OE = 14 salidas**. En esta placa, la marca literal `C / NC` impide confirmar todavía el número de líneas de selección efectivas.
- **Framebuffer a 8 colores**, 3 bits RGB por píxel (una intensidad binaria por canal): **4096 × 3 = 12 288 bits ≈ 1,5 KiB** compactado; **4096 bytes = 4 KiB** si cada píxel se almacena en un byte, como el firmware anterior del grupo de juegos.
- **RGB888**: 4096 × 24 bits = **98 304 bits = 12 KiB**; requiere gestión de planos de bits/BCM o PWM, mayor ancho de banda y complejidad.
- No asignar memoria definitiva: la **BRAM es compartida** con CPU, instrucciones, pila, otros registros y FIFOs. La arquitectura de lectura simultánea debe acordarse: doble puerto real, arbitraje, buffer de línea o doble framebuffer.
- La base **propuesta** de MMIO del framebuffer es `0x480000` y la de control `0x4C0000`; **no se ha validado en SoC físico**. El README raíz presenta además detalles desactualizados de la plataforma y responsabilidades.

## 6. Distinción crucial entre relojes

- `CLK_FPGA`: oscilador de referencia **27 MHz** de Tang Nano 9K, sujeto a confirmar que esa sea la placa definitiva.
- `CLK_PANEL`: señal de desplazamiento hacia HUB75E, **derivada/controlada** por un generador síncrono; no necesariamente 27 MHz.
- `T_refresco`: periodo de todas las direcciones/bancos y, si se usa, de todos los planos de bits.
- `T_juego`: período de actualización del firmware, independiente del barrido de pantalla. El valor anterior de 150 ms es una **propuesta**, no una medición.

Para un panel convencional de 64 columnas y 32 direcciones por cuadro, sin planos de profundidad, hay **64 × 32 = 2048 pulsos de desplazamiento mínimos por barrido completo** (sin contar LAT, blanking y tiempo iluminado). No significa que pueda refrescarse a frecuencia `CLK_PANEL/2048` en la práctica: falta el tiempo de exhibición de cada línea y las restricciones del controlador real.

## 7. Dependencias antes de generar Verilog

- Confirmar mediante trazado o documentación qué representan `C / NC` y la posible señal `D` ausente; identificar el CI de selección de filas y los patrones de barrido.
- Confirmar frecuencia de refresco objetivo **medible**, ancho de bits RGB y política de brillo.
- Confirmar número y tipo de bancos de BRAM, latencia de lectura, interfaz MMIO real y acceso concurrente.
- Confirmar pines de salida y niveles de tensión de cada banco en `.cst`.
- Acordar un caso mínimo: color sólido fijo generado en hardware, **sin CPU ni framebuffer**, antes de integrar el sistema.
