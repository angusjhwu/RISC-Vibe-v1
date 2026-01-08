//==============================================================================
// RISC-Vibe RV32I Processor - Control Unit
//==============================================================================
// This module decodes the instruction opcode and function fields to generate
// all control signals for the datapath. It supports the full RV32I base ISA.
//==============================================================================

module control_unit
  import riscvibe_pkg::*;
(
  // Instruction fields
  input  logic [6:0] opcode,    // Instruction opcode
  input  logic [2:0] funct3,    // Function field 3
  input  logic [6:0] funct7,    // Function field 7

  // ALU control signals
  output alu_op_t    alu_op,    // ALU operation selector
  output logic       alu_src_a, // ALU source A: 0=rs1, 1=PC
  output logic       alu_src_b, // ALU source B: 0=rs2, 1=immediate

  // Register file control signals
  output logic       reg_write,  // Register write enable
  output reg_wr_src_t reg_wr_src, // Register write source

  // Memory control signals
  output logic       mem_read,   // Memory read enable
  output logic       mem_write,  // Memory write enable
  output logic [2:0] mem_width,  // Memory access width (funct3)

  // Branch control signals
  output branch_type_t branch_type, // Branch type
  output logic [2:0]   branch_cmp   // Branch comparison type (funct3)
);

  //============================================================================
  // ALU Operation Decoder
  //============================================================================
  // Determines the ALU operation based on opcode, funct3, and funct7[5]

  function automatic alu_op_t decode_alu_op(
    input logic [6:0] op,
    input logic [2:0] f3,
    input logic       f7_bit5,
    input logic       is_imm
  );
    alu_op_t result;

    case (f3)
      FUNCT3_ADD_SUB: begin
        // For R-type: ADD if funct7[5]=0, SUB if funct7[5]=1
        // For I-type: Always ADD (no SUBI instruction in RV32I)
        if (!is_imm && f7_bit5)
          result = ALU_SUB;
        else
          result = ALU_ADD;
      end
      FUNCT3_SLL:     result = ALU_SLL;
      FUNCT3_SLT:     result = ALU_SLT;
      FUNCT3_SLTU:    result = ALU_SLTU;
      FUNCT3_XOR:     result = ALU_XOR;
      FUNCT3_SRL_SRA: begin
        // SRL if funct7[5]=0, SRA if funct7[5]=1
        if (f7_bit5)
          result = ALU_SRA;
        else
          result = ALU_SRL;
      end
      FUNCT3_OR:      result = ALU_OR;
      FUNCT3_AND:     result = ALU_AND;
      default:        result = ALU_ADD;
    endcase

    return result;
  endfunction

  //============================================================================
  // Main Control Logic
  //============================================================================

  always_comb begin
    // Default values - safe defaults for unknown instructions
    alu_op      = ALU_ADD;
    alu_src_a   = 1'b0;        // Default: rs1
    alu_src_b   = 1'b0;        // Default: rs2
    reg_write   = 1'b0;
    reg_wr_src  = REG_WR_ALU;
    mem_read    = 1'b0;
    mem_write   = 1'b0;
    mem_width   = funct3;      // Pass through funct3 for load/store width
    branch_type = BRANCH_NONE;
    branch_cmp  = funct3;      // Pass through funct3 for branch comparison

    case (opcode)
      //------------------------------------------------------------------------
      // OP (R-type): Register-register ALU operations
      //------------------------------------------------------------------------
      OPCODE_OP: begin
        alu_op    = decode_alu_op(opcode, funct3, funct7[5], 1'b0);
        alu_src_a = 1'b0;      // rs1
        alu_src_b = 1'b0;      // rs2
        reg_write = 1'b1;
        reg_wr_src = REG_WR_ALU;
      end

      //------------------------------------------------------------------------
      // OP-IMM (I-type): Register-immediate ALU operations
      //------------------------------------------------------------------------
      OPCODE_OP_IMM: begin
        alu_op    = decode_alu_op(opcode, funct3, funct7[5], 1'b1);
        alu_src_a = 1'b0;      // rs1
        alu_src_b = 1'b1;      // immediate
        reg_write = 1'b1;
        reg_wr_src = REG_WR_ALU;
      end

      //------------------------------------------------------------------------
      // LOAD (I-type): Load from memory
      //------------------------------------------------------------------------
      OPCODE_LOAD: begin
        alu_op    = ALU_ADD;   // Address calculation: rs1 + imm
        alu_src_a = 1'b0;      // rs1
        alu_src_b = 1'b1;      // immediate
        reg_write = 1'b1;
        reg_wr_src = REG_WR_MEM;
        mem_read  = 1'b1;
        // mem_width set from funct3
      end

      //------------------------------------------------------------------------
      // STORE (S-type): Store to memory
      //------------------------------------------------------------------------
      OPCODE_STORE: begin
        alu_op    = ALU_ADD;   // Address calculation: rs1 + imm
        alu_src_a = 1'b0;      // rs1
        alu_src_b = 1'b1;      // immediate
        mem_write = 1'b1;
        // mem_width set from funct3
      end

      //------------------------------------------------------------------------
      // BRANCH (B-type): Conditional branches
      //------------------------------------------------------------------------
      OPCODE_BRANCH: begin
        alu_op      = ALU_SUB; // For comparison
        alu_src_a   = 1'b0;    // rs1
        alu_src_b   = 1'b0;    // rs2 (compare rs1 and rs2)
        branch_type = BRANCH_COND;
        // branch_cmp set from funct3
      end

      //------------------------------------------------------------------------
      // JAL (J-type): Jump and link
      //------------------------------------------------------------------------
      OPCODE_JAL: begin
        reg_write   = 1'b1;
        reg_wr_src  = REG_WR_PC4; // Save return address (PC+4)
        branch_type = BRANCH_JAL;
      end

      //------------------------------------------------------------------------
      // JALR (I-type): Jump and link register
      //------------------------------------------------------------------------
      OPCODE_JALR: begin
        alu_op      = ALU_ADD; // Target: rs1 + imm
        alu_src_a   = 1'b0;    // rs1
        alu_src_b   = 1'b1;    // immediate
        reg_write   = 1'b1;
        reg_wr_src  = REG_WR_PC4; // Save return address (PC+4)
        branch_type = BRANCH_JALR;
      end

      //------------------------------------------------------------------------
      // LUI (U-type): Load upper immediate
      //------------------------------------------------------------------------
      OPCODE_LUI: begin
        reg_write  = 1'b1;
        reg_wr_src = REG_WR_IMM; // Write immediate value directly
      end

      //------------------------------------------------------------------------
      // AUIPC (U-type): Add upper immediate to PC
      //------------------------------------------------------------------------
      OPCODE_AUIPC: begin
        alu_op    = ALU_ADD;   // PC + imm
        alu_src_a = 1'b1;      // PC
        alu_src_b = 1'b1;      // immediate
        reg_write = 1'b1;
        reg_wr_src = REG_WR_ALU;
      end

      //------------------------------------------------------------------------
      // FENCE: Memory ordering (treat as NOP for basic implementation)
      //------------------------------------------------------------------------
      OPCODE_FENCE: begin
        // No operation in basic implementation
        // In a more complex implementation, this would control memory ordering
      end

      //------------------------------------------------------------------------
      // SYSTEM: ECALL, EBREAK, CSR instructions
      //------------------------------------------------------------------------
      OPCODE_SYSTEM: begin
        // Basic implementation treats as NOP
        // Full implementation would handle CSR access and exceptions
      end

      //------------------------------------------------------------------------
      // Default: Unknown opcode (treat as NOP)
      //------------------------------------------------------------------------
      default: begin
        // All signals remain at safe default values
      end
    endcase
  end

endmodule : control_unit
