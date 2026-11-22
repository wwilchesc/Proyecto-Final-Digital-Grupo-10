# Simulacion del periferico SPI (Grupo 1). Uso: make sim  |  make ondas  |  make clean
RTL = ../rtl/perip_spi.v ../rtl/spi_control.v ../rtl/spi_datapath.v
TB  = perip_spi_tb.v flash_model.v

sim: perip_spi_tb.vvp
	vvp perip_spi_tb.vvp | tee perip_spi_tb.log

perip_spi_tb.vvp: $(TB) $(RTL)
	iverilog -g2012 -Wall -o $@ $(TB) $(RTL)

ondas: sim
	gtkwave perip_spi_tb.vcd

clean:
	rm -f perip_spi_tb.vvp perip_spi_tb.vcd

.PHONY: sim ondas clean
