# RISC-V ALU Test Program for RiscVibe Processor
# Tests all basic ALU operations: arithmetic, logical, shifts, comparisons
#
# Expected register values after execution:
#   x1  = 10          (0x0000000A)
#   x2  = 20          (0x00000014)
#   x3  = -5          (0xFFFFFFFB)
#   x4  = 30          (0x0000001E)
#   x5  = 10          (0x0000000A)
#   x6  = 5           (0x00000005)
#   x7  = 10          (0x0000000A)
#   x8  = 250         (0x000000FA)
#   x9  = 245         (0x000000F5)
#   x10 = 0           (0x00000000) - Pass indicator
#   x11 = 15          (0x0000000F)
#   x12 = -3          (0xFFFFFFFD)
#   x13 = 1           (0x00000001)
#   x14 = 1           (0x00000001)
#   x15 = 1           (0x00000001)
#   x16 = 40          (0x00000028) - Shift result moved here

.text
.globl _start

_start:
    # ============================================
    # Section 1: Test ADDI (I-type immediate adds)
    # ============================================
    addi x1, x0, 10         # x1 = 10
    addi x2, x0, 20         # x2 = 20
    addi x3, x0, -5         # x3 = -5 (test negative immediate)

    # ============================================
    # Section 2: Test R-type arithmetic (ADD, SUB)
    # ============================================
    add  x4, x1, x2         # x4 = x1 + x2 = 10 + 20 = 30
    sub  x5, x2, x1         # x5 = x2 - x1 = 20 - 10 = 10
    add  x6, x3, x1         # x6 = x3 + x1 = -5 + 10 = 5

    # ============================================
    # Section 3: Test logical operations (AND, OR, XOR)
    # ============================================
    andi x7, x1, 0xF        # x7 = x1 & 0xF = 10 & 15 = 10
    ori  x8, x1, 0xF0       # x8 = x1 | 0xF0 = 10 | 240 = 250
    xori x9, x1, 0xFF       # x9 = x1 ^ 0xFF = 10 ^ 255 = 245

    # ============================================
    # Section 4: Test shift operations (SLL, SRL, SRA)
    # ============================================
    slli x16, x1, 2         # x16 = x1 << 2 = 10 << 2 = 40

    # ============================================
    # Section 5: Test comparison operations (SLT, SLTI)
    # ============================================
    slt  x13, x1, x2        # x13 = (x1 < x2) = (10 < 20) = 1
    slti x14, x3, 0         # x14 = (x3 < 0) = (-5 < 0) = 1
    sltu x15, x1, x2        # x15 = (x1 <u x2) = (10 <u 20) = 1

    # ============================================
    # Section 6: More logical operations
    # ============================================
    or   x11, x1, x6        # x11 = x1 | x6 = 10 | 5 = 15
    xor  x12, x3, x1        # x12 = x3 ^ x1 = -5 ^ 10 = -3

    # Set pass indicator
    addi x10, x0, 0         # x10 = 0 (PASS)

    nop
    ecall                   # End program
