module register_file(
    Clk  ,
    WEN  ,
    RW   ,
    busW ,
    RX   ,
    RY   ,
    busX ,
    busY
);
    input        Clk, WEN;
    input  [2:0] RW, RX, RY;
    input  [7:0] busW;
    output [7:0] busX, busY;

    // write your design here

//==== i/o definition ====
    reg  [7:0]  register[7:0];
    wire [7:0]  busX_tmp, busY_tmp;

//==== reg/wire definition ====

//==== combinational circuit ====

    assign busX_tmp = (RX == 3'b000) ? register[0] :
               (RX == 3'b001) ? register[1] :
               (RX == 3'b010) ? register[2] :
               (RX == 3'b011) ? register[3] :
               (RX == 3'b100) ? register[4] :
               (RX == 3'b101) ? register[5] :
               (RX == 3'b110) ? register[6] : register[7];

    assign busY_tmp = (RY == 3'b000) ? register[0] :
               (RY == 3'b001) ? register[1] :
               (RY == 3'b010) ? register[2] :
               (RY == 3'b011) ? register[3] :
               (RY == 3'b100) ? register[4] :
               (RY == 3'b101) ? register[5] :
               (RY == 3'b110) ? register[6] : register[7];

    /*always@(RX) begin
        case(RX)
            3'b000:
                busX_tmp = register[0];
            3'b001:
                busX_tmp = register[1];
            3'b010:
                busX_tmp = register[2];
            3'b011:
                busX_tmp = register[3];
            3'b100:
                busX_tmp = register[4];
            3'b101:
                busX_tmp = register[5];
            3'b110:
                busX_tmp = register[6];
            3'b111:
                busX_tmp = register[7];
        endcase
    end

    always@(RY) begin
        case(RY)
            3'b000:
                busY_tmp = register[0];
            3'b001:
                busY_tmp = register[1];
            3'b010:
                busY_tmp = register[2];
            3'b011:
                busY_tmp = register[3];
            3'b100:
                busY_tmp = register[4];
            3'b101:
                busY_tmp = register[5];
            3'b110:
                busY_tmp = register[6];
            3'b111:
                busY_tmp = register[7];
        endcase
    end*/

    assign busX = busX_tmp;
    assign busY = busY_tmp;

//==== sequential circuit ====
    always@( posedge Clk ) begin
        register[0] = 8'd0;
        if(WEN)begin
            case(RW)
                3'b001:
                    register[1] <= busW;
                3'b010:
                    register[2] <= busW;
                3'b011:
                    register[3] <= busW;
                3'b100:
                    register[4] <= busW;
                3'b101:
                    register[5] <= busW;
                3'b110:
                    register[6] <= busW;
                3'b111:
                    register[7] <= busW;
            endcase
        end
    end

endmodule
