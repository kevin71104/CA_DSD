module cacheL1(
    clk,
    proc_reset,
    proc_read,
    proc_write,
    proc_addr,
    proc_wdata,
    proc_stall,
    proc_rdata,
    mem_read,
    mem_write,
    mem_addr,
    mem_rdata,
    mem_wdata,
    mem_ready
);

//==== input/output definition ============================
    input          clk;
    // processor interface
    input          proc_reset;
    input          proc_read, proc_write;
    input   [29:0] proc_addr;
    input   [31:0] proc_wdata;
    output         proc_stall;
    output  [31:0] proc_rdata;
    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output         mem_read, mem_write;
    output  [27:0] mem_addr;
    output [127:0] mem_wdata;

//==== wire/reg definition ================================
    // 8 blocks with 4 words
    parameter WAY_NUM = 3; // 2-way: 1, 4-way: 2, 8-way: 3
    parameter SET_NUM = 8 >> WAY_NUM;
    
    reg  [127:0] block[7:0];
    reg  [127:0] block_next;
    reg          blockvalid[7:0];
    reg          blockvalid_next;
    reg          blockdirty[7:0];
    reg          blockdirty_next;
    reg  [27:0]  blocktag[7:0];
    reg  [27:0]  blocktag_next;
    reg   [2:0]  blockrelease[7:0];
    reg   [2:0]  blockrelease_next[7:0];

    //output
    //processor interface
    reg		[31:0] proc_rdata;
    reg	        proc_stall;
    //memory interface
    reg            mem_read,mem_write;
    reg	    [27:0] mem_addr;
    reg	   [127:0] mem_wdata;

    // MUX-output
    reg   [27:0] tag;
    reg          valid;
    reg          dirty;
    reg  [127:0] blockdata;
    reg    [2:0] releaseb;

    // divide proc_addr_r into 3 wire
    wire  [1:0] wordIndex;
    wire  [2:0] setIndex;
    wire [27:0] dataTag;

    reg  [2:0] blockIndex;
    reg  [2:0] blockIndex_prev;
    reg        hit;

    integer i;

