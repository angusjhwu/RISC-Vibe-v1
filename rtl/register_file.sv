//-----------------------------------------------------------------------------
// Module: register_file
// Project: RiscVibe - RV32I Processor
// Description: 32x32-bit register file for RISC-V RV32I architecture
//              - 32 general-purpose registers (x0-x31)
//              - x0 is hardwired to zero
//              - Two asynchronous read ports
//              - One synchronous write port
//-----------------------------------------------------------------------------

module register_file (
    // Clock and reset
    input  logic        clk,        // Clock signal
    input  logic        rst_n,      // Active-low synchronous reset

    // Read port 1
    input  logic [4:0]  rs1_addr,   // Source register 1 address
    output logic [31:0] rs1_data,   // Source register 1 data

    // Read port 2
    input  logic [4:0]  rs2_addr,   // Source register 2 address
    output logic [31:0] rs2_data,   // Source register 2 data

    // Write port
    input  logic [4:0]  rd_addr,    // Destination register address
    input  logic [31:0] rd_data,    // Data to write
    input  logic        reg_write   // Write enable signal
);

    //-------------------------------------------------------------------------
    // Register array declaration
    // Note: x0 is handled separately to ensure it's always zero
    //-------------------------------------------------------------------------
    logic [31:0] registers [1:31];  // Registers x1-x31 (x0 is hardwired to 0)

    //-------------------------------------------------------------------------
    // Synchronous write logic
    // Writes occur on the positive edge of the clock
    // Writes to x0 are ignored (rd_addr != 0 check)
    //-------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Reset all registers to zero
            for (int i = 1; i < 32; i++) begin
                registers[i] <= 32'h0;
            end
        end else if (reg_write && (rd_addr != 5'b0)) begin
            // Write to register if write is enabled and not targeting x0
            registers[rd_addr] <= rd_data;
        end
    end

    //-------------------------------------------------------------------------
    // Asynchronous read logic - Port 1
    // Returns 0 when reading x0, otherwise returns register contents
    //-------------------------------------------------------------------------
    always_comb begin
        if (rs1_addr == 5'b0) begin
            rs1_data = 32'h0;
        end else begin
            rs1_data = registers[rs1_addr];
        end
    end

    //-------------------------------------------------------------------------
    // Asynchronous read logic - Port 2
    // Returns 0 when reading x0, otherwise returns register contents
    //-------------------------------------------------------------------------
    always_comb begin
        if (rs2_addr == 5'b0) begin
            rs2_data = 32'h0;
        end else begin
            rs2_data = registers[rs2_addr];
        end
    end

endmodule
