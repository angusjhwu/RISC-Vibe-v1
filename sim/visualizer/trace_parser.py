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
    For MVP, loads entire trace into memory as a list of dicts.
    """

    def __init__(self, filepath: str):
        """
        Load and index a JSONL trace file.

        Args:
            filepath: Path to the JSONL trace file

        Raises:
            FileNotFoundError: If the trace file doesn't exist
            json.JSONDecodeError: If a line contains invalid JSON
        """
        self._cycles: list[dict] = []
        self._filepath = filepath
        self._load_trace(filepath)

    def _load_trace(self, filepath: str) -> None:
        """
        Load trace data from file.

        Args:
            filepath: Path to the JSONL trace file
        """
        with open(filepath, 'r') as f:
            for line_num, line in enumerate(f, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    cycle_data = json.loads(line)
                    self._cycles.append(cycle_data)
                except json.JSONDecodeError as e:
                    raise json.JSONDecodeError(
                        f"Invalid JSON on line {line_num}: {e.msg}",
                        e.doc,
                        e.pos
                    )

    def get_cycle(self, n: int) -> Optional[dict]:
        """
        Get state at cycle n.

        Args:
            n: Cycle number (0-indexed based on position in file,
               or matches 'cycle' field if present)

        Returns:
            Cycle state dict, or None if out of range
        """
        # First try to find by 'cycle' field if it exists
        for cycle_data in self._cycles:
            if cycle_data.get('cycle') == n:
                return cycle_data

        # Fall back to index-based access
        if 0 <= n < len(self._cycles):
            return self._cycles[n]

        return None

    def get_range(self, start: int, end: int) -> list[dict]:
        """
        Get cycles in range [start, end).

        Args:
            start: Start cycle (inclusive)
            end: End cycle (exclusive)

        Returns:
            List of cycle state dicts in the range
        """
        result = []

        # Try to find cycles by 'cycle' field first
        cycle_map = {c.get('cycle'): c for c in self._cycles if 'cycle' in c}

        if cycle_map:
            for n in range(start, end):
                if n in cycle_map:
                    result.append(cycle_map[n])
        else:
            # Fall back to index-based slicing
            start_idx = max(0, start)
            end_idx = min(len(self._cycles), end)
            result = self._cycles[start_idx:end_idx]

        return result

    @property
    def total_cycles(self) -> int:
        """
        Total number of cycles in trace.

        Returns:
            Number of cycles loaded from the trace file
        """
        return len(self._cycles)

    def get_stats(self) -> dict:
        """
        Compute execution statistics from the trace.

        Returns:
            Dict containing:
                - total_cycles: Total number of cycles
                - stall_cycles: Number of cycles with any stall
                - flush_cycles: Number of cycles with any flush
                - instructions_retired: Number of instructions that completed WB
                - cpi: Cycles per instruction (total_cycles / instructions_retired)
        """
        total_cycles = len(self._cycles)
        stall_cycles = 0
        flush_cycles = 0
        instructions_retired = 0

        for cycle_data in self._cycles:
            # Count stall cycles
            hazard = cycle_data.get('hazard', {})
            if hazard.get('stall_if') or hazard.get('stall_id'):
                stall_cycles += 1

            # Count flush cycles
            if hazard.get('flush_id') or hazard.get('flush_ex'):
                flush_cycles += 1

            # Count retired instructions (valid writeback with write enabled)
            wb = cycle_data.get('wb', {})
            if wb.get('valid') and wb.get('write'):
                instructions_retired += 1

        # Calculate CPI (avoid division by zero)
        if instructions_retired > 0:
            cpi = total_cycles / instructions_retired
        else:
            cpi = 0.0

        return {
            'total_cycles': total_cycles,
            'stall_cycles': stall_cycles,
            'flush_cycles': flush_cycles,
            'instructions_retired': instructions_retired,
            'cpi': round(cpi, 2)
        }
