# =============================================================================
# Branch Test Program for RISC-Vibe RV32I Processor
# =============================================================================
# Tests BNE (branch not equal) instruction.
#
# If x1 != x2, branch skips the instruction that clears x2.
#
# Expected register values after execution:
#   x1 = 5
#   x2 = 3 (branch taken, so x2 is NOT cleared to 0)
# =============================================================================

.text
.globl _start

_start:
    addi x1, x0, 5          # x1 = 5
    addi x2, x0, 3          # x2 = 3
    nop                     # Pipeline delay
    nop                     # Pipeline delay
    bne  x1, x2, skip       # If x1 != x2, skip next instruction
    addi x2, x0, 0          # x2 = 0 (skipped if branch taken)
skip:
    nop                     # Pipeline delay
    ecall                   # End program
