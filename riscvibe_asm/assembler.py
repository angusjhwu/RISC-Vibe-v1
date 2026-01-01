"""
Main assembler implementation.

Two-pass assembler for RISC-V RV32I assembly to hex output.
"""

from typing import List, Dict, Optional, Tuple
from pathlib import Path
import sys

from .parser import Parser, ParsedLine, parse_immediate, parse_memory_operand
from .registers import parse_register
from .instructions import get_instruction, is_valid_instruction, InstructionFormat
from .pseudo import is_pseudo_instruction, expand_pseudo, get_pseudo_instruction_count
from .encoder import encode_instruction
from .errors import AssemblerError, ParseError, EncodingError, SymbolError


class Assembler:
    """
    Two-pass RISC-V assembler.

    Pass 1: Collect labels and compute addresses
    Pass 2: Encode instructions with resolved labels
    """

    def __init__(self, verbose: bool = False):
        """
        Initialize the assembler.

        Args:
            verbose: If True, print detailed assembly information
        """
        self.verbose = verbose
        self.parser = Parser()
        self.symbols: Dict[str, int] = {}  # label -> byte address
        self.instructions: List[int] = []  # encoded 32-bit instructions
        self.current_address: int = 0
        self.source_map: List[Tuple[int, str, int]] = []  # (addr, original_line, line_num)

    def log(self, message: str) -> None:
        """Print message if verbose mode is enabled."""
        if self.verbose:
            print(message)

    def assemble_file(self, input_path: str, output_path: str = None) -> List[int]:
        """
        Assemble an assembly file to hex output.

        Args:
            input_path: Path to input .S file
            output_path: Path to output .hex file (optional)

        Returns:
            List of 32-bit encoded instructions
        """
        # Read and parse the file
        self.log(f"Assembling: {input_path}")
        lines = self.parser.parse_file(input_path)

        # Run two-pass assembly
        self._pass1(lines)
        self._pass2(lines)

        # Write output if path provided
        if output_path:
            self.write_hex(output_path)
            self.log(f"Output written to: {output_path}")

        return self.instructions

    def assemble_string(self, source: str) -> List[int]:
        """
        Assemble from a string.

        Args:
            source: Assembly source code

        Returns:
            List of 32-bit encoded instructions
        """
        lines = self.parser.parse_string(source)
        self._pass1(lines)
        self._pass2(lines)
        return self.instructions

    def _pass1(self, lines: List[ParsedLine]) -> None:
        """
        First pass: Collect labels and compute addresses.
        """
        self.log("\n=== Pass 1: Collecting labels ===")
        self.symbols = {}
        self.current_address = 0

        for line in lines:
            # Record label at current address
            if line.label:
                if line.label in self.symbols:
                    raise SymbolError(
                        f"Duplicate label: {line.label}",
                        line.line_num,
                        line.original,
                    )
                self.symbols[line.label] = self.current_address
                self.log(f"  Label '{line.label}' at 0x{self.current_address:04X}")

            # Skip directives and empty lines for address calculation
            if not line.mnemonic or line.is_directive:
                continue

            # Calculate instruction count (pseudo-instructions may expand)
            mnemonic = line.mnemonic.lower()
            if is_pseudo_instruction(mnemonic):
                instr_count = get_pseudo_instruction_count(mnemonic, line.operands)
            else:
                instr_count = 1

            # Advance address (each instruction is 4 bytes)
            self.current_address += instr_count * 4

        self.log(f"  Total symbols: {len(self.symbols)}")
        self.log(f"  Program size: {self.current_address} bytes")

    def _pass2(self, lines: List[ParsedLine]) -> None:
        """
        Second pass: Encode instructions with resolved labels.
        """
        self.log("\n=== Pass 2: Encoding instructions ===")
        self.instructions = []
        self.source_map = []
        self.current_address = 0

        for line in lines:
            # Skip directives and empty lines
            if not line.mnemonic or line.is_directive:
                continue

            mnemonic = line.mnemonic.lower()

            # Handle pseudo-instructions
            if is_pseudo_instruction(mnemonic):
                expanded = expand_pseudo(mnemonic, line.operands)
                for exp_mnemonic, exp_operands in expanded:
                    encoded = self._encode_instruction(
                        exp_mnemonic, exp_operands, line.line_num, line.original
                    )
                    self.instructions.append(encoded)
                    self.source_map.append(
                        (self.current_address, line.original, line.line_num)
                    )
                    self.log(
                        f"  0x{self.current_address:04X}: {encoded:08X}  "
                        f"{exp_mnemonic} {', '.join(exp_operands)}"
                    )
                    self.current_address += 4
            else:
                encoded = self._encode_instruction(
                    mnemonic, line.operands, line.line_num, line.original
                )
                self.instructions.append(encoded)
                self.source_map.append(
                    (self.current_address, line.original, line.line_num)
                )
                self.log(
                    f"  0x{self.current_address:04X}: {encoded:08X}  "
                    f"{mnemonic} {', '.join(line.operands)}"
                )
                self.current_address += 4

        self.log(f"\n  Total instructions: {len(self.instructions)}")

    def _encode_instruction(
        self, mnemonic: str, operands: List[str], line_num: int, line_text: str
    ) -> int:
        """
        Encode a single instruction.

        Args:
            mnemonic: Instruction mnemonic
            operands: List of operand strings
            line_num: Source line number for error reporting
            line_text: Original line text for error reporting

        Returns:
            32-bit encoded instruction
        """
        instr = get_instruction(mnemonic)
        if instr is None:
            raise ParseError(
                f"Unknown instruction: {mnemonic}", line_num, line_text
            )

        try:
            # Parse operands based on instruction format
            rd, rs1, rs2, imm = self._parse_operands(
                instr, mnemonic, operands, line_num, line_text
            )

            # Encode the instruction
            return encode_instruction(instr, mnemonic, rd, rs1, rs2, imm)

        except (ValueError, EncodingError) as e:
            raise EncodingError(str(e), line_num, line_text)

    def _parse_operands(
        self,
        instr,
        mnemonic: str,
        operands: List[str],
        line_num: int,
        line_text: str,
    ) -> Tuple[int, int, int, int]:
        """
        Parse operands for an instruction.

        Returns:
            Tuple of (rd, rs1, rs2, imm)
        """
        rd = rs1 = rs2 = imm = 0
        fmt = instr.format

        # Handle special cases first
        if mnemonic in ("ecall", "ebreak"):
            # No operands needed
            return 0, 0, 0, 0

        if mnemonic == "fence":
            # Fence instruction - encode as NOP for now
            return 0, 0, 0, 0

        if fmt == InstructionFormat.R:
            # R-type: rd, rs1, rs2
            if len(operands) != 3:
                raise ParseError(
                    f"{mnemonic} requires 3 operands (rd, rs1, rs2), got {len(operands)}",
                    line_num,
                    line_text,
                )
            rd = parse_register(operands[0])
            rs1 = parse_register(operands[1])
            rs2 = parse_register(operands[2])

        elif fmt == InstructionFormat.I:
            if mnemonic in ("lb", "lh", "lw", "lbu", "lhu"):
                # Load: rd, offset(rs1)
                if len(operands) != 2:
                    raise ParseError(
                        f"{mnemonic} requires 2 operands (rd, offset(rs1)), got {len(operands)}",
                        line_num,
                        line_text,
                    )
                rd = parse_register(operands[0])
                imm, rs1_name = parse_memory_operand(operands[1])
                rs1 = parse_register(rs1_name)

            elif mnemonic == "jalr":
                # JALR can be: jalr rd, rs1, imm  OR  jalr rd, imm(rs1)
                if len(operands) == 3:
                    rd = parse_register(operands[0])
                    rs1 = parse_register(operands[1])
                    imm = self._resolve_immediate(operands[2], line_num, line_text)
                elif len(operands) == 2:
                    rd = parse_register(operands[0])
                    imm, rs1_name = parse_memory_operand(operands[1])
                    rs1 = parse_register(rs1_name)
                else:
                    raise ParseError(
                        f"jalr requires 2 or 3 operands, got {len(operands)}",
                        line_num,
                        line_text,
                    )

            else:
                # Other I-type: rd, rs1, imm
                if len(operands) != 3:
                    raise ParseError(
                        f"{mnemonic} requires 3 operands (rd, rs1, imm), got {len(operands)}",
                        line_num,
                        line_text,
                    )
                rd = parse_register(operands[0])
                rs1 = parse_register(operands[1])
                imm = self._resolve_immediate(operands[2], line_num, line_text)

        elif fmt == InstructionFormat.S:
            # S-type (store): rs2, offset(rs1)
            if len(operands) != 2:
                raise ParseError(
                    f"{mnemonic} requires 2 operands (rs2, offset(rs1)), got {len(operands)}",
                    line_num,
                    line_text,
                )
            rs2 = parse_register(operands[0])
            imm, rs1_name = parse_memory_operand(operands[1])
            rs1 = parse_register(rs1_name)

        elif fmt == InstructionFormat.B:
            # B-type (branch): rs1, rs2, offset/label
            if len(operands) != 3:
                raise ParseError(
                    f"{mnemonic} requires 3 operands (rs1, rs2, offset), got {len(operands)}",
                    line_num,
                    line_text,
                )
            rs1 = parse_register(operands[0])
            rs2 = parse_register(operands[1])

            # Resolve label or immediate to PC-relative offset
            target = operands[2].strip()
            if target in self.symbols:
                # Label reference - compute relative offset
                target_addr = self.symbols[target]
                imm = target_addr - self.current_address
            else:
                # Direct offset
                imm = self._resolve_immediate(target, line_num, line_text)

        elif fmt == InstructionFormat.U:
            # U-type: rd, imm
            if len(operands) != 2:
                raise ParseError(
                    f"{mnemonic} requires 2 operands (rd, imm), got {len(operands)}",
                    line_num,
                    line_text,
                )
            rd = parse_register(operands[0])
            imm = self._resolve_immediate(operands[1], line_num, line_text)

        elif fmt == InstructionFormat.J:
            # J-type (JAL): rd, offset/label
            if len(operands) != 2:
                raise ParseError(
                    f"{mnemonic} requires 2 operands (rd, offset), got {len(operands)}",
                    line_num,
                    line_text,
                )
            rd = parse_register(operands[0])

            # Resolve label or immediate to PC-relative offset
            target = operands[1].strip()
            if target in self.symbols:
                # Label reference - compute relative offset
                target_addr = self.symbols[target]
                imm = target_addr - self.current_address
            else:
                # Direct offset
                imm = self._resolve_immediate(target, line_num, line_text)

        return rd, rs1, rs2, imm

    def _resolve_immediate(
        self, value: str, line_num: int, line_text: str
    ) -> int:
        """
        Resolve an immediate value or label reference.

        Args:
            value: Immediate value string or label name
            line_num: Source line number for error reporting
            line_text: Original line text for error reporting

        Returns:
            Integer value
        """
        value = value.strip()

        # Check if it's a label
        if value in self.symbols:
            return self.symbols[value]

        # Try to parse as immediate
        try:
            return parse_immediate(value)
        except ParseError as e:
            # Re-raise with line info
            raise ParseError(str(e), line_num, line_text)

    def write_hex(self, output_path: str) -> None:
        """
        Write assembled instructions to hex file.

        Args:
            output_path: Path to output file
        """
        with open(output_path, "w") as f:
            for instr in self.instructions:
                f.write(f"{instr:08x}\n")

    def get_hex_string(self) -> str:
        """
        Get assembled instructions as a hex string.

        Returns:
            String with one hex instruction per line
        """
        return "\n".join(f"{instr:08x}" for instr in self.instructions)

    def get_listing(self) -> str:
        """
        Get an assembly listing showing addresses, encodings, and source.

        Returns:
            Formatted listing string
        """
        lines = []
        lines.append("Address   Code       Source")
        lines.append("-" * 60)

        for addr, source, line_num in self.source_map:
            idx = addr // 4
            if idx < len(self.instructions):
                code = self.instructions[idx]
                source_stripped = source.strip()
                lines.append(f"0x{addr:04X}:   {code:08X}   {source_stripped}")

        return "\n".join(lines)
