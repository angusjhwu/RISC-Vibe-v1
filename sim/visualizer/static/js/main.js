/**
 * RISC-Vibe Pipeline Visualizer - Main Application Logic
 *
 * This module handles the interactive visualization of pipeline traces,
 * including playback controls, register file display, and hazard/forwarding status.
 * Supports dynamic architecture configurations via YAML files.
 */

// =============================================================================
// Application State
// =============================================================================

const state = {
    cycles: [],             // Array of cycle states
    currentCycle: 0,        // Current cycle index
    totalCycles: 0,         // Total number of cycles
    isPlaying: false,       // Playback state
    playbackSpeed: 5,       // Cycles per second
    playbackTimer: null,    // Timer ID for playback
    previousRegs: null,     // Previous cycle's register values (for highlighting changes)
    regDisplayHex: true,    // Register display format: true=hex, false=decimal
    programListing: [],     // Array of {pc, instr, asm} objects for program view
    architecture: null,     // Loaded architecture definition
    stageElements: {},      // Dynamic stage DOM element references
    hazardElements: {},     // Dynamic hazard DOM element references
    forwardElements: {}     // Dynamic forward DOM element references
};

// Default ABI register names (can be overridden by architecture)
const DEFAULT_ABI_NAMES = [
    'zero', 'ra', 'sp', 'gp', 'tp', 't0', 't1', 't2',
    's0/fp', 's1', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5',
    'a6', 'a7', 's2', 's3', 's4', 's5', 's6', 's7',
    's8', 's9', 's10', 's11', 't3', 't4', 't5', 't6'
];

// =============================================================================
// DOM Element References
// =============================================================================

let elements = {};

function initElements() {
    elements = {
        // Header
        loadArchBtn: document.getElementById('load-arch-btn'),
        archFileInput: document.getElementById('arch-file-input'),
        loadTraceBtn: document.getElementById('load-trace-btn'),
        traceFileInput: document.getElementById('trace-file-input'),
        archName: document.getElementById('arch-name'),

        // Loading/Error
        loadingOverlay: document.getElementById('loading-overlay'),
        loadingMessage: document.getElementById('loading-message'),
        errorToast: document.getElementById('error-toast'),
        errorMessage: document.getElementById('error-message'),
        errorClose: document.getElementById('error-close'),

        // Pipeline container (stages generated dynamically)
        pipelineContainer: document.getElementById('pipeline-container'),
        noArchMessage: document.getElementById('no-arch-message'),
        forwardingArrows: document.getElementById('forwarding-arrows'),
        arrowDefs: document.getElementById('arrow-defs'),

        // Registers
        registerSection: document.getElementById('register-section'),
        registerGrid: document.getElementById('register-grid'),

        // Controls
        btnFirst: document.getElementById('btn-first'),
        btnPrev: document.getElementById('btn-prev'),
        btnPlay: document.getElementById('btn-play'),
        btnNext: document.getElementById('btn-next'),
        btnLast: document.getElementById('btn-last'),
        cycleInput: document.getElementById('cycle-input'),
        totalCyclesEl: document.getElementById('total-cycles'),
        speedSlider: document.getElementById('speed-slider'),
        speedValue: document.getElementById('speed-value'),

        // Hazards and Forwarding (containers - content generated dynamically)
        hazardSection: document.getElementById('hazard-section'),
        hazardGrid: document.getElementById('hazard-grid'),
        forwardSection: document.getElementById('forward-section'),
        forwardGrid: document.getElementById('forward-grid'),

        // Register format toggle
        regFormatToggle: document.getElementById('reg-format-toggle')
    };
}

// =============================================================================
// Initialization
// =============================================================================

function init() {
    initElements();
    bindEventListeners();
    bindKeyboardShortcuts();
    updateControlsState();
}

// =============================================================================
// Event Listeners
// =============================================================================

function bindEventListeners() {
    // Load architecture button
    if (elements.loadArchBtn) {
        elements.loadArchBtn.addEventListener('click', () => {
            elements.archFileInput.click();
        });
    }

    if (elements.archFileInput) {
        elements.archFileInput.addEventListener('change', handleArchitectureSelect);
    }

    // Load trace button
    if (elements.loadTraceBtn) {
        elements.loadTraceBtn.addEventListener('click', () => {
            elements.traceFileInput.click();
        });
    }

    if (elements.traceFileInput) {
        elements.traceFileInput.addEventListener('change', handleFileSelect);
    }

    // Error toast close
    if (elements.errorClose) {
        elements.errorClose.addEventListener('click', hideError);
    }

    // Playback controls
    if (elements.btnFirst) elements.btnFirst.addEventListener('click', goToFirst);
    if (elements.btnPrev) elements.btnPrev.addEventListener('click', goToPrev);
    if (elements.btnPlay) elements.btnPlay.addEventListener('click', togglePlayback);
    if (elements.btnNext) elements.btnNext.addEventListener('click', goToNext);
    if (elements.btnLast) elements.btnLast.addEventListener('click', goToLast);

    // Cycle input
    if (elements.cycleInput) {
        elements.cycleInput.addEventListener('change', handleCycleInput);
        elements.cycleInput.addEventListener('keyup', (e) => {
            if (e.key === 'Enter') handleCycleInput();
        });
    }

    // Speed slider
    if (elements.speedSlider) {
        elements.speedSlider.addEventListener('input', handleSpeedChange);
    }

    // Register format toggle
    if (elements.regFormatToggle) {
        elements.regFormatToggle.addEventListener('change', handleRegFormatToggle);
    }
}

function bindKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
        if (e.target.tagName === 'INPUT') return;

        switch (e.key) {
            case 'ArrowLeft':
                e.preventDefault();
                goToPrev();
                break;
            case 'ArrowRight':
                e.preventDefault();
                goToNext();
                break;
            case ' ':
                e.preventDefault();
                togglePlayback();
                break;
            case 'Home':
                e.preventDefault();
                goToFirst();
                break;
            case 'End':
                e.preventDefault();
                goToLast();
                break;
        }
    });
}

// =============================================================================
// Architecture Loading
// =============================================================================

async function handleArchitectureSelect(event) {
    const file = event.target.files[0];
    if (!file) return;

    showLoading('Loading architecture...');

    try {
        const formData = new FormData();
        formData.append('file', file);

        const response = await fetch('/api/architecture', {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.message || 'Failed to load architecture');
        }

        // Store architecture and generate UI
        state.architecture = data.architecture;
        loadArchitecture(data.architecture);

        // Update architecture name display
        if (elements.archName) {
            elements.archName.textContent = data.summary?.name || 'Unknown';
        }

        // Enable trace loading
        if (elements.loadTraceBtn) {
            elements.loadTraceBtn.disabled = false;
        }

        // Clear any existing trace data
        state.cycles = [];
        state.totalCycles = 0;
        state.currentCycle = 0;
        updateControlsState();

        hideLoading();

    } catch (error) {
        hideLoading();
        showError(error.message);
    }

    event.target.value = '';
}

/**
 * Load architecture configuration and generate dynamic UI elements.
 */
function loadArchitecture(arch) {
    state.architecture = arch;

    // Generate pipeline stages
    generatePipelineStages(arch);

    // Generate hazard indicators
    generateHazardIndicators(arch);

    // Generate forwarding indicators
    generateForwardingIndicators(arch);

    // Generate arrow markers for forwarding
    generateArrowMarkers(arch);

    // Initialize register grid based on architecture
    initRegisterGrid(arch);

    // Hide the "no architecture" message
    if (elements.noArchMessage) {
        elements.noArchMessage.style.display = 'none';
    }

    // Show/hide sections based on architecture config
    if (elements.hazardSection) {
        const hasHazards = arch.hazards &&
            ((arch.hazards.stall_signals?.length > 0) ||
             (arch.hazards.flush_signals?.length > 0));
        elements.hazardSection.style.display = hasHazards ? 'block' : 'none';
    }

    if (elements.forwardSection) {
        const hasForwarding = arch.forwarding?.enabled &&
                              arch.forwarding?.paths?.length > 0;
        elements.forwardSection.style.display = hasForwarding ? 'block' : 'none';
    }

    if (elements.registerSection) {
        const hasRegFile = arch.register_file?.enabled !== false;
        elements.registerSection.style.display = hasRegFile ? 'block' : 'none';
    }
}

/**
 * Generate pipeline stage DOM elements based on architecture definition.
 */
