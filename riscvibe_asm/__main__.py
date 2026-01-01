#!/usr/bin/env python3
"""
RISC-Vibe Assembler - Command Line Interface

Usage:
    python3 -m riscvibe_asm input.S -o output.hex
    python3 -m riscvibe_asm input.S -o output.hex -v
    python3 -m riscvibe_asm input.S --listing
"""

import argparse
import sys
from pathlib import Path

from .assembler import Assembler
from .errors import AssemblerError


def main():
    parser = argparse.ArgumentParser(
        description="RISC-Vibe RV32I Assembler",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s programs/test_alu.S -o programs/test_alu.hex
  %(prog)s programs/test_fib.S -o programs/test_fib.hex -v
  %(prog)s programs/test_alu.S --listing
        """,
    )

    parser.add_argument(
        "input",
        type=str,
        help="Input assembly file (.S)",
    )

    parser.add_argument(
        "-o",
        "--output",
        type=str,
        help="Output hex file (.hex). If not specified, prints to stdout.",
    )

    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable verbose output",
    )

    parser.add_argument(
        "-l",
        "--listing",
        action="store_true",
        help="Print assembly listing",
    )

    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s 1.0.0",
    )

    args = parser.parse_args()

    # Validate input file
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    # Determine output path
    if args.output:
        output_path = args.output
    else:
        output_path = None

    try:
        # Create assembler and assemble
        asm = Assembler(verbose=args.verbose)
        asm.assemble_file(str(input_path), output_path)

        # Print listing if requested
        if args.listing:
            print("\n" + asm.get_listing())

        # If no output file, print hex to stdout
        if not output_path and not args.listing:
            print(asm.get_hex_string())

        # Print summary
        if args.verbose or output_path:
            print(f"\nAssembly successful: {len(asm.instructions)} instructions")

    except AssemblerError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        if args.verbose:
            import traceback

            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
