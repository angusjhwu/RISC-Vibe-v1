# RISC-Vibe Simulator Implementation Plan

## Executive Summary

This document details the implementation plan for an interactive cycle-accurate simulator/visualizer for the RISC-Vibe 5-stage pipelined RV32I processor. The simulator will allow users to step through program execution, visualize pipeline stages, observe register/memory state, and understand hazard handling in real-time.

---

## 1. Review of Original Specification

### Original Goals (from SIMULATOR.md)
- GUI showing current processor states (registers, stage flags)
- Step through program execution to visualize hardware usage
- Cross-platform compatibility
- Lightweight, interactive GUI (file input, button interaction)

### Proposed Approach (from SIMULATOR.md)
- CSV-based trace format capturing all processor states per cycle
- GUI organized by pipeline stage
- Forward/backward stepping through cycles

---

## 2. Expert Analysis & Additional Considerations

### 2.1 Data Capture Strategy

**Original proposal**: CSV format

**Recommendation**: Use **JSON Lines (.jsonl)** format instead of CSV

**Rationale**:
- CSV struggles with nested data (pipeline registers have sub-fields)
- JSON naturally represents hierarchical processor state
- JSON Lines (one JSON object per line) maintains streaming/line-based benefits
- Modern GUI frameworks have excellent JSON parsing support
- Self-documenting field names vs. positional CSV columns
- Easier to extend with new signals without breaking parsers

**Alternative considered**: VCD parsing
- Pros: Already generated, standard format
- Cons: Complex parser needed, signal names are hierarchical/verbose, designed for waveforms not structured state

### 2.2 Processor State to Capture

Based on analysis of `riscvibe_pkg.sv` and `tb_riscvibe_5stage.sv`, the following state should be captured each cycle:

| Category | Signals | Purpose |
|----------|---------|---------|
| **Metadata** | cycle, timestamp | Time reference |
| **IF Stage** | pc, instruction, valid | Current fetch |
| **IF/ID Register** | pc, pc_plus_4, instruction, valid | Pipeline reg |
| **ID Stage** | rs1_addr, rs2_addr, rs1_data, rs2_data, rd_addr, immediate | Decode outputs |
| **ID/EX Register** | All fields from `id_ex_reg_t` | Pipeline reg |
| **EX Stage** | alu_op_a, alu_op_b, alu_result, branch_taken, branch_target | Execute outputs |
| **EX/MEM Register** | All fields from `ex_mem_reg_t` | Pipeline reg |
| **MEM Stage** | mem_addr, mem_write_data, mem_read_data, mem_active | Memory access |
| **MEM/WB Register** | All fields from `mem_wb_reg_t` | Pipeline reg |
| **WB Stage** | wb_data, wb_addr, wb_enable | Write-back |
| **Registers** | x0-x31 (32 values) | Full register file |
| **Hazard Control** | stall_if, stall_id, flush_id, flush_ex | Hazard signals |
| **Forwarding** | forward_a, forward_b, fwd_a_data, fwd_b_data | Data forwarding |

### 2.3 GUI Framework Selection

**Requirements**:
- Cross-platform (macOS, Windows, Linux)
- Lightweight installation
- Interactive (buttons, file dialogs)
- Good rendering for pipeline diagrams
- Active development/community

**Options Evaluated**:

| Framework | Pros | Cons | Verdict |
|-----------|------|------|---------|
| **Tauri + Web** | Tiny binary, web tech, Rust backend | Learning curve, complex build | Overkill |
| **Electron** | Rich ecosystem, easy web dev | Heavy (100MB+), memory hog | Too heavy |
| **PyQt/PySide** | Mature, powerful, Python | GPL licensing concerns, complex | Good option |
| **Tkinter** | Built into Python, simple | Dated look, limited widgets | Fallback |
| **Dear ImGui (Python)** | Fast, immediate-mode, game-dev proven | Less native look | Good for viz |
| **Web (Flask + Browser)** | Zero install, universal, flexible | Requires local server | **Recommended** |
| **Streamlit** | Rapid Python UI, auto-refresh | Limited customization | Quick prototype |

**Recommendation**: **Web-based (Python Flask/FastAPI backend + HTML/CSS/JS frontend)**

**Rationale**:
1. **Zero installation friction** - Users only need Python and a browser
2. **True cross-platform** - Any OS with a browser works
3. **Rich visualization** - D3.js, Canvas, SVG for pipeline diagrams
4. **Easy styling** - CSS for professional appearance
5. **Responsive** - Works on different screen sizes
6. **Familiar stack** - Matches existing Python regression infrastructure

