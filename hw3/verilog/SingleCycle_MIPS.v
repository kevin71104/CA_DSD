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
//                             Jump, Jumpreg, ALUsrc, ALUOp
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
//`include "ALU_control.v"
//`include "Control.v"
//`include "ALU.v"

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
    //wire [4:0]    Mux_RegDst;
    //wire [31:0]   MUX_MemtoReg, MUX_Address, MUX_Jump, MUX_Branch, MUX_Src;
    // ALU I/O
    wire [31:0]   ALUin1, ALUin2, ALUresult;
    wire [3:0]    ALUctrl;
    wire          ALUzero;
    // RF's data I/O
    wire [31:0]   ReadData1;
    wire [31:0]   WriteData;
    wire [4:0]    Reg_R1, Reg_R2, Reg_W;
    // PC
    reg  [31:0]   PC;
    wire [31:0]   PCin, PCnext, PCfinal, BranchAddr, JumpAddr, JumpRegAddr;
    wire [31:0]   NoJumpAddr, tempBranchAddr, NoJumpRegAddr;
    // Control Signals
    wire [1:0]    RegDst, MemtoReg, ALUOp;
    wire          Branch, MemRead, MemWrite, ALUsrc, RegWrite, Jump, JumpReg;
    // offset = IR[15:0] extension
    wire [31:0]   offset;

//==== submodule declaration ==============================
    ALU_control i_ALU_control(
        ALUOp,
        IR[5:0],
        ALUctrl
    );
    Control i_Control(
        IR[31:26],
        IR[5:0],
        RegDst,
        MemtoReg,
        ALUOp,
        Branch,
        MemRead,
        MemWrite,
        ALUsrc,
        RegWrite,
        Jump,
        JumpReg
    );
    SignExtendUnit i_SignExtend(
        IR[15:0],
        offset
    );
    ALU i_ALU(
        ALUin1,
        ALUin2,
        ALUctrl,
        ALUresult,
        ALUzero
    );

//==== combinational part =================================
    // PC part
    assign PCin            = PC;
    assign PCnext          = PCin + 4;
    assign tempBranchAddr  = offset << 2;
    assign BranchAddr      = PCnext + tempBranchAddr;
    assign NoJumpAddr      = (Branch & ALUzero) ? BranchAddr : PCnext;
    assign JumpRegAddr     = ReadData1;
    assign NoJumpRegAddr   = { {PCin[31:28]}, {IR[25:0]}, 2'b00};
    assign JumpAddr        = JumpReg ? JumpRegAddr : NoJumpRegAddr;
    assign PCfinal         = Jump ? JumpAddr : NoJumpAddr;
    assign IR_addr         = PC;

    // Registers part
    assign Reg_R1    = IR[25:21];
    assign Reg_R2    = IR[20:16];
    assign Reg_W     = RegDst[1] ? 5'd31 :
                       RegDst[0] ? IR[15:11] : IR[20:16];
    assign ReadData1 = RF[Reg_R1];
    assign ReadData2 = RF[Reg_R2];

    // ALU part
    assign ALUin1 = ReadData1;
    assign ALUin2 = ALUsrc ? offset : ReadData2;

    // Memory part
    assign A         = ALUresult[8:2];
    assign CEN       = ~(MemRead | MemWrite);
    assign WEN       = ~(MemWrite);
    assign OEN       = 0;
    assign WriteData = MemtoReg[1] ? PCnext :
                       MemtoReg[0] ? ReadDataMem : ALUresult;
    assign RF_writedata = WriteData;

//==== sequential part ====================================
    integer       i;
    always@ (posedge clk) begin
        if(~rst_n) begin
            PC <= 32'd0;
            for (i = 0; i < 32; i = i+1)
                RF[i] <= 32'd0;
        end
        else begin
            PC <= PCfinal;
            if(RegWrite == 1'b1)
                RF[Reg_W] <= WriteData;
            RF[0] <= 32'd0;
        end
    end

endmodule

// Sign Extension: extend 16-bits input to 32-bits output
module SignExtendUnit(data_i, data_o);

input   [15:0]  data_i;
output  [31:0]  data_o;

assign data_o = { {16{data_i[15]}} , data_i };

endmodule

// ALU
module ALU(
    ALUin1,
    ALUin2,
    ALUctrl,
    ALUresult,
    ALUzero
);

//==== in/out declaration =================================
    input    [31:0] ALUin1;
    input    [31:0] ALUin2;
    input    [3:0]  ALUctrl;
    output   reg [31:0] ALUresult;
    output          ALUzero;
    reg      [31:0] tempResult;

//==== combinational part =================================
    assign ALUzero   = (ALUresult == 32'd0) ? 1 : 0;
    //assign ALUresult = tempResult;
    always@ (*) begin
        case(ALUctrl)
            4'b0000:
                ALUresult = ALUin1 & ALUin2;
            4'b0001:
                ALUresult = ALUin1 | ALUin2;
            4'b0010:
                ALUresult = ALUin1 + ALUin2;
            4'b0110:
                ALUresult = ALUin1 - ALUin2;
            4'b0111:
            begin
                tempResult = ALUin1 - ALUin2;
                ALUresult = {31'd0, tempResult[31]};
            end
            //4'b1100:
                //tempResult = ~(ALUin1 | ALUin2);
            default:
                ALUresult = 32'd0;
        endcase
    end
endmodule

// Control signals
module Control(
    Op,
    func,
    RegDst,
    MemtoReg,
    ALUOp,
    Branch,
    MemRead,
    MemWrite,
    ALUsrc,
    RegWrite,
    Jump,
    JumpReg
);

//==== in/out declaration =================================
    input    [5:0] Op;
    input    [5:0] func;
    output   [1:0] RegDst, MemtoReg, ALUOp;
    output         Branch, MemRead, MemWrite, ALUsrc, RegWrite, Jump, JumpReg;

//==== reg/wire declaration ===============================
    wire     R, J, lw, sw, jal;
    //wire R_format, lw, sw, beq, jump, jr, jal;

//==== combinational part =================================

    assign R           = ~(Op[5] | Op[2]);  //R type
    assign J           = (~Op[5]) & Op[1];  //J type
    assign lw          = Op[5] & (~Op[3]);  //lw type
    assign sw          = Op[5] & Op[3];     //sw type
    assign jal         = (~Op[5]) & Op[0];

    assign RegDst[1]   = J;
    assign RegDst[0]   = ~Op[5];
    assign MemtoReg[1] = J;
    assign MemtoReg[0] = Op[5];
    assign ALUOp[1]    = R;
    assign ALUOp[0]    = Op[2];
    assign Branch      = ~Op[5] & Op[2];
    assign MemRead     = lw;
    assign MemWrite    = sw;
    assign ALUsrc      = Op[5];
    assign RegWrite    = lw | (R & func[5]) | jal;
    assign Jump        = (~func[5] & R) | J;
    assign JumpReg     = ~Op[1];

endmodule

// ALU control signals
module ALU_control(
    ALUOp,
    func,
    ALUctrl
);

//==== in/out declaration =================================
    input    [1:0] ALUOp;
    input    [5:0] func;
    output   [3:0] ALUctrl;

//==== combinational part =================================
    assign ALUctrl[3] = 1'b0;
    assign ALUctrl[0] = (func[3] | func[0]) & ALUOp[1];
    assign ALUctrl[1] = ~(func[2] & ALUOp[1]);
    assign ALUctrl[2] = ALUOp[0] | (ALUOp[1] & func[1]);

endmodule
