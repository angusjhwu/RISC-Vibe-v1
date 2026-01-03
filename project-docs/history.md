# RISC-Vibe Development History

## Session 1: Initial Implementation

### User Request
Build a RISC-V processor from scratch called "RISC-Vibe" following the project plan in PLAN.md:
- Single-stage RV32I processor in SystemVerilog
- Supports RV32I base integer instruction set
- Follows standard RISC-V calling convention
- Framework for users to input and simulate RISC-V programs

### Actions Taken

#### 1. Project Setup
- Added official RISC-V ISA manual as git submodule from `git@github.com:riscv/riscv-isa-manual.git`
- Created project directory structure: `rtl/`, `tb/`, `programs/`
- Created implementation plan document

#### 2. ISA Research
- Used subagent to thoroughly research RV32I specification from official documentation
- Documented all instruction formats (R, I, S, B, U, J)
- Documented all 40 RV32I instructions with opcodes, funct3, funct7 fields
- Documented immediate encoding for each instruction type
- Documented register file requirements and PC handling

#### 3. Core Component Implementation
Created the following RTL modules in parallel using subagents:

**riscvibe_pkg.sv** - Package with:
- RV32I opcode definitions
- ALU operation encodings (alu_op_t enum)
- Branch comparison types (branch_cmp_t enum)
- Memory width types (mem_width_t enum)
- Control signal types (alu_src_t, reg_wr_src_t, mem_op_t, branch_type_t)

**alu.sv** - Arithmetic Logic Unit:
- 10 operations: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
- 32-bit operands and result
- Zero flag output for branch comparison

**register_file.sv** - Register File:
- 32 x 32-bit registers (x0-x31)
- x0 hardwired to zero
- Two asynchronous read ports
- One synchronous write port
- Active-low reset

**immediate_gen.sv** - Immediate Generator:
- Extracts and sign-extends immediates based on opcode
- Supports all immediate formats (I, S, B, U, J)

**control_unit.sv** - Control Unit:
- Decodes opcode, funct3, funct7 fields
- Generates ALU operation, source selects, write enables
- Generates memory and branch control signals

**branch_unit.sv** - Branch Unit:
- Compares rs1 and rs2 for branch conditions
- Supports BEQ, BNE, BLT, BGE, BLTU, BGEU
- Outputs branch_taken signal

**program_counter.sv** - Program Counter:
- Configurable reset vector
- Handles sequential, branch, JAL, and JALR targets
- Clears LSB for JALR alignment

**instruction_mem.sv** - Instruction Memory:
- ROM-style memory with hex file initialization
- Asynchronous read (combinational)
- Word-aligned addressing
- Returns NOP for out-of-bounds access

**data_memory.sv** - Data Memory:
- Byte-addressable memory array
- Little-endian byte ordering
- Supports LB, LH, LW, LBU, LHU (with sign/zero extension)
- Supports SB, SH, SW
- Synchronous write, asynchronous read

#### 4. Top-Level Integration
**riscvibe_top.sv** - Top Module:
- Instantiates all submodules
- Connects datapath signals
- Instruction field extraction
- Branch target calculation
- ALU input multiplexers
- Register write data selection

#### 5. Verification Infrastructure
**tb_riscvibe_top.sv** - Testbench:
- 100MHz clock generation (10ns period)
- Active-low reset sequence (5 cycles)
- Configurable max simulation cycles
- Per-cycle debug output (PC, instruction)
- Periodic register file dumps
- ECALL/EBREAK detection for simulation termination
- Pass/fail reporting based on x10 (a0) register
- VCD waveform dump for GTKWave

**Makefile** - Build System:
- `make compile` - Compile with Icarus Verilog (-g2012)
- `make sim` - Run simulation with vvp
- `make wave` - Open waveforms in GTKWave
- `make clean` - Remove generated files
- `make all` - Compile and simulate (default)
- Configurable TESTPROG variable for test program selection

#### 6. Test Programs Created
**test_simple.hex** - Basic ADDI test:
- ADDI x1, x0, 5
- ADDI x2, x0, 10
- ADDI x3, x0, 15
- NOP
- ECALL

**test_alu.hex** - Comprehensive ALU test:
- Tests ADDI with positive and negative immediates
- Tests ADD, SUB (R-type arithmetic)
- Tests ANDI, ORI, XORI (logical)
- Tests SLLI, SRLI, SRAI (shifts)
- Tests SLT, SLTU, SLTI (comparisons)
- NOP before ECALL

**test_add.hex** - Simple R-type test:
- ADDI x1, x0, 10
- ADDI x2, x0, 20
- ADD x4, x1, x2
- NOPs
- ECALL

### Bugs Found and Fixed

#### 1. Import Statement Syntax
**Issue**: Icarus Verilog doesn't support `import` statements outside module declarations.
**Fix**: Changed from:
```systemverilog
import riscvibe_pkg::*;
module foo (...);
```
To:
```systemverilog
module foo
  import riscvibe_pkg::*;
(...);
```

#### 2. Ternary Operator with Enum Types
**Issue**: Icarus Verilog requires explicit handling for ternary operators with enum types.
**Fix**: Changed ternary to if-else in control_unit.sv for SRL/SRA selection.

#### 3. Test Program Path
**Issue**: vvp runs from sim/ directory, so relative paths to programs/ didn't work.
**Fix**: Updated Makefile to pass `../programs/test.hex` and testbench to use correct relative path.

#### 4. Register Write Timing (Major)
**Issue**: In single-cycle design, register writes and PC updates happen at same clock edge. Due to combinational instruction memory, the instruction changes at the same time as the write, causing the wrong rd address to be used.

**Symptoms**:
- First instruction's write was lost
- Values written to wrong registers (off-by-one)

**Fix Applied**:
1. Added write-back pipeline registers (rd_wb, rd_data_wb, reg_write_wb) to delay writes by one cycle
2. Added forwarding logic to bypass pipeline register for RAW hazards

**Remaining Issue**: R-type instructions with data dependencies still show incorrect behavior. Sequential I-type instructions work correctly. This appears to be a simulation race condition at clock edges.

