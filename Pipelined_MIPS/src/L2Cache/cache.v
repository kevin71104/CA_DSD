module cache(
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
    //parameter WAY_NUM = 3; // 2-way: 1, 4-way: 2, 8-way: 3
    //parameter SET_NUM = 8 >> WAY_NUM;
    
    reg  [127:0] block[7:0];
    reg  [127:0] block_next;
    reg          blockvalid[7:0];
    reg          blockvalid_next;
    reg          blockdirty[7:0];
    reg          blockdirty_next;
    reg  [25:0]  blocktag[7:0];
    reg  [25:0]  blocktag_next;
    reg          blockrelease[7:0];
    reg          blockrelease_next[7:0];

    //output
    //processor interface
    reg		[31:0] proc_rdata;
    reg            proc_stall;
    //memory interface
    reg            mem_read_L2,mem_write_L2;
    reg	    [27:0] mem_addr_L2;
    reg	   [127:0] mem_wdata_L2;

    // MUX-output
    wire   [25:0] tag;
    wire          valid;
    wire          dirty;
    wire  [127:0] blockdata;
    //wire          releaseb;
    wire          hit;

    wire   [25:0] tag1;
    wire          valid1;
    wire          releaseb1;
    wire          hit1;

    wire   [25:0] tag2;
    wire          valid2;
    wire          releaseb2;
    wire          hit2;

    // divide proc_addr_r into 3 wire
    wire  [1:0] wordIndex;
    wire  [2:0] setIndex;
    wire  [2:0] blockIndex_base;
    wire [25:0] dataTag;
    wire  [2:0] blockIndex;

    
    reg  [2:0] blockIndex_prev;
    integer i;
    integer j;

    // Wires to L2 cache
    wire         L2_read, L2_write;
    wire  [27:0] L2_addr;
    wire [127:0] L2_wdata;
    // Wires from L2 cache
    wire         L2_stall;
    wire [127:0]  L2_rdata;
    
    // For Debug
    wire   [23:0] tag_L2;
    wire          valid_L2;
    wire          dirty_L2;
    wire  [127:0] blockdata_L2;
    wire          hit_L2;
//==== L2 cache declaration ==============================
L2cache l2_cache(
    .clk(clk),
    .proc_reset(proc_reset),
    .proc_read(L2_read),
    .proc_write(L2_write),
    .proc_addr(L2_addr),
    .proc_wdata(L2_wdata),
    .proc_stall(L2_stall),
    .proc_rdata(L2_rdata),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .mem_addr(mem_addr),
    .mem_rdata(mem_rdata),
    .mem_wdata(mem_wdata),
    .mem_ready(mem_ready),
    .L1_stall(proc_stall),
    .tag_L2(tag_L2),
    .valid_L2(valid_L2),
    .dirty_L2(dirty_L2),
    .blockdata_L2(blockdata_L2),
    .hit_L2(hit_L2)
);
//==== combinational circuit ==============================
	// Assign wires to L2 cache
    assign L2_read = mem_read_L2;
    assign L2_write = mem_write_L2;
    assign L2_addr = mem_addr_L2;
    assign L2_wdata = mem_wdata_L2;

    // Assign wires in L1 cache
    assign wordIndex  = proc_addr[1:0];
    assign setIndex   = {1'b0,proc_addr[3:2]};
    assign blockIndex_base = setIndex << 1;
    assign dataTag    = proc_addr[29:4];

    assign tag1 = blocktag[blockIndex_base];
    assign valid1 = blockvalid[blockIndex_base];
    assign releaseb1 = blockrelease[blockIndex_base];
    assign hit1 = (tag1 == dataTag) ? 1 :0;

    assign tag2 = blocktag[blockIndex_base+1];
    assign valid2 = blockvalid[blockIndex_base+1];
    assign releaseb2 = blockrelease[blockIndex_base+1];
    assign hit2 = (tag2 == dataTag) ? 1 :0;

    assign blockIndex = (hit1 == 1)? blockIndex_base
                       :(hit2 == 1)? blockIndex_base+1
                       :(valid1 == 0)? blockIndex_base
                       :(valid2 == 0)? blockIndex_base+1
                       :(releaseb1 > releaseb2)? blockIndex_base+1
                       :blockIndex_base;
    assign tag = blocktag[blockIndex];
    assign valid = blockvalid[blockIndex];
    assign dirty = blockdirty[blockIndex];
    assign blockdata = block[blockIndex];
    assign hit = (tag == dataTag) ? 1 :0;
    
    // read/write in cache
	always@(*) begin
		//default
		mem_read_L2   = 0;
		mem_write_L2  = 0;
		//mem_addr_L2   = 0;
		mem_addr_L2  = proc_addr[29:2];
		//mem_wdata_L2  = 0;
                mem_wdata_L2  = blockdata;
		proc_stall = 0;
		proc_rdata = 0;

		block_next = block[blockIndex];
    	blockvalid_next = blockvalid[blockIndex];
        blockdirty_next = blockdirty[blockIndex];
        blocktag_next = blocktag[blockIndex];
		
		for (j=0;j<=7;j=j+1) begin 
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
						proc_stall = 0;
						if (blockIndex != blockIndex_prev) begin
							if(blockIndex == blockIndex_base)begin
                                if (blockrelease[blockIndex_base+1] > 0) begin
								    blockrelease_next[blockIndex_base+1] = blockrelease[blockIndex_base+1]-1;
							    end
                            end else begin
                                if (blockrelease[blockIndex_base] > 0) begin
                                    blockrelease_next[blockIndex_base] = blockrelease[blockIndex_base]-1;
                                end
                            end
						end
						blockrelease_next[blockIndex] = 1;
					end
					//write hit
					else if(~proc_read && proc_write)begin
						case(wordIndex)
							2'd0: block_next[31:0]   = proc_wdata;
							2'd1: block_next[63:32]  = proc_wdata;
							2'd2: block_next[95:64]  = proc_wdata;
							2'd3: block_next[127:96] = proc_wdata;
						endcase
						proc_stall = 0;
                        if (blockIndex != blockIndex_prev) begin
							if(blockIndex == blockIndex_base)begin
                                if (blockrelease[blockIndex_base+1] > 0) begin
								    blockrelease_next[blockIndex_base+1] = blockrelease[blockIndex_base+1]-1;
							    end
                            end else begin
                                if (blockrelease[blockIndex_base] > 0) begin
                                    blockrelease_next[blockIndex_base] = blockrelease[blockIndex_base]-1;
                                end
                            end
						end
						blockrelease_next[blockIndex] = 1;
						blockdirty_next = 1;
					end
				end
				else begin
					proc_stall = 1;
					// MISS
					if(dirty == 0) begin
					//$display("L1 in MISS !!!!!");
						if (hit_L2 && valid_L2) begin // concern some L2 info  
							mem_read_L2 = 1;
							mem_write_L2 = 0;
							mem_addr_L2 = proc_addr[29:2];
							block_next = L2_rdata; 
							blocktag_next = dataTag;
								
						end else begin
							if(mem_ready == 0) begin
								mem_read_L2 = 1;
								mem_write_L2 = 0;
								mem_addr_L2 = proc_addr[29:2];
							end else if (L2_stall == 0) begin
								mem_read_L2  = 0;
								mem_write_L2 = 0;
								block_next = L2_rdata; 
								blocktag_next = dataTag;
							end
						end
					end
					// WB
					else begin
					//$display("L1 in WB !!!!!");
						if (hit_L2 && valid_L2) begin // concern some L2 info  
							mem_read_L2  = 0;
							mem_write_L2 = 1;	
							mem_addr_L2 = {tag[25:0],setIndex[1:0]};
                            				mem_wdata_L2  = blockdata;
            						blockdirty_next = 1'b0;
						
						end else begin	
							if(mem_ready == 0) begin
								mem_read_L2  = 0;
								mem_write_L2 = 1;	
								mem_addr_L2 = {tag[25:0],setIndex[1:0]};
                            					mem_wdata_L2  = blockdata;
							end
							else if (L2_stall == 0) begin
                         	   				mem_read_L2   = 1'b0;
            							mem_write_L2  = 1'b0;
            							blockdirty_next = 1'b0;
							end
						end
					end
				end
			end
			//valid = 0
			else begin
				//$display("L1 in valid !!!!!");
				proc_stall = 1;
				if (hit_L2 && valid_L2) begin // concern some L2 info  
					mem_read_L2  = 1;
					mem_write_L2 = 0;
					mem_addr_L2  = proc_addr[29:2];
					block_next = L2_rdata;
					blocktag_next = dataTag;
					blockvalid_next = 1'b1;
					blockdirty_next = 1'b0;	
				end else begin
					if (mem_ready == 0) begin
						mem_read_L2  = 1;
						mem_write_L2 = 0;
						mem_addr_L2  = proc_addr[29:2];
					end else if (L2_stall == 0) begin
						mem_read_L2  = 0;
						mem_write_L2 = 0;
						block_next = L2_rdata;
						blocktag_next = dataTag;
						blockvalid_next = 1'b1;
						blockdirty_next = 1'b0;
					end
				end
			end
		end

		// read=0 && write=0
		else begin
			mem_read_L2   = 0;
			mem_write_L2  = 0;
			mem_addr_L2   = 0;
			mem_wdata_L2  = 0;
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
				blocktag[i]   <= 26'b1;
            end
                blockIndex_prev <=  0;
		end
        else begin
            	block[blockIndex] <= block_next;
            	blocktag[blockIndex] <= blocktag_next;
            	blockvalid[blockIndex] <= blockvalid_next;
                blockdirty[blockIndex] <= blockdirty_next;
                blockIndex_prev        <=  blockIndex;
		
		for (i=0;i<=7;i=i+1)begin
			blockrelease[i] <= blockrelease_next[i];
		end
	    end
	end

endmodule


module L2cache(
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
    mem_ready,
    L1_stall, 
 
    tag_L2,
    valid_L2,
    dirty_L2,
    blockdata_L2,
    hit_L2
);

//==== input/output definition ============================
    input          clk;
    // processor interface
    input          proc_reset;

    input          proc_read, proc_write;
    input   [27:0] proc_addr;
    input   [127:0] proc_wdata;
    input          L1_stall;

    output         proc_stall;
    output  [127:0] proc_rdata;
    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output         mem_read, mem_write;
    output  [27:0] mem_addr;
    output [127:0] mem_wdata;

    output   [23:0] tag_L2;
    output          valid_L2;
    output          dirty_L2;
    output  [127:0] blockdata_L2;
    output          hit_L2;

//==== wire/reg definition ================================
    // 8 blocks with 4 words
    //parameter WAY_NUM = 1; // 2-way: 1, 4-way: 2, 8-way: 3
    //parameter SET_NUM = 8 >> WAY_NUM;
    
    reg  [127:0] block[31:0];
    reg  [127:0] block_next;
    reg          blockvalid[31:0];
    reg          blockvalid_next;
    reg          blockdirty[31:0];
    reg          blockdirty_next;
    reg  [23:0]  blocktag[31:0];
    reg  [23:0]  blocktag_next;
    reg          blockrelease[31:0];
    reg          blockrelease_next[31:0];

    //output
    //processor interface
    reg  [127:0] proc_rdata;
    reg	         proc_stall;
    //memory interface
    reg            mem_read,mem_write;
    reg	    [27:0] mem_addr;
    reg	   [127:0] mem_wdata;

    // MUX-output
    wire   [23:0] tag_L2;
    wire          valid_L2;
    wire          dirty_L2;
    wire  [127:0] blockdata_L2;
    //wire          releaseb;
    wire          hit_L2;

    wire   [23:0] tag1_L2;
    wire          valid1_L2;
    wire          releaseb1_L2;
    wire          hit1_L2;

    wire   [23:0] tag2_L2;
    wire          valid2_L2;
    wire          releaseb2_L2;
    wire          hit2_L2;

    // divide proc_addr_r into 3 wire
    //wire  [1:0] wordIndex;
    wire  [4:0] setIndex_L2;
    wire  [4:0] blockIndex_base_L2;
    wire [23:0] dataTag_L2;
    wire  [4:0] blockIndex_L2;

    
    reg  [4:0] blockIndex_prev_L2;
    integer i;
    integer j;

//==== combinational circuit ==============================
    //assign wordIndex  = proc_addr[1:0];
    assign setIndex_L2   = {1'b0,proc_addr[3:0]};
    assign blockIndex_base_L2 = setIndex_L2 << 1;
    assign dataTag_L2    = proc_addr[27:4];

    assign tag1_L2 = blocktag[blockIndex_base_L2];
    assign valid1_L2 = blockvalid[blockIndex_base_L2];
    assign releaseb1_L2 = blockrelease[blockIndex_base_L2];
    assign hit1_L2 = (tag1_L2 == dataTag_L2) ? 1 :0;

    assign tag2_L2 = blocktag[blockIndex_base_L2+1];
    assign valid2_L2 = blockvalid[blockIndex_base_L2+1];
    assign releaseb2_L2 = blockrelease[blockIndex_base_L2+1];
    assign hit2_L2 = (tag2_L2 == dataTag_L2) ? 1 :0;

    assign blockIndex_L2 = (hit1_L2 == 1)? blockIndex_base_L2
                       :(hit2_L2 == 1)? blockIndex_base_L2+1
                       :(valid1_L2 == 0)? blockIndex_base_L2
                       :(valid2_L2 == 0)? blockIndex_base_L2+1
                       :(releaseb1_L2 > releaseb2_L2)? blockIndex_base_L2+1
                       :blockIndex_base_L2;
    assign tag_L2 = blocktag[blockIndex_L2];
    assign valid_L2 = blockvalid[blockIndex_L2];
    assign dirty_L2 = blockdirty[blockIndex_L2];
    assign blockdata_L2 = block[blockIndex_L2];
    assign hit_L2 = (tag_L2 == dataTag_L2) ? 1 :0;
    
    // read/write in cache
	always@(*) begin
		//default
		mem_read   = 0;
		mem_write  = 0;
		mem_addr   = 0;
		mem_wdata  = 0;
		proc_stall = 0;
		proc_rdata = 0;

		block_next = block[blockIndex_L2];
    	blockvalid_next = blockvalid[blockIndex_L2];
        blockdirty_next = blockdirty[blockIndex_L2];
        blocktag_next = blocktag[blockIndex_L2];
		
		for (j=0;j<=31;j=j+1) begin
       			blockrelease_next[i] = blockrelease[i];
		end

		//read or write
		//if (proc_read || proc_write)begin
			if (valid_L2 == 1) begin
				if(hit_L2)begin
                    //read hit
					if(proc_read && ~proc_write) begin
                        proc_rdata = blockdata_L2;
						proc_stall = 0;
						if (blockIndex_L2 != blockIndex_prev_L2) begin
							if(blockIndex_L2 == blockIndex_base_L2)begin
                                if (blockrelease[blockIndex_base_L2+1] > 0) begin
								    blockrelease_next[blockIndex_base_L2+1] = blockrelease[blockIndex_base_L2+1]-1;
							    end
                            end else begin
                                if (blockrelease[blockIndex_base_L2] > 0) begin
                                    blockrelease_next[blockIndex_base_L2] = blockrelease[blockIndex_base_L2]-1;
                                end
                            end
						end
						blockrelease_next[blockIndex_L2] = 1;
					end
					//write hit
					else if(~proc_read && proc_write)begin
                        block_next = proc_wdata;
						proc_stall = 0;
                        if (blockIndex_L2 != blockIndex_prev_L2) begin
                            if(blockIndex_L2 == blockIndex_base_L2)begin
                                if (blockrelease[blockIndex_base_L2+1] > 0) begin
                                    blockrelease_next[blockIndex_base_L2+1] = blockrelease[blockIndex_base_L2+1]-1;
                                end
                            end else begin
                                if (blockrelease[blockIndex_base_L2] > 0) begin
                                    blockrelease_next[blockIndex_base_L2] = blockrelease[blockIndex_base_L2]-1;
                                end
                            end
                        end
                        blockrelease_next[blockIndex_L2] = 1;
						blockdirty_next = 1;
					end
				end
				else begin
					proc_stall = 1;
					// MISS
					if(dirty_L2 == 0) begin
					//$display("L2 in MISS !!!!!");
						if(mem_ready == 0) begin
							mem_read = 1;
							mem_write = 0;
							mem_addr = proc_addr[27:0];
						end
						else begin
							mem_read  = 0;
							mem_write = 0;
							block_next = mem_rdata;
							blocktag_next = dataTag_L2;
						end
					end
					// WB
					else begin
					//$display("L2 in WB !!!!!");
						if(mem_ready == 0 ) begin
							mem_read  = 0;
							mem_write = 1;	
							mem_addr = {tag_L2[23:0],setIndex_L2[3:0]};
                            				mem_wdata  = blockdata_L2;
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
				//$display("L2 in valid !!!!!");
				proc_stall = 1;
				if (mem_ready == 0) begin
					mem_read  = 1;
					mem_write = 0;
					mem_addr  = proc_addr[27:0];
				end else begin
					mem_read  = 0;
					mem_write = 0;
					block_next = mem_rdata;
					blocktag_next = dataTag_L2;
					blockvalid_next = 1'b1;
					blockdirty_next = 1'b0;
				end
			end
		/*end

		// read=0 && write=0
		else begin
			mem_read   = 0;
			mem_write  = 0;
			mem_addr   = 0;
			mem_wdata  = 0;
			proc_stall = 0;
			proc_rdata = 0;
		end*/
	end

//==== sequential circuit =================================
	always@(negedge clk or posedge proc_reset) begin
		if(proc_reset)begin
			for (i=0;i<=31;i=i+1)begin
				blockdirty[i] <= 1'b0;
                blockvalid[i] <= 1'b0;
                blockrelease[i] <= 1'b0;
                blocktag[i]   <= 24'b1;
            end
            blockIndex_prev_L2 <=  0;
		end
        else begin
            	block[blockIndex_L2] <= block_next;
            	blocktag[blockIndex_L2] <= blocktag_next;
            	blockvalid[blockIndex_L2] <= blockvalid_next;
                blockdirty[blockIndex_L2] <= blockdirty_next;
                blockIndex_prev_L2        <=  blockIndex_L2;
		
		for (i=0;i<=31;i=i+1)begin
			blockrelease[i] <= blockrelease_next[i];
		end
	    end
	end


endmodule
