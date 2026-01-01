# Test Program: test_hazard_jalr.S
# Description: Tests JALR (Jump and Link Register) control hazard
#
# JALR is an indirect jump that:
# 1. Computes target as (rs1 + immediate) & ~1
# 2. Saves PC+4 to the destination register
# 3. Jumps to computed target
# 4. Causes a 2-cycle flush
#
# Additional complexity: JALR may depend on a register value
# that needs forwarding or stall (load-use).
#
# Expected Register Values:
#   x1  = base address
#   x2  = return address from first JALR
#   x3  = 0           - FLUSHED
#   x4  = 100         - Set at target1
#   x5  = target2 address
#   x6  = return address
#   x7  = 200         - Set at target2
#   x8  = address computed with forwarding
#   x9  = return address
#   x10 = 300         - Set at target3
#   x11 = 400         - Final marker

.text
.globl _start

_start:
    # ===== Setup: Compute address for first JALR =====
    # We need to know the address of target1
    # Use AUIPC to get current PC, then add offset
    # target1 is 5 instructions ahead: AUIPC, ADDI, JALR, ADDI(flushed), ADDI(flushed)
    auipc x1, 0             # x1 = PC of this instruction = 0x00
    addi  x1, x1, 20        # x1 = 0x14 = address of target1 (5 instructions * 4 bytes)

    # ===== Test 4.5.1: Basic JALR =====
    jalr x2, x1, 0          # Jump to x1, save return address to x2
    addi x3, x0, 3          # FLUSHED
    addi x3, x0, 3          # FLUSHED
target1:
    addi x4, x0, 100        # x4 = 100

    # ===== Test 4.5.2: JALR with immediate offset =====
    auipc x5, 0             # x5 = PC
    # target2 is 16 bytes ahead (4 instructions)
    jalr x6, x5, 16         # Jump to x5 + 16
    addi x3, x0, 3          # FLUSHED
    addi x3, x0, 3          # FLUSHED
target2:
    addi x7, x0, 200        # x7 = 200

    # ===== Test 4.5.3: JALR with forwarded register (EX hazard) =====
    auipc x8, 0             # x8 = PC (needs forwarding to JALR)
    jalr x9, x8, 12         # Jump to x8 + 12 (forward x8 from EX/MEM)
    addi x3, x0, 3          # FLUSHED
target3:
    addi x10, x0, 300       # x10 = 300

    # ===== Final marker =====
    addi x11, x0, 400       # x11 = 400

    # ===== End: Signal completion =====
    ecall
