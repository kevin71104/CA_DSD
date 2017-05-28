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
    reg  [127:0] block[7:0];
    reg  [127:0] block_next;
    reg          blockvalid[7:0];
    reg          blockvalid_next;
    reg          blockdirty[7:0];
    reg          blockdirty_next;
    reg  [24:0]  blocktag[7:0];
    reg  [24:0]  blocktag_next;
	//output
	//processor interface
	reg		[31:0] proc_rdata;
	reg			   proc_stall;
	//memory interface
	reg			   mem_read,mem_write;
	reg		[27:0] mem_addr;
	reg	   [127:0] mem_wdata;

    // MUX-output
    wire  [24:0]  tag;
    wire          valid;
    wire          dirty;
    wire  [127:0] blockdata;

    // divide proc_addr_r into 3 wire
    wire  [1:0] wordIndex;
    wire  [2:0] blockIndex;
    wire [24:0] dataTag;

    wire hit;

	integer i;
    //test
    wire          dirtyvibe;

//==== combinational circuit ==============================

    assign dirtyvibe = blockdirty_next;

    assign wordIndex  = proc_addr[1:0];
    assign blockIndex = proc_addr[4:2];
    assign dataTag    = proc_addr[29:5];

    assign tag = blocktag[blockIndex];
    assign valid = blockvalid[blockIndex];
    assign dirty = blockdirty[blockIndex];
    assign blockdata = block[blockIndex];

    assign hit = (tag == dataTag) ? 1 :0;

    // read/write in cache
	always@(*) begin
		//default
		mem_read   = 0;
		mem_write  = 0;
		mem_addr   = 0;
		mem_wdata  = 0;
		proc_stall = 1;
		proc_rdata = 0;

        block_next = block[blockIndex];
        blockvalid_next = blockvalid[blockIndex];
        blockdirty_next = blockdirty[blockIndex];
        blocktag_next = blocktag[blockIndex];
		//read
		if (proc_read || proc_write)begin
			//if valid = 1
			if (valid == 1) begin
				//if tag same, get value from cache
				//read hit
				if(hit)begin
					if(proc_read && ~proc_write) begin
						case(wordIndex)
							2'd0: proc_rdata = blockdata[31:0];
							2'd1: proc_rdata = blockdata[63:32];
							2'd2: proc_rdata = blockdata[95:64];
							2'd3: proc_rdata = blockdata[127:96];
						endcase
						proc_stall = 0;
					end
					//proc_write
					else if(~proc_read && proc_write)begin
						case(wordIndex)
							2'd0: block_next[31:0]   = proc_wdata;
							2'd1: block_next[63:32]  = proc_wdata;
							2'd2: block_next[95:64]  = proc_wdata;
							2'd3: block_next[127:96] = proc_wdata;
						endcase
						blockdirty_next = 1;//D=1
						proc_stall = 0;
					end
				end
				//if tags aren't same
				else begin
					proc_stall = 1;
					//dirty=0
					if(dirty == 0) begin
						if(mem_ready == 0) begin
							mem_read = 1;
							mem_write = 0;
							mem_addr = proc_addr[29:2];
						end
						//ready=1
						else begin
							//stop mem
							mem_read  = 0;
							mem_write = 0;
							//write data from mem into cache
							block_next = mem_rdata;
							blocktag_next = dataTag;
							//then go to read hit
						end
					end
					//dirty=1,write back
					else begin
						//write data into mem
						if(mem_ready == 0 ) begin
							mem_read  = 0;
							mem_write = 1;
                            mem_addr   = {tag[24:0],blockIndex[2:0]};
                            mem_wdata  = blockdata;
						end
						//after finishing write back, get value from mem
						else begin
                            //mem_read   = 1'b0;
                            //mem_write  = 1'b0;
                            blockdirty_next = 1'b0;
						end
					end
				end
			end
			//valid = 0,read miss, need to get value from memory
			else begin
				proc_stall = 1;
				//get value from mem
				if (mem_ready == 0) begin
					mem_read  = 1;
					mem_write = 0;
					mem_addr  = proc_addr[29:2];
				end
				//write data from mem into cach,and read
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
			proc_stall = 1;
			proc_rdata = 0;
		end
	end

//==== sequential circuit =================================

	always@(posedge clk or posedge proc_reset) begin
		if(proc_reset)begin
			for (i=0;i<=7;i=i+1)begin
				blockdirty[i] <= 1'b0;
                blockvalid[i] <= 1'b0;
            end

		end
        else begin
            block[blockIndex] <= block_next;
            blocktag[blockIndex] <= blocktag_next;
            blockvalid[blockIndex] <= blockvalid_next;
            blockdirty[blockIndex] <= blockdirty_next;
		end
	end

endmodule
