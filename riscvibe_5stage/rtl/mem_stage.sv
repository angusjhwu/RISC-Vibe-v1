//==============================================================================
// RISC-Vibe RV32I Processor - Memory Access Stage (MEM)
//==============================================================================
// This module implements the Memory Access stage of the 5-stage RISC-V pipeline.
// It handles load and store operations by interfacing with the data memory.
// Memory operations only occur when the instruction is valid to prevent
// spurious writes from flushed instructions.
//==============================================================================

module mem_stage
  import riscvibe_pkg::*;
#(
  parameter int DMEM_DEPTH = 4096  // Data memory depth in bytes (default 4KB)
) (
  input  logic        clk,
  input  logic        rst_n,

  // Pipeline register input from EX/MEM
  input  ex_mem_reg_t ex_mem_in,

  // Pipeline register output to MEM/WB
  output mem_wb_reg_t mem_wb_out
);

  //============================================================================
  // Internal Signals
  //============================================================================
  logic [31:0] mem_read_data;  // Data read from memory

  //============================================================================
  // Data Memory Instance
  //============================================================================
  // Memory operations are gated by valid to prevent spurious writes from
  // flushed instructions in the pipeline.

  data_memory #(
    .DEPTH(DMEM_DEPTH)
  ) u_data_memory (
    .clk        (clk),
    .rst_n      (rst_n),
    .addr       (ex_mem_in.alu_result),
    .write_data (ex_mem_in.rs2_data),
    .mem_read   (ex_mem_in.mem_read && ex_mem_in.valid),
    .mem_write  (ex_mem_in.mem_write && ex_mem_in.valid),
    .mem_width  (ex_mem_in.mem_width),
    .read_data  (mem_read_data)
  );

  //============================================================================
  // MEM/WB Pipeline Register Output
  //============================================================================
  // Pass through control signals and data to the writeback stage

  always_comb begin
    mem_wb_out.pc_plus_4     = ex_mem_in.pc_plus_4;
    mem_wb_out.alu_result    = ex_mem_in.alu_result;
    mem_wb_out.mem_read_data = mem_read_data;
    mem_wb_out.rd_addr       = ex_mem_in.rd_addr;
    mem_wb_out.reg_write     = ex_mem_in.reg_write;
    mem_wb_out.reg_wr_src    = ex_mem_in.reg_wr_src;
    mem_wb_out.valid         = ex_mem_in.valid;
  end

endmodule : mem_stage
