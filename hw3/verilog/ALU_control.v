//=========================================================
//               Computer Architecture 2017
//                Hw3 : ALU control
//=========================================================

module ALU_control(
    ALUOp;
    func;
    ALUctrl;
);

//==== in/out declaration =================================
    input    [1:0] ALUOp;
    input    [5:0] func;
    output   [3:0] ALUctrl;

//==== combinational part =================================
    ALUctrl[3] = 0;
    always@ (*) begin
        ALUctrl[0] = (func[3] | func[0]) & ALUOp[1];
        ALUctrl[1] = ~(func[2] & ALUOp[1]);
        ALUctrl[2] = ALUOp[0] | (ALUOp1 & func[1]);
    end
