# Forwarding GUI Enhancement Plan

## Overview

Improve the data forwarding visualization in the pipeline visualizer by:
1. Clarifying what "Forward A" and "Forward B" mean (rs1/rs2 operands)
2. Adding visual arrows in the pipeline diagram showing data forwarding paths

## Current State

- Forward A = ALU operand A (rs1 source register value)
- Forward B = ALU operand B (rs2 source register value)
- Forwarding sources: NONE (00), WB (01), MEM (10)
- Current GUI shows simple text labels: "Forward A: NONE" and "Forward B: NONE"
- No visual indication of forwarding in the pipeline diagram itself

## Requirements

1. **Clearer Labels**: Change "Forward A" to "rs1 Forward" and "Forward B" to "rs2 Forward"
2. **Visual Arrows**: Draw curved arrows in the pipeline diagram showing:
   - MEM→EX forwarding (from MEM stage back to EX stage)
   - WB→EX forwarding (from WB stage back to EX stage)
3. **Color Coding**:
   - MEM forwarding: Orange arrow
   - WB forwarding: Blue arrow
4. **Arrow Labels**: Show "rs1" or "rs2" on the arrow to indicate which operand

## Implementation

### 1. HTML Changes (index.html)

Add SVG overlay to pipeline container for drawing arrows:

```html
<div class="pipeline-container">
    <svg class="forwarding-arrows" id="forwarding-arrows">
        <!-- Arrows drawn dynamically by JavaScript -->
    </svg>
    <!-- Existing stage boxes -->
</div>
```

Update forwarding section labels:

```html
<div class="forward-item">
    <span class="forward-label">rs1 Forward:</span>
    <span class="forward-value" id="forward-a">NONE</span>
</div>
<div class="forward-item">
    <span class="forward-label">rs2 Forward:</span>
    <span class="forward-value" id="forward-b">NONE</span>
</div>
```

### 2. CSS Changes (style.css)

Add styles for SVG arrows overlay:

```css
.pipeline-container {
    position: relative;  /* Enable absolute positioning for SVG */
}

.forwarding-arrows {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;  /* Don't block clicks on stages */
    overflow: visible;
}

.forward-arrow {
    fill: none;
    stroke-width: 2;
    stroke-linecap: round;
    marker-end: url(#arrowhead);
}

.forward-arrow.mem {
    stroke: var(--stage-flushed);  /* Orange */
}

.forward-arrow.wb {
    stroke: var(--color-blue-500);  /* Blue */
}

.forward-arrow-label {
    font-size: 0.625rem;
    font-weight: 600;
}

.forward-arrow-label.mem {
    fill: var(--stage-flushed);
}

.forward-arrow-label.wb {
    fill: var(--color-blue-500);
}
```

### 3. JavaScript Changes (main.js)

Add function to draw forwarding arrows:

```javascript
function renderForwardingArrows(cycle) {
    const svg = document.getElementById('forwarding-arrows');
    if (!svg) return;

    const forward = cycle.forward || {};
    const forwardA = forward.a || 0;
    const forwardB = forward.b || 0;

    // Clear existing arrows
    svg.innerHTML = `
        <defs>
            <marker id="arrowhead-mem" markerWidth="6" markerHeight="6"
                    refX="5" refY="3" orient="auto">
                <polygon points="0 0, 6 3, 0 6" fill="var(--stage-flushed)"/>
            </marker>
            <marker id="arrowhead-wb" markerWidth="6" markerHeight="6"
                    refX="5" refY="3" orient="auto">
                <polygon points="0 0, 6 3, 0 6" fill="var(--color-blue-500)"/>
            </marker>
        </defs>
    `;

    // Get stage element positions
    const exStage = document.getElementById('stage-ex');
    const memStage = document.getElementById('stage-mem');
    const wbStage = document.getElementById('stage-wb');
    const container = svg.parentElement;

    if (!exStage || !memStage || !wbStage || !container) return;

    const containerRect = container.getBoundingClientRect();

    // Draw MEM→EX arrow if forwarding from MEM
    if (forwardA === 2 || forwardB === 2) {
        const labels = [];
        if (forwardA === 2) labels.push('rs1');
        if (forwardB === 2) labels.push('rs2');
        drawForwardArrow(svg, memStage, exStage, containerRect, 'mem', labels.join(','), -20);
    }

    // Draw WB→EX arrow if forwarding from WB
    if (forwardA === 1 || forwardB === 1) {
        const labels = [];
        if (forwardA === 1) labels.push('rs1');
        if (forwardB === 1) labels.push('rs2');
        drawForwardArrow(svg, wbStage, exStage, containerRect, 'wb', labels.join(','), -40);
    }
}

function drawForwardArrow(svg, fromStage, toStage, containerRect, type, label, yOffset) {
    const fromRect = fromStage.getBoundingClientRect();
    const toRect = toStage.getBoundingClientRect();

    // Calculate positions relative to container
    const fromX = fromRect.left - containerRect.left + fromRect.width / 2;
    const fromY = fromRect.bottom - containerRect.top + 5;
    const toX = toRect.left - containerRect.left + toRect.width / 2;
    const toY = toRect.bottom - containerRect.top + 5;

    // Curved path going below the stages
    const midY = fromY + Math.abs(yOffset);
    const path = `M ${fromX} ${fromY} Q ${fromX} ${midY}, ${(fromX + toX) / 2} ${midY} Q ${toX} ${midY}, ${toX} ${toY}`;

    const pathEl = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    pathEl.setAttribute('d', path);
    pathEl.setAttribute('class', `forward-arrow ${type}`);
    pathEl.setAttribute('marker-end', `url(#arrowhead-${type})`);
    svg.appendChild(pathEl);

    // Add label at midpoint
    const textEl = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    textEl.setAttribute('x', (fromX + toX) / 2);
    textEl.setAttribute('y', midY + 12);
    textEl.setAttribute('text-anchor', 'middle');
    textEl.setAttribute('class', `forward-arrow-label ${type}`);
    textEl.textContent = label;
    svg.appendChild(textEl);
}
```

Update renderCycle to call renderForwardingArrows:

```javascript
function renderCycle(cycleNum) {
    const cycle = state.cycles[cycleNum];
    if (!cycle) return;

    renderPipelineStages(cycle);
    renderRegisters(cycle);
    renderForwarding(cycle);
    renderHazards(cycle);
    updateProgramLetters(cycle);
    renderForwardingArrows(cycle);  // Add this
}
```

## Files to Modify

| File | Changes |
|------|---------|
| `sim/visualizer/templates/index.html` | Add SVG overlay, update forward labels |
| `sim/visualizer/static/css/style.css` | Add arrow styles |
| `sim/visualizer/static/js/main.js` | Add arrow rendering functions |

## Visual Design

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Pipeline Stages                                                         │
│                                                                          │
│  ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐                   │
│  │ IF  │ →  │ ID  │ →  │ EX  │ →  │ MEM │ →  │ WB  │                   │
│  │0x04 │    │0x00 │    │0x04 │    │0x00 │    │0x08 │                   │
│  │addi │    │addi │    │add  │    │addi │    │addi │                   │
│  └─────┘    └─────┘    └──┬──┘    └──┬──┘    └──┬──┘                   │
│                           │          │          │                        │
│                           │    ╭─────╯          │                        │
│                           │◄───┤ rs1 (orange)   │                        │
│                           │    ╰────────────────╯                        │
│                           │◄──────────────────────╯                      │
│                                  rs2 (blue)                              │
└─────────────────────────────────────────────────────────────────────────┘

Legend:
  Orange arrow (MEM→EX): Forwarding from MEM stage result
  Blue arrow (WB→EX): Forwarding from WB stage result
  Labels show which operand (rs1, rs2, or both)
```

## Testing Checklist

1. [ ] Labels updated from "Forward A/B" to "rs1/rs2 Forward"
2. [ ] No arrows when forwarding is NONE
3. [ ] Orange arrow appears for MEM forwarding (forward value = 2)
4. [ ] Blue arrow appears for WB forwarding (forward value = 1)
5. [ ] Arrow shows correct label (rs1, rs2, or both)
6. [ ] Arrows update correctly when stepping through cycles
7. [ ] Arrows position correctly on window resize
