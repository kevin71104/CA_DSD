//=========================================================
//               Computer Architecture 2017
//                Hw3 : ALU
//=========================================================

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
    output   [31:0] ALUresult;
    output          ALUzero;
    reg      [31:0] tempResult;

//==== combinational part =================================
    assign ALUzero   = (ALUresult == 0) ? 1 : 0;
    assign ALUresult = tempResult;
    always@ (*) begin
        case(ALUctrl)
            4'b0000:
                tempResult = ALUin1 & ALUin2;
            4'b0001:
                tempResult = ALUin1 | ALUin2;
            4'b0010:
                tempResult = ALUin1 + ALUin2;
            4'b0110:
                tempResult = ALUin1 - ALUin2;
            4'b0111:
                tempResult = (ALUin1 < ALUin2) ? 1 : 0;
            4'b1100:
                tempResult = ~(ALUin1 | ALUin2);
            default:
                tempResult = ALUin1;
        endcase
    end
endmodule
