# Processor Demo Implementation Plan

## Overview

This document details the implementation plan for demonstrating the RiscVibe visualizer with two processor configurations:
1. **5-stage pipeline** (current implementation in `./rtl`)
2. **Single-stage (single-cycle) processor** (original implementation from commit `5f4b1ca`)

The goal is to reorganize the codebase so each processor variant has its own directory with RTL, testbenches, and trace generation capabilities, allowing the visualizer to load architecture files and traces for either processor.

---

## 1. 5-Stage Processor Reorganization

### 1.1 Current State

The 5-stage processor files are currently in:
- **RTL:** `./rtl/` (20 SystemVerilog files)
- **Testbench:** `./tb/tb_riscvibe_5stage.sv`
- **Architecture file:** `./sim/visualizer/architectures/riscv_5stage.yaml`
- **Traces:** `./sim/*.jsonl`

### 1.2 Target Directory Structure

```
riscvibe_5stage/
├── rtl/
│   ├── riscvibe_pkg.sv           # Shared package (types, constants)
│   ├── riscvibe_5stage_top.sv    # Top-level module
│   ├── if_stage.sv               # Instruction Fetch
│   ├── id_stage.sv               # Instruction Decode
│   ├── ex_stage.sv               # Execute
│   ├── mem_stage.sv              # Memory Access
│   ├── wb_stage.sv               # Write Back
│   ├── forwarding_unit.sv        # Data forwarding
│   ├── hazard_unit.sv            # Hazard detection
│   ├── alu.sv                    # ALU
│   ├── branch_unit.sv            # Branch comparison
│   ├── control_unit.sv           # Instruction decode
│   ├── immediate_gen.sv          # Immediate extraction
│   ├── register_file.sv          # Register file
│   ├── instruction_mem.sv        # Instruction memory
│   ├── data_memory.sv            # Data memory
│   ├── program_counter.sv        # PC management
│   ├── disasm.sv                 # Disassembler (for traces)
│   └── trace_logger.sv           # JSON trace generation
├── tb/
│   └── tb_riscvibe_5stage.sv     # Testbench
├── programs/                      # Symlink to ../programs or copy
├── sim/
│   └── traces/                   # Generated trace files
├── architecture.yaml             # Architecture definition
└── Makefile                      # Build/sim targets
```

### 1.3 Implementation Steps

1. **Create directory structure**
   ```bash
   mkdir -p riscvibe_5stage/{rtl,tb,sim/traces}
   ```

2. **Move RTL files**
   - Move all `.sv` files from `./rtl/` to `./riscvibe_5stage/rtl/`
   - Update any include paths if necessary

3. **Move testbench**
   - Move `./tb/tb_riscvibe_5stage.sv` to `./riscvibe_5stage/tb/`

4. **Copy architecture file**
   - Copy `./sim/visualizer/architectures/riscv_5stage.yaml` to `./riscvibe_5stage/architecture.yaml`

5. **Create Makefile**
   - Adapt from root `./Makefile` for 5-stage specific build
   - Targets: `compile`, `sim`, `trace`, `clean`

6. **Link programs**
   - Create symlink: `ln -s ../programs riscvibe_5stage/programs`
   - Or copy test programs if modifications needed

### 1.4 Verification

- Run existing test programs through reorganized structure
- Verify trace generation works
- Load traces in visualizer with architecture file

---

## 2. Single-Stage Processor Recreation

### 2.1 Git History Analysis

The single-stage processor is from commit `5f4b1ca` (Initial implementation):

**Key characteristics:**
- **True single-cycle design** - All operations complete in one clock cycle
- **Combinational instruction memory** - Asynchronous read (unlike later 2-stage which has synchronous IMEM)
- Uses `riscvibe_top.sv` as top module
- Has write-back pipeline registers (timing fix, but conceptually single-cycle)
- Simple WB-to-decode forwarding
- No hazard unit
- No separate pipeline stage modules
- Uses `tb_riscvibe_top.sv` testbench

**Files from commit `5f4b1ca`:**
```
rtl/alu.sv
rtl/branch_unit.sv
rtl/control_unit.sv
rtl/data_memory.sv
rtl/immediate_gen.sv
rtl/instruction_mem.sv      # COMBINATIONAL read - key difference!
rtl/program_counter.sv
rtl/register_file.sv
rtl/riscvibe_pkg.sv
rtl/riscvibe_top.sv
tb/tb_riscvibe_top.sv
```

