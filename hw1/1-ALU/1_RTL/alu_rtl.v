//RTL (use continuous assignment)

module mux2(out,in1,in2,sel);
    output out;
    input  in1, in2, sel;

    assign out = sel ? in1 :in2;
endmodule

module alu_rtl(
    ctrl,
    x,
    y,
    carry,
    out
);
//==== IN/OUT DECLARATION =========================
    input  [3:0] ctrl;
    input  [7:0] x;
    input  [7:0] y;
    output       carry;
    output [7:0] out;

//==== REG/WIRE DECLARATION ======================
    wire  [8:0]  temp,tempX,tempY;

    assign tempX = {x[7],x[7:0]};
    assign tempY = {y[7],y[7:0]};

    assign temp  =  (ctrl == 4'b0000) ? tempX + tempY :
                    (ctrl == 4'b0001) ? tempX - tempY : 9'b000000000;
    assign carry = (temp[8] != temp[7]) ? 1 : 0;
    assign out   = (ctrl == 4'b0000  || ctrl == 4'b0001) ? temp[7:0] :
                   (ctrl == 4'b0010) ? (x & y)       :
                   (ctrl == 4'b0011) ? (x | y)       :
                   (ctrl == 4'b0100) ? (~ x)         :
                   (ctrl == 4'b0101) ? {x[7],x[7:1]} :
                   (ctrl == 4'b0110) ? {x[6:0],x[7]} :
                   (ctrl == 4'b0111) ? {x[0],x[7:1]} :
                   (ctrl == 4'b1000) ? ((x == y) ? 1 : 0) : 0;

endmodule
