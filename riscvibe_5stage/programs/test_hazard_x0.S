# Test Program: test_hazard_x0.S
# Description: Tests x0 (zero register) edge cases
#
# The x0 register is hardwired to zero. This tests:
# 1. Writes to x0 should be ignored
# 2. Reads from x0 should always return 0
# 3. Forwarding should NOT happen when rd = x0
# 4. Dependencies on x0 should not cause hazards
#
# Expected Register Values:
#   x0  = 0           - Always zero (writes ignored)
#   x1  = 0           - x0 + x0 = 0
#   x2  = 0           - Read x0 after "write" to x0
#   x3  = 10          - Normal value
#   x4  = 0           - No forwarding when rd=x0
#   x5  = 0           - x0 should still be 0
#   x6  = 42          - Normal operation
#   x7  = 0           - x0 after many "writes"

.text
.globl _start

_start:
    # ===== Test 6.1.1: Write to x0 is ignored =====
    addi x0, x0, 5          # Try to write 5 to x0 (ignored)
    add  x1, x0, x0         # x1 = x0 + x0 = 0 + 0 = 0

    # ===== Test 6.1.2: Immediate read after write to x0 =====
    addi x0, x0, 100        # Try to write 100 to x0 (ignored)
    add  x2, x0, x0         # x2 = 0 (x0 still 0, no forwarding)

    # ===== Test 6.1.3: Normal operation still works =====
    addi x3, x0, 10         # x3 = 10
    addi x6, x0, 42         # x6 = 42

    # ===== Test 6.1.4: Forwarding should not forward x0 =====
    # Even though previous instruction "wrote" x0, it should not forward
    addi x0, x0, 999        # "Write" to x0 (ignored)
    add  x4, x0, x0         # x4 = 0 (no forwarding from x0 write)

    # ===== Test 6.1.5: R-type with x0 destination =====
    addi x10, x0, 5         # x10 = 5
    addi x11, x0, 3         # x11 = 3
    add  x0, x10, x11       # "Write" to x0 (ignored)
    add  x5, x0, x0         # x5 = 0 (x0 still 0)

    # ===== Test 6.1.6: Multiple consecutive writes to x0 =====
    addi x0, x0, 1          # Ignored
    addi x0, x0, 2          # Ignored
    addi x0, x0, 3          # Ignored
    add  x7, x0, x0         # x7 = 0

    # ===== Test 6.1.7: Load to x0 (ignored) =====
    # First set up memory
    addi x20, x0, 123       # x20 = 123
    sw   x20, 0(x0)         # M[0] = 123
    lw   x0, 0(x0)          # Load to x0 (ignored)
    add  x8, x0, x0         # x8 = 0 (x0 still 0)

    # ===== Final check: x0 is still 0 =====
    beq  x0, x0, end        # Should always branch (0 == 0)
    addi x9, x0, 999        # Should NOT execute

end:
    addi x9, x0, 1          # x9 = 1 (marker that we got here)

    # ===== End: Signal completion =====
    ecall
