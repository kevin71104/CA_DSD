`include "alu.v"
`include "register_file.v"

module simple_calculator(Clk, WEN, RW, RX, RY, DataIn, Sel, Ctrl, busY, Carry);

    input        Clk;
    input        WEN;
    input  [2:0] RW, RX, RY;
    input  [7:0] DataIn;
    input        Sel;
    input  [3:0] Ctrl;
    output [7:0] busY;
    output       Carry;

// declaration of wire/reg
    wire        carry_tmp;
    wire [7:0]  busW_tmp, busX_tmp, busY_tmp, x, y;
// submodule instantiation
    register_file rf(Clk, WEN, RW, busW_tmp, RX, RY, busX_tmp, busY_tmp);
    alu alu1(Ctrl, x, y, Carry, busW_tmp);
    
// combinational part
    //assign x    = Sel ? busX_tmp : DataIn;
    always@(Sel,busX_tmp,DataIn) begin
        if (Sel) : x = busX_tmp;
        else     : x = DataIn;
    end
    assign y    = busY_tmp;
    assign busY = busY_tmp;
// sequential part


endmodule