### Test Results

**test_simple.hex**: PASS
- x1 = 5, x2 = 10, x3 = 15 (all correct)

**test_alu.hex**: FAIL (partial)
- Some values incorrect due to data hazard timing issue

**test_add.hex**: FAIL
- R-type ADD result appears in wrong register

### Files Created
```
RiscVibe/
├── .gitmodules
├── Makefile
├── programs/
│   ├── test_add.hex
│   ├── test_alu.S
│   ├── test_alu.hex
│   └── test_simple.hex
├── project-docs/
│   ├── PLAN.md (original)
│   ├── implementation-plan.md
│   ├── history.md (this file)
│   └── riscv-isa-manual/ (submodule)
├── rtl/
│   ├── alu.sv
│   ├── branch_unit.sv
│   ├── control_unit.sv
│   ├── data_memory.sv
│   ├── immediate_gen.sv
│   ├── instruction_mem.sv
│   ├── program_counter.sv
│   ├── register_file.sv
│   ├── riscvibe_pkg.sv
│   └── riscvibe_top.sv
├── sim/ (generated, not committed)
│   ├── riscvibe.vcd
│   └── riscvibe.vvp
└── tb/
    └── tb_riscvibe_top.sv
```

### Git Commit
```
commit 5f4b1ca
Initial implementation of RISC-Vibe RV32I processor
- 20 files changed, 1976 insertions
```

### Known Issues for Future Work
1. ~~R-type instruction data hazard timing issue~~ (RESOLVED in Session 2)
2. Need to test branch instructions
3. Need to test load/store instructions
4. Consider switching to Verilator for more predictable simulation

### Commands Reference
```bash
# Compile and run default test
make all

# Run specific test program
make all TESTPROG=programs/test_simple.hex

# View waveforms
make wave

# Clean generated files
make clean
```

---

## Session 2: Timing Bug Fixes

### User Request
Continue from previous session to fix the remaining timing issues with R-type instructions and data hazards.

### Issues Identified and Fixed

#### 1. Program Counter Reset Glitch (Async Reset Issue)
**Issue**: The PC was using asynchronous reset (`negedge rst_n` in sensitivity list), which caused Icarus Verilog to spuriously update the PC when reset was released (posedge of rst_n).

**Symptoms**:
- PC jumped from 0x00 to 0x04 immediately when rst_n went high, without waiting for a clock edge
- First instruction at PC=0x00 was effectively skipped

**Fix**: Changed PC to use synchronous reset (only `posedge clk` in sensitivity list).

```systemverilog
// Before (broken)
always_ff @(posedge clk or negedge rst_n) begin

// After (fixed)
always_ff @(posedge clk) begin
```

#### 2. Instruction Memory Timing (Combinational to Synchronous)
**Issue**: Combinational instruction memory caused race conditions between PC updates and instruction reads at the same clock edge.

**Fix**: Made instruction memory synchronous (registered output). This creates a clean 2-stage pipeline:
- Stage 1 (IF): Instruction memory captures PC and reads instruction
- Stage 2 (EX): Decode, execute, memory, writeback using the registered instruction

```systemverilog
// Before (combinational)
always_comb begin
    instruction = mem[word_addr];
end

// After (synchronous)
always_ff @(posedge clk) begin
    instruction <= mem[word_addr];
end
```

#### 3. Write-back Pipeline and Forwarding
**Issue**: With synchronous IMEM, there's a 1-cycle delay between instruction fetch and execution. This creates RAW (Read-After-Write) hazards when consecutive instructions have data dependencies.

**Fix**: Added write-back pipeline registers and forwarding logic:
- Pipeline registers delay the write by one cycle
- Forwarding logic bypasses the register file when reading a register that's about to be written

```systemverilog
// Pipeline registers
always_ff @(posedge clk) begin
    rd_wb        <= rd;
    rd_data_wb   <= rd_data;
    reg_write_wb <= reg_write;
end

// Forwarding
assign rs1_data = (reg_write_wb && (rd_wb != 5'b0) && (rd_wb == rs1))
                  ? rd_data_wb : rs1_data_raw;
```

#### 4. Register File Write Timing
**Issue**: Register file was using negative edge writes (negedge clk) which was inconsistent with the new pipelined design.

**Fix**: Changed back to positive edge writes, consistent with the pipeline register timing.

#### 5. Test Program Encoding Errors
**Issue**: Several test program hex files had incorrect instruction encodings.

**Examples**:
- SUB x5, x2, x1 was encoded as ADDI x5, x2, 0x401 (wrong opcode)
- ADD x4 was using wrong rd field
- SRLI x11 had wrong shift amount
- SLT x13 had wrong rs1 field

**Fix**: Regenerated all test hex files with correct RISC-V encodings.

### Test Results After Fixes

**test_simple.hex**: PASS
- x1 = 5, x2 = 10, x3 = 15 (all correct)

**test_add.hex**: PASS
- x1 = 10, x2 = 20, x4 = 30 (all correct)

**test_alu.hex**: All values correct
- All 15 register values match expected (x1-x15)
- Note: Test reports "FAIL" because a0 ≠ 0, but this is expected since test_alu doesn't set a0 to indicate pass/fail

### Architecture Summary (After Fixes)

The processor is now a proper 2-stage pipeline:

```
            ┌─────────────────────────────────────────────┐
            │                  CYCLE N                     │
            └─────────────────────────────────────────────┘
                      ▼
    ┌─────────────────────────────────────────────────────┐
    │  STAGE 1 (IF): IMEM captures PC, registers instr    │
    └─────────────────────────────────────────────────────┘
                      │
                      │ (registered instruction)
                      ▼
    ┌─────────────────────────────────────────────────────┐
    │  STAGE 2 (EX/WB): Decode, Execute, Memory, Write    │
    │  - Forwarding handles RAW hazards                   │
    │  - Write-back to register file                      │
    └─────────────────────────────────────────────────────┘
```

