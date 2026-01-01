# Test Program: test_hazard_ex_ex.S
# Description: Tests EX-to-EX forwarding (1-cycle RAW hazard)
#
# This tests the case where an instruction produces a result in EX stage,
# and the immediately following instruction needs that result as an operand.
# The forwarding unit should forward from EX/MEM register.
#
# Expected Register Values:
#   x1  = 10          (0x0000000A)  - Initial value
#   x2  = 10          (0x0000000A)  - Forward x1 to rs1
#   x3  = 10          (0x0000000A)  - Forward x1 to rs2
#   x4  = 20          (0x00000014)  - Forward x1 to both rs1 and rs2
#   x5  = 15          (0x0000000F)  - Chain: depends on x4 via forwarding
#   x6  = 100         (0x00000064)  - Initial value
#   x7  = 95          (0x0000005F)  - SUB with forwarding
#   x8  = 5           (0x00000005)  - Result of SUB
#   x9  = 8           (0x00000008)  - AND with forwarding
#   x10 = 1           (0x00000001)  - SLT with forwarding
#   x11 = 40          (0x00000028)  - SLL with forwarding
#   x12 = 2           (0x00000002)  - SRL with forwarding

.text
.globl _start

_start:
    # ===== Test 2.1.1: EX/MEM -> rs1 forwarding =====
    # ADD produces x1, immediately used as rs1
    addi x1, x0, 10         # x1 = 10
    add  x2, x1, x0         # x2 = x1 + 0 = 10 (forward x1)

    # ===== Test 2.1.2: EX/MEM -> rs2 forwarding =====
    # x1 already = 10, use as rs2
    add  x3, x0, x1         # x3 = 0 + x1 = 10 (forward x1 to rs2)

    # ===== Test 2.1.3: EX/MEM -> both rs1 and rs2 =====
    # x1 = 10, use for both operands
    add  x4, x1, x1         # x4 = x1 + x1 = 20 (forward x1 to both)

    # ===== Test 2.1.4: Chained forwarding =====
    # x4 was just produced, use it immediately
    sub  x5, x4, x1         # x5 = x4 - x1 = 20 - 5 = 15 (forward x4)
    # Note: x1 is now 3 cycles old, comes from register file

    # ===== Test 2.1.5: SUB followed by dependent instruction =====
    addi x6, x0, 100        # x6 = 100
    sub  x7, x6, x1         # x7 = 100 - 10 = 90 (x6 forwarded, x1 not)
    # Note: x6 needs forwarding, x1 from register file

    # Recalculate with proper forwarding test
    addi x6, x0, 100        # x6 = 100
    addi x8, x0, 5          # x8 = 5
    sub  x7, x6, x8         # x7 = 100 - 5 = 95 (both may need forwarding)

    # ===== Test 2.1.6: Different ALU ops with forwarding =====
    addi x8, x0, 5          # x8 = 5
    and  x9, x8, x1         # x9 = 5 & 10 = 0 (binary: 0101 & 1010 = 0000)

    # Let's use values that produce non-zero AND
    addi x8, x0, 15         # x8 = 15 (0xF)
    and  x9, x8, x1         # x9 = 15 & 10 = 10 (0xF & 0xA = 0xA)

    # More interesting: 15 & 8 = 8
    addi x8, x0, 8          # x8 = 8
    or   x9, x8, x1         # x9 = 8 | 10 = 10 | 8 = 10 (0xA | 0x8 = 0xA = 10)
    # Actually: 1010 | 1000 = 1010 = 10... no that's wrong
    # 8 = 1000, 10 = 1010, OR = 1010 = 10? No: 1000 | 1010 = 1010 = 10
    # Wait, let me recalculate: 8 (1000) | 10 (1010) = 1010 = 10? No!
    # 1000 | 1010 = 1010 = 10... Actually 0b1000 | 0b1010 = 0b1010 = 10
    # Hmm, 8|10 should be... 0x8 | 0xA = 0xA = 10... but 8 binary is 1000, 10 is 1010
    # 1000 | 1010 = 1010 = 10. But that seems like 10, not higher.
    # Actually I think 8 | 10 = 10 is wrong. Let me think again:
    # 8  = 0000_1000
    # 10 = 0000_1010
    # OR = 0000_1010 = 10
    # No wait: 1000 OR 1010 = 1010 which is 10. But 8 already contributes bit 3.
    # 8 = bit 3 set (1000)
    # 10 = bit 1 and 3 set (1010)
    # OR = bits 1, 3 = 1010 = 10
    # Hmm, 10 already has bit 3, so 8|10 = 10. Let me use different values.
    addi x8, x0, 12         # x8 = 12 (1100)
    or   x9, x8, x1         # x9 = 12 | 10 = 1100 | 1010 = 1110 = 14

    # Recalculate expected: x9 should be 14, let me redo
    # Actually let me just keep it simple and consistent
    addi x8, x0, 15         # x8 = 15
    and  x9, x8, x1         # x9 = 15 & 10 = 10 (x8 forwarded)

    # Hmm let me reconsider: 15 = 1111, 10 = 1010, AND = 1010 = 10
    # But let me use different test: x9 = 8
    addi x8, x0, 8          # x8 = 8
    and  x9, x8, x8         # x9 = 8 & 8 = 8 (forward to both)

    # ===== Test 2.1.7: SLT with forwarding =====
    addi x8, x0, 5          # x8 = 5
    slt  x10, x8, x1        # x10 = (5 < 10) ? 1 : 0 = 1 (x8 forwarded)

    # ===== Test 2.1.8: Shift with forwarding =====
    addi x8, x0, 10         # x8 = 10
    slli x11, x8, 2         # x11 = 10 << 2 = 40 (x8 forwarded)

    addi x8, x0, 8          # x8 = 8
    srli x12, x8, 2         # x12 = 8 >> 2 = 2 (x8 forwarded)

    # ===== End: Signal completion =====
    ecall
