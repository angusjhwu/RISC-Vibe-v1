//==============================================================================
// RISC-Vibe RV32I Processor - Instruction Decode Stage (ID)
//==============================================================================
// This module implements the Instruction Decode stage of the 5-stage pipeline.
// It decodes instructions, reads the register file, generates immediates,
// and produces control signals for downstream stages.
//==============================================================================

module id_stage
  import riscvibe_pkg::*;
(
  //--------------------------------------------------------------------------
  // Clock and Reset
  //--------------------------------------------------------------------------
  input  logic        clk,
  input  logic        rst_n,

  //--------------------------------------------------------------------------
  // Pipeline Control (from Hazard Unit)
  //--------------------------------------------------------------------------
  input  logic        stall,      // Stall this stage (insert bubble)
  input  logic        flush,      // Flush this stage (insert bubble)

  //--------------------------------------------------------------------------
  // Input from IF/ID Pipeline Register
  //--------------------------------------------------------------------------
  input  if_id_reg_t  if_id_in,

  //--------------------------------------------------------------------------
  // Writeback Interface (from WB Stage)
  //--------------------------------------------------------------------------
  input  logic [4:0]  wb_rd_addr,   // Destination register address
  input  logic [31:0] wb_rd_data,   // Data to write
  input  logic        wb_reg_write, // Write enable

  //--------------------------------------------------------------------------
  // Output to ID/EX Pipeline Register
  //--------------------------------------------------------------------------
  output id_ex_reg_t  id_ex_out
);

  //--------------------------------------------------------------------------
  // Instruction Field Extraction
  //--------------------------------------------------------------------------
  logic [6:0]  opcode;
  logic [4:0]  rd_addr;
  logic [2:0]  funct3;
  logic [4:0]  rs1_addr;
  logic [4:0]  rs2_addr;
  logic [6:0]  funct7;

  assign opcode   = if_id_in.instruction[6:0];
  assign rd_addr  = if_id_in.instruction[11:7];
  assign funct3   = if_id_in.instruction[14:12];
  assign rs1_addr = if_id_in.instruction[19:15];
  assign rs2_addr = if_id_in.instruction[24:20];
  assign funct7   = if_id_in.instruction[31:25];

  //--------------------------------------------------------------------------
  // Control Unit Signals
  //--------------------------------------------------------------------------
  alu_op_t      ctrl_alu_op;
  logic         ctrl_alu_src_a;
  logic         ctrl_alu_src_b;
  logic         ctrl_reg_write;
  reg_wr_src_t  ctrl_reg_wr_src;
  logic         ctrl_mem_read;
  logic         ctrl_mem_write;
  logic [2:0]   ctrl_mem_width;
  branch_type_t ctrl_branch_type;
  logic [2:0]   ctrl_branch_cmp;

  //--------------------------------------------------------------------------
  // Control Unit Instance
  //--------------------------------------------------------------------------
  control_unit u_control_unit (
    .opcode      (opcode),
    .funct3      (funct3),
    .funct7      (funct7),
    .alu_op      (ctrl_alu_op),
    .alu_src_a   (ctrl_alu_src_a),
    .alu_src_b   (ctrl_alu_src_b),
    .reg_write   (ctrl_reg_write),
    .reg_wr_src  (ctrl_reg_wr_src),
    .mem_read    (ctrl_mem_read),
    .mem_write   (ctrl_mem_write),
    .mem_width   (ctrl_mem_width),
    .branch_type (ctrl_branch_type),
    .branch_cmp  (ctrl_branch_cmp)
  );

  //--------------------------------------------------------------------------
  // Register File Signals
  //--------------------------------------------------------------------------
  logic [31:0] rs1_data_raw;
  logic [31:0] rs2_data_raw;
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;

  //--------------------------------------------------------------------------
  // Register File Instance
  // - Two combinational read ports for rs1 and rs2
  // - One synchronous write port driven by WB stage
  //--------------------------------------------------------------------------
  register_file u_register_file (
    .clk       (clk),
    .rst_n     (rst_n),
    .rs1_addr  (rs1_addr),
    .rs1_data  (rs1_data_raw),
    .rs2_addr  (rs2_addr),
    .rs2_data  (rs2_data_raw),
    .rd_addr   (wb_rd_addr),
    .rd_data   (wb_rd_data),
    .reg_write (wb_reg_write)
  );

  //--------------------------------------------------------------------------
  // WB-to-ID Forwarding (Register File Bypass)
  // Handle the case where WB is writing a register that ID is reading
  // Since register file write is synchronous, we need to bypass the value
  //--------------------------------------------------------------------------
  always_comb begin
    // Forward rs1 from WB if there's a match
    if (wb_reg_write && (wb_rd_addr != 5'b0) && (wb_rd_addr == rs1_addr)) begin
      rs1_data = wb_rd_data;
    end else begin
      rs1_data = rs1_data_raw;
    end

    // Forward rs2 from WB if there's a match
    if (wb_reg_write && (wb_rd_addr != 5'b0) && (wb_rd_addr == rs2_addr)) begin
      rs2_data = wb_rd_data;
    end else begin
      rs2_data = rs2_data_raw;
    end
  end

  //--------------------------------------------------------------------------
  // Immediate Generator Signals
  //--------------------------------------------------------------------------
  logic [31:0] immediate;

  //--------------------------------------------------------------------------
  // Immediate Generator Instance
  //--------------------------------------------------------------------------
  immediate_gen u_immediate_gen (
    .instruction (if_id_in.instruction),
    .immediate   (immediate)
  );

  //--------------------------------------------------------------------------
  // Output Logic
  // On stall or flush, insert a bubble (NOP) by clearing control signals
  //--------------------------------------------------------------------------
  always_comb begin
    // Default: pass through all decoded signals
    id_ex_out.pc          = if_id_in.pc;
    id_ex_out.pc_plus_4   = if_id_in.pc_plus_4;
    id_ex_out.rs1_data    = rs1_data;
    id_ex_out.rs2_data    = rs2_data;
    id_ex_out.rs1_addr    = rs1_addr;
    id_ex_out.rs2_addr    = rs2_addr;
    id_ex_out.rd_addr     = rd_addr;
    id_ex_out.immediate   = immediate;
    id_ex_out.alu_op      = ctrl_alu_op;
    id_ex_out.alu_src_a   = ctrl_alu_src_a;
    id_ex_out.alu_src_b   = ctrl_alu_src_b;
    id_ex_out.mem_read    = ctrl_mem_read;
    id_ex_out.mem_write   = ctrl_mem_write;
    id_ex_out.mem_width   = ctrl_mem_width;
    id_ex_out.reg_write   = ctrl_reg_write;
    id_ex_out.reg_wr_src  = ctrl_reg_wr_src;
    id_ex_out.branch_type = ctrl_branch_type;
    id_ex_out.branch_cmp  = ctrl_branch_cmp;
    id_ex_out.valid       = if_id_in.valid;

    // Insert bubble on stall or flush
    // Clear all control signals that could modify state
    if (stall || flush) begin
      id_ex_out.reg_write   = 1'b0;
      id_ex_out.mem_read    = 1'b0;
      id_ex_out.mem_write   = 1'b0;
      id_ex_out.branch_type = BRANCH_NONE;
      id_ex_out.valid       = 1'b0;
    end
  end

endmodule : id_stage