### Files Modified
- `rtl/program_counter.sv` - Synchronous reset
- `rtl/instruction_mem.sv` - Synchronous read
- `rtl/register_file.sv` - Posedge write
- `rtl/riscvibe_top.sv` - Pipeline registers and forwarding
- `tb/tb_riscvibe_top.sv` - Simplified debug output
- `programs/test_alu.hex` - Fixed encodings
- `programs/test_add.hex` - Fixed encodings

---

## Session 3: Branch Instructions and Fibonacci Test

### User Request
Create a Fibonacci test program to verify branch instructions work correctly.

### Issues Identified and Fixed

#### 1. Pipeline Flush on Branch (Control Hazard)
**Issue**: When a branch is taken, the instruction already fetched from the wrong path was still being executed.

**Symptoms**:
- After branch, the instruction at the old PC+4 would execute before the target instruction
- Caused incorrect register writes during loops

**Fix**: Added `flush_pipeline` signal in `riscvibe_top.sv`:
- Register `branch_taken` for one cycle
- Use `flush_pipeline` to suppress register writes and memory operations
- Prevents the "delay slot" instruction from affecting program state

```systemverilog
// Pipeline flush logic
always_ff @(posedge clk) begin
    flush_pipeline <= branch_taken;
end

// Suppress register write on flush
reg_write_wb <= reg_write && !flush_pipeline;

// Suppress memory operations on flush
.mem_read   (mem_read && !flush_pipeline),
.mem_write  (mem_write && !flush_pipeline),
```

#### 2. Branch Instruction Encoding Errors
**Issue**: Manual hex encoding had several errors in the Fibonacci program.

**Examples**:
- `add x3, x1, x2` was 0x002080b3 (rd=1) instead of 0x002081b3 (rd=3)
- `add x1, x0, x2` was 0x000100b3 (wrong rs1/rs2) instead of 0x002000b3
- `add x2, x0, x3` was 0x00018133 instead of 0x00300133
- `bne x4, x0, offset` had rs1=x8 instead of rs1=x4

**Fix**: Created Python encoder script to generate correct instruction encodings.

#### 3. Data Hazard with Branch Comparison
**Issue**: The 2-stage pipeline has a 2-cycle latency from instruction decode to register write-back. Branch comparison reads register values before they're written.

**Symptoms**:
- Branch condition evaluated with stale register values
- Loops didn't iterate correctly

**Fix**: Added 2 NOPs before branch instruction to allow the comparison register (x4) to be written back before the branch reads it.

### Test Program Created

**test_fib.S / test_fib.hex** - Fibonacci Sequence:
- Computes F(1) through F(10) = 1, 1, 2, 3, 5, 8, 13, 21, 34, 55
- Uses loop with BNE instruction
- Verifies F(10) = 55
- Sets x10 = 0 for PASS

```assembly
    addi x1, x0, 1      # F(1) = 1
    addi x2, x0, 1      # F(2) = 1
    addi x4, x0, 8      # counter = 8
loop:
    add  x3, x1, x2     # F(n) = F(n-2) + F(n-1)
    add  x1, x0, x2     # F(n-2) = F(n-1)
    add  x2, x0, x3     # F(n-1) = F(n)
    addi x4, x4, -1     # counter--
    nop                 # hazard mitigation
    nop                 # hazard mitigation
    bne  x4, x0, loop   # if counter != 0, loop
    addi x11, x0, 55    # expected = 55
    sub  x10, x3, x11   # result = F(10) - 55 (0 if correct)
    nop
    ecall
```

### Test Results

**test_fib.hex**: PASS
- x1 = 34 (F(9))
- x2 = 55 (F(10))
- x3 = 55 (F(10))
- x4 = 0 (loop counter exhausted)
- x10 = 0 (PASS)
- x11 = 55 (expected value)

**test_simple.hex**: PASS
**test_add.hex**: PASS
**test_alu.hex**: PASS (all values correct)

### Architecture Update

The processor now properly handles control hazards with a 1-cycle branch penalty:

```
    Cycle N:   Branch instruction decoded, branch_taken asserted
    Cycle N+1: Instruction from wrong path is flushed (no side effects)
    Cycle N+2: First instruction from correct target executes
```

### Files Created/Modified
- `programs/test_fib.S` - Fibonacci assembly with comments
- `programs/test_fib.hex` - Correctly encoded hex file
- `rtl/riscvibe_top.sv` - Added pipeline flush logic

### Known Issues for Future Work
1. ~~Branch instructions not working~~ (RESOLVED)
2. Data hazards require manual NOP insertion (no automatic stalling/forwarding for branches)
3. Need to test load/store instructions
4. Consider adding interlocking or full forwarding for branch source registers

---

## Session 4: PC Offset Fix and Bubble Sort Test

### User Request
Run a bubble sort program that uses stack-based memory, JAL jumps, and multiple branch types.

### Issues Identified and Fixed

#### 1. PC Offset for Branch/Jump Instructions (Critical Bug)
**Issue**: Branch and jump target calculations were using the wrong PC value. With synchronous IMEM, when an instruction executes, the PC register has already advanced to the next address. The branch_target was calculated as `pc + immediate`, but should be `instr_pc + immediate` where `instr_pc = pc - 4`.

**Symptoms**:
- JAL jumps went to wrong address (off by 4)
- Branch loops jumped to incorrect targets
- Program counter went to undefined values

**Root Cause**:
- In the 2-stage pipeline, when instruction at address X executes, PC shows X+4
- RISC-V branch offsets are relative to the instruction's own PC, not the next PC

**Fix**: Added `instr_pc` signal and updated all PC-relative calculations in `riscvibe_top.sv`:

```systemverilog
// Calculate actual instruction PC
assign instr_pc = pc - 32'd4;

// Branch target uses instruction PC
assign branch_target = instr_pc + immediate;

// AUIPC uses instruction PC
assign alu_operand_a = alu_src_a ? instr_pc : rs1_data;

// JAL/JALR return address uses instruction PC + 4
REG_WR_PC4: rd_data = instr_pc + 32'd4;
```

#### 2. Test Program Re-encoding
**Issue**: Previous test programs had branch offsets encoded for the (incorrect) pipelined PC. After fixing the RTL, they needed standard RISC-V encoding.

