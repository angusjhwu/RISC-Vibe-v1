//==============================================================================
// RISC-Vibe RV32I Processor - Program Counter Module
//==============================================================================
// This module manages the program counter (PC) register and calculates the
// next PC value based on branch/jump decisions.
//
// The PC is updated according to the following priority:
//   1. Reset: PC = RESET_VECTOR
//   2. JALR: PC = jalr_target (rs1 + imm with LSB cleared)
//   3. Branch taken (COND/JAL): PC = branch_target (PC + offset)
//   4. Normal: PC = PC + 4
//==============================================================================

module program_counter
  import riscvibe_pkg::*;
#(
  parameter logic [31:0] RESET_VECTOR = 32'h00000000  // Configurable reset vector
) (
  // Clock and reset
  input  logic        clk,
  input  logic        rst_n,

  // Branch control inputs
  input  logic        branch_taken,   // Branch condition is true
  input  branch_type_t branch_type,   // Type of branch/jump instruction
  input  logic [31:0] branch_target,  // Target for conditional branches and JAL
  input  logic [31:0] jalr_target,    // Target for JALR (rs1 + imm, LSB already cleared)

  // Program counter outputs
  output logic [31:0] pc,             // Current program counter
  output logic [31:0] pc_plus_4       // PC + 4 (for link register and sequential fetch)
);

  //============================================================================
  // Internal Signals
  //============================================================================

  logic [31:0] next_pc;  // Next PC value to be registered

  //============================================================================
  // PC + 4 Calculation
  //============================================================================
  // Calculate PC + 4 for sequential execution and link register value

  assign pc_plus_4 = pc + 32'd4;

  //============================================================================
  // Next PC Selection Logic
  //============================================================================
  // Determine the next PC based on branch type and branch_taken signal
  //
  // Priority:
  //   - JALR: Always use jalr_target (unconditional indirect jump)
  //   - JAL: Always use branch_target (unconditional direct jump)
  //   - COND: Use branch_target if branch_taken, else PC + 4
  //   - NONE: Use PC + 4 (sequential execution)

  always_comb begin
    case (branch_type)
      BRANCH_JALR: begin
        // JALR: Use jalr_target (rs1 + imm with LSB cleared)
        // The LSB clearing is done externally, but we ensure it here for safety
        next_pc = {jalr_target[31:1], 1'b0};
      end

      BRANCH_JAL: begin
        // JAL: Unconditional jump to PC + offset
        next_pc = branch_target;
      end

      BRANCH_COND: begin
        // Conditional branch: Take branch if condition is true
        next_pc = branch_taken ? branch_target : pc_plus_4;
      end

      default: begin  // BRANCH_NONE
        // Sequential execution
        next_pc = pc_plus_4;
      end
    endcase
  end

  //============================================================================
  // PC Register
  //============================================================================
  // Update PC on rising clock edge, synchronous reset to RESET_VECTOR

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc <= RESET_VECTOR;
    end else begin
      pc <= next_pc;
    end
  end

endmodule : program_counter
