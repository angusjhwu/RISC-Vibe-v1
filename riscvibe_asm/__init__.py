"""
RISC-Vibe Assembler - A modular RV32I assembler for the RISC-Vibe processor.

This package provides a complete assembler for the RV32I base integer instruction set.
"""

from .assembler import Assembler
from .errors import AssemblerError, ParseError, EncodingError

__version__ = "1.0.0"
__all__ = ["Assembler", "AssemblerError", "ParseError", "EncodingError"]
