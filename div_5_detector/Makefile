TOP_MODULE := top

SV_SRC :=  \
	$(TOP_MODULE).sv \
	div_5_detector.sv

NUM_CYCLES ?= 40

PLUSARGS := +NUM_CYCLES=$(NUM_CYCLES)

compile: $(SV_SRC)
	iverilog -g2012 -o $(TOP_MODULE) $(SV_SRC)

sim: $(TOP_MODULE)
	vvp $(TOP_MODULE) -lxt2 $(PLUSARGS)

clean:
	rm -rf $(TOP_MODULE)
	rm -rf dump.lx2

all: clean compile sim
.PHONY: all

.DEFAULT_GOAL := all
