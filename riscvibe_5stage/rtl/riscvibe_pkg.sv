//==============================================================================
// RISC-Vibe RV32I Processor - Package Definitions
//==============================================================================
// This package contains type definitions, opcodes, and control signal
// encodings for the RISC-Vibe RV32I processor implementation.
//==============================================================================

package riscvibe_pkg;

  //============================================================================
  // RV32I Opcode Definitions (bits [6:0] of instruction)
  //============================================================================
  // These opcodes are defined per the RISC-V specification for RV32I base ISA

  localparam logic [6:0] OPCODE_OP      = 7'h33;  // Register-register ALU ops
  localparam logic [6:0] OPCODE_OP_IMM  = 7'h13;  // Register-immediate ALU ops
  localparam logic [6:0] OPCODE_LOAD    = 7'h03;  // Load instructions
  localparam logic [6:0] OPCODE_STORE   = 7'h23;  // Store instructions
  localparam logic [6:0] OPCODE_BRANCH  = 7'h63;  // Conditional branches
  localparam logic [6:0] OPCODE_JAL     = 7'h6F;  // Jump and link
  localparam logic [6:0] OPCODE_JALR    = 7'h67;  // Jump and link register
  localparam logic [6:0] OPCODE_LUI     = 7'h37;  // Load upper immediate
  localparam logic [6:0] OPCODE_AUIPC   = 7'h17;  // Add upper immediate to PC
  localparam logic [6:0] OPCODE_SYSTEM  = 7'h73;  // System instructions (ECALL, EBREAK, CSR)
  localparam logic [6:0] OPCODE_FENCE   = 7'h0F;  // Memory ordering (FENCE)

  //============================================================================
  // ALU Operation Encodings (4-bit)
  //============================================================================
  // ALU operations for arithmetic, logical, and shift instructions

  typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,  // Addition
    ALU_SUB  = 4'b0001,  // Subtraction
    ALU_SLL  = 4'b0010,  // Shift left logical
    ALU_SLT  = 4'b0011,  // Set less than (signed)
    ALU_SLTU = 4'b0100,  // Set less than (unsigned)
    ALU_XOR  = 4'b0101,  // Bitwise XOR
    ALU_SRL  = 4'b0110,  // Shift right logical
    ALU_SRA  = 4'b0111,  // Shift right arithmetic
    ALU_OR   = 4'b1000,  // Bitwise OR
    ALU_AND  = 4'b1001   // Bitwise AND
  } alu_op_t;

  //============================================================================
  // Branch Comparison Types (3-bit funct3)
  //============================================================================
  // Branch condition encodings as specified in RISC-V funct3 field

  typedef enum logic [2:0] {
    BRANCH_BEQ  = 3'b000,  // Branch if equal
    BRANCH_BNE  = 3'b001,  // Branch if not equal
    BRANCH_BLT  = 3'b100,  // Branch if less than (signed)
    BRANCH_BGE  = 3'b101,  // Branch if greater or equal (signed)
    BRANCH_BLTU = 3'b110,  // Branch if less than (unsigned)
    BRANCH_BGEU = 3'b111   // Branch if greater or equal (unsigned)
  } branch_cmp_t;

  //============================================================================
  // Load/Store Width Types (3-bit funct3)
  //============================================================================
  // Memory access width encodings as specified in RISC-V funct3 field

  typedef enum logic [2:0] {
    MEM_BYTE   = 3'b000,  // 8-bit signed byte
    MEM_HALF   = 3'b001,  // 16-bit signed halfword
    MEM_WORD   = 3'b010,  // 32-bit word
    MEM_BYTE_U = 3'b100,  // 8-bit unsigned byte
    MEM_HALF_U = 3'b101   // 16-bit unsigned halfword
  } mem_width_t;

  //============================================================================
  // ALU Source Selection
  //============================================================================
  // Selects the source for ALU operand B

  typedef enum logic [1:0] {
    ALU_SRC_REG  = 2'b00,  // Second operand from register file (rs2)
    ALU_SRC_IMM  = 2'b01,  // Second operand from immediate
    ALU_SRC_PC   = 2'b10,  // First operand from PC (for AUIPC)
    ALU_SRC_ZERO = 2'b11   // Zero (for LUI passthrough)
  } alu_src_t;

  //============================================================================
  // Register Write Source Selection
  //============================================================================
  // Selects the data source for register file write-back

  typedef enum logic [1:0] {
    REG_WR_ALU  = 2'b00,  // Write ALU result
    REG_WR_MEM  = 2'b01,  // Write memory load data
    REG_WR_PC4  = 2'b10,  // Write PC+4 (for JAL/JALR link)
    REG_WR_IMM  = 2'b11   // Write immediate value (for LUI)
  } reg_wr_src_t;

  //============================================================================
  // Memory Operation Type
  //============================================================================
  // Specifies the type of memory operation

  typedef enum logic [1:0] {
    MEM_OP_NONE  = 2'b00,  // No memory operation
    MEM_OP_LOAD  = 2'b01,  // Load from memory
    MEM_OP_STORE = 2'b10   // Store to memory
  } mem_op_t;

  //============================================================================
  // Branch Type
  //============================================================================
  // Specifies the type of control flow change

  typedef enum logic [1:0] {
    BRANCH_NONE = 2'b00,  // No branch (sequential execution)
    BRANCH_COND = 2'b01,  // Conditional branch (BEQ, BNE, etc.)
    BRANCH_JAL  = 2'b10,  // Unconditional jump (JAL)
    BRANCH_JALR = 2'b11   // Indirect jump (JALR)
  } branch_type_t;

  //============================================================================
  // Instruction Funct3 Constants
  //============================================================================
  // Common funct3 values for instruction decoding

  // ALU immediate/register funct3 values
  localparam logic [2:0] FUNCT3_ADD_SUB = 3'b000;  // ADD/SUB (funct7 distinguishes)
  localparam logic [2:0] FUNCT3_SLL     = 3'b001;  // Shift left logical
  localparam logic [2:0] FUNCT3_SLT     = 3'b010;  // Set less than
  localparam logic [2:0] FUNCT3_SLTU    = 3'b011;  // Set less than unsigned
  localparam logic [2:0] FUNCT3_XOR     = 3'b100;  // XOR
  localparam logic [2:0] FUNCT3_SRL_SRA = 3'b101;  // Shift right (funct7 distinguishes)
  localparam logic [2:0] FUNCT3_OR      = 3'b110;  // OR
  localparam logic [2:0] FUNCT3_AND     = 3'b111;  // AND

  //============================================================================
  // Instruction Funct7 Constants
  //============================================================================
  // Funct7 values for distinguishing ADD/SUB and SRL/SRA

  localparam logic [6:0] FUNCT7_NORMAL = 7'b0000000;  // ADD, SRL
  localparam logic [6:0] FUNCT7_ALT    = 7'b0100000;  // SUB, SRA

  //============================================================================
  // System Instruction Funct3 Constants
  //============================================================================
  // Funct3 values for SYSTEM opcode instructions

  localparam logic [2:0] FUNCT3_PRIV   = 3'b000;  // ECALL, EBREAK, xRET
  localparam logic [2:0] FUNCT3_CSRRW  = 3'b001;  // CSR read/write
  localparam logic [2:0] FUNCT3_CSRRS  = 3'b010;  // CSR read/set
  localparam logic [2:0] FUNCT3_CSRRC  = 3'b011;  // CSR read/clear
  localparam logic [2:0] FUNCT3_CSRRWI = 3'b101;  // CSR read/write immediate
  localparam logic [2:0] FUNCT3_CSRRSI = 3'b110;  // CSR read/set immediate
  localparam logic [2:0] FUNCT3_CSRRCI = 3'b111;  // CSR read/clear immediate

  //============================================================================
  // Register Address Constants
  //============================================================================
  // Special register addresses

  localparam logic [4:0] REG_ZERO = 5'd0;   // x0 - hardwired zero
  localparam logic [4:0] REG_RA   = 5'd1;   // x1 - return address
  localparam logic [4:0] REG_SP   = 5'd2;   // x2 - stack pointer

  //============================================================================
  // Data Width Constants
  //============================================================================
  // Common width parameters for the RV32I implementation

  localparam int XLEN       = 32;  // Register width
  localparam int ILEN       = 32;  // Instruction width
  localparam int REG_ADDR_W = 5;   // Register address width (32 registers)

  //============================================================================
  // Forwarding Unit Selection
  //============================================================================
  // Selects the source for forwarded data in the EX stage

  typedef enum logic [1:0] {
    FWD_NONE = 2'b00,  // No forwarding, use ID/EX register
    FWD_WB   = 2'b01,  // Forward from MEM/WB stage
    FWD_MEM  = 2'b10   // Forward from EX/MEM stage
  } forward_sel_t;

  //============================================================================
  // Pipeline Register Structures (5-stage pipeline)
  //============================================================================
  // Packed structs for pipeline registers between each stage

  //----------------------------------------------------------------------------
  // IF/ID Pipeline Register
  //----------------------------------------------------------------------------
  typedef struct packed {
    logic [31:0] instruction;  // Fetched instruction
    logic [31:0] pc;           // Program counter of this instruction
    logic [31:0] pc_plus_4;    // PC + 4 for sequential next instruction
    logic        valid;        // Instruction valid flag
  } if_id_reg_t;

  //----------------------------------------------------------------------------
  // ID/EX Pipeline Register
  //----------------------------------------------------------------------------
  typedef struct packed {
    logic [31:0]  pc;           // Program counter
    logic [31:0]  pc_plus_4;    // PC + 4 for link address
    logic [31:0]  rs1_data;     // Source register 1 data
    logic [31:0]  rs2_data;     // Source register 2 data
    logic [4:0]   rs1_addr;     // Source register 1 address
    logic [4:0]   rs2_addr;     // Source register 2 address
    logic [4:0]   rd_addr;      // Destination register address
    logic [31:0]  immediate;    // Sign-extended immediate value
    alu_op_t      alu_op;       // ALU operation (4 bits)
    logic         alu_src_a;    // ALU source A select (0=rs1, 1=PC)
    logic         alu_src_b;    // ALU source B select (0=rs2, 1=imm)
    logic         mem_read;     // Memory read enable
    logic         mem_write;    // Memory write enable
    logic [2:0]   mem_width;    // Memory access width
    logic         reg_write;    // Register write enable
    reg_wr_src_t  reg_wr_src;   // Register write source (2 bits)
    branch_type_t branch_type;  // Branch type (2 bits)
    logic [2:0]   branch_cmp;   // Branch comparison type
    logic         valid;        // Pipeline stage valid flag
  } id_ex_reg_t;

  //----------------------------------------------------------------------------
  // EX/MEM Pipeline Register
  //----------------------------------------------------------------------------
  typedef struct packed {
    logic [31:0] pc_plus_4;     // PC + 4 for link address
    logic [31:0] alu_result;    // ALU computation result
    logic [31:0] rs2_data;      // Store data (from rs2)
    logic [4:0]  rd_addr;       // Destination register address
    logic        mem_read;      // Memory read enable
    logic        mem_write;     // Memory write enable
    logic [2:0]  mem_width;     // Memory access width
    logic        reg_write;     // Register write enable
    reg_wr_src_t reg_wr_src;    // Register write source (2 bits)
    logic        valid;         // Pipeline stage valid flag
  } ex_mem_reg_t;

  //----------------------------------------------------------------------------
  // MEM/WB Pipeline Register
  //----------------------------------------------------------------------------
  typedef struct packed {
    logic [31:0] pc_plus_4;     // PC + 4 for link address
    logic [31:0] alu_result;    // ALU computation result
    logic [31:0] mem_read_data; // Data read from memory
    logic [4:0]  rd_addr;       // Destination register address
    logic        reg_write;     // Register write enable
    reg_wr_src_t reg_wr_src;    // Register write source (2 bits)
    logic        valid;         // Pipeline stage valid flag
  } mem_wb_reg_t;

endpackage : riscvibe_pkg
