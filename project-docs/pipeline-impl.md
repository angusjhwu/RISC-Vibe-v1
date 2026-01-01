# 5-Stage Pipeline Implementation Plan for RISC-Vibe

## Overview

This document details the implementation plan for converting the current 2-stage RISC-Vibe processor to a standard 5-stage pipeline (FDXMW: Fetch, Decode, Execute, Memory, Writeback).

## Current Architecture (2-Stage)

```
┌─────────────────────────────────────────────────────────────────┐
│ Stage 1: Instruction Fetch (IF)                                  │
│   - PC register → Instruction Memory → Instruction Register      │
└────────────────────────────────┬────────────────────────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────┐
│ Stage 2: Execute/Memory/Writeback (EX/MEM/WB)                    │
│   - Decode → Register Read → ALU → Memory → Register Write       │
│   - Simple forwarding from WB to EX                              │
│   - 1-cycle branch penalty (flush on taken branch)               │
└─────────────────────────────────────────────────────────────────┘
```

## Target Architecture (5-Stage)

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│   IF     │──▶│   ID     │──▶│   EX     │──▶│   MEM    │──▶│   WB     │
│  Fetch   │   │  Decode  │   │ Execute  │   │  Memory  │   │Writeback │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
     │              │              │              │              │
  IF/ID          ID/EX          EX/MEM         MEM/WB           │
  Reg            Reg            Reg            Reg              │
                                  │              │              │
                                  └──────────────┴──────────────┘
                                       Forwarding Paths
```

## Pipeline Stages

### Stage 1: Instruction Fetch (IF)
- **Inputs**: PC, branch_target, jalr_target, branch_taken, stall
- **Operations**:
  - Fetch instruction from IMEM at current PC
  - Calculate PC+4
  - Determine next PC (sequential, branch, or stall)
- **Outputs to IF/ID Register**:
  - `instruction` (32 bits)
  - `pc` (32 bits) - PC of fetched instruction
  - `pc_plus_4` (32 bits)
  - `valid` (1 bit) - false if bubble/flush

### Stage 2: Instruction Decode (ID)
- **Inputs**: IF/ID register, forwarded data
- **Operations**:
  - Decode opcode, funct3, funct7
  - Extract rs1, rs2, rd
  - Read register file
  - Generate immediate
  - Generate control signals
  - Detect hazards
  - **Branch decision (early branch)** - Optional optimization
- **Outputs to ID/EX Register**:
  - `pc` (32 bits)
  - `pc_plus_4` (32 bits)
  - `rs1_data` (32 bits)
  - `rs2_data` (32 bits)
  - `rs1_addr` (5 bits) - for forwarding
  - `rs2_addr` (5 bits) - for forwarding
  - `rd_addr` (5 bits)
  - `immediate` (32 bits)
  - `alu_op` (4 bits)
  - `alu_src_a` (1 bit)
  - `alu_src_b` (1 bit)
  - `mem_read` (1 bit)
  - `mem_write` (1 bit)
  - `mem_width` (3 bits)
  - `reg_write` (1 bit)
  - `reg_wr_src` (2 bits)
  - `branch_type` (2 bits)
  - `branch_cmp` (3 bits)
  - `valid` (1 bit)

### Stage 3: Execute (EX)
- **Inputs**: ID/EX register, forwarded data from EX/MEM and MEM/WB
- **Operations**:
  - Select ALU operands (with forwarding muxes)
  - Perform ALU operation
  - Calculate branch target
  - Evaluate branch condition
- **Outputs to EX/MEM Register**:
  - `pc_plus_4` (32 bits)
  - `alu_result` (32 bits)
  - `rs2_data` (32 bits) - for store
  - `rd_addr` (5 bits)
  - `mem_read` (1 bit)
  - `mem_write` (1 bit)
  - `mem_width` (3 bits)
  - `reg_write` (1 bit)
  - `reg_wr_src` (2 bits)
  - `branch_taken` (1 bit)
  - `branch_target` (32 bits)
  - `valid` (1 bit)

### Stage 4: Memory Access (MEM)
- **Inputs**: EX/MEM register
- **Operations**:
  - Perform load/store operations
  - Forward branch decision to IF stage
- **Outputs to MEM/WB Register**:
  - `pc_plus_4` (32 bits)
  - `alu_result` (32 bits)
  - `mem_read_data` (32 bits)
  - `rd_addr` (5 bits)
  - `reg_write` (1 bit)
  - `reg_wr_src` (2 bits)
  - `valid` (1 bit)

### Stage 5: Writeback (WB)
- **Inputs**: MEM/WB register
- **Operations**:
  - Select writeback data (ALU result, memory data, PC+4, immediate)
  - Write to register file

## Pipeline Registers

### IF/ID Register
```systemverilog
typedef struct packed {
    logic [31:0] instruction;
    logic [31:0] pc;
    logic [31:0] pc_plus_4;
    logic        valid;
} if_id_reg_t;
```

### ID/EX Register
```systemverilog
typedef struct packed {
    logic [31:0] pc;
    logic [31:0] pc_plus_4;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [4:0]  rs1_addr;
    logic [4:0]  rs2_addr;
    logic [4:0]  rd_addr;
    logic [31:0] immediate;
    alu_op_t     alu_op;
    logic        alu_src_a;
    logic        alu_src_b;
    logic        mem_read;
    logic        mem_write;
    logic [2:0]  mem_width;
    logic        reg_write;
    reg_wr_src_t reg_wr_src;
    branch_type_t branch_type;
    logic [2:0]  branch_cmp;
    logic        valid;
} id_ex_reg_t;
```

### EX/MEM Register
```systemverilog
typedef struct packed {
    logic [31:0] pc_plus_4;
    logic [31:0] alu_result;
    logic [31:0] rs2_data;     // Store data
    logic [4:0]  rd_addr;
    logic        mem_read;
    logic        mem_write;
    logic [2:0]  mem_width;
    logic        reg_write;
    reg_wr_src_t reg_wr_src;
    logic        valid;
} ex_mem_reg_t;
```

### MEM/WB Register
```systemverilog
typedef struct packed {
    logic [31:0] pc_plus_4;
    logic [31:0] alu_result;
    logic [31:0] mem_read_data;
    logic [4:0]  rd_addr;
    logic        reg_write;
    reg_wr_src_t reg_wr_src;
    logic        valid;
} mem_wb_reg_t;
```

## Data Hazards and Forwarding

### Types of Data Hazards

In a 5-stage pipeline, RAW (Read-After-Write) hazards can occur:

1. **EX Hazard**: Instruction in EX needs result from instruction in MEM
   - Distance: 1 instruction
   - Solution: Forward from EX/MEM register

2. **MEM Hazard**: Instruction in EX needs result from instruction in WB
   - Distance: 2 instructions
   - Solution: Forward from MEM/WB register

3. **Load-Use Hazard**: Instruction in EX needs result from LOAD in MEM
   - Distance: 1 instruction
   - Solution: **Cannot forward** - must stall 1 cycle

### Forwarding Unit Logic

```systemverilog
// ForwardA selects operand A for ALU
// 00 = ID/EX (no forwarding)
// 01 = MEM/WB (forward from writeback)
// 10 = EX/MEM (forward from memory stage)

