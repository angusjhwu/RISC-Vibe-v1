/**
 * RISC-Vibe Pipeline Visualizer - Main Application Logic
 *
 * This module handles the interactive visualization of RISC-V pipeline traces,
 * including playback controls, register file display, and hazard/forwarding status.
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
    regDisplayHex: true     // Register display format: true=hex, false=decimal
};

// ABI register names for tooltips
const ABI_NAMES = [
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
        loadTraceBtn: document.getElementById('load-trace-btn'),
        traceFileInput: document.getElementById('trace-file-input'),

        // Loading/Error
        loadingOverlay: document.getElementById('loading-overlay'),
        errorToast: document.getElementById('error-toast'),
        errorMessage: document.getElementById('error-message'),
        errorClose: document.getElementById('error-close'),

        // Pipeline stages
        stages: {
            if: document.getElementById('stage-if'),
            id: document.getElementById('stage-id'),
            ex: document.getElementById('stage-ex'),
            mem: document.getElementById('stage-mem'),
            wb: document.getElementById('stage-wb')
        },

        // Registers
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

        // Hazards
        hazardStallIf: document.getElementById('hazard-stall-if'),
        hazardStallId: document.getElementById('hazard-stall-id'),
        hazardFlushId: document.getElementById('hazard-flush-id'),
        hazardFlushEx: document.getElementById('hazard-flush-ex'),

        // Forwarding
        forwardA: document.getElementById('forward-a'),
        forwardB: document.getElementById('forward-b'),

        // Register format toggle
        regFormatToggle: document.getElementById('reg-format-toggle')
    };
}

// =============================================================================
// Initialization
// =============================================================================

function init() {
    initElements();
    initRegisterGrid();
    bindEventListeners();
    bindKeyboardShortcuts();
    updateControlsState();
}

function initRegisterGrid() {
    if (!elements.registerGrid) return;
    elements.registerGrid.innerHTML = '';

    for (let i = 0; i < 32; i++) {
        const cell = document.createElement('div');
        cell.className = 'register-cell';
        cell.id = `reg-${i}`;
        cell.title = `x${i} (${ABI_NAMES[i]})`;
        cell.innerHTML = `
            <span class="register-name">x${i}</span>
            <span class="register-value mono" id="reg-val-${i}">0x00000000</span>
        `;
        elements.registerGrid.appendChild(cell);
    }
}

// =============================================================================
// Event Listeners
// =============================================================================

function bindEventListeners() {
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
// File Handling
// =============================================================================

async function handleFileSelect(event) {
    const file = event.target.files[0];
    if (!file) return;

    showLoading();

    try {
        const formData = new FormData();
        formData.append('file', file);

        // Upload to server using /api/load endpoint
        const response = await fetch('/api/load', {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.message || 'Failed to upload trace file');
        }

        const data = await response.json();

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
}

function renderPipelineStages(cycle) {
    // IF Stage
    const ifStage = cycle.if || {};
    updateStageField('if-pc', ifStage.pc);
    updateStageField('if-inst-hex', ifStage.instr);
    updateStageField('if-inst-asm', '---'); // IF doesn't have asm in trace
    updateStageValid('if-valid', ifStage.valid !== false);
    updateStageClass('if', ifStage.valid !== false, cycle.hazard);

    // ID Stage
    const idStage = cycle.id || {};
    updateStageField('id-pc', idStage.pc);
    updateStageField('id-inst-hex', idStage.instr);
    updateStageField('id-rs1', idStage.rs1 !== undefined ? `x${idStage.rs1}` : '--');
    updateStageField('id-rs2', idStage.rs2 !== undefined ? `x${idStage.rs2}` : '--');
    updateStageValid('id-valid', idStage.valid);
    updateStageClass('id', idStage.valid, cycle.hazard);

    // EX Stage
    const exStage = cycle.ex || {};
    updateStageField('ex-pc', exStage.pc);
    updateStageField('ex-alu-op', exStage.alu_op || '---');
    updateStageField('ex-alu-result', exStage.result);
    updateStageValid('ex-valid', exStage.valid);
    updateStageClass('ex', exStage.valid, cycle.hazard);

    // MEM Stage
    const memStage = cycle.mem || {};
    updateStageField('mem-addr', memStage.addr);
    const memRW = memStage.read ? 'READ' : (memStage.write ? 'WRITE' : '---');
    updateStageField('mem-rw', memRW);
    updateStageField('mem-rd', memStage.rd !== undefined ? `x${memStage.rd}` : '--');
    updateStageValid('mem-valid', memStage.valid);
    updateStageClass('mem', memStage.valid, cycle.hazard);

    // WB Stage
    const wbStage = cycle.wb || {};
    updateStageField('wb-rd', wbStage.rd !== undefined ? `x${wbStage.rd}` : '--');
    updateStageField('wb-data', wbStage.data);
    updateStageField('wb-src', wbStage.src || '---');
    updateStageValid('wb-valid', wbStage.valid);
    updateStageClass('wb', wbStage.valid, cycle.hazard);
}

function updateStageField(id, value) {
    const el = document.getElementById(id);
    if (!el) return;

    if (value === undefined || value === null) {
        el.textContent = '--------';
    } else if (typeof value === 'string' && value.startsWith('0x')) {
        el.textContent = value.toUpperCase();
    } else {
        el.textContent = value;
    }
}

function updateStageValid(id, valid) {
    const el = document.getElementById(id);
    if (!el) return;
    el.textContent = valid ? 'VALID' : 'BUBBLE';
}

function updateStageClass(stageKey, valid, hazard) {
    const stageEl = elements.stages[stageKey];
    if (!stageEl) return;

    hazard = hazard || {};
    const stalled = (stageKey === 'if' && hazard.stall_if) || (stageKey === 'id' && hazard.stall_id);
    const flushed = (stageKey === 'id' && hazard.flush_id) || (stageKey === 'ex' && hazard.flush_ex);

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
    const regs = cycle.regs || [];
    const prevRegs = state.previousRegs || [];

    for (let i = 0; i < 32; i++) {
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
 * @param {string|number|undefined} value - The register value
 * @returns {string} Formatted string representation
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
    const fwd = cycle.forward || {};

    updateForwardingIndicator(elements.forwardA, fwd.a);
    updateForwardingIndicator(elements.forwardB, fwd.b);
}

function updateForwardingIndicator(el, value) {
    if (!el) return;

    el.classList.remove('none', 'mem', 'wb');

    if (value === 'MEM') {
        el.textContent = 'MEM';
        el.classList.add('mem');
    } else if (value === 'WB') {
        el.textContent = 'WB';
        el.classList.add('wb');
    } else {
        el.textContent = 'NONE';
        el.classList.add('none');
    }
}

function renderHazards(cycle) {
    const hazard = cycle.hazard || {};

    updateHazardDot(elements.hazardStallIf, hazard.stall_if);
    updateHazardDot(elements.hazardStallId, hazard.stall_id);
    updateHazardDot(elements.hazardFlushId, hazard.flush_id);
    updateHazardDot(elements.hazardFlushEx, hazard.flush_ex);
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
// UI Utilities
// =============================================================================

function showLoading() {
    if (elements.loadingOverlay) elements.loadingOverlay.classList.remove('hidden');
}

function hideLoading() {
    if (elements.loadingOverlay) elements.loadingOverlay.classList.add('hidden');
}

function showError(message) {
    if (elements.errorMessage) elements.errorMessage.textContent = message;
    if (elements.errorToast) elements.errorToast.classList.remove('hidden');
    setTimeout(hideError, 5000);
}

function hideError() {
    if (elements.errorToast) elements.errorToast.classList.add('hidden');
}

// =============================================================================
// Initialize Application
// =============================================================================

document.addEventListener('DOMContentLoaded', init);
