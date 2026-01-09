"""
RISC-Vibe Pipeline Trace Parser

Parses JSON Lines trace files from the pipeline simulation.
Each line contains the complete pipeline state for one clock cycle.
"""

import json
from typing import Optional


class TraceParser:
    """
    Parser for JSONL pipeline trace files.

    Loads and indexes trace data for efficient cycle-by-cycle access.
    """

    def __init__(self, filepath: str):
        """Load and index a JSONL trace file."""
        self._cycles: list[dict] = []
        self._cycle_index: dict[int, dict] = {}  # cycle number -> cycle data
        self._load_trace(filepath)

    def _load_trace(self, filepath: str) -> None:
        """Load trace data from file."""
        with open(filepath, 'r') as f:
            for line_num, line in enumerate(f, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    cycle_data = json.loads(line)
                    self._cycles.append(cycle_data)
                    if 'cycle' in cycle_data:
                        self._cycle_index[cycle_data['cycle']] = cycle_data
                except json.JSONDecodeError as e:
                    raise json.JSONDecodeError(
                        f"Invalid JSON on line {line_num}: {e.msg}",
                        e.doc,
                        e.pos
                    )

    def get_cycle(self, n: int) -> Optional[dict]:
        """Get state at cycle n. Uses cycle field if indexed, otherwise position."""
        if n in self._cycle_index:
            return self._cycle_index[n]

        if 0 <= n < len(self._cycles):
            return self._cycles[n]

        return None

    def get_range(self, start: int, end: int) -> list[dict]:
        """Get cycles in range [start, end)."""
        if self._cycle_index:
            return [self._cycle_index[n] for n in range(start, end) if n in self._cycle_index]

        start_idx = max(0, start)
        end_idx = min(len(self._cycles), end)
        return self._cycles[start_idx:end_idx]

    @property
    def total_cycles(self) -> int:
        """Total number of cycles in trace."""
        return len(self._cycles)

    def _get_hazard_keys(self, architecture: dict | None) -> tuple[list[str], list[str]]:
        """Extract stall and flush signal keys from architecture or use defaults."""
        if architecture and 'hazards' in architecture:
            hazards = architecture['hazards']
            stall_keys = [s['key'] for s in hazards.get('stall_signals', [])]
            flush_keys = [s['key'] for s in hazards.get('flush_signals', [])]
        else:
            stall_keys = ['stall_if', 'stall_id']
            flush_keys = ['flush_id', 'flush_ex']
        return stall_keys, flush_keys

    def _get_last_stage_id(self, architecture: dict | None) -> str:
        """Get the last pipeline stage ID for counting retired instructions."""
        if architecture and 'stages' in architecture:
            return architecture['stages'][-1]['id']
        return 'wb'

    def get_stats(self, architecture: dict = None) -> dict:
        """Compute execution statistics from the trace."""
        stall_keys, flush_keys = self._get_hazard_keys(architecture)
        last_stage_id = self._get_last_stage_id(architecture)

        stall_cycles = 0
        flush_cycles = 0
        instructions_retired = 0

        for cycle_data in self._cycles:
            hazard = cycle_data.get('hazard', {})

            if any(hazard.get(key) for key in stall_keys):
                stall_cycles += 1

            if any(hazard.get(key) for key in flush_keys):
                flush_cycles += 1

            last_stage = cycle_data.get(last_stage_id, {})
            if last_stage.get('valid') and last_stage.get('write'):
                instructions_retired += 1

        cpi = len(self._cycles) / instructions_retired if instructions_retired > 0 else 0.0

        return {
            'total_cycles': len(self._cycles),
            'stall_cycles': stall_cycles,
            'flush_cycles': flush_cycles,
            'instructions_retired': instructions_retired,
            'cpi': round(cpi, 2)
        }
