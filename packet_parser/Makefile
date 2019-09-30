TOP_MODULE := top

SV_SRC :=  \
	$(TOP_MODULE).sv \
	packet_parser.sv

SEED                  ?= 1
NUM_PKTS              ?= 5
MAX_PKT_SIZE_IN_BYTES ?= 100
RUN_BRINGUP_PKT       ?= 0

PLUSARGS := \
	+SEED=$(SEED) \
	+NUM_PKTS=$(NUM_PKTS) \
	+MAX_PKT_SIZE_IN_BYTES=$(MAX_PKT_SIZE_IN_BYTES) \
	+RUN_BRINGUP_PKT=$(RUN_BRINGUP_PKT)

# Simulate
sim: $(TOP_MODULE)
	vvp $(TOP_MODULE) -lxt2 $(PLUSARGS)

# Compile
$(TOP_MODULE): $(SV_SRC)
	iverilog -g2012 -o $(TOP_MODULE) $(SV_SRC)

clean:
	rm -rf $(TOP_MODULE)
	rm -rf dump.lx2
