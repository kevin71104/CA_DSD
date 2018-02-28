module ALU(
	clk,
	rst_n,
	ALUOp_regD,
    funct_regD,
    ALUinA,
    ALUinB,
    ALUout,
	stall_muldiv
);
//==== input/output definition ============================
    input   [5:0] funct_regD;
    input   [5:0] ALUOp_regD;
    input  [31:0] ALUinA, ALUinB;
    output [31:0] ALUout;
	// I/O for Extension
	input         clk, rst_n;
	output        stall_muldiv;

//==== wire/reg definition ================================
    reg  [31:0] ALUout;
	// for Extension
	reg         sign_and, sign_and_next;   // signed bits for multiplicand or dividend
	reg         sign_er, sign_er_next;     // signed bits for multiplier or divisor
	reg   [6:0] state, state_next;
	reg  [31:0] reg_hi, reg_hi_next;
	reg  [31:0] reg_lo, reg_lo_next;
	reg  [31:0] operand, operand_next;     // multiplier or divisor
	wire [32:0] tempresult;                // result of the subALU
    reg         stall_muldiv;
	    //control part
    wire        action;                    // div always 1, mult depends on the multiplicand
	wire [31:0] subaluinA;
	wire [31:0] subaluinB;
	wire [63:0] result, result_com;
	wire [31:0] hi_com, lo_com;