function generatePipelineStages(arch) {
    const container = elements.pipelineContainer;
    if (!container) return;

    // Clear existing stages (preserve SVG and message)
    const svg = elements.forwardingArrows;
    const noArchMsg = elements.noArchMessage;

    container.innerHTML = '';
    if (svg) container.appendChild(svg);
    if (noArchMsg) container.appendChild(noArchMsg);

    state.stageElements = {};

    const stages = arch.stages || [];

    stages.forEach((stageCfg, index) => {
        // Create stage div
        const stageDiv = document.createElement('div');
        stageDiv.className = 'stage';
        stageDiv.id = `stage-${stageCfg.id}`;

        // Create stage header
        const header = document.createElement('div');
        header.className = 'stage-header';
        header.textContent = stageCfg.name;
        stageDiv.appendChild(header);

        // Create stage body
        const body = document.createElement('div');
        body.className = 'stage-body';

        // Add main fields
        if (stageCfg.fields) {
            for (const field of stageCfg.fields) {
                const fieldDiv = document.createElement('div');
                fieldDiv.className = field.class || 'stage-field';
                fieldDiv.id = `${stageCfg.id}-${field.key || 'static'}`;
                if (field.format === 'hex_compact' || field.format === 'hex') {
                    fieldDiv.classList.add('mono');
                }
                fieldDiv.textContent = '---';
                body.appendChild(fieldDiv);
            }
        }

        // Add detail fields
        if (stageCfg.detail_fields && stageCfg.detail_fields.length > 0) {
            const detailDiv = document.createElement('div');
            detailDiv.className = 'stage-detail';

            for (const field of stageCfg.detail_fields) {
                if (field.label) {
                    const labelSpan = document.createElement('span');
                    labelSpan.className = 'field-label';
                    labelSpan.textContent = field.label;
                    detailDiv.appendChild(labelSpan);
                }

                if (field.format !== 'static') {
                    const valueSpan = document.createElement('span');
                    valueSpan.id = `${stageCfg.id}-${field.key}`;
                    if (field.format === 'hex_compact' || field.format === 'hex' ||
                        field.format === 'hex_smart') {
                        valueSpan.classList.add('mono');
                    }
                    valueSpan.textContent = '---';
                    detailDiv.appendChild(valueSpan);
                }
            }

            body.appendChild(detailDiv);
        }

        stageDiv.appendChild(body);

        // Insert before SVG and message
        if (svg) {
            container.insertBefore(stageDiv, svg);
        } else {
            container.appendChild(stageDiv);
        }

        // Add arrow between stages (except after last)
        if (index < stages.length - 1) {
            const arrow = document.createElement('div');
            arrow.className = 'arrow';
            arrow.innerHTML = '&rarr;';
            if (svg) {
                container.insertBefore(arrow, svg);
            } else {
                container.appendChild(arrow);
            }
        }

        // Store reference
        state.stageElements[stageCfg.id] = stageDiv;
    });
}

/**
 * Generate hazard indicator DOM elements based on architecture.
 */
function generateHazardIndicators(arch) {
    const grid = elements.hazardGrid;
    if (!grid) return;

    grid.innerHTML = '';
    state.hazardElements = {};

    if (!arch.hazards) return;

    const allSignals = [
        ...(arch.hazards.stall_signals || []),
        ...(arch.hazards.flush_signals || [])
    ];

    for (const signal of allSignals) {
        const item = document.createElement('div');
        item.className = 'hazard-item';

        const dot = document.createElement('span');
        dot.className = 'hazard-dot';
        dot.id = `hazard-${signal.key}`;
        item.appendChild(dot);

        const label = document.createElement('span');
        label.className = 'hazard-label';
        label.textContent = signal.label || signal.key;
        item.appendChild(label);

        grid.appendChild(item);

        state.hazardElements[signal.key] = dot;
    }
}

/**
 * Generate forwarding indicator DOM elements based on architecture.
 */
function generateForwardingIndicators(arch) {
    const grid = elements.forwardGrid;
    if (!grid) return;

    grid.innerHTML = '';
    state.forwardElements = {};

    const forwarding = arch.forwarding;
    if (!forwarding?.enabled || !forwarding?.paths) return;

    for (const path of forwarding.paths) {
        const item = document.createElement('div');
        item.className = 'forward-item';

        const label = document.createElement('span');
        label.className = 'forward-label';
        label.textContent = `${path.label || path.key}:`;
        item.appendChild(label);

        const value = document.createElement('span');
        value.className = 'forward-value';
        value.id = `forward-${path.key}`;
        value.textContent = 'NONE';
        item.appendChild(value);

        grid.appendChild(item);

        state.forwardElements[path.key] = value;
    }
}

/**
 * Generate SVG arrow markers based on architecture forwarding config.
 */
function generateArrowMarkers(arch) {
    const defs = elements.arrowDefs;
    if (!defs) return;

    defs.innerHTML = '';

    const forwarding = arch.forwarding;
    if (!forwarding?.enabled || !forwarding?.paths) return;

    // Collect unique colors from sources
    const colorMap = new Map();

    for (const path of forwarding.paths) {
        if (path.sources) {
            for (const source of path.sources) {
                if (source.color && !colorMap.has(source.stage)) {
                    colorMap.set(source.stage, source.color);
                }
            }
        }
    }

    // Create markers for each unique source stage
    for (const [stage, color] of colorMap) {
        const marker = document.createElementNS('http://www.w3.org/2000/svg', 'marker');
        marker.setAttribute('id', `arrowhead-${stage}`);
        marker.setAttribute('markerWidth', '8');
        marker.setAttribute('markerHeight', '8');
        marker.setAttribute('refX', '6');
        marker.setAttribute('refY', '4');
        marker.setAttribute('orient', 'auto');

        const polygon = document.createElementNS('http://www.w3.org/2000/svg', 'polygon');
        polygon.setAttribute('points', '0 0, 8 4, 0 8');
        polygon.setAttribute('fill', color);

        marker.appendChild(polygon);
        defs.appendChild(marker);
    }
}

