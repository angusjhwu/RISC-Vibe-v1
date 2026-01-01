"""
Pipeline hazard analysis and NOP insertion.

This module provides functionality to analyze data dependencies in instruction
sequences and insert NOPs where needed for pipeline hazard mitigation.

Currently stubbed out as the RISC-Vibe 2-stage pipeline handles most hazards
via forwarding. This module is designed to be easily adaptable when the
pipeline structure changes.
"""

from typing import List, Tuple, Optional
from dataclasses import dataclass


@dataclass
class PipelineConfig:
    """
    Configuration for the processor pipeline.

    Attributes:
        stages: Number of pipeline stages
        forwarding_enabled: Whether data forwarding is enabled
        branch_delay_slots: Number of delay slots after branches
        load_use_hazard: Whether load-use hazards require stalls
    """

    stages: int = 2
    forwarding_enabled: bool = True
    branch_delay_slots: int = 0
    load_use_hazard: bool = False


@dataclass
class InstructionInfo:
    """
    Information about an instruction for hazard analysis.

    Attributes:
        mnemonic: Instruction mnemonic
        rd: Destination register (None if no destination)
        rs1: Source register 1 (None if not used)
        rs2: Source register 2 (None if not used)
        is_branch: True if this is a branch/jump instruction
        is_load: True if this is a load instruction
    """

    mnemonic: str
    rd: Optional[int] = None
    rs1: Optional[int] = None
    rs2: Optional[int] = None
    is_branch: bool = False
    is_load: bool = False


class NopInserter:
    """
    Analyzes instruction sequences for hazards and inserts NOPs as needed.

    This class is designed to be configurable for different pipeline depths
    and hazard characteristics.
    """

    def __init__(self, config: PipelineConfig = None):
        """
        Initialize the NOP inserter with a pipeline configuration.

        Args:
            config: Pipeline configuration. Uses defaults if None.
        """
        self.config = config or PipelineConfig()

    def analyze_hazards(
        self, instructions: List[InstructionInfo]
    ) -> List[Tuple[int, int]]:
        """
        Analyze instruction sequence for data hazards.

        Args:
            instructions: List of InstructionInfo objects

        Returns:
            List of (index, nop_count) tuples indicating where to insert NOPs
        """
        hazards = []

        if not self.config.forwarding_enabled:
            # Without forwarding, need to check RAW hazards more carefully
            for i in range(1, len(instructions)):
                prev = instructions[i - 1]
                curr = instructions[i]

                # Check if current instruction reads a register that
                # the previous instruction writes
                if prev.rd is not None and prev.rd != 0:
                    needs_nop = False
                    if curr.rs1 == prev.rd or curr.rs2 == prev.rd:
                        needs_nop = True
                    if needs_nop:
                        # Number of NOPs depends on pipeline depth
                        nops_needed = self.config.stages - 1
                        hazards.append((i, nops_needed))

        # Check for branch hazards in 2-stage pipeline
        # The current RISC-Vibe processor needs NOPs before branches
        # that use recently-written registers
        if self.config.stages == 2:
            for i in range(len(instructions)):
                curr = instructions[i]
                if curr.is_branch:
                    # Check previous 2 instructions for RAW hazards
                    for j in range(max(0, i - 2), i):
                        prev = instructions[j]
                        if prev.rd is not None and prev.rd != 0:
                            if curr.rs1 == prev.rd or curr.rs2 == prev.rd:
                                # Need NOPs between writer and branch
                                nops_needed = 2 - (i - j - 1)
                                if nops_needed > 0:
                                    hazards.append((i, nops_needed))
                                    break

        return hazards

    def insert_nops(
        self, instructions: List[InstructionInfo]
    ) -> List[InstructionInfo]:
        """
        Insert NOPs into instruction sequence to handle hazards.

        Args:
            instructions: Original instruction sequence

        Returns:
            New instruction sequence with NOPs inserted
        """
        hazards = self.analyze_hazards(instructions)

        if not hazards:
            return instructions

        # Sort hazards by index in reverse order so we can insert without
        # invalidating subsequent indices
        hazards.sort(key=lambda x: x[0], reverse=True)

        result = list(instructions)
        for index, nop_count in hazards:
            nops = [
                InstructionInfo(mnemonic="nop", rd=0, rs1=0, rs2=0)
                for _ in range(nop_count)
            ]
            result = result[:index] + nops + result[index:]

        return result


def create_default_inserter() -> NopInserter:
    """
    Create a NOP inserter with the default RISC-Vibe configuration.

    Returns:
        NopInserter configured for the 2-stage pipeline
    """
    config = PipelineConfig(
        stages=2,
        forwarding_enabled=True,
        branch_delay_slots=0,
        load_use_hazard=False,
    )
    return NopInserter(config)