//==== combinational circuits =============================
    assign action = reg_lo[0];
	assign subaluinA = reg_hi;
	assign subaluinB = (action | state[6] ) ? operand : 32'd0;
	assign tempresult = subaluinA + subaluinB;
	assign result = {reg_hi,reg_lo};
	//2's complement
	assign result_com = (~result) + 1;
	assign hi_com = (~reg_hi) + 1;
	assign lo_com = (~reg_lo) + 1;

	// FSM
	//state 0: idle
	//state 1-32: mult
	//state 33: turn {hi,lo} to 2's complement if necessary
	//state 65-96: div
	//state 97: turn hi & lo to 2's complement if necessary
	always@(*) begin
        stall_muldiv = 1'b1;
		state_next = state + 6'd1;
		sign_er_next = sign_er;
		sign_and_next = sign_and;
		operand_next = operand;
		reg_hi_next = reg_hi;
		reg_lo_next = reg_lo;
		if(state[6]) begin
			if(state[5:0] == 6'd33)begin
                if(tempresult[31])begin // < 0
				    reg_hi_next = {{reg_hi[30:0]}, reg_lo[31]};
					reg_lo_next = {{reg_lo[30:0]}, 1'b0};
				end
				else begin
				    reg_hi_next = tempresult[31:0];
				    reg_lo_next = {{reg_lo[30:0]}, 1'b1};
				end
                if(sign_and | sign_er)begin
                    state_next = 7'd97;
    				stall_muldiv = 1'b1;
                end
                else begin
                    state_next = 7'd0;
    				stall_muldiv = 1'b0;
                end
            end
            else if(state[5:0] == 6'd34) begin
                state_next = 7'd0;
				stall_muldiv = 1'b0;
                //  a =  b   *  c   +  d (a,b,c,d all > 0)
				if(sign_and & sign_er)begin         // -a = (-b) *  c   + (-d)
                    reg_lo_next = lo_com;
				end
				else if(sign_and & (~sign_er))begin // -a =  b   * (-c) + (-d)
				    reg_lo_next = lo_com;
					reg_hi_next = hi_com;
				end
				else if((~sign_and) & sign_er)begin //  a = (-b) * (-c) +  d
					reg_hi_next = hi_com;
				end
			end
			else begin
                if(tempresult[31])begin // < 0
				    reg_hi_next = {{reg_hi[30:0]}, reg_lo[31]};
					reg_lo_next = {{reg_lo[30:0]}, 1'b0};
				end
				else begin
				    reg_hi_next = {{tempresult[30:0]}, reg_lo[31]};
				    reg_lo_next = {{reg_lo[30:0]}, 1'b1};
				end
			end
		end
		else begin
		    if(state[5:0] == 6'd0)begin //idle
                stall_muldiv = 1'b0;
				sign_and_next = ALUinA[31];
				sign_er_next = ALUinB[31];
				reg_lo_next = ALUinA[31] ? ((~ALUinA) + 1) : ALUinA;
				reg_hi_next = 32'd0;
				if(funct_regD == 6'b011000) begin // mult
                    stall_muldiv = 1'b1;
				    state_next = 7'd1;
					operand_next = ALUinB[31] ? ((~ALUinB) + 1) : ALUinB;
				end
				else if(funct_regD == 6'b011010) begin // div
                    stall_muldiv= 1'b1;
				    state_next = 7'd65;
					operand_next = ALUinB[31] ? ALUinB : ((~ALUinB) + 1); // use add 2's to replace sub
                end
				else begin
				    state_next = 7'd0;
                    reg_lo_next = reg_lo;
    				reg_hi_next = reg_hi;
				end
			end
			else if(state[5:0] == 6'd32) begin
                reg_hi_next = tempresult[32:1];
                reg_lo_next = {tempresult[0],{reg_lo[31:1]}};
                if(sign_er ^ sign_and) begin
                    stall_muldiv = 1'b1;
                    state_next = 7'd33;
                end
                else begin
                    stall_muldiv = 1'b0;
                    state_next = 7'd0;
                end
			end
            else if(state[5:0] == 6'd33)begin
                stall_muldiv = 1'b0;
                state_next = 7'd0;
            end
			else begin
				reg_hi_next = tempresult[32:1];
				reg_lo_next = {tempresult[0],{reg_lo[31:1]}};
			end
		end
	end
	always@(*) begin
		ALUout = 32'b0;
		case(ALUOp_regD)
			//===== R-type ===============
        	6'b000000: begin
        		case(funct_regD)
     		       	6'b100000: begin // add
     		       		ALUout = ALUinA + ALUinB;
               		end
               		6'b100010: begin // sub
                   		ALUout = ALUinA - ALUinB;
        	        end
               		6'b100100: begin // and
                   		ALUout = ALUinA & ALUinB;
               		end
               		6'b100101: begin // or
                   		ALUout = ALUinA | ALUinB;
               		end
               		6'b100110: begin // xor
               			ALUout = ALUinA ^ ALUinB;
               		end
               		6'b100111: begin // nor
               			ALUout = ~(ALUinA | ALUinB);
               		end
               		6'b000000: begin // sll and nop?
               			ALUout = ALUinA << ALUinB;
               		end
               		6'b000011: begin // sra
               			ALUout = ALUinA >>> ALUinB;
               		end
               		6'b000010: begin // srl
               			ALUout = ALUinA >> ALUinB;
               		end
               		6'b101010: begin // slt
                   		ALUout = (ALUinA < ALUinB)? 32'b1: 32'b0;
               		end
               		6'b001000: begin // jr
            	   		ALUout = 32'b1;
               		end
               		6'b001001: begin // jalr
     		       	    ALUout = ALUinA + ALUinB;
               		end
					6'b010000: begin // mfhi
					    ALUout = reg_hi;
					end
					6'b010010: begin // mflo
					    ALUout = reg_lo;
					end
               		default: begin
		   				ALUout = 32'b0;
					end
           		endcase
       		end
        	//===== I-type ===============
        	6'b001000: begin // addi
        		ALUout = ALUinA + ALUinB;
        	end
        	6'b001100: begin // andi
				    ALUout = ALUinA & ALUinB;
        	end
        	6'b001101: begin // ori
        		ALUout = ALUinA | ALUinB;
        	end
        	6'b001110: begin // xori
				    ALUout = ALUinA ^ ALUinB;
        	end
        	6'b001010: begin // slti
        		ALUout = (ALUinA < ALUinB)? 32'b1: 32'b0;
        	end
        	6'b100011: begin // lw
        		ALUout = (ALUinA + ALUinB); // memory address (32 bits)
        	end
        	6'b101011: begin // sw
				    ALUout = (ALUinA + ALUinB); // memory address (32 bits)
        	end
       		6'b000100: begin //beq
		    		ALUout = (ALUinA - ALUinB);
       		end
        	//===== J-type ===============
        	6'b000010: begin // j
     				ALUout = 32'b1;
       		end
       		6'b000011: begin // jal
     		    ALUout = ALUinA + ALUinB;
        	end
			default: begin
 				ALUout = 32'b0;
			end
    	endcase
    end

//==== sequential circuits ================================
	always@( posedge clk or negedge rst_n )
    begin
        // active low asynchronous reset
        if( ~rst_n )begin
            sign_and <= 1'd0;
            sign_er  <= 1'd0;
            state    <= 7'd0;
            reg_hi   <= 32'd0;
            reg_lo   <= 32'd0;
            operand  <= 32'd0;
        end
        else begin
			sign_and <= sign_and_next;
            sign_er  <= sign_er_next;
            state    <= state_next;
            reg_hi   <= reg_hi_next;
            reg_lo   <= reg_lo_next;
            operand  <= operand_next;
        end
    end
endmodule