### 2.2 Target Directory Structure

```
riscvibe_1stage/
├── rtl/
│   ├── riscvibe_pkg.sv           # Package (from 5f4b1ca)
│   ├── riscvibe_1stage_top.sv    # Top-level module (renamed from riscvibe_top)
│   ├── alu.sv                    # ALU (from 5f4b1ca)
│   ├── branch_unit.sv            # Branch comparison (from 5f4b1ca)
│   ├── control_unit.sv           # Instruction decode (from 5f4b1ca)
│   ├── immediate_gen.sv          # Immediate extraction (from 5f4b1ca)
│   ├── register_file.sv          # Register file (from 5f4b1ca)
│   ├── instruction_mem.sv        # COMBINATIONAL instruction memory (from 5f4b1ca)
│   ├── data_memory.sv            # Data memory (from 5f4b1ca)
│   ├── program_counter.sv        # PC management (from 5f4b1ca)
│   ├── disasm.sv                 # Disassembler (copy from current)
│   └── trace_logger_1stage.sv    # JSON trace generation (new)
├── tb/
│   └── tb_riscvibe_1stage.sv     # Testbench (adapted from 5f4b1ca)
├── programs/                      # Symlink to ../programs
├── sim/
│   └── traces/                   # Generated trace files
├── architecture.yaml             # Architecture definition (new)
└── Makefile                      # Build/sim targets
```

### 2.3 Implementation Steps

#### Step 1: Extract RTL from Git History

```bash
# Create directory
mkdir -p riscvibe_1stage/{rtl,tb,sim/traces}

# Extract ALL RTL files from commit 5f4b1ca (the original single-cycle version)
git show 5f4b1ca:rtl/riscvibe_top.sv > riscvibe_1stage/rtl/riscvibe_1stage_top.sv
git show 5f4b1ca:rtl/riscvibe_pkg.sv > riscvibe_1stage/rtl/riscvibe_pkg.sv
git show 5f4b1ca:rtl/alu.sv > riscvibe_1stage/rtl/alu.sv
git show 5f4b1ca:rtl/branch_unit.sv > riscvibe_1stage/rtl/branch_unit.sv
git show 5f4b1ca:rtl/control_unit.sv > riscvibe_1stage/rtl/control_unit.sv
git show 5f4b1ca:rtl/immediate_gen.sv > riscvibe_1stage/rtl/immediate_gen.sv
git show 5f4b1ca:rtl/register_file.sv > riscvibe_1stage/rtl/register_file.sv
git show 5f4b1ca:rtl/instruction_mem.sv > riscvibe_1stage/rtl/instruction_mem.sv
git show 5f4b1ca:rtl/data_memory.sv > riscvibe_1stage/rtl/data_memory.sv
git show 5f4b1ca:rtl/program_counter.sv > riscvibe_1stage/rtl/program_counter.sv

# Copy disasm.sv from current (wasn't in original, needed for traces)
cp rtl/disasm.sv riscvibe_1stage/rtl/

# Extract testbench
git show 5f4b1ca:tb/tb_riscvibe_top.sv > riscvibe_1stage/tb/tb_riscvibe_1stage.sv
```

#### Step 2: Rename Top Module

Edit `riscvibe_1stage/rtl/riscvibe_1stage_top.sv`:
- Change `module riscvibe_top` to `module riscvibe_1stage_top`
- Keep all other logic identical

#### Step 3: Create Trace Logger for Single-Stage

Create `riscvibe_1stage/rtl/trace_logger_1stage.sv`:

The single-stage processor has a unique characteristic:
- **Single stage visible** - Instruction fetch, decode, execute, memory, and writeback all happen in one cycle
- From the visualizer perspective, we show one "stage" that does everything

Trace format per cycle:
```json
{
  "cycle": 1,
  "cpu": {
    "pc": "0x00400000",
    "instr": "0x00500093",
    "asm": "addi x1, x0, 5",
    "valid": true,
    "rd": 1,
    "rs1": 0,
    "rs2": 0,
    "rs1_data": "0x00000000",
    "rs2_data": "0x00000000",
    "alu_result": "0x00000005",
    "mem_read": false,
    "mem_write": false,
    "mem_addr": "0x00000000",
    "mem_data": "0x00000000",
    "rd_data": "0x00000005",
    "write": true,
    "branch_taken": false
  },
  "hazard": {},
  "forward": {
    "rs1": "NONE",
    "rs2": "NONE"
  },
  "regs": [0, 5, 0, ...]
}
```

