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
    parameter  MISS    = 2'd0;
    parameter  HIT     = 2'd1;
    parameter  WB      = 2'd2;
    parameter  PROCESS = 2'd3;
//==== wire/reg definition ================================
    // internal FF
    // 8 blocks with 4 words
    reg  [31:0] block[7:0][3:0], block_next[7:0][3:0];
    reg         blockvalid[7:0], blockvalid_next[7:0],
    reg         blockdirty[7:0], blockdirty_next[7:0];
    reg   [2:0] state, state_next;

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

    // divide proc_addr_r into 3 wire
    wire  [1:0] wordIndex;
    wire  [2:0] blockIndex;
    wire [24:0] dataTag;

    // comparator's pin
    wire        hit;
    reg  [24:0] tag;
    reg         valid;

    // writeback
    reg         dirty;

//==== submodules =========================================
    comparator i_comp(
        .dataTag(dataTag),
        .blockTag(tag),
        .valid(valid)
        .hit(hit)
    );

//==== combinational circuit ==============================
    // divide proc_addr_r into 3 parts
    wordIndex  = proc_addr_r[1:0];
    blockIndex = proc_addr_r[4:2];
    dataTag    = proc_addr_r[29:5];

    // finite state machine
    always@(*)begin
        case(state)
            MISS:
                begin
                    if(~mem_ready_r)begin
                        state_next = MISS;
                        proc_stall_next = 1'b1;
                    end
                    else begin
                        state_next = PROCESS;
                        proc_stall_next = 1'b0;
                    end
                end
            HIT:
                begin
                    if(hit)begin
                        state_next = PORCESS;
                        proc_stall_next = 1'b0;
                    end
                    else if(dirty && ~hit)begin
                        state_next = WB;
                        proc_stall_next = 1'b1;
                    end
                    else begin
                        state_next = MISS;
                        proc_stall_next = 1'b1;
                    end
                end
            WB:
                begin
                    if(mem_ready_r)begin
                        state_next = MISS;
                        proc_stall_next = 1'b1;
                    end
                    else begin
                        state_next = WB;
                        proc_stall_next = 1'b1;
                    end
                end
            PROCESS:
                begin
                    state_next = HIT;
                    proc_stall_next = 1'b1;
                end
            default:
                begin
                    state_next = PROCESS;
                    proc_stall_next = 1'b0;
                end
        endcase
    end

    // tag, valid, dirty MUX
    always@(*)begin
        tag = blocktag[blockindex];
        valid = blockvalid[blockindex];
        dirty = blockdirty[blockindex];
        case(blockIndex)
            3'd0:
                tag = blocktag[0];
                valid = blockvalid[0];
                dirty = blockdirty[0];
            3'd1:
                tag = blocktag[1];
                valid = blockvalid[1];
                dirty = blockdirty[1];
            3'd2:
                tag = blocktag[2];
                valid = blockvalid[2];
                dirty = blockdirty[2];
            3'd3:
                tag = blocktag[3];
                valid = blockvalid[3];
                dirty = blockdirty[3];
            3'd4:
                tag = blocktag[4];
                valid = blockvalid[4];
                dirty = blockdirty[4];
            3'd5:
                tag = blocktag[5];
                valid = blockvalid[5];
                dirty = blockdirty[5];
            3'd6:
                tag = blocktag[6];
                valid = blockvalid[6];
                dirty = blockdirty[6];
            3'd7:
                tag = blocktag[6];
                valid = blockvalid[7];
                dirty = blockdirty[7];
            default:
                tag = 25'd0;
                valid = 1'b0;
                dirty = 1'b0;
        endcase
    end

    //
    always@(*)begin
        for(i=0;i<=7;i=i+1)begin
            {block_next[i][3:0]} = {block[i][3:0]};
            blockvalid_next[i] = blockvalid[i];
            blockdirty_next[i] = blockdirty[i];
            blocktag_next[i] = blocktag[i];
        end
        if (state == PROCESS) begin
            if(proc_read_r && ~proc_write_r)begin
                proc_rdata_next =
            end

        end
    end
//==== sequential circuit =================================
    always@( posedge clk or posedge proc_reset ) begin
        if( proc_reset ) begin
            for(i=0;i<=7;i=i+1)begin
                blockvalid[i]  <= 1'b0;
                blockdirty[i]  <= 1'b0;
            end
            state_next = PROCESS;
            proc_stall_next = 1'b0;
        end
        else begin
            // output
            mem_read  <= mem_read_next;
            mem_write <= mem_write_next;
            mem_addr  <= mem_addr_next;
            mem_wdata <= mem_wdata_next;

            proc_stall <= proc_stall_next;
            proc_rdata <= proc_rdata_next;

            // state
            state <= state_next;

            //internal FF
        end
    end

    // input to input register
    always@( posedge clk)begin
        proc_read_r  <= proc_read;
        proc_write_r <= proc_write;
        proc_addr_r  <= proc_addr;
        proc_wdata_r <= proc_wdata;
        mem_ready_r  <= mem_ready;
        mem_rdata_r  <= mem_rdata;
    end

endmodule

module comparator(
    dataTag,
    blockTag,
    valid,
    hit
);

//==== in/out declaration =================================
    input    [24:0] dataTag;
    input    [24:0] blockTag;
    input           valid;
    output          hit;

    temp = (dataTag == blockTag)? 1 : 0;
    hit = valid ? temp : 0;
endmodule
