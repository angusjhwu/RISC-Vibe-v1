# RiscVibe

A 5-stage pipelined RISC-V processor implementing the RV32I base integer instruction set, written in SystemVerilog. Includes a custom Python assembler and comprehensive test suite.

## Features

### Processor Architecture
- **5-stage pipeline**: Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory Access (MEM), Write Back (WB)
- **Full RV32I support**: All 37 base integer instructions including arithmetic, logic, branches, jumps, loads, and stores
- **Data hazard handling**:
  - EX-to-EX forwarding (1-cycle distance)
  - MEM-to-EX forwarding (2-cycle distance)
  - WB-to-ID bypass for register reads
  - Load-use stall detection with automatic pipeline bubble insertion
- **Control hazard handling**: Branch/jump detection with pipeline flush (2-cycle penalty)
- **Memory system**:
  - 4KB instruction memory (ROM, word-addressed)
  - 4KB data memory (byte-addressable, little-endian)
  - Byte, halfword, and word load/store with sign/zero extension

### Assembler
- Two-pass assembler written in Python
- Full RV32I instruction support
- Pseudo-instruction expansion (li, mv, j, ret, call, etc.)
- Label resolution for branches and jumps
- ABI register name support (ra, sp, a0-a7, t0-t6, s0-s11, etc.)
- Outputs Verilog-compatible hex files

### Testing Infrastructure
- Automated regression test runner
- 12 functional test programs covering ALU, loops, memory, and all hazard scenarios
- Per-test register value validation
- VCD waveform generation for debugging

### Pipeline Visualizer
- Interactive web-based visualization of pipeline execution
- Cycle-by-cycle stepping with playback controls
- Real-time display of all 5 pipeline stages with PC and disassembled instructions
- Register file contents with change highlighting and hex/decimal toggle
- Hazard and forwarding signal visualization
- JSON Lines trace format for external tool integration

## Repository Structure

```
RiscVibe/
├── rtl/                          # SystemVerilog RTL modules
│   ├── riscvibe_pkg.sv           # Package with types, opcodes, control signals
│   ├── riscvibe_5stage_top.sv    # 5-stage pipeline top module
│   ├── if_stage.sv               # Instruction Fetch stage
│   ├── id_stage.sv               # Instruction Decode stage
│   ├── ex_stage.sv               # Execute stage
│   ├── mem_stage.sv              # Memory Access stage
│   ├── wb_stage.sv               # Write Back stage
│   ├── hazard_unit.sv            # Load-use hazard detection
│   ├── forwarding_unit.sv        # Data forwarding control
│   ├── alu.sv                    # Arithmetic Logic Unit
│   ├── branch_unit.sv            # Branch comparison logic
│   ├── control_unit.sv           # Instruction decode/control
│   ├── register_file.sv          # 32x32-bit register file
│   ├── data_memory.sv            # Data memory
│   ├── immediate_gen.sv          # Immediate generator
│   ├── instruction_mem.sv        # Instruction ROM
│   ├── trace_logger.sv           # JSON trace generator for visualizer
│   └── disasm.sv                 # RV32I disassembler package
├── tb/                           # Testbenches
│   └── tb_riscvibe_5stage.sv     # 5-stage pipeline testbench
├── programs/                     # Test programs (.S and .hex)
├── riscvibe_asm/                 # Python assembler
├── sim/                          # Simulation outputs
│   └── visualizer/               # Pipeline visualizer web app
│       ├── app.py                # Flask backend server
│       ├── trace_parser.py       # JSONL trace file parser
│       ├── templates/            # HTML templates
│       └── static/               # CSS and JavaScript
│           ├── css/style.css     # Stylesheet
│           └── js/
│               ├── main.js       # Application logic
│               └── disasm.js     # RV32I disassembler
├── project-docs/                 # Design documentation
├── Makefile                      # Build system
├── run_visualizer.sh             # Visualizer launch script
└── regression_pipeline.py        # Automated test runner
```

## System Dependencies

### Required
- **Icarus Verilog** (`iverilog`, `vvp`) - Open-source Verilog/SystemVerilog simulator
- **Python 3.8+** - For the assembler and test runner

### Optional
- **GTKWave** - Waveform viewer for debugging

### Installation

**macOS (Homebrew):**
```bash
brew install icarus-verilog gtkwave python3
```

**Ubuntu/Debian:**
```bash
sudo apt install iverilog gtkwave python3
```

