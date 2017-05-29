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
    input   [29:0] proc_addr; //retrieve byte offset
    input   [31:0] proc_wdata;
    output         proc_stall;
    output  [31:0] proc_rdata;

    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output         mem_read, mem_write;
    output  [27:0] mem_addr;
    output [127:0] mem_wdata;

    integer    i;
    // state parameters
    parameter  JUDGE   = 3'd0;
    parameter  WB      = 3'd1;
    parameter  MISS    = 3'd2;
    parameter  HIT     = 3'd3;
    parameter  STALL   = 3'd4;
//==== wire/reg definition ================================
    // internal FF
    // 8 blocks with 4 words
    reg  [127:0] block[7:0];
    reg  [127:0] block_next;
    reg          blockvalid[7:0];
    reg          blockvalid_next;
    reg          blockdirty[7:0];
    reg          blockdirty_next;
    reg  [24:0]  blocktag[7:0];
    reg  [24:0]  blocktag_next;
    reg   [2:0]  state, state_next;

    // input FF (*_r <= *)
    reg         proc_read_r, proc_write_r, mem_ready_r;
    reg [127:0] mem_rdata_r;
    reg  [29:0] proc_addr_r; //retrieve byte offset
    reg  [31:0] proc_wdata_r;

    // output FF ( * <= *_next)
    reg         mem_read, mem_read_next;
    reg         mem_write, mem_write_next;
    reg         proc_stall, proc_stall_next;
    reg  [27:0] mem_addr, mem_addr_next;
    reg [127:0] mem_wdata, mem_wdata_next;
    reg  [31:0] proc_rdata, proc_rdata_next;

    // MUX-output
    wire  [24:0]  tag;
    wire          valid;
    wire          dirty;
    wire  [127:0] blockdata;

    // divide proc_addr_r into 3 wire
    wire  [1:0] wordIndex;
    wire  [2:0] blockIndex;
    wire [24:0] dataTag;

    // comparator's pin
    wire        hit;
    //wire        match;

//==== submodules =========================================

