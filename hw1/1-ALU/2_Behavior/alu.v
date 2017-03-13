//Behavior level (event-driven)
module alu(
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
    reg  carry;
    reg  [7:0]  out;
    reg  [8:0]  tempX,tempY,temp;

//==== EVENT-DRIVEN ALWAYS BLOCK =================
    //<#bits>'<decimal,binary...><numbers>
    always @(*)
    begin
        case(ctrl)
            4'b0000:
            begin
                tempX = {x[7],x[7:0]};
                tempY = {y[7],y[7:0]};
                temp = tempX + tempY;
                carry = (temp[8] != temp[7]) ? 1 : 0;
                out = temp[7:0];
            end
            4'b0001:
            begin
                tempX = {x[7],x[7:0]};
                tempY = {y[7],y[7:0]};
                temp = tempX - tempY;
                carry = (temp[8] != temp[7]) ? 1 : 0;
                out = temp[7:0];
            end
            4'b0010:
                out = x & y;
            4'b0011:
                out = x | y;
            4'b0100:
                out = ~ x;
            4'b0101:
                out = x ^ y;
            4'b0110:
                out = ~(x | y);
            4'b0111:
                out = y << x[2:0];
            4'b1000:
                out = y >> x[2:0];
            4'b1001:
                out = {x[7],x[7:1]};
            4'b1010:
                out = {x[6:0],x[7]};
            4'b1011:
                out = {x[0],x[7:1]};
            4'b1100:
                out = (x == y) ? 1 : 0;
            default:
            begin
                out   = 0;
                carry = 0;
                temp  = 0;
            end
        endcase
    end

endmodule