// EX Hazard for rs1
if (ex_mem_reg_write &&
    (ex_mem_rd_addr != 0) &&
    (ex_mem_rd_addr == id_ex_rs1_addr))
    ForwardA = 2'b10;

// MEM Hazard for rs1 (only if no EX hazard)
else if (mem_wb_reg_write &&
         (mem_wb_rd_addr != 0) &&
         (mem_wb_rd_addr == id_ex_rs1_addr))
    ForwardA = 2'b01;

else
    ForwardA = 2'b00;

// Similar logic for ForwardB (rs2)
```

### Load-Use Hazard Detection (Stalling)

```systemverilog
// Detect load-use hazard: load in EX, dependent instruction in ID
stall = id_ex_mem_read &&
        (id_ex_rd_addr != 0) &&
        ((id_ex_rd_addr == if_id_rs1_addr) ||
         (id_ex_rd_addr == if_id_rs2_addr));

// When stall:
// 1. Hold PC (don't advance)
// 2. Hold IF/ID register (don't update)
// 3. Insert bubble in ID/EX (make control signals NOP)
```

## Control Hazards (Branches/Jumps)

### Branch Resolution

Branches are resolved in the **EX stage**. This means:
- 2 instructions after branch are fetched before we know if branch is taken
- Need to flush IF/ID and ID/EX if branch is taken

### Flush Logic

```systemverilog
// Flush when branch taken (detected in EX stage)
flush = branch_taken;

