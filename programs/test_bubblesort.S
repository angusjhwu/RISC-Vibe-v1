# =============================================================================
# Bubble Sort Test Program for RISC-Vibe RV32I Processor
# =============================================================================
# This program implements bubble sort on a 5-element array.
#
# C equivalent:
#   int arr[5] = {3, 5, 1, 2, 4};
#   for(int i = 0; i < 4; i++){
#       for(int j = 0; j < 4 - i; j++){
#           if(arr[j] > arr[j + 1]){
#               tmp = arr[j];
#               arr[j] = arr[j + 1];
#               arr[j + 1] = tmp;
#           }
#       }
#   }
#
# After sorting, arr[] should contain: {1, 2, 3, 4, 5}
#
# Register usage:
#   sp (x2)  - Stack pointer (initialized to 0x400)
#   s0 (x8)  - Frame pointer
#   a0 (x10) - Return value
#   a3 (x13) - Temporary
#   a4 (x14) - Temporary / arr[j] value
#   a5 (x15) - Temporary / arr[j+1] value
#   ra (x1)  - Return address
#
# Memory layout (after stack setup):
#   s0-48 to s0-32: arr[0..4] (20 bytes)
#   s0-28: tmp (4 bytes)
#   s0-24: j (4 bytes)
#   s0-20: i (4 bytes)
# =============================================================================

    # Initialize stack pointer to 0x400 (1024 bytes into data memory)
    addi    sp, zero, 0x400     # 0x00: sp = 1024

main:
    # Create stack frame
    addi    sp, sp, -48         # 0x04
    # Save s0
    sw      s0, 44(sp)          # 0x08
    # Update s0 (frame pointer)
    addi    s0, sp, 48          # 0x0C

    # Initialize arr[] in memory (at s0-48 to s0-32)
    li      a5, 3               # 0x10
    sw      a5, -48(s0)         # 0x14: arr[0] = 3
    li      a5, 5               # 0x18
    sw      a5, -44(s0)         # 0x1C: arr[1] = 5
    li      a5, 1               # 0x20
    sw      a5, -40(s0)         # 0x24: arr[2] = 1
    li      a5, 2               # 0x28
    sw      a5, -36(s0)         # 0x2C: arr[3] = 2
    li      a5, 4               # 0x30
    sw      a5, -32(s0)         # 0x34: arr[4] = 4

    # Initialize i = 0 in memory
    sw      zero, -20(s0)       # 0x38: i = 0
    j       .L2                 # 0x3C: jump to outer loop check

.L6:    # Outer loop body
    # Initialize j = 0 in memory
    sw      zero, -24(s0)       # 0x40: j = 0
    j       .L3                 # 0x44: jump to inner loop check

.L5:    # Inner loop body
    # Load arr[j] to a4
    lw      a5, -24(s0)         # 0x48: a5 = j
    slli    a5, a5, 2           # 0x4C: a5 = j * 4
    addi    a4, s0, -16         # 0x50
    add     a5, a4, a5          # 0x54: a5 = &arr[j] + 16
    lw      a4, -32(a5)         # 0x58: a4 = arr[j]

    # Load arr[j+1] to a5
    lw      a5, -24(s0)         # 0x5C: a5 = j
    addi    a5, a5, 1           # 0x60: a5 = j + 1
    slli    a5, a5, 2           # 0x64: a5 = (j+1) * 4
    addi    a3, s0, -16         # 0x68
    add     a5, a3, a5          # 0x6C: a5 = &arr[j+1] + 16
    lw      a5, -32(a5)         # 0x70: a5 = arr[j+1]

    # If arr[j+1] >= arr[j], skip swap
    bge     a5, a4, .L4         # 0x74

    # arr[j+1] < arr[j], need to swap

    # Load arr[j] to a5
    lw      a5, -24(s0)         # 0x78: a5 = j
    slli    a5, a5, 2           # 0x7C: a5 = j * 4
    addi    a4, s0, -16         # 0x80
    add     a5, a4, a5          # 0x84
    lw      a5, -32(a5)         # 0x88: a5 = arr[j]

    # Store arr[j] to tmp
    sw      a5, -28(s0)         # 0x8C: tmp = arr[j]

    # Load arr[j+1] to a4
    lw      a5, -24(s0)         # 0x90: a5 = j
    addi    a5, a5, 1           # 0x94: a5 = j + 1
    slli    a5, a5, 2           # 0x98: a5 = (j+1) * 4
    addi    a4, s0, -16         # 0x9C
    add     a5, a4, a5          # 0xA0
    lw      a4, -32(a5)         # 0xA4: a4 = arr[j+1]

    # arr[j] = arr[j+1]
    lw      a5, -24(s0)         # 0xA8: a5 = j
    slli    a5, a5, 2           # 0xAC: a5 = j * 4
    addi    a3, s0, -16         # 0xB0
    add     a5, a3, a5          # 0xB4
    sw      a4, -32(a5)         # 0xB8: arr[j] = arr[j+1]

    # arr[j+1] = tmp
    lw      a5, -24(s0)         # 0xBC: a5 = j
    addi    a5, a5, 1           # 0xC0: a5 = j + 1
    slli    a5, a5, 2           # 0xC4: a5 = (j+1) * 4
    addi    a4, s0, -16         # 0xC8
    add     a5, a4, a5          # 0xCC
    lw      a4, -28(s0)         # 0xD0: a4 = tmp
    sw      a4, -32(a5)         # 0xD4: arr[j+1] = tmp

.L4:    # j++
    lw      a5, -24(s0)         # 0xD8
    addi    a5, a5, 1           # 0xDC
    sw      a5, -24(s0)         # 0xE0

.L3:    # Inner loop check: j < (4 - i)
    li      a4, 4               # 0xE4
    lw      a5, -20(s0)         # 0xE8: a5 = i
    sub     a5, a4, a5          # 0xEC: a5 = 4 - i
    lw      a4, -24(s0)         # 0xF0: a4 = j
    blt     a4, a5, .L5         # 0xF4: if j < (4-i), continue inner loop

    # i++
    lw      a5, -20(s0)         # 0xF8
    addi    a5, a5, 1           # 0xFC
    sw      a5, -20(s0)         # 0x100

.L2:    # Outer loop check: i < 4
    lw      a4, -20(s0)         # 0x104: a4 = i
    li      a5, 3               # 0x108
    bge     a5, a4, .L6         # 0x10C: if 3 >= i (i.e., i < 4), continue outer loop

    # Return 0
    li      a5, 0               # 0x110
    mv      a0, a5              # 0x114
    lw      s0, 44(sp)          # 0x118
    addi    sp, sp, 48          # 0x11C
    ecall                       # 0x120: terminate simulation

# =============================================================================
# Expected result after sorting:
#   arr[0] = 1 (at address 0x3D0)
#   arr[1] = 2 (at address 0x3D4)
#   arr[2] = 3 (at address 0x3D8)
#   arr[3] = 4 (at address 0x3DC)
#   arr[4] = 5 (at address 0x3E0)
# =============================================================================
