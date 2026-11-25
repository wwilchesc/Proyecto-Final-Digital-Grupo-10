// Reloj de 50 MHz de la Tang Primer 25K
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
