#######################################################################
# Makefile - PRUEBA_2 (controlador HUB75 64x64) para Tang Nano 9K
# Flujo: Yosys -> nextpnr-himbaechel -> gowin_pack -> openFPGALoader
#python3 img2hexpp.py grinch_8_64x64.png
#######################################################################

# ---- Proyecto ----
TOP      ?= tang_nano_9k_top
CONSTR   ?= tang_nano_9k.cst
DESIGN   := framebuffer.v hub75_control.v hub75_datapath.v hub75_top.v tang_nano_9k_top.v
# Archivos de datos que el diseño lee con $readmemh (cambian -> se resintetiza)
DATA     := image.hex
# Testbench (solo simulación)
TB       ?= hub75_tb
TB_SRC   ?= hub75_tb.v

# ---- FPGA ----
FAMILY   := GW1N-9C
DEVICE   := GW1NR-LV9QN88PC6/I5
BOARD    := tangnano9k
FREQ_MHZ := 27

# ---- Herramientas ----
# Si existe el entorno del curso se activa solo; si no, se usan las del sistema.
# Forzar sin entorno: make RUN=
RUN      ?= $(shell command -v digital-logic-design >/dev/null 2>&1 && echo "source digital-logic-design activate &&")
SHELL    := /bin/bash
YOSYS    ?= yosys
NEXTPNR  ?= nextpnr-himbaechel
PACK     ?= gowin_pack
LOADER   ?= openFPGALoader
RM       := rm -rf

# ---- Archivos generados ----
BUILD_DIR := build
JSON      := $(BUILD_DIR)/$(TOP).json
PNR       := $(BUILD_DIR)/$(TOP)_pnr.json
BITSTREAM := $(BUILD_DIR)/$(TOP).fs
LOG_YOSYS := $(BUILD_DIR)/yosys-$(TOP).log
LOG_PNR   := $(BUILD_DIR)/nextpnr-$(TOP).log

.DEFAULT_GOAL := help
.PHONY: help all syn json pnr bitstream config config-sram config-flash \
        detect reset erase-flash sim wave log-syn log-pnr clean clean-syn

help:
	@echo ""
	@echo "## SINTESIS Y CONFIGURACION (Tang Nano 9K) ##"
	@echo "  make syn           -> Sintetizar (yosys + nextpnr + gowin_pack)"
	@echo "  make config        -> Sintetizar y cargar a la SRAM (se pierde al apagar)"
	@echo "  make config-flash  -> Sintetizar y grabar en flash (permanente)"
	@echo "  make detect        -> Detectar la FPGA"
	@echo "  make reset         -> Reiniciar la FPGA"
	@echo "  make erase-flash   -> Borrar la flash"
	@echo "  make sim           -> Simular con Icarus Verilog (debe imprimir PASS)"
	@echo "  make wave          -> Abrir la simulacion en GTKWave"
	@echo "  make log-syn       -> Ver log de Yosys"
	@echo "  make log-pnr       -> Ver log de nextpnr"
	@echo "  make clean         -> Borrar build/"
	@echo ""

all: syn
syn: bitstream

json: $(JSON)
pnr: $(PNR)
bitstream: $(BITSTREAM)

# 1. Sintesis con Yosys
$(JSON): $(DESIGN) $(DATA)
	mkdir -p $(BUILD_DIR)
	$(RUN) $(YOSYS) -p "synth_gowin -top $(TOP) -json $(JSON)" $(DESIGN) -l $(LOG_YOSYS)

# 2. Place & route con nextpnr (reloj de 27 MHz del pin 52)
$(PNR): $(JSON) $(CONSTR)
	$(RUN) $(NEXTPNR) --json $(JSON) --write $(PNR) --device $(DEVICE) \
		--vopt family=$(FAMILY) --vopt cst=$(CONSTR) --freq $(FREQ_MHZ) --log $(LOG_PNR)

# 3. Empaquetar bitstream
$(BITSTREAM): $(PNR)
	$(RUN) $(PACK) -c -d $(FAMILY) -o $(BITSTREAM) $(PNR)

# ---- Cargar a la FPGA ----
config: config-sram

config-sram: $(BITSTREAM)
	$(RUN) $(LOADER) -b $(BOARD) -m $(BITSTREAM)

config-flash: $(BITSTREAM)
	$(RUN) $(LOADER) -b $(BOARD) -f $(BITSTREAM)

detect:
	$(RUN) $(LOADER) --detect

reset:
	$(RUN) $(LOADER) -b $(BOARD) -r

erase-flash:
	$(RUN) $(LOADER) -b $(BOARD) --bulk-erase

# ---- Simulacion ----
SIM_SRC := framebuffer.v hub75_datapath.v hub75_control.v hub75_top.v $(TB_SRC)

sim: $(DATA)
	mkdir -p $(BUILD_DIR)
	$(RUN) iverilog -g2012 -Wall -s $(TB) -o $(BUILD_DIR)/$(TB) $(SIM_SRC)
	$(RUN) vvp $(BUILD_DIR)/$(TB)

wave: sim
	$(RUN) gtkwave $(TB).vcd &

# ---- Logs y limpieza ----
log-syn:
	less $(LOG_YOSYS)

log-pnr:
	less $(LOG_PNR)

clean clean-syn:
	$(RM) $(BUILD_DIR)