/**
 * Initialize register grid based on architecture config.
 */
function initRegisterGrid(arch) {
    if (!elements.registerGrid) return;
    elements.registerGrid.innerHTML = '';

    const regFile = arch.register_file || {};
    const count = regFile.count || 32;
    const abiNames = regFile.abi_names || DEFAULT_ABI_NAMES;

    for (let i = 0; i < count; i++) {
        const cell = document.createElement('div');
        cell.className = 'register-cell';
        cell.id = `reg-${i}`;
        const abiName = abiNames[i] || `x${i}`;
        cell.title = `x${i} (${abiName})`;
        cell.innerHTML = `
            <span class="register-name">x${i}</span>
            <span class="register-value mono" id="reg-val-${i}">0x00000000</span>
        `;
        elements.registerGrid.appendChild(cell);
    }
}

// =============================================================================
// File Handling
// =============================================================================

async function handleFileSelect(event) {
    const file = event.target.files[0];
    if (!file) return;

    if (!state.architecture) {
        showError('Please load an architecture file first');
        event.target.value = '';
        return;
    }

    showLoading('Loading trace...');

    try {
        const formData = new FormData();
        formData.append('file', file);

        // Upload to server using /api/load endpoint
        const response = await fetch('/api/load', {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (!response.ok) {
            let errorMsg = data.message || 'Failed to upload trace file';
            if (data.details && data.details.length > 0) {
                errorMsg += '\n' + data.details.slice(0, 5).join('\n');
            }
            throw new Error(errorMsg);
        }

        if (!data.success) {
            throw new Error(data.message || 'Failed to load trace');
        }

        // Now fetch all cycles
        const rangeResponse = await fetch(`/api/range/0/${data.cycles}`);
        if (!rangeResponse.ok) {
            throw new Error('Failed to fetch cycle data');
        }

        const rangeData = await rangeResponse.json();

        state.cycles = rangeData.cycles || [];
        state.totalCycles = state.cycles.length;
        state.currentCycle = 0;
        state.previousRegs = null;

        // Build and render program listing
        buildProgramListing();
        renderProgramListing();

        // Update UI
        if (elements.totalCyclesEl) {
            elements.totalCyclesEl.textContent = state.totalCycles > 0 ? state.totalCycles - 1 : 0;
        }
        if (elements.cycleInput) {
            elements.cycleInput.max = state.totalCycles > 0 ? state.totalCycles - 1 : 0;
            elements.cycleInput.value = 0;
        }

        // Render first cycle
        if (state.totalCycles > 0) {
            renderCycle(0);
        }

        updateControlsState();
        hideLoading();

    } catch (error) {
        hideLoading();
        showError(error.message);
    }

    event.target.value = '';
}

// =============================================================================
// Playback Controls
// =============================================================================

function goToFirst() {
    if (state.totalCycles === 0) return;
    goToCycle(0);
}

function goToPrev() {
    if (state.currentCycle > 0) {
        goToCycle(state.currentCycle - 1);
    }
}

function goToNext() {
    if (state.currentCycle < state.totalCycles - 1) {
        goToCycle(state.currentCycle + 1);
    }
}

function goToLast() {
    if (state.totalCycles === 0) return;
    goToCycle(state.totalCycles - 1);
}

function goToCycle(cycleNum) {
    if (cycleNum < 0 || cycleNum >= state.totalCycles) return;

    state.previousRegs = state.cycles[state.currentCycle]?.regs || null;
    state.currentCycle = cycleNum;
    renderCycle(cycleNum);
    if (elements.cycleInput) elements.cycleInput.value = cycleNum;
    updateControlsState();
}

function handleCycleInput() {
    const value = parseInt(elements.cycleInput.value, 10);
    if (!isNaN(value) && value >= 0 && value < state.totalCycles) {
        goToCycle(value);
    } else {
        elements.cycleInput.value = state.currentCycle;
    }
}

function togglePlayback() {
    if (state.totalCycles === 0) return;

    state.isPlaying = !state.isPlaying;

    if (state.isPlaying) {
        elements.btnPlay.innerHTML = '&#10074;&#10074;';
        elements.btnPlay.classList.add('playing');
        startPlayback();
    } else {
        elements.btnPlay.innerHTML = '&#9658;';
        elements.btnPlay.classList.remove('playing');
        stopPlayback();
    }
}

function startPlayback() {
    if (state.playbackTimer) clearInterval(state.playbackTimer);

    const interval = 1000 / state.playbackSpeed;
    state.playbackTimer = setInterval(() => {
        if (state.currentCycle < state.totalCycles - 1) {
            goToNext();
        } else {
            togglePlayback();
        }
    }, interval);
}

function stopPlayback() {
    if (state.playbackTimer) {
        clearInterval(state.playbackTimer);
        state.playbackTimer = null;
    }
}

function handleSpeedChange() {
    state.playbackSpeed = parseInt(elements.speedSlider.value, 10);
    if (elements.speedValue) elements.speedValue.textContent = state.playbackSpeed;

    if (state.isPlaying) startPlayback();
}

function handleRegFormatToggle() {
    state.regDisplayHex = !elements.regFormatToggle.checked;
    // Re-render registers with new format
    if (state.totalCycles > 0) {
        renderRegisters(state.cycles[state.currentCycle]);
    }
}

function updateControlsState() {
    const hasData = state.totalCycles > 0;
    const atStart = state.currentCycle === 0;
    const atEnd = state.currentCycle >= state.totalCycles - 1;

    if (elements.btnFirst) elements.btnFirst.disabled = !hasData || atStart;
    if (elements.btnPrev) elements.btnPrev.disabled = !hasData || atStart;
    if (elements.btnPlay) elements.btnPlay.disabled = !hasData;
    if (elements.btnNext) elements.btnNext.disabled = !hasData || atEnd;
    if (elements.btnLast) elements.btnLast.disabled = !hasData || atEnd;
    if (elements.cycleInput) elements.cycleInput.disabled = !hasData;
}

// =============================================================================
// Rendering
// =============================================================================

function renderCycle(cycleNum) {
    const cycle = state.cycles[cycleNum];
    if (!cycle) return;

    renderPipelineStages(cycle);
    renderRegisters(cycle);
    renderForwarding(cycle);
    renderHazards(cycle);
    updateProgramLetters(cycle);
    renderForwardingArrows(cycle);
}

/**
 * Render all pipeline stages based on architecture configuration.
 */
function renderPipelineStages(cycle) {
    const arch = state.architecture;
    if (!arch || !arch.stages) return;

    for (const stageCfg of arch.stages) {
        const stageData = cycle[stageCfg.id] || {};
        renderStage(stageCfg, stageData, cycle.hazard || {});
    }
}

/**
 * Render a single pipeline stage.
 */
function renderStage(stageCfg, stageData, hazard) {
    const stageEl = state.stageElements[stageCfg.id];
    if (!stageEl) return;

    // Render main fields
    if (stageCfg.fields) {
        for (const field of stageCfg.fields) {
            const fieldEl = document.getElementById(`${stageCfg.id}-${field.key || 'static'}`);
            if (!fieldEl) continue;

            const value = stageData[field.key];
            fieldEl.textContent = formatField(value, field, stageData);
        }
    }

    // Render detail fields
    if (stageCfg.detail_fields) {
        for (const field of stageCfg.detail_fields) {
            if (field.format === 'static') continue;

            const fieldEl = document.getElementById(`${stageCfg.id}-${field.key}`);
            if (!fieldEl) continue;

            const value = stageData[field.key];
            fieldEl.textContent = formatField(value, field, stageData);
        }
    }

    // Update stage class (valid/stalled/flushed)
    updateStageClass(stageCfg.id, stageData.valid, hazard);
}

/**
 * Format a field value based on its format type.
 */
function formatField(value, fieldCfg, stageData) {
    const format = fieldCfg.format;

    // Handle undefined/null values
    if (value === undefined || value === null) {
        if (format === 'static') return '';
        if (format === 'memory_op') return formatMemoryOp(stageData);
        if (format === 'writeback') return formatWriteback(stageData);
        return '---';
    }

    switch (format) {
        case 'hex_compact':
            return formatPC(value);

        case 'hex':
            return formatHex(value);

        case 'decimal':
            return formatDecimal(value);

        case 'hex_smart':
            return formatResult(value);

        case 'disasm':
            // Only disasm if stage is valid
            if (stageData.valid === false) return '---';
            return disasm(value);

        case 'register':
            return typeof value === 'number' ? `x${value}` : '--';

        case 'string':
            return value.toString();

        case 'memory_op':
            return formatMemoryOp(stageData);

        case 'writeback':
            return formatWriteback(stageData);

        default:
            return value.toString();
    }
}

/**
 * Format memory operation based on stage data.
 */
function formatMemoryOp(stageData) {
    if (!stageData.valid) return '---';
    if (stageData.read) return `R @${formatAddr(stageData.addr)}`;
    if (stageData.write) return `W @${formatAddr(stageData.addr)}`;
    return '---';
}

/**
 * Format writeback operation based on stage data.
 */
function formatWriteback(stageData) {
    if (!stageData.valid) return '---';
    if (stageData.write && stageData.rd !== 0) {
        return `x${stageData.rd} <- ${formatResult(stageData.data)}`;
    }
    return '---';
}

/**
 * Format PC as compact hex (e.g., "0x0010")
 */
function formatPC(pc) {
    if (!pc) return '---';
    const val = parseInt(pc, 16);
    if (isNaN(val)) return pc;
    return '0x' + val.toString(16).padStart(4, '0');
}

/**
 * Format as full hex
 */
function formatHex(value) {
    if (!value) return '---';
    const val = parseInt(value, 16);
    if (isNaN(val)) return value;
    return '0x' + val.toString(16).padStart(8, '0');
}

/**
 * Format as decimal
 */
function formatDecimal(value) {
    if (!value) return '---';
    const val = parseInt(value, 16);
    if (isNaN(val)) return value;
    return val.toString(10);
}

/**
 * Format address compactly
 */
function formatAddr(addr) {
    if (!addr) return '---';
    const val = parseInt(addr, 16);
    if (isNaN(val)) return addr;
    return '0x' + val.toString(16);
}

/**
 * Format result value compactly (decimal if small, hex if large)
 */
function formatResult(result) {
    if (!result) return '---';
    const val = parseInt(result, 16);
    if (isNaN(val)) return result;
    // Show small values in decimal, large in hex
    if (val <= 999) return val.toString(10);
    return '0x' + val.toString(16);
}

/**
 * Update stage visual class based on valid/stall/flush state.
 */
function updateStageClass(stageId, valid, hazard) {
    const stageEl = state.stageElements[stageId];
    if (!stageEl) return;

    hazard = hazard || {};

    // Check if this stage is stalled or flushed based on architecture
    let stalled = false;
    let flushed = false;

    const arch = state.architecture;
    if (arch && arch.hazards) {
        // Check stall signals
        for (const signal of arch.hazards.stall_signals || []) {
            if (signal.stage === stageId && hazard[signal.key]) {
                stalled = true;
                break;
            }
        }

        // Check flush signals
        for (const signal of arch.hazards.flush_signals || []) {
            if (signal.stage === stageId && hazard[signal.key]) {
                flushed = true;
                break;
            }
        }
    }

    stageEl.classList.remove('valid', 'invalid', 'stalled', 'flushed');

    if (flushed) {
        stageEl.classList.add('flushed');
    } else if (stalled) {
        stageEl.classList.add('stalled');
    } else if (valid) {
        stageEl.classList.add('valid');
    } else {
        stageEl.classList.add('invalid');
    }
}

function renderRegisters(cycle) {
    const arch = state.architecture;
    const regFile = arch?.register_file || {};
    const sourceField = regFile.source_field || 'regs';
    const count = regFile.count || 32;

    const regs = cycle[sourceField] || [];
    const prevRegs = state.previousRegs || [];

    for (let i = 0; i < count; i++) {
        const cell = document.getElementById(`reg-${i}`);
        const valueEl = document.getElementById(`reg-val-${i}`);
        if (!cell || !valueEl) continue;

        let value = regs[i];
        valueEl.textContent = formatRegValue(value);

        // Highlight changed registers
        if (prevRegs.length > 0 && regs[i] !== prevRegs[i]) {
            cell.classList.remove('changed');
            void cell.offsetWidth; // Force reflow
            cell.classList.add('changed');
        }
    }
}

/**
 * Format a register value based on the current display mode (hex or decimal)
 */
function formatRegValue(value) {
    // Convert to numeric value first
    let numValue = 0;
    if (typeof value === 'string' && value.startsWith('0x')) {
        numValue = parseInt(value, 16) >>> 0; // >>> 0 ensures unsigned 32-bit
    } else if (typeof value === 'number') {
        numValue = value >>> 0;
    }

    if (state.regDisplayHex) {
        // Hex format: 0xXXXXXXXX
        return '0x' + numValue.toString(16).padStart(8, '0').toUpperCase();
    } else {
        // Decimal format: unsigned 32-bit integer
        return numValue.toString(10);
    }
}

function renderForwarding(cycle) {
    const arch = state.architecture;
    const forwarding = arch?.forwarding;

    if (!forwarding?.enabled || !forwarding?.paths) return;

    const sourceField = forwarding.source_field || 'forward';
    const fwd = cycle[sourceField] || {};

    for (const path of forwarding.paths) {
        const el = state.forwardElements[path.key];
        if (!el) continue;

        const value = fwd[path.key];
        updateForwardingIndicator(el, value, path);
    }
}

function updateForwardingIndicator(el, value, pathCfg) {
    if (!el) return;

    // Remove all source-based classes
    el.classList.remove('none', 'mem', 'wb');
    for (const source of pathCfg.sources || []) {
        el.classList.remove(source.stage);
    }

    // Find matching source
    let matched = false;
    for (const source of pathCfg.sources || []) {
        if (value === source.value) {
            el.textContent = source.value;
            el.classList.add(source.stage);
            el.style.color = source.color || '';
            matched = true;
            break;
        }
    }

    if (!matched) {
        el.textContent = 'NONE';
        el.classList.add('none');
        el.style.color = '';
    }
}

function renderHazards(cycle) {
    const hazard = cycle.hazard || {};

    for (const key of Object.keys(state.hazardElements)) {
        const el = state.hazardElements[key];
        updateHazardDot(el, hazard[key]);
    }
}

function updateHazardDot(el, active) {
    if (!el) return;
    if (active) {
        el.classList.add('active');
    } else {
        el.classList.remove('active');
    }
}

// =============================================================================
// Forwarding Arrows
// =============================================================================

/**
 * Render forwarding arrows on the pipeline diagram.
 */
function renderForwardingArrows(cycle) {
    const svg = elements.forwardingArrows;
    if (!svg) return;

    const arch = state.architecture;
    const forwarding = arch?.forwarding;

    if (!forwarding?.enabled) return;

    const sourceField = forwarding.source_field || 'forward';
    const forward = cycle[sourceField] || {};

    // Clear existing arrows (keep defs)
    const defs = svg.querySelector('defs');
    svg.innerHTML = '';
    if (defs) svg.appendChild(defs);

    const container = svg.parentElement;
    if (!container) return;

    const containerRect = container.getBoundingClientRect();

    // Group by source stage to draw combined arrows
    const sourceArrows = new Map();  // sourceStage -> {labels: [], color: ''}

    for (const path of forwarding.paths || []) {
        const value = forward[path.key];
        if (!value || value === 'NONE') continue;

        // Find the source config
        for (const source of path.sources || []) {
            if (value === source.value) {
                if (!sourceArrows.has(source.stage)) {
                    sourceArrows.set(source.stage, {
                        labels: [],
                        color: source.color,
                        targetStage: path.target_stage
                    });
                }
                const info = sourceArrows.get(source.stage);
                // Add label like "rs1" or "rs2" based on path key
                const label = path.key === 'a' ? 'rs1' : (path.key === 'b' ? 'rs2' : path.key);
                if (!info.labels.includes(label)) {
                    info.labels.push(label);
                }
                break;
            }
        }
    }

    // Draw arrows for each source stage
    let yOffsetBase = 20;
    for (const [sourceStage, info] of sourceArrows) {
        const fromStage = state.stageElements[sourceStage];
        const toStage = state.stageElements[info.targetStage];

        if (fromStage && toStage) {
            drawForwardArrow(
                svg,
                fromStage,
                toStage,
                containerRect,
                sourceStage,
                info.labels.join(', '),
                yOffsetBase
            );
            yOffsetBase += 20;
        }
    }
}

/**
 * Draw a single forwarding arrow from one stage to another.
 */
function drawForwardArrow(svg, fromStage, toStage, containerRect, type, label, yOffset) {
    const fromRect = fromStage.getBoundingClientRect();
    const toRect = toStage.getBoundingClientRect();

    // Calculate positions relative to container
    const fromX = fromRect.left - containerRect.left + fromRect.width / 2;
    const fromY = fromRect.bottom - containerRect.top + 5;
    const toX = toRect.left - containerRect.left + toRect.width / 2;
    const toY = toRect.bottom - containerRect.top + 5;

    // Curved path going below the stages
    const midY = Math.max(fromY, toY) + yOffset;
    const controlOffset = 15;

    // Create a smooth curved path
    const path = `M ${fromX} ${fromY}
                  C ${fromX} ${fromY + controlOffset},
                    ${fromX} ${midY},
                    ${(fromX + toX) / 2} ${midY}
                  C ${toX} ${midY},
                    ${toX} ${toY + controlOffset},
                    ${toX} ${toY}`;

    const pathEl = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    pathEl.setAttribute('d', path);
    pathEl.setAttribute('class', `forward-arrow ${type}`);
    pathEl.setAttribute('marker-end', `url(#arrowhead-${type})`);
    svg.appendChild(pathEl);

    // Add label at midpoint below the curve
    const textEl = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    textEl.setAttribute('x', (fromX + toX) / 2);
    textEl.setAttribute('y', midY + 12);
    textEl.setAttribute('text-anchor', 'middle');
    textEl.setAttribute('class', `forward-arrow-label ${type}`);
    textEl.textContent = label;
    svg.appendChild(textEl);
}

// =============================================================================
// Program Listing
// =============================================================================

/**
 * Build the program listing from trace data.
 * Extracts unique (PC, instruction) pairs from the first stage across all cycles.
 */
function buildProgramListing() {
    const seen = new Map();  // PC -> {pc, instr, asm}
    const arch = state.architecture;
    const firstStageId = arch?.stages?.[0]?.id || 'if';

    // Collect unique instructions from first stage across all cycles
    for (const cycle of state.cycles) {
        const firstStage = cycle[firstStageId];
        if (firstStage && firstStage.valid && firstStage.pc && firstStage.instr) {
            const pc = firstStage.pc;
            if (!seen.has(pc)) {
                seen.set(pc, {
                    pc: pc,
                    instr: firstStage.instr,
                    asm: disasm(firstStage.instr)
                });
            }
        }
    }

    // Sort by PC address
    state.programListing = Array.from(seen.values())
        .sort((a, b) => parseInt(a.pc, 16) - parseInt(b.pc, 16));
}

/**
 * Render the program listing with stage indicator letters.
 */
function renderProgramListing() {
    const container = document.getElementById('program-container');
    if (!container) return;

    container.innerHTML = '';

    const arch = state.architecture;
    const stages = arch?.stages || [];

    for (const entry of state.programListing) {
        const row = document.createElement('div');
        row.className = 'program-row';
        row.dataset.pc = entry.pc;

        // Create stage letters div
        const lettersDiv = document.createElement('div');
        lettersDiv.className = 'stage-letters';

        for (const stageCfg of stages) {
            const letterSpan = document.createElement('span');
            letterSpan.className = `stage-letter ${stageCfg.letter.toLowerCase()}`;
            letterSpan.dataset.stage = stageCfg.id;
            letterSpan.textContent = stageCfg.letter;
            lettersDiv.appendChild(letterSpan);
        }

        row.appendChild(lettersDiv);

        // Add PC and assembly
        const pcSpan = document.createElement('span');
        pcSpan.className = 'program-pc';
        pcSpan.textContent = formatPC(entry.pc);
        row.appendChild(pcSpan);

        const asmSpan = document.createElement('span');
        asmSpan.className = 'program-asm';
        asmSpan.textContent = entry.asm;
        row.appendChild(asmSpan);

        container.appendChild(row);
    }
}

/**
 * Update stage indicator letters based on current cycle.
 */
function updateProgramLetters(cycle) {
    const arch = state.architecture;
    const stages = arch?.stages || [];
    const hazard = cycle.hazard || {};

    // Build map of PC -> stage info for current cycle
    const pcToStages = new Map();

    for (const stageCfg of stages) {
        const stageData = cycle[stageCfg.id];
        if (stageData && stageData.pc) {
            const pc = stageData.pc;
            if (!pcToStages.has(pc)) {
                pcToStages.set(pc, []);
            }

            // Check if stalled or flushed based on architecture
            let stalled = false;
            let flushed = false;

            if (arch.hazards) {
                for (const signal of arch.hazards.stall_signals || []) {
                    if (signal.stage === stageCfg.id && hazard[signal.key]) {
                        stalled = true;
                        break;
                    }
                }
                for (const signal of arch.hazards.flush_signals || []) {
                    if (signal.stage === stageCfg.id && hazard[signal.key]) {
                        flushed = true;
                        break;
                    }
                }
            }

            pcToStages.get(pc).push({
                stage: stageCfg.id,
                valid: stageData.valid,
                stalled: stalled,
                flushed: flushed
            });
        }
    }

    // Update all program rows
    const rows = document.querySelectorAll('.program-row');
    for (const row of rows) {
        const pc = row.dataset.pc;
        const stageInfos = pcToStages.get(pc) || [];

        // Update each letter in this row
        const letters = row.querySelectorAll('.stage-letter');
        for (const letter of letters) {
            const stage = letter.dataset.stage;
            const info = stageInfos.find(s => s.stage === stage);

            // Reset classes
            letter.classList.remove('active', 'stalled', 'flushed', 'invalid');

            if (info) {
                if (info.flushed) {
                    letter.classList.add('active', 'flushed');
                } else if (info.stalled) {
                    letter.classList.add('active', 'stalled');
                } else if (info.valid) {
                    letter.classList.add('active');
                } else {
                    letter.classList.add('active', 'invalid');
                }
            }
        }

        // Highlight row if any instruction is in pipeline
        row.classList.toggle('in-pipeline', stageInfos.length > 0);
    }

    // Auto-scroll to the instruction currently being fetched (first stage)
    const firstStageId = stages[0]?.id;
    const firstStagePc = cycle[firstStageId]?.pc;
    if (firstStagePc) {
        const fetchRow = document.querySelector(`.program-row[data-pc="${firstStagePc}"]`);
        if (fetchRow) {
            fetchRow.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
    }
}

// =============================================================================
// UI Utilities
// =============================================================================

function showLoading(message) {
    if (elements.loadingMessage) elements.loadingMessage.textContent = message || 'Loading...';
    if (elements.loadingOverlay) elements.loadingOverlay.classList.remove('hidden');
}

function hideLoading() {
    if (elements.loadingOverlay) elements.loadingOverlay.classList.add('hidden');
}

function showError(message) {
    if (elements.errorMessage) elements.errorMessage.textContent = message;
    if (elements.errorToast) elements.errorToast.classList.remove('hidden');
    setTimeout(hideError, 8000);  // Longer timeout for validation errors
}

function hideError() {
    if (elements.errorToast) elements.errorToast.classList.add('hidden');
}

// =============================================================================
// Initialize Application
// =============================================================================

document.addEventListener('DOMContentLoaded', init);
