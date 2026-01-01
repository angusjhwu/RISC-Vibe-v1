"""
RISC-V instruction definitions.

This module defines all supported instructions with their opcodes, funct3, funct7,
and format types. Designed to be easily extensible for new instructions or ISA
extensions (M, A, F, D, etc.).
"""

from dataclasses import dataclass
from typing import Optional
from enum import Enum, auto


class InstructionFormat(Enum):
    """RISC-V instruction format types."""

    R = auto()  # Register-register operations
    I = auto()  # Immediate operations
    S = auto()  # Store operations
    B = auto()  # Branch operations
    U = auto()  # Upper immediate operations
    J = auto()  # Jump operations


@dataclass
class Instruction:
    """
    Definition of a RISC-V instruction.

    Attributes:
        opcode: 7-bit opcode field
        format: Instruction format type
        funct3: 3-bit function field (None if not applicable)
        funct7: 7-bit function field (None if not applicable)
    """

    opcode: int
    format: InstructionFormat
    funct3: Optional[int] = None
    funct7: Optional[int] = None


# =============================================================================
# RV32I Base Integer Instruction Set
# =============================================================================

INSTRUCTIONS = {
    # -------------------------------------------------------------------------
    # R-Type Instructions (Register-Register) - Opcode: 0x33
    # -------------------------------------------------------------------------
    "add": Instruction(opcode=0x33, format=InstructionFormat.R, funct3=0b000, funct7=0x00),
    "sub": Instruction(opcode=0x33, format=InstructionFormat.R, funct3=0b000, funct7=0x20),
    "sll": Instruction(opcode=0x33, format=InstructionFormat.R, funct3=0b001, funct7=0x00),
    "slt": Instruction(opcode=0x33, format=InstructionFormat.R, funct3=0b010, funct7=0x00),
    "sltu": Instruction(opcode=0x33, format=InstructionFormat.R, funct3=0b011, funct7=0x00),
    "xor": Instruction(opcode=0x33, format=InstructionFormat.R, funct3=0b100, funct7=0x00),
    "srl": Instruction(opcode=0x33, format=InstructionFormat.R, funct3=0b101, funct7=0x00),
    "sra": Instruction(opcode=0x33, format=InstructionFormat.R, funct3=0b101, funct7=0x20),
    "or": Instruction(opcode=0x33, format=InstructionFormat.R, funct3=0b110, funct7=0x00),
    "and": Instruction(opcode=0x33, format=InstructionFormat.R, funct3=0b111, funct7=0x00),
    # -------------------------------------------------------------------------
    # I-Type Instructions (Immediate) - Opcode: 0x13
    # -------------------------------------------------------------------------
    "addi": Instruction(opcode=0x13, format=InstructionFormat.I, funct3=0b000),
    "slti": Instruction(opcode=0x13, format=InstructionFormat.I, funct3=0b010),
    "sltiu": Instruction(opcode=0x13, format=InstructionFormat.I, funct3=0b011),
    "xori": Instruction(opcode=0x13, format=InstructionFormat.I, funct3=0b100),
    "ori": Instruction(opcode=0x13, format=InstructionFormat.I, funct3=0b110),
    "andi": Instruction(opcode=0x13, format=InstructionFormat.I, funct3=0b111),
    # Shift immediate instructions (I-type with shamt, funct7 embedded in imm)
    "slli": Instruction(opcode=0x13, format=InstructionFormat.I, funct3=0b001, funct7=0x00),
    "srli": Instruction(opcode=0x13, format=InstructionFormat.I, funct3=0b101, funct7=0x00),
    "srai": Instruction(opcode=0x13, format=InstructionFormat.I, funct3=0b101, funct7=0x20),
    # -------------------------------------------------------------------------
    # Load Instructions (I-Type) - Opcode: 0x03
    # -------------------------------------------------------------------------
    "lb": Instruction(opcode=0x03, format=InstructionFormat.I, funct3=0b000),
    "lh": Instruction(opcode=0x03, format=InstructionFormat.I, funct3=0b001),
    "lw": Instruction(opcode=0x03, format=InstructionFormat.I, funct3=0b010),
    "lbu": Instruction(opcode=0x03, format=InstructionFormat.I, funct3=0b100),
    "lhu": Instruction(opcode=0x03, format=InstructionFormat.I, funct3=0b101),
    # -------------------------------------------------------------------------
    # Store Instructions (S-Type) - Opcode: 0x23
    # -------------------------------------------------------------------------
    "sb": Instruction(opcode=0x23, format=InstructionFormat.S, funct3=0b000),
    "sh": Instruction(opcode=0x23, format=InstructionFormat.S, funct3=0b001),
    "sw": Instruction(opcode=0x23, format=InstructionFormat.S, funct3=0b010),
    # -------------------------------------------------------------------------
    # Branch Instructions (B-Type) - Opcode: 0x63
    # -------------------------------------------------------------------------
    "beq": Instruction(opcode=0x63, format=InstructionFormat.B, funct3=0b000),
    "bne": Instruction(opcode=0x63, format=InstructionFormat.B, funct3=0b001),
    "blt": Instruction(opcode=0x63, format=InstructionFormat.B, funct3=0b100),
    "bge": Instruction(opcode=0x63, format=InstructionFormat.B, funct3=0b101),
    "bltu": Instruction(opcode=0x63, format=InstructionFormat.B, funct3=0b110),
    "bgeu": Instruction(opcode=0x63, format=InstructionFormat.B, funct3=0b111),
    # -------------------------------------------------------------------------
    # Jump Instructions
    # -------------------------------------------------------------------------
    "jal": Instruction(opcode=0x6F, format=InstructionFormat.J),  # J-type
    "jalr": Instruction(opcode=0x67, format=InstructionFormat.I, funct3=0b000),  # I-type
    # -------------------------------------------------------------------------
    # Upper Immediate Instructions (U-Type)
    # -------------------------------------------------------------------------
    "lui": Instruction(opcode=0x37, format=InstructionFormat.U),
    "auipc": Instruction(opcode=0x17, format=InstructionFormat.U),
    # -------------------------------------------------------------------------
    # System Instructions - Opcode: 0x73
    # These are encoded as I-type with specific immediate values
    # -------------------------------------------------------------------------
    "ecall": Instruction(opcode=0x73, format=InstructionFormat.I, funct3=0b000),
    "ebreak": Instruction(opcode=0x73, format=InstructionFormat.I, funct3=0b000),
    # -------------------------------------------------------------------------
    # Fence Instruction - Opcode: 0x0F
    # -------------------------------------------------------------------------
    "fence": Instruction(opcode=0x0F, format=InstructionFormat.I, funct3=0b000),
}

# Special immediate values for system instructions
SYSTEM_IMM = {
    "ecall": 0x000,
    "ebreak": 0x001,
}


def get_instruction(mnemonic: str) -> Optional[Instruction]:
    """
    Look up an instruction by mnemonic.

    Args:
        mnemonic: Instruction mnemonic (case-insensitive)

    Returns:
        Instruction object if found, None otherwise
    """
    return INSTRUCTIONS.get(mnemonic.lower())


def is_valid_instruction(mnemonic: str) -> bool:
    """Check if a mnemonic is a valid instruction."""
    return mnemonic.lower() in INSTRUCTIONS


def get_all_mnemonics() -> list:
    """Get a list of all supported instruction mnemonics."""
    return list(INSTRUCTIONS.keys())
