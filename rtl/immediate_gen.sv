//-----------------------------------------------------------------------------
// Module: immediate_gen
// Description: Immediate Generator for RISC-Vibe RV32I Processor
//              Extracts and sign-extends immediate values from RV32I instructions
//-----------------------------------------------------------------------------

module immediate_gen
  import riscvibe_pkg::*;
(
    // Inputs
    input  logic [31:0] instruction,

    // Outputs
    output logic [31:0] immediate
);

    //-------------------------------------------------------------------------
    // Local Parameters - RV32I Opcodes
    //-------------------------------------------------------------------------
    localparam logic [6:0] OPCODE_LOAD   = 7'h03;  // I-type: LB, LH, LW, LBU, LHU
    localparam logic [6:0] OPCODE_OP_IMM = 7'h13;  // I-type: ADDI, SLTI, etc.
    localparam logic [6:0] OPCODE_STORE  = 7'h23;  // S-type: SB, SH, SW
    localparam logic [6:0] OPCODE_BRANCH = 7'h63;  // B-type: BEQ, BNE, etc.
    localparam logic [6:0] OPCODE_LUI    = 7'h37;  // U-type: LUI
    localparam logic [6:0] OPCODE_AUIPC  = 7'h17;  // U-type: AUIPC
    localparam logic [6:0] OPCODE_JAL    = 7'h6F;  // J-type: JAL
    localparam logic [6:0] OPCODE_JALR   = 7'h67;  // I-type: JALR

    //-------------------------------------------------------------------------
    // Internal Signals
    //-------------------------------------------------------------------------
    logic [6:0] opcode;

    //-------------------------------------------------------------------------
    // Opcode Extraction
    //-------------------------------------------------------------------------
    assign opcode = instruction[6:0];

    //-------------------------------------------------------------------------
    // Immediate Generation
    // Sign-extends immediates based on instruction type determined by opcode
    //-------------------------------------------------------------------------
    always_comb begin
        case (opcode)
            // I-type: imm[11:0] = instruction[31:20], sign-extend from bit 11
            OPCODE_LOAD,
            OPCODE_OP_IMM,
            OPCODE_JALR: begin
                immediate = {{20{instruction[31]}}, instruction[31:20]};
            end

            // S-type: imm[11:5] = instruction[31:25], imm[4:0] = instruction[11:7]
            // Sign-extend from bit 11
            OPCODE_STORE: begin
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            end

            // B-type: imm[12|10:5|4:1|11] with imm[0] = 0
            // Sign-extend from bit 12
            OPCODE_BRANCH: begin
                immediate = {{19{instruction[31]}},  // Sign-extend from bit 12
                             instruction[31],        // imm[12]
                             instruction[7],         // imm[11]
                             instruction[30:25],     // imm[10:5]
                             instruction[11:8],      // imm[4:1]
                             1'b0};                  // imm[0] = 0
            end

            // U-type: imm[31:12] = instruction[31:12], imm[11:0] = 0
            OPCODE_LUI,
            OPCODE_AUIPC: begin
                immediate = {instruction[31:12], 12'b0};
            end

            // J-type: imm[20|10:1|11|19:12] with imm[0] = 0
            // Sign-extend from bit 20
            OPCODE_JAL: begin
                immediate = {{11{instruction[31]}},  // Sign-extend from bit 20
                             instruction[31],        // imm[20]
                             instruction[19:12],     // imm[19:12]
                             instruction[20],        // imm[11]
                             instruction[30:21],     // imm[10:1]
                             1'b0};                  // imm[0] = 0
            end

            // Default: Output zero for unsupported opcodes
            default: begin
                immediate = 32'b0;
            end
        endcase
    end

endmodule
