# Test Program: test_hazard_branch.S
# Description: Tests control hazards from branches (2-cycle flush)
#
# When a branch is taken in EX stage, the two instructions that were
# speculatively fetched (in IF and ID) must be flushed.
#
# Expected Register Values:
#   x1  = 1           - Set before first branch test
#   x2  = 0           - Should NOT be set (flushed by taken branch)
#   x3  = 0           - Should NOT be set (flushed by taken branch)
#   x4  = 100         - Set at target of first branch
#   x5  = 5           - Set before branch not taken test
#   x6  = 5           - Equal to x5 for comparison
#   x7  = 10          - Set after branch not taken (sequential)
#   x8  = 0           - Skipped (at not-taken target)
#   x9  = 20          - Set in BEQ taken test
#   x10 = 0           - Flushed
#   x11 = 30          - BNE taken test
#   x12 = 40          - BLT taken test
#   x13 = 50          - BGE taken test
#   x14 = 60          - BLTU taken test
#   x15 = 70          - BGEU taken test
#   x16 = 200         - Final marker

.text
.globl _start

_start:
    # ===== Test 4.1.1: Branch taken (BEQ x0,x0) - always taken =====
    addi x1, x0, 1          # x1 = 1
    beq  x0, x0, target1    # Always taken (0 == 0)
    addi x2, x0, 2          # FLUSHED - should not execute
    addi x3, x0, 3          # FLUSHED - should not execute
target1:
    addi x4, x0, 100        # x4 = 100 (executed after branch)

    # ===== Test 4.2.1: Branch not taken (BEQ with unequal) =====
    addi x5, x0, 5          # x5 = 5
    addi x6, x0, 10         # x6 = 10 (different from x5)
    beq  x5, x6, target2    # Not taken (5 != 10)
    addi x7, x0, 10         # x7 = 10 (executed - branch not taken)
    j    skip_target2       # Skip over target2
target2:
    addi x8, x0, 8          # Should NOT execute
skip_target2:

    # ===== Test 4.3.1: BEQ taken =====
    addi x5, x0, 5          # x5 = 5
    addi x6, x0, 5          # x6 = 5 (equal)
    beq  x5, x6, beq_target # Taken (5 == 5)
    addi x10, x0, 10        # FLUSHED
beq_target:
    addi x9, x0, 20         # x9 = 20

    # ===== Test 4.3.3: BNE taken =====
    addi x5, x0, 5          # x5 = 5
    addi x6, x0, 10         # x6 = 10
    bne  x5, x6, bne_target # Taken (5 != 10)
    addi x10, x0, 10        # FLUSHED
bne_target:
    addi x11, x0, 30        # x11 = 30

    # ===== Test 4.3.5: BLT taken (signed) =====
    addi x5, x0, -5         # x5 = -5 (negative)
    addi x6, x0, 10         # x6 = 10
    blt  x5, x6, blt_target # Taken (-5 < 10 signed)
    addi x10, x0, 10        # FLUSHED
blt_target:
    addi x12, x0, 40        # x12 = 40

    # ===== Test 4.3.7: BGE taken (signed) =====
    addi x5, x0, 10         # x5 = 10
    addi x6, x0, 5          # x6 = 5
    bge  x5, x6, bge_target # Taken (10 >= 5 signed)
    addi x10, x0, 10        # FLUSHED
bge_target:
    addi x13, x0, 50        # x13 = 50

    # ===== Test 4.3.9: BLTU taken (unsigned) =====
    addi x5, x0, 5          # x5 = 5
    addi x6, x0, -1         # x6 = 0xFFFFFFFF (large unsigned)
    bltu x5, x6, bltu_target # Taken (5 < 0xFFFFFFFF unsigned)
    addi x10, x0, 10        # FLUSHED
bltu_target:
    addi x14, x0, 60        # x14 = 60

    # ===== Test 4.3.11: BGEU taken (unsigned) =====
    addi x5, x0, -1         # x5 = 0xFFFFFFFF (large unsigned)
    addi x6, x0, 5          # x6 = 5
    bgeu x5, x6, bgeu_target # Taken (0xFFFFFFFF >= 5 unsigned)
    addi x10, x0, 10        # FLUSHED
bgeu_target:
    addi x15, x0, 70        # x15 = 70

    # ===== Final marker =====
    addi x16, x0, 200       # x16 = 200

    # ===== End: Signal completion =====
    ecall
