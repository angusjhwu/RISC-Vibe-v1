# Test Program: test_hazard_load_use.S
# Description: Tests Load-Use hazard (requires 1-cycle stall)
#
# Load instructions have data available only after MEM stage. When a load
# is immediately followed by an instruction using the loaded value, the
# pipeline must stall for 1 cycle, then forward from MEM/WB.
#
# Memory Setup (done at start):
#   M[0]   = 42  (0x0000002A)
#   M[4]   = 100 (0x00000064)
#   M[8]   = 200 (0x000000C8)
#   M[12]  = 4   (address for indirect test)
#
# Expected Register Values:
#   x1  = 42          - Loaded from M[0]
#   x2  = 42          - Load-use: forward after stall
#   x3  = 100         - Loaded from M[4]
#   x4  = 142         - x1 + x3 with forwarding
#   x5  = 84          - x1 + x1 with forwarding to both
#   x6  = 200         - Loaded from M[8]
#   x7  = 200         - Load-use with rs2
#   x8  = 4           - Loaded from M[12]
#   x9  = 100         - Chain load: LW x9, 0(x8) = LW x9, 0(4) = M[4]
#   x10 = store address (16)
#   After store: M[16] = 42

.text
.globl _start

_start:
    # ===== Setup: Initialize memory with test values =====
    addi x20, x0, 42        # x20 = 42
    sw   x20, 0(x0)         # M[0] = 42

    addi x20, x0, 100       # x20 = 100
    sw   x20, 4(x0)         # M[4] = 100

    addi x20, x0, 200       # x20 = 200
    sw   x20, 8(x0)         # M[8] = 200

    addi x20, x0, 4         # x20 = 4 (address for indirect test)
    sw   x20, 12(x0)        # M[12] = 4

    # ===== Test 3.1.1: Load-use with rs1 =====
    # LW followed immediately by instruction using loaded value as rs1
    lw   x1, 0(x0)          # x1 = M[0] = 42
    add  x2, x1, x0         # x2 = x1 + 0 = 42 (STALL, then forward)

    # ===== Test 3.1.2: Load-use with rs2 =====
    lw   x6, 8(x0)          # x6 = M[8] = 200
    add  x7, x0, x6         # x7 = 0 + x6 = 200 (STALL, then forward)

    # ===== Test 3.1.3: Load-use with both rs1 and rs2 =====
    lw   x1, 0(x0)          # x1 = M[0] = 42
    add  x5, x1, x1         # x5 = x1 + x1 = 84 (STALL, forward to both)

    # ===== Test 3.1.4: Two loads, use both =====
    lw   x1, 0(x0)          # x1 = M[0] = 42
    lw   x3, 4(x0)          # x3 = M[4] = 100 (no dependency, no stall)
    add  x4, x1, x3         # x4 = 42 + 100 = 142 (x1 from MEM/WB, x3 stall+forward)

    # ===== Test 3.1.5: Chain load (address from loaded value) =====
    lw   x8, 12(x0)         # x8 = M[12] = 4 (this is an address)
    lw   x9, 0(x8)          # x9 = M[x8] = M[4] = 100 (STALL for address)

    # ===== Test 3.1.6: Load followed by store =====
    addi x10, x0, 16        # x10 = 16 (store address)
    lw   x1, 0(x0)          # x1 = M[0] = 42
    sw   x1, 0(x10)         # M[16] = x1 = 42 (STALL for store data)

    # Verify the store worked by loading it back
    lw   x11, 16(x0)        # x11 = M[16] = 42

    # ===== Test 3.1.7: Load with no immediate dependency (no stall) =====
    lw   x1, 0(x0)          # x1 = M[0] = 42
    addi x12, x0, 999       # x12 = 999 (independent, no stall needed)
    add  x13, x1, x0        # x13 = 42 (x1 forwarded from MEM/WB, no stall)

    # ===== End: Signal completion =====
    ecall
