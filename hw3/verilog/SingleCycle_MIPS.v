//=========================================================
//               Computer Architecture 2017
//                Hw3 : Single Cycle MIPS
//=========================================================

//=========================================================
// Input/Output Signals:
// positive-edge triggered         clk
// active low asynchronous reset   rst_n
// instruction memory interface    IR_addr, IR
// output for testing purposes     RF_writedata
//=========================================================
// Wire/Reg Specifications:
// control signals             MemtoReg, MemRead, MemWrite,
//                             RegDst, RegWrite, Branch,
//                             Jump, Jumpreg, ALUSrc, ALUOp
// ALU control signals         ALUctrl
// ALU input signals           ALUin1, ALUin2
// ALU output signals          ALUresult, ALUzero
// instruction specifications  r, j, jal, jr, lw, sw, beq
// sign-extended signal        SignExtend
// MUX output signals          MUX_RegDst, MUX_MemtoReg,
//                             MUX_Src, MUX_Branch, MUX_Jump
// registers input signals     Reg_R1, Reg_R2, Reg_W, WriteData
// registers                   RF[31:0]
// registers output signals    ReadData1, ReadData2
// data memory contral signals CEN, OEN, WEN
// data memory output signals  ReadDataMem
// program counter/address     PC, PCnext, JumpAddr, BranchAddr
//=========================================================

module SingleCycle_MIPS(
    clk,
    rst_n,
    IR_addr,
    IR,
    RF_writedata,
    ReadDataMem,
    CEN,
    WEN,
    A,
    ReadData2,
    OEN
);

//==== in/out declaration =================================
    //-------- processor ----------------------------------
    input         clk, rst_n;
    input  [31:0] IR;
    output [31:0] IR_addr, RF_writedata;
    //-------- data memory --------------------------------
    input  [31:0] ReadDataMem;  // read_data from memory
    output        CEN;  // chip_enable, 0 when you read/write data from/to memory
    output        WEN;  // write_enable, 0 when you write data into SRAM & 1 when you read data from SRAM
    output [6:0]  A;  // address
    output [31:0] ReadData2;  // write_data to memory
    output        OEN;  // output_enable, 0

//==== reg/wire declaration ===============================
    // 32 registers in the CPU
    reg  [31:0]   RF[31:0];
    // MUX results
    wire [4:0]    Mux_RegDst;
    wire [31:0]   MUX_MemtoReg, MUX_Address, MUX_Jump, MUX_Branch, MUX_Src;
    // ALU I/O
    wire [31:0]   ALUin1, ALUin2, ALUresult, ALUzero;
    wire [3:0]    ALUctrl;
    // RF's data I/O
    wire [31:0]   ReadData1, ReadData2;
    wire [31:0]   WriteData;
    wire [4:0]    Reg_R1, Reg_R2, Reg_W;
    // PC
    wire [31:0]   PC, PCnext, BranchAddr, JumpAddr, JumpRegAddr;
    // Control Signals
    wire [1:0]    RegDst, MemtoReg, ALUOp;
    wire          Branch, MemRead, MemWrite, ALUsrc, RegWrite, Jump, JumpReg;

//==== combinational part =================================
    always@ (~rst_n) begin
        for (i = 0; i < 32; i = i+1)
            RF[i] = 0;
    end

//==== sequential part ====================================
    always@ (posedge clk) begin

    end


//=========================================================
endmodule