**Fix**: Updated `test_fib.hex` and `test_fib_max.hex` with correct branch encodings:
- BNE offset changed from -28 to -24 (standard offset from instruction address)
- Changed encoding from `fe0212e3` to `fe0214e3`

### Test Programs Created

**test_bubblesort.S / test_bubblesort.hex** - Bubble Sort:
- Sorts array {3, 5, 1, 2, 4} → {1, 2, 3, 4, 5}
- Uses stack-based memory allocation (sp initialized to 0x400)
- Uses JAL for unconditional jumps
- Uses BGE and BLT for conditional branches
- Nested loops (outer i loop, inner j loop)
- 73 instructions total

```assembly
    addi    sp, zero, 0x400     # Initialize stack pointer
    addi    sp, sp, -48         # Allocate stack frame
    sw      s0, 44(sp)          # Save frame pointer
    addi    s0, sp, 48          # Set up frame pointer
    # ... array initialization ...
    # ... nested sorting loops with j/bge/blt ...
    ecall                       # Terminate
```

**test_fib_max.S / test_fib_max.hex** - Maximum Fibonacci (from Session 3):
- Updated with corrected branch encoding
- Computes F(47) = 2,971,215,073 (largest 32-bit Fibonacci)

### Test Results

| Test | Cycles | Result | Notes |
|------|--------|--------|-------|
| test_simple | ~15 | PASS | Basic I-type |
| test_add | ~20 | PASS | R-type arithmetic |
| test_alu | ~50 | PASS | All ALU operations |
| test_fib | 69 | PASS | F(10) = 55 |
| test_fib_max | ~370 | PASS | F(47) = 2,971,215,073 |
| test_bubblesort | 419 | PASS | Array sorted correctly |

### Architecture Summary

The processor correctly implements standard RISC-V branch/jump semantics:

```
                    ┌─────────────────────────────────────────┐
  Instruction at X: │  branch_target = X + offset            │
                    │  return_addr   = X + 4                 │
                    └─────────────────────────────────────────┘

  Pipeline state when instruction X executes:
    - pc register shows X + 4 (next fetch address)
    - instr_pc = pc - 4 = X (actual instruction address)
    - All PC-relative calculations use instr_pc
```

### Files Created/Modified
- `rtl/riscvibe_top.sv` - Added instr_pc, fixed branch_target, alu_operand_a, and return address
- `programs/test_fib.hex` - Fixed branch encoding
- `programs/test_fib_max.hex` - Fixed branch encoding
- `programs/test_bubblesort.S` - New bubble sort assembly
- `programs/test_bubblesort.hex` - Compiled bubble sort

### Git Commits
```
3f9fd23 Fix PC offset for branches/jumps and add bubble sort test
9a39916 Add pipeline flush and Fibonacci test programs
```

### Known Issues for Future Work
1. ~~PC offset for branches incorrect~~ (RESOLVED)
2. Data hazards still require manual NOP insertion before branches
3. Load/store instructions tested via bubble sort (working)
4. Consider adding branch prediction or forwarding for branch source registers

---

## Session 5: RISC-V Assembler Implementation

### User Request
Build a modular Python3 assembler for all currently supported RV32I instructions. Design it to be extensible for future ISA expansion, with NOP insertion capability stubbed for future pipeline changes.

### Implementation

#### Package Structure
Created `riscvibe_asm/` Python package with modular design:

```
riscvibe_asm/
├── __init__.py        # Package exports
├── __main__.py        # CLI entry point
├── assembler.py       # Main two-pass assembler
├── encoder.py         # Instruction encoding for all formats
├── errors.py          # Custom exception types
├── instructions.py    # Extensible instruction definitions
├── nop_inserter.py    # Pipeline hazard handling (stubbed)
├── parser.py          # Assembly source tokenizer
├── pseudo.py          # Pseudo-instruction expansion
└── registers.py       # Register name mapping
```

#### Supported Instructions

**All 37 RV32I Base Instructions:**
- R-type: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
- I-type: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
- Load: LB, LH, LW, LBU, LHU
- Store: SB, SH, SW
- Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
- Jump: JAL, JALR
- Upper: LUI, AUIPC
- System: ECALL, EBREAK, FENCE

**19 Pseudo-Instructions:**
- NOP, LI, MV, NOT, NEG
- J, JR, RET, CALL
- BEQZ, BNEZ, BLEZ, BGEZ, BLTZ, BGTZ
- SEQZ, SNEZ, SLTZ, SGTZ

#### Key Features

1. **Two-Pass Assembly:**
   - Pass 1: Collect labels and compute addresses
   - Pass 2: Encode instructions with resolved symbols

2. **Label Support:**
   - Standard labels (e.g., `_start:`, `loop:`)
   - Local/GCC-style labels (e.g., `.L2:`, `.L6:`)

3. **Immediate Formats:**
   - Decimal: `10`, `-5`
   - Hexadecimal: `0x400`, `0xFF`
   - Binary: `0b1010`

4. **Memory Operand Syntax:**
   - `offset(register)` format for loads/stores
   - e.g., `lw a5, -24(s0)` or `sw s0, 44(sp)`

5. **Extensibility:**
   - Add new instructions to `instructions.py` with opcode/funct3/funct7/format
   - Encoder automatically handles encoding based on format type
   - `nop_inserter.py` ready for configurable pipeline hazard handling

#### Usage
```bash
python3 -m riscvibe_asm input.S -o output.hex      # Basic
python3 -m riscvibe_asm input.S -o output.hex -v   # Verbose
python3 -m riscvibe_asm input.S --listing          # Show listing
```

### Verification Results

Assembled all existing test programs and ran simulations:

| Test | Instructions | Result | Notes |
|------|-------------|--------|-------|
| test_alu.S | 16 | PASS | All ALU operations correct |
| test_fib.S | 14 | PASS | F(10) = 55 |
| test_bubblesort.S | 73 | PASS | Array sorted correctly |