**Trace Logger Implementation:**

```systemverilog
//==============================================================================
// Single-Stage Processor Trace Logger
//==============================================================================
// Generates JSON Lines trace output for the single-cycle RISC-V processor.
// Each line represents one clock cycle with complete processor state.
//==============================================================================

module trace_logger_1stage
  import riscvibe_pkg::*;
(
  input logic        clk,
  input logic        rst_n,
  input logic        trace_enable,

  // Processor state from top module
  input logic [31:0] pc,
  input logic [31:0] instruction,
  input logic [31:0] rs1_data,
  input logic [31:0] rs2_data,
  input logic [31:0] alu_result,
  input logic [31:0] mem_read_data,
  input logic [31:0] rd_data,
  input logic [4:0]  rd,
  input logic [4:0]  rs1,
  input logic [4:0]  rs2,
  input logic        reg_write,
  input logic        mem_read,
  input logic        mem_write,
  input logic        branch_taken,

  // Forwarding indicators
  input logic        fwd_rs1,
  input logic        fwd_rs2,

  // Register file state (directly connected)
  input logic [31:0] regs [0:31]
);

  // Cycle counter
  int cycle_count;

  // File handle
  int trace_file;

  // Disassembly string
  string asm_str;

  initial begin
    cycle_count = 0;
    if (trace_enable) begin
      trace_file = $fopen("trace.jsonl", "w");
    end
  end

  // Import disassembly function
  import "DPI-C" function string disasm(input logic [31:0] instr, input logic [31:0] pc);

  always_ff @(posedge clk) begin
    if (rst_n && trace_enable) begin
      cycle_count <= cycle_count + 1;

      // Get disassembly
      asm_str = disasm(instruction, pc);

      // Write JSON line
      $fwrite(trace_file, "{");
      $fwrite(trace_file, "\"cycle\":%0d,", cycle_count);

      // CPU state (single stage)
      $fwrite(trace_file, "\"cpu\":{");
      $fwrite(trace_file, "\"pc\":\"%08x\",", pc);
      $fwrite(trace_file, "\"instr\":\"%08x\",", instruction);
      $fwrite(trace_file, "\"asm\":\"%s\",", asm_str);
      $fwrite(trace_file, "\"valid\":true,");
      $fwrite(trace_file, "\"rd\":%0d,", rd);
      $fwrite(trace_file, "\"rs1\":%0d,", rs1);
      $fwrite(trace_file, "\"rs2\":%0d,", rs2);
      $fwrite(trace_file, "\"rs1_data\":\"%08x\",", rs1_data);
      $fwrite(trace_file, "\"rs2_data\":\"%08x\",", rs2_data);
      $fwrite(trace_file, "\"alu_result\":\"%08x\",", alu_result);
      $fwrite(trace_file, "\"mem_read\":%s,", mem_read ? "true" : "false");
      $fwrite(trace_file, "\"mem_write\":%s,", mem_write ? "true" : "false");
      $fwrite(trace_file, "\"rd_data\":\"%08x\",", rd_data);
      $fwrite(trace_file, "\"write\":%s,", reg_write ? "true" : "false");
      $fwrite(trace_file, "\"branch_taken\":%s", branch_taken ? "true" : "false");
      $fwrite(trace_file, "},");

      // Hazard (empty for single-stage)
      $fwrite(trace_file, "\"hazard\":{},");

      // Forwarding
      $fwrite(trace_file, "\"forward\":{");
      $fwrite(trace_file, "\"rs1\":\"%s\",", fwd_rs1 ? "WB" : "NONE");
      $fwrite(trace_file, "\"rs2\":\"%s\"", fwd_rs2 ? "WB" : "NONE");
      $fwrite(trace_file, "},");

      // Register file
      $fwrite(trace_file, "\"regs\":[");
      for (int i = 0; i < 32; i++) begin
        $fwrite(trace_file, "%0d", regs[i]);
        if (i < 31) $fwrite(trace_file, ",");
      end
      $fwrite(trace_file, "]");

      $fwrite(trace_file, "}\n");
    end
  end

  final begin
    if (trace_enable) begin
      $fclose(trace_file);
    end
  end

endmodule
```