//==== combinational circuit ==============================
    assign wordIndex  = proc_addr[1:0];
    assign setIndex   = (WAY_NUM == 3)? 0:(WAY_NUM == 2)? {{2{1'b0}},proc_addr[2]}:{1'b0, proc_addr[3:2]};
    assign dataTag    = (WAY_NUM == 3)? proc_addr[29:2]:(WAY_NUM == 2)? {{1{1'b0}},proc_addr[29:3]}:{{2{1'b0}},proc_addr[29:4]};

    // read/write in cache
	always@(*) begin
		//default
		mem_read   = 0;
		mem_write  = 0;
		mem_addr   = 0;
		mem_wdata  = 0;
		proc_stall = 0;
		proc_rdata = 0;

    		blockIndex = setIndex << WAY_NUM;

		hit = 0;
		valid = 1;
		
		for (i=0;i<(1<<WAY_NUM);i=i+1) begin
			if (~hit) begin
				if (valid) begin
					if (blockrelease[blockIndex] > blockrelease[(setIndex << WAY_NUM)+i]) begin
						blockIndex = (setIndex << WAY_NUM)+i;
					end
					if (blockvalid[(setIndex << WAY_NUM)+i] == 0) begin
						valid = 0;
						blockIndex = (setIndex << WAY_NUM)+i;
					end
				end
				if (blocktag[(setIndex << WAY_NUM)+i] == dataTag) begin
					hit = 1;
					blockIndex = (setIndex << WAY_NUM)+i;
				end 
			end 
		end
    		
		tag   = blocktag[blockIndex];
		valid = blockvalid[blockIndex];
		dirty = blockdirty[blockIndex];
		releaseb  = blockrelease[blockIndex];
		hit = (tag == dataTag) ? 1: 0;
		blockdata = block[blockIndex];
	        
		block_next = block[blockIndex];
        	blockvalid_next = blockvalid[blockIndex];
        	blockdirty_next = blockdirty[blockIndex];
        	blocktag_next = blocktag[blockIndex];
		for (i=0;i<=7;i=i+1) begin
       			blockrelease_next[i] = blockrelease[i];
		end

		//read or write
		if (proc_read || proc_write)begin
			if (valid == 1) begin
				if(hit)begin
                    			//read hit
					if(proc_read && ~proc_write) begin
						case(wordIndex)
							2'd0: proc_rdata = blockdata[31:0];
							2'd1: proc_rdata = blockdata[63:32];
							2'd2: proc_rdata = blockdata[95:64];
							2'd3: proc_rdata = blockdata[127:96];
						endcase
						if (blockIndex != blockIndex_prev) begin
							for (i=0;i<(1<<WAY_NUM);i=i+1) begin
								if(blockrelease[(setIndex << WAY_NUM)+i]> 0)begin
									blockrelease_next[(setIndex << WAY_NUM)+i] = blockrelease[(setIndex << WAY_NUM)+i]-1;
								end else begin
									blockrelease_next[(setIndex << WAY_NUM)+i] = blockrelease[(setIndex << WAY_NUM)+i];
								end
							end
						end
						blockrelease_next[blockIndex] = (1<<WAY_NUM)-1;
						proc_stall = 0;
					end
					//write hit
					else if(~proc_read && proc_write)begin
						case(wordIndex)
							2'd0: block_next[31:0]   = proc_wdata;
							2'd1: block_next[63:32]  = proc_wdata;
							2'd2: block_next[95:64]  = proc_wdata;
							2'd3: block_next[127:96] = proc_wdata;
						endcase
						if (blockIndex != blockIndex_prev) begin
							for (i=0;i<(1<<WAY_NUM);i=i+1) begin
								if(blockrelease[(setIndex << WAY_NUM)+i]> 0)begin
									blockrelease_next[(setIndex << WAY_NUM)+i] = blockrelease[(setIndex << WAY_NUM)+i]-1;
								end else begin
									blockrelease_next[(setIndex << WAY_NUM)+i] = blockrelease[(setIndex << WAY_NUM)+i];
								end
							end
						end
						blockrelease_next[blockIndex] = (1<<WAY_NUM)-1;
						blockdirty_next = 1;
						proc_stall = 0;
					end
				end
				else begin
					proc_stall = 1;
					// MISS
					if(dirty == 0) begin
						if(mem_ready == 0) begin
							mem_read = 1;
							mem_write = 0;
							mem_addr = proc_addr[29:2];
						end
						else begin
							mem_read  = 0;
							mem_write = 0;
							block_next = mem_rdata;
							blocktag_next = dataTag;
						end
					end
					// WB
					else begin
						if(mem_ready == 0 ) begin
							mem_read  = 0;
							mem_write = 1;	
							mem_addr =(WAY_NUM == 3)? tag:(WAY_NUM ==2)?{tag[26:0],setIndex[0]} :{tag[25:0],setIndex[1:0]};
                            				mem_wdata  = blockdata;
						end
						else begin
                            				mem_read   = 1'b0;
                            				mem_write  = 1'b0;
                            				blockdirty_next = 1'b0;
						end
					end
				end
			end
			//valid = 0
			else begin
				proc_stall = 1;
				if (mem_ready == 0) begin
					mem_read  = 1;
					mem_write = 0;
					mem_addr  = proc_addr[29:2];
				end
				else begin
					mem_read  = 0;
					mem_write = 0;
					block_next = mem_rdata;
					blocktag_next = dataTag;
					blockvalid_next = 1'b1;
					blockdirty_next = 1'b0;
				end
			end
		end

		// read=0 && write=0
		else begin
			mem_read   = 0;
			mem_write  = 0;
			mem_addr   = 0;
			mem_wdata  = 0;
			proc_stall = 0;
			proc_rdata = 0;
		end
	end

//==== sequential circuit =================================
	always@(posedge clk or posedge proc_reset) begin
		if(proc_reset)begin
			for (i=0;i<=7;i=i+1)begin
				blockdirty[i] <= 1'b0;
                		blockvalid[i] <= 1'b0;
				blockrelease[i] <= 1'b0;
            		end
			blockIndex_prev <=  0;
		end
        else begin
            	block[blockIndex] <= block_next;
            	blocktag[blockIndex] <= blocktag_next;
            	blockvalid[blockIndex] <= blockvalid_next;
        	blockdirty[blockIndex] <= blockdirty_next;
		blockIndex_prev        <=  blockIndex;
		
		for (i=0;i<8;i=i+1)begin
			blockrelease[i] <= blockrelease_next[i];
		end
	    end
	end

endmodule


module cacheL2(
    clk,
    proc_reset,
    proc_read,
    proc_write,
    proc_addr,
    proc_wdata,
    proc_stall,
    proc_rdata,
    mem_read,
    mem_write,
    mem_addr,
    mem_rdata,
    mem_wdata,
    mem_ready
);

//==== input/output definition ============================
    input          clk;
    // processor interface
    input          proc_reset;
    input          proc_read, proc_write;
    input   [29:0] proc_addr;
    input   [31:0] proc_wdata;
    output         proc_stall;
    output  [31:0] proc_rdata;
    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output         mem_read, mem_write;
    output  [27:0] mem_addr;
    output [127:0] mem_wdata;

//==== wire/reg definition ================================
    // 8 blocks with 4 words
    parameter WAY_NUM = 1; // 2-way: 1, 4-way: 2, 8-way: 3
    parameter SET_NUM = 8 >> WAY_NUM;
    
    reg  [127:0] block[63:0];
    reg  [127:0] block_next;
    reg          blockvalid[63:0];
    reg          blockvalid_next;
    reg          blockdirty[63:0];
    reg          blockdirty_next;
    reg  [25:0]  blocktag[63:0];
    reg  [2:0]  blocktag_next;
    reg   [2:0]  blockrelease[63:0];
    reg   [2:0]  blockrelease_next[63:0];

    //output
    //processor interface
    reg		[31:0] proc_rdata;
    reg	        proc_stall;
    //memory interface
    reg            mem_read,mem_write;
    reg	    [27:0] mem_addr;
    reg	   [127:0] mem_wdata;

    // MUX-output
    reg   [27:0] tag;
    reg          valid;
    reg          dirty;
    reg  [127:0] blockdata;
    reg    [2:0] releaseb;

    // divide proc_addr_r into 3 wire
    wire  [1:0] wordIndex;
    wire  [5:0] setIndex;
    wire [27:0] dataTag;

    reg  [5:0] blockIndex;
    reg  [5:0] blockIndex_prev;
    reg        hit;

    integer i;

//==== combinational circuit ==============================
    assign wordIndex  = proc_addr[1:0];
    //assign setIndex   = (WAY_NUM == 3)? 0:(WAY_NUM == 2)? {{2{1'b0}},proc_addr[2]}:{1'b0, proc_addr[3:2]};
    //assign dataTag    = (WAY_NUM == 3)? proc_addr[29:2]:(WAY_NUM == 2)? {{1{1'b0}},proc_addr[29:3]}:{{2{1'b0}},proc_addr[29:4]};
    assign setIndex   = {{WAY_NUM{1'b0}},proc_addr[7-WAY_NUM:2]};
    assign dataTag    = {{{4-WAY_NUM}{1'b0}},proc_addr[29:(6-WAY_NUM)]};

    // read/write in cache
	always@(*) begin
		//default
		mem_read   = 0;
		mem_write  = 0;
		mem_addr   = 0;
		mem_wdata  = 0;
		proc_stall = 0;
		proc_rdata = 0;

    		blockIndex = setIndex << WAY_NUM;

		hit = 0;
		valid = 1;
		
		for (i=0;i<(1<<WAY_NUM);i=i+1) begin
			if (~hit) begin
				if (valid) begin
					if (blockrelease[blockIndex] > blockrelease[(setIndex << WAY_NUM)+i]) begin
						blockIndex = (setIndex << WAY_NUM)+i;
					end
					if (blockvalid[(setIndex << WAY_NUM)+i] == 0) begin
						valid = 0;
						blockIndex = (setIndex << WAY_NUM)+i;
					end
				end
				if (blocktag[(setIndex << WAY_NUM)+i] == dataTag) begin
					hit = 1;
					blockIndex = (setIndex << WAY_NUM)+i;
				end 
			end 
		end
    		
		tag   = blocktag[blockIndex];
		valid = blockvalid[blockIndex];
		dirty = blockdirty[blockIndex];
		releaseb  = blockrelease[blockIndex];
		hit = (tag == dataTag) ? 1: 0;
		blockdata = block[blockIndex];
	        
		block_next = block[blockIndex];
        	blockvalid_next = blockvalid[blockIndex];
        	blockdirty_next = blockdirty[blockIndex];
        	blocktag_next = blocktag[blockIndex];
		for (i=0;i<64;i=i+1) begin
       			blockrelease_next[i] = blockrelease[i];
		end

		//read or write
		if (proc_read || proc_write)begin
			if (valid == 1) begin
				if(hit)begin
                    			//read hit
					if(proc_read && ~proc_write) begin
						case(wordIndex)
							2'd0: proc_rdata = blockdata[31:0];
							2'd1: proc_rdata = blockdata[63:32];
							2'd2: proc_rdata = blockdata[95:64];
							2'd3: proc_rdata = blockdata[127:96];
						endcase
						if (blockIndex != blockIndex_prev) begin
							for (i=0;i<(1<<WAY_NUM);i=i+1) begin
								if(blockrelease[(setIndex << WAY_NUM)+i]> 0)begin
									blockrelease_next[(setIndex << WAY_NUM)+i] = blockrelease[(setIndex << WAY_NUM)+i]-1;
								end else begin
									blockrelease_next[(setIndex << WAY_NUM)+i] = blockrelease[(setIndex << WAY_NUM)+i];
								end
							end
						end
						blockrelease_next[blockIndex] = (1<<WAY_NUM)-1;
						proc_stall = 0;
					end
					//write hit
					else if(~proc_read && proc_write)begin
						case(wordIndex)
							2'd0: block_next[31:0]   = proc_wdata;
							2'd1: block_next[63:32]  = proc_wdata;
							2'd2: block_next[95:64]  = proc_wdata;
							2'd3: block_next[127:96] = proc_wdata;
						endcase
						if (blockIndex != blockIndex_prev) begin
							for (i=0;i<(1<<WAY_NUM);i=i+1) begin
								if(blockrelease[(setIndex << WAY_NUM)+i]> 0)begin
									blockrelease_next[(setIndex << WAY_NUM)+i] = blockrelease[(setIndex << WAY_NUM)+i]-1;
								end else begin
									blockrelease_next[(setIndex << WAY_NUM)+i] = blockrelease[(setIndex << WAY_NUM)+i];
								end
							end
						end
						blockrelease_next[blockIndex] = (1<<WAY_NUM)-1;
						blockdirty_next = 1;
						proc_stall = 0;
					end
				end
				else begin
					proc_stall = 1;
					// MISS
					if(dirty == 0) begin
						if(mem_ready == 0) begin
							mem_read = 1;
							mem_write = 0;
							mem_addr = proc_addr[29:2];
						end
						else begin
							mem_read  = 0;
							mem_write = 0;
							block_next = mem_rdata;
							blocktag_next = dataTag;
						end
					end
					// WB
					else begin
						if(mem_ready == 0 ) begin
							mem_read  = 0;
							mem_write = 1;	
							//mem_addr =(WAY_NUM == 3)? tag:(WAY_NUM ==2)?{tag[26:0],setIndex[0]} :{tag[25:0],setIndex[1:0]};
							mem_addr   = {tag[21+WAY_NUM:0], setIndex[5-WAY_NUM:0]}; 
                            				mem_wdata  = blockdata;
						end
						else begin
                            				mem_read   = 1'b0;
                            				mem_write  = 1'b0;
                            				blockdirty_next = 1'b0;
						end
					end
				end
			end
			//valid = 0
			else begin
				proc_stall = 1;
				if (mem_ready == 0) begin
					mem_read  = 1;
					mem_write = 0;
					mem_addr  = proc_addr[29:2];
				end
				else begin
					mem_read  = 0;
					mem_write = 0;
					block_next = mem_rdata;
					blocktag_next = dataTag;
					blockvalid_next = 1'b1;
					blockdirty_next = 1'b0;
				end
			end
		end

		// read=0 && write=0
		else begin
			mem_read   = 0;
			mem_write  = 0;
			mem_addr   = 0;
			mem_wdata  = 0;
			proc_stall = 0;
			proc_rdata = 0;
		end
	end

//==== sequential circuit =================================
	always@(posedge clk or posedge proc_reset) begin
		if(proc_reset)begin
			for (i=0;i<64;i=i+1)begin
				blockdirty[i] <= 1'b0;
                		blockvalid[i] <= 1'b0;
				blockrelease[i] <= 1'b0;
            		end
			blockIndex_prev <=  0;
		end
        else begin
            	block[blockIndex] <= block_next;
            	blocktag[blockIndex] <= blocktag_next;
            	blockvalid[blockIndex] <= blockvalid_next;
        	blockdirty[blockIndex] <= blockdirty_next;
		blockIndex_prev        <=  blockIndex;
		
		for (i=0;i<64;i=i+1)begin
			blockrelease[i] <= blockrelease_next[i];
		end
	    end
	end

endmodule
