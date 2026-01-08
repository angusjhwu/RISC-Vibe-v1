// =============================================================================
// RiscVibe Instruction Memory - ROM-like Program Memory for RV32I
// =============================================================================
// This module implements the instruction memory (IMEM) for the RiscVibe
// RV32I processor. It provides a simple ROM-like interface for storing
// and fetching 32-bit instructions.
//
// Features:
// - Parameterizable memory depth
// - Asynchronous (combinational) read access
// - Initialization from hex file via $readmemh
// - Word-aligned addressing with NOP on out-of-bounds access
// =============================================================================

module instruction_mem #(
    parameter int DEPTH     = 1024,           // Number of 32-bit words (default 4KB)
    parameter     INIT_FILE = ""              // Path to hex file for initialization
) (
    // Clock input (used for initialization only)
    input  logic        clk,

    // Address input (byte address from PC)
    input  logic [31:0] addr,

    // Instruction output
    output logic [31:0] instruction
);

    // -------------------------------------------------------------------------
    // Local parameters
    // -------------------------------------------------------------------------
    // NOP instruction (ADDI x0, x0, 0) for out-of-bounds or invalid access
    localparam logic [31:0] NOP_INSTRUCTION = 32'h0000_0013;

    // -------------------------------------------------------------------------
    // Memory array declaration
    // -------------------------------------------------------------------------
    logic [31:0] mem [0:DEPTH-1];

    // -------------------------------------------------------------------------
    // Word address calculation
    // -------------------------------------------------------------------------
    // Convert byte address to word address by discarding lower 2 bits
    // This assumes word-aligned access (addr[1:0] == 2'b00)
    logic [31:0] word_addr;
    assign word_addr = addr[31:2];

    // -------------------------------------------------------------------------
    // Memory initialization
    // -------------------------------------------------------------------------
    // Load program from hex file if INIT_FILE is specified
    initial begin
        // Initialize all memory to NOP instructions
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = NOP_INSTRUCTION;
        end

        // Load program from file if specified
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // -------------------------------------------------------------------------
    // Synchronous read logic
    // -------------------------------------------------------------------------
    // Registered read with bounds checking
    // The instruction is registered on the positive clock edge, which means
    // the instruction seen is from the PREVIOUS cycle's PC value.
    // This creates a proper pipeline stage for instruction fetch.
    always_ff @(posedge clk) begin
        if (word_addr < DEPTH) begin
            instruction <= mem[word_addr];
        end else begin
            // Return NOP for out-of-bounds access
            instruction <= NOP_INSTRUCTION;
        end
    end

endmodule : instruction_mem