**Arch Linux:**
```bash
sudo pacman -S iverilog gtkwave python
```

## Quick Start

### Run the default test
```bash
make
```

### Run a specific test program
```bash
make TESTPROG=programs/test_fib.hex
```

### Run the full regression suite
```bash
./regression_pipeline.py
```

### View waveforms
```bash
make wave
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make` or `make all` | Compile and simulate 5-stage pipeline (default) |
| `make compile` | Compile only |
| `make sim` | Run simulation only |
| `make trace` | Compile and run with trace logging for visualizer |
| `make visualizer` | Start the pipeline visualizer web server |
| `make 2stage` | Compile and run legacy 2-stage pipeline |
| `make wave` | Open waveforms in GTKWave |
| `make clean` | Remove generated files |
| `make help` | Show all available targets |

### Variables
- `TESTPROG` - Path to test program hex file (default: `programs/test_alu.hex`)
- `MAX_CYCLES` - Maximum simulation cycles (default: `10000`)

## Test Programs

### Functional Tests
| Test | Description |
|------|-------------|
| `test_alu` | All ALU operations: add, sub, shifts, comparisons, logical |
| `test_fib` | Fibonacci sequence with loops and branches |
| `test_bubblesort` | Bubble sort algorithm with memory operations |

### Pipeline Hazard Tests
| Test | Description |
|------|-------------|
| `test_hazard_ex_ex` | EX-to-EX data forwarding |
| `test_hazard_mem_ex` | MEM-to-EX data forwarding |
| `test_hazard_load_use` | Load-use stall insertion |
| `test_hazard_branch` | Branch flush verification |
| `test_hazard_jal` | JAL instruction hazards |
| `test_hazard_jalr` | JALR instruction hazards |
| `test_hazard_x0` | x0 register hardwiring |
| `test_hazard_chain` | Chained data dependencies |
| `test_hazard_comprehensive` | Combined hazard scenarios |

### Regression Testing
```bash
# Run all tests
./regression_pipeline.py

# Verbose output
./regression_pipeline.py -v

# Run specific test
./regression_pipeline.py --test test_fib

# List available tests
./regression_pipeline.py --list
```

Results are saved to `sim/regression_report.txt` with detailed logs in `sim/logs/`.

## Running Your Own Programs

### Writing RISC-V Assembly

Create a `.S` file in the `programs/` directory. Example:

```asm
# my_program.S - Simple example
    addi x1, x0, 10      # x1 = 10
    addi x2, x0, 20      # x2 = 20
    add  x3, x1, x2      # x3 = x1 + x2 = 30

    # Store result to memory
    sw   x3, 0(x0)       # mem[0] = 30

    # End program (required)
    ecall
```

**Important:** All programs must end with `ecall` or `ebreak` to terminate simulation.

### Supported Instructions

**R-Type (register-register):** `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`

**I-Type (immediate):** `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`

**Load:** `lb`, `lh`, `lw`, `lbu`, `lhu`

**Store:** `sb`, `sh`, `sw`

**Branch:** `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`

**Jump:** `jal`, `jalr`

**Upper immediate:** `lui`, `auipc`

**System:** `ecall`, `ebreak`

**Pseudo-instructions:** `nop`, `li`, `mv`, `not`, `neg`, `j`, `jr`, `ret`, `call`, `beqz`, `bnez`, `blez`, `bgez`, `bltz`, `bgtz`

### Assembling Your Program

```bash
python3 -m riscvibe_asm programs/my_program.S -o programs/my_program.hex
```

Add `-v` for verbose output showing each instruction encoded.

### Running Your Program

```bash
make TESTPROG=programs/my_program.hex
```

Or step by step:
```bash
make compile TESTPROG=programs/my_program.hex
make sim
```

### Viewing Waveforms

After simulation, view internal signals with GTKWave:
```bash
make wave
```

The VCD file is saved to `sim/riscvibe_5stage.vcd`.

### Using the Pipeline Visualizer

The pipeline visualizer provides an interactive web-based view of pipeline execution:

1. **Generate a trace file:**
   ```bash
   make trace TESTPROG=programs/test_fib.hex
   ```
   This creates `sim/trace.jsonl` containing cycle-by-cycle processor state.

2. **Start the visualizer:**
   ```bash
   ./run_visualizer.sh
   ```
   Or manually:
   ```bash
   make visualizer
   ```

