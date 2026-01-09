# =============================================================================
# Add Test Program for RISC-Vibe RV32I Processor
# =============================================================================
# Tests basic ADD instruction with immediate loads.
#
# Expected register values after execution:
#   x1 = 10
#   x2 = 20
#   x4 = 30 (x1 + x2)
# =============================================================================

.text
.globl _start

_start:
    addi x1, x0, 10         # x1 = 10
    addi x2, x0, 20         # x2 = 20
    add  x4, x1, x2         # x4 = x1 + x2 = 30
    nop                     # Pipeline delay
    nop                     # Pipeline delay
    ecall                   # End program