### 2.4 Visualization Design Considerations

**Pipeline Diagram Layout**:
```
+--------+    +--------+    +--------+    +--------+    +--------+
|   IF   | -> |   ID   | -> |   EX   | -> |  MEM   | -> |   WB   |
+--------+    +--------+    +--------+    +--------+    +--------+
| PC:... |    | rs1:.. |    | ALU:.. |    | Addr:..|    | rd:... |
| Instr: |    | rs2:.. |    | Op:... |    | Data:..|    | Data:..|
| Valid  |    | imm:.. |    | Result |    | R/W:.. |    | Write  |
+--------+    +--------+    +--------+    +--------+    +--------+
                  ^              ^              |
                  |              +--------------+ (forwarding)
                  +------------------------------+
```

**Key Visual Elements**:
1. **Pipeline stages** as connected boxes showing instruction flow
2. **Instruction highlighting** - track one instruction through stages
3. **Hazard indicators** - red for stalls, orange for flushes
4. **Forwarding paths** - animated arrows showing data bypass
5. **Register file** - 32 registers with change highlighting
6. **Memory view** - recent accesses, optional full dump
7. **Control panel** - play/pause, step, speed slider, cycle counter

### 2.5 Stepping Mechanism

**Forward stepping**: Straightforward - advance cycle index

**Backward stepping**:
- Since we capture full state each cycle, backward stepping is trivial
- Simply decrement cycle index and display previous state
- No need for reverse simulation or checkpointing

**Performance consideration**:
- For large traces (10K+ cycles), consider:
  - Lazy loading (load 1000 cycles at a time)
  - Binary format option for faster parsing
  - IndexedDB caching in browser

### 2.6 Additional Features Worth Considering

1. **Instruction Disassembly** - Show human-readable assembly alongside hex
2. **Breakpoints** - Stop at specific PC or cycle
3. **Watch expressions** - Monitor specific registers/signals
4. **Search** - Find cycle where register changed to value X
5. **Statistics** - CPI, stall frequency, branch stats
6. **Comparison mode** - Diff two trace files
7. **Export** - Screenshot pipeline state, export to PDF

---

## 3. Detailed Implementation Plan

### Phase 1: Trace Generation Infrastructure

#### 1.1 Create Trace Generator Module (`rtl/trace_logger.sv`)

A SystemVerilog module that outputs JSON Lines format:

```systemverilog
module trace_logger #(
    parameter string TRACE_FILE = "trace.jsonl"
)(
    input logic clk,
    input logic rst_n,
    input logic enable,
    // All processor state inputs...
);
```

**Implementation notes**:
- Use `$fopen`, `$fwrite`, `$fclose` for file I/O
- Format each cycle as a single JSON line
- Include instruction disassembly using a decode function

#### 1.2 Modify Testbench (`tb/tb_riscvibe_5stage.sv`)

Add trace logging instantiation:
- New parameter `TRACE_ENABLE` (default 1)
- New parameter `TRACE_FILE` (default "trace.jsonl")
- Connect all monitored signals to trace logger

#### 1.3 JSON Line Format Specification

```json
{
  "cycle": 42,
  "if": {"pc": "0x00000100", "instr": "0x00500093", "asm": "addi x1, x0, 5", "valid": true},
  "id": {"pc": "0x000000fc", "instr": "0x00000013", "asm": "nop", "rs1": 0, "rs2": 0, "rd": 1, "imm": "0x00000005", "valid": true},
  "ex": {"alu_a": "0x00000000", "alu_b": "0x00000005", "alu_op": "ADD", "result": "0x00000005", "branch_taken": false, "valid": true},
  "mem": {"addr": "0x00000000", "write_data": "0x00000000", "read_data": "0x00000000", "read": false, "write": false, "valid": true},
  "wb": {"rd": 1, "data": "0x00000005", "enable": true, "valid": true},
  "regs": ["0x0", "0x5", "0x0", ...],
  "hazard": {"stall_if": false, "stall_id": false, "flush_id": false, "flush_ex": false},
  "forward": {"a": "NONE", "b": "NONE"}
}
```

#### 1.4 Add Disassembler Function

Create `rtl/disasm.sv` or inline function to decode instructions:
- Input: 32-bit instruction
- Output: String like "addi x1, x0, 5"
- Cover all RV32I instructions

