# Simulacion de los perifericos del Grupo 1.
# Uso: make sim | make sim-i2c | make sim-mem | make sim-prueba | make todo | make ondas | make ondas-i2c | make clean
RTL_SPI = ../rtl/perip_spi.v ../rtl/spi_control.v ../rtl/spi_datapath.v
TB_SPI  = perip_spi_tb.v flash_model.v

RTL_I2C = ../rtl/perip_i2c.v ../rtl/i2c_control.v ../rtl/i2c_datapath.v
TB_I2C  = perip_i2c_tb.v eeprom_model.v

# ---- SPI ----
sim: perip_spi_tb.vvp
	vvp perip_spi_tb.vvp | tee perip_spi_tb.log

perip_spi_tb.vvp: $(TB_SPI) $(RTL_SPI)
	iverilog -g2012 -Wall -o $@ $(TB_SPI) $(RTL_SPI)

ondas: sim
	gtkwave perip_spi_tb.vcd

# ---- I2C ----
sim-i2c: perip_i2c_tb.vvp
	vvp perip_i2c_tb.vvp | tee perip_i2c_tb.log

perip_i2c_tb.vvp: $(TB_I2C) $(RTL_I2C)
	iverilog -g2012 -Wall -o $@ $(TB_I2C) $(RTL_I2C)

ondas-i2c: sim-i2c
	gtkwave perip_i2c_tb.vcd

# ---- Bloque completo (SPI + I2C por el bus del Quark) ----
RTL_MEM = ../rtl/memoria_externa.v $(RTL_SPI) $(RTL_I2C)
TB_MEM  = memoria_externa_tb.v flash_model.v eeprom_model.v

sim-mem: memoria_externa_tb.vvp
	vvp memoria_externa_tb.vvp | tee memoria_externa_tb.log

memoria_externa_tb.vvp: $(TB_MEM) $(RTL_MEM)
	iverilog -g2012 -Wall -o $@ $(TB_MEM) $(RTL_MEM)

# ---- Prueba en placa (fpga/prueba_grupo1.v) ----
sim-prueba: prueba_grupo1_tb.vvp
	vvp prueba_grupo1_tb.vvp | tee prueba_grupo1_tb.log

prueba_grupo1_tb.vvp: prueba_grupo1_tb.v flash_model.v eeprom_model.v ../fpga/prueba_grupo1.v $(RTL_MEM)
	iverilog -g2012 -Wall -o $@ prueba_grupo1_tb.v flash_model.v eeprom_model.v ../fpga/prueba_grupo1.v $(RTL_MEM)

# ---- Todos ----
todo: sim sim-i2c sim-mem sim-prueba

clean:
	rm -f perip_spi_tb.vvp perip_spi_tb.vcd perip_i2c_tb.vvp perip_i2c_tb.vcd memoria_externa_tb.vvp memoria_externa_tb.vcd prueba_grupo1_tb.vvp prueba_grupo1_tb.vcd

.PHONY: sim sim-i2c sim-mem sim-prueba todo ondas ondas-i2c clean