// When flush:
// 1. Clear IF/ID.valid (make instruction NOP)
// 2. Clear ID/EX.valid (make instruction NOP)
// 3. Update PC to branch target
```

### Branch Penalty

- Branch resolved in EX → 2 cycle penalty on taken branch
- Optimization: Move branch resolution to ID stage → 1 cycle penalty
- Further optimization: Branch prediction (future enhancement)

## Module Structure

### New/Modified Modules

```
rtl/
├── riscvibe_pkg.sv         # Add pipeline register types
├── riscvibe_5stage_top.sv  # NEW: 5-stage top module
├── pipeline_regs.sv        # NEW: Pipeline register module
├── forwarding_unit.sv      # NEW: Forwarding control
├── hazard_unit.sv          # NEW: Hazard detection & stall/flush
├── if_stage.sv             # NEW: Fetch stage
├── id_stage.sv             # NEW: Decode stage
├── ex_stage.sv             # NEW: Execute stage
├── mem_stage.sv            # NEW: Memory stage
├── wb_stage.sv             # NEW: Writeback stage
├── alu.sv                  # Unchanged
├── branch_unit.sv          # Unchanged
├── register_file.sv        # Unchanged
├── immediate_gen.sv        # Unchanged
├── control_unit.sv         # Unchanged
├── instruction_mem.sv      # Minor: remove output register
├── data_memory.sv          # Unchanged
└── program_counter.sv      # Simplified (just PC reg)
```

### Module Hierarchy

```
riscvibe_5stage_top
├── if_stage
│   ├── program_counter
│   └── instruction_mem
├── pipeline_regs (IF/ID)
├── id_stage
│   ├── control_unit
│   ├── register_file
│   └── immediate_gen
├── pipeline_regs (ID/EX)
├── ex_stage
│   ├── alu
│   └── branch_unit
├── pipeline_regs (EX/MEM)
├── mem_stage
│   └── data_memory
├── pipeline_regs (MEM/WB)
├── wb_stage
├── forwarding_unit
└── hazard_unit
```

## Implementation Order

### Phase 1: Core Pipeline Structure
1. Add pipeline register types to `riscvibe_pkg.sv`
2. Create `if_stage.sv` - Fetch stage
3. Create `id_stage.sv` - Decode stage
4. Create `ex_stage.sv` - Execute stage
5. Create `mem_stage.sv` - Memory stage
6. Create `wb_stage.sv` - Writeback stage
7. Create `riscvibe_5stage_top.sv` - Connect stages with pipeline regs

### Phase 2: Hazard Handling
8. Create `forwarding_unit.sv` - EX and MEM hazard forwarding
9. Create `hazard_unit.sv` - Load-use stalling + branch flushing
10. Integrate forwarding muxes in EX stage
11. Integrate stall/flush signals in pipeline regs

### Phase 3: Testing & Verification
12. Update testbench for 5-stage timing
13. Run all existing test programs
14. Create new hazard-specific test programs
15. Update assembler NOP insertion if needed

## Test Plan

### Test Cases

1. **Basic Sequential Execution**
   - `test_simple.S` - ADDI instructions
   - Verify correct pipeline timing

2. **ALU Operations**
   - `test_alu.S` - All ALU ops
   - Tests data dependencies

3. **Data Hazards - Forwarding**
   - Create `test_forward.S`:
     ```assembly
     addi x1, x0, 10    # Write x1
     addi x2, x1, 5     # EX hazard: read x1 immediately
     addi x3, x1, 3     # MEM hazard: read x1 after 1 cycle
     add  x4, x2, x3    # Both hazards
     ```

4. **Load-Use Hazard - Stalling**
   - Create `test_loaduse.S`:
     ```assembly
     sw   x5, 0(x0)     # Store value
     lw   x1, 0(x0)     # Load to x1
     addi x2, x1, 5     # Load-use: must stall
     ```

5. **Branch Instructions**
   - `test_fib.S` - Loops with branches
   - Verify correct flush on taken branches

6. **Complex Programs**
   - `test_bubblesort.S` - Stack, memory, branches
   - Full integration test

## Expected Timing Differences

### Current (2-Stage)
- CPI ≈ 1.0 for most instructions
- 1 cycle branch penalty
- Manual NOPs for hazards

### Target (5-Stage)
- CPI ≈ 1.0-1.2 depending on hazards
- 2 cycle branch penalty (without prediction)
- 1 cycle stall for load-use hazards
- No manual NOPs needed (forwarding handles most cases)

## Assembler Updates

The `riscvibe_asm` assembler has a `nop_inserter.py` module that is currently stubbed. After implementing the 5-stage pipeline:

1. **NOP insertion is generally NOT needed** for most hazards due to forwarding
2. **Load-use hazards** are handled by hardware stalling
3. **Branch hazards** are handled by hardware flushing
4. The assembler can remain unchanged or optionally:
   - Add `-O` flag to reorder instructions to reduce stalls
   - Add `-no-stall` flag to insert NOPs for load-use (for debugging)

## References

- [RISC-V Pipeline Hazards - Chipmunk Logic](https://chipmunklogic.com/digital-logic-design/designing-pequeno-risc-v-cpu-from-scratch-part-3-dealing-with-pipeline-hazards/)
- [RISC-V Pipeline Data Hazards - University of Freiburg](https://cca.informatik.uni-freiburg.de/riscv-simulator/datahazards.html)
- [5-Stage RISC-V Pipeline with Branch Predictor](https://github.com/steven3abc/Pipelined-RISC-V-like-CPU-with-Branch-Predictor)
- [Five-Stage RISC-V Pipeline Processor Verilog](https://github.com/pha123661/Five-Stage-RISC-V-Pipeline-Processor-Verilog)
- [RISC-V 32I 5-stage Pipeline Core](https://github.com/Varunkumar0610/RISC-V-32I-5-stage-Pipeline-Core)
