//rtl_tb
`timescale 1ns/10ps
`define CYCLE  10
`define HCYCLE  5

module alu_rtl_tb;
    reg  [3:0] ctrl;
    reg  [7:0] x;
    reg  [7:0] y;
    wire       carry;
    wire [7:0] out;

    alu_rtl alu1(
        ctrl     ,
        x        ,
        y        ,
        carry    ,
        out
    );

   initial begin
       $dumpfile("alu_rtl.vcd");
       $dumpvars;
//        $fsdbDumpfile("alu_rtl.fsdb");
//        $fsdbDumpvars;
   end

    initial begin
        ctrl = 4'b0000;
        x    = -8'd127;
        y    = 8'd1;

        #(`CYCLE);
        // 0100 boolean not
        ctrl = 4'b0000;

        #(`HCYCLE);
        if( out == 8'b1000_0010 && carry == 0)
            $display( "PASS --- 0000 ADD(signed)" );
        else
            $display( "FAIL --- 0000 ADD(signed)" );

        // finish tb
        #(`CYCLE) $finish;
    end

endmodule
