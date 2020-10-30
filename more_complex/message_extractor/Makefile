####################################################################
# Message Extractor Makefile
####################################################################

MIN_MSG_BYTES       ?= 8
MAX_MSG_BYTES       ?= 32
WIDTH_IN_DATA_BYTES ?= 8

RUN_BRINGUP_PKT ?= 1

IN_VALID_PROB ?= 100

SEED ?= 1

ifneq "$(and $(NUM_PKT),$(NUM_MSG_PER_PKT))" ""
	PLUSARG_NUM_PKT         := +NUM_PKT=$(NUM_PKT)
	PLUSARG_NUM_MSG_PER_PKT := +NUM_MSG_PER_PKT=$(NUM_MSG_PER_PKT)
else ifneq "$(and $(RUN_BRINGUP_PKT))" ""
	PLUSARG_RUN_BRINGUP_PKT := +RUN_BRINGUP_PKT=$(RUN_BRINGUP_PKT)
endif

ifneq "$(and $(IN_VALID_PROB))" ""
	PLUSARG_IN_VALID_PROB := +IN_VALID_PROB=$(IN_VALID_PROB)
endif

TOP_MODULE := top
DUT_MODULE := message_extractor

LIB := work

VLOG_SWITCHES := \
	-sv \
	-f $(DUT_MODULE).f \
	-suppress 2583

VSIM_SWITCHES := \
	-c \
	-wlf $(DUT_MODULE).wlf \
	-do sim.do \
	-sv_seed $(SEED)

MACROS := \
	+define+MIN_MSG_BYTES=$(MIN_MSG_BYTES) \
	+define+MAX_MSG_BYTES=$(MAX_MSG_BYTES) \
	+define+WIDTH_IN_DATA_BYTES=$(WIDTH_IN_DATA_BYTES)

PLUSARGS := \
	$(PLUSARG_NUM_PKT) \
	$(PLUSARG_NUM_MSG_PER_PKT) \
	$(PLUSARG_RUN_BRINGUP_PKT) \
	$(PLUSARG_IN_VALID_PROB)

all: sim

sim: $(LIB)
	vlog $(VLOG_SWITCHES) $(MACROS)
	vsim $(VSIM_SWITCHES) $(PLUSARGS) $(TOP_MODULE)

$(LIB):
	vlib $(LIB)

.PHONY: \
	waves \
	clean

waves:
	vsim -do wave_post.do -view $(DUT_MODULE).wlf

clean:
	rm -rf $(LIB)
	rm -rf $(DUT_MODULE).wlf
	rm -rf dump.vcd
	rm -rf transcript
	rm -rf rand_input_stimulus.txt
