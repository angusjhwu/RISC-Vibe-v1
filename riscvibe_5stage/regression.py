#!/usr/bin/env python3
"""
RISC-Vibe 5-Stage Pipeline Regression Test Runner

Runs all test programs in the programs/ directory to verify processor correctness.
This includes hazard detection/forwarding tests specific to the 5-stage pipeline.
Automatically assembles .S files to .hex, compiles, simulates, and validates results.

Usage:
    ./regression.py              # Run all tests
    ./regression.py -v           # Verbose output
    ./regression.py --test NAME  # Run specific test
    ./regression.py --list       # List available tests
"""

import argparse
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional


@dataclass
class TestResult:
    """Result of a single test run."""
    name: str
    passed: bool
    cycles: int
    reason: str
    registers: dict = field(default_factory=dict)
    log_file: str = ""
    assemble_time: float = 0.0
    compile_time: float = 0.0
    sim_time: float = 0.0


# Test configurations with expected register values
# Format: test_name -> dict of expected register values
# These are derived from the comments in each .S file
TEST_EXPECTATIONS = {
    # Basic tests
    "test_simple": {
        "x1": 5,
        "x2": 10,
        "x3": 15,
    },
    "test_add": {
        "x1": 10,
        "x2": 20,
        "x4": 30,
    },
    "test_branch": {
        "x1": 5,
        "x2": 3,  # Branch taken, so x2 is NOT cleared to 0
    },
    "test_alu": {
        "x1": 0x0000000A,   # 10
        "x2": 0x00000014,   # 20
        "x3": 0xFFFFFFFB,   # -5 (two's complement)
        "x4": 0x0000001E,   # 30
        "x5": 0x0000000A,   # 10
        "x6": 0x00000005,   # 5
        "x10": 0x00000000,  # 0 (PASS indicator)
        "x16": 0x00000028,  # 40 (shift result)
    },
    "test_fib_5stage": {
        "x1": 34,           # F(9)
        "x2": 55,           # F(10)
        "x3": 55,           # F(10)
        "x10": 0,           # PASS (x3 - 55 = 0)
        "x11": 55,          # Expected value
    },

    # Hazard tests - EX-to-EX forwarding
    "test_hazard_ex_ex": {
        "x1": 0x0000000A,   # 10
        "x2": 0x0000000A,   # 10 (forward to rs1)
        "x3": 0x0000000A,   # 10 (forward to rs2)
        "x4": 0x00000014,   # 20 (x1+x1)
        "x10": 0x00000001,  # SLT result
        "x11": 0x00000028,  # 40 (shift)
        "x12": 0x00000002,  # 2 (shift)
    },

    # Hazard tests - MEM-to-EX forwarding
    "test_hazard_mem_ex": {
        "x1": 0x0000000A,   # 10
        "x3": 0x0000000A,   # 10 (MEM/WB forward)
        "x6": 0x0000001E,   # 30
        "x9": 0x00000014,   # 20
        "x12": 0x000000C8,  # 200
    },

    # Hazard tests - Load-use stall
    "test_hazard_load_use": {
        "x1": 0x0000002A,   # 42
        "x2": 0x0000002A,   # 42 (load-use)
        "x3": 0x00000064,   # 100
        "x9": 0x00000064,   # 100 (chain load)
        "x11": 0x0000002A,  # 42 (verify store)
    },

    # Hazard tests - Branch flush
    "test_hazard_branch": {
        "x1": 0x00000001,   # 1
        "x2": 0x00000000,   # 0 (flushed)
        "x4": 0x00000064,   # 100
        "x9": 0x00000014,   # 20
        "x16": 0x000000C8,  # 200
    },

    # Hazard tests - JAL control hazard
    "test_hazard_jal": {
        "x1": 0x00000004,   # Return address
        "x4": 0x00000064,   # 100
        "x6": 0x000000C8,   # 200
        "x9": 0x0000012C,   # 300
        "x10": 0x00000190,  # 400
    },

    # Hazard tests - JALR control hazard
    "test_hazard_jalr": {
        "x2": 0x0000000C,   # Return address
        "x4": 0x00000064,   # 100
        "x7": 0x000000C8,   # 200
        "x10": 0x0000012C,  # 300
        "x11": 0x00000190,  # 400
    },

    # Hazard tests - x0 hardwired zero
    "test_hazard_x0": {
        "x0": 0x00000000,   # Always 0
        "x1": 0x00000000,   # 0
        "x3": 0x0000000A,   # 10
        "x6": 0x0000002A,   # 42
        "x9": 0x00000001,   # End marker
    },

    # Hazard tests - Chained dependencies
    "test_hazard_chain": {
        "x1": 0x00000001,
        "x2": 0x00000002,
        "x3": 0x00000003,
        "x4": 0x00000004,
        "x8": 0x00000008,
        "x12": 0x00000080,  # 128
        "x16": 0x00000064,  # 100
    },

    # Hazard tests - Comprehensive
    "test_hazard_comprehensive": {
        "x1": 0x0000000A,   # 10
        "x2": 0x00000014,   # 20
        "x3": 0x0000002A,   # 42
        "x4": 0x0000003E,   # 62
        "x5": 0x00000064,   # 100
        "x8": 0x00000005,   # 5 (loop counter)
        "x9": 0x0000000F,   # 15 (sum)
        "x20": 0x000003E8,  # 1000 (success marker)
    },
}


