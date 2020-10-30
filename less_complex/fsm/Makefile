TOP_MODULE := top

SV_SRC :=  \
	$(TOP_MODULE).sv \
	fsm.sv

SEED       ?=  1
NUM_CYCLES ?= 40

PLUSARGS := \
	+SEED=$(SEED) \
	+NUM_CYCLES=$(NUM_CYCLES)

# Simulate
sim: $(TOP_MODULE)
	vvp $(TOP_MODULE) -lxt2 $(PLUSARGS)

# Compile
$(TOP_MODULE): $(SV_SRC)
	iverilog -g2012 -o $(TOP_MODULE) $(SV_SRC)

clean:
	rm -rf $(TOP_MODULE)
	rm -rf dump.lx2
