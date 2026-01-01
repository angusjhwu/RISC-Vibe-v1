# RISC-Vibe 5-Stage Pipeline Hazard Verification Plan

This document provides a comprehensive analysis of all hazards possible in the RV32I ISA
for a 5-stage pipeline (IF-ID-EX-MEM-WB) and defines test programs to verify each scenario.

## Table of Contents

1. [Pipeline Hazard Overview](#1-pipeline-hazard-overview)
2. [Data Hazards (RAW Dependencies)](#2-data-hazards-raw-dependencies)
3. [Load-Use Hazards](#3-load-use-hazards)
4. [Control Hazards](#4-control-hazards)
5. [Structural Hazards](#5-structural-hazards)
6. [Edge Cases and Corner Cases](#6-edge-cases-and-corner-cases)
7. [Test Program Implementations](#7-test-program-implementations)
8. [Verification Checklist](#8-verification-checklist)

---

## 1. Pipeline Hazard Overview

### 1.1 Pipeline Stage Timing

```
Cycle:    1     2     3     4     5     6     7     8
         ┌─────┬─────┬─────┬─────┬─────┐
Instr 1: │ IF  │ ID  │ EX  │ MEM │ WB  │
         └─────┴─────┴─────┴─────┴─────┘
               ┌─────┬─────┬─────┬─────┬─────┐
Instr 2:       │ IF  │ ID  │ EX  │ MEM │ WB  │
               └─────┴─────┴─────┴─────┴─────┘
                     ┌─────┬─────┬─────┬─────┬─────┐
Instr 3:             │ IF  │ ID  │ EX  │ MEM │ WB  │
                     └─────┴─────┴─────┴─────┴─────┘
```

### 1.2 Hazard Categories in RV32I 5-Stage Pipeline

| Hazard Type | Description | Resolution |
|-------------|-------------|------------|
| **Data Hazard (EX→EX)** | Producer in MEM, consumer in EX | EX/MEM→EX forwarding |
| **Data Hazard (MEM→EX)** | Producer in WB, consumer in EX | MEM/WB→EX forwarding |
| **Data Hazard (WB→ID)** | Producer in WB, consumer in ID | WB→ID forwarding (register bypass) |
| **Load-Use Hazard** | Load in EX, consumer in ID | 1-cycle stall + forwarding |
| **Control Hazard (Branch)** | Conditional branch taken | 2-cycle flush |
| **Control Hazard (JAL)** | Unconditional jump | 2-cycle flush |
| **Control Hazard (JALR)** | Indirect jump | 2-cycle flush |

---

## 2. Data Hazards (RAW Dependencies)

### 2.1 EX-to-EX Forwarding (1-cycle gap)

**Scenario:** An instruction produces a result in EX stage, and the immediately following
instruction needs that result as an operand.

**Pipeline Timing:**
```
Cycle:    1     2     3     4     5
         ┌─────┬─────┬─────┬─────┬─────┐
ADD x1:  │ IF  │ ID  │ EX* │ MEM │ WB  │  ← Result available in EX/MEM
         └─────┴─────┴─────┴─────┴─────┘
               ┌─────┬─────┬─────┬─────┬─────┐
ADD x2,x1:     │ IF  │ ID  │ EX* │ MEM │ WB  │  ← Needs x1 in EX (forwarding)
               └─────┴─────┴─────┴─────┴─────┘
```

**Test Cases:**

| Test ID | Instruction Sequence | Expected Result | Forwarding Path |
|---------|---------------------|-----------------|-----------------|
| 2.1.1 | `ADD x1,x0,5; ADD x2,x1,x0` | x2 = 5 | EX/MEM→rs1 |
| 2.1.2 | `ADD x1,x0,5; ADD x2,x0,x1` | x2 = 5 | EX/MEM→rs2 |
| 2.1.3 | `ADD x1,x0,5; ADD x2,x1,x1` | x2 = 10 | EX/MEM→rs1,rs2 |
| 2.1.4 | `SUB x1,x2,x3; AND x4,x1,x5` | x4 = (x2-x3) & x5 | EX/MEM→rs1 |
| 2.1.5 | `SLT x1,x2,x3; ADD x4,x0,x1` | x4 = (x2<x3)?1:0 | EX/MEM→rs2 |

**Test Program: test_hazard_ex_ex.S**

### 2.2 MEM-to-EX Forwarding (2-cycle gap)

**Scenario:** An instruction produces a result, then after one unrelated instruction,
another instruction needs that result.

**Pipeline Timing:**
```
Cycle:    1     2     3     4     5     6
         ┌─────┬─────┬─────┬─────┬─────┐
ADD x1:  │ IF  │ ID  │ EX  │ MEM*│ WB  │  ← Result in MEM/WB
         └─────┴─────┴─────┴─────┴─────┘
               ┌─────┬─────┬─────┬─────┬─────┐
NOP:           │ IF  │ ID  │ EX  │ MEM │ WB  │  (unrelated)
               └─────┴─────┴─────┴─────┴─────┘
                     ┌─────┬─────┬─────┬─────┬─────┐
ADD x2,x1:           │ IF  │ ID  │ EX* │ MEM │ WB  │  ← Needs x1 (forwarding from MEM/WB)
                     └─────┴─────┴─────┴─────┴─────┘
```

**Test Cases:**

| Test ID | Instruction Sequence | Expected Result | Forwarding Path |
|---------|---------------------|-----------------|-----------------|
| 2.2.1 | `ADD x1,x0,5; NOP; ADD x2,x1,x0` | x2 = 5 | MEM/WB→rs1 |
| 2.2.2 | `ADD x1,x0,5; NOP; ADD x2,x0,x1` | x2 = 5 | MEM/WB→rs2 |
| 2.2.3 | `ADD x1,x0,5; ADD x3,x0,10; ADD x2,x1,x3` | x2 = 15 | MEM/WB→rs1, EX/MEM→rs2 |

**Test Program: test_hazard_mem_ex.S**

### 2.3 WB-to-ID Forwarding (3-cycle gap)

**Scenario:** An instruction produces a result, and after 2 unrelated instructions,
another instruction reads the result. The result is being written to register file
in the same cycle that ID stage reads it.

**Pipeline Timing:**
```
Cycle:    1     2     3     4     5     6     7
         ┌─────┬─────┬─────┬─────┬─────┐
ADD x1:  │ IF  │ ID  │ EX  │ MEM │ WB* │  ← Writing to RF
         └─────┴─────┴─────┴─────┴─────┘
                           ...
                     ┌─────┬─────┬─────┬─────┬─────┐
ADD x2,x1:           │ IF  │ ID* │ EX  │ MEM │ WB  │  ← Reading from RF (needs bypass)
                     └─────┴─────┴─────┴─────┴─────┘
```

**Test Cases:**

| Test ID | Instruction Sequence | Expected Result | Forwarding Path |
|---------|---------------------|-----------------|-----------------|
| 2.3.1 | `ADD x1,x0,5; NOP; NOP; ADD x2,x1,x0` | x2 = 5 | WB→ID rs1 bypass |
| 2.3.2 | `ADD x1,x0,5; NOP; NOP; ADD x2,x0,x1` | x2 = 5 | WB→ID rs2 bypass |
| 2.3.3 | `ADD x1,x0,5; NOP; NOP; ADD x2,x1,x1` | x2 = 10 | WB→ID rs1,rs2 bypass |

**Test Program: test_hazard_wb_id.S**

### 2.4 Back-to-Back Dependencies (Chained)

**Scenario:** Multiple consecutive instructions each depending on the previous result.

**Test Cases:**

| Test ID | Instruction Sequence | Expected Result |
|---------|---------------------|-----------------|
| 2.4.1 | `ADDI x1,x0,1; ADDI x2,x1,1; ADDI x3,x2,1; ADDI x4,x3,1` | x4 = 4 |
| 2.4.2 | `ADDI x1,x0,10; SLLI x1,x1,1; SLLI x1,x1,1; SLLI x1,x1,1` | x1 = 80 |

**Test Program: test_hazard_chain.S**

### 2.5 Multi-Source Dependencies

**Scenario:** An instruction depends on results from multiple previous instructions.

**Test Cases:**

| Test ID | Instruction Sequence | Expected Result | Notes |
|---------|---------------------|-----------------|-------|
| 2.5.1 | `ADDI x1,x0,5; ADDI x2,x0,3; ADD x3,x1,x2` | x3 = 8 | Both from EX/MEM |
| 2.5.2 | `ADDI x1,x0,5; NOP; ADDI x2,x0,3; ADD x3,x1,x2` | x3 = 8 | x1 from MEM/WB, x2 from EX/MEM |

**Test Program: test_hazard_multi.S**

---

## 3. Load-Use Hazards

Load instructions have a unique hazard because the data is not available until the
MEM stage completes. This requires a 1-cycle stall when a load is immediately followed
by an instruction that uses the loaded value.

### 3.1 Load-Use with Stall (1-cycle gap)

**Pipeline Timing (with stall):**
```
Cycle:    1     2     3     4     5     6     7
         ┌─────┬─────┬─────┬─────┬─────┐
LW x1:   │ IF  │ ID  │ EX  │ MEM*│ WB  │  ← Data available after MEM
         └─────┴─────┴─────┴─────┴─────┘
               ┌─────┬─────┬─────┬─────┬─────┬─────┐
ADD x2,x1:     │ IF  │ ID  │stall│ EX  │ MEM │ WB  │  ← Stall 1 cycle, then forward
               └─────┴─────┴─────┴─────┴─────┴─────┘
```

**Test Cases:**

| Test ID | Instruction Sequence | Memory Setup | Expected Result |
|---------|---------------------|--------------|-----------------|
| 3.1.1 | `LW x1,0(x0); ADD x2,x1,x0` | M[0]=42 | x2 = 42 |
| 3.1.2 | `LW x1,0(x0); ADD x2,x0,x1` | M[0]=42 | x2 = 42 |
| 3.1.3 | `LW x1,0(x0); ADD x2,x1,x1` | M[0]=21 | x2 = 42 |
| 3.1.4 | `LW x1,0(x0); LW x2,0(x1)` | M[0]=4, M[4]=99 | x2 = 99 |
| 3.1.5 | `LW x1,0(x0); SW x1,4(x0)` | M[0]=42 | M[4] = 42 |

**Test Program: test_hazard_load_use.S**

### 3.2 Load with Independent Instruction (No Stall)

**Scenario:** A load followed by an instruction that does NOT use the loaded value.

**Test Cases:**

| Test ID | Instruction Sequence | Expected Result | Notes |
|---------|---------------------|-----------------|-------|
| 3.2.1 | `LW x1,0(x0); ADD x2,x3,x4; ADD x5,x1,x0` | x5 = M[0] | No stall for ADD x2 |
| 3.2.2 | `LW x1,0(x0); LW x2,4(x0); ADD x3,x1,x2` | x3 = M[0]+M[4] | Stall for ADD x3 |

**Test Program: test_hazard_load_no_stall.S**

### 3.3 Consecutive Loads

**Scenario:** Multiple loads in sequence, some with dependencies.

**Test Cases:**

| Test ID | Instruction Sequence | Expected Result |
|---------|---------------------|-----------------|
| 3.3.1 | `LW x1,0(x0); LW x2,4(x0); LW x3,8(x0)` | Independent loads (no stall) |
| 3.3.2 | `LW x1,0(x0); LW x2,0(x1)` | Chain load (stall for second) |
| 3.3.3 | `ADDI x1,x0,4; LW x2,0(x1); ADD x3,x2,x0` | Address calc + load-use |

**Test Program: test_hazard_load_chain.S**

### 3.4 Load-Use with Different Load Widths

**Test Cases:**

| Test ID | Instruction Sequence | Memory Setup | Expected Result |
|---------|---------------------|--------------|-----------------|
| 3.4.1 | `LB x1,0(x0); ADD x2,x1,x0` | M[0]=0x12345678 | x2 = 0x78 (sign-ext) |
| 3.4.2 | `LBU x1,0(x0); ADD x2,x1,x0` | M[0]=0x12345678 | x2 = 0x78 (zero-ext) |
| 3.4.3 | `LH x1,0(x0); ADD x2,x1,x0` | M[0]=0x12345678 | x2 = 0x5678 (sign-ext) |
| 3.4.4 | `LHU x1,0(x0); ADD x2,x1,x0` | M[0]=0x12345678 | x2 = 0x5678 (zero-ext) |

**Test Program: test_hazard_load_width.S**

---

## 4. Control Hazards

Control hazards occur when branch/jump instructions change program flow.
In our implementation, branches are resolved in the EX stage, causing a 2-cycle penalty.

### 4.1 Conditional Branch Taken

**Pipeline Timing (branch taken in EX):**
```
Cycle:    1     2     3     4     5     6     7
         ┌─────┬─────┬─────┬─────┬─────┐
BEQ:     │ IF  │ ID  │ EX* │ MEM │ WB  │  ← Branch resolved, flush
         └─────┴─────┴─────┴─────┴─────┘
               ┌─────┬─────┐
Instr+4:       │ IF  │ ID  │ FLUSHED     ← Speculative fetch, discarded
               └─────┴─────┘
                     ┌─────┐
Instr+8:             │ IF  │ FLUSHED     ← Speculative fetch, discarded
                     └─────┘
                           ┌─────┬─────┬─────┬─────┬─────┐
Target:                    │ IF  │ ID  │ EX  │ MEM │ WB  │  ← Correct target
                           └─────┴─────┴─────┴─────┴─────┘
```

**Test Cases:**

| Test ID | Instruction Sequence | Expected Behavior |
|---------|---------------------|-------------------|
| 4.1.1 | `BEQ x0,x0,target; ADD x1,x0,1; ADD x2,x0,2; target: ADD x3,x0,3` | x1=0, x2=0, x3=3 |
| 4.1.2 | `ADDI x1,x0,5; ADDI x2,x0,5; BEQ x1,x2,target; ADDI x3,x0,99; target: ADDI x4,x0,4` | x3=0, x4=4 |

**Test Program: test_hazard_branch_taken.S**

### 4.2 Conditional Branch Not Taken

**Scenario:** Branch condition is false, pipeline continues sequentially.

**Test Cases:**

| Test ID | Instruction Sequence | Expected Behavior |
|---------|---------------------|-------------------|
| 4.2.1 | `ADDI x1,x0,1; BEQ x1,x0,target; ADD x2,x0,2; target: ADD x3,x0,3` | x2=2, x3=3 |
| 4.2.2 | `BNE x0,x0,target; ADD x1,x0,1; target: NOP` | x1=1 (branch not taken) |

**Test Program: test_hazard_branch_not_taken.S**

### 4.3 All Branch Types

**Test Cases for each branch condition:**

| Test ID | Branch | Condition | Taken? |
|---------|--------|-----------|--------|
| 4.3.1 | BEQ | x1 == x2 | Yes |
| 4.3.2 | BEQ | x1 != x2 | No |
| 4.3.3 | BNE | x1 != x2 | Yes |
| 4.3.4 | BNE | x1 == x2 | No |
| 4.3.5 | BLT | x1 < x2 (signed) | Yes |
| 4.3.6 | BLT | x1 >= x2 (signed) | No |
| 4.3.7 | BGE | x1 >= x2 (signed) | Yes |
| 4.3.8 | BGE | x1 < x2 (signed) | No |
| 4.3.9 | BLTU | x1 < x2 (unsigned) | Yes |
| 4.3.10 | BLTU | x1 >= x2 (unsigned) | No |
| 4.3.11 | BGEU | x1 >= x2 (unsigned) | Yes |
| 4.3.12 | BGEU | x1 < x2 (unsigned) | No |

**Test Program: test_hazard_branch_all.S**

### 4.4 JAL (Unconditional Jump)

**Test Cases:**

| Test ID | Instruction Sequence | Expected Behavior |
|---------|---------------------|-------------------|
| 4.4.1 | `JAL x1,target; ADD x2,x0,1; target: ADD x3,x0,3` | x1=PC+4, x2=0, x3=3 |
| 4.4.2 | `JAL x0,target; ADD x1,x0,1; target: NOP` | x1=0 (flushed) |

**Test Program: test_hazard_jal.S**

### 4.5 JALR (Indirect Jump)

**Scenario:** JALR has additional complexity because the target depends on a register value.

**Test Cases:**

| Test ID | Instruction Sequence | Expected Behavior |
|---------|---------------------|-------------------|
| 4.5.1 | `AUIPC x1,0; ADDI x1,x1,16; JALR x2,x1,0; ADD x3,x0,1; target: ADD x4,x0,4` | x2=PC+4, x3=0, x4=4 |
| 4.5.2 | `LUI x1,target>>12; ADDI x1,x1,target&0xFFF; JALR x0,x1,0` | Jump via register |

**Test Program: test_hazard_jalr.S**

### 4.6 Branch with Data Dependency

**Scenario:** Branch instruction depends on a result from a previous instruction.

**Test Cases:**

| Test ID | Instruction Sequence | Forwarding | Expected Behavior |
|---------|---------------------|------------|-------------------|
| 4.6.1 | `ADDI x1,x0,5; BEQ x1,x0,target` | EX/MEM→branch | Not taken |
| 4.6.2 | `ADDI x1,x0,0; BEQ x1,x0,target` | EX/MEM→branch | Taken |
| 4.6.3 | `LW x1,0(x0); BEQ x1,x0,target` | Load-use + branch | Stall then evaluate |

**Test Program: test_hazard_branch_fwd.S**

### 4.7 JALR with Data Dependency

**Scenario:** JALR target register depends on a previous instruction.

**Test Cases:**

| Test ID | Instruction Sequence | Expected Behavior |
|---------|---------------------|-------------------|
| 4.7.1 | `AUIPC x1,0; JALR x2,x1,16` | EX/MEM forwarding to JALR |
| 4.7.2 | `LW x1,0(x0); JALR x2,x1,0` | Load-use stall before JALR |

**Test Program: test_hazard_jalr_fwd.S**

---

## 5. Structural Hazards

In a properly designed pipeline, structural hazards should not occur. These tests
verify that the pipeline handles resource sharing correctly.

### 5.1 Register File Port Conflict

**Scenario:** WB stage writing while ID stage reading the same register.

**Test Cases:**

| Test ID | Instruction Sequence | Expected Behavior |
|---------|---------------------|-------------------|
| 5.1.1 | Instruction writing to x1 in WB while another reads x1 in ID | WB→ID bypass |

(Already covered in 2.3 WB-to-ID Forwarding)

### 5.2 Memory Port Conflict

**Scenario:** Load and store accessing memory simultaneously (not applicable in our design
since IF uses separate IMEM and MEM uses DMEM).

**Note:** Our design uses Harvard architecture (separate instruction and data memories),
so there are no memory structural hazards.

---

## 6. Edge Cases and Corner Cases

### 6.1 x0 Register (Zero Register)

The x0 register is hardwired to zero. Writes to x0 should be ignored, and forwarding
should not forward when rd=x0.

**Test Cases:**

| Test ID | Instruction Sequence | Expected Result |
|---------|---------------------|-----------------|
| 6.1.1 | `ADDI x0,x0,5; ADD x1,x0,x0` | x0=0, x1=0 |
| 6.1.2 | `ADD x0,x1,x2; ADD x3,x0,x0` | x0=0, x3=0 |
| 6.1.3 | `LW x0,0(x0); ADD x1,x0,x0` | x0=0, x1=0 |

**Test Program: test_hazard_x0.S**

### 6.2 Self-Dependency

**Scenario:** Instruction writes to the same register it reads from.

**Test Cases:**

| Test ID | Instruction Sequence | Expected Result |
|---------|---------------------|-----------------|
| 6.2.1 | `ADDI x1,x0,5; ADD x1,x1,x1` | x1 = 10 |
| 6.2.2 | `ADDI x1,x0,1; SLLI x1,x1,1; SLLI x1,x1,1` | x1 = 4 |

**Test Program: test_hazard_self.S**

### 6.3 Long Dependency Chains

**Test Cases:**

| Test ID | Length | Expected Result |
|---------|--------|-----------------|
| 6.3.1 | 5 instructions | Final value correct |
| 6.3.2 | 10 instructions | Final value correct |

**Test Program: test_hazard_long_chain.S**

### 6.4 Interleaved Dependencies

**Scenario:** Multiple independent dependency chains interleaved.

**Test Cases:**

| Test ID | Instruction Sequence | Expected Result |
|---------|---------------------|-----------------|
| 6.4.1 | `ADDI x1,x0,1; ADDI x2,x0,2; ADD x1,x1,x1; ADD x2,x2,x2` | x1=2, x2=4 |

**Test Program: test_hazard_interleave.S**

### 6.5 Store with Forwarded Data

**Scenario:** Store instruction needs forwarded value for the store data (rs2).

**Test Cases:**

| Test ID | Instruction Sequence | Expected Result |
|---------|---------------------|-----------------|
| 6.5.1 | `ADDI x1,x0,42; SW x1,0(x0)` | M[0] = 42 |
| 6.5.2 | `LW x1,0(x0); SW x1,4(x0)` | M[4] = M[0] (after stall) |
| 6.5.3 | `ADDI x1,x0,42; ADDI x2,x0,8; SW x1,0(x2)` | M[8] = 42 |

**Test Program: test_hazard_store_fwd.S**

### 6.6 Branch at End of Memory

**Test:** Branch near the end of instruction memory to verify PC wrapping/boundary handling.

### 6.7 Back-to-Back Branches

**Test Cases:**

| Test ID | Instruction Sequence | Expected Behavior |
|---------|---------------------|-------------------|
| 6.7.1 | `BEQ ...; BNE ...` (first not taken) | Second branch evaluated |
| 6.7.2 | `JAL target1; target1: JAL target2` | Both jumps execute correctly |

**Test Program: test_hazard_branch_seq.S**

---

## 7. Test Program Implementations

### 7.1 Test File Naming Convention

```
programs/
├── test_hazard_ex_ex.S       # EX-to-EX forwarding tests
├── test_hazard_mem_ex.S      # MEM-to-EX forwarding tests
├── test_hazard_wb_id.S       # WB-to-ID forwarding tests
├── test_hazard_chain.S       # Chained dependency tests
├── test_hazard_load_use.S    # Load-use hazard tests
├── test_hazard_load_chain.S  # Consecutive load tests
├── test_hazard_branch.S      # All branch hazard tests
├── test_hazard_jal.S         # JAL tests
├── test_hazard_jalr.S        # JALR tests
├── test_hazard_x0.S          # Zero register edge cases
├── test_hazard_store_fwd.S   # Store forwarding tests
└── test_hazard_comprehensive.S # Combined comprehensive test
```

### 7.2 Test Program Template

Each test program follows this structure:

```asm
# Test Program: test_hazard_XXX.S
# Description: Tests [specific hazard scenario]
#
# Expected Register Values:
#   x1  = [value]
#   x2  = [value]
#   ...
#
# Expected Memory Values (if applicable):
#   M[addr] = [value]
#   ...

.text
.globl _start

_start:
    # ===== Test Section N: [Description] =====

    [test instructions]

    # ===== End: Signal completion =====
    ecall
```

### 7.3 Expected Values Documentation

Each test will have documented expected values that the testbench can verify automatically.

---

## 8. Verification Checklist

### 8.1 Forwarding Unit Tests

- [ ] EX/MEM → rs1 forwarding
- [ ] EX/MEM → rs2 forwarding
- [ ] MEM/WB → rs1 forwarding
- [ ] MEM/WB → rs2 forwarding
- [ ] WB → ID rs1 bypass
- [ ] WB → ID rs2 bypass
- [ ] No forwarding when rd = x0
- [ ] EX/MEM priority over MEM/WB
- [ ] Mixed forwarding (rs1 from EX/MEM, rs2 from MEM/WB)

### 8.2 Hazard Unit Tests

- [ ] Load-use stall (1 cycle)
- [ ] Load-use with rs1 dependency
- [ ] Load-use with rs2 dependency
- [ ] Load-use with both rs1 and rs2
- [ ] No stall for independent instruction after load
- [ ] Branch taken → 2-cycle flush
- [ ] Branch not taken → no flush
- [ ] JAL → 2-cycle flush
- [ ] JALR → 2-cycle flush

### 8.3 Branch/Jump Tests

- [ ] BEQ taken and not taken
- [ ] BNE taken and not taken
- [ ] BLT/BGE signed comparison
- [ ] BLTU/BGEU unsigned comparison
- [ ] JAL with link register
- [ ] JAL with x0 (no link)
- [ ] JALR basic functionality
- [ ] JALR with forwarded target

### 8.4 Edge Case Tests

- [ ] x0 register writes ignored
- [ ] x0 reads always return 0
- [ ] No forwarding when destination is x0
- [ ] Self-modifying register operations
- [ ] Long dependency chains
- [ ] Back-to-back branches/jumps

### 8.5 Combined Scenario Tests

- [ ] Load followed by branch using loaded value
- [ ] ALU result used by both next instruction AND branch
- [ ] Store with forwarded address and data
- [ ] Function call sequence (JAL + JALR return)

---

## Implementation Priority

1. **High Priority:** Data hazard forwarding tests (2.1, 2.2, 2.3)
2. **High Priority:** Load-use hazard tests (3.1)
3. **High Priority:** Branch control hazard tests (4.1, 4.2)
4. **Medium Priority:** All branch type tests (4.3)
5. **Medium Priority:** JAL/JALR tests (4.4, 4.5)
6. **Medium Priority:** Edge cases (6.1-6.5)
7. **Lower Priority:** Combined comprehensive tests

---

## 9. Verification Results

### 9.1 Bug Discovered and Fixed

During hazard verification, a critical bug was discovered in the EX/MEM pipeline register
handling for control hazards:

**Bug:** When a branch/jump was taken, the `flush_ex` signal was incorrectly clearing the
EX/MEM pipeline register. This meant that JAL/JALR instructions (which need to write their
return address to the link register) were having their `reg_write` signal cleared, causing
the link address to not be saved.

**Root Cause:** The `flush_ex` signal was intended to insert a bubble for the instruction
that was speculatively fetched after the branch. However, it was being applied to the
EX→MEM transition, which contains the branch instruction itself, not the speculative
instruction.

**Fix:** Removed the `flush_ex` condition from the EX/MEM pipeline register. The branch
instruction in EX stage should always proceed to MEM and WB stages to complete its
execution (including writing the link address for JAL/JALR). The `flush_id` signal
correctly handles inserting bubbles for the speculatively fetched instructions in the
IF/ID and ID/EX registers.

**File Modified:** `rtl/riscvibe_5stage_top.sv`

### 9.2 Test Results Summary

| Test Program | Status | Key Verifications |
|--------------|--------|-------------------|
| test_hazard_ex_ex.S | PASS | EX/MEM→rs1, EX/MEM→rs2, EX/MEM→both |
| test_hazard_mem_ex.S | PASS | MEM/WB→rs1, MEM/WB→rs2, mixed forwarding |
| test_hazard_load_use.S | PASS | Load-use stall, chain loads, store forwarding |
| test_hazard_branch.S | PASS | All 6 branch types (BEQ/BNE/BLT/BGE/BLTU/BGEU) |
| test_hazard_jal.S | PASS | JAL with link, JAL to x0, function call pattern |
| test_hazard_jalr.S | PASS | JALR with forwarding, indirect jumps |
| test_hazard_x0.S | PASS | x0 always zero, no forwarding when rd=x0 |
| test_hazard_chain.S | PASS | 8-instruction add chain, shift chains, self-modify |
| test_hazard_comprehensive.S | PASS | Combined data/load-use/control hazards, loops |
| test_alu.hex | PASS | Original ALU test (regression) |
| test_fib.hex | PASS | Original Fibonacci test (regression) |
| test_bubblesort.hex | PASS | Original bubble sort test (regression) |

### 9.3 Verification Checklist (Completed)

#### Forwarding Unit Tests
- [x] EX/MEM → rs1 forwarding
- [x] EX/MEM → rs2 forwarding
- [x] MEM/WB → rs1 forwarding
- [x] MEM/WB → rs2 forwarding
- [x] WB → ID rs1 bypass
- [x] WB → ID rs2 bypass
- [x] No forwarding when rd = x0
- [x] EX/MEM priority over MEM/WB
- [x] Mixed forwarding (rs1 from EX/MEM, rs2 from MEM/WB)

#### Hazard Unit Tests
- [x] Load-use stall (1 cycle)
- [x] Load-use with rs1 dependency
- [x] Load-use with rs2 dependency
- [x] Load-use with both rs1 and rs2
- [x] No stall for independent instruction after load
- [x] Branch taken → 2-cycle flush
- [x] Branch not taken → no flush
- [x] JAL → 2-cycle flush + link address saved
- [x] JALR → 2-cycle flush + link address saved

#### Branch/Jump Tests
- [x] BEQ taken and not taken
- [x] BNE taken and not taken
- [x] BLT/BGE signed comparison
- [x] BLTU/BGEU unsigned comparison
- [x] JAL with link register
- [x] JAL with x0 (no link)
- [x] JALR basic functionality
- [x] JALR with forwarded target

#### Edge Case Tests
- [x] x0 register writes ignored
- [x] x0 reads always return 0
- [x] No forwarding when destination is x0
- [x] Self-modifying register operations
- [x] Long dependency chains
- [x] Back-to-back branches/jumps

#### Combined Scenario Tests
- [x] Load followed by branch using loaded value
- [x] ALU result used by both next instruction AND branch
- [x] Store with forwarded address and data
- [x] Function call sequence (JAL + JALR return)
