# ==============================================================================
# Makefile para el proyecto Audio I2S (Pac-Man) en Tang Nano 9K (Gowin GW1NR-9)
# ==============================================================================

top       = top_test_hw
DESIGN    = top_test_hw.v i2s_melody_peripheral.v i2s_tx_core.v
MEM_FILE  = pacman_songs.mem
tb        = tb_i2s_melody.v
CST       = top.cst
DIR_BUILD = build

# Archivos intermedios y finales
JSON      = $(DIR_BUILD)/$(top).json
PNR       = $(DIR_BUILD)/$(top)_pnr.json
BITSTREAM = $(DIR_BUILD)/$(top).fs
VCD_FILE  = $(DIR_BUILD)/i2s_test.vcd

# Configuración específica de la FPGA Gowin
DEVICE = GW1NR-LV9QN88PC6/I5
FAMILY = GW1N-9C
BOARD  = tangnano9k

.PHONY: help syn sim wave config config-flash clean detect erase rtl

help:
	@printf "\n## SÍNTESIS Y CONFIGURACIÓN (TANG NANO 9K - AUDIO I2S) ##\n"
	@printf "\tmake syn\t\t-> Sintetizar diseño y generar bitstream (.fs)\n"
	@printf "\tmake config\t\t-> Configurar FPGA en SRAM (se borra al apagar)\n"
	@printf "\tmake config-flash\t-> Guardar el bitstream en memoria flash interna\n"
	@printf "\tmake detect\t\t-> Detectar la placa FPGA conectada por USB\n"
	@printf "\tmake sim\t\t-> Compilar y simular el diseño con iverilog\n"
	@printf "\tmake wave\t\t-> Ver formas de onda de la simulación (GTKWave)\n"
	@printf "\tmake rtl\t\t-> Generar diagrama RTL en SVG\n"
	@printf "\tmake clean\t\t-> Limpiar directorio de compilación\n"
	@printf "\tmake erase\t\t-> Limpiar la memoria flash\n"

# --- 1. SÍNTESIS E IMPLEMENTACIÓN ---
syn: $(BITSTREAM)

$(DIR_BUILD):
	mkdir -p $(DIR_BUILD)

$(JSON): $(DESIGN) $(MEM_FILE) | $(DIR_BUILD)
	yosys -p "synth_gowin -top $(top) -json $(JSON)" $(DESIGN)

$(PNR): $(JSON) $(CST)
	nextpnr-himbaechel --json $(JSON) --write $(PNR) --device $(DEVICE) --vopt cst=$(CST) --vopt family=$(FAMILY)

$(BITSTREAM): $(PNR)
	gowin_pack -d $(FAMILY) -o $(BITSTREAM) $(PNR)

# --- 2. PROGRAMACIÓN (openFPGALoader) ---
config: $(BITSTREAM)
	openFPGALoader -b $(BOARD) -m $(BITSTREAM)

config-flash: $(BITSTREAM)
	openFPGALoader -b $(BOARD) -f $(BITSTREAM)

# --- 3. SIMULACIÓN ---
sim: $(DESIGN) $(tb) $(MEM_FILE) | $(DIR_BUILD)
	cp $(MEM_FILE) $(DIR_BUILD)/
	iverilog -o $(DIR_BUILD)/sim_i2s.vvp $(tb) $(DESIGN)
	cd $(DIR_BUILD) && vvp sim_i2s.vvp

wave:
	gtkwave $(VCD_FILE) &

# --- 4. LIMPIEZA ---
clean:
	rm -rf $(DIR_BUILD)

# --- 5. DETECCIÓN Y BORRADO DE FLASH ---
detect:
	openFPGALoader -b $(BOARD) --detect

erase:
	openFPGALoader -b $(BOARD) --bulk-erase

# --- 6. ESQUEMÁTICO RTL ---
rtl: | $(DIR_BUILD)
	yosys -p "read_verilog $(DESIGN); prep -top $(top); hierarchy -check; proc; write_json $(DIR_BUILD)/$(top)_rtl.json"
	netlist2svg $(DIR_BUILD)/$(top)_rtl.json -o $(DIR_BUILD)/$(top).svg
	eog $(DIR_BUILD)/$(top).svg || xdg-open $(DIR_BUILD)/$(top).svg