The assembler produces byte-identical output to manually-encoded hex files (with minor differences in pseudo-instruction expansion, e.g., `mv` → `addi` vs `add`).

### Design Decisions

1. **Modular Architecture:** Each concern (parsing, encoding, pseudo-expansion) in separate module for maintainability and testing.

2. **Standard Pseudo-Instruction Expansion:** Following RISC-V specification:
   - `mv rd, rs` → `addi rd, rs, 0`
   - `li rd, imm` → `addi rd, x0, imm` (small) or `lui + addi` (large)
   - `nop` → `addi x0, x0, 0`

3. **NOP Insertion Stubbed:** The `nop_inserter.py` module is designed but not active, ready for when pipeline configuration changes require automatic hazard mitigation.

4. **Error Handling:** Custom exception types with line numbers and source context for debugging.

### Files Created
- `assembler.md` - Design document and plan
- `riscvibe_asm/` - Complete Python package (9 modules)

### Git Commit
```
3c1d196 Add modular RV32I assembler for RISC-Vibe processor
```

### Future Enhancements
1. Activate NOP insertion for automatic hazard handling
2. Add M extension (multiply/divide) when processor supports it
3. Add `.data` section support for initialized data
4. Add macro support

---

## Session 6: 5-Stage Pipeline Implementation

### User Request
Convert the existing 2-stage RISC-Vibe processor to a standard 5-stage pipeline (FDXMW: Fetch, Decode, Execute, Memory, Writeback) with full forwarding and hazard detection.

### Implementation Overview

Created a comprehensive 5-stage pipeline implementation with the following components:

#### New RTL Modules
1. **if_stage.sv** - Instruction Fetch stage
   - PC register and PC+4 calculation
   - Next PC mux (sequential, branch, JALR)
   - Embedded combinational instruction memory
   - Stall and flush support

2. **id_stage.sv** - Instruction Decode stage
   - Instruction field extraction
   - Control unit instantiation
   - Register file with WB-to-ID forwarding
   - Immediate generation
   - Bubble insertion on stall/flush

3. **ex_stage.sv** - Execute stage
   - Forwarding muxes for ALU operands
   - ALU source selection (register/PC, register/immediate)
   - Branch target calculation
   - JALR target calculation
   - Branch decision via branch unit

4. **mem_stage.sv** - Memory Access stage
   - Data memory instantiation
   - Load/store operations
   - Pass-through of control signals

5. **wb_stage.sv** - Writeback stage
   - Writeback data mux (ALU, memory, PC+4, immediate)
   - Register file write interface

6. **forwarding_unit.sv** - Data forwarding control
   - EX hazard detection (1-cycle distance)
   - MEM hazard detection (2-cycle distance)
   - Forward select signals for ALU operands

7. **hazard_unit.sv** - Hazard detection and control
   - Load-use hazard detection (requires stall)
   - Control hazard detection (branch taken)
   - Stall and flush signal generation

8. **riscvibe_5stage_top.sv** - Top-level module
   - Pipeline register instantiation
   - Stage interconnections
   - Hazard/forwarding unit integration

#### Package Updates
- Added pipeline register struct types (if_id_reg_t, id_ex_reg_t, ex_mem_reg_t, mem_wb_reg_t)
- Added forward_sel_t enumeration

### Key Design Decisions

1. **Forwarding Paths**:
   - EX-to-EX: Forward from EX/MEM register (ALU result)
   - MEM-to-EX: Forward from MEM/WB register (writeback data)
   - WB-to-ID: Forward from WB to ID stage (register file bypass)

2. **Hazard Handling**:
   - Load-use hazard: 1-cycle stall + bubble insertion
   - Control hazard: 2-cycle flush (IF and ID stages)
   - Stall signals only affect PC and IF/ID register
   - ID/EX register receives bubble on flush, not stall

3. **Branch Resolution**:
   - Branches resolved in EX stage
   - 2-cycle branch penalty for taken branches
   - Flush IF/ID and ID/EX on branch taken

4. **Pipeline Register Updates**:
   - IF/ID: Hold on stall, else update
   - ID/EX: Flush to bubble, else update (no stall)
   - EX/MEM: Flush to bubble on control hazard, else update
   - MEM/WB: Always update

### Testbench Updates
- Created tb_riscvibe_5stage.sv for 5-stage pipeline
- Pipeline stage monitoring and debug output
- Forwarding and hazard signal display
- Updated Makefile with 5-stage and 2-stage targets

### Test Results

| Test | 2-Stage Cycles | 5-Stage Cycles | Result |
|------|----------------|----------------|--------|
| test_fib.hex | 69 | 83 | PASS |
| test_bubblesort.hex | 419 | 565 | PASS |
| test_alu.hex | ~20 | 23 | PASS* |

*test_alu doesn't set x10=0 for pass; all register values are correct.

### Files Created
```
rtl/
├── if_stage.sv           # Instruction Fetch stage
├── id_stage.sv           # Instruction Decode stage
├── ex_stage.sv           # Execute stage
├── mem_stage.sv          # Memory stage
├── wb_stage.sv           # Writeback stage
├── forwarding_unit.sv    # Data forwarding control
├── hazard_unit.sv        # Hazard detection
└── riscvibe_5stage_top.sv # 5-stage top module

tb/
└── tb_riscvibe_5stage.sv  # 5-stage testbench

project-docs/
└── pipeline-impl.md       # Implementation plan document
```

### Files Modified
- rtl/riscvibe_pkg.sv - Added pipeline register types
- Makefile - Added 5-stage and 2-stage build targets

### Build Commands
```bash
# Build and simulate 5-stage pipeline (default)
make all TESTPROG=programs/test_fib.hex

# Build and simulate 2-stage pipeline (original)
make 2stage TESTPROG=programs/test_fib.hex
```

### Known Issues
1. test_fib_max.hex timing differs from 2-stage due to different hazard handling
2. Tests with manual NOPs for 2-stage may behave differently

