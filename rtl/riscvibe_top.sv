//==============================================================================
// RISC-Vibe RV32I Processor - Top-Level Module
//==============================================================================
// This is the top-level module for the RISC-Vibe RV32I processor.
// It instantiates and connects all submodules to form a complete single-cycle
// processor implementation.
//
// Architecture Overview:
//   - Instruction Fetch: PC -> Instruction Memory -> Instruction
//   - Decode: Extract opcode, funct3, funct7, rs1, rs2, rd from instruction
//   - Execute: ALU operations based on control signals
//   - Memory: Data memory for load/store operations
//   - Writeback: Select and write result back to register file
//==============================================================================

module riscvibe_top
  import riscvibe_pkg::*;
#(
  parameter int    IMEM_DEPTH     = 1024,  // Instruction memory depth (words)
  parameter int    DMEM_DEPTH     = 4096,  // Data memory depth (bytes)
  parameter string IMEM_INIT_FILE = ""     // Instruction memory initialization file
) (
  input  logic clk,    // Clock signal
  input  logic rst_n   // Active-low reset
);

  //============================================================================
  // Internal Signals - Instruction Fetch Stage
  //============================================================================
  logic [31:0] pc;              // Current program counter
  logic [31:0] pc_plus_4;       // PC + 4 for sequential execution
  logic [31:0] instruction;    // Fetched instruction

  //============================================================================
  // Internal Signals - Instruction Decode Stage
  //============================================================================
  // Instruction field extraction
  logic [6:0]  opcode;
  logic [4:0]  rd;
  logic [2:0]  funct3;
  logic [4:0]  rs1;
  logic [4:0]  rs2;
  logic [6:0]  funct7;

  // Register file signals
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;
  logic [31:0] rd_data;

  // Immediate value
  logic [31:0] immediate;

  //============================================================================
  // Internal Signals - Control Signals
  //============================================================================
  alu_op_t      alu_op;
  logic         alu_src_a;      // 0=rs1, 1=PC
  logic         alu_src_b;      // 0=rs2, 1=immediate
  logic         reg_write;
  reg_wr_src_t  reg_wr_src;
  logic         mem_read;
  logic         mem_write;
  logic [2:0]   mem_width;
  branch_type_t branch_type;
  logic [2:0]   branch_cmp;

  //============================================================================
  // Internal Signals - Execute Stage
  //============================================================================
  logic [31:0] alu_operand_a;
  logic [31:0] alu_operand_b;
  logic [31:0] alu_result;
  logic        alu_zero;

  //============================================================================
  // Internal Signals - Memory Stage
  //============================================================================
  logic [31:0] mem_read_data;

  //============================================================================
  // Internal Signals - Branch/Jump
  //============================================================================
  logic        branch_taken;
  logic [31:0] branch_target;
  logic [31:0] jalr_target;

  //============================================================================
  // Internal Signals - Write-back Pipeline Registers
  //============================================================================
  // These registers ensure write-back data is stable during the clock edge
  // by delaying the write by one cycle relative to instruction fetch
  logic [4:0]  rd_wb;           // Registered destination register address
  logic [31:0] rd_data_wb;      // Registered write data
  logic        reg_write_wb;    // Registered write enable

  //============================================================================
  // Instruction Field Extraction
  //============================================================================
  assign opcode = instruction[6:0];
  assign rd     = instruction[11:7];
  assign funct3 = instruction[14:12];
  assign rs1    = instruction[19:15];
  assign rs2    = instruction[24:20];
  assign funct7 = instruction[31:25];

  //============================================================================
  // Branch Target Calculation
  //============================================================================
  // branch_target = PC + immediate (for JAL, conditional branches)
  // jalr_target = rs1_data + immediate (for JALR) with LSB cleared
  assign branch_target = pc + immediate;
  assign jalr_target   = (rs1_data + immediate) & 32'hFFFFFFFE;  // Clear LSB

  //============================================================================
  // ALU Input Multiplexers
  //============================================================================
  // Select ALU operand A: 0=rs1, 1=PC
  assign alu_operand_a = alu_src_a ? pc : rs1_data;

  // Select ALU operand B: 0=rs2, 1=immediate
  assign alu_operand_b = alu_src_b ? immediate : rs2_data;

  //============================================================================
  // Register Write Data Selection
  //============================================================================
  always_comb begin
    case (reg_wr_src)
      REG_WR_ALU: rd_data = alu_result;
      REG_WR_MEM: rd_data = mem_read_data;
      REG_WR_PC4: rd_data = pc_plus_4;
      REG_WR_IMM: rd_data = immediate;
      default:    rd_data = alu_result;
    endcase
  end

  //============================================================================
  // Write-back Pipeline Registers
  //============================================================================
  // Register the write-back signals to ensure they're stable at clock edge
  // This adds a one-cycle latency to writes but fixes the timing issue
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_wb        <= 5'b0;
      rd_data_wb   <= 32'b0;
      reg_write_wb <= 1'b0;
    end else begin
      rd_wb        <= rd;
      rd_data_wb   <= rd_data;
      reg_write_wb <= reg_write;
    end
  end

  //============================================================================
  // Module Instantiations
  //============================================================================

  //----------------------------------------------------------------------------
  // Program Counter
  //----------------------------------------------------------------------------
  program_counter u_program_counter (
    .clk           (clk),
    .rst_n         (rst_n),
    .branch_taken  (branch_taken),
    .branch_type   (branch_type),
    .branch_target (branch_target),
    .jalr_target   (jalr_target),
    .pc            (pc),
    .pc_plus_4     (pc_plus_4)
  );

  //----------------------------------------------------------------------------
  // Instruction Memory
  //----------------------------------------------------------------------------
  instruction_mem #(
    .DEPTH     (IMEM_DEPTH),
    .INIT_FILE (IMEM_INIT_FILE)
  ) u_instruction_mem (
    .clk         (clk),
    .addr        (pc),
    .instruction (instruction)
  );

  //----------------------------------------------------------------------------
  // Register File
  //----------------------------------------------------------------------------
  // Raw register file outputs (before forwarding)
  logic [31:0] rs1_data_raw;
  logic [31:0] rs2_data_raw;

  register_file u_register_file (
    .clk       (clk),
    .rst_n     (rst_n),
    .rs1_addr  (rs1),
    .rs1_data  (rs1_data_raw),
    .rs2_addr  (rs2),
    .rs2_data  (rs2_data_raw),
    .rd_addr   (rd_wb),         // Use pipelined write address
    .rd_data   (rd_data_wb),    // Use pipelined write data
    .reg_write (reg_write_wb)   // Use pipelined write enable
  );

  //----------------------------------------------------------------------------
  // Forwarding Logic
  //----------------------------------------------------------------------------
  // Forward data from write-back stage if there's a RAW hazard
  // A hazard exists when:
  //   1. Write-back is enabled (reg_write_wb == 1)
  //   2. Write-back destination matches read source (rd_wb == rs1 or rs2)
  //   3. Destination is not x0 (rd_wb != 0)

  // Forward for rs1
  assign rs1_data = (reg_write_wb && (rd_wb != 5'b0) && (rd_wb == rs1))
                    ? rd_data_wb
                    : rs1_data_raw;

  // Forward for rs2
  assign rs2_data = (reg_write_wb && (rd_wb != 5'b0) && (rd_wb == rs2))
                    ? rd_data_wb
                    : rs2_data_raw;

  //----------------------------------------------------------------------------
  // Immediate Generator
  //----------------------------------------------------------------------------
  immediate_gen u_immediate_gen (
    .instruction (instruction),
    .immediate   (immediate)
  );

  //----------------------------------------------------------------------------
  // Control Unit
  //----------------------------------------------------------------------------
  control_unit u_control_unit (
    .opcode      (opcode),
    .funct3      (funct3),
    .funct7      (funct7),
    .alu_op      (alu_op),
    .alu_src_a   (alu_src_a),
    .alu_src_b   (alu_src_b),
    .reg_write   (reg_write),
    .reg_wr_src  (reg_wr_src),
    .mem_read    (mem_read),
    .mem_write   (mem_write),
    .mem_width   (mem_width),
    .branch_type (branch_type),
    .branch_cmp  (branch_cmp)
  );

  //----------------------------------------------------------------------------
  // ALU
  //----------------------------------------------------------------------------
  alu u_alu (
    .operand_a (alu_operand_a),
    .operand_b (alu_operand_b),
    .alu_op    (alu_op),
    .result    (alu_result),
    .zero      (alu_zero)
  );

  //----------------------------------------------------------------------------
  // Branch Unit
  //----------------------------------------------------------------------------
  branch_unit u_branch_unit (
    .rs1_data     (rs1_data),
    .rs2_data     (rs2_data),
    .branch_type  (branch_type),
    .branch_cmp   (branch_cmp),
    .branch_taken (branch_taken)
  );

  //----------------------------------------------------------------------------
  // Data Memory
  //----------------------------------------------------------------------------
  data_memory #(
    .DEPTH (DMEM_DEPTH)
  ) u_data_memory (
    .clk        (clk),
    .rst_n      (rst_n),
    .addr       (alu_result),
    .write_data (rs2_data),
    .mem_read   (mem_read),
    .mem_write  (mem_write),
    .mem_width  (mem_width),
    .read_data  (mem_read_data)
  );

endmodule : riscvibe_top
