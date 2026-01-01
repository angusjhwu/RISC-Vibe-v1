"""
Pseudo-instruction expansion.

Expands RISC-V pseudo-instructions into their equivalent real instructions.
"""

from typing import List, Tuple, Optional, Callable
from .parser import parse_immediate
from .errors import ParseError


# Type alias for expanded instruction
# (mnemonic, operands_list)
ExpandedInstruction = Tuple[str, List[str]]


def expand_li(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand LI (load immediate) pseudo-instruction.

    li rd, imm ->
        If imm fits in 12 bits signed: addi rd, x0, imm
        Otherwise: lui rd, upper20 ; addi rd, rd, lower12
    """
    if len(operands) != 2:
        raise ParseError(f"LI requires 2 operands, got {len(operands)}")

    rd = operands[0]
    imm = parse_immediate(operands[1])

    # Check if immediate fits in 12-bit signed range
    if -2048 <= imm <= 2047:
        return [("addi", [rd, "x0", str(imm)])]

    # Need LUI + ADDI
    # Upper 20 bits
    upper = (imm + 0x800) >> 12  # Add 0x800 to handle sign extension of lower
    # Lower 12 bits (sign extended)
    lower = imm - (upper << 12)

    # Handle the case where upper might overflow 20 bits
    upper = upper & 0xFFFFF

    result = [("lui", [rd, str(upper)])]
    if lower != 0:
        result.append(("addi", [rd, rd, str(lower)]))

    return result


def expand_mv(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand MV (move) pseudo-instruction.

    mv rd, rs -> addi rd, rs, 0
    """
    if len(operands) != 2:
        raise ParseError(f"MV requires 2 operands, got {len(operands)}")

    rd, rs = operands
    return [("addi", [rd, rs, "0"])]


def expand_not(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand NOT pseudo-instruction.

    not rd, rs -> xori rd, rs, -1
    """
    if len(operands) != 2:
        raise ParseError(f"NOT requires 2 operands, got {len(operands)}")

    rd, rs = operands
    return [("xori", [rd, rs, "-1"])]


def expand_neg(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand NEG (negate) pseudo-instruction.

    neg rd, rs -> sub rd, x0, rs
    """
    if len(operands) != 2:
        raise ParseError(f"NEG requires 2 operands, got {len(operands)}")

    rd, rs = operands
    return [("sub", [rd, "x0", rs])]


def expand_nop(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand NOP pseudo-instruction.

    nop -> addi x0, x0, 0
    """
    if len(operands) != 0:
        raise ParseError(f"NOP takes no operands, got {len(operands)}")

    return [("addi", ["x0", "x0", "0"])]


def expand_j(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand J (jump) pseudo-instruction.

    j offset -> jal x0, offset
    """
    if len(operands) != 1:
        raise ParseError(f"J requires 1 operand, got {len(operands)}")

    return [("jal", ["x0", operands[0]])]


def expand_jr(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand JR (jump register) pseudo-instruction.

    jr rs -> jalr x0, rs, 0
    """
    if len(operands) != 1:
        raise ParseError(f"JR requires 1 operand, got {len(operands)}")

    return [("jalr", ["x0", operands[0], "0"])]


def expand_ret(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand RET (return) pseudo-instruction.

    ret -> jalr x0, ra, 0
    """
    if len(operands) != 0:
        raise ParseError(f"RET takes no operands, got {len(operands)}")

    return [("jalr", ["x0", "ra", "0"])]


def expand_call(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand CALL pseudo-instruction.

    call offset -> jal ra, offset
    """
    if len(operands) != 1:
        raise ParseError(f"CALL requires 1 operand, got {len(operands)}")

    return [("jal", ["ra", operands[0]])]


def expand_beqz(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand BEQZ (branch if equal to zero) pseudo-instruction.

    beqz rs, offset -> beq rs, x0, offset
    """
    if len(operands) != 2:
        raise ParseError(f"BEQZ requires 2 operands, got {len(operands)}")

    rs, offset = operands
    return [("beq", [rs, "x0", offset])]


def expand_bnez(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand BNEZ (branch if not equal to zero) pseudo-instruction.

    bnez rs, offset -> bne rs, x0, offset
    """
    if len(operands) != 2:
        raise ParseError(f"BNEZ requires 2 operands, got {len(operands)}")

    rs, offset = operands
    return [("bne", [rs, "x0", offset])]


def expand_blez(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand BLEZ (branch if less than or equal to zero) pseudo-instruction.

    blez rs, offset -> bge x0, rs, offset
    """
    if len(operands) != 2:
        raise ParseError(f"BLEZ requires 2 operands, got {len(operands)}")

    rs, offset = operands
    return [("bge", ["x0", rs, offset])]


def expand_bgez(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand BGEZ (branch if greater than or equal to zero) pseudo-instruction.

    bgez rs, offset -> bge rs, x0, offset
    """
    if len(operands) != 2:
        raise ParseError(f"BGEZ requires 2 operands, got {len(operands)}")

    rs, offset = operands
    return [("bge", [rs, "x0", offset])]


def expand_bltz(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand BLTZ (branch if less than zero) pseudo-instruction.

    bltz rs, offset -> blt rs, x0, offset
    """
    if len(operands) != 2:
        raise ParseError(f"BLTZ requires 2 operands, got {len(operands)}")

    rs, offset = operands
    return [("blt", [rs, "x0", offset])]


def expand_bgtz(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand BGTZ (branch if greater than zero) pseudo-instruction.

    bgtz rs, offset -> blt x0, rs, offset
    """
    if len(operands) != 2:
        raise ParseError(f"BGTZ requires 2 operands, got {len(operands)}")

    rs, offset = operands
    return [("blt", ["x0", rs, offset])]


def expand_seqz(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand SEQZ (set if equal to zero) pseudo-instruction.

    seqz rd, rs -> sltiu rd, rs, 1
    """
    if len(operands) != 2:
        raise ParseError(f"SEQZ requires 2 operands, got {len(operands)}")

    rd, rs = operands
    return [("sltiu", [rd, rs, "1"])]


def expand_snez(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand SNEZ (set if not equal to zero) pseudo-instruction.

    snez rd, rs -> sltu rd, x0, rs
    """
    if len(operands) != 2:
        raise ParseError(f"SNEZ requires 2 operands, got {len(operands)}")

    rd, rs = operands
    return [("sltu", [rd, "x0", rs])]


def expand_sltz(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand SLTZ (set if less than zero) pseudo-instruction.

    sltz rd, rs -> slt rd, rs, x0
    """
    if len(operands) != 2:
        raise ParseError(f"SLTZ requires 2 operands, got {len(operands)}")

    rd, rs = operands
    return [("slt", [rd, rs, "x0"])]


def expand_sgtz(operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand SGTZ (set if greater than zero) pseudo-instruction.

    sgtz rd, rs -> slt rd, x0, rs
    """
    if len(operands) != 2:
        raise ParseError(f"SGTZ requires 2 operands, got {len(operands)}")

    rd, rs = operands
    return [("slt", [rd, "x0", rs])]


# Map of pseudo-instruction names to their expansion functions
PSEUDO_INSTRUCTIONS: dict[str, Callable[[List[str]], List[ExpandedInstruction]]] = {
    "li": expand_li,
    "mv": expand_mv,
    "not": expand_not,
    "neg": expand_neg,
    "nop": expand_nop,
    "j": expand_j,
    "jr": expand_jr,
    "ret": expand_ret,
    "call": expand_call,
    "beqz": expand_beqz,
    "bnez": expand_bnez,
    "blez": expand_blez,
    "bgez": expand_bgez,
    "bltz": expand_bltz,
    "bgtz": expand_bgtz,
    "seqz": expand_seqz,
    "snez": expand_snez,
    "sltz": expand_sltz,
    "sgtz": expand_sgtz,
}


def is_pseudo_instruction(mnemonic: str) -> bool:
    """Check if a mnemonic is a pseudo-instruction."""
    return mnemonic.lower() in PSEUDO_INSTRUCTIONS


def expand_pseudo(mnemonic: str, operands: List[str]) -> List[ExpandedInstruction]:
    """
    Expand a pseudo-instruction into real instructions.

    Args:
        mnemonic: Pseudo-instruction mnemonic
        operands: List of operand strings

    Returns:
        List of (mnemonic, operands) tuples for real instructions

    Raises:
        ParseError: If the pseudo-instruction is invalid
    """
    mnemonic_lower = mnemonic.lower()
    if mnemonic_lower not in PSEUDO_INSTRUCTIONS:
        raise ParseError(f"Unknown pseudo-instruction: {mnemonic}")

    return PSEUDO_INSTRUCTIONS[mnemonic_lower](operands)


def get_pseudo_instruction_count(mnemonic: str, operands: List[str]) -> int:
    """
    Get the number of real instructions a pseudo-instruction expands to.

    This is needed for address calculation in the first pass.
    """
    mnemonic_lower = mnemonic.lower()
    if mnemonic_lower not in PSEUDO_INSTRUCTIONS:
        return 1  # Not a pseudo, counts as 1 instruction

    # Special handling for LI which can expand to 1 or 2 instructions
    if mnemonic_lower == "li":
        if len(operands) >= 2:
            try:
                imm = parse_immediate(operands[1])
                if -2048 <= imm <= 2047:
                    return 1
                return 2
            except Exception:
                return 2  # Assume worst case
        return 2  # Assume worst case

    # All other pseudo-instructions expand to exactly 1 instruction
    return 1
