"""
RISC-V instruction encoder.

Encodes parsed instructions into 32-bit machine code based on their format type.
Handles the bit-shuffling required for B-type and J-type immediate encoding.
"""

from .instructions import Instruction, InstructionFormat, SYSTEM_IMM
from .errors import EncodingError


def sign_extend(value: int, bits: int) -> int:
    """Sign-extend a value to the specified number of bits."""
    sign_bit = 1 << (bits - 1)
    return (value & (sign_bit - 1)) - (value & sign_bit)


def check_immediate_range(value: int, bits: int, signed: bool = True, name: str = "immediate") -> None:
    """
    Check if an immediate value fits in the specified bit width.

    Args:
        value: The immediate value to check
        bits: Number of bits available
        signed: Whether the immediate is signed
        name: Name for error messages
    """
    if signed:
        min_val = -(1 << (bits - 1))
        max_val = (1 << (bits - 1)) - 1
    else:
        min_val = 0
        max_val = (1 << bits) - 1

    if not (min_val <= value <= max_val):
        raise EncodingError(
            f"{name} value {value} out of range [{min_val}, {max_val}] for {bits}-bit field"
        )


def encode_r_type(instr: Instruction, rd: int, rs1: int, rs2: int) -> int:
    """
    Encode an R-type instruction.

    Format: [funct7(7) | rs2(5) | rs1(5) | funct3(3) | rd(5) | opcode(7)]
    """
    encoding = instr.opcode & 0x7F
    encoding |= (rd & 0x1F) << 7
    encoding |= (instr.funct3 & 0x7) << 12
    encoding |= (rs1 & 0x1F) << 15
    encoding |= (rs2 & 0x1F) << 20
    encoding |= (instr.funct7 & 0x7F) << 25
    return encoding


def encode_i_type(instr: Instruction, rd: int, rs1: int, imm: int, mnemonic: str = None) -> int:
    """
    Encode an I-type instruction.

    Format: [imm[11:0](12) | rs1(5) | funct3(3) | rd(5) | opcode(7)]

    For shift instructions (SLLI, SRLI, SRAI), funct7 is embedded in upper bits of imm.
    """
    # Handle system instructions (ecall, ebreak)
    if mnemonic and mnemonic.lower() in SYSTEM_IMM:
        imm = SYSTEM_IMM[mnemonic.lower()]
        # For ecall/ebreak, rs1 and rd are both 0
        rs1 = 0
        rd = 0

    # Handle shift immediate instructions
    if instr.funct7 is not None and mnemonic and mnemonic.lower() in ("slli", "srli", "srai"):
        # For shift instructions, imm is the shift amount (0-31)
        check_immediate_range(imm, 5, signed=False, name="shift amount")
        # Embed funct7 in upper 7 bits of the 12-bit immediate field
        imm = (instr.funct7 << 5) | (imm & 0x1F)
    else:
        # Regular I-type immediate
        check_immediate_range(imm, 12, signed=True, name="I-type immediate")
        imm = imm & 0xFFF  # Mask to 12 bits

    encoding = instr.opcode & 0x7F
    encoding |= (rd & 0x1F) << 7
    encoding |= (instr.funct3 & 0x7) << 12
    encoding |= (rs1 & 0x1F) << 15
    encoding |= (imm & 0xFFF) << 20
    return encoding


def encode_s_type(instr: Instruction, rs1: int, rs2: int, imm: int) -> int:
    """
    Encode an S-type instruction.

    Format: [imm[11:5](7) | rs2(5) | rs1(5) | funct3(3) | imm[4:0](5) | opcode(7)]
    """
    check_immediate_range(imm, 12, signed=True, name="S-type immediate")
    imm = imm & 0xFFF  # Mask to 12 bits

    encoding = instr.opcode & 0x7F
    encoding |= (imm & 0x1F) << 7  # imm[4:0]
    encoding |= (instr.funct3 & 0x7) << 12
    encoding |= (rs1 & 0x1F) << 15
    encoding |= (rs2 & 0x1F) << 20
    encoding |= ((imm >> 5) & 0x7F) << 25  # imm[11:5]
    return encoding


def encode_b_type(instr: Instruction, rs1: int, rs2: int, imm: int) -> int:
    """
    Encode a B-type instruction.

    Format: [imm[12](1) | imm[10:5](6) | rs2(5) | rs1(5) | funct3(3) | imm[4:1](4) | imm[11](1) | opcode(7)]

    The immediate is a 13-bit signed value with the LSB always 0 (2-byte aligned).
    We receive the byte offset and encode it.
    """
    # B-type immediate must be even (2-byte aligned)
    if imm & 1:
        raise EncodingError(f"B-type branch offset must be even, got {imm}")

    # Range: -4096 to +4094 (13-bit signed with LSB=0)
    check_immediate_range(imm, 13, signed=True, name="B-type offset")

    # The immediate encoding uses bits [12:1], bit 0 is always 0
    imm = imm & 0x1FFE  # Mask to 13 bits, clear bit 0

    encoding = instr.opcode & 0x7F
    encoding |= ((imm >> 11) & 0x1) << 7  # imm[11]
    encoding |= ((imm >> 1) & 0xF) << 8  # imm[4:1]
    encoding |= (instr.funct3 & 0x7) << 12
    encoding |= (rs1 & 0x1F) << 15
    encoding |= (rs2 & 0x1F) << 20
    encoding |= ((imm >> 5) & 0x3F) << 25  # imm[10:5]
    encoding |= ((imm >> 12) & 0x1) << 31  # imm[12]
    return encoding


def encode_u_type(instr: Instruction, rd: int, imm: int) -> int:
    """
    Encode a U-type instruction.

    Format: [imm[31:12](20) | rd(5) | opcode(7)]

    The immediate is the upper 20 bits (already shifted or raw depending on syntax).
    """
    # U-type immediate can be any 20-bit value (after shifting by 12)
    # Check if imm is in valid 20-bit range
    if imm < 0:
        # Handle negative values - treat as 20-bit signed
        check_immediate_range(imm, 20, signed=True, name="U-type immediate")
        imm = imm & 0xFFFFF
    else:
        check_immediate_range(imm, 20, signed=False, name="U-type immediate")

    encoding = instr.opcode & 0x7F
    encoding |= (rd & 0x1F) << 7
    encoding |= (imm & 0xFFFFF) << 12
    return encoding


def encode_j_type(instr: Instruction, rd: int, imm: int) -> int:
    """
    Encode a J-type instruction.

    Format: [imm[20](1) | imm[10:1](10) | imm[11](1) | imm[19:12](8) | rd(5) | opcode(7)]

    The immediate is a 21-bit signed value with the LSB always 0 (2-byte aligned).
    """
    # J-type immediate must be even (2-byte aligned)
    if imm & 1:
        raise EncodingError(f"J-type jump offset must be even, got {imm}")

    # Range: -1048576 to +1048574 (21-bit signed with LSB=0)
    check_immediate_range(imm, 21, signed=True, name="J-type offset")

    # Handle sign extension for negative values
    if imm < 0:
        imm = imm & 0x1FFFFF  # Mask to 21 bits

    encoding = instr.opcode & 0x7F
    encoding |= (rd & 0x1F) << 7
    encoding |= ((imm >> 12) & 0xFF) << 12  # imm[19:12]
    encoding |= ((imm >> 11) & 0x1) << 20  # imm[11]
    encoding |= ((imm >> 1) & 0x3FF) << 21  # imm[10:1]
    encoding |= ((imm >> 20) & 0x1) << 31  # imm[20]
    return encoding


def encode_instruction(
    instr: Instruction,
    mnemonic: str,
    rd: int = 0,
    rs1: int = 0,
    rs2: int = 0,
    imm: int = 0,
) -> int:
    """
    Encode an instruction based on its format.

    Args:
        instr: Instruction definition
        mnemonic: Instruction mnemonic (for special handling)
        rd: Destination register (0-31)
        rs1: Source register 1 (0-31)
        rs2: Source register 2 (0-31)
        imm: Immediate value

    Returns:
        32-bit encoded instruction
    """
    fmt = instr.format

    if fmt == InstructionFormat.R:
        return encode_r_type(instr, rd, rs1, rs2)
    elif fmt == InstructionFormat.I:
        return encode_i_type(instr, rd, rs1, imm, mnemonic)
    elif fmt == InstructionFormat.S:
        return encode_s_type(instr, rs1, rs2, imm)
    elif fmt == InstructionFormat.B:
        return encode_b_type(instr, rs1, rs2, imm)
    elif fmt == InstructionFormat.U:
        return encode_u_type(instr, rd, imm)
    elif fmt == InstructionFormat.J:
        return encode_j_type(instr, rd, imm)
    else:
        raise EncodingError(f"Unknown instruction format: {fmt}")