3. **Open in browser:**
   Navigate to `http://localhost:5050`

4. **Load and explore:**
   - Click "Load Trace" to load `sim/trace.jsonl`
   - Use playback controls or keyboard shortcuts:
     - `Space` - Play/Pause
     - `←` / `→` - Step backward/forward
     - `Home` / `End` - Jump to start/end
   - View pipeline stages with PC and disassembled instructions (e.g., `addi x1, x0, 10`)
   - Toggle register display between hex and decimal formats
   - Monitor hazard and forwarding signals in real-time

### Writing C Programs

To run C programs, you'll need a RISC-V cross-compiler toolchain:

1. **Install the toolchain:**
   ```bash
   # macOS
   brew tap riscv-software-src/riscv
   brew install riscv-tools

   # Ubuntu
   sudo apt install gcc-riscv64-unknown-elf
   ```

2. **Write your C program:**
   ```c
   // my_program.c
   int main() {
       int a = 10;
       int b = 20;
       int c = a + b;
       return c;
   }
   ```

3. **Compile and convert to hex:**
   ```bash
   # Compile to object file
   riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -T linker.ld my_program.c -o my_program.elf

   # Extract binary
   riscv64-unknown-elf-objcopy -O binary my_program.elf my_program.bin

   # Convert to hex (you'll need a bin2hex script)
   xxd -p -c 4 my_program.bin | awk '{print $1}' > my_program.hex
   ```

   **Note:** You'll need a minimal linker script (`linker.ld`) and startup code for proper execution. For simple programs, writing directly in assembly is recommended.

### Memory Map

| Region | Address Range | Size | Description |
|--------|---------------|------|-------------|
| Instruction Memory | `0x0000` - `0x0FFF` | 4 KB | Read-only, word-aligned |
| Data Memory | `0x0000` - `0x0FFF` | 4 KB | Read/write, byte-addressable |

**Note:** Instruction and data memory are separate (Harvard architecture).

## Supported ISA

RiscVibe implements the complete **RV32I** base integer instruction set (37 instructions):

| Format | Instructions | Count |
|--------|--------------|-------|
| R-type | ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND | 10 |
| I-type | ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI | 9 |
| Load | LB, LH, LW, LBU, LHU | 5 |
| Store | SB, SH, SW | 3 |
| Branch | BEQ, BNE, BLT, BGE, BLTU, BGEU | 6 |
| Jump | JAL, JALR | 2 |
| U-type | LUI, AUIPC | 2 |

## Future Work

### Near-term Improvements
- **Branch prediction**: Add a simple branch predictor (BTB or bimodal) to reduce branch penalty from 2 cycles to ~1 cycle on average
- **Memory-mapped I/O**: Add UART or other peripherals for external communication
- **Interrupt support**: Implement basic interrupt handling with CSR registers
- **Performance counters**: Add cycle counter, instruction counter, and other CSRs

### Extensions
- **M extension**: Integer multiplication and division (MUL, DIV, REM)
- **C extension**: Compressed 16-bit instructions for improved code density
- **Zicsr extension**: Control and Status Register instructions
- **F extension**: Single-precision floating-point

### Infrastructure
- **FPGA synthesis**: Provide constraints and scripts for common FPGA boards (Arty A7, DE10-Nano)
- **Formal verification**: Add formal property checking with SymbiYosys
- **Continuous integration**: GitHub Actions for automated regression on PRs
- **Code coverage**: Add simulation coverage metrics
- **Verilator support**: Add Verilator compilation for faster simulation

### Advanced Features
- **Cache hierarchy**: Instruction and data caches with configurable size/associativity
- **MMU/virtual memory**: Page tables and address translation for OS support
- **Multi-core**: Extend to dual-core with cache coherency
- **Out-of-order execution**: Superscalar pipeline with register renaming

## Documentation

Additional documentation is available in `project-docs/`:
- [PIPELINE.md](project-docs/PIPELINE.md) - Pipeline architecture overview
- [pipeline-impl.md](project-docs/pipeline-impl.md) - Detailed implementation specification
- [hazards_tb_impl.md](project-docs/hazards_tb_impl.md) - Hazard testing documentation
- [simulator_impl.md](project-docs/simulator_impl.md) - Pipeline visualizer implementation
- [assembler.md](assembler.md) - Assembler design and usage

## License

This project is open source. See individual files for license information.
