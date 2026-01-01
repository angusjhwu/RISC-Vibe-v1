//==============================================================================
// RISC-Vibe RV32I Processor - 5-Stage Pipeline Top Module
//==============================================================================
// This is the top-level module for the 5-stage pipelined RISC-V processor.
// It instantiates all pipeline stages, hazard detection, forwarding unit,
// and manages the pipeline registers.
//
// Pipeline Stages:
// 1. IF  - Instruction Fetch
// 2. ID  - Instruction Decode
// 3. EX  - Execute
// 4. MEM - Memory Access
// 5. WB  - Write Back
//==============================================================================

module riscvibe_5stage_top
  import riscvibe_pkg::*;
#(
  parameter int IMEM_DEPTH     = 1024,  // Instruction memory depth in words
  parameter int DMEM_DEPTH     = 4096,  // Data memory depth in bytes
  parameter     IMEM_INIT_FILE = ""     // Instruction memory initialization file
) (
  input  logic clk,
  input  logic rst_n
);

  //============================================================================
  // Pipeline Registers
  //============================================================================
  if_id_reg_t  if_id_reg;
  id_ex_reg_t  id_ex_reg;
  ex_mem_reg_t ex_mem_reg;
  mem_wb_reg_t mem_wb_reg;

  //============================================================================
  // Stage Output Signals (Combinational)
  //============================================================================
  if_id_reg_t  if_id_out;
  id_ex_reg_t  id_ex_out;
  ex_mem_reg_t ex_mem_out;
  mem_wb_reg_t mem_wb_out;

  //============================================================================
  // Hazard Unit Signals
  //============================================================================
  logic stall_if;
  logic stall_id;
  logic flush_id;
  logic flush_ex;

  //============================================================================
  // Forwarding Unit Signals
  //============================================================================
  logic [1:0] forward_a;
  logic [1:0] forward_b;

  //============================================================================
  // Branch/Jump Signals from EX Stage
  //============================================================================
  logic        branch_taken;
  logic [31:0] branch_target;
  logic [31:0] jalr_target;
  branch_type_t branch_type_ex;

  //============================================================================
  // Writeback Stage Signals
  //============================================================================
  logic [4:0]  wb_rd_addr;
  logic [31:0] wb_rd_data;
  logic        wb_reg_write;

  //============================================================================
  // RS1/RS2 Addresses Extracted from IF/ID Register
  //============================================================================
  logic [4:0] if_id_rs1_addr;
  logic [4:0] if_id_rs2_addr;

  assign if_id_rs1_addr = if_id_reg.instruction[19:15];
  assign if_id_rs2_addr = if_id_reg.instruction[24:20];

  //============================================================================
  // IF Stage Instance
  //============================================================================
  if_stage #(
    .IMEM_DEPTH     (IMEM_DEPTH),
    .IMEM_INIT_FILE (IMEM_INIT_FILE)
  ) u_if_stage (
    .clk           (clk),
    .rst_n         (rst_n),
    .stall         (stall_if),
    .flush         (branch_taken),
    .branch_taken  (branch_taken),
    .branch_target (branch_target),
    .jalr_target   (jalr_target),
    .branch_type_ex(id_ex_reg.branch_type),
    .if_id_out     (if_id_out)
  );

  //============================================================================
  // ID Stage Instance
  //============================================================================
  id_stage u_id_stage (
    .clk          (clk),
    .rst_n        (rst_n),
    .stall        (stall_id),
    .flush        (flush_id),
    .if_id_in     (if_id_reg),
    .wb_rd_addr   (wb_rd_addr),
    .wb_rd_data   (wb_rd_data),
    .wb_reg_write (wb_reg_write),
    .id_ex_out    (id_ex_out)
  );

  //============================================================================
  // EX Stage Instance
  //============================================================================
  ex_stage u_ex_stage (
    .clk              (clk),
    .rst_n            (rst_n),
    .id_ex_in         (id_ex_reg),
    .forward_a        (forward_a),
    .forward_b        (forward_b),
    .ex_mem_alu_result(ex_mem_reg.alu_result),
    .mem_wb_rd_data   (wb_rd_data),
    .ex_mem_out       (ex_mem_out),
    .branch_taken     (branch_taken),
    .branch_target    (branch_target),
    .jalr_target      (jalr_target),
    .branch_type_out  (branch_type_ex)
  );

  //============================================================================
  // MEM Stage Instance
  //============================================================================
  mem_stage #(
    .DMEM_DEPTH (DMEM_DEPTH)
  ) u_mem_stage (
    .clk        (clk),
    .rst_n      (rst_n),
    .ex_mem_in  (ex_mem_reg),
    .mem_wb_out (mem_wb_out)
  );

  //============================================================================
  // WB Stage Instance
  //============================================================================
  wb_stage u_wb_stage (
    .mem_wb_in    (mem_wb_reg),
    .wb_rd_addr   (wb_rd_addr),
    .wb_rd_data   (wb_rd_data),
    .wb_reg_write (wb_reg_write)
  );

  //============================================================================
  // Forwarding Unit Instance
  //============================================================================
  forwarding_unit u_forwarding_unit (
    .id_ex_rs1_addr  (id_ex_reg.rs1_addr),
    .id_ex_rs2_addr  (id_ex_reg.rs2_addr),
    .ex_mem_rd_addr  (ex_mem_reg.rd_addr),
    .ex_mem_reg_write(ex_mem_reg.reg_write),
    .ex_mem_valid    (ex_mem_reg.valid),
    .mem_wb_rd_addr  (mem_wb_reg.rd_addr),
    .mem_wb_reg_write(mem_wb_reg.reg_write),
    .mem_wb_valid    (mem_wb_reg.valid),
    .forward_a       (forward_a),
    .forward_b       (forward_b)
  );

  //============================================================================
  // Hazard Unit Instance
  //============================================================================
  hazard_unit u_hazard_unit (
    .if_id_rs1_addr (if_id_rs1_addr),
    .if_id_rs2_addr (if_id_rs2_addr),
    .id_ex_rd_addr  (id_ex_reg.rd_addr),
    .id_ex_mem_read (id_ex_reg.mem_read),
    .id_ex_valid    (id_ex_reg.valid),
    .branch_taken   (branch_taken),
    .stall_if       (stall_if),
    .stall_id       (stall_id),
    .flush_id       (flush_id),
    .flush_ex       (flush_ex)
  );

  //============================================================================
  // Pipeline Register Logic
  //============================================================================

  //----------------------------------------------------------------------------
  // IF/ID Pipeline Register
  //----------------------------------------------------------------------------
  // On stall: hold current value
  // On reset: clear valid bit
  // Otherwise: load from IF stage output
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      if_id_reg.valid <= 1'b0;
      if_id_reg.instruction <= '0;
      if_id_reg.pc <= '0;
      if_id_reg.pc_plus_4 <= '0;
    end else if (stall_id) begin
      // Hold current value on stall
      if_id_reg <= if_id_reg;
    end else begin
      if_id_reg <= if_id_out;
    end
  end

  //----------------------------------------------------------------------------
  // ID/EX Pipeline Register
  //----------------------------------------------------------------------------
  // On flush: clear valid bit and control signals (insert bubble)
  // On reset: clear valid bit
  // Otherwise: load from ID stage output
  //
  // Note: ID/EX does NOT stall when stall_id is set. The stall_id signal is
  // for holding IF/ID, not ID/EX. When there's a load-use hazard:
  //   - IF/ID is held (stall_id)
  //   - ID/EX receives a bubble (flush_id) - the dependent instruction waits
  //   - EX/MEM and MEM/WB continue normally (load proceeds)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      id_ex_reg.valid <= 1'b0;
      id_ex_reg.pc <= '0;
      id_ex_reg.pc_plus_4 <= '0;
      id_ex_reg.rs1_data <= '0;
      id_ex_reg.rs2_data <= '0;
      id_ex_reg.rs1_addr <= '0;
      id_ex_reg.rs2_addr <= '0;
      id_ex_reg.rd_addr <= '0;
      id_ex_reg.immediate <= '0;
      id_ex_reg.alu_op <= ALU_ADD;
      id_ex_reg.alu_src_a <= 1'b0;
      id_ex_reg.alu_src_b <= 1'b0;
      id_ex_reg.mem_read <= 1'b0;
      id_ex_reg.mem_write <= 1'b0;
      id_ex_reg.mem_width <= '0;
      id_ex_reg.reg_write <= 1'b0;
      id_ex_reg.reg_wr_src <= REG_WR_ALU;
      id_ex_reg.branch_type <= BRANCH_NONE;
      id_ex_reg.branch_cmp <= '0;
    end else if (flush_id) begin
      // Clear valid bit on flush (insert bubble)
      // This happens for load-use hazard OR control hazard
      id_ex_reg.valid <= 1'b0;
      id_ex_reg.reg_write <= 1'b0;
      id_ex_reg.mem_read <= 1'b0;
      id_ex_reg.mem_write <= 1'b0;
      id_ex_reg.branch_type <= BRANCH_NONE;
    end else begin
      id_ex_reg <= id_ex_out;
    end
  end

  //----------------------------------------------------------------------------
  // EX/MEM Pipeline Register
  //----------------------------------------------------------------------------
  // On reset: clear valid bit
  // Otherwise: always load from EX stage output
  //
  // Note: We do NOT flush the EX/MEM register for control hazards. When a
  // branch/jump is taken in EX stage, that instruction itself needs to
  // complete (e.g., JAL/JALR need to write their link address). The flush
  // signals only affect IF/ID and ID/EX to discard the speculatively
  // fetched instructions AFTER the branch.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ex_mem_reg.valid <= 1'b0;
      ex_mem_reg.pc_plus_4 <= '0;
      ex_mem_reg.alu_result <= '0;
      ex_mem_reg.rs2_data <= '0;
      ex_mem_reg.rd_addr <= '0;
      ex_mem_reg.mem_read <= 1'b0;
      ex_mem_reg.mem_write <= 1'b0;
      ex_mem_reg.mem_width <= '0;
      ex_mem_reg.reg_write <= 1'b0;
      ex_mem_reg.reg_wr_src <= REG_WR_ALU;
    end else begin
      ex_mem_reg <= ex_mem_out;
    end
  end

  //----------------------------------------------------------------------------
  // MEM/WB Pipeline Register
  //----------------------------------------------------------------------------
  // On reset: clear valid bit
  // Otherwise: always load from MEM stage output
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_wb_reg.valid <= 1'b0;
      mem_wb_reg.pc_plus_4 <= '0;
      mem_wb_reg.alu_result <= '0;
      mem_wb_reg.mem_read_data <= '0;
      mem_wb_reg.rd_addr <= '0;
      mem_wb_reg.reg_write <= 1'b0;
      mem_wb_reg.reg_wr_src <= REG_WR_ALU;
    end else begin
      mem_wb_reg <= mem_wb_out;
    end
  end

endmodule : riscvibe_5stage_top