### Architecture Diagram
```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│   IF     │──▶│   ID     │──▶│   EX     │──▶│   MEM    │──▶│   WB     │
│  Fetch   │   │  Decode  │   │ Execute  │   │  Memory  │   │Writeback │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
     │              │              │              │              │
  IF/ID          ID/EX          EX/MEM         MEM/WB           │
  Reg            Reg            Reg            Reg              │
     │              │                                           │
     │              └────────────┐                              │
     │                           │      ┌───────────────────────┘
     │              ┌────────────┴──────┴───────────────┐
     │              │       Forwarding Unit             │
     │              │  (EX-to-EX, MEM-to-EX, WB-to-ID)  │
     │              └───────────────────────────────────┘
     │                           │
     └──────────┐   ┌────────────┘
                │   │
           ┌────▼───▼─────┐
           │ Hazard Unit  │
           │ (stall/flush)│
           └──────────────┘
```

---

## Session 7: Comprehensive Hazard Verification

### User Request
"Verify more extensively the pipelined processor, by first listing all hazards possible in this ISA, then for each hazard scenario explain the hazard and design a testbench to verify functional correctness. First analyze and think hard about the scenarios, and write your plan in hazards_tb_impl.md"

### Analysis

Created comprehensive hazard analysis covering all scenarios in an RV32I 5-stage pipeline:

1. **Data Hazards (RAW Dependencies)**
   - EX-to-EX forwarding (1-cycle gap)
   - MEM-to-EX forwarding (2-cycle gap)
   - WB-to-ID forwarding (3-cycle gap, register bypass)
   - Back-to-back dependency chains
   - Multi-source dependencies

2. **Load-Use Hazards**
   - Load followed by dependent instruction (requires 1-cycle stall)
   - Chain loads (address dependency)
   - Load-store forwarding
   - Different load widths (LB, LBU, LH, LHU, LW)

3. **Control Hazards**
   - Conditional branches (all 6 types: BEQ, BNE, BLT, BGE, BLTU, BGEU)
   - JAL (unconditional jump with link)
   - JALR (indirect jump with link)
   - Branch with data dependency (forwarding to branch operands)

4. **Edge Cases**
   - x0 register (hardwired zero, no forwarding)
   - Self-modifying register operations
   - Long dependency chains
   - Interleaved independent chains

### Bug Discovered and Fixed

**Critical Bug:** JAL/JALR instructions were not saving their return address to the link register.

**Root Cause:** The `flush_ex` signal was incorrectly applied to the EX/MEM pipeline register when a branch was taken. This cleared the `reg_write` signal for the branch instruction itself, preventing JAL/JALR from writing their return address.

**Analysis:**
- When branch_taken is asserted, `flush_ex` was set by hazard_unit
- EX/MEM pipeline register had: `if (flush_ex) reg_write <= 0`
- This incorrectly cleared the branch instruction's reg_write, not the speculative instruction after it

**Fix:** Removed the `flush_ex` condition from the EX/MEM pipeline register. The branch instruction in EX stage should always proceed to MEM and WB stages to complete execution. The `flush_id` signal correctly handles clearing the speculatively fetched instructions in IF/ID and ID/EX registers.

**File Modified:** `rtl/riscvibe_5stage_top.sv`

### Test Programs Created

| Test File | Purpose |
|-----------|---------|
| test_hazard_ex_ex.S | EX/MEM→EX forwarding (1-cycle RAW) |
| test_hazard_mem_ex.S | MEM/WB→EX forwarding (2-cycle RAW) |
| test_hazard_load_use.S | Load-use hazard with stall |
| test_hazard_branch.S | All 6 branch types |
| test_hazard_jal.S | JAL with link address |
| test_hazard_jalr.S | JALR with forwarding |
| test_hazard_x0.S | x0 register edge cases |
| test_hazard_chain.S | Long dependency chains |
| test_hazard_comprehensive.S | Combined all scenarios |

### Test Results

All 12 tests passed (9 new hazard tests + 3 regression tests):

| Test | Result | Cycles | Key Verifications |
|------|--------|--------|-------------------|
| test_hazard_ex_ex | PASS | 35 | EX/MEM forwarding to rs1, rs2, both |
| test_hazard_mem_ex | PASS | 23 | MEM/WB forwarding, mixed paths |
| test_hazard_load_use | PASS | 39 | Load-use stall, chain loads |
| test_hazard_branch | PASS | 56 | All 6 branch conditions |
| test_hazard_jal | PASS | 25 | JAL link address saved correctly |
| test_hazard_jalr | PASS | 24 | JALR with forwarding |
| test_hazard_x0 | PASS | 31 | x0 writes ignored, no forwarding |
| test_hazard_chain | PASS | 35 | 8-instruction chain, self-modify |
| test_hazard_comprehensive | PASS | 84 | All hazard types combined |
| test_alu (regression) | PASS | 23 | Original ALU operations |
| test_fib (regression) | PASS | 83 | Fibonacci computation |
| test_bubblesort (regression) | PASS | 565 | Bubble sort algorithm |

### Files Created/Modified

```
programs/
├── test_hazard_ex_ex.S
├── test_hazard_mem_ex.S
├── test_hazard_load_use.S
├── test_hazard_branch.S
├── test_hazard_jal.S
├── test_hazard_jalr.S
├── test_hazard_x0.S
├── test_hazard_chain.S
└── test_hazard_comprehensive.S

project-docs/
└── hazards_tb_impl.md    # Comprehensive hazard analysis and verification plan

rtl/
└── riscvibe_5stage_top.sv  # Bug fix for EX/MEM flush
```

### Verification Checklist Completed

All forwarding, hazard, branch/jump, and edge case tests verified:
- 9 forwarding unit tests
- 9 hazard unit tests
- 8 branch/jump tests
- 6 edge case tests
- 4 combined scenario tests

---

## Session 8: Regression Test Automation and Testbench Cleanup

### User Request
1. Create a regression script to automate running all pipeline tests
2. Fix test_alu to conform to pass/fail convention
3. Clean up testbench to remove misleading pass/fail messages

### Implementation

#### 1. Regression Test Runner (regression_pipeline.py)

Created Python script to automate pipeline verification:

