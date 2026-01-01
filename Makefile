#==============================================================================
# RISC-Vibe RV32I Processor - Makefile
#==============================================================================
# Simulation makefile for Icarus Verilog
#
# Targets:
#   make all      - Compile and simulate 5-stage pipeline (default)
#   make compile  - Compile the 5-stage pipeline design
#   make sim      - Run the 5-stage pipeline simulation
#   make 2stage   - Compile and simulate original 2-stage pipeline
#   make wave     - Open waveforms in GTKWave
#   make clean    - Clean generated files
#   make help     - Show this help message
#
# Variables:
#   TESTPROG      - Path to test program hex file
#   MAX_CYCLES    - Maximum simulation cycles
#==============================================================================

#------------------------------------------------------------------------------
# Configuration Variables
#------------------------------------------------------------------------------
TESTPROG    ?= programs/test_alu.hex
MAX_CYCLES  ?= 10000

#------------------------------------------------------------------------------
# Directory Structure
#------------------------------------------------------------------------------
RTL_DIR     := rtl
TB_DIR      := tb
SIM_DIR     := sim

#------------------------------------------------------------------------------
# Source Files - 5-Stage Pipeline (Default)
#------------------------------------------------------------------------------
# Package must be compiled first
RTL_PKG     := $(RTL_DIR)/riscvibe_pkg.sv

# 5-stage pipeline modules
RTL_5STAGE  := $(RTL_PKG) \
               $(RTL_DIR)/alu.sv \
               $(RTL_DIR)/branch_unit.sv \
               $(RTL_DIR)/control_unit.sv \
               $(RTL_DIR)/data_memory.sv \
               $(RTL_DIR)/immediate_gen.sv \
               $(RTL_DIR)/register_file.sv \
               $(RTL_DIR)/if_stage.sv \
               $(RTL_DIR)/id_stage.sv \
               $(RTL_DIR)/ex_stage.sv \
               $(RTL_DIR)/mem_stage.sv \
               $(RTL_DIR)/wb_stage.sv \
               $(RTL_DIR)/forwarding_unit.sv \
               $(RTL_DIR)/hazard_unit.sv \
               $(RTL_DIR)/riscvibe_5stage_top.sv

TB_5STAGE   := $(TB_DIR)/tb_riscvibe_5stage.sv

# 2-stage pipeline modules (original)
RTL_2STAGE  := $(RTL_PKG) \
               $(RTL_DIR)/alu.sv \
               $(RTL_DIR)/branch_unit.sv \
               $(RTL_DIR)/control_unit.sv \
               $(RTL_DIR)/data_memory.sv \
               $(RTL_DIR)/immediate_gen.sv \
               $(RTL_DIR)/instruction_mem.sv \
               $(RTL_DIR)/program_counter.sv \
               $(RTL_DIR)/register_file.sv \
               $(RTL_DIR)/riscvibe_top.sv

TB_2STAGE   := $(TB_DIR)/tb_riscvibe_top.sv

# Default to 5-stage
RTL_SRCS    := $(RTL_5STAGE)
TB_SRCS     := $(TB_5STAGE)

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
.PHONY: all compile sim wave clean help dirs 2stage compile-2stage sim-2stage

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
# Compile Target (5-Stage Pipeline)
#------------------------------------------------------------------------------
compile: dirs
	@echo "========================================"
	@echo "Compiling RISC-Vibe 5-Stage Pipeline"
	@echo "========================================"
	@echo "RTL Sources: $(RTL_5STAGE)"
	@echo "TB Sources:  $(TB_5STAGE)"
	@echo "Test Program: $(TESTPROG)"
	@echo "========================================"
	$(IVERILOG) $(IVFLAGS) -o $(VVP_FILE) $(RTL_5STAGE) $(TB_5STAGE)
	@echo "Compilation successful!"
	@echo ""

#------------------------------------------------------------------------------
# Simulation Target (5-Stage Pipeline)
#------------------------------------------------------------------------------
sim: $(VVP_FILE)
	@echo "========================================"
	@echo "Running 5-Stage Pipeline Simulation"
	@echo "========================================"
	@echo "Test Program: $(TESTPROG)"
	@echo "Max Cycles:   $(MAX_CYCLES)"
	@echo "========================================"
	cd $(SIM_DIR) && $(VVP) riscvibe.vvp
	@echo ""
	@echo "Simulation complete!"
	@echo "Waveform saved to: $(VCD_FILE)"

#------------------------------------------------------------------------------
# 2-Stage Pipeline Targets (Original)
#------------------------------------------------------------------------------
2stage: compile-2stage sim-2stage

compile-2stage: dirs
	@echo "========================================"
	@echo "Compiling RISC-Vibe 2-Stage Pipeline"
	@echo "========================================"
	@echo "RTL Sources: $(RTL_2STAGE)"
	@echo "TB Sources:  $(TB_2STAGE)"
	@echo "Test Program: $(TESTPROG)"
	@echo "========================================"
	$(IVERILOG) $(IVFLAGS) -o $(VVP_FILE) $(RTL_2STAGE) $(TB_2STAGE)
	@echo "Compilation successful!"
	@echo ""

sim-2stage: $(VVP_FILE)
	@echo "========================================"
	@echo "Running 2-Stage Pipeline Simulation"
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
	@echo "  all           - Compile and run 5-stage pipeline (default)"
	@echo "  compile       - Compile 5-stage pipeline design"
	@echo "  sim           - Run 5-stage pipeline simulation"
	@echo "  2stage        - Compile and run original 2-stage pipeline"
	@echo "  compile-2stage- Compile 2-stage pipeline"
	@echo "  sim-2stage    - Run 2-stage pipeline simulation"
	@echo "  wave          - Open waveforms in GTKWave"
	@echo "  clean         - Remove generated files"
	@echo "  help          - Show this message"
	@echo ""
	@echo "Variables:"
	@echo "  TESTPROG=$(TESTPROG)"
	@echo "           Path to test program hex file"
	@echo ""
	@echo "  MAX_CYCLES=$(MAX_CYCLES)"
	@echo "           Maximum simulation cycles before timeout"
	@echo ""
	@echo "Examples:"
	@echo "  make                                    # Compile and simulate 5-stage"
	@echo "  make 2stage                             # Run original 2-stage pipeline"
	@echo "  make compile                            # Just compile 5-stage"
	@echo "  make sim TESTPROG=programs/test_fib.hex # Run specific test"
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