//==== combinational circuit ==============================
    // divide proc_addr_r into 3 parts
    assign wordIndex  = proc_addr_r[1:0];
    assign blockIndex = proc_addr_r[4:2];
    assign dataTag    = proc_addr_r[29:5];

    // comparator's pin
    //assign match = (tag == dataTag) ? 1 : 0;
    //assign hit = ~valid ? 0 : match ;
    assign hit = valid ? (tag == dataTag) : 0;

    // finite state machine
    always@(*)begin
        // prevent output LATCH
        state_next = JUDGE;
        proc_stall_next = 1'b1;
        mem_read_next   = 1'b0;
        mem_write_next  = 1'b0;
        proc_rdata_next = proc_rdata;
        mem_addr_next   = mem_addr;
        mem_wdata_next  = mem_wdata;
        case(state)
            MISS:
                begin
                    if(mem_ready_r)begin
                        state_next = HIT;
                        proc_stall_next = 1'b0;
                        mem_read_next   = 1'b0;
                        mem_write_next  = 1'b0;
                        case(wordIndex)
                                2'd0:
                                    proc_rdata_next = mem_rdata_r[31:0];
                                2'd1:
                                    proc_rdata_next = mem_rdata_r[63:32];
                                2'd2:
                                    proc_rdata_next = mem_rdata_r[95:64];
                                2'd3:
                                    proc_rdata_next = mem_rdata_r[127:96];
                        endcase
                    end
                    else begin
                        state_next = MISS;
                        proc_stall_next = 1'b1;
                        mem_read_next   = 1'b1;
                        mem_write_next  = 1'b0;
                        mem_addr_next = {proc_addr_r[29:2]}; //miss
                    end
                end
            JUDGE:
                begin
                    if(hit)begin
                        state_next = HIT;
                        proc_stall_next = 1'b0;
                        mem_read_next   = 1'b0;
                        mem_write_next  = 1'b0;
                        // READ
                        if(proc_read_r && ~proc_write_r)begin
                            case(wordIndex)
                                2'd0:
                                    proc_rdata_next = blockdata[31:0];
                                2'd1:
                                    proc_rdata_next = blockdata[63:32];
                                2'd2:
                                    proc_rdata_next = blockdata[95:64];
                                2'd3:
                                    proc_rdata_next = blockdata[127:96];
                            endcase
                        end
                    end
                    else if(dirty && ~hit)begin
                        state_next = WB;
                        proc_stall_next = 1'b1;
                        mem_read_next   = 1'b0;
                        mem_write_next  = 1'b1;
                        mem_addr_next = {tag[24:0],blockIndex[2:0]}; //WB
                        mem_wdata_next = blockdata;
                    end
                    else if(~dirty && ~hit)begin
                        state_next = MISS;
                        proc_stall_next = 1'b1;
                        mem_read_next   = 1'b1;
                        mem_write_next  = 1'b0;
                        mem_addr_next = {proc_addr_r[29:2]}; //miss
                    end
                end
            WB:
                begin
                    if(mem_ready_r)begin
                        state_next = MISS;
                        proc_stall_next = 1'b1;
                        mem_read_next   = 1'b1;
                        mem_write_next  = 1'b0;
                        mem_addr_next = {proc_addr_r[29:2]}; //miss
                    end
                    else if((~mem_ready_r))begin
                        state_next = WB;
                        proc_stall_next = 1'b1;
                        mem_read_next   = 1'b0;
                        mem_write_next  = 1'b1;
                        mem_addr_next = {tag[24:0],blockIndex[2:0]}; //WB
                    end
                end
            HIT:
                begin
                    state_next = STALL;
                    proc_stall_next = 1'b1;
                    mem_read_next   = 1'b0;
                    mem_write_next  = 1'b0;
                end
            STALL:
                begin
                    state_next = JUDGE;
                    proc_stall_next = 1'b1;
                    mem_read_next   = 1'b0;
                    mem_write_next  = 1'b0;
                end
            default:
                begin
                    state_next = JUDGE;
                    proc_stall_next = 1'b1;
                    mem_read_next   = 1'b0;
                    mem_write_next  = 1'b0;
                end
        endcase
    end

    // tag, valid, dirty MUX
    assign tag = blocktag[blockIndex];
    assign valid = blockvalid[blockIndex];
    assign dirty = blockdirty[blockIndex];
    assign blockdata = block[blockIndex];

    // get original FF content
    always@(*)begin
        block_next = blockdata;
        blockvalid_next = valid;
        blockdirty_next = dirty;
        blocktag_next = tag;

        if(state == MISS)begin
            if(mem_ready_r)begin
                block_next = mem_rdata_r; // provide rdata early
                blocktag_next = dataTag;  // update block tag
                blockdirty_next = 1'b0;   // update block dirty
                blockvalid_next = 1'b1;   // update block valid
            end
        end
        if(state == HIT)begin
            //write
            if(~proc_read_r && proc_write_r)begin
                case(wordIndex)
                    2'd0: block_next[31:0]   = proc_wdata_r;
                    2'd1: block_next[63:32]  = proc_wdata_r;
                    2'd2: block_next[95:64]  = proc_wdata_r;
                    2'd3: block_next[127:96] = proc_wdata_r;
                endcase
                blockdirty_next = 1'b1;
            end
        end
    end
//==== sequential circuit =================================
    always@( posedge clk or posedge proc_reset) begin
        //====== asynchronous reset should only contain if-else block,
        //====== anything beyond these scopes is prohibited.
        if(proc_reset)begin
            state <= JUDGE;
            for(i=0;i<=7;i=i+1)begin
                blockvalid[i] <= 1'b0;
                blockdirty[i] <= 1'b0;
            end
		end
        else begin
            state <= state_next;
            //internal FF
            block[blockIndex] <= block_next;
            blocktag[blockIndex] <= blocktag_next;
            blockvalid[blockIndex] <= blockvalid_next;
            blockdirty[blockIndex] <= blockdirty_next;
        end
    end

    always@( posedge clk)begin
        // input to input register
        proc_read_r  <= proc_read;
        proc_write_r <= proc_write;
        proc_addr_r  <= proc_addr;
        proc_wdata_r <= proc_wdata;
        mem_ready_r  <= mem_ready;
        mem_rdata_r  <= mem_rdata;

        // output
        mem_read  <= mem_read_next;
        mem_write <= mem_write_next;
        mem_addr  <= mem_addr_next;
        mem_wdata <= mem_wdata_next;

        proc_stall <= proc_stall_next;
        proc_rdata <= proc_rdata_next;
    end

endmodule