**Features:**
- Auto-discovers all test_hazard_*.hex and original test files
- Compiles and simulates each test via Makefile
- Parses register values from simulation output
- Validates against test-specific expected register values
- Generates detailed logs in sim/logs/
- Produces summary report in sim/regression_report.txt

**Usage:**
```bash
./regression_pipeline.py              # Run all tests
./regression_pipeline.py -v           # Verbose output
./regression_pipeline.py --test NAME  # Run specific test
./regression_pipeline.py --list       # List available tests
```

**Test Expectations:**
Each test has specific expected register values defined in `TEST_EXPECTATIONS` dictionary, allowing flexible validation beyond just x10=0.

#### 2. test_alu.S Fix

**Issue:** test_alu used x10 for shift result (40), but testbench expected x10=0 for pass.

**Fix:**
- Moved shift result from x10 to x16
- Added `addi x10, x0, 0` at end as pass indicator
- Updated regression expectations

#### 3. Testbench Simplification

**Problem:** Testbench had hardcoded x10=0 check that showed "TEST FAILED" for tests that don't use this convention, creating confusion.

**Design Decision:**
- Testbench should only run simulations and display state
- Pass/fail validation belongs in regression script which has test-specific expectations
- This is more scalable as tests can use any register values

**Changes to tb_riscvibe_5stage.sv:**
- Removed `check_result()` task with ASCII art pass/fail banners
- Replaced with simple `display_x10_summary()` showing "SIMULATION COMPLETE"
- Removed x10_value variable
- Updated header comments to reference regression script

### Test Results

All 12 tests pass:
```
test_alu                 PASS     23 cycles
test_bubblesort          PASS    565 cycles
test_fib                 PASS     83 cycles
test_hazard_branch       PASS     56 cycles
test_hazard_chain        PASS     35 cycles
test_hazard_comprehensive PASS    84 cycles
test_hazard_ex_ex        PASS     35 cycles
test_hazard_jal          PASS     25 cycles
test_hazard_jalr         PASS     24 cycles
test_hazard_load_use     PASS     39 cycles
test_hazard_mem_ex       PASS     23 cycles
test_hazard_x0           PASS     31 cycles
```

### Files Created/Modified

```
regression_pipeline.py       # New: Automated test runner
programs/test_alu.S          # Modified: x10=0 pass convention
programs/test_alu.hex        # Regenerated
tb/tb_riscvibe_5stage.sv     # Modified: Removed pass/fail logic
sim/logs/                    # Generated: Per-test logs
sim/regression_report.txt    # Generated: Summary report
```

### Git Commits
```
8ba0735 Fix test_alu to use x10=0 pass convention
16aa4c9 Remove pass/fail logic from testbench
```

### Architecture Decision

**Separation of Concerns:**
| Component | Responsibility |
|-----------|----------------|
| Testbench | Run simulation, dump registers, detect ECALL/EBREAK |
| Regression Script | Validate correctness with test-specific expectations |

This approach allows:
- Tests to use any registers for meaningful values
- Flexible per-test validation criteria
- Single source of truth for expected values
- Clean logs without misleading messages

---

## Session 9: Pipeline Visualizer Implementation

### User Request
Create an interactive simulator/visualizer that allows stepping through program execution cycle-by-cycle, showing pipeline stages, registers, hazards, and forwarding in real-time.

### Design Decisions

1. **Trace Format**: JSON Lines (.jsonl) instead of CSV
   - Better for nested/hierarchical data (pipeline registers have sub-fields)
   - Self-documenting field names
   - Easy to parse in any language

2. **GUI Framework**: Web-based (Python Flask + HTML/JS)
   - Cross-platform (works in any browser)
   - Zero installation friction
   - Rich visualization capabilities

3. **Port**: 5050 (default) to avoid conflict with macOS AirPlay on port 5000

### Implementation

#### 1. Trace Logger (rtl/trace_logger.sv)

SystemVerilog module that outputs JSON Lines format each cycle:
- Cycle count and all pipeline register contents
- Register file values (all 32 registers)
- Hazard signals (stall_if, stall_id, flush_id, flush_ex)
- Forwarding status (forward_a, forward_b)
- ALU operands and results
- Branch taken/target information

**JSON Output Format:**
```json
{"cycle":10,"if":{"pc":"0x00000028","instr":"0x00445593","valid":true},"id":{...},"ex":{...},"mem":{...},"wb":{...},"regs":["0x00000000",...],"hazard":{"stall_if":false,...},"forward":{"a":"NONE","b":"NONE"}}
```

#### 2. Disassembler (rtl/disasm.sv)

Package with function to decode RV32I instructions to assembly strings:
- All R-type, I-type, Load, Store, Branch, Jump, Upper, System instructions
- Proper immediate formatting (decimal for small, hex for large)
- Pseudo-instruction recognition (e.g., NOP)

#### 3. Testbench Updates (tb/tb_riscvibe_5stage.sv)

Added conditional trace logger instantiation:
- `TRACE_ENABLE` define controls inclusion
- Extracts register file values for trace logger
- Connects all pipeline signals

#### 4. Flask Backend (sim/visualizer/)

**Files created:**
- `app.py` - Flask application with REST API
- `trace_parser.py` - JSONL trace file parser with statistics
- `requirements.txt` - Python dependencies (flask>=2.3.0)

**API Endpoints:**
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Serve main HTML page |
| `/api/load` | POST | Upload trace file |
| `/api/cycle/<n>` | GET | Get cycle n state |
| `/api/cycles` | GET | Get total cycle count |
| `/api/stats` | GET | Get execution statistics |
| `/api/range/<start>/<end>` | GET | Get cycle range |

#### 5. Frontend (sim/visualizer/static/, templates/)

**Features:**
- 5-stage pipeline visualization with color coding
  - Green: valid instruction
  - Gray: bubble/invalid
  - Red: stalled
  - Orange: being flushed
- 32-register file display with change highlighting
- Playback controls (first, prev, play/pause, next, last)
- Direct cycle input and speed slider
- Hazard status indicators (stall/flush signals)
- Forwarding status (NONE/MEM/WB)
- Keyboard shortcuts (←, →, Space, Home, End)

