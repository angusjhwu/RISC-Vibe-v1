"""
Custom exception types for the RISC-Vibe assembler.
"""


class AssemblerError(Exception):
    """Base exception for assembler errors."""

    def __init__(self, message: str, line_num: int = None, line_text: str = None):
        self.line_num = line_num
        self.line_text = line_text
        if line_num is not None:
            if line_text:
                message = f"Line {line_num}: {message}\n  {line_text}"
            else:
                message = f"Line {line_num}: {message}"
        super().__init__(message)


class ParseError(AssemblerError):
    """Exception raised for parsing errors."""

    pass


class EncodingError(AssemblerError):
    """Exception raised for instruction encoding errors."""

    pass


class SymbolError(AssemblerError):
    """Exception raised for symbol/label errors."""

    pass
