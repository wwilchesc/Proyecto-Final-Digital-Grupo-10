# Grupo 2 · Joystick SPI

Receptor del Joystick: recibe las teclas que presiona el jugador y se las entrega al procesador.

## Integrantes

- Miguel Pardo
- Crsitian Silva
- Sebastian Ochoa
- Arturo Tello

## Qué hace este grupo

Nuestro grupo implementa el periférico de joystick analógico de la consola de videojuegos. Su función es leer la posición del joystick (ejes X e Y) y el estado de su pulsador, y dejar esa información disponible para el procesador FemtoRV, que la usa para controlar el juego (mover al personaje, navegar menús, etc.).

El joystick entrega dos voltajes analógicos, uno por eje, entre 0 y 3.3 V. Como la FPGA Tang Nano solo trabaja con señales digitales, usamos un conversor analógico-digital MCP3008 con 4 canales, donde la FPGA actúa como maestro y el MCP3008 como esclavo.

- Dispositivo(s): Joystick conectado a MCP3008
- Protocolo: SPI
- Dirección base en el mapa de memoria: `0x43_0000`

## Tareas

- [ ] 1. Estudiar el protocolo SPI y la trama del MCP3008
- [ ] 2. Caja negra + características
- [ ] 3. Bloques + señales
- [ ] 4. Diagrama de tiempos
- [ ] 5. Diagrama de flujo
- [ ] 6. Clasificación control/datapath
- [ ] 7. ASMD + tabla de transferencias
- [ ] 8. Arquitectura control/datapath
- [ ] 9. FSM
