RTL := rtl/perip_hub75_ctrl.v
TB  := sim/perip_hub75_ctrl_tb.v
BUILD := build
.PHONY: sim clean
sim:
	mkdir -p $(BUILD)
	iverilog -g2012 -Wall -s perip_hub75_ctrl_tb -o $(BUILD)/tb $(RTL) $(TB)
	vvp $(BUILD)/tb
clean:
	rm -rf $(BUILD) perip_hub75_ctrl_tb.vcd