class RegressionRunner:
    """Runs regression tests for the 5-stage pipeline processor."""

    def __init__(self, processor_dir: Path, verbose: bool = False):
        self.processor_dir = processor_dir
        self.project_dir = processor_dir.parent
        self.verbose = verbose
        self.programs_dir = processor_dir / "programs"
        self.sim_dir = processor_dir / "sim"
        self.log_dir = self.sim_dir / "logs"
        self.results: list[TestResult] = []

    def log(self, message: str, force: bool = False):
        """Print message if verbose or forced."""
        if self.verbose or force:
            print(message)

    def discover_tests(self) -> list[str]:
        """Find all test programs (.S files) to run."""
        tests = []
        for s_file in sorted(self.programs_dir.glob("*.S")):
            tests.append(s_file.stem)
        return tests

    def assemble_program(self, test_name: str) -> tuple[bool, str, float]:
        """Assemble a .S file to .hex. Returns (success, output, time)."""
        start = time.time()
        s_file = self.programs_dir / f"{test_name}.S"
        hex_file = self.programs_dir / f"{test_name}.hex"

        try:
            result = subprocess.run(
                [
                    sys.executable, "-m", "riscvibe_asm",
                    str(s_file), "-o", str(hex_file)
                ],
                cwd=self.project_dir,
                capture_output=True,
                text=True,
                timeout=30
            )
            elapsed = time.time() - start
            output = result.stdout + result.stderr

            if result.returncode != 0:
                return False, f"Assembly failed:\n{output}", elapsed

            return True, output, elapsed

        except subprocess.TimeoutExpired:
            return False, "Assembly timed out", time.time() - start
        except Exception as e:
            return False, f"Assembly error: {e}", time.time() - start

    def compile_test(self, test_name: str) -> tuple[bool, str, float]:
        """Compile the processor with test program. Returns (success, output, time)."""
        start = time.time()

        try:
            result = subprocess.run(
                ["make", "compile", f"PROGRAM={test_name}"],
                cwd=self.processor_dir,
                capture_output=True,
                text=True,
                timeout=60
            )
            elapsed = time.time() - start
            output = result.stdout + result.stderr
            success = result.returncode == 0 and "Compilation successful" in output
            return success, output, elapsed

        except subprocess.TimeoutExpired:
            return False, "Compilation timed out", time.time() - start
        except Exception as e:
            return False, f"Compilation error: {e}", time.time() - start

    def run_simulation(self, test_name: str) -> tuple[bool, str, float]:
        """Run simulation. Returns (success, output, time)."""
        start = time.time()

        try:
            result = subprocess.run(
                ["make", "sim"],
                cwd=self.processor_dir,
                capture_output=True,
                text=True,
                timeout=120
            )
            elapsed = time.time() - start
            output = result.stdout + result.stderr

            # Simulation is "successful" if it ran to completion
            success = (
                result.returncode == 0 or
                "ECALL detected" in output or
                "EBREAK detected" in output
            )
            return success, output, elapsed

        except subprocess.TimeoutExpired:
            return False, "Simulation timed out", time.time() - start
        except Exception as e:
            return False, f"Simulation error: {e}", time.time() - start

    def parse_registers(self, output: str) -> dict:
        """Parse register values from simulation output."""
        registers = {}

        # Match lines like: x1  (ra)   = 0x0000000a
        pattern = r'x(\d+)\s+\(\w+\)\s+=\s+0x([0-9a-fA-F]+)'
        for match in re.finditer(pattern, output):
            reg_num = int(match.group(1))
            value = int(match.group(2), 16)
            registers[f"x{reg_num}"] = value

        return registers

    def parse_cycles(self, output: str) -> int:
        """Parse cycle count from simulation output."""
        # Match: Stopping simulation after N cycles
        match = re.search(r'Stopping simulation after (\d+) cycles', output)
        if match:
            return int(match.group(1))
        return 0

    def check_expectations(self, test_name: str, registers: dict) -> tuple[bool, str]:
        """Check if register values match expectations."""
        if test_name not in TEST_EXPECTATIONS:
            # No expectations defined - pass if simulation completed
            return True, "No expectations defined (simulation completed)"

        expected = TEST_EXPECTATIONS[test_name]
        failures = []

        for reg, exp_value in expected.items():
            if reg not in registers:
                failures.append(f"{reg}: not found in output")
                continue

            actual = registers[reg]
            if actual != exp_value:
                failures.append(f"{reg}: expected 0x{exp_value:08X}, got 0x{actual:08X}")

        if failures:
            return False, "; ".join(failures)
        return True, "All register values match"

    def save_log(self, test_name: str, asm_out: str, compile_out: str, sim_out: str) -> str:
        """Save test log to file. Returns log file path."""
        self.log_dir.mkdir(parents=True, exist_ok=True)
        log_file = self.log_dir / f"{test_name}.log"

        with open(log_file, 'w') as f:
            f.write(f"{'='*60}\n")
            f.write(f"Test: {test_name}\n")
            f.write(f"Processor: RISC-Vibe 5-Stage Pipeline\n")
            f.write(f"Date: {datetime.now().isoformat()}\n")
            f.write(f"{'='*60}\n\n")

            f.write("--- ASSEMBLY OUTPUT ---\n")
            f.write(asm_out if asm_out else "(no output)\n")
            f.write("\n\n")

            f.write("--- COMPILATION OUTPUT ---\n")
            f.write(compile_out if compile_out else "(no output)\n")
            f.write("\n\n")

            f.write("--- SIMULATION OUTPUT ---\n")
            f.write(sim_out if sim_out else "(no output)\n")

        return str(log_file)

    def cleanup_hex(self, test_name: str):
        """Remove generated .hex file."""
        hex_file = self.programs_dir / f"{test_name}.hex"
        if hex_file.exists():
            hex_file.unlink()

    def run_test(self, test_name: str, keep_hex: bool = False) -> TestResult:
        """Run a single test and return result."""
        self.log(f"\n{'='*50}")
        self.log(f"Running: {test_name}")
        self.log(f"{'='*50}")

        asm_out = ""
        compile_out = ""
        sim_out = ""

        # Step 1: Assemble
        self.log("  Assembling...", force=True)
        asm_ok, asm_out, asm_time = self.assemble_program(test_name)

        if not asm_ok:
            log_file = self.save_log(test_name, asm_out, "", "")
            return TestResult(
                name=test_name,
                passed=False,
                cycles=0,
                reason="Assembly failed",
                log_file=log_file,
                assemble_time=asm_time
            )

        # Step 2: Compile
        self.log("  Compiling...", force=True)
        compile_ok, compile_out, compile_time = self.compile_test(test_name)

        if not compile_ok:
            log_file = self.save_log(test_name, asm_out, compile_out, "")
            if not keep_hex:
                self.cleanup_hex(test_name)
            return TestResult(
                name=test_name,
                passed=False,
                cycles=0,
                reason="Compilation failed",
                log_file=log_file,
                assemble_time=asm_time,
                compile_time=compile_time
            )

        # Step 3: Simulate
        self.log("  Simulating...", force=True)
        sim_ok, sim_out, sim_time = self.run_simulation(test_name)

        # Save log
        log_file = self.save_log(test_name, asm_out, compile_out, sim_out)

        # Cleanup hex file
        if not keep_hex:
            self.cleanup_hex(test_name)

        if not sim_ok:
            return TestResult(
                name=test_name,
                passed=False,
                cycles=0,
                reason="Simulation failed or timed out",
                log_file=log_file,
                assemble_time=asm_time,
                compile_time=compile_time,
                sim_time=sim_time
            )

        # Parse results
        registers = self.parse_registers(sim_out)
        cycles = self.parse_cycles(sim_out)

        # Check expectations
        passed, reason = self.check_expectations(test_name, registers)

        result = TestResult(
            name=test_name,
            passed=passed,
            cycles=cycles,
            reason=reason,
            registers=registers,
            log_file=log_file,
            assemble_time=asm_time,
            compile_time=compile_time,
            sim_time=sim_time
        )

        status = "PASS" if passed else "FAIL"
        self.log(f"  Result: {status} ({cycles} cycles)")
        if not passed:
            self.log(f"  Reason: {reason}")

        return result

    def run_all(self, test_filter: Optional[str] = None, keep_hex: bool = False) -> list[TestResult]:
        """Run all tests (or filtered subset)."""
        tests = self.discover_tests()

        if test_filter:
            tests = [t for t in tests if test_filter in t]

        if not tests:
            print("No tests found!")
            return []

        print(f"\nRISC-Vibe 5-Stage Pipeline Regression")
        print(f"Running {len(tests)} tests...")
        print("=" * 60)

        self.results = []
        for test in tests:
            result = self.run_test(test, keep_hex=keep_hex)
            self.results.append(result)

        return self.results

    def generate_report(self) -> str:
        """Generate summary report."""
        lines = []
        lines.append("")
        lines.append("=" * 70)
        lines.append("RISC-Vibe 5-Stage Pipeline Regression Test Report")
        lines.append(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append("=" * 70)
        lines.append("")

        # Summary
        total = len(self.results)
        passed = sum(1 for r in self.results if r.passed)
        failed = total - passed

        lines.append(f"Summary: {passed}/{total} tests passed")
        if failed > 0:
            lines.append(f"         {failed} tests FAILED")
        lines.append("")

        # Categorize tests
        basic_tests = [r for r in self.results if not r.name.startswith("test_hazard")]
        hazard_tests = [r for r in self.results if r.name.startswith("test_hazard")]

        # Basic tests table
        if basic_tests:
            lines.append("Basic Tests:")
            lines.append("-" * 70)
            lines.append(f"{'Test Name':<30} {'Status':<8} {'Cycles':<10} {'Time':<10}")
            lines.append("-" * 70)
            for r in basic_tests:
                status = "PASS" if r.passed else "FAIL"
                total_time = r.assemble_time + r.compile_time + r.sim_time
                time_str = f"{total_time:.2f}s"
                lines.append(f"{r.name:<30} {status:<8} {r.cycles:<10} {time_str:<10}")
            lines.append("")

        # Hazard tests table
        if hazard_tests:
            lines.append("Pipeline Hazard Tests:")
            lines.append("-" * 70)
            lines.append(f"{'Test Name':<30} {'Status':<8} {'Cycles':<10} {'Time':<10}")
            lines.append("-" * 70)
            for r in hazard_tests:
                status = "PASS" if r.passed else "FAIL"
                total_time = r.assemble_time + r.compile_time + r.sim_time
                time_str = f"{total_time:.2f}s"
                lines.append(f"{r.name:<30} {status:<8} {r.cycles:<10} {time_str:<10}")
            lines.append("-" * 70)
        lines.append("")

        # Failures detail
        failures = [r for r in self.results if not r.passed]
        if failures:
            lines.append("FAILURES:")
            lines.append("-" * 70)
            for r in failures:
                lines.append(f"  {r.name}:")
                lines.append(f"    Reason: {r.reason}")
                lines.append(f"    Log: {r.log_file}")
            lines.append("")

        # Footer
        lines.append("=" * 70)
        if failed == 0:
            lines.append("ALL TESTS PASSED!")
        else:
            lines.append(f"REGRESSION FAILED: {failed} test(s) failed")
        lines.append("=" * 70)

        return "\n".join(lines)

    def save_report(self, report: str):
        """Save report to file."""
        self.sim_dir.mkdir(parents=True, exist_ok=True)
        report_file = self.sim_dir / "regression_report.txt"

        with open(report_file, 'w') as f:
            f.write(report)

        print(f"\nReport saved to: {report_file}")


def main():
    parser = argparse.ArgumentParser(
        description="RISC-Vibe 5-Stage Pipeline Regression Test Runner"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Verbose output"
    )
    parser.add_argument(
        "--test",
        type=str,
        help="Run only tests matching this name"
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available tests and exit"
    )
    parser.add_argument(
        "--keep-hex",
        action="store_true",
        help="Keep generated .hex files after tests"
    )

    args = parser.parse_args()

    # Find processor directory (where this script is located)
    processor_dir = Path(__file__).parent.resolve()

    runner = RegressionRunner(processor_dir, verbose=args.verbose)

    if args.list:
        tests = runner.discover_tests()
        basic = [t for t in tests if not t.startswith("test_hazard")]
        hazard = [t for t in tests if t.startswith("test_hazard")]

        print("Available tests:")
        print("\nBasic Tests:")
        for t in basic:
            exp = "✓" if t in TEST_EXPECTATIONS else "○"
            print(f"  {exp} {t}")

        print("\nPipeline Hazard Tests:")
        for t in hazard:
            exp = "✓" if t in TEST_EXPECTATIONS else "○"
            print(f"  {exp} {t}")

        print(f"\n✓ = has expected values, ○ = no expectations (pass on completion)")
        return 0

    # Run tests
    results = runner.run_all(test_filter=args.test, keep_hex=args.keep_hex)

    if not results:
        return 1

    # Generate and display report
    report = runner.generate_report()
    print(report)

    # Save report
    runner.save_report(report)

    # Return exit code based on results
    failed = sum(1 for r in results if not r.passed)
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
