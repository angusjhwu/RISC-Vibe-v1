"""
Assembly source file parser.

Handles tokenization, comment stripping, label extraction, and instruction parsing.
Supports standard RISC-V assembly syntax including directives.
"""

import re
from typing import List, Tuple, Optional, Dict, Any
from dataclasses import dataclass
from .errors import ParseError
from .registers import parse_register, is_valid_register
from .instructions import is_valid_instruction


@dataclass
class ParsedLine:
    """
    Represents a parsed line of assembly.

    Attributes:
        line_num: Original line number in source file
        label: Label defined on this line (if any)
        mnemonic: Instruction mnemonic (if any)
        operands: List of operand strings
        original: Original line text
        is_directive: True if this is a directive (e.g., .text, .globl)
    """

    line_num: int
    label: Optional[str] = None
    mnemonic: Optional[str] = None
    operands: List[str] = None
    original: str = ""
    is_directive: bool = False

    def __post_init__(self):
        if self.operands is None:
            self.operands = []


def strip_comments(line: str) -> str:
    """
    Remove comments from a line.

    Supports # and // style comments.
    """
    # Find comment start (outside of strings)
    # Simple approach: just find # or // and take everything before
    hash_pos = line.find("#")
    double_slash = line.find("//")

    comment_pos = -1
    if hash_pos >= 0 and double_slash >= 0:
        comment_pos = min(hash_pos, double_slash)
    elif hash_pos >= 0:
        comment_pos = hash_pos
    elif double_slash >= 0:
        comment_pos = double_slash

    if comment_pos >= 0:
        return line[:comment_pos]
    return line


def parse_immediate(value_str: str) -> int:
    """
    Parse an immediate value from string.

    Supports:
    - Decimal: 123, -45
    - Hexadecimal: 0x1A, 0X1a
    - Binary: 0b1010
    - Octal: 0o17

    Returns:
        Integer value
    """
    value_str = value_str.strip()

    if not value_str:
        raise ParseError(f"Empty immediate value")

    # Check for negative
    negative = value_str.startswith("-")
    if negative:
        value_str = value_str[1:].strip()

    try:
        if value_str.lower().startswith("0x"):
            result = int(value_str, 16)
        elif value_str.lower().startswith("0b"):
            result = int(value_str, 2)
        elif value_str.lower().startswith("0o"):
            result = int(value_str, 8)
        else:
            result = int(value_str, 10)

        return -result if negative else result
    except ValueError:
        raise ParseError(f"Invalid immediate value: {value_str}")


def parse_memory_operand(operand: str) -> Tuple[int, str]:
    """
    Parse a memory operand in the form offset(register).

    Examples:
    - "0(sp)" -> (0, "sp")
    - "-48(s0)" -> (-48, "s0")
    - "44(sp)" -> (44, "sp")

    Returns:
        Tuple of (offset, register_name)
    """
    # Match pattern: optional_offset(register)
    match = re.match(r"^\s*(-?\w*)\s*\(\s*(\w+)\s*\)\s*$", operand)
    if not match:
        raise ParseError(f"Invalid memory operand syntax: {operand}")

    offset_str = match.group(1).strip()
    reg_str = match.group(2).strip()

    # Parse offset (default to 0 if empty)
    if offset_str == "" or offset_str == "-":
        offset = 0
    else:
        offset = parse_immediate(offset_str)

    # Validate register
    if not is_valid_register(reg_str):
        raise ParseError(f"Invalid register in memory operand: {reg_str}")

    return offset, reg_str


def tokenize_operands(operand_str: str) -> List[str]:
    """
    Split operand string into individual operands.

    Handles commas as separators and parentheses for memory operands.
    """
    operands = []
    current = ""
    paren_depth = 0

    for char in operand_str:
        if char == "(":
            paren_depth += 1
            current += char
        elif char == ")":
            paren_depth -= 1
            current += char
        elif char == "," and paren_depth == 0:
            if current.strip():
                operands.append(current.strip())
            current = ""
        else:
            current += char

    if current.strip():
        operands.append(current.strip())

    return operands


def parse_line(line: str, line_num: int) -> ParsedLine:
    """
    Parse a single line of assembly.

    Returns:
        ParsedLine object containing parsed components
    """
    original = line
    result = ParsedLine(line_num=line_num, original=original)

    # Strip comments
    line = strip_comments(line).strip()

    # Empty line after comment removal
    if not line:
        return result

    # Check for label (ends with :)
    # Labels can start with a letter, underscore, or dot (for local labels)
    label_match = re.match(r"^(\.?\w+)\s*:\s*(.*)$", line)
    if label_match:
        result.label = label_match.group(1)
        line = label_match.group(2).strip()

    # Check if line is empty after label extraction
    if not line:
        return result

    # Check for directive
    if line.startswith("."):
        parts = line.split(None, 1)
        result.mnemonic = parts[0].lower()
        result.is_directive = True
        if len(parts) > 1:
            result.operands = [p.strip() for p in parts[1].split(",")]
        return result

    # Parse instruction
    parts = line.split(None, 1)
    if parts:
        result.mnemonic = parts[0].lower()
        if len(parts) > 1:
            result.operands = tokenize_operands(parts[1])

    return result


class Parser:
    """
    Assembly file parser.

    Provides methods to parse entire files and extract structured information.
    """

    def __init__(self):
        self.lines: List[ParsedLine] = []
        self.labels: Dict[str, int] = {}  # label -> line index
        self.errors: List[str] = []

    def parse_file(self, filepath: str) -> List[ParsedLine]:
        """
        Parse an assembly file.

        Args:
            filepath: Path to the assembly file

        Returns:
            List of ParsedLine objects
        """
        with open(filepath, "r") as f:
            content = f.read()
        return self.parse_string(content)

    def parse_string(self, content: str) -> List[ParsedLine]:
        """
        Parse assembly source from a string.

        Args:
            content: Assembly source code string

        Returns:
            List of ParsedLine objects
        """
        self.lines = []
        self.labels = {}
        self.errors = []

        for i, line in enumerate(content.splitlines(), start=1):
            try:
                parsed = parse_line(line, i)
                self.lines.append(parsed)

                # Track labels
                if parsed.label:
                    if parsed.label in self.labels:
                        self.errors.append(
                            f"Line {i}: Duplicate label '{parsed.label}'"
                        )
                    else:
                        self.labels[parsed.label] = len(self.lines) - 1

            except ParseError as e:
                e.line_num = i
                e.line_text = line
                raise

        return self.lines

    def get_instructions(self) -> List[ParsedLine]:
        """
        Get only instruction lines (excluding directives and empty lines).
        """
        return [
            line
            for line in self.lines
            if line.mnemonic and not line.is_directive
        ]

    def get_label_address(self, label: str) -> Optional[int]:
        """
        Get the line index for a label.
        """
        return self.labels.get(label)
