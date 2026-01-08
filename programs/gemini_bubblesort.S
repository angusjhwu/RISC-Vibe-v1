# =============================================================================
# Bubble Sort Test Program for RISC-Vibe RV32I Processor
# =============================================================================
# Storage:
#   Use registers x1, x2, x3, x4, x5, x6, x7, x8 to store the 8 integers.
# Logic:
#   Perform a "Pass." In each pass, compare x1 with x2, x2 with x3, etc.
#   If a left register is greater than a right register, swap them and set a "swapped" flag (x9).
#   Outer Loop: If the "swapped" flag is set at the end of a pass, repeat the process. If no swaps occurred during a full pass, the array is sorted.
# Registers Used:
#   x1 - x8: The "Array."
#   x9: The swapped flag (0 for false, 1 for true).
#   x10, x11: Temporary registers for swapping.
# 
# // Using discrete variables because we can't index registers in Assembly
# int x1=10, x2=2, x3=5, x4=8, x5=1, x6=3, x7=9, x8=4;
# int swapped;
# 
# do {
#     swapped = 0;
#     // Manual comparison of adjacent "elements"
#     if (x1 > x2) { int tmp = x1; x1 = x2; x2 = tmp; swapped = 1; }
#     if (x2 > x3) { int tmp = x2; x2 = x3; x3 = tmp; swapped = 1; }
#     if (x3 > x4) { int tmp = x3; x3 = x4; x4 = tmp; swapped = 1; }
#     if (x4 > x5) { int tmp = x4; x4 = x5; x5 = tmp; swapped = 1; }
#     if (x5 > x6) { int tmp = x5; x5 = x6; x6 = tmp; swapped = 1; }
#     if (x6 > x7) { int tmp = x6; x6 = x7; x7 = tmp; swapped = 1; }
#     if (x7 > x8) { int tmp = x7; x7 = x8; x8 = tmp; swapped = 1; }
# } while (swapped != 0);
#
# =============================================================================

# 1. Initialization: Load 8 integers into registers
_start:
    addi x1, x0, 10      # x1 = 10
    addi x2, x0, 2       # x2 = 2
    addi x3, x0, 5       # x3 = 5
    addi x4, x0, 8       # x4 = 8
    addi x5, x0, 1       # x5 = 1
    addi x6, x0, 3       # x6 = 3
    addi x7, x0, 9       # x7 = 9
    addi x8, x0, 4       # x8 = 4

# 2. Outer Loop
outer_loop:
    addi x9, x0, 0       # Set swapped_flag (x9) = 0

    # --- Comparison Pass ---
    
    # Pair 1: x1, x2
    blt x1, x2, skip1    # If x1 < x2, don't swap
    beq x1, x2, skip1    # If x1 == x2, don't swap
    addi x10, x1, 0      # tmp = x1
    addi x1, x2, 0       # x1 = x2
    addi x2, x10, 0      # x2 = tmp
    addi x9, x0, 1       # swapped_flag = 1
skip1:

    # Pair 2: x2, x3
    blt x2, x3, skip2
    beq x2, x3, skip2
    addi x10, x2, 0
    addi x2, x3, 0
    addi x3, x10, 0
    addi x9, x0, 1
skip2:

    # Pair 3: x3, x4
    blt x3, x4, skip3
    beq x3, x4, skip3
    addi x10, x3, 0
    addi x3, x4, 0
    addi x4, x10, 0
    addi x9, x0, 1
skip3:

    # Pair 4: x4, x5
    blt x4, x5, skip4
    beq x4, x5, skip4
    addi x10, x4, 0
    addi x4, x5, 0
    addi x5, x10, 0
    addi x9, x0, 1
skip4:

    # Pair 5: x5, x6
    blt x5, x6, skip5
    beq x5, x6, skip5
    addi x10, x5, 0
    addi x5, x6, 0
    addi x6, x10, 0
    addi x9, x0, 1
skip5:

    # Pair 6: x6, x7
    blt x6, x7, skip6
    beq x6, x7, skip6
    addi x10, x6, 0
    addi x6, x7, 0
    addi x7, x10, 0
    addi x9, x0, 1
skip6:

    # Pair 7: x7, x8
    blt x7, x8, skip7
    beq x7, x8, skip7
    addi x10, x7, 0
    addi x7, x8, 0
    addi x8, x10, 0
    addi x9, x0, 1
skip7:

    # Check if any swaps occurred
    bne x9, x0, outer_loop  # If swapped_flag != 0, repeat

# 3. End of Program
end:
    ebreak               # Exit/Halt (standard for many simulators)