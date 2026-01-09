# Test Program: test_hazard_comprehensive.S
# Description: Comprehensive hazard test combining all scenarios
#
# This test combines multiple hazard types in realistic patterns:
# - Data hazards with forwarding
# - Load-use hazards with stalls
# - Control hazards with flushes
# - Edge cases and corner cases
#
# Expected Register Values (final):
#   x1  = 10          - Base value
#   x2  = 20          - x1 + x1
#   x3  = 42          - Loaded from memory
#   x4  = 62          - x2 + x3 (mixed forwarding)
#   x5  = 100         - After branch test
#   x6  = 200         - After JAL test
#   x7  = 300         - After JALR test
#   x8  = 5           - Loop counter final
#   x9  = 15          - Accumulated sum (1+2+3+4+5)
#   x10 = 500         - After loop
#   x20 = 1000        - Final success marker

.text
.globl _start

_start:
    # ===== Section 1: Data Hazard Chain =====
    # EX-to-EX forwarding through computation chain
    addi x1, x0, 10         # x1 = 10
    add  x2, x1, x1         # x2 = 20 (forward x1)

    # ===== Section 2: Memory Operations with Hazards =====
    # Store then load with forwarding
    addi x30, x0, 42        # x30 = 42
    sw   x30, 0(x0)         # M[0] = 42
    lw   x3, 0(x0)          # x3 = 42

    # Load-use hazard: add loaded value immediately
    add  x4, x2, x3         # x4 = 20 + 42 = 62 (stall for x3, forward x2)

    # ===== Section 3: Branch with Forwarding =====
    # Branch uses forwarded value for comparison
    addi x10, x0, 5         # x10 = 5
    addi x11, x0, 5         # x11 = 5
    beq  x10, x11, branch1_target # Taken (forward both to branch)
    addi x5, x0, 999        # FLUSHED
branch1_target:
    addi x5, x0, 100        # x5 = 100

    # ===== Section 4: JAL with Hazards =====
    # JAL followed by dependent instruction (flushed)
    jal  x25, jal_target    # Jump, save return address
    addi x6, x0, 999        # FLUSHED
    addi x6, x0, 999        # FLUSHED
jal_target:
    addi x6, x0, 200        # x6 = 200

    # ===== Section 5: JALR with Forwarding =====
    # JALR uses forwarded address
    auipc x26, 0            # x26 = PC
    jalr x27, x26, 12       # Jump to x26 + 12 (forward x26)
    addi x7, x0, 999        # FLUSHED
jalr_target:
    addi x7, x0, 300        # x7 = 300

    # ===== Section 6: Loop with All Hazard Types =====
    # Simple loop that sums 1+2+3+4+5 = 15
    addi x8, x0, 0          # x8 = counter = 0
    addi x9, x0, 0          # x9 = sum = 0
    addi x12, x0, 5         # x12 = limit = 5

loop:
    addi x8, x8, 1          # counter++ (forward x8)
    add  x9, x9, x8         # sum += counter (forward x8, forward x9)
    bne  x8, x12, loop      # branch if counter != 5 (forward both)

    # After loop: x8 = 5, x9 = 15

    addi x10, x0, 500       # x10 = 500 (after loop)

    # ===== Section 7: Store with Forwarded Data =====
    # Store using forwarded values for both address and data
    addi x13, x0, 16        # x13 = address
    addi x14, x0, 999       # x14 = data
    sw   x14, 0(x13)        # M[16] = 999 (forward both x13 and x14)

    # Load it back and verify
    lw   x15, 16(x0)        # x15 = M[16] = 999
    add  x16, x15, x0       # x16 = 999 (load-use stall)

    # ===== Section 8: Multiple Back-to-Back Branches =====
    addi x17, x0, 1         # x17 = 1
    beq  x17, x17, skip1    # Taken
    addi x20, x0, 0         # FLUSHED
skip1:
    addi x17, x0, 2         # x17 = 2
    beq  x17, x17, skip2    # Taken
    addi x20, x0, 0         # FLUSHED
skip2:

    # ===== Section 9: Interleaved Dependencies =====
    # Two parallel chains interleaved
    addi x18, x0, 1         # x18 = 1 (chain A)
    addi x19, x0, 10        # x19 = 10 (chain B)
    add  x18, x18, x18      # x18 = 2 (chain A: forward x18)
    add  x19, x19, x19      # x19 = 20 (chain B: forward x19)
    add  x18, x18, x18      # x18 = 4 (chain A: forward x18)
    add  x19, x19, x19      # x19 = 40 (chain B: forward x19)

    # ===== Section 10: Load Chain =====
    # Multiple loads with dependencies
    addi x21, x0, 100       # x21 = 100
    sw   x21, 20(x0)        # M[20] = 100
    addi x21, x0, 20        # x21 = 20 (address for indirect)
    sw   x21, 24(x0)        # M[24] = 20

    lw   x22, 24(x0)        # x22 = 20 (address)
    lw   x23, 0(x22)        # x23 = M[20] = 100 (load-use stall)

    # ===== Final Success Marker =====
    addi x20, x0, 1000      # x20 = 1000 (success!)

    # ===== End: Signal completion =====
    ecall
