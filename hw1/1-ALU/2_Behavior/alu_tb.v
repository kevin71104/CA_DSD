//rtl_tb
`timescale 1ns/10ps
`define CYCLE  10
`define HCYCLE  5


module alu_tb;
//======== port-declaration ========
    reg  [3:0] ctrl;
    reg  [7:0] x;
    reg  [7:0] y;
    wire       carry;
    wire [7:0] out;

    reg        Clk;
    reg  [8:0] true_out,tempX,tempY;
//======== initial ========
    initial begin
        $dumpfile("alu.vcd");
        $dumpvars;
    end
//======== DUT instantiation ========
    alu alu1(ctrl, x, y, carry, out);

//======== clock generation ========
    always#(`HCYCLE) Clk = ~Clk;
    always @ ( posedge Clk) ctrl = ctrl + 1 ;

//======== Simulation ========
    integer err;

    initial begin
        ctrl  = 4'b0000;
        Clk   = 1;
        //$srand($time);
        x     = 0;
        y     = 0;
        tempX = 0;
        tempY = 0;
        err   = 0;

        //0000 : x + y
        #(0.2*`CYCLE);
        ctrl = 0;
        x = {$random}%256;
        y = {$random}%256;
        $display("Test: x(%b) + y(%b)",x,y);
        tempX = {x[7],x[7:0]};
        tempY = {y[7],y[7:0]};
        true_out = tempX + tempY;
        #(0.3*`CYCLE);
        if( {carry,out} == true_out)
            $display( "PASS --- %b(%d) + %b(%d) = %d",x,$signed(x),y,$signed(y),$signed({carry,out}) );
        else begin
            err = err + 1;
            $display( "FAIL --- expected(%b), but yours(%b)",true_out,{carry,out} );
        end
        #(0.5*`CYCLE);

        //0001 : x - y
        #(0.2*`CYCLE);
        x = {$random}%256;
        y = {$random}%256;
        $display("Test: x(%b) - y(%b)",x,y);
        tempX = {x[7],x[7:0]};
        tempY = {y[7],y[7:0]};
        true_out = tempX - tempY;
        #(0.3*`CYCLE);
        if( {carry,out} == true_out)
            $display( "PASS --- %b(%d) - %b(%d) = %d",x,$signed(x),y,$signed(y),$signed({carry,out}) );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out,{carry,out} );
        #(0.5*`CYCLE);

        //0010 : x & y
        #(0.2*`CYCLE);
        x = {$random}%256;
        y = {$random}%256;
        $display("Test: x(%b) & y(%b)",x,y);
        true_out = x & y;
        #(0.3*`CYCLE);
        if( out == true_out[7:0])
            $display( "PASS --- %b & %b = %b",x,y,out );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out[7:0],out);
        #(0.5*`CYCLE);

        //0011 : x | y
        #(0.2*`CYCLE);
        x = {$random}%256;
        y = {$random}%256;
        $display("Test: x(%b) | y(%b)",x,y);
        true_out = x | y;
        #(0.3*`CYCLE);
        if( out == true_out[7:0])
            $display( "PASS --- %b | %b = %b",x,y,out );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out[7:0],out);
        #(0.5*`CYCLE);

        //0100 : ~ x
        #(0.2*`CYCLE);
        x = {$random}%256;
        $display("Test: ~ (x(%b))",x);
        true_out = ~ x ;
        #(0.3*`CYCLE);
        if( out == true_out[7:0])
            $display( "PASS --- ~(%b)  = %b",x,out );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out[7:0],out);
        #(0.5*`CYCLE);

        //0101 : x ^ y
        #(0.2*`CYCLE);
        x = {$random}%256;
        y = {$random}%256;
        $display("Test: x(%b) | y(%b)",x,y);
        true_out = x ^ y;
        #(0.3*`CYCLE);
        if( out == true_out[7:0])
            $display( "PASS --- %b ^ %b = %b",x,y,out );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out[7:0],out);
        #(0.5*`CYCLE);

        //0110 : x | y
        #(0.2*`CYCLE);
        x    = {$random}%256;
        y    = {$random}%256;
        $display("Test: ~( x(%b) | y(%b) )",x,y);
        true_out = ~(x | y);
        #(0.3*`CYCLE);
        if( out == true_out[7:0])
            $display( "PASS --- ~( %b | %b ) = %b",x,y,out );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out[7:0],out);
        #(0.5*`CYCLE);

        //0111 : y << x[2:0]
        #(0.2*`CYCLE);
        x = {$random}%256;
        y = {$random}%256;
        $display("Test: ~( y(%b) << x[2:0](%d) )",y,x[2:0]);
        true_out = y << x[2:0];
        #(0.3*`CYCLE);
        if( out == true_out[7:0])
            $display( "PASS --- %b << %d  = %b",y,x[2:0],out );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out[7:0],out);
        #(0.5*`CYCLE);

        //1000 : y >> x[2:0]
        #(0.2*`CYCLE);
        x = {$random}%256;
        y = {$random}%256;
        $display("Test: ~( y(%b) >> x[2:0](%d) )",y,x[2:0]);
        true_out = y >> x[2:0];
        #(0.3*`CYCLE);
        if( out == true_out[7:0])
            $display( "PASS --- %b >> %d  = %b",y,x[2:0],out );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out[7:0],out);
        #(0.5*`CYCLE);

        //1001 : x right-shift
        #(0.2*`CYCLE);
        x = {$random}%256;
        $display("Test: x(%b) right-shift ", x);
        true_out = {x[7],x[7:1]};
        #(0.3*`CYCLE);
        if( out == true_out[7:0])
            $display( "PASS --- %b right-shift = %b", x, out );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out[7:0],out);
        #(0.5*`CYCLE);

        //1010 : x left-rotated
        #(0.2*`CYCLE);
        x = {$random}%256;
        $display("Test: x(%b) left-rotated ", x);
        true_out = {x[6:0],x[7]};
        #(0.3*`CYCLE);
        if( out == true_out[7:0])
            $display( "PASS --- %b left-rotated = %b", x, out );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out[7:0],out);
        #(0.5*`CYCLE);

        //1011 : x right-rotated
        #(0.2*`CYCLE);
        x = {$random}%256;
        $display("Test: x(%b) right-rotated ", x);
        true_out = {x[0],x[7:1]};
        #(0.3*`CYCLE);
        if( out == true_out[7:0])
            $display( "PASS --- %b right-rotated = %b", x, out );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out[7:0],out);
        #(0.5*`CYCLE);

        //1100 : x equal y ?
        #(0.2*`CYCLE);
        x = {$random} % 256;
        x = {$random} % 256;
        $display("Test: x(%b) equal y(%b) ? ", x, y);
        true_out = (x == y) ? 1 : 0;
        #(0.3*`CYCLE);
        if( out == true_out[7:0])
            $display( "PASS --- %b equal %b ? %d", x, y, out );
        else
            $display( "FAIL --- expected(%b), but yours(%b)",true_out[7:0],out);
        #(0.5*`CYCLE);

        // finish tb
        #(10*(`CYCLE)) $finish;
    end

endmodule