### Phase 2: Python Backend

#### 2.1 Directory Structure

```
sim/
  visualizer/
    __init__.py
    app.py              # Flask/FastAPI application
    trace_parser.py     # JSONL trace file parser
    disassembler.py     # Python disassembler (backup)
    static/
      css/
        style.css       # Main stylesheet
        pipeline.css    # Pipeline diagram styles
      js/
        main.js         # Core application logic
        pipeline.js     # Pipeline visualization
        registers.js    # Register file display
        controls.js     # Playback controls
      img/
        (icons, etc.)
    templates/
      index.html        # Main page template
```

#### 2.2 Backend API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Serve main HTML page |
| `/api/load` | POST | Upload/load trace file |
| `/api/cycle/<n>` | GET | Get state at cycle n |
| `/api/cycles` | GET | Get total cycle count |
| `/api/search` | POST | Search for conditions |
| `/api/stats` | GET | Get execution statistics |

#### 2.3 Trace Parser (`trace_parser.py`)

```python
class TraceParser:
    def __init__(self, filepath: str):
        """Load and index a trace file"""

    def get_cycle(self, n: int) -> dict:
        """Get state at cycle n"""

    def get_range(self, start: int, end: int) -> list[dict]:
        """Get cycles in range (for buffering)"""

    def search(self, predicate: callable) -> list[int]:
        """Find cycles matching condition"""

    @property
    def total_cycles(self) -> int:
        """Total cycles in trace"""
```

### Phase 3: Frontend Visualization

#### 3.1 Main Layout (`index.html`)

```
+------------------------------------------------------------------+
|  RISC-Vibe Pipeline Simulator                    [Load Trace]    |
+------------------------------------------------------------------+
|                                                                  |
|  +------------------------------------------------------------+  |
|  |                    PIPELINE DIAGRAM                        |  |
|  |   [IF] --> [ID] --> [EX] --> [MEM] --> [WB]               |  |
|  |                                                            |  |
|  +------------------------------------------------------------+  |
|                                                                  |
|  +------------------------+  +-------------------------------+   |
|  |    REGISTER FILE      |  |         CONTROLS              |   |
|  | x0:  0x00000000       |  |  [|<] [<] [>] [>|] [Play]     |   |
|  | x1:  0x00000005  *    |  |  Cycle: [____42____] / 1000   |   |
|  | x2:  0x00001000       |  |  Speed: [----o----]           |   |
|  | ...                   |  +-------------------------------+   |
|  +------------------------+  +-------------------------------+   |
|                             |       HAZARD STATUS            |   |
|  +------------------------+ |  Stall IF: [ ]  Flush ID: [ ] |   |
|  |    MEMORY ACCESS      |  |  Stall ID: [ ]  Flush EX: [ ] |   |
|  | Last: 0x1000 R 0xAB   |  |  Forward A: NONE              |   |
|  +------------------------+ |  Forward B: MEM               |   |
|                             +-------------------------------+   |
+------------------------------------------------------------------+
```

#### 3.2 Pipeline Visualization (`pipeline.js`)

- SVG-based rendering for crisp scaling
- Each stage as a rounded rectangle
- Connection lines between stages
- Animated data flow (optional)
- Color coding:
  - Green: Valid instruction
  - Gray: Bubble/NOP
  - Red border: Stalled
  - Orange: Being flushed
  - Blue arrow: Active forwarding path

#### 3.3 Register File Display (`registers.js`)

- 8x4 grid of registers
- Highlight recently changed (yellow fade)
- Show both hex and decimal on hover
- ABI names (x1/ra, x2/sp, etc.)
- Click to add to watch list

#### 3.4 Playback Controls (`controls.js`)

- First cycle (`|<`)
- Previous cycle (`<`)
- Next cycle (`>`)
- Last cycle (`>|`)
- Play/Pause with configurable speed
- Direct cycle input
- Keyboard shortcuts (left/right arrows, space for play/pause)

### Phase 4: Integration & Polish

#### 4.1 Makefile Updates

Add new targets:
```makefile
trace:        # Run simulation with trace generation
visualizer:   # Start the visualizer web server
```

#### 4.2 Launch Script

Create `run_visualizer.sh` / `run_visualizer.bat`:
1. Check Python dependencies
2. Start Flask server
3. Open browser to localhost:5000

#### 4.3 Documentation

