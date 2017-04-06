//=========================================================
//               Computer Architecture 2017
//                Hw3 : Control
//=========================================================

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
    assign ALUOp[1]    = Op[2];
    assign ALUOp[0]    = R;
    assign Branch      = ~Op[5] & Op[2];
    assign MemRead     = lw;
    assign MemWrite    = sw;
    assign ALUsrc      = Op[5];
    assign RegWrite    = lw | (R & func[5]) | jal;
    assign Jump        = (~func[5] & R) | J;
    assign JumpReg     = ~Op[1];

endmodule
