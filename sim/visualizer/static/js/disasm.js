/**
 * RISC-Vibe RV32I Disassembler
 *
 * Converts 32-bit RISC-V instruction hex values to human-readable assembly strings.
 */

// RV32I Opcodes
const OPCODE = {
    OP:      0b0110011,  // R-type ALU
    OP_IMM:  0b0010011,  // I-type ALU
    LOAD:    0b0000011,  // Load
    STORE:   0b0100011,  // Store
    BRANCH:  0b1100011,  // Branch
    JAL:     0b1101111,  // JAL
    JALR:    0b1100111,  // JALR
    LUI:     0b0110111,  // LUI
    AUIPC:   0b0010111,  // AUIPC
    SYSTEM:  0b1110011,  // ECALL/EBREAK
    FENCE:   0b0001111   // FENCE
};

/**
 * Parse a hex string or number to a 32-bit unsigned integer
 */
function parseInstr(instr) {
    if (typeof instr === 'string') {
        if (instr.startsWith('0x')) {
            return parseInt(instr, 16) >>> 0;
        }
        return parseInt(instr, 16) >>> 0;
    }
    return instr >>> 0;
}

/**
 * Extract instruction fields
 */
function getOpcode(instr) { return instr & 0x7f; }
function getRd(instr)     { return (instr >> 7) & 0x1f; }
function getFunct3(instr) { return (instr >> 12) & 0x7; }
function getRs1(instr)    { return (instr >> 15) & 0x1f; }
function getRs2(instr)    { return (instr >> 20) & 0x1f; }
function getFunct7(instr) { return (instr >> 25) & 0x7f; }

/**
 * Extract immediates with sign extension
 */
function getImmI(instr) {
    // I-type: instr[31:20] sign-extended
    let imm = (instr >> 20) & 0xfff;
    if (imm & 0x800) imm |= 0xfffff000; // Sign extend
    return imm | 0; // Convert to signed
}

function getImmS(instr) {
    // S-type: {instr[31:25], instr[11:7]}
    let imm = ((instr >> 25) << 5) | ((instr >> 7) & 0x1f);
    if (imm & 0x800) imm |= 0xfffff000;
    return imm | 0;
}

function getImmB(instr) {
    // B-type: {instr[31], instr[7], instr[30:25], instr[11:8], 0}
    let imm = (((instr >> 31) & 0x1) << 12) |
              (((instr >> 7) & 0x1) << 11) |
              (((instr >> 25) & 0x3f) << 5) |
              (((instr >> 8) & 0xf) << 1);
    if (imm & 0x1000) imm |= 0xffffe000;
    return imm | 0;
}

function getImmU(instr) {
    // U-type: instr[31:12] << 12
    return instr & 0xfffff000;
}

function getImmJ(instr) {
    // J-type: {instr[31], instr[19:12], instr[20], instr[30:21], 0}
    let imm = (((instr >> 31) & 0x1) << 20) |
              (((instr >> 12) & 0xff) << 12) |
              (((instr >> 20) & 0x1) << 11) |
              (((instr >> 21) & 0x3ff) << 1);
    if (imm & 0x100000) imm |= 0xffe00000;
    return imm | 0;
}

/**
 * Format register as x0-x31
 */
function fmtReg(r) {
    return `x${r}`;
}

/**
 * Format immediate: decimal for small, hex for large
 */
function fmtImm(imm) {
    if (imm >= -4096 && imm <= 4095) {
        return imm.toString(10);
    }
    if (imm < 0) {
        return '-0x' + ((-imm) >>> 0).toString(16);
    }
    return '0x' + (imm >>> 0).toString(16);
}

/**
 * Format U-type immediate (upper 20 bits)
 */
function fmtImmU(imm) {
    return '0x' + ((imm >>> 12) & 0xfffff).toString(16);
}

/**
 * Disassemble R-type instruction
 */
function disasmRType(instr) {
    const funct3 = getFunct3(instr);
    const funct7 = getFunct7(instr);
    const rd = getRd(instr);
    const rs1 = getRs1(instr);
    const rs2 = getRs2(instr);

    let mnemonic;
    switch (funct3) {
        case 0b000: mnemonic = (funct7 === 0b0100000) ? 'sub' : 'add'; break;
        case 0b001: mnemonic = 'sll'; break;
        case 0b010: mnemonic = 'slt'; break;
        case 0b011: mnemonic = 'sltu'; break;
        case 0b100: mnemonic = 'xor'; break;
        case 0b101: mnemonic = (funct7 === 0b0100000) ? 'sra' : 'srl'; break;
        case 0b110: mnemonic = 'or'; break;
        case 0b111: mnemonic = 'and'; break;
        default: mnemonic = '?'; break;
    }

    return `${mnemonic} ${fmtReg(rd)}, ${fmtReg(rs1)}, ${fmtReg(rs2)}`;
}

/**
 * Disassemble I-type ALU instruction
 */
function disasmITypeAlu(instr) {
    const funct3 = getFunct3(instr);
    const funct7 = getFunct7(instr);
    const rd = getRd(instr);
    const rs1 = getRs1(instr);
    const imm = getImmI(instr);
    const shamt = (instr >> 20) & 0x1f;

    let mnemonic;
    switch (funct3) {
        case 0b000: mnemonic = 'addi'; break;
        case 0b010: mnemonic = 'slti'; break;
        case 0b011: mnemonic = 'sltiu'; break;
        case 0b100: mnemonic = 'xori'; break;
        case 0b110: mnemonic = 'ori'; break;
        case 0b111: mnemonic = 'andi'; break;
        case 0b001: mnemonic = 'slli'; break;
        case 0b101: mnemonic = (funct7 === 0b0100000) ? 'srai' : 'srli'; break;
        default: mnemonic = '?'; break;
    }

    // Shift instructions use shamt
    if (funct3 === 0b001 || funct3 === 0b101) {
        return `${mnemonic} ${fmtReg(rd)}, ${fmtReg(rs1)}, ${shamt}`;
    }
    return `${mnemonic} ${fmtReg(rd)}, ${fmtReg(rs1)}, ${fmtImm(imm)}`;
}