- Update README with visualizer usage
- Add tooltips/help in UI
- Example trace files for demo

---

## 4. File Inventory

### New Files to Create

| File | Purpose |
|------|---------|
| `rtl/trace_logger.sv` | SystemVerilog trace generation module |
| `rtl/disasm.sv` | Instruction disassembler function |
| `sim/visualizer/app.py` | Python Flask backend |
| `sim/visualizer/trace_parser.py` | Trace file parser |
| `sim/visualizer/static/css/style.css` | Main styles |
| `sim/visualizer/static/css/pipeline.css` | Pipeline diagram styles |
| `sim/visualizer/static/js/main.js` | Main application JS |
| `sim/visualizer/static/js/pipeline.js` | Pipeline visualization |
| `sim/visualizer/static/js/registers.js` | Register display |
| `sim/visualizer/static/js/controls.js` | Playback controls |
| `sim/visualizer/templates/index.html` | Main HTML template |
| `sim/visualizer/requirements.txt` | Python dependencies |
| `run_visualizer.sh` | Launch script (Unix) |
| `run_visualizer.bat` | Launch script (Windows) |

### Files to Modify

| File | Changes |
|------|---------|
| `tb/tb_riscvibe_5stage.sv` | Add trace logger instantiation |
| `Makefile` | Add trace and visualizer targets |
| `README.md` | Document visualizer usage |

---

## 5. Dependencies

### Python Requirements (`requirements.txt`)
```
flask>=2.3.0
```

No other external dependencies needed - keeping it minimal.

### Browser Requirements
- Modern browser with ES6 support (Chrome, Firefox, Safari, Edge)
- No plugins required

### Build Requirements
- Existing: Icarus Verilog, Make
- No new RTL tools required

---

## 6. Implementation Order & Milestones

### Milestone 1: Trace Infrastructure (Core)
1. Create `trace_logger.sv` module
2. Create `disasm.sv` disassembler
3. Modify testbench to instantiate logger
4. Generate first trace file
5. Validate JSON format

**Deliverable**: Running `make trace` produces valid `.jsonl` file

### Milestone 2: Backend API
1. Set up Flask project structure
2. Implement `trace_parser.py`
3. Implement basic API endpoints
4. Test with curl/Postman

**Deliverable**: API returns cycle data from trace file

### Milestone 3: Basic Frontend
1. Create HTML layout
2. Style with CSS
3. Implement cycle navigation
4. Display register values
5. Basic pipeline boxes

**Deliverable**: Can step through cycles, see registers change

### Milestone 4: Pipeline Visualization
1. SVG pipeline diagram
2. Show instruction in each stage
3. Hazard/forwarding indicators
4. Data flow visualization

**Deliverable**: Visual pipeline matches testbench output

### Milestone 5: Polish & Integration
1. Keyboard shortcuts
2. Auto-play functionality
3. Search/breakpoint features
4. Makefile integration
5. Documentation

**Deliverable**: Complete, documented simulator ready for use

---

## 7. Testing Strategy

### 7.1 Trace Generation Tests

#### T1: Basic Trace Output
- **Test**: Run `make trace` with `test_alu.hex`
- **Expected**: `trace.jsonl` file is created in `sim/` directory
- **Validation**: File exists, non-empty, valid JSON per line

#### T2: JSON Format Validation
- **Test**: Parse every line of generated trace with Python `json.loads()`
- **Expected**: All lines parse without error
- **Validation**: Python script that loads and validates schema

#### T3: Cycle Count Consistency
- **Test**: Compare trace cycle count to testbench reported cycles
- **Expected**: Trace has exactly N cycles matching testbench output
- **Validation**: `wc -l trace.jsonl` matches cycle count in simulation log

#### T4: Register State Accuracy
- **Test**: Compare trace register values at final cycle to testbench final dump
- **Expected**: All 32 registers match exactly
- **Validation**: Script compares trace last line regs[] to testbench output

#### T5: Hazard Signal Capture
- **Test**: Run `test_hazard_load_use.hex`, check trace for stall cycles
- **Expected**: `stall_if` and `stall_id` are true on load-use hazard cycles
- **Validation**: Grep trace for `"stall_if": true`, verify cycle numbers

#### T6: Forwarding Signal Capture
- **Test**: Run `test_hazard_ex_ex.hex`, check trace for forwarding
- **Expected**: `forward_a` or `forward_b` show "MEM" or "WB" values
- **Validation**: Grep trace for non-"NONE" forwarding values

