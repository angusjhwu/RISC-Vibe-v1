// =============================================================================
// RiscVibe ALU - Arithmetic Logic Unit for RV32I
// =============================================================================
// This module implements the ALU for the RiscVibe RV32I processor.
// It supports all integer computational operations defined in the base
// RV32I instruction set.
//
// Operation encoding follows {funct7[5], funct3} for R-type instructions,
// allowing direct mapping from instruction decode to ALU operation selection.
// =============================================================================

module alu
  import riscvibe_pkg::*;
(
    // Operand inputs
    input  logic [31:0] operand_a,  // First operand (from rs1)
    input  logic [31:0] operand_b,  // Second operand (from rs2 or immediate)

    // Operation selector
    input  logic [3:0]  alu_op,     // ALU operation code

    // Result outputs
    output logic [31:0] result,     // Operation result
    output logic        zero        // Zero flag (result == 0)
);

    // -------------------------------------------------------------------------
    // Shift amount extraction
    // -------------------------------------------------------------------------
    // For RV32I, only the lower 5 bits of operand_b specify the shift amount
    logic [4:0] shamt;
    assign shamt = operand_b[4:0];

    // -------------------------------------------------------------------------
    // Signed operands for comparison operations
    // -------------------------------------------------------------------------
    // Cast operands to signed for SLT operation
    logic signed [31:0] operand_a_signed;
    logic signed [31:0] operand_b_signed;

    assign operand_a_signed = $signed(operand_a);
    assign operand_b_signed = $signed(operand_b);

    // -------------------------------------------------------------------------
    // ALU operation selection
    // -------------------------------------------------------------------------
    always_comb begin
        // Default result to prevent latches
        result = 32'h0;

        case (alu_op)
            // Arithmetic operations
            ALU_ADD:  result = operand_a + operand_b;
            ALU_SUB:  result = operand_a - operand_b;

            // Shift operations
            ALU_SLL:  result = operand_a << shamt;
            ALU_SRL:  result = operand_a >> shamt;
            ALU_SRA:  result = $unsigned(operand_a_signed >>> shamt);

            // Comparison operations (set-less-than)
            ALU_SLT:  result = {31'b0, (operand_a_signed < operand_b_signed)};
            ALU_SLTU: result = {31'b0, (operand_a < operand_b)};

            // Logical operations
            ALU_XOR:  result = operand_a ^ operand_b;
            ALU_OR:   result = operand_a | operand_b;
            ALU_AND:  result = operand_a & operand_b;

            // Default case for undefined operations
            default:  result = 32'h0;
        endcase
    end

    // -------------------------------------------------------------------------
    // Zero flag generation
    // -------------------------------------------------------------------------
    // Used for branch comparison (BEQ, BNE)
    assign zero = (result == 32'h0);

endmodule : alu
