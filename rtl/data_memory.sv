//==============================================================================
// RISC-Vibe RV32I Processor - Data Memory Module
//==============================================================================
// This module implements the data memory for load/store operations with
// byte, halfword, and word granularity. Supports sign and zero extension
// for load operations.
//==============================================================================

module data_memory
  import riscvibe_pkg::*;
#(
  parameter int DEPTH = 4096  // Number of bytes (default 4KB)
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [31:0] addr,
  input  logic [31:0] write_data,
  input  logic        mem_read,
  input  logic        mem_write,
  input  logic [2:0]  mem_width,
  output logic [31:0] read_data
);

  //============================================================================
  // Memory Array - Byte Addressable
  //============================================================================
  logic [7:0] mem [0:DEPTH-1];

  //============================================================================
  // Address Calculation
  //============================================================================
  // Use lower bits of address based on memory depth
  localparam int ADDR_BITS = $clog2(DEPTH);
  logic [ADDR_BITS-1:0] byte_addr;

  assign byte_addr = addr[ADDR_BITS-1:0];

  //============================================================================
  // Synchronous Write Logic
  //============================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Memory contents are undefined after reset (no initialization)
    end else if (mem_write) begin
      case (mem_width)
        MEM_BYTE, MEM_BYTE_U: begin
          // Store byte - write single byte
          mem[byte_addr] <= write_data[7:0];
        end

        MEM_HALF, MEM_HALF_U: begin
          // Store halfword - write 2 bytes (little-endian)
          mem[byte_addr]     <= write_data[7:0];
          mem[byte_addr + 1] <= write_data[15:8];
        end

        MEM_WORD: begin
          // Store word - write 4 bytes (little-endian)
          mem[byte_addr]     <= write_data[7:0];
          mem[byte_addr + 1] <= write_data[15:8];
          mem[byte_addr + 2] <= write_data[23:16];
          mem[byte_addr + 3] <= write_data[31:24];
        end

        default: begin
          // No operation for undefined widths
        end
      endcase
    end
  end

  //============================================================================
  // Asynchronous Read Logic (Combinational)
  //============================================================================
  always_comb begin
    read_data = 32'b0;

    if (mem_read) begin
      case (mem_width)
        MEM_BYTE: begin
          // Load byte - sign extend
          read_data = {{24{mem[byte_addr][7]}}, mem[byte_addr]};
        end

        MEM_HALF: begin
          // Load halfword - sign extend (little-endian)
          read_data = {{16{mem[byte_addr + 1][7]}},
                       mem[byte_addr + 1],
                       mem[byte_addr]};
        end

        MEM_WORD: begin
          // Load word (little-endian)
          read_data = {mem[byte_addr + 3],
                       mem[byte_addr + 2],
                       mem[byte_addr + 1],
                       mem[byte_addr]};
        end

        MEM_BYTE_U: begin
          // Load byte unsigned - zero extend
          read_data = {24'b0, mem[byte_addr]};
        end

        MEM_HALF_U: begin
          // Load halfword unsigned - zero extend (little-endian)
          read_data = {16'b0,
                       mem[byte_addr + 1],
                       mem[byte_addr]};
        end

        default: begin
          read_data = 32'b0;
        end
      endcase
    end
  end

endmodule : data_memory
