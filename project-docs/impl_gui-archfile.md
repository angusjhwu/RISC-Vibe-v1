# GUI Architecture File Implementation Plan

## Overview

Transform the RiscVibe pipeline visualizer from a hardcoded 5-stage RISC-V implementation to a flexible, architecture-agnostic system driven by YAML configuration files.

**User Requirements:**
- Linear pipeline only (sequential stages A→B→C→D)
- Separate ISA (architecture file defines pipeline structure, not instruction decoding)
- Strict validation (reject traces that don't match architecture schema)
- YAML format for architecture definition

---

## 1. Architecture File Format (YAML)

### Example: `riscv_5stage.yaml`

```yaml
name: "riscv_5stage"
version: "1.0"
description: "Classic 5-stage RISC-V pipeline"

# Pipeline stages (order defines flow direction)
stages:
  - id: "if"                    # Key used in trace files
    name: "IF"                  # Display name in header
    letter: "F"                 # Single letter for program view
    fields:
      - key: "pc"
        format: "hex_compact"
        class: "stage-pc"
      - key: "instr"
        format: "disasm"        # Run through disassembler
        class: "stage-asm"
    detail_fields:
      - key: null
        label: "Fetching"
        format: "static"

  - id: "id"
    name: "ID"
    letter: "D"
    fields:
      - key: "pc"
        format: "hex_compact"
        class: "stage-pc"
      - key: "instr"
        format: "disasm"
        class: "stage-asm"
    detail_fields:
      - key: "rs1"
        label: "rs1:"
        format: "register"
      - key: "rs2"
        label: "rs2:"
        format: "register"

  - id: "ex"
    name: "EX"
    letter: "X"
    fields:
      - key: "pc"
        format: "hex_compact"
        class: "stage-pc"
      - key: "instr"
        format: "disasm"
        class: "stage-asm"
    detail_fields:
      - key: "result"
        label: "Result:"
        format: "hex_smart"

  - id: "mem"
    name: "MEM"
    letter: "M"
    fields:
      - key: "pc"
        format: "hex_compact"
        class: "stage-pc"
      - key: "instr"
        format: "disasm"
        class: "stage-asm"
    detail_fields:
      - key: "mem_op"
        format: "memory_op"     # Special: shows R/W @addr or ---

  - id: "wb"
    name: "WB"
    letter: "W"
    fields:
      - key: "pc"
        format: "hex_compact"
        class: "stage-pc"
      - key: "instr"
        format: "disasm"
        class: "stage-asm"
    detail_fields:
      - key: "wb_info"
        format: "writeback"     # Special: shows xN <- value or ---

# Hazard signals configuration
hazards:
  stall_signals:
    - key: "stall_if"
      stage: "if"
      label: "Stall IF"
    - key: "stall_id"
      stage: "id"
      label: "Stall ID"
  flush_signals:
    - key: "flush_id"
      stage: "id"
      label: "Flush ID"
    - key: "flush_ex"
      stage: "ex"
      label: "Flush EX"

# Forwarding configuration
forwarding:
  enabled: true
  source_field: "forward"       # Top-level trace field
  paths:
    - key: "a"
      label: "rs1 (A)"
      target_stage: "ex"
      sources:
        - stage: "mem"
          value: "MEM"
          color: "#ea580c"      # Orange
        - stage: "wb"
          value: "WB"
          color: "#2563eb"      # Blue
    - key: "b"
      label: "rs2 (B)"
      target_stage: "ex"
      sources:
        - stage: "mem"
          value: "MEM"
          color: "#ea580c"
        - stage: "wb"
          value: "WB"
          color: "#2563eb"

# Register file configuration
register_file:
  enabled: true
  source_field: "regs"
  count: 32
  width: 32
  abi_names:
    - "zero"
    - "ra"
    - "sp"
    - "gp"
    - "tp"
    - "t0"
    - "t1"
    - "t2"
    - "s0/fp"
    - "s1"
    - "a0"
    - "a1"
    - "a2"
    - "a3"
    - "a4"
    - "a5"
    - "a6"
    - "a7"
    - "s2"
    - "s3"
    - "s4"
    - "s5"
    - "s6"
    - "s7"
    - "s8"
    - "s9"
    - "s10"
    - "s11"
    - "t3"
    - "t4"
    - "t5"
    - "t6"

# Trace validation
validation:
  required_top_level:
    - "cycle"
  required_per_stage:
    - "pc"
    - "valid"
```

### Field Format Types

| Format | Description | Example Input | Example Output |
|--------|-------------|---------------|----------------|
| `hex_compact` | Hex with minimal padding | `0x00000004` | `0x0004` |
| `hex` | Full 8-digit hex | `0x04` | `0x00000004` |
| `decimal` | Decimal number | `0x2d` | `45` |
| `hex_smart` | Decimal if <256, else hex | `0x02d` / `0xDEAD` | `45` / `0xdead` |
| `disasm` | Run through ISA disassembler | `0x00100093` | `addi x1, x0, 1` |
| `register` | Format as register name | `5` | `x5` |
| `string` | Pass through unchanged | `"MEM"` | `MEM` |
| `static` | Show label only, no data | - | `Fetching` |
| `memory_op` | Special: R/W @addr | `{read:T,addr:0x10}` | `R @0x0010` |
| `writeback` | Special: xN <- val | `{write:T,rd:1,data:5}` | `x1 <- 5` |

---

## 2. Files to Modify

### Backend (Python)

#### `sim/visualizer/app.py`
- Add `/api/architecture` POST endpoint (upload YAML)
- Add `/api/architecture` GET endpoint (return current architecture)
- Modify `/api/load` to validate trace against architecture
- Add `pyyaml` dependency

#### `sim/visualizer/trace_parser.py`
- Add `validate_against_architecture()` method
- Modify `get_stats()` to use architecture-defined hazard signals

### Frontend (HTML)

#### `sim/visualizer/templates/index.html`
- Add "Load Architecture" button in header (line ~13)
- Replace hardcoded stage divs (lines 48-117) with dynamic container
- Replace hardcoded hazard grid with dynamic container
- Replace hardcoded forwarding grid with dynamic container

### Frontend (JavaScript)

#### `sim/visualizer/static/js/main.js`

**New State:**
```javascript
const state = {
    // ... existing
    architecture: null,         // Loaded architecture
    stageElements: {},          // Dynamic stage DOM refs
    hazardElements: {},         // Dynamic hazard DOM refs
    forwardElements: {},        // Dynamic forward DOM refs
};
```

**New Functions:**
- `handleArchitectureSelect(event)` - File input handler
- `loadArchitecture(archData)` - Store and apply architecture
- `generatePipelineStages(arch)` - Create stage divs dynamically
- `generateHazardIndicators(arch)` - Create hazard dots dynamically
- `generateForwardingIndicators(arch)` - Create forwarding displays
- `generateProgramLetters(arch)` - Create stage letters for program view
- `generateArrowMarkers(arch)` - Create SVG markers with config colors
- `formatField(value, fieldConfig, stageData)` - Apply field formatting
- `renderStage(stageConfig, stageData, hazardData)` - Generic stage renderer

**Refactored Functions:**
- `initElements()` - Add architecture button refs, remove hardcoded stages
- `renderPipelineStages()` - Loop through `state.architecture.stages`
- `updateStageClass()` - Use architecture hazard config
- `renderHazards()` - Use architecture hazard config
- `renderForwarding()` - Use architecture forwarding config
- `renderForwardingArrows()` - Use architecture forwarding paths
- `renderProgramListing()` - Generate letters from `stage.letter`
- `updateProgramLetters()` - Match stages dynamically

### Frontend (CSS)

#### `sim/visualizer/static/css/style.css`
- Add `.no-architecture-message` style
- Add `.btn-secondary` style for architecture button
- Ensure existing stage classes work with dynamic elements

---

## 3. Implementation Phases

### Phase 1: Backend Foundation
1. Add `pyyaml` to `requirements.txt`
2. Create `parse_architecture_yaml()` function with validation
3. Add `/api/architecture` POST endpoint
4. Add `/api/architecture` GET endpoint
5. Create `validate_trace_against_architecture()` function
6. Modify `/api/load` to call validation

### Phase 2: Frontend Architecture Loading
1. Add architecture file input to HTML header
2. Create `handleArchitectureSelect()` in main.js
3. Create `loadArchitecture()` to store in state
4. Add API call to POST architecture file

### Phase 3: Dynamic Stage Generation
1. Create `generatePipelineStages()` - generates stage divs from config
2. Create `formatField()` with all format types
3. Create generic `renderStage()` function
4. Refactor `renderPipelineStages()` to iterate architecture.stages
5. Refactor `updateStageClass()` for dynamic hazard lookup

### Phase 4: Dynamic Hazards & Forwarding
1. Create `generateHazardIndicators()` from architecture.hazards
2. Create `generateForwardingIndicators()` from architecture.forwarding
3. Refactor `renderHazards()` to use config
4. Refactor `renderForwarding()` to use config
5. Create `generateArrowMarkers()` for dynamic colors
6. Refactor `renderForwardingArrows()` for dynamic paths

### Phase 5: Program View Update
1. Refactor `renderProgramListing()` to use `stage.letter`
2. Refactor `updateProgramLetters()` to match dynamic stages

### Phase 6: Create Example Architectures
1. Create `sim/visualizer/architectures/riscv_5stage.yaml`
2. Create `sim/visualizer/architectures/simple_3stage.yaml` (example)

---

## 4. API Endpoints

### New Endpoints

| Method | Endpoint | Request | Response |
|--------|----------|---------|----------|
| POST | `/api/architecture` | YAML file (multipart) | `{success: true, architecture: {...}}` |
| GET | `/api/architecture` | - | `{architecture: {...}}` or `{error: "..."}` |

### Modified Endpoints

| Endpoint | Change |
|----------|--------|
| `POST /api/load` | Add strict validation; return `{success, cycles, errors: [...]}` |
| `GET /api/stats` | Use architecture-defined hazard signal names |

### Error Response Format

```json
{
    "error": "Trace validation failed",
    "details": [
        "Line 5: Missing required field 'ex.result'",
        "Line 12: Unknown stage 'decode' (expected: if, id, ex, mem, wb)"
    ]
}
```

---

## 5. Tests

### 5.1 Architecture Parsing Tests (`test_architecture_parser.py`)

| Test | Input | Expected |
|------|-------|----------|
| `test_valid_yaml` | Well-formed architecture | Success, parsed dict |
| `test_invalid_yaml_syntax` | Malformed YAML | Error with syntax details |
| `test_missing_stages` | No `stages` key | Error: "Missing required field 'stages'" |
| `test_empty_stages` | `stages: []` | Error: "At least one stage required" |
| `test_duplicate_stage_ids` | Two stages with id "ex" | Error: "Duplicate stage id 'ex'" |
| `test_invalid_format_type` | `format: "unknown"` | Error: "Unknown format type" |
| `test_hazard_invalid_stage` | Hazard references non-existent stage | Error: "Stage 'foo' not defined" |
| `test_forwarding_invalid_target` | Forward target not in stages | Error: "Target stage 'bar' not defined" |

### 5.2 Trace Validation Tests (`test_trace_validation.py`)

| Test | Input | Expected |
|------|-------|----------|
| `test_matching_trace` | Trace with all expected stages | Success |
| `test_missing_stage` | Trace missing "mem" stage | Error: "Missing stage 'mem'" |
| `test_missing_required_field` | Stage missing "valid" | Error: "Stage 'ex' missing field 'valid'" |
| `test_missing_hazard_object` | No `hazard` in cycle | Error: "Missing 'hazard' object" |
| `test_missing_forward_object` | No `forward` when forwarding enabled | Error: "Missing 'forward' object" |
| `test_wrong_hazard_keys` | `hazard.stall_fetch` instead of `stall_if` | Error: "Unknown hazard signal 'stall_fetch'" |

### 5.3 Rendering Tests (Manual/E2E)

| Test | Steps | Expected |
|------|-------|----------|
| 5-stage rendering | Load `riscv_5stage.yaml`, load trace | 5 stage boxes with correct labels |
| 3-stage rendering | Load `simple_3stage.yaml`, load matching trace | 3 stage boxes |
| Stage letters | Load arch, load trace, check program view | Letters match `stage.letter` config |
| Forwarding arrows | Load arch with forwarding, trigger forward | Arrows with configured colors |
| Hazard indicators | Load arch with hazards, trigger stall | Correct dots light up |
| No architecture | Try to load trace without architecture | Error: "Load architecture first" |
| Mismatched trace | Load arch, then incompatible trace | Error with specific field mismatches |

### 5.4 Edge Case Tests

| Test | Expected |
|------|----------|
| Architecture with 10 stages | Horizontal scroll, no layout breakage |
| Stage with no detail_fields | Detail section hidden or empty |
| Forwarding disabled | No forwarding section rendered |
| Empty abi_names | Use x0-x31 format |

---

## 6. File Summary

### Files to Create

| File | Purpose |
|------|---------|
| `sim/visualizer/architecture_parser.py` | YAML parsing and validation |
| `sim/visualizer/architectures/riscv_5stage.yaml` | Default 5-stage config |
| `sim/visualizer/architectures/simple_3stage.yaml` | Example 3-stage config |
| `sim/visualizer/tests/test_architecture_parser.py` | Parser unit tests |
| `sim/visualizer/tests/test_trace_validation.py` | Validation unit tests |

### Files to Modify

| File | Changes |
|------|---------|
| `sim/visualizer/app.py` | Add architecture endpoints, trace validation |
| `sim/visualizer/trace_parser.py` | Add architecture-aware validation, dynamic stats |
| `sim/visualizer/templates/index.html` | Replace hardcoded stages with dynamic containers |
| `sim/visualizer/static/js/main.js` | Major refactor for dynamic generation |
| `sim/visualizer/static/css/style.css` | Minor additions for new UI elements |
| `sim/visualizer/requirements.txt` | Add `pyyaml` |

---

## 7. User Workflow

1. **Load Architecture**: Click "Load Architecture" button, select YAML file
2. **Validation**: Architecture file is validated; errors shown if invalid
3. **UI Generation**: Pipeline stages, hazard indicators, forwarding paths generated dynamically
4. **Load Trace**: Click "Load Trace", select JSONL file
5. **Trace Validation**: Trace validated against architecture; errors shown with line numbers
6. **Visualization**: Trace displayed using architecture-defined rendering rules