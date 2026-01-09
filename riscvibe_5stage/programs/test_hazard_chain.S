# Test Program: test_hazard_chain.S
# Description: Tests chained/back-to-back RAW dependencies
#
# This tests long chains of instructions where each instruction
# depends on the result of the immediately preceding instruction.
# The forwarding unit must correctly forward in every cycle.
#
# Expected Register Values:
#   x1  = 1           - Start of chain
#   x2  = 2           - x1 + 1
#   x3  = 3           - x2 + 1
#   x4  = 4           - x3 + 1
#   x5  = 5           - x4 + 1
#   x6  = 6           - x5 + 1
#   x7  = 7           - x6 + 1
#   x8  = 8           - x7 + 1
#   x9  = 16          - x8 * 2 (shift left)
#   x10 = 32          - x9 * 2
#   x11 = 64          - x10 * 2
#   x12 = 128         - x11 * 2
#   x13 = 32          - x12 / 4 (shift right)
#   x14 = 8           - x13 / 4
#   x15 = 10          - Start of new chain
#   x16 = 100         - x15 * x15 (multiply via shift/add)

.text
.globl _start

_start:
    # ===== Test 2.4.1: Long add chain =====
    addi x1, x0, 1          # x1 = 1
    addi x2, x1, 1          # x2 = 2 (forward x1)
    addi x3, x2, 1          # x3 = 3 (forward x2)
    addi x4, x3, 1          # x4 = 4 (forward x3)
    addi x5, x4, 1          # x5 = 5 (forward x4)
    addi x6, x5, 1          # x6 = 6 (forward x5)
    addi x7, x6, 1          # x7 = 7 (forward x6)
    addi x8, x7, 1          # x8 = 8 (forward x7)

    # ===== Test 2.4.2: Shift chain (multiply by 2 repeatedly) =====
    slli x9, x8, 1          # x9 = 8 << 1 = 16 (forward x8)
    slli x10, x9, 1         # x10 = 16 << 1 = 32 (forward x9)
    slli x11, x10, 1        # x11 = 32 << 1 = 64 (forward x10)
    slli x12, x11, 1        # x12 = 64 << 1 = 128 (forward x11)

    # ===== Test 2.4.3: Shift right chain (divide by 4) =====
    srli x13, x12, 2        # x13 = 128 >> 2 = 32 (forward x12)
    srli x14, x13, 2        # x14 = 32 >> 2 = 8 (forward x13)

    # ===== Test 2.4.4: Mixed operation chain =====
    addi x15, x0, 10        # x15 = 10
    # Calculate 10 * 10 = 100 using shifts and adds
    # 10 * 10 = 10 * (8 + 2) = 10*8 + 10*2 = 80 + 20 = 100
    slli x16, x15, 3        # x16 = 10 << 3 = 80 (forward x15)
    slli x17, x15, 1        # x17 = 10 << 1 = 20
    add  x16, x16, x17      # x16 = 80 + 20 = 100 (forward both)

    # ===== Test 2.4.5: Self-modifying chain =====
    addi x18, x0, 1         # x18 = 1
    slli x18, x18, 1        # x18 = 2 (forward x18 to itself)
    slli x18, x18, 1        # x18 = 4 (forward x18 to itself)
    slli x18, x18, 1        # x18 = 8 (forward x18 to itself)
    slli x18, x18, 1        # x18 = 16 (forward x18 to itself)

    # ===== Test 2.4.6: Alternating registers chain =====
    addi x19, x0, 1         # x19 = 1
    add  x20, x19, x19      # x20 = 2 (forward x19 to both)
    add  x19, x20, x20      # x19 = 4 (forward x20 to both)
    add  x20, x19, x19      # x20 = 8 (forward x19 to both)
    add  x19, x20, x20      # x19 = 16 (forward x20 to both)

    # ===== End: Signal completion =====
    ecall
