# RISC-Vibe Implementation Plan

## Overview
Single-stage RV32I processor implementation in SystemVerilog.

## Architecture

```
                    +------------------+
                    |   Instruction    |
                    |     Memory       |
                    +--------+---------+
                             |
                             v
+------------+      +--------+---------+      +------------+
|    PC      |----->|   Instruction    |----->|  Immediate |
|  Register  |      |     Fetch        |      |   Decoder  |
+-----+------+      +--------+---------+      +-----+------+
      ^                      |                      |
      |                      v                      |
      |             +--------+---------+            |
      |             |    Control       |            |
      |             |     Unit         |            |
      |             +--------+---------+            |
      |                      |                      |
      |                      v                      v
      |             +--------+---------+      +-----+------+
      |             |   Register       |<-----|    ALU     |
      +-------------|     File         |----->|            |
                    +--------+---------+      +-----+------+
                             |                      |
                             v                      v
                    +--------+---------+      +-----+------+
                    |     Data         |<---->|   Memory   |
                    |    Memory        |      |  Interface |
                    +------------------+      +------------+
```

## Module Hierarchy

```
riscvibe_top
├── program_counter
├── instruction_memory
├── instruction_decoder
├── immediate_generator
├── register_file
├── alu
├── control_unit
├── data_memory
└── branch_unit
```

## Implementation Phases

### Phase 1: Core Components
- [ ] ALU (Arithmetic Logic Unit)
- [ ] Register File (32 x 32-bit registers)
- [ ] Immediate Generator (all immediate formats)

### Phase 2: Control Logic
- [ ] Instruction Decoder
- [ ] Control Unit (control signal generation)
- [ ] Branch/Jump Unit

### Phase 3: Memory System
- [ ] Program Counter
- [ ] Instruction Memory
- [ ] Data Memory Interface

### Phase 4: Integration
- [ ] Top-level CPU module
- [ ] Datapath connections
- [ ] Control path connections

### Phase 5: Verification
- [ ] Individual module testbenches
- [ ] Integration tests
- [ ] RV32I compliance tests

## RV32I Instruction Summary

### Opcodes
| Opcode  | Type    | Instructions |
|---------|---------|--------------|
| 0x33    | R-type  | ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND |
| 0x13    | I-type  | ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI |
| 0x03    | I-type  | LB, LH, LW, LBU, LHU |
| 0x23    | S-type  | SB, SH, SW |
| 0x63    | B-type  | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| 0x37    | U-type  | LUI |
| 0x17    | U-type  | AUIPC |
| 0x6F    | J-type  | JAL |
| 0x67    | I-type  | JALR |
| 0x73    | I-type  | ECALL, EBREAK |
| 0x0F    | I-type  | FENCE |

### ALU Operations
| Operation | funct3 | funct7[5] | Description |
|-----------|--------|-----------|-------------|
| ADD/ADDI  | 000    | 0         | Addition |
| SUB       | 000    | 1         | Subtraction |
| SLL/SLLI  | 001    | 0         | Shift left logical |
| SLT/SLTI  | 010    | -         | Set less than (signed) |
| SLTU/SLTIU| 011    | -         | Set less than (unsigned) |
| XOR/XORI  | 100    | -         | Bitwise XOR |
| SRL/SRLI  | 101    | 0         | Shift right logical |
| SRA/SRAI  | 101    | 1         | Shift right arithmetic |
| OR/ORI    | 110    | -         | Bitwise OR |
| AND/ANDI  | 111    | -         | Bitwise AND |

## File Structure
```
RiscVibe/
├── rtl/
│   ├── riscvibe_pkg.sv      # Package with defines and types
│   ├── alu.sv               # Arithmetic Logic Unit
│   ├── register_file.sv     # 32x32 Register File
│   ├── immediate_gen.sv     # Immediate Generator
│   ├── control_unit.sv      # Control Signal Generator
│   ├── branch_unit.sv       # Branch Comparison Unit
│   ├── program_counter.sv   # PC Register
│   ├── instruction_mem.sv   # Instruction Memory
│   ├── data_memory.sv       # Data Memory
│   └── riscvibe_top.sv      # Top-level Module
├── tb/
│   ├── tb_alu.sv
│   ├── tb_register_file.sv
│   ├── tb_riscvibe_top.sv
│   └── ...
├── programs/
│   ├── test_alu.hex
│   ├── test_branches.hex
│   └── ...
└── project-docs/
    └── ...
```

## Verification Strategy
1. Unit tests for each module
2. Integration tests for datapath
3. Assembly test programs for instruction coverage
4. RISC-V compliance test suite (optional)

## Current Status (Phase 1 Complete)

### Implemented
- [x] Project structure and documentation
- [x] ALU with all RV32I operations
- [x] Register File (32x32-bit, x0 hardwired to 0)
- [x] Immediate Generator (all immediate formats)
- [x] Control Unit (all RV32I opcodes)
- [x] Branch Unit (all comparison types)
- [x] Program Counter
- [x] Instruction Memory (ROM-style with hex file loading)
- [x] Data Memory (byte-addressable, load/store support)
- [x] Top-level integration
- [x] Testbench infrastructure (Icarus Verilog)
- [x] Write-back pipeline register (for timing fix)
- [x] Data forwarding logic (RAW hazard handling)

### Known Issues
1. **Register Write Timing**: There's a subtle timing issue with data-dependent instructions.
   Sequential I-type instructions (ADDI) work correctly, but R-type instructions
   that read from recently-written registers show incorrect behavior. The root
   cause appears to be simulation race conditions at clock edges.

2. **Workaround**: Adding NOP instructions between dependent instructions resolves
   the issue temporarily.

### Next Steps
1. Debug and fix the R-type instruction data hazard
2. Add comprehensive test programs for all instruction types
3. Implement branch instruction tests
4. Add load/store tests
5. Consider switching to Verilator for more predictable simulation behavior