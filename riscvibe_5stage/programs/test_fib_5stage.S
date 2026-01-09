# =============================================================================
# Fibonacci Test Program for 5-Stage Pipeline (with NOPs for hazards)
# =============================================================================
# Computes Fibonacci sequence: F(1)=1, F(2)=1, F(n)=F(n-1)+F(n-2)
# This version includes NOP instructions to handle pipeline hazards in the
# 5-stage processor without forwarding.
#
# Expected register values after execution:
#   x1 = 34 (F(9))
#   x2 = 55 (F(10))
#   x3 = 55 (F(10))
#   x4 = 0  (loop counter exhausted)
#   x10 = 0 (PASS if x3 == 55)
#   x11 = 55 (expected value)
# =============================================================================

.text
.globl _start

_start:
    addi x1, x0, 1          # x1 = 1 (F(1))
    addi x2, x0, 1          # x2 = 1 (F(2))
    addi x4, x0, 8          # x4 = 8 (loop counter)

loop:
    add  x3, x1, x2         # x3 = x1 + x2 (F(n) = F(n-2) + F(n-1))
    add  x1, x0, x2         # x1 = x2 (shift: F(n-2) = old F(n-1))
    add  x2, x0, x3         # x2 = x3 (shift: F(n-1) = new F(n))
    addi x4, x4, -1         # x4 = x4 - 1 (decrement counter)
    nop                     # Pipeline delay for x4
    nop                     # Pipeline delay for x4
    bne  x4, x0, loop       # If x4 != 0, continue loop

    # Verify result: x3 should be 55
    addi x11, x0, 55        # x11 = 55 (expected F(10))
    sub  x10, x3, x11       # x10 = x3 - 55 (0 if PASS)
    nop                     # Pipeline delay
    ecall                   # End program