#### T7: Branch/Flush Capture
- **Test**: Run `test_hazard_branch.hex`, check for flush signals
- **Expected**: `flush_id` and `flush_ex` true after taken branches
- **Validation**: Verify flush signals appear after branch instructions

### 7.2 Disassembler Tests

#### T8: R-Type Instructions
- **Test**: Disassemble all R-type instructions (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND)
- **Expected**: Correct mnemonic and register operands
- **Validation**: `0x003100b3` -> "add x1, x2, x3"

#### T9: I-Type Instructions
- **Test**: Disassemble ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
- **Expected**: Correct mnemonic, register, and immediate
- **Validation**: `0x00500093` -> "addi x1, x0, 5"

#### T10: Load Instructions
- **Test**: Disassemble LB, LH, LW, LBU, LHU
- **Expected**: Correct format with offset(base)
- **Validation**: `0x00012083` -> "lw x1, 0(x2)"

#### T11: Store Instructions
- **Test**: Disassemble SB, SH, SW
- **Expected**: Correct format with offset(base)
- **Validation**: `0x00112023` -> "sw x1, 0(x2)"

#### T12: Branch Instructions
- **Test**: Disassemble BEQ, BNE, BLT, BGE, BLTU, BGEU
- **Expected**: Correct comparison registers and offset
- **Validation**: `0x00208463` -> "beq x1, x2, 8"

#### T13: Jump Instructions
- **Test**: Disassemble JAL, JALR
- **Expected**: Correct link register and target
- **Validation**: `0x008000ef` -> "jal x1, 8"

#### T14: Upper Immediate Instructions
- **Test**: Disassemble LUI, AUIPC
- **Expected**: Correct destination and upper immediate
- **Validation**: `0x123450b7` -> "lui x1, 0x12345"

#### T15: System Instructions
- **Test**: Disassemble ECALL, EBREAK
- **Expected**: Correct mnemonic
- **Validation**: `0x00000073` -> "ecall"

### 7.3 Backend API Tests

#### T16: Server Startup
- **Test**: Run `python app.py`, check server starts
- **Expected**: Server listening on port 5000
- **Validation**: `curl http://localhost:5000/` returns 200

#### T17: Trace Load Endpoint
- **Test**: POST trace file to `/api/load`
- **Expected**: Returns success with cycle count
- **Validation**: `curl -X POST -F "file=@trace.jsonl" /api/load`

#### T18: Cycle Fetch Endpoint
- **Test**: GET `/api/cycle/0` after loading trace
- **Expected**: Returns JSON with cycle 0 state
- **Validation**: Response contains "cycle": 0

#### T19: Cycle Range Validation
- **Test**: GET `/api/cycle/-1` and `/api/cycle/999999`
- **Expected**: Returns 404 or appropriate error
- **Validation**: Status code is 404

#### T20: Total Cycles Endpoint
- **Test**: GET `/api/cycles` after loading trace
- **Expected**: Returns total cycle count matching trace file
- **Validation**: Count matches `wc -l trace.jsonl`

#### T21: Statistics Endpoint
- **Test**: GET `/api/stats` after loading trace
- **Expected**: Returns execution statistics (CPI, stall count, etc.)
- **Validation**: Stats are mathematically consistent

### 7.4 Frontend Tests

#### T22: Page Load
- **Test**: Open http://localhost:5000 in browser
- **Expected**: Page renders without JavaScript errors
- **Validation**: No errors in browser console

#### T23: File Upload UI
- **Test**: Click "Load Trace" and select file
- **Expected**: File uploads, UI updates with cycle count
- **Validation**: Cycle counter shows correct total

#### T24: Forward Step
- **Test**: Click ">" button starting at cycle 0
- **Expected**: Cycle increments to 1, display updates
- **Validation**: Cycle counter shows 1, data changes

#### T25: Backward Step
- **Test**: Click "<" button starting at cycle 5
- **Expected**: Cycle decrements to 4, display updates
- **Validation**: Cycle counter shows 4

#### T26: First/Last Buttons
- **Test**: Click "|<" from middle, ">|" from start
- **Expected**: Jumps to cycle 0 and last cycle respectively
- **Validation**: Cycle counter shows 0 or max

#### T27: Direct Cycle Input
- **Test**: Type "50" in cycle input and press Enter
- **Expected**: Jumps to cycle 50
- **Validation**: Display shows cycle 50 state

