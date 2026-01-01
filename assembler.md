# RISC-Vibe Assembler Design Document

## Overview

This document describes the design of a modular Python3 assembler for the RISC-Vibe RV32I processor. The assembler converts RISC-V assembly source files (`.S`) into hex files (`.hex`) compatible with the processor's instruction memory.

## Supported Instructions

### Complete RV32I Base ISA

The assembler supports all 37 instructions from the RV32I base integer instruction set:

#### R-Type (Register-Register) - Opcode: 0x33
| Instruction | funct7  | funct3 | Operation |
|-------------|---------|--------|-----------|
| ADD         | 0x00    | 0b000  | rd = rs1 + rs2 |
| SUB         | 0x20    | 0b000  | rd = rs1 - rs2 |
| SLL         | 0x00    | 0b001  | rd = rs1 << rs2[4:0] |
| SLT         | 0x00    | 0b010  | rd = (rs1 < rs2) signed |
| SLTU        | 0x00    | 0b011  | rd = (rs1 < rs2) unsigned |
| XOR         | 0x00    | 0b100  | rd = rs1 ^ rs2 |
| SRL         | 0x00    | 0b101  | rd = rs1 >> rs2[4:0] (logical) |
| SRA         | 0x20    | 0b101  | rd = rs1 >> rs2[4:0] (arithmetic) |
| OR          | 0x00    | 0b110  | rd = rs1 \| rs2 |
| AND         | 0x00    | 0b111  | rd = rs1 & rs2 |

#### I-Type (Immediate) - Opcode: 0x13
| Instruction | funct3 | Operation |
|-------------|--------|-----------|
| ADDI        | 0b000  | rd = rs1 + imm[11:0] |
| SLTI        | 0b010  | rd = (rs1 < imm) signed |
| SLTIU       | 0b011  | rd = (rs1 < imm) unsigned |
| XORI        | 0b100  | rd = rs1 ^ imm |
| ORI         | 0b110  | rd = rs1 \| imm |
| ANDI        | 0b111  | rd = rs1 & imm |
| SLLI        | 0b001  | rd = rs1 << shamt[4:0] (funct7=0x00) |
| SRLI        | 0b101  | rd = rs1 >> shamt[4:0] (funct7=0x00) |
| SRAI        | 0b101  | rd = rs1 >> shamt[4:0] (funct7=0x20) |

#### Load Instructions - Opcode: 0x03
| Instruction | funct3 | Operation |
|-------------|--------|-----------|
| LB          | 0b000  | rd = sign_extend(mem[rs1+imm][7:0]) |
| LH          | 0b001  | rd = sign_extend(mem[rs1+imm][15:0]) |
| LW          | 0b010  | rd = mem[rs1+imm][31:0] |
| LBU         | 0b100  | rd = zero_extend(mem[rs1+imm][7:0]) |
| LHU         | 0b101  | rd = zero_extend(mem[rs1+imm][15:0]) |

#### Store Instructions - Opcode: 0x23
| Instruction | funct3 | Operation |
|-------------|--------|-----------|
| SB          | 0b000  | mem[rs1+imm][7:0] = rs2[7:0] |
| SH          | 0b001  | mem[rs1+imm][15:0] = rs2[15:0] |
| SW          | 0b010  | mem[rs1+imm][31:0] = rs2 |

#### Branch Instructions - Opcode: 0x63
| Instruction | funct3 | Operation |
|-------------|--------|-----------|
| BEQ         | 0b000  | if (rs1 == rs2) PC += imm |
| BNE         | 0b001  | if (rs1 != rs2) PC += imm |
| BLT         | 0b100  | if (rs1 < rs2) signed, PC += imm |
| BGE         | 0b101  | if (rs1 >= rs2) signed, PC += imm |
| BLTU        | 0b110  | if (rs1 < rs2) unsigned, PC += imm |
| BGEU        | 0b111  | if (rs1 >= rs2) unsigned, PC += imm |

#### Jump Instructions
| Instruction | Opcode | Type | Operation |
|-------------|--------|------|-----------|
| JAL         | 0x6F   | J    | rd = PC+4; PC += imm |
| JALR        | 0x67   | I    | rd = PC+4; PC = (rs1 + imm) & ~1 |

#### Upper Immediate Instructions
| Instruction | Opcode | Type | Operation |
|-------------|--------|------|-----------|
| LUI         | 0x37   | U    | rd = imm << 12 |
| AUIPC       | 0x17   | U    | rd = PC + (imm << 12) |

#### System Instructions - Opcode: 0x73
| Instruction | funct12 | Operation |
|-------------|---------|-----------|
| ECALL       | 0x000   | Environment call |
| EBREAK      | 0x001   | Breakpoint |

#### Fence Instruction - Opcode: 0x0F
| Instruction | Operation |
|-------------|-----------|
| FENCE       | Memory ordering (NOP in this implementation) |

### Pseudo-Instructions
| Pseudo | Expansion |
|--------|-----------|
| NOP    | ADDI x0, x0, 0 |
| LI rd, imm | ADDI rd, x0, imm (for -2048 <= imm <= 2047) |
|            | LUI rd, upper + ADDI rd, rd, lower (for larger imm) |
| MV rd, rs | ADDI rd, rs, 0 |
| NOT rd, rs | XORI rd, rs, -1 |
| NEG rd, rs | SUB rd, x0, rs |
| J offset | JAL x0, offset |
| JR rs | JALR x0, rs, 0 |
| RET | JALR x0, x1, 0 |
| CALL offset | JAL x1, offset |
| BEQZ rs, offset | BEQ rs, x0, offset |
| BNEZ rs, offset | BNE rs, x0, offset |
| BLEZ rs, offset | BGE x0, rs, offset |
| BGEZ rs, offset | BGE rs, x0, offset |
| BLTZ rs, offset | BLT rs, x0, offset |
| BGTZ rs, offset | BLT x0, rs, offset |

