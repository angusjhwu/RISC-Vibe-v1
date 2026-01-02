#!/usr/bin/env python3
"""
RISC-Vibe Pipeline Regression Test Runner

Runs all pipeline-related functional correctness tests and generates
a report with pass/fail status and logs for debugging.

Usage:
    ./regression_pipeline.py              # Run all tests
    ./regression_pipeline.py -v           # Verbose output
    ./regression_pipeline.py --test NAME  # Run specific test
    ./regression_pipeline.py --list       # List available tests
"""

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass
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
    registers: dict
    log_file: str
    compile_time: float
    sim_time: float


# Test configurations with expected values
# Format: test_name -> dict of expected register values (None means don't check)
TEST_EXPECTATIONS = {
    # Original tests
    "test_alu": {
        "x1": 0x0000000A,   # 10
        "x2": 0x00000014,   # 20
        "x3": 0xFFFFFFFB,   # -5
        "x4": 0x0000001E,   # 30
        "x10": 0x00000028,  # 40 (not 0, so skip x10=0 check)
    },
    "test_fib": {
        "x10": 0,  # Success marker
    },
    "test_bubblesort": {
        "x10": 0,  # Success marker
    },

    # Hazard tests - most don't use x10=0 convention
    "test_hazard_ex_ex": {
        "x1": 0x0000000A,   # 10
        "x2": 0x0000000A,   # 10 (forward to rs1)
        "x3": 0x0000000A,   # 10 (forward to rs2)
        "x4": 0x00000014,   # 20 (x1+x1)
        "x10": 0x00000001,  # SLT result
        "x11": 0x00000028,  # 40 (shift)
        "x12": 0x00000002,  # 2 (shift)
    },
    "test_hazard_mem_ex": {
        "x1": 0x0000000A,   # 10
        "x3": 0x0000000A,   # 10 (MEM/WB forward)
        "x6": 0x0000001E,   # 30
        "x9": 0x00000014,   # 20
        "x12": 0x000000C8,  # 200
    },
    "test_hazard_load_use": {
        "x1": 0x0000002A,   # 42
        "x2": 0x0000002A,   # 42 (load-use)
        "x3": 0x00000064,   # 100
        "x9": 0x00000064,   # 100 (chain load)
        "x11": 0x0000002A,  # 42 (verify store)
    },
    "test_hazard_branch": {
        "x1": 0x00000001,   # 1
        "x2": 0x00000000,   # 0 (flushed)
        "x4": 0x00000064,   # 100
        "x9": 0x00000014,   # 20
        "x16": 0x000000C8,  # 200
    },
    "test_hazard_jal": {
        "x1": 0x00000004,   # Return address
        "x4": 0x00000064,   # 100
        "x6": 0x000000C8,   # 200
        "x9": 0x0000012C,   # 300
        "x10": 0x00000190,  # 400
    },
    "test_hazard_jalr": {
        "x2": 0x0000000C,   # Return address
        "x4": 0x00000064,   # 100
        "x7": 0x000000C8,   # 200
        "x10": 0x0000012C,  # 300
        "x11": 0x00000190,  # 400
    },
    "test_hazard_x0": {
        "x0": 0x00000000,   # Always 0
        "x1": 0x00000000,   # 0
        "x3": 0x0000000A,   # 10
        "x6": 0x0000002A,   # 42
        "x9": 0x00000001,   # End marker
    },
    "test_hazard_chain": {
        "x1": 0x00000001,
        "x2": 0x00000002,
        "x3": 0x00000003,
        "x4": 0x00000004,
        "x8": 0x00000008,
        "x12": 0x00000080,  # 128
        "x16": 0x00000064,  # 100
    },
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
    """Runs pipeline regression tests."""

    def __init__(self, project_dir: Path, verbose: bool = False):
        self.project_dir = project_dir
        self.verbose = verbose
        self.log_dir = project_dir / "sim" / "logs"
        self.results: list[TestResult] = []

    def log(self, message: str, force: bool = False):
        """Print message if verbose or forced."""
        if self.verbose or force:
            print(message)

    def discover_tests(self) -> list[str]:
        """Find all test programs to run."""
        programs_dir = self.project_dir / "programs"
        tests = []

        # Find all .hex files
        for hex_file in sorted(programs_dir.glob("*.hex")):
            name = hex_file.stem
            # Skip files that are just intermediate artifacts
            if name.endswith("_5stage"):
                continue
            # Include hazard tests and original tests
            if name.startswith("test_hazard_") or name in ["test_alu", "test_fib", "test_bubblesort"]:
                tests.append(name)

        return tests

    def compile_test(self, test_name: str) -> tuple[bool, str, float]:
        """Compile a test program. Returns (success, output, time)."""
        import time

        start = time.time()
        hex_file = f"programs/{test_name}.hex"

        try:
            result = subprocess.run(
                ["make", "compile", f"TESTPROG={hex_file}"],
                cwd=self.project_dir,
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
        import time

        start = time.time()

        try:
            result = subprocess.run(
                ["make", "sim"],
                cwd=self.project_dir,
                capture_output=True,
                text=True,
                timeout=120
            )
            elapsed = time.time() - start
            output = result.stdout + result.stderr
            # Simulation is "successful" if it ran (we check results separately)
            success = result.returncode == 0 or "EBREAK detected" in output
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

    def save_log(self, test_name: str, compile_out: str, sim_out: str) -> str:
        """Save test log to file. Returns log file path."""
        self.log_dir.mkdir(parents=True, exist_ok=True)

        log_file = self.log_dir / f"{test_name}.log"

        with open(log_file, 'w') as f:
            f.write(f"{'='*60}\n")
            f.write(f"Test: {test_name}\n")
            f.write(f"Date: {datetime.now().isoformat()}\n")
            f.write(f"{'='*60}\n\n")

            f.write("--- COMPILATION OUTPUT ---\n")
            f.write(compile_out)
            f.write("\n\n")

            f.write("--- SIMULATION OUTPUT ---\n")
            f.write(sim_out)

        return str(log_file)

    def run_test(self, test_name: str) -> TestResult:
        """Run a single test and return result."""
        self.log(f"\n{'='*50}")
        self.log(f"Running: {test_name}")
        self.log(f"{'='*50}")

        # Compile
        self.log("  Compiling...", force=True)
        compile_ok, compile_out, compile_time = self.compile_test(test_name)

        if not compile_ok:
            log_file = self.save_log(test_name, compile_out, "")
            return TestResult(
                name=test_name,
                passed=False,
                cycles=0,
                reason=f"Compilation failed",
                registers={},
                log_file=log_file,
                compile_time=compile_time,
                sim_time=0
            )

        # Simulate
        self.log("  Simulating...", force=True)
        sim_ok, sim_out, sim_time = self.run_simulation(test_name)

        # Save log
        log_file = self.save_log(test_name, compile_out, sim_out)

        if not sim_ok:
            return TestResult(
                name=test_name,
                passed=False,
                cycles=0,
                reason="Simulation failed or timed out",
                registers={},
                log_file=log_file,
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
            compile_time=compile_time,
            sim_time=sim_time
        )

        status = "PASS" if passed else "FAIL"
        self.log(f"  Result: {status} ({cycles} cycles)")
        if not passed:
            self.log(f"  Reason: {reason}")

        return result

    def run_all(self, test_filter: Optional[str] = None) -> list[TestResult]:
        """Run all tests (or filtered subset)."""
        tests = self.discover_tests()

        if test_filter:
            tests = [t for t in tests if test_filter in t]

        if not tests:
            print("No tests found!")
            return []

        print(f"\nRunning {len(tests)} tests...")
        print("=" * 60)

        self.results = []
        for test in tests:
            result = self.run_test(test)
            self.results.append(result)

        return self.results

    def generate_report(self) -> str:
        """Generate summary report."""
        lines = []
        lines.append("")
        lines.append("=" * 70)
        lines.append("RISC-Vibe Pipeline Regression Test Report")
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

        # Results table
        lines.append("-" * 70)
        lines.append(f"{'Test Name':<35} {'Status':<8} {'Cycles':<10} {'Time':<10}")
        lines.append("-" * 70)

        for r in self.results:
            status = "PASS" if r.passed else "FAIL"
            time_str = f"{r.compile_time + r.sim_time:.2f}s"
            lines.append(f"{r.name:<35} {status:<8} {r.cycles:<10} {time_str:<10}")

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
        report_file = self.project_dir / "sim" / "regression_report.txt"
        report_file.parent.mkdir(parents=True, exist_ok=True)

        with open(report_file, 'w') as f:
            f.write(report)

        print(f"\nReport saved to: {report_file}")


def main():
    parser = argparse.ArgumentParser(
        description="RISC-Vibe Pipeline Regression Test Runner"
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

    args = parser.parse_args()

    # Find project directory (where this script is located)
    project_dir = Path(__file__).parent.resolve()

    runner = RegressionRunner(project_dir, verbose=args.verbose)

    if args.list:
        tests = runner.discover_tests()
        print("Available tests:")
        for t in tests:
            print(f"  {t}")
        return 0

    # Run tests
    results = runner.run_all(test_filter=args.test)

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
