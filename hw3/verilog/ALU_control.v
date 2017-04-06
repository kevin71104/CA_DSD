//=========================================================
//               Computer Architecture 2017
//                Hw3 : ALU control
//=========================================================

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
