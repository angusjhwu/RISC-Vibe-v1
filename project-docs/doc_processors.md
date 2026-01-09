# RiscVibe Processor Implementations

This document describes the two processor implementations in the RiscVibe project and how to use them.

## Overview

RiscVibe contains two RISC-V processor implementations:

| Processor | Directory | Description |
|-----------|-----------|-------------|
| Single-Stage | `riscvibe_1stage/` | Single-cycle processor - all operations complete in one clock cycle |
| 5-Stage Pipeline | `riscvibe_5stage/` | Classic 5-stage pipeline (Fetch, Decode, Execute, Memory, Writeback) |

Both processors implement the RV32I base integer instruction set.

## Directory Structure

```
RiscVibe/
├── riscvibe_1stage/           # Single-cycle processor
│   ├── rtl/                   # RTL source files
│   ├── tb/                    # Testbench
│   ├── sim/                   # Simulation outputs
│   │   └── traces/            # Generated trace files
│   ├── programs -> ../programs  # Symlink to shared test programs
│   ├── architecture.yaml      # Visualizer architecture definition
│   └── Makefile               # Build system
│
├── riscvibe_5stage/           # 5-stage pipelined processor
│   ├── rtl/                   # RTL source files
│   ├── tb/                    # Testbench
│   ├── sim/                   # Simulation outputs
│   │   └── traces/            # Generated trace files
│   ├── programs -> ../programs  # Symlink to shared test programs
│   ├── architecture.yaml      # Visualizer architecture definition
│   └── Makefile               # Build system
│
├── programs/                  # Shared test programs (.hex files)
├── sim/visualizer/            # Pipeline visualization tool
└── riscvibe_asm/              # Assembler (for 5-stage processor)
```

## Single-Stage Processor (`riscvibe_1stage/`)

### Architecture

The single-stage (single-cycle) processor completes all instruction phases in one clock cycle:
- Instruction Fetch
- Decode
- Execute (ALU operation)
- Memory Access
- Register Writeback

Key characteristics:
- **Combinational instruction memory** - instruction available same cycle as PC
- No pipeline hazards (no forwarding or stalling needed)
- Simpler control logic
- Lower clock frequency due to longest critical path

### Building and Running

```bash
cd riscvibe_1stage

# Compile and run simulation (default: test_alu)
make

# Run specific test program
make PROGRAM=test_fib sim

# Generate trace for visualizer
make PROGRAM=test_alu trace

# View waveforms
make wave

# Clean generated files
make clean
```

### Make Targets

| Target | Description |
|--------|-------------|
| `make all` | Compile and simulate (default) |
| `make compile` | Compile the design |
| `make sim` | Run simulation |
| `make trace` | Compile and run with trace logging |
| `make wave` | Open waveforms in GTKWave |
| `make clean` | Remove generated files |

### Test Programs

The single-stage processor uses the shared test programs in `programs/`:
- `test_alu.hex` - Basic ALU operations
- `test_fib.hex` - Fibonacci sequence calculation

Note: Programs using NOP-based hazard mitigation (e.g., `test_fib_5stage.hex`) are designed for the 5-stage processor and may execute differently on the single-stage.

## 5-Stage Pipelined Processor (`riscvibe_5stage/`)

### Architecture

The 5-stage pipeline divides instruction execution into stages:

1. **Fetch (F)** - Read instruction from memory
2. **Decode (D)** - Decode instruction, read registers
3. **Execute (X)** - ALU operation, branch calculation
4. **Memory (M)** - Data memory read/write
5. **Writeback (W)** - Write results to register file

Key characteristics:
- **Pipeline registers** between stages
- **Data forwarding** from EX and MEM stages
- **Hazard detection** and stalling for load-use hazards
- **Branch prediction** with flush on misprediction
- Higher throughput (up to 1 instruction per cycle)

### Building and Running

```bash
cd riscvibe_5stage

# Compile and run simulation (default: test_alu)
make

# Run specific test program
make PROGRAM=test_fib sim

# Generate trace for visualizer
make PROGRAM=test_fib trace

# Run hazard tests
make PROGRAM=test_hazard_ex_ex sim

# View waveforms
make wave

# Clean generated files
make clean
```

### Make Targets

Same as single-stage processor.

### Test Programs

The 5-stage processor can run all programs in `programs/`:
- `test_alu.hex` - Basic ALU operations
- `test_fib.hex` - Fibonacci sequence calculation
- `test_fib_5stage.hex` - Fibonacci with explicit NOPs for pipeline timing
- `test_hazard_*.hex` - Various hazard test cases

## Using the Visualizer

The visualizer supports both processor architectures through YAML configuration files.

### Loading Traces

1. Start the visualizer:
   ```bash
   cd sim/visualizer
   python app.py
   ```

2. Open browser to `http://localhost:5001`

3. Select architecture from dropdown:
   - "riscv_1stage" for single-stage traces
   - "riscv_5stage" for 5-stage traces

4. Upload trace file:
   - Single-stage: `riscvibe_1stage/sim/traces/*.jsonl`
   - 5-stage: `riscvibe_5stage/sim/traces/*.jsonl`

### Architecture Files

Each processor has its own `architecture.yaml`:

**Single-stage** (`riscvibe_1stage/architecture.yaml`):
- Single "cpu" stage
- No hazard signals

**5-stage** (`riscvibe_5stage/architecture.yaml`):
- Five stages: F, D, X, M, W
- Hazard signals for stall and flush
- Forwarding signal mappings

## Comparing Processors

| Feature | Single-Stage | 5-Stage Pipeline |
|---------|--------------|------------------|
| CPI | 1 | 1 (ideal), higher with hazards |
| Clock frequency | Limited by longest path | Higher (shorter critical path) |
| Throughput | 1 instr/cycle | Up to 1 instr/cycle |
| Hazards | None | Data, control hazards |
| Hardware complexity | Lower | Higher (forwarding, hazard detection) |
| Instruction memory | Combinational | Synchronous |

## Quick Reference

### Single-Stage
```bash
cd riscvibe_1stage
make PROGRAM=test_alu trace
# Trace: sim/traces/test_alu_trace.jsonl
```

### 5-Stage Pipeline
```bash
cd riscvibe_5stage
make PROGRAM=test_fib trace
# Trace: sim/traces/test_fib_trace.jsonl
```

### Visualize
```bash
cd sim/visualizer
python app.py
# Open http://localhost:5001
# Select architecture, upload trace
```
