# =============================================================================
# Simple Test Program for RISC-Vibe RV32I Processor
# =============================================================================
# Basic test that loads immediate values into registers.
#
# Expected register values after execution:
#   x1 = 5
#   x2 = 10
#   x3 = 15
# =============================================================================

.text
.globl _start

_start:
    addi x1, x0, 5          # x1 = 5
    addi x2, x0, 10         # x2 = 10
    addi x3, x0, 15         # x3 = 15
    nop                     # No operation
    ecall                   # End program
