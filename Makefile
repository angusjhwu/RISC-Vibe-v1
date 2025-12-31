#==============================================================================
# RISC-Vibe RV32I Processor - Makefile
#==============================================================================
# Simulation makefile for Icarus Verilog
#
# Targets:
#   make compile  - Compile the design and testbench
#   make sim      - Run the simulation
#   make wave     - Open waveforms in GTKWave
#   make clean    - Clean generated files
#   make all      - Compile and simulate
#   make help     - Show this help message
#
# Variables:
#   TESTPROG      - Path to test program hex file
#   MAX_CYCLES    - Maximum simulation cycles
#==============================================================================

#------------------------------------------------------------------------------
# Configuration Variables
#------------------------------------------------------------------------------
TESTPROG    ?= programs/test.hex
MAX_CYCLES  ?= 10000

#------------------------------------------------------------------------------
# Directory Structure
#------------------------------------------------------------------------------
RTL_DIR     := rtl
TB_DIR      := tb
SIM_DIR     := sim

#------------------------------------------------------------------------------
# Source Files
#------------------------------------------------------------------------------
# Package must be compiled first
RTL_PKG     := $(RTL_DIR)/riscvibe_pkg.sv
RTL_SRCS    := $(RTL_PKG) $(filter-out $(RTL_PKG),$(wildcard $(RTL_DIR)/*.sv))
TB_SRCS     := $(TB_DIR)/tb_riscvibe_top.sv

#------------------------------------------------------------------------------
# Output Files
#------------------------------------------------------------------------------
VVP_FILE    := $(SIM_DIR)/riscvibe.vvp
VCD_FILE    := $(SIM_DIR)/riscvibe.vcd

#------------------------------------------------------------------------------
# Tool Settings
#------------------------------------------------------------------------------
IVERILOG    := iverilog
VVP         := vvp
GTKWAVE     := gtkwave

# Icarus Verilog flags
IVFLAGS     := -g2012 -Wall -Wno-timescale
IVFLAGS     += -I $(RTL_DIR)
IVFLAGS     += -DTESTPROG_FILE=\"../$(TESTPROG)\"

#------------------------------------------------------------------------------
# Phony Targets
#------------------------------------------------------------------------------
.PHONY: all compile sim wave clean help dirs

#------------------------------------------------------------------------------
# Default Target
#------------------------------------------------------------------------------
all: compile sim

#------------------------------------------------------------------------------
# Create simulation directory
#------------------------------------------------------------------------------
dirs:
	@mkdir -p $(SIM_DIR)

#------------------------------------------------------------------------------
# Compile Target
#------------------------------------------------------------------------------
compile: dirs
	@echo "========================================"
	@echo "Compiling RISC-Vibe RV32I Processor"
	@echo "========================================"
	@echo "RTL Sources: $(RTL_SRCS)"
	@echo "TB Sources:  $(TB_SRCS)"
	@echo "Test Program: $(TESTPROG)"
	@echo "========================================"
	$(IVERILOG) $(IVFLAGS) -o $(VVP_FILE) $(RTL_SRCS) $(TB_SRCS)
	@echo "Compilation successful!"
	@echo ""

#------------------------------------------------------------------------------
# Simulation Target
#------------------------------------------------------------------------------
sim: $(VVP_FILE)
	@echo "========================================"
	@echo "Running Simulation"
	@echo "========================================"
	@echo "Test Program: $(TESTPROG)"
	@echo "Max Cycles:   $(MAX_CYCLES)"
	@echo "========================================"
	cd $(SIM_DIR) && $(VVP) riscvibe.vvp
	@echo ""
	@echo "Simulation complete!"
	@echo "Waveform saved to: $(VCD_FILE)"

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
	rm -rf $(SIM_DIR)
	@echo "Clean complete!"

#------------------------------------------------------------------------------
# Help Target
#------------------------------------------------------------------------------
help:
	@echo "RISC-Vibe RV32I Processor - Build System"
	@echo ""
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Compile and run simulation (default)"
	@echo "  compile  - Compile design and testbench"
	@echo "  sim      - Run simulation"
	@echo "  wave     - Open waveforms in GTKWave"
	@echo "  clean    - Remove generated files"
	@echo "  help     - Show this message"
	@echo ""
	@echo "Variables:"
	@echo "  TESTPROG=$(TESTPROG)"
	@echo "           Path to test program hex file"
	@echo ""
	@echo "  MAX_CYCLES=$(MAX_CYCLES)"
	@echo "           Maximum simulation cycles before timeout"
	@echo ""
	@echo "Examples:"
	@echo "  make                                    # Compile and simulate"
	@echo "  make compile                            # Just compile"
	@echo "  make sim TESTPROG=programs/add.hex      # Run specific test"
	@echo "  make sim MAX_CYCLES=50000               # Run with more cycles"
	@echo "  make wave                               # View waveforms"
	@echo ""

#------------------------------------------------------------------------------
# Dependency Rules
#------------------------------------------------------------------------------
$(VVP_FILE): $(RTL_SRCS) $(TB_SRCS) | dirs
	@$(MAKE) compile

$(VCD_FILE): $(VVP_FILE)
	@$(MAKE) sim