## Instruction Encoding Formats

```
R-type:  [funct7(7) | rs2(5) | rs1(5) | funct3(3) | rd(5) | opcode(7)]
I-type:  [imm[11:0](12) | rs1(5) | funct3(3) | rd(5) | opcode(7)]
S-type:  [imm[11:5](7) | rs2(5) | rs1(5) | funct3(3) | imm[4:0](5) | opcode(7)]
B-type:  [imm[12](1) | imm[10:5](6) | rs2(5) | rs1(5) | funct3(3) | imm[4:1](4) | imm[11](1) | opcode(7)]
U-type:  [imm[31:12](20) | rd(5) | opcode(7)]
J-type:  [imm[20](1) | imm[10:1](10) | imm[11](1) | imm[19:12](8) | rd(5) | opcode(7)]
```

## Architecture Design

The assembler is designed with modularity and extensibility in mind:

```
riscvibe_asm/
├── __init__.py
├── assembler.py        # Main assembler class (2-pass assembler)
├── encoder.py          # Instruction encoding module
├── parser.py           # Assembly source parser
├── registers.py        # Register definitions and aliases
├── instructions.py     # Instruction definitions (easily extensible)
├── pseudo.py           # Pseudo-instruction expansion
├── nop_inserter.py     # NOP insertion for pipeline hazards (future)
└── errors.py           # Custom exception types
```

### Module Responsibilities

#### `assembler.py` - Main Assembler
- Two-pass assembly:
  - **Pass 1**: Collect labels and their addresses
  - **Pass 2**: Encode instructions, resolve labels
- Manages symbol table
- Outputs hex file

#### `encoder.py` - Instruction Encoder
- Encodes each instruction format (R, I, S, B, U, J)
- Handles immediate encoding quirks (B-type and J-type bit shuffling)
- Validates immediate ranges

#### `parser.py` - Assembly Parser
- Tokenizes assembly source
- Strips comments (# and //)
- Handles directives (.text, .globl, .data)
- Returns normalized instruction tuples

#### `registers.py` - Register Definitions
- Maps register names to numbers (x0-x31)
- Supports ABI names (zero, ra, sp, gp, tp, t0-t6, s0-s11, a0-a7)

#### `instructions.py` - Instruction Definitions
- Defines opcode, funct3, funct7 for each instruction
- Specifies instruction format (R, I, S, B, U, J)
- Easy to extend for M, A, F, D extensions

#### `pseudo.py` - Pseudo-Instruction Expansion
- Expands pseudo-instructions to real instructions
- Handles complex expansions (LI with large immediates)

#### `nop_inserter.py` - Pipeline Hazard Handling (Future)
- Analyzes data dependencies
- Inserts NOPs for hazards (configurable)
- Designed to adapt to different pipeline depths

#### `errors.py` - Error Handling
- Custom exceptions for assembly errors
- Clear error messages with line numbers

## NOP Insertion Strategy

The current 2-stage pipeline requires NOPs in specific situations:

1. **Branch after register write**: 2 NOPs needed between a register write and a branch that uses that register
2. **Jump/branch delay**: 1 cycle penalty (handled by hardware flush)

The `nop_inserter.py` module is designed to be configurable:
```python
class NopInserter:
    def __init__(self, pipeline_stages=2, forwarding_enabled=True):
        self.pipeline_stages = pipeline_stages
        self.forwarding_enabled = forwarding_enabled

    def analyze_and_insert(self, instructions):
        # Analyze data dependencies
        # Insert NOPs as needed based on pipeline configuration
        pass
```

Currently, the processor handles most hazards via forwarding. The NOP inserter is stubbed out for future pipeline changes.

## Implementation Plan

### Phase 1: Core Assembler
1. Implement register name mapping
2. Implement instruction definitions with format info
3. Implement encoder for all instruction formats
4. Implement basic parser (tokenizer)
5. Implement two-pass assembler core

### Phase 2: Pseudo-Instructions
1. Implement pseudo-instruction expansion
2. Handle LI with large immediates (LUI + ADDI)
3. Support all standard RISC-V pseudo-instructions

### Phase 3: Validation
1. Assemble existing test programs
2. Compare output to existing .hex files
3. Run simulations to verify correctness

### Phase 4: NOP Insertion (Optional/Future)
1. Implement dependency analysis
2. Implement configurable NOP insertion
3. Add command-line flag to enable/disable

## Usage

```bash
# Basic usage
python3 -m riscvibe_asm input.S -o output.hex

# With verbose output
python3 -m riscvibe_asm input.S -o output.hex -v

# Future: with automatic NOP insertion
python3 -m riscvibe_asm input.S -o output.hex --insert-nops
```

## Output Format

The assembler outputs a hex file with one 32-bit instruction per line in hexadecimal format (no 0x prefix), compatible with Verilog's `$readmemh`:

```
00a00093
01400113
ffb00193
00208233
```

## Extensibility

To add new instructions (e.g., M extension):

1. Add to `instructions.py`:
```python
INSTRUCTIONS['mul'] = Instruction(
    opcode=0x33,
    funct3=0b000,
    funct7=0b0000001,
    format='R'
)
```

2. The encoder automatically handles it based on format.

To add new pseudo-instructions:

1. Add to `pseudo.py`:
```python
PSEUDO_INSTRUCTIONS['seqz'] = lambda rd, rs: [
    ('sltiu', rd, rs, 1)
]
```
