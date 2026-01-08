//==============================================================================
// RISC-Vibe Single-Stage Processor - Trace Logger Module
//==============================================================================
// This module generates JSON Lines (.jsonl) trace output capturing full
// processor state each cycle for visualization and debugging purposes.
//
// Output format: One JSON object per line containing:
//   - Cycle count
//   - Single CPU stage state (all operations in one cycle)
//   - Register file contents
//   - Forwarding signals
//==============================================================================

module trace_logger_1stage
  import riscvibe_pkg::*;
#(
  parameter string TRACE_FILE = "trace.jsonl"
) (
  // Clock and control
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // Cycle count
  input  logic [31:0] cycle_count,

  // Processor state
  input  logic [31:0] pc,
  input  logic [31:0] instruction,
  input  logic [4:0]  rd,
  input  logic [4:0]  rs1,
  input  logic [4:0]  rs2,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  input  logic [31:0] alu_result,
  input  logic [31:0] rd_data,
  input  logic        reg_write,
  input  logic        mem_read,
  input  logic        mem_write,
  input  logic        branch_taken,

  // Forwarding signals
  input  logic        fwd_rs1,
  input  logic        fwd_rs2,

  // Register file values (32 x 32-bit)
  input  logic [31:0] reg_file [32]
);

  //============================================================================
  // File Handle
  //============================================================================
  integer trace_fd;
  logic   file_opened;

  //============================================================================
  // Formatting Functions
  //============================================================================

  // Convert 32-bit value to 8-digit lowercase hex string with 0x prefix
  // Handles undefined (x) values by treating them as 0
  function automatic string hex32(input logic [31:0] val);
    logic [31:0] safe_val;
    safe_val = val;
    for (int i = 0; i < 32; i++) begin
      if (val[i] === 1'bx || val[i] === 1'bz) begin
        safe_val[i] = 1'b0;
      end
    end
    return $sformatf("0x%08x", safe_val);
  endfunction

  // Convert boolean to JSON boolean string
  function automatic string bool_str(input logic val);
    if (val === 1'b1) return "true";
    else return "false";
  endfunction

  // Convert forward select to string
  function automatic string forward_str(input logic fwd);
    if (fwd === 1'b1) return "WB";
    else return "NONE";
  endfunction

  // Build register file JSON array
  function automatic string build_reg_array();
    string result;
    result = "[";
    for (int i = 0; i < 32; i++) begin
      if (i == 0) begin
        result = {result, "\"0x00000000\""};
      end else begin
        result = {result, "\"", hex32(reg_file[i]), "\""};
      end
      if (i < 31) result = {result, ","};
    end
    result = {result, "]"};
    return result;
  endfunction

  //============================================================================
  // File Open on First Enable After Reset
  //============================================================================
  initial begin
    file_opened = 1'b0;
    trace_fd = 0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      if (file_opened && trace_fd != 0) begin
        $fclose(trace_fd);
      end
      file_opened <= 1'b0;
      trace_fd <= 0;
    end else if (enable && !file_opened) begin
      trace_fd = $fopen(TRACE_FILE, "w");
      if (trace_fd == 0) begin
        $display("ERROR: trace_logger could not open file: %s", TRACE_FILE);
      end else begin
        $display("trace_logger: Opened trace file: %s", TRACE_FILE);
        file_opened <= 1'b1;
      end
    end
  end

  //============================================================================
  // Trace Logging - Write JSON Line Each Cycle
  //============================================================================
  always_ff @(posedge clk) begin
    if (rst_n && enable && file_opened && trace_fd != 0) begin
      // Build and write JSON line
      $fwrite(trace_fd, "{");

      // Cycle count
      $fwrite(trace_fd, "\"cycle\":%0d,", cycle_count);

      // CPU Stage (single stage - all operations happen here)
      $fwrite(trace_fd, "\"cpu\":{");
      $fwrite(trace_fd, "\"pc\":\"%s\",", hex32(pc));
      $fwrite(trace_fd, "\"instr\":\"%s\",", hex32(instruction));
      $fwrite(trace_fd, "\"rd\":%0d,", rd);
      $fwrite(trace_fd, "\"rs1\":%0d,", rs1);
      $fwrite(trace_fd, "\"rs2\":%0d,", rs2);
      $fwrite(trace_fd, "\"result\":\"%s\",", hex32(alu_result));
      $fwrite(trace_fd, "\"data\":\"%s\",", hex32(rd_data));
      $fwrite(trace_fd, "\"write\":%s,", bool_str(reg_write));
      $fwrite(trace_fd, "\"mem_read\":%s,", bool_str(mem_read));
      $fwrite(trace_fd, "\"mem_write\":%s,", bool_str(mem_write));
      $fwrite(trace_fd, "\"branch_taken\":%s,", bool_str(branch_taken));
      $fwrite(trace_fd, "\"valid\":true");
      $fwrite(trace_fd, "},");

      // Register file
      $fwrite(trace_fd, "\"regs\":%s,", build_reg_array());

      // Hazard signals (empty for single-stage - no hazards)
      $fwrite(trace_fd, "\"hazard\":{},");

      // Forwarding signals
      $fwrite(trace_fd, "\"forward\":{");
      $fwrite(trace_fd, "\"rs1\":\"%s\",", forward_str(fwd_rs1));
      $fwrite(trace_fd, "\"rs2\":\"%s\"", forward_str(fwd_rs2));
      $fwrite(trace_fd, "}");

      // Close JSON object and newline
      $fwrite(trace_fd, "}\n");

      // Flush to ensure data is written
      $fflush(trace_fd);
    end
  end

  //============================================================================
  // Close File on Simulation End
  //============================================================================
  final begin
    if (file_opened && trace_fd != 0) begin
      $fclose(trace_fd);
      $display("trace_logger: Closed trace file: %s", TRACE_FILE);
    end
  end

endmodule : trace_logger_1stage