#### T28: Keyboard Navigation
- **Test**: Press Left Arrow, Right Arrow, Space
- **Expected**: Step back, step forward, toggle play
- **Validation**: Cycle changes appropriately

#### T29: Register Display
- **Test**: Load trace and step to cycle where register changes
- **Expected**: Changed register is highlighted
- **Validation**: Visual highlight on modified register

#### T30: Pipeline Stage Display
- **Test**: Load trace with valid instructions in all stages
- **Expected**: All 5 stages show instruction info
- **Validation**: Each stage box contains PC and instruction

### 7.5 Integration Tests

#### T31: End-to-End: test_alu
- **Test**: Generate trace from test_alu, load in visualizer, verify final state
- **Expected**: Final register values match expected test output
- **Validation**: x10=0 (pass), other registers per test spec

#### T32: End-to-End: test_fib
- **Test**: Generate trace from test_fib, step through, observe Fibonacci sequence
- **Expected**: Fibonacci numbers appear in registers as computation proceeds
- **Validation**: Can observe 1, 1, 2, 3, 5, 8... in registers

#### T33: Hazard Visualization: Load-Use
- **Test**: Run test_hazard_load_use, observe stall in visualizer
- **Expected**: Stall indicator appears, IF/ID stages freeze for one cycle
- **Validation**: Visual stall indicator, cycle count matches expected

#### T34: Hazard Visualization: Branch
- **Test**: Run test_hazard_branch, observe flush in visualizer
- **Expected**: Flush indicator appears, bubbles inserted in pipeline
- **Validation**: Orange flush indicator, stages show invalid after branch

#### T35: Forwarding Visualization
- **Test**: Run test_hazard_ex_ex, observe forwarding path
- **Expected**: Forwarding arrow/indicator shows data bypass
- **Validation**: Blue forwarding path visible, forward_a/b show source

### 7.6 Cross-Reference Validation

#### T36: Trace vs VCD Comparison
- **Test**: Compare trace.jsonl data to riscvibe_5stage.vcd for same run
- **Expected**: All captured signals match between formats
- **Validation**: Script samples 10 random cycles, compares values

#### T37: Trace vs Testbench Log
- **Test**: Compare trace register dumps to testbench $display output
- **Expected**: Values match at corresponding cycles
- **Validation**: Parse both outputs, diff at interval cycles

### 7.7 Performance Tests

#### T38: Large Trace Load Time
- **Test**: Generate 10,000 cycle trace, measure load time
- **Expected**: Loads in under 5 seconds
- **Validation**: Time from upload to ready < 5s

#### T39: Step Responsiveness
- **Test**: Rapidly click step button 100 times
- **Expected**: UI remains responsive, no lag accumulation
- **Validation**: Each step completes in < 100ms

#### T40: Memory Usage
- **Test**: Load 10,000 cycle trace, check browser memory
- **Expected**: Memory usage under 200MB
- **Validation**: Browser dev tools memory profiler

---

## 8. Future Enhancements (Post-MVP)

1. **Memory Viewer** - Browse data memory contents
2. **Instruction Memory View** - See upcoming instructions
3. **Execution Graph** - Visualize control flow taken
4. **Performance Counters** - CPI, IPC, stall breakdown
5. **Trace Comparison** - Diff two runs
6. **Dark Mode** - User preference
7. **Export to PDF/PNG** - For documentation
8. **Waveform Integration** - Link to VCD viewer

---

## 9. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Large trace files (>100MB) | Slow load, high memory | Lazy loading, pagination |
| Browser compatibility | Features don't work | Test on major browsers, use polyfills |
| SystemVerilog file I/O limits | Can't generate trace | Use simpler format, post-process |
| Complex forwarding visualization | Confusing UI | Iterative design, user testing |

---

## 10. Conclusion

This implementation plan provides a clear path from the current RISC-Vibe processor to a fully interactive pipeline visualizer. The key decisions are:

1. **JSON Lines format** for trace data (structured, extensible)
2. **Web-based GUI** (cross-platform, zero install, rich visualization)
3. **Python Flask backend** (matches existing tooling)
4. **SVG pipeline diagrams** (crisp, interactive)

The phased approach allows for incremental delivery and testing, with the core trace infrastructure as the foundation for all visualization features.

**Estimated effort**: The implementation is straightforward with well-defined components. Each milestone builds on the previous, reducing integration risk.
