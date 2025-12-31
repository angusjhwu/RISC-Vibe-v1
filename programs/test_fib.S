# =============================================================================
# Fibonacci Sequence Test Program for RISC-Vibe RV32I Processor
# =============================================================================
# This program computes the first 10 Fibonacci numbers and stores them in
# registers, then verifies the 10th Fibonacci number (F(10) = 55).
#
# Fibonacci sequence: 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, ...
# F(1) = 1, F(2) = 1, F(n) = F(n-1) + F(n-2) for n > 2
#
# Register allocation:
#   x1  (ra)  - F(n-2), previous-previous value
#   x2  (sp)  - F(n-1), previous value
#   x3  (gp)  - F(n), current value
#   x4  (tp)  - Loop counter (counts down from 8)
#   x10 (a0)  - Test result: 0 = PASS, non-zero = FAIL
#   x11 (a1)  - Expected value (55)
#
# Final register values after execution:
#   x1 = 34 (F(9))
#   x2 = 55 (F(10))
#   x3 = 55 (F(10))
#   x10 = 0 (PASS) if x3 == 55
#
# NOTE: This program requires 2 NOPs before the branch to handle the 2-stage
# pipeline's data hazard (x4 value needs time to propagate through register
# write-back before being read by the branch comparison).
# =============================================================================

    # Initialize F(1) = 1 in x1
    addi x1, x0, 1          # 0x00: x1 = 1 (F(1))

    # Initialize F(2) = 1 in x2
    addi x2, x0, 1          # 0x04: x2 = 1 (F(2))

    # Initialize loop counter = 8 (we compute F(3) through F(10))
    addi x4, x0, 8          # 0x08: x4 = 8 (loop counter)

loop:
    # Compute F(n) = F(n-1) + F(n-2)
    add  x3, x1, x2         # 0x0C: x3 = x1 + x2 (F(n) = F(n-2) + F(n-1))

    # Shift values: F(n-2) = F(n-1), F(n-1) = F(n)
    add  x1, x0, x2         # 0x10: x1 = x2 (F(n-2) = old F(n-1))
    add  x2, x0, x3         # 0x14: x2 = x3 (F(n-1) = F(n))

    # Decrement counter
    addi x4, x4, -1         # 0x18: x4 = x4 - 1

    # NOPs to allow x4 value to be written back before branch reads it
    nop                     # 0x1C: pipeline hazard mitigation
    nop                     # 0x20: pipeline hazard mitigation

    # Branch if counter > 0 (offset = -28 from PC when executing at 0x28)
    bne  x4, x0, loop       # 0x24: if x4 != 0, goto loop (0x0C)

    # Verification: x3 should now contain F(10) = 55
    addi x11, x0, 55        # 0x28: x11 = 55 (expected value)

    # Compare: if x3 == x11, set x10 = 0 (PASS), else non-zero (FAIL)
    sub  x10, x3, x11       # 0x2C: x10 = x3 - 55 (0 if correct)

    # NOP before ECALL
    nop                     # 0x30: delay

    # Terminate simulation
    ecall                   # 0x34

# =============================================================================
# Expected execution trace (after reset):
#
# Iteration 0: x1=1, x2=1, x4=8
# Iteration 1: x3=2,  x1=1, x2=2,  x4=7  (F(3))
# Iteration 2: x3=3,  x1=2, x2=3,  x4=6  (F(4))
# Iteration 3: x3=5,  x1=3, x2=5,  x4=5  (F(5))
# Iteration 4: x3=8,  x1=5, x2=8,  x4=4  (F(6))
# Iteration 5: x3=13, x1=8, x2=13, x4=3  (F(7))
# Iteration 6: x3=21, x1=13, x2=21, x4=2 (F(8))
# Iteration 7: x3=34, x1=21, x2=34, x4=1 (F(9))
# Iteration 8: x3=55, x1=34, x2=55, x4=0 (F(10))
#
# Final: x3=55, x10=0 (PASS)
# =============================================================================