#### 6. Makefile Updates

New targets:
- `make trace` - Compile and run with trace logging
- `make compile-trace` - Compile only with trace logger
- `make sim-trace` - Run simulation with trace output
- `make visualizer` - Start the visualizer web server

#### 7. Launch Script (run_visualizer.sh)

Shell script that:
- Creates Python virtual environment if needed
- Installs Flask dependency
- Starts the visualizer server

### Usage

```bash
# Generate a trace file
make trace TESTPROG=programs/test_fib.hex

# Start the visualizer
./run_visualizer.sh

# Open browser to http://localhost:5050
# Click "Load Trace" and select sim/trace.jsonl
# Use playback controls or keyboard to step through cycles
```

### Test Results

- Trace generation verified: 22 cycles for test_alu.hex
- JSON format validated: all lines parse correctly
- API endpoints tested:
  - `/api/load` returns `{"success":true,"cycles":22}`
  - `/api/cycles` returns `{"total":22}`
  - `/api/cycle/10` returns full cycle state
  - `/api/stats` returns `{"cpi":1.22,"stall_cycles":0,...}`
- Frontend renders correctly with all UI components

### Files Created

```
rtl/
├── trace_logger.sv           # JSON trace output module
└── disasm.sv                 # RV32I disassembler package

sim/visualizer/
├── __init__.py
├── app.py                    # Flask backend
├── trace_parser.py           # JSONL parser
├── requirements.txt          # Python dependencies
├── templates/
│   └── index.html            # Main page template
└── static/
    ├── css/
    │   └── style.css         # Stylesheet
    └── js/
        └── main.js           # Application logic

run_visualizer.sh             # Launch script
project-docs/simulator_impl.md # Detailed implementation plan
```

### Files Modified

```
tb/tb_riscvibe_5stage.sv      # Added trace logger instantiation
Makefile                      # Added trace/visualizer targets
```

### Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Simulation     │     │   Flask Server   │     │    Browser      │
│  (iverilog)     │────▶│  (trace_parser)  │────▶│  (JavaScript)   │
│                 │     │                  │     │                 │
│ trace_logger.sv │     │    REST API      │     │  Visualization  │
│ → trace.jsonl   │     │  /api/cycle/N    │     │  Controls       │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

### Documentation

Created comprehensive implementation plan in `project-docs/simulator_impl.md`:
- Design decisions and rationale
- Detailed file specifications
- 40 test cases covering all functionality
- Future enhancement ideas

---

## Session 10: Pipeline Visualizer Enhancements

### User Request
1. Add a hex/decimal toggle for the register file display
2. Improve pipeline stage readability by showing PC and disassembled RISC-V instructions consistently across all 5 stages

### Implementation

#### 1. Register Format Toggle

Added interactive toggle switch to switch register display between hexadecimal and decimal formats:

**Changes:**
- Added toggle switch HTML in `templates/index.html` (section header)
- Added `regDisplayHex` state variable in `main.js`
- Added `formatRegValue()` helper function for format conversion
- Added CSS styles for toggle switch (`.toggle-switch`, `.toggle-slider`)

#### 2. Pipeline Stage Readability Improvements

**Problem:** Each pipeline stage displayed different information, making it difficult to track instruction flow through the pipeline. The trace format didn't include PC/instruction for later stages (EX, MEM, WB).

**Solution:**

**A. RTL Changes (trace_logger.sv):**
- Added shadow pipeline registers to track PC and instruction through all stages:
  ```systemverilog
  logic [31:0] ex_pc_shadow, ex_instr_shadow;
  logic [31:0] mem_pc_shadow, mem_instr_shadow;
  logic [31:0] wb_pc_shadow, wb_instr_shadow;
  ```
- Shadow registers update each cycle, propagating values from IF/ID through the pipeline
- Updated JSON trace output to include `pc` and `instr` fields for EX, MEM, and WB stages

**B. JavaScript Disassembler (disasm.js):**
- Created complete RV32I disassembler in JavaScript
- Converts hex instruction to readable assembly (e.g., `0x00a00093` → `addi x1, x0, 10`)
- Supports all instruction types: R, I, S, B, U, J, SYSTEM, FENCE
- Proper immediate formatting and sign extension

**C. UI Updates:**
- Simplified stage layout with consistent structure:
  - PC display (compact hex, e.g., `0x0010`)
  - Disassembled instruction (e.g., `addi x1, x0, 10`)
  - Stage-specific detail (result for EX, memory op for MEM, writeback info for WB)
- Added CSS classes: `.stage-pc`, `.stage-asm`, `.stage-detail`
- Flushed instructions shown with strikethrough styling

### Files Created

```
sim/visualizer/static/js/disasm.js    # RV32I JavaScript disassembler
```

### Files Modified

```
rtl/trace_logger.sv                   # Added shadow registers for PC/instr tracking
sim/visualizer/templates/index.html   # Simplified stage layout, added format toggle
sim/visualizer/static/js/main.js      # Added disasm integration, format toggle handler
sim/visualizer/static/css/style.css   # Added stage-pc, stage-asm, toggle styles
```

### Trace Format Changes

Each stage now includes `pc` and `instr` fields:
```json
{
  "cycle": 3,
  "if": {"pc": "0x0000000c", "instr": "0x00208233", "valid": true},
  "id": {"pc": "0x00000008", "instr": "0xffb00193", ...},
  "ex": {"pc": "0x00000004", "instr": "0x01400113", ...},
  "mem": {"pc": "0x00000000", "instr": "0x00a00093", ...},
  "wb": {"pc": "0x00000000", "instr": "0x00000000", ...},
  ...
}
```

### Visual Improvements

Each pipeline stage now displays:
| Element | Description |
|---------|-------------|
| PC | Compact hex address (e.g., `0x0010`) |
| Assembly | Disassembled instruction (e.g., `addi x1, x0, 10`) |
| Detail | Stage-specific info (EX: result, MEM: R/W operation, WB: register write) |

This makes it easy to visually track each instruction as it flows through IF → ID → EX → MEM → WB.
