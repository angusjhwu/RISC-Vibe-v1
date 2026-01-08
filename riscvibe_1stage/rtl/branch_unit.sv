//==============================================================================
// RISC-Vibe RV32I Processor - Branch Unit
//==============================================================================
// This module compares two operands and determines if a branch should be taken
// based on the branch type and comparison condition.
//==============================================================================

module branch_unit
  import riscvibe_pkg::*;
(
    // Operand inputs
    input  logic [31:0] rs1_data,     // First operand (from register file)
    input  logic [31:0] rs2_data,     // Second operand (from register file)

    // Control inputs
    input  logic [1:0]  branch_type,  // Type of branch operation
    input  logic [2:0]  branch_cmp,   // Branch comparison type (funct3)

    // Output
    output logic        branch_taken  // 1 if branch should be taken
);

  //============================================================================
  // Internal Signals
  //============================================================================

  logic cmp_result;  // Result of the comparison operation

  //============================================================================
  // Branch Comparison Logic
  //============================================================================
  // Evaluate the comparison based on funct3 encoding

  always_comb begin
    case (branch_cmp)
      BRANCH_BEQ:  cmp_result = (rs1_data == rs2_data);
      BRANCH_BNE:  cmp_result = (rs1_data != rs2_data);
      BRANCH_BLT:  cmp_result = ($signed(rs1_data) < $signed(rs2_data));
      BRANCH_BGE:  cmp_result = ($signed(rs1_data) >= $signed(rs2_data));
      BRANCH_BLTU: cmp_result = (rs1_data < rs2_data);
      BRANCH_BGEU: cmp_result = (rs1_data >= rs2_data);
      default:     cmp_result = 1'b0;
    endcase
  end

  //============================================================================
  // Branch Taken Logic
  //============================================================================
  // Determine if branch should be taken based on branch type

  always_comb begin
    case (branch_type)
      BRANCH_NONE: branch_taken = 1'b0;        // Never taken
      BRANCH_COND: branch_taken = cmp_result;  // Taken if comparison is true
      BRANCH_JAL:  branch_taken = 1'b1;        // Always taken
      BRANCH_JALR: branch_taken = 1'b1;        // Always taken
      default:     branch_taken = 1'b0;
    endcase
  end

endmodule : branch_unit
