# =============================================================================
# Maximum 32-bit Fibonacci Test Program for RISC-Vibe RV32I Processor
# =============================================================================
# This program computes F(47) = 2,971,215,073, the largest Fibonacci number
# that fits in a 32-bit unsigned integer.
#
# Fibonacci sequence: F(1)=1, F(2)=1, F(n) = F(n-1) + F(n-2)
# F(47) = 2,971,215,073 = 0xB11924E1
# F(46) = 1,836,311,903 = 0x6D73E55F
#
# Register allocation:
#   x1  (ra)  - F(n-2), previous-previous value
#   x2  (sp)  - F(n-1), previous value
#   x3  (gp)  - F(n), current value
#   x4  (tp)  - Loop counter (counts down from 45)
#   x10 (a0)  - Test result: 0 = PASS, non-zero = FAIL
#   x11 (a1)  - Expected value high bits
#   x12 (a2)  - Expected value low bits (for LUI+ADDI construction)
#
# Final register values after execution:
#   x1 = 1,836,311,903 (F(46)) = 0x6D73E55F
#   x2 = 2,971,215,073 (F(47)) = 0xB11924E1
#   x3 = 2,971,215,073 (F(47)) = 0xB11924E1
#   x10 = 0 (PASS) if x3 == F(47)
#
# To compute F(47), we need 45 iterations: F(2) -> F(3) -> ... -> F(47)
# =============================================================================

    # Initialize F(1) = 1 in x1
    addi x1, x0, 1          # 0x00: x1 = 1 (F(1))

    # Initialize F(2) = 1 in x2
    addi x2, x0, 1          # 0x04: x2 = 1 (F(2))

    # Initialize loop counter = 45 (we compute F(3) through F(47))
    addi x4, x0, 45         # 0x08: x4 = 45 (loop counter)

loop:
    # Compute F(n) = F(n-1) + F(n-2)
    add  x3, x1, x2         # 0x0C: x3 = x1 + x2

    # Shift values: F(n-2) = F(n-1), F(n-1) = F(n)
    add  x1, x0, x2         # 0x10: x1 = x2
    add  x2, x0, x3         # 0x14: x2 = x3

    # Decrement counter
    addi x4, x4, -1         # 0x18: x4 = x4 - 1

    # NOPs to allow x4 value to be written back before branch reads it
    nop                     # 0x1C: pipeline hazard mitigation
    nop                     # 0x20: pipeline hazard mitigation

    # Branch if counter > 0
    bne  x4, x0, loop       # 0x24: if x4 != 0, goto loop

    # Build expected value F(47) = 0xB11924E1 = 2,971,215,073
    # Using LUI + ADDI: LUI loads upper 20 bits, ADDI adds lower 12 bits
    # 0xB11924E1 = 0xB1193 << 12 | 0x4E1
    # But ADDI sign-extends, so we need to adjust:
    # 0x4E1 = 1249 (positive, no adjustment needed)
    # LUI x11, 0xB1193 -> x11 = 0xB1193000
    # ADDI x11, x11, 0x4E1 -> x11 = 0xB11934E1... wait that's wrong
    #
    # Let me recalculate:
    # 0xB11924E1 in binary: 1011 0001 0001 1001 0010 0100 1110 0001
    # Upper 20 bits: 0xB1192 = 726418
    # Lower 12 bits: 0x4E1 = 1249
    # LUI x11, 0xB1192 -> x11 = 0xB1192000
    # ADDI x11, x11, 0x4E1 -> x11 = 0xB11924E1 ✓

    lui  x11, 0xB1192       # 0x28: x11 = 0xB1192000
    addi x11, x11, 0x4E1    # 0x2C: x11 = 0xB11924E1 = F(47)

    # Compare: if x3 == x11, set x10 = 0 (PASS)
    sub  x10, x3, x11       # 0x30: x10 = x3 - F(47) (0 if correct)

    # NOP before ECALL
    nop                     # 0x34: delay

    # Terminate simulation
    ecall                   # 0x38

# =============================================================================
# Key Fibonacci values for verification:
#   F(45) = 1,134,903,170 = 0x43A53F82
#   F(46) = 1,836,311,903 = 0x6D73E55F
#   F(47) = 2,971,215,073 = 0xB11924E1  <- largest that fits in 32 bits
#   F(48) = 4,807,526,976 = 0x11E8D2A40 <- overflows! (needs 33 bits)
# =============================================================================
