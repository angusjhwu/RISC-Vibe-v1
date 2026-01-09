# Test Program: test_hazard_jal.S
# Description: Tests JAL (Jump and Link) control hazard
#
# JAL is an unconditional jump that:
# 1. Saves PC+4 to the destination register (link address)
# 2. Jumps to PC + immediate
# 3. Causes a 2-cycle flush (like taken branches)
#
# Expected Register Values:
#   x1  = return address from first JAL (PC of JAL + 4)
#   x2  = 0           - FLUSHED (after JAL)
#   x3  = 0           - FLUSHED (after JAL)
#   x4  = 100         - Set at target1
#   x5  = return address from second JAL
#   x6  = 200         - Set at target2
#   x7  = return address from third JAL (to x0, discarded)
#   x8  = 0           - FLUSHED
#   x9  = 300         - Set at target3
#   x10 = 400         - Set after all jumps
#   x11 = address of after_func (return address from call)
#   x12 = 500         - Set in function
#   x13 = 600         - Set after function return

.text
.globl _start

_start:
    # ===== Test 4.4.1: Basic JAL with link =====
    jal  x1, target1        # Jump to target1, save return address
    addi x2, x0, 2          # FLUSHED - should not execute
    addi x3, x0, 3          # FLUSHED - should not execute
target1:
    addi x4, x0, 100        # x4 = 100

    # ===== Test 4.4.2: Another JAL =====
    jal  x5, target2        # Jump to target2
    addi x2, x0, 2          # FLUSHED
target2:
    addi x6, x0, 200        # x6 = 200

    # ===== Test 4.4.3: JAL with x0 (no link saved) =====
    jal  x0, target3        # Jump, but don't save link (x0 ignored)
    addi x8, x0, 8          # FLUSHED
target3:
    addi x9, x0, 300        # x9 = 300

    # ===== Continue after all jumps =====
    addi x10, x0, 400       # x10 = 400

    # ===== Test 4.4.4: Function call pattern (JAL + JALR return) =====
    jal  x11, function      # Call function
after_func:
    addi x13, x0, 600       # x13 = 600 (after function return)

    # ===== End: Signal completion =====
    j    end_program

function:
    # Function body
    addi x12, x0, 500       # x12 = 500
    jalr x0, x11, 0         # Return to caller (jump to x11)

end_program:
    ecall