/**
 * Disassemble Load instruction
 */
function disasmLoad(instr) {
    const funct3 = getFunct3(instr);
    const rd = getRd(instr);
    const rs1 = getRs1(instr);
    const imm = getImmI(instr);

    let mnemonic;
    switch (funct3) {
        case 0b000: mnemonic = 'lb'; break;
        case 0b001: mnemonic = 'lh'; break;
        case 0b010: mnemonic = 'lw'; break;
        case 0b100: mnemonic = 'lbu'; break;
        case 0b101: mnemonic = 'lhu'; break;
        default: mnemonic = 'l?'; break;
    }

    return `${mnemonic} ${fmtReg(rd)}, ${fmtImm(imm)}(${fmtReg(rs1)})`;
}

/**
 * Disassemble Store instruction
 */
function disasmStore(instr) {
    const funct3 = getFunct3(instr);
    const rs1 = getRs1(instr);
    const rs2 = getRs2(instr);
    const imm = getImmS(instr);

    let mnemonic;
    switch (funct3) {
        case 0b000: mnemonic = 'sb'; break;
        case 0b001: mnemonic = 'sh'; break;
        case 0b010: mnemonic = 'sw'; break;
        default: mnemonic = 's?'; break;
    }

    return `${mnemonic} ${fmtReg(rs2)}, ${fmtImm(imm)}(${fmtReg(rs1)})`;
}

/**
 * Disassemble Branch instruction
 */
function disasmBranch(instr) {
    const funct3 = getFunct3(instr);
    const rs1 = getRs1(instr);
    const rs2 = getRs2(instr);
    const imm = getImmB(instr);

    let mnemonic;
    switch (funct3) {
        case 0b000: mnemonic = 'beq'; break;
        case 0b001: mnemonic = 'bne'; break;
        case 0b100: mnemonic = 'blt'; break;
        case 0b101: mnemonic = 'bge'; break;
        case 0b110: mnemonic = 'bltu'; break;
        case 0b111: mnemonic = 'bgeu'; break;
        default: mnemonic = 'b?'; break;
    }

    return `${mnemonic} ${fmtReg(rs1)}, ${fmtReg(rs2)}, ${fmtImm(imm)}`;
}

/**
 * Disassemble JAL instruction
 */
function disasmJal(instr) {
    const rd = getRd(instr);
    const imm = getImmJ(instr);
    return `jal ${fmtReg(rd)}, ${fmtImm(imm)}`;
}

/**
 * Disassemble JALR instruction
 */
function disasmJalr(instr) {
    const rd = getRd(instr);
    const rs1 = getRs1(instr);
    const imm = getImmI(instr);
    return `jalr ${fmtReg(rd)}, ${fmtReg(rs1)}, ${fmtImm(imm)}`;
}

/**
 * Disassemble LUI instruction
 */
function disasmLui(instr) {
    const rd = getRd(instr);
    const imm = getImmU(instr);
    return `lui ${fmtReg(rd)}, ${fmtImmU(imm)}`;
}

/**
 * Disassemble AUIPC instruction
 */
function disasmAuipc(instr) {
    const rd = getRd(instr);
    const imm = getImmU(instr);
    return `auipc ${fmtReg(rd)}, ${fmtImmU(imm)}`;
}

/**
 * Disassemble SYSTEM instruction
 */
function disasmSystem(instr) {
    const funct3 = getFunct3(instr);
    const imm12 = (instr >> 20) & 0xfff;

    if (funct3 === 0) {
        if (imm12 === 0) return 'ecall';
        if (imm12 === 1) return 'ebreak';
    }
    return '?';
}

/**
 * Main disassembly function
 * @param {string|number} instrHex - Instruction as hex string (e.g., "0x00500093") or number
 * @returns {string} Human-readable assembly string
 */
function disasm(instrHex) {
    const instr = parseInstr(instrHex);

    // Check for NOP (addi x0, x0, 0)
    if (instr === 0x00000013) {
        return 'nop';
    }

    // Check for bubble/invalid instruction
    if (instr === 0x00000000) {
        return '---';
    }

    const opcode = getOpcode(instr);

    switch (opcode) {
        case OPCODE.OP:      return disasmRType(instr);
        case OPCODE.OP_IMM:  return disasmITypeAlu(instr);
        case OPCODE.LOAD:    return disasmLoad(instr);
        case OPCODE.STORE:   return disasmStore(instr);
        case OPCODE.BRANCH:  return disasmBranch(instr);
        case OPCODE.JAL:     return disasmJal(instr);
        case OPCODE.JALR:    return disasmJalr(instr);
        case OPCODE.LUI:     return disasmLui(instr);
        case OPCODE.AUIPC:   return disasmAuipc(instr);
        case OPCODE.SYSTEM:  return disasmSystem(instr);
        case OPCODE.FENCE:   return 'fence';
        default:             return '?';
    }
}

// Export for use in main.js (if using modules) or make globally available
if (typeof window !== 'undefined') {
    window.disasm = disasm;
}
