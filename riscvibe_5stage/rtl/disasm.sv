//==============================================================================
// RISC-Vibe RV32I Processor - Disassembler Package
//==============================================================================
// This package provides instruction disassembly functions for converting
// 32-bit RISC-V instructions into human-readable assembly strings.
// Used by the trace logger for debugging and waveform annotation.
//==============================================================================

package disasm_pkg;

  import riscvibe_pkg::*;

  //============================================================================
  // Field Extraction Helper Functions
  //============================================================================

  // Extract rd field (bits 11:7)
  function automatic logic [4:0] get_rd(input logic [31:0] instr);
    return instr[11:7];
  endfunction

  // Extract rs1 field (bits 19:15)
  function automatic logic [4:0] get_rs1(input logic [31:0] instr);
    return instr[19:15];
  endfunction

  // Extract rs2 field (bits 24:20)
  function automatic logic [4:0] get_rs2(input logic [31:0] instr);
    return instr[24:20];
  endfunction

  // Extract funct3 field (bits 14:12)
  function automatic logic [2:0] get_funct3(input logic [31:0] instr);
    return instr[14:12];
  endfunction

  // Extract funct7 field (bits 31:25)
  function automatic logic [6:0] get_funct7(input logic [31:0] instr);
    return instr[31:25];
  endfunction

  // Extract opcode field (bits 6:0)
  function automatic logic [6:0] get_opcode(input logic [31:0] instr);
    return instr[6:0];
  endfunction

  //============================================================================
  // Immediate Extraction Functions (with sign extension)
  //============================================================================

  // I-type immediate: instr[31:20] sign-extended
  function automatic logic signed [31:0] get_imm_i(input logic [31:0] instr);
    return {{20{instr[31]}}, instr[31:20]};
  endfunction

  // S-type immediate: {instr[31:25], instr[11:7]} sign-extended
  function automatic logic signed [31:0] get_imm_s(input logic [31:0] instr);
    return {{20{instr[31]}}, instr[31:25], instr[11:7]};
  endfunction

  // B-type immediate: {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0} sign-extended
  function automatic logic signed [31:0] get_imm_b(input logic [31:0] instr);
    return {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
  endfunction

  // U-type immediate: {instr[31:12], 12'b0}
  function automatic logic [31:0] get_imm_u(input logic [31:0] instr);
    return {instr[31:12], 12'b0};
  endfunction

  // J-type immediate: {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0} sign-extended
  function automatic logic signed [31:0] get_imm_j(input logic [31:0] instr);
    return {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
  endfunction

  //============================================================================
  // Formatting Helper Functions
  //============================================================================

  // Format register name as "x0" through "x31"
  function automatic string fmt_reg(input logic [4:0] reg_addr);
    return $sformatf("x%0d", reg_addr);
  endfunction

  // Format immediate value: signed decimal for small values, hex for large
  function automatic string fmt_imm(input logic signed [31:0] imm);
    if (imm >= -4096 && imm <= 4095) begin
      return $sformatf("%0d", imm);
    end else begin
      return $sformatf("0x%0x", imm);
    end
  endfunction

  // Format unsigned immediate (for U-type upper bits)
  function automatic string fmt_imm_u(input logic [31:0] imm);
    // U-type stores upper 20 bits, show the upper immediate value
    logic [19:0] upper;
    upper = imm[31:12];
    return $sformatf("0x%0x", upper);
  endfunction

  //============================================================================
  // Instruction Type Disassembly Functions
  //============================================================================

  // Disassemble R-type instruction (register-register ALU)
  function automatic string disasm_r_type(input logic [31:0] instr);
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rd, rs1, rs2;
    string mnemonic;

    funct3 = get_funct3(instr);
    funct7 = get_funct7(instr);
    rd     = get_rd(instr);
    rs1    = get_rs1(instr);
    rs2    = get_rs2(instr);

    case (funct3)
      3'b000: mnemonic = (funct7 == 7'b0100000) ? "sub" : "add";
      3'b001: mnemonic = "sll";
      3'b010: mnemonic = "slt";
      3'b011: mnemonic = "sltu";
      3'b100: mnemonic = "xor";
      3'b101: mnemonic = (funct7 == 7'b0100000) ? "sra" : "srl";
      3'b110: mnemonic = "or";
      3'b111: mnemonic = "and";
      default: mnemonic = "unknown";
    endcase

    return $sformatf("%s %s, %s, %s", mnemonic, fmt_reg(rd), fmt_reg(rs1), fmt_reg(rs2));
  endfunction

  // Disassemble I-type ALU instruction (register-immediate ALU)
  function automatic string disasm_i_type_alu(input logic [31:0] instr);
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rd, rs1;
    logic signed [31:0] imm;
    logic [4:0] shamt;
    string mnemonic;

    funct3 = get_funct3(instr);
    funct7 = get_funct7(instr);
    rd     = get_rd(instr);
    rs1    = get_rs1(instr);
    imm    = get_imm_i(instr);
    shamt  = instr[24:20];  // Shift amount for shift instructions

    case (funct3)
      3'b000: mnemonic = "addi";
      3'b010: mnemonic = "slti";
      3'b011: mnemonic = "sltiu";
      3'b100: mnemonic = "xori";
      3'b110: mnemonic = "ori";
      3'b111: mnemonic = "andi";
      3'b001: mnemonic = "slli";
      3'b101: mnemonic = (funct7 == 7'b0100000) ? "srai" : "srli";
      default: mnemonic = "unknown";
    endcase

    // For shift instructions, use shift amount instead of full immediate
    if (funct3 == 3'b001 || funct3 == 3'b101) begin
      return $sformatf("%s %s, %s, %0d", mnemonic, fmt_reg(rd), fmt_reg(rs1), shamt);
    end else begin
      return $sformatf("%s %s, %s, %s", mnemonic, fmt_reg(rd), fmt_reg(rs1), fmt_imm(imm));
    end
  endfunction

  // Disassemble Load instruction
  function automatic string disasm_load(input logic [31:0] instr);
    logic [2:0] funct3;
    logic [4:0] rd, rs1;
    logic signed [31:0] imm;
    string mnemonic;

    funct3 = get_funct3(instr);
    rd     = get_rd(instr);
    rs1    = get_rs1(instr);
    imm    = get_imm_i(instr);

    case (funct3)
      3'b000: mnemonic = "lb";
      3'b001: mnemonic = "lh";
      3'b010: mnemonic = "lw";
      3'b100: mnemonic = "lbu";
      3'b101: mnemonic = "lhu";
      default: mnemonic = "unknown";
    endcase

    return $sformatf("%s %s, %s(%s)", mnemonic, fmt_reg(rd), fmt_imm(imm), fmt_reg(rs1));
  endfunction

  // Disassemble Store instruction
  function automatic string disasm_store(input logic [31:0] instr);
    logic [2:0] funct3;
    logic [4:0] rs1, rs2;
    logic signed [31:0] imm;
    string mnemonic;

    funct3 = get_funct3(instr);
    rs1    = get_rs1(instr);
    rs2    = get_rs2(instr);
    imm    = get_imm_s(instr);

    case (funct3)
      3'b000: mnemonic = "sb";
      3'b001: mnemonic = "sh";
      3'b010: mnemonic = "sw";
      default: mnemonic = "unknown";
    endcase

    return $sformatf("%s %s, %s(%s)", mnemonic, fmt_reg(rs2), fmt_imm(imm), fmt_reg(rs1));
  endfunction

  // Disassemble Branch instruction
  function automatic string disasm_branch(input logic [31:0] instr);
    logic [2:0] funct3;
    logic [4:0] rs1, rs2;
    logic signed [31:0] imm;
    string mnemonic;

    funct3 = get_funct3(instr);
    rs1    = get_rs1(instr);
    rs2    = get_rs2(instr);
    imm    = get_imm_b(instr);

    case (funct3)
      3'b000: mnemonic = "beq";
      3'b001: mnemonic = "bne";
      3'b100: mnemonic = "blt";
      3'b101: mnemonic = "bge";
      3'b110: mnemonic = "bltu";
      3'b111: mnemonic = "bgeu";
      default: mnemonic = "unknown";
    endcase

    return $sformatf("%s %s, %s, %s", mnemonic, fmt_reg(rs1), fmt_reg(rs2), fmt_imm(imm));
  endfunction

  // Disassemble JAL instruction
  function automatic string disasm_jal(input logic [31:0] instr);
    logic [4:0] rd;
    logic signed [31:0] imm;

    rd  = get_rd(instr);
    imm = get_imm_j(instr);

    return $sformatf("jal %s, %s", fmt_reg(rd), fmt_imm(imm));
  endfunction

  // Disassemble JALR instruction
  function automatic string disasm_jalr(input logic [31:0] instr);
    logic [4:0] rd, rs1;
    logic signed [31:0] imm;

    rd  = get_rd(instr);
    rs1 = get_rs1(instr);
    imm = get_imm_i(instr);

    return $sformatf("jalr %s, %s, %s", fmt_reg(rd), fmt_reg(rs1), fmt_imm(imm));
  endfunction

  // Disassemble LUI instruction
  function automatic string disasm_lui(input logic [31:0] instr);
    logic [4:0] rd;
    logic [31:0] imm;

    rd  = get_rd(instr);
    imm = get_imm_u(instr);

    return $sformatf("lui %s, %s", fmt_reg(rd), fmt_imm_u(imm));
  endfunction

  // Disassemble AUIPC instruction
  function automatic string disasm_auipc(input logic [31:0] instr);
    logic [4:0] rd;
    logic [31:0] imm;

    rd  = get_rd(instr);
    imm = get_imm_u(instr);

    return $sformatf("auipc %s, %s", fmt_reg(rd), fmt_imm_u(imm));
  endfunction

  // Disassemble SYSTEM instruction (ECALL, EBREAK)
  function automatic string disasm_system(input logic [31:0] instr);
    logic [2:0] funct3;
    logic [11:0] imm12;

    funct3 = get_funct3(instr);
    imm12  = instr[31:20];

    if (funct3 == 3'b000) begin
      // ECALL or EBREAK
      if (imm12 == 12'b0) begin
        return "ecall";
      end else if (imm12 == 12'b1) begin
        return "ebreak";
      end else begin
        return "unknown";
      end
    end else begin
      // CSR instructions - show as unknown for RV32I base
      return "unknown";
    end
  endfunction

  // Disassemble FENCE instruction
  function automatic string disasm_fence(input logic [31:0] instr);
    // For simplicity, just show "fence" without detailed flags
    return "fence";
  endfunction

  //============================================================================
  // Main Disassembly Function
  //============================================================================

  // Disassemble a 32-bit RISC-V instruction into a human-readable string
  function automatic string disasm(input logic [31:0] instr);
    logic [6:0] opcode;

    // Check for NOP (addi x0, x0, 0) - encoded as 0x00000013
    if (instr == 32'h00000013) begin
      return "nop";
    end

    opcode = get_opcode(instr);

    case (opcode)
      OPCODE_OP:      return disasm_r_type(instr);      // R-type ALU
      OPCODE_OP_IMM:  return disasm_i_type_alu(instr);  // I-type ALU
      OPCODE_LOAD:    return disasm_load(instr);        // Load
      OPCODE_STORE:   return disasm_store(instr);       // Store
      OPCODE_BRANCH:  return disasm_branch(instr);      // Branch
      OPCODE_JAL:     return disasm_jal(instr);         // JAL
      OPCODE_JALR:    return disasm_jalr(instr);        // JALR
      OPCODE_LUI:     return disasm_lui(instr);         // LUI
      OPCODE_AUIPC:   return disasm_auipc(instr);       // AUIPC
      OPCODE_SYSTEM:  return disasm_system(instr);      // ECALL/EBREAK
      OPCODE_FENCE:   return disasm_fence(instr);       // FENCE
      default:        return "unknown";
    endcase
  endfunction

endpackage : disasm_pkg
