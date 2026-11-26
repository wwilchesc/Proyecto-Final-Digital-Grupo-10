// Reloj de 27 MHz de la Tang Nano 9K
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
