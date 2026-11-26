IVERILOG ?= iverilog
VVP ?= vvp
RTL := rtl/perip_hub75_ctrl.v rtl/framebuffer_rgb111.v rtl/hub75_control.v rtl/hub75_datapath.v rtl/perip_hub75.v
TB := sim/perip_hub75_tb.v
.PHONY: sim vcd clean
build/perip_hub75_tb: $(RTL) $(TB)
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s perip_hub75_tb -o $@ $(RTL) $(TB)
sim: build/perip_hub75_tb
	$(VVP) $<
vcd: build/perip_hub75_tb
	$(VVP) $< +vcd
clean:
	rm -rf build
