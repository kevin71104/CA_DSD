//RTL (use continuous assignment)
module alu_rtl(
    ctrl,
    x,
    y,
    carry,
    out
);

    input  [3:0] ctrl;
    input  [7:0] x;
    input  [7:0] y;
    output       carry;
    output [7:0] out;
    reg    [8:0] temp;

    assign out   = 8'b00000000;
    assign carry = 1'b0;
    assign reg   = 9'b000000000;

    always @(ctrl)
    begin
        case(ctrl)
        4'b0000:
        begin
            reg = x + y;
            out = temp[7:0];
            carry = temp[8];
        end
        4'b0001:
        begin
            reg = x - y;
            out = temp[7:0];
            carry = temp[8];
        end
        4'b0010:
        begin
            out = x & y;
        end
        4'b0011:
        begin
            out = x | y;
        end
        4'b0100:
        begin
            out = ~ x;
        end
    end

endmodule
