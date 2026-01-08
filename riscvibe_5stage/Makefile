#==============================================================================
# RISC-Vibe 5-Stage Pipeline - Makefile
#==============================================================================
# Simulation makefile for Icarus Verilog
#
# Targets:
#   make all      - Compile and simulate (default)
#   make compile  - Compile the design
#   make sim      - Run the simulation
#   make trace    - Compile and run with trace logging
#   make wave     - Open waveforms in GTKWave
#   make clean    - Clean generated files
#
# Variables:
#   PROGRAM       - Test program name (without .hex extension)
#   MAX_CYCLES    - Maximum simulation cycles
#==============================================================================

#------------------------------------------------------------------------------
# Configuration Variables
#------------------------------------------------------------------------------
PROGRAM     ?= test_alu
MAX_CYCLES  ?= 10000

#------------------------------------------------------------------------------
# Directory Structure
#------------------------------------------------------------------------------
RTL_DIR     := rtl
TB_DIR      := tb
PROG_DIR    := programs
SIM_DIR     := sim

#------------------------------------------------------------------------------
# Source Files
#------------------------------------------------------------------------------
RTL_PKG     := $(RTL_DIR)/riscvibe_pkg.sv

RTL_SRCS    := $(RTL_PKG) \
               $(RTL_DIR)/alu.sv \
               $(RTL_DIR)/branch_unit.sv \
               $(RTL_DIR)/control_unit.sv \
               $(RTL_DIR)/data_memory.sv \
               $(RTL_DIR)/immediate_gen.sv \
               $(RTL_DIR)/register_file.sv \
               $(RTL_DIR)/instruction_mem.sv \
               $(RTL_DIR)/program_counter.sv \
               $(RTL_DIR)/if_stage.sv \
               $(RTL_DIR)/id_stage.sv \
               $(RTL_DIR)/ex_stage.sv \
               $(RTL_DIR)/mem_stage.sv \
               $(RTL_DIR)/wb_stage.sv \
               $(RTL_DIR)/forwarding_unit.sv \
               $(RTL_DIR)/hazard_unit.sv \
               $(RTL_DIR)/riscvibe_5stage_top.sv

TB_SRCS     := $(TB_DIR)/tb_riscvibe_5stage.sv

TRACE_SRCS  := $(RTL_DIR)/trace_logger.sv $(RTL_DIR)/disasm.sv

#------------------------------------------------------------------------------
# Output Files
#------------------------------------------------------------------------------
VVP_FILE    := $(SIM_DIR)/riscvibe_5stage.vvp
VCD_FILE    := $(SIM_DIR)/riscvibe_5stage.vcd
TRACE_FILE  := $(SIM_DIR)/traces/$(PROGRAM)_trace.jsonl

#------------------------------------------------------------------------------
# Tool Settings
#------------------------------------------------------------------------------
IVERILOG    := iverilog
VVP         := vvp
GTKWAVE     := gtkwave

IVFLAGS     := -g2012 -Wall -Wno-timescale
IVFLAGS     += -I $(RTL_DIR)
IVFLAGS     += -DTESTPROG_FILE=\"../$(PROG_DIR)/$(PROGRAM).hex\"

#------------------------------------------------------------------------------
# Phony Targets
#------------------------------------------------------------------------------
.PHONY: all compile sim trace compile-trace sim-trace wave clean help dirs

#------------------------------------------------------------------------------
# Default Target
#------------------------------------------------------------------------------
all: compile sim

#------------------------------------------------------------------------------
# Create directories
#------------------------------------------------------------------------------
dirs:
	@mkdir -p $(SIM_DIR)/traces

#------------------------------------------------------------------------------
# Compile Target
#------------------------------------------------------------------------------
compile: dirs
	@echo "========================================"
	@echo "Compiling RISC-Vibe 5-Stage Pipeline"
	@echo "========================================"
	@echo "Test Program: $(PROG_DIR)/$(PROGRAM).hex"
	@echo "========================================"
	$(IVERILOG) $(IVFLAGS) -o $(VVP_FILE) $(RTL_SRCS) $(TB_SRCS)
	@echo "Compilation successful!"

#------------------------------------------------------------------------------
# Simulation Target
#------------------------------------------------------------------------------
sim: $(VVP_FILE)
	@echo "========================================"
	@echo "Running 5-Stage Pipeline Simulation"
	@echo "========================================"
	@echo "Test Program: $(PROGRAM)"
	@echo "========================================"
	cd $(SIM_DIR) && $(VVP) riscvibe_5stage.vvp
	@echo ""
	@echo "Simulation complete!"

#------------------------------------------------------------------------------
# Trace Generation Targets
#------------------------------------------------------------------------------
trace: compile-trace sim-trace

compile-trace: dirs
	@echo "========================================"
	@echo "Compiling with Trace Logger Enabled"
	@echo "========================================"
	@echo "Test Program: $(PROG_DIR)/$(PROGRAM).hex"
	@echo "========================================"
	$(IVERILOG) $(IVFLAGS) -DTRACE_ENABLE -o $(VVP_FILE) $(RTL_SRCS) $(TRACE_SRCS) $(TB_SRCS)
	@echo "Compilation successful!"

sim-trace: $(VVP_FILE)
	@echo "========================================"
	@echo "Running Simulation with Trace Logging"
	@echo "========================================"
	@echo "Test Program: $(PROGRAM)"
	@echo "========================================"
	cd $(SIM_DIR) && $(VVP) riscvibe_5stage.vvp
	@mv $(SIM_DIR)/trace.jsonl $(TRACE_FILE) 2>/dev/null || true
	@echo ""
	@echo "Trace saved to: $(TRACE_FILE)"

#------------------------------------------------------------------------------
# Waveform Viewer Target
#------------------------------------------------------------------------------
wave: $(VCD_FILE)
	@echo "Opening waveform viewer..."
	$(GTKWAVE) $(VCD_FILE) &

#------------------------------------------------------------------------------
# Clean Target
#------------------------------------------------------------------------------
clean:
	@echo "Cleaning generated files..."
	rm -f $(SIM_DIR)/*.vvp $(SIM_DIR)/*.vcd $(SIM_DIR)/traces/*.jsonl
	@echo "Clean complete!"

#------------------------------------------------------------------------------
# Help Target
#------------------------------------------------------------------------------
help:
	@echo "RISC-Vibe 5-Stage Pipeline - Build System"
	@echo ""
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Targets:"
	@echo "  all           - Compile and run simulation (default)"
	@echo "  compile       - Compile the design"
	@echo "  sim           - Run simulation"
	@echo "  trace         - Compile and run with trace logging"
	@echo "  wave          - Open waveforms in GTKWave"
	@echo "  clean         - Remove generated files"
	@echo "  help          - Show this message"
	@echo ""
	@echo "Variables:"
	@echo "  PROGRAM=$(PROGRAM)"
	@echo "           Test program name (without .hex)"
	@echo ""
	@echo "Examples:"
	@echo "  make                          # Compile and simulate test_alu"
	@echo "  make PROGRAM=test_fib sim     # Run Fibonacci test"
	@echo "  make PROGRAM=test_fib trace   # Generate trace for visualizer"
	@echo ""
