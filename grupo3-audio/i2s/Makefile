# ==============================================================================
# Makefile para el proyecto Blink en Tang Nano 9K (Gowin GW1NR-9)
# ==============================================================================

top = top
DESIGN = top.v i2s_transmitter.v
tb = top_tb.v
CST = top.cst
DIR_BUILD = build

# Archivos intermedios y finales
JSON = $(DIR_BUILD)/$(top).json
PNR = $(DIR_BUILD)/$(top)_pnr.json
BITSTREAM = $(DIR_BUILD)/$(top).fs

# Configuración específica de la FPGA Gowin
DEVICE = GW1NR-LV9QN88PC6/I5
FAMILY = GW1N-9C
BOARD = tangnano9k

.PHONY: help syn sim wave config config-flash clean detect

help:
	@printf "\n## SÍNTESIS Y CONFIGURACIÓN (TANG NANO 9K) ##\n"
	@printf "\tmake syn\t\t-> Sintetizar diseño y generar bitstream (.fs)\n"
	@printf "\tmake config\t\t-> Configurar FPGA en SRAM (se borra al apagar)\n"
	@printf "\tmake config-flash\t-> Guardar el bitstream en memoria flash interna\n"
	@printf "\tmake detect\t\t-> Detectar la placa FPGA conectada por USB\n"
	@printf "\tmake sim\t\t-> Compilar y simular el diseño con iverilog\n"
	@printf "\tmake wave\t\t-> Ver formas de onda de la simulación\n"
	@printf "\tmake clean\t\t-> Limpiar directorio de compilación\n"
	@printf "\tmake erase\t\t-> Limpria la memoria fash\n"

# --- 1. SÍNTESIS E IMPLEMENTACIÓN ---
syn: $(BITSTREAM)

$(DIR_BUILD):
	mkdir -p $(DIR_BUILD)

$(JSON): $(DESIGN) | $(DIR_BUILD)
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
sim: | $(DIR_BUILD)
	iverilog -o $(DIR_BUILD)/$(top).vvp $(tb) $(DESIGN)
	cd $(DIR_BUILD) && vvp $(top).vvp

wave:
	gtkwave $(DIR_BUILD)/top_tb.vcd

# --- 4. LIMPIEZA ---
clean:
	rm -rf $(DIR_BUILD)

# --- 5. DETECCIÓN DE LA FPGA ---
detect:
	openFPGALoader -b $(BOARD) --detect
	# --- BORRAR MEMORIA FLASH ---
erase:
	openFPGALoader -b $(BOARD) --bulk-erase
	
rtl: | $(DIR_BUILD)
	yosys -p "read_verilog $(DESIGN); prep -top $(top); hierarchy -check; proc; write_json $(DIR_BUILD)/$(top).json"
	netlist2svg $(DIR_BUILD)/$(top).json -o $(DIR_BUILD)/$(top).svg
	eog $(DIR_BUILD)/$(top).svg || xdg-open $(DIR_BUILD)/$(top).svg