#### Step 4: Create Architecture File

Create `riscvibe_1stage/architecture.yaml`:

```yaml
name: "riscv_1stage"
version: "1.0"
description: "Single-cycle RISC-V processor"

stages:
  - id: "cpu"
    name: "CPU"
    letter: "X"
    fields:
      - key: "pc"
        format: "hex_compact"
        class: "stage-pc"
      - key: "asm"
        format: "string"
        class: "stage-asm"
    detail_fields:
      - key: "alu_result"
        label: "ALU:"
        format: "hex_smart"
      - key: null
        label: "Writeback"
        format: "writeback"

hazards:
  stall_signals: []
  flush_signals: []

forwarding:
  enabled: true
  source_field: "forward"
  paths:
    - key: "rs1"
      label: "rs1"
      target_stage: "cpu"
      sources:
        - stage: "cpu"
          value: "WB"
          color: "#3498db"
    - key: "rs2"
      label: "rs2"
      target_stage: "cpu"
      sources:
        - stage: "cpu"
          value: "WB"
          color: "#3498db"

register_file:
  enabled: true
  source_field: "regs"
  count: 32
  width: 32

validation:
  required_top_level:
    - "cycle"
  required_per_stage:
    - "pc"
    - "valid"
```

#### Step 5: Adapt Testbench

Edit `riscvibe_1stage/tb/tb_riscvibe_1stage.sv`:
- Change DUT instantiation from `riscvibe_top` to `riscvibe_1stage_top`
- Add trace logger instantiation
- Connect trace logger to internal signals
- Update file paths

#### Step 6: Create Makefile

Create `riscvibe_1stage/Makefile`:

```makefile
# RiscVibe Single-Stage Pipeline Build System

IVERILOG = iverilog
VVP = vvp

RTL_DIR = rtl
TB_DIR = tb
PROG_DIR = programs
SIM_DIR = sim

RTL_FILES = \
    $(RTL_DIR)/riscvibe_pkg.sv \
    $(RTL_DIR)/alu.sv \
    $(RTL_DIR)/branch_unit.sv \
    $(RTL_DIR)/control_unit.sv \
    $(RTL_DIR)/immediate_gen.sv \
    $(RTL_DIR)/register_file.sv \
    $(RTL_DIR)/program_counter.sv \
    $(RTL_DIR)/instruction_mem.sv \
    $(RTL_DIR)/data_memory.sv \
    $(RTL_DIR)/disasm.sv \
    $(RTL_DIR)/trace_logger_1stage.sv \
    $(RTL_DIR)/riscvibe_1stage_top.sv

TB_FILE = $(TB_DIR)/tb_riscvibe_1stage.sv

# Default program
PROGRAM ?= test_alu

.PHONY: all compile sim trace clean

all: sim

compile:
	$(IVERILOG) -g2012 -o $(SIM_DIR)/riscvibe_1stage.vvp \
		-DIMEM_INIT_FILE=\"$(PROG_DIR)/$(PROGRAM).hex\" \
		$(RTL_FILES) $(TB_FILE)

sim: compile
	$(VVP) $(SIM_DIR)/riscvibe_1stage.vvp

trace: compile
	$(VVP) $(SIM_DIR)/riscvibe_1stage.vvp +trace
	mv trace.jsonl $(SIM_DIR)/traces/$(PROGRAM)_trace.jsonl

clean:
	rm -f $(SIM_DIR)/*.vvp $(SIM_DIR)/*.vcd $(SIM_DIR)/traces/*.jsonl
```

### 2.4 Test Applicability Analysis

Review each test program to determine if it applies to the single-stage processor:

| Test Program | 5-Stage | 1-Stage | Notes |
|--------------|---------|---------|-------|
| `test_alu.S` | Yes | Yes | Basic ALU ops - works on both |
| `test_fib.S` | Yes | Yes | Branches, memory ops - works on both |
| `test_fib_max.S` | Yes | Yes | Extended Fibonacci - works on both |
| `test_bubblesort.S` | Yes | Yes | Memory-intensive - works on both |
| `test_hazard_ex_ex.S` | Yes | **No** | Tests EX-to-EX forwarding (5-stage only) |
| `test_hazard_mem_ex.S` | Yes | **No** | Tests MEM-to-EX forwarding (5-stage only) |
| `test_hazard_load_use.S` | Yes | **No** | Tests load-use stall (5-stage only) |
| `test_hazard_branch.S` | Yes | **No** | 5-stage branch penalty test |
| `test_hazard_jal.S` | Yes | **No** | 5-stage jump timing test |
| `test_hazard_jalr.S` | Yes | **No** | 5-stage jump timing test |
| `test_hazard_x0.S` | Yes | Yes | x0 hardwired zero test - works on both |
| `test_hazard_chain.S` | Yes | **No** | Tests multi-cycle forwarding chains (5-stage only) |
| `test_hazard_comprehensive.S` | Yes | **No** | 5-stage hazard comprehensive test |

**Applicable tests for single-stage:** `test_alu`, `test_fib`, `test_fib_max`, `test_bubblesort`, `test_hazard_x0`

**Note:** The single-stage processor from commit `5f4b1ca` had a known issue with R-type instructions with data dependencies (mentioned in the commit message). The fix came in commit `273eb9d`. We need to verify which tests pass on the original single-stage version.

---

## 3. Assembler Considerations

### 3.1 Current Assembler Analysis

The current assembler (`./riscvibe_asm/`) generates standard RV32I machine code:
- `nop_inserter.py` has `PipelineConfig` class with configurable stages
- The assembler doesn't insert NOPs by default
- Machine code is valid for any RV32I processor

### 3.2 Assembler Strategy

**Recommendation:** Use the existing assembler as-is for both processors.

The assembler generates standard RV32I machine code that works on any compliant processor. The single-stage processor executes each instruction in one cycle with no pipeline hazards, so no special handling is needed.

**No changes to the assembler are required.**

---

## 4. Documentation Updates

### 4.1 Create User Guide

Create `./PROCESSORS.md`:

```markdown
# RiscVibe Processor Variants

## Overview

RiscVibe includes two processor implementations:
- **Single-stage (single-cycle)** (`riscvibe_1stage/`) - All operations in one clock cycle
- **5-stage pipeline** (`riscvibe_5stage/`) - Classic RISC pipelined design

## Directory Structure

```
RiscVibe/
├── riscvibe_1stage/          # Single-cycle processor
│   ├── rtl/                  # RTL source files
│   ├── tb/                   # Testbench
│   ├── sim/traces/           # Generated traces
│   ├── architecture.yaml     # Visualizer config
│   └── Makefile
├── riscvibe_5stage/          # 5-stage processor
│   ├── rtl/
│   ├── tb/
│   ├── sim/traces/
│   ├── architecture.yaml
│   └── Makefile
├── programs/                 # Shared test programs
├── riscvibe_asm/            # Assembler
└── sim/visualizer/          # Web visualizer
```

## Building and Running

### Single-Stage Processor

```bash
cd riscvibe_1stage
make PROGRAM=test_fib sim       # Run simulation
make PROGRAM=test_fib trace     # Generate trace
```

### 5-Stage Processor

```bash
cd riscvibe_5stage
make PROGRAM=test_fib sim       # Run simulation
make PROGRAM=test_fib trace     # Generate trace
```

## Using the Visualizer

1. Start the visualizer:
   ```bash
   ./run_visualizer.sh
   ```

2. Open http://localhost:5050 in your browser

3. Load architecture file:
   - For single-stage: `riscvibe_1stage/architecture.yaml`
   - For 5-stage: `riscvibe_5stage/architecture.yaml`

4. Load trace file:
   - For single-stage: `riscvibe_1stage/sim/traces/*.jsonl`
   - For 5-stage: `riscvibe_5stage/sim/traces/*.jsonl`

## Architecture Comparison

| Feature | Single-Stage | 5-Stage |
|---------|--------------|---------|
| Pipeline stages | 1 (CPU) | 5 (IF, ID, EX, MEM, WB) |
| Clock cycles per instruction | 1 | 1 (ideal), ~1.3 (with hazards) |
| Data forwarding | WB→decode | EX→EX, MEM→EX, WB→ID |
| Hazard detection | None needed | Load-use stall, branch flush |
| Branch penalty | 0 cycles | 2 cycles |
| Clock frequency | Lower (long critical path) | Higher (shorter stages) |
| Throughput | 1 IPC max | 1 IPC max (with forwarding) |
```

### 4.2 Update history.md

Add Session 14 entry documenting:
- Processor demo implementation
- Directory reorganization
- Single-stage processor recreation from commit `5f4b1ca`
- Architecture file creation
- Test applicability analysis

---

## 5. Verification Plan

### 5.1 Single-Stage Processor Verification

| Test | Expected Result | Verification Method |
|------|-----------------|---------------------|
| `test_alu` | x10 = 0 (pass) | Check register dump |
| `test_fib` | Correct Fibonacci sequence | Compare with 5-stage output |
| `test_bubblesort` | Sorted array | Memory dump comparison |
| Trace generation | Valid JSONL | Load in visualizer |
| Architecture loading | No validation errors | Visualizer accepts |

**Note:** The original single-stage processor (commit `5f4b1ca`) had timing issues with R-type data dependencies. We may need to apply the fix from commit `273eb9d` (register file positive edge writes) if tests fail.

### 5.2 5-Stage Processor Verification

| Test | Expected Result | Verification Method |
|------|-----------------|---------------------|
| All existing tests | Same results as before | Regression run |
| Trace generation | Valid JSONL | Load in visualizer |
| Architecture loading | No validation errors | Visualizer accepts |

### 5.3 Visualizer Integration Tests

1. Load single-stage architecture → Verify 1 stage displayed ("CPU")
2. Load single-stage trace → Verify data populates correctly
3. Load 5-stage architecture → Verify 5 stages displayed
4. Load 5-stage trace → Verify data populates correctly
5. Switch between architectures → Verify clean transition

---

## 6. Implementation Order

### Phase 1: 5-Stage Reorganization
1. [ ] Create `riscvibe_5stage/` directory structure
2. [ ] Move RTL files
3. [ ] Move testbench
4. [ ] Copy architecture file
5. [ ] Create Makefile
6. [ ] Verify existing tests pass
7. [ ] Verify trace generation

### Phase 2: Single-Stage Recreation
1. [ ] Create `riscvibe_1stage/` directory structure
2. [ ] Extract all RTL from git commit `5f4b1ca`
3. [ ] Rename top module to `riscvibe_1stage_top`
4. [ ] Copy disasm.sv from current codebase
5. [ ] Create trace logger for single-stage
6. [ ] Create architecture.yaml
7. [ ] Adapt testbench
8. [ ] Create Makefile

### Phase 3: Single-Stage Verification
1. [ ] Run applicable test programs
2. [ ] Fix any timing issues if needed (apply register file fix)
3. [ ] Verify trace generation
4. [ ] Load traces in visualizer
5. [ ] Fix any trace format issues

### Phase 4: Documentation
1. [ ] Create PROCESSORS.md guide
2. [ ] Update history.md
3. [ ] Git commit

---

## 7. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Single-stage RTL has timing bugs | High | May need to cherry-pick fixes from 273eb9d |
| Trace format incompatible with visualizer | Medium | Architecture file validation catches this |
| Test programs fail on single-stage | Low | Expected - some tests are 5-stage specific |
| Combinational IMEM causes simulation issues | Low | Original worked, should still work |

---

## 8. Success Criteria

1. **5-stage processor** builds and runs from `riscvibe_5stage/`
2. **Single-stage processor** builds and runs from `riscvibe_1stage/`
3. Both processors generate valid traces loadable in visualizer
4. Visualizer correctly displays different pipeline structures (1 stage vs 5 stages)
5. Documentation clearly explains how to use both variants
6. All changes committed to git with descriptive message

---

## 9. Key Differences: Single-Stage vs 5-Stage

### Single-Stage (commit `5f4b1ca`)
- **Instruction Memory:** Combinational (asynchronous read)
- **Execution:** All operations in one cycle
- **Forwarding:** WB-to-decode (for the next instruction)
- **No hazards:** Single-cycle means no pipeline hazards
- **Simple control:** No stall/flush logic needed

### 5-Stage (current)
- **Instruction Memory:** Synchronous (registered output)
- **Execution:** Split across 5 pipeline stages
- **Forwarding:** Multiple paths (EX→EX, MEM→EX, WB→ID)
- **Hazard detection:** Load-use stalls, branch flushes
- **Complex control:** Hazard unit manages pipeline bubbles
