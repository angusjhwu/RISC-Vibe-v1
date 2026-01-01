//==============================================================================
// RISC-Vibe RV32I Processor - Instruction Fetch (IF) Stage
//==============================================================================
// This module implements the Instruction Fetch stage of a 5-stage RISC-V
// pipeline. It manages the Program Counter, fetches instructions from
// instruction memory, and outputs data to the IF/ID pipeline register.
//
// Features:
// - PC register with reset to 0
// - PC+4 calculation for sequential execution
// - Next PC mux supporting sequential, branch, and JALR targets
// - Stall support from hazard detection unit
// - Flush support for branch misprediction
// - Combinational instruction memory read
//==============================================================================

module if_stage
  import riscvibe_pkg::*;
#(
  parameter int IMEM_DEPTH     = 1024,  // Instruction memory depth (words)
  parameter     IMEM_INIT_FILE = ""     // Instruction memory initialization file
) (
  // Clock and reset
  input  logic        clk,
  input  logic        rst_n,

  // Hazard unit interface
  input  logic        stall,          // Stall IF stage (hold PC and IF/ID)
  input  logic        flush,          // Flush fetched instruction (invalidate)

  // Branch/Jump interface from EX stage
  input  logic        branch_taken,   // Branch or jump is taken
  input  logic [31:0] branch_target,  // Target address for branches and JAL
  input  logic [31:0] jalr_target,    // Target address for JALR (indirect jump)
  input  branch_type_t branch_type_ex, // Branch type from EX stage

  // Output to IF/ID pipeline register
  output if_id_reg_t  if_id_out
);

  //============================================================================
  // Local Parameters
  //============================================================================
  // NOP instruction (ADDI x0, x0, 0) for initialization and invalid fetches
  localparam logic [31:0] NOP_INSTRUCTION = 32'h0000_0013;

  //============================================================================
  // Internal Signals
  //============================================================================
  logic [31:0] pc_reg;        // Current program counter
  logic [31:0] pc_plus_4;     // PC + 4 (next sequential address)
  logic [31:0] next_pc;       // Next PC value (mux output)
  logic [31:0] instruction;   // Fetched instruction from memory

  //============================================================================
  // Instruction Memory Instance (Combinational Read)
  //============================================================================
  // Memory array
  logic [31:0] imem [0:IMEM_DEPTH-1];

  // Word address calculation (convert byte address to word index)
  logic [31:0] word_addr;
  assign word_addr = pc_reg[31:2];

  // Memory initialization
  initial begin
    // Initialize all memory to NOP instructions
    for (int i = 0; i < IMEM_DEPTH; i++) begin
      imem[i] = NOP_INSTRUCTION;
    end
    // Load program from file if specified
    if (IMEM_INIT_FILE != "") begin
      $readmemh(IMEM_INIT_FILE, imem);
    end
  end

  // Combinational read (asynchronous memory access)
  always_comb begin
    if (word_addr < IMEM_DEPTH) begin
      instruction = imem[word_addr];
    end else begin
      // Return NOP for out-of-bounds access
      instruction = NOP_INSTRUCTION;
    end
  end

  //============================================================================
  // PC + 4 Calculation
  //============================================================================
  assign pc_plus_4 = pc_reg + 32'd4;

  //============================================================================
  // Next PC Mux
  //============================================================================
  // Priority:
  // 1. If branch_taken and JALR: use jalr_target
  // 2. If branch_taken (JAL or conditional): use branch_target
  // 3. Otherwise: use pc_plus_4 (sequential)
  always_comb begin
    if (branch_taken) begin
      if (branch_type_ex == BRANCH_JALR) begin
        next_pc = jalr_target;
      end else begin
        next_pc = branch_target;
      end
    end else begin
      next_pc = pc_plus_4;
    end
  end

  //============================================================================
  // PC Register
  //============================================================================
  // Update PC on clock edge unless stalled
  // On reset, PC starts at 0
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_reg <= 32'h0000_0000;
    end else if (!stall) begin
      pc_reg <= next_pc;
    end
    // If stalled, PC holds its current value (implicit)
  end

  //============================================================================
  // IF/ID Output Register Logic
  //============================================================================
  // The IF/ID pipeline register is external to this module
  // This module provides the values to be captured in that register
  //
  // Valid is cleared (instruction invalidated) when:
  // - flush is asserted (branch misprediction)
  // - branch_taken is asserted (control hazard - instruction at old PC invalid)
  //
  // When stalled, the external IF/ID register should hold its value
  // (controlled by the stall signal at the register level)
  always_comb begin
    if_id_out.instruction = instruction;
    if_id_out.pc          = pc_reg;
    if_id_out.pc_plus_4   = pc_plus_4;
    // Invalidate instruction on flush or when branch is taken
    if_id_out.valid       = !(flush || branch_taken);
  end

endmodule : if_stage
