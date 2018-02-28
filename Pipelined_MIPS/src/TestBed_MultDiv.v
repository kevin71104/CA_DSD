`timescale 1 ns/10 ps

`define	TestPort	30'd0
`define	CheckNum	6'd13

module	TestBed(
	clk,
	rst,
	addr,
	data,
	wen,
	error_num,
	duration,
	finish
);
	input			clk, rst;
	input	[29:0]	addr;
	input	[31:0]	data;
	input			wen;
	output	[7:0]	error_num;
	output	[15:0]	duration;
	output			finish;
	reg		[15:0]	duration;
	reg				finish;
    reg     [7:0]   error_num;
	reg		[1:0]	curstate;
	reg		[1:0]	nxtstate;
	reg		[5:0]	curaddr;
	reg		[5:0]	nxtaddr;
	reg		[15:0]	nxtduration;
	reg		[7:0]	nxt_error_num;
	reg				state,state_next;
	reg     [31:0]  answer;
	reg     [29:0]  testaddr;

	parameter	state_idle 	= 2'b00;
	parameter	state_pass= 2'b01;

	always@( posedge clk or negedge rst )						// State-DFF
	begin
		if( ~rst )
		begin
			curstate <= state_idle;
			curaddr  <= 0;
			duration <= 0;
            error_num <= 0;
			state <= 0;
		end
		else
		begin
			curstate <= nxtstate;
			curaddr  <= nxtaddr;
			duration <= nxtduration;
            error_num <= nxt_error_num;
			state <= state_next;
		end
	end

	always@( curstate or curaddr or addr or data or wen or duration )	// FSM for test
	begin
		finish = 1'b0;
		case( curstate )
		state_idle: 	begin
							nxtaddr = curaddr;
							nxtduration = 0;
							nxt_error_num = error_num;
							if( addr==testaddr && wen && state==0 )
							begin
								nxtaddr = curaddr + 1;
                                if( data != answer )begin
									nxt_error_num = error_num + 8'd1;
                                    $display("Error: addr=%d, data=%d, expected=%d.", curaddr, data, answer);
                                end
								else begin
									$display("Correct: addr=%d, data=%d, expected=%d.", curaddr, data, answer);
								end
							end
							//$display("nxtaddr:&d",nxtaddr);
							nxtstate = curstate;
							if( curaddr==`CheckNum )begin
								nxtstate = state_pass;
						    end
						end
		state_pass:	begin
						finish = 1'b1;
						nxtaddr = curaddr;
						nxtstate = curstate;
						nxtduration = duration;
						nxt_error_num = error_num;
					end
		endcase
	end

	always@(*)begin//sub-FSM (avoid the Dcache stall condition)
		case(state)
			1'b0:begin
				if(wen)
					state_next=1;
				else
					state_next=state;
			end
			1'b1:begin
				if(!wen)
					state_next=0;
				else
					state_next=state;
			end
		endcase
	end

	always@( negedge clk )
	begin
		if(curstate == state_pass) begin
			if (error_num) begin
				$display("============================================================================");
				$display("\n (T_T) FAIL!! The simulation result is FAIL!!! there were %d errors at all.\n", error_num);
				$display("============================================================================");
			end
			 else begin
				$display("============================================================================");
				$display("\n \\(^o^)/ CONGRATULATIONS!!  The simulation result is PASS!!!\n");
				$display("============================================================================");
			end
		end
	end

	always@( curstate  or curaddr)	// ROM for correct result
	begin
		answer = 0;
		testaddr = 0;
		case( curaddr )
		6'd0 :begin
			answer = 32'd2;
			testaddr = 30'd0;
		end
		6'd1 :begin
			answer = 32'd6;
			testaddr = 30'd1;
		end
		6'd2 :begin
			answer = 32'd24;
			testaddr = 30'd2;
		end
		6'd3 :begin
			answer = 32'd120;
			testaddr = 30'd3;
		end
		6'd4 :begin
			answer = 32'd720;
			testaddr = 30'd4;
		end
		6'd5 :begin
			answer = 32'd5040;
			testaddr = 30'd5;
		end
		6'd6 :begin
			answer = 32'd40320;
			testaddr = 30'd6;
		end
		6'd7 :begin
			answer = 32'd20160;
			testaddr = 30'd7;
		end
		6'd8 :begin
			answer = 32'd0;
			testaddr = 30'd8;
		end
		6'd9 :begin
		    answer = 32'd8064;
			testaddr = 30'd9;
		end
		6'd10:begin
		    answer = 32'd0;
			testaddr = 30'd10;
		end
		6'd11:begin
		    answer = 32'd3665;
			testaddr = 30'd11;
		end
		6'd12:begin
		    answer = 32'd5;
			testaddr = 30'd12;
		end
		endcase
	end
endmodule
