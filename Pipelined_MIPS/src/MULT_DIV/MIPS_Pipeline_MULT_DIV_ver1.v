module MIPS_Pipeline(
    // control interface
    clk,
    rst_n,
//----------I cache interface-------
    ICACHE_ren,
    ICACHE_wen,
    ICACHE_addr,
    ICACHE_wdata,
    ICACHE_stall,
    ICACHE_rdata,
//----------D cache interface-------
    DCACHE_ren,
    DCACHE_wen,
    DCACHE_addr,
    DCACHE_wdata,
    DCACHE_stall,
    DCACHE_rdata
);

//==== input/output definition ============================
    input clk, rst_n;

    // I-cache interface
    input  [31:0] ICACHE_rdata;
    input         ICACHE_stall;
    output        ICACHE_wen;
    output        ICACHE_ren;
    output [29:0] ICACHE_addr;
    output [31:0] ICACHE_wdata;

    // D-cache interface
    input  [31:0] DCACHE_rdata;
    input         DCACHE_stall;
    output        DCACHE_wen;
    output        DCACHE_ren;
    output [29:0] DCACHE_addr;
    output [31:0] DCACHE_wdata;

//==== wire/reg definition ================================
    // PC part
    wire   [31:0] PCplus4;
    wire   [31:0] PCnext;
    wire   [31:0] PCcur;
    reg    [31:0] PCreg;
    wire    [2:0] PCsrc;

    // IF_DEC_regFile
    wire   [31:0] instruction_next;
    wire   [31:0] PCplus4_regI;
        // instruction decode
    wire    [4:0] Rs, Rt, Rd, shamt;
    wire    [5:0] opcode, funct;
    wire   [15:0] branchOffset_D;
    wire   [15:0] immediate;
    wire   [31:0] instruction_regI;
    wire    [5:0] funct_m;

    // DEC_EX_regFile
    wire          ALUsrc_regD;
    wire          MemWrite_regD, MemRead_regD, RegWrite_regD, JumpReg_regD;
    wire          Branch_regD;
    wire    [1:0] MemtoReg_regD;
    wire    [5:0] ALUOp_regD;
    wire    [4:0] Rs_regD, Rt_regD, wsel_regD;
    wire    [5:0] funct_regD;
    wire   [31:0] A_regD, B_regD, ExtOut_regD;
    wire   [31:0] PCplus4_regD;
    wire   [15:0] branchOffset_regD;

    // EX_MEM_regFile
    wire          RegWrite_regE, MemRead_regE, MemWrite_regE;
    wire    [1:0] MemtoReg_regE;
    wire    [4:0] wsel_regE;
    wire   [31:0] ALUout_regE, B_regE;

    // MEM_WB_regFile
    wire          RegWrite_regM;
    wire    [1:0] MemtoReg_regM;
    wire    [4:0] wsel_regM;
    wire   [31:0] ALUout_regM, dataOut_regM;

    // Control
    // although MemtoReg, ALUOp and ALUsrc will pass to next stahe,
    // it won't influence data in cache. => no need to insert 0
    wire    [1:0] RegDst, MemtoReg;
    wire    [5:0] ALUOp;
    wire          ExtOp, ALUsrc;
    wire          Branch_DEC, Branch_DEC_m, JumpReg, JumpReg_m;
    wire          MemRead, MemRead_m, MemWrite, MemWrite_m, RegWrite, RegWrite_m;

    // registerFile
    wire   [31:0] REG_A, REG_B;
    wire   [31:0] A, B;
    wire   [31:0] WriteData;    // from the MUX_wdata

    wire    [4:0] wsel; // write target register @ wsel_MUX

    // extender
    wire   [31:0] ExtOut;

    // ALU & ALUcontrol unit
    wire   [31:0] A_f, B_f; //use ALU to do 0 + PCplus4
    wire    [3:0] ALUctrl;  //from ALUcontrol unit
    wire   [31:0] ALUinA, ALUinB, tempALUinB;
    wire   [31:0] ALUout;

    // forwarding unit
    wire    [1:0] FU_Asel, FU_Bsel;

    // hazard_detection
    wire          stall_lw_use, stallcache;
    wire          flush;
    wire          pred_cond;
    wire          stall_muldiv;

    // branch_prediction
    wire          predict;
    wire          branchpred_his;

    // pre-control decode at IF
    wire          Jump_IF;
    wire          Branch_IF;
    wire   [15:0] branchOffset_I;
    wire   [25:0] targetAddr;

    // judge at the EX stage
    wire          equal;

    // DCACHE readdata
    wire   [31:0] dataOut;

//==== submodule declaration ==============================
    IF_DEC_regFile i_IF_DEC_regFile(
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .stallcache(stallcache),
        .stall_lw_use(stall_lw_use),
        .instruction_next(instruction_next),
        .PCplus4(PCplus4),
        .branchOffset(branchOffset_D),
        .opcode(opcode),
        .Rs(Rs),
        .Rt(Rt),
        .Rd(Rd),
        .shamt(shamt),
        .funct(funct),
        .immediate(immediate),
        .instruction_regI(instruction_regI),
        .PCplus4_regI(PCplus4_regI)
    );

    DEC_EX_regFile i_DEC_EX_regFile(
        .clk(clk),
        .rst_n(rst_n),
        .stallcache(stallcache),
        .MemtoReg(MemtoReg),
        .ALUOp(ALUOp),
        .JumpReg(JumpReg_m),       // add for jr and jalr forwarding
        .MemRead(MemRead_m),     // may stall by lw-use hazard
        .MemWrite(MemWrite_m),   // may stall by lw-use hazard
        .ALUsrc(ALUsrc),
        .RegWrite(RegWrite_m),   // may stall by lw-use hazard
        .Branch(Branch_DEC_m),
        .PCplus4_regI(PCplus4_regI),
        .funct(funct_m),
        .branchOffset_D(branchOffset_D),
        .A(A_f),
        .B(B_f),
        .ExtOut(ExtOut),
        .Rs(Rs),
        .Rt(Rt),
        .wsel(wsel),
        .MemtoReg_regD(MemtoReg_regD),
        .ALUOp_regD(ALUOp_regD),
        .MemRead_regD(MemRead_regD),
        .MemWrite_regD(MemWrite_regD),
        .ALUsrc_regD(ALUsrc_regD),
        .RegWrite_regD(RegWrite_regD),
        .funct_regD(funct_regD),
        .A_regD(A_regD),
        .B_regD(B_regD),
        .ExtOut_regD(ExtOut_regD),
        .Rs_regD(Rs_regD),
        .Rt_regD(Rt_regD),
        .wsel_regD(wsel_regD),
        .JumpReg_regD(JumpReg_regD),  // add for jr and jalr forwarding
        .Branch_regD(Branch_regD),
        .PCplus4_regD(PCplus4_regD),
        .branchOffset_regD(branchOffset_regD)
    );

    EX_MEM_regFile i_EX_MEM_regFile(
        .clk(clk),
        .rst_n(rst_n),
        .stallcache(stallcache),
        .MemtoReg_regD(MemtoReg_regD),
        .MemRead_regD(MemRead_regD),
        .MemWrite_regD(MemWrite_regD),
        .RegWrite_regD(RegWrite_regD),
        .B_regD(tempALUinB),
        .wsel_regD(wsel_regD),
        .ALUout(ALUout),
        .MemtoReg_regE(MemtoReg_regE),
        .MemRead_regE(MemRead_regE),
        .MemWrite_regE(MemWrite_regE),
        .RegWrite_regE(RegWrite_regE),
        .B_regE(B_regE),
        .wsel_regE(wsel_regE),
        .ALUout_regE(ALUout_regE)
    );

    MEM_WB_regFile i_MEM_WB_regFile(
        .clk(clk),
        .rst_n(rst_n),
        .stallcache(stallcache),
        .MemtoReg_regE(MemtoReg_regE),
        .RegWrite_regE(RegWrite_regE),
        .ALUout_regE(ALUout_regE),
        .wsel_regE(wsel_regE),
        .dataOut(DCACHE_rdata),
        .MemtoReg_regM(MemtoReg_regM),
        .RegWrite_regM(RegWrite_regM),
        .ALUout_regM(ALUout_regM),
        .wsel_regM(wsel_regM),
        .dataOut_regM(dataOut_regM)
    );

    maincontrol i_maincontrol(
        .opcode(opcode),
        .funct(funct),
        .RegDst(RegDst),
        .MemtoReg(MemtoReg),
        .ALUOp(ALUOp),
        .Branch(Branch_DEC),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .ALUsrc(ALUsrc),
        .RegWrite(RegWrite),
        .JumpReg(JumpReg),
        .ExtOp(ExtOp)
    );

    registerFile i_registrefFile(
        .clk(clk),
        .rst_n(rst_n),
        .rsel1(Rs),
        .rsel2(Rt),
        .wsel(wsel_regM),
        .wen(RegWrite_regM),
        .wdata(WriteData),
        .rdata1(A),
        .rdata2(B)
    );

    extender i_extender(
        .shamt_i(shamt),
        .immed_i(immediate),
        .ExtOp_i(ExtOp),
        .ExtOut_o(ExtOut)
    );

    MUX_5_3to1 MUX_wsel(
        .data0_i(Rt),
        .data1_i(Rd),
        .data2_i(5'd31),
        .select_i(RegDst),
        .data_o(wsel)
    );

    MUX_32_3to1 MUX_WriteData(
        .data0_i(dataOut_regM),
        .data1_i(ALUout_regM),
        .data2_i(ALUout_regM),
        .select_i(MemtoReg_regM),
        .data_o(WriteData)
    );

    MUX_32_3to1 MUX_ALUinA(
        .data0_i(A_regD),
        .data1_i(WriteData),
        .data2_i(ALUout_regE),
        .select_i(FU_Asel),
        .data_o(ALUinA)
    );

    MUX_32_3to1 MUX_ALUinB(
        .data0_i(B_regD),
        .data1_i(WriteData),
        .data2_i(ALUout_regE),
        .select_i(FU_Bsel),
        .data_o(tempALUinB)
    );

    forwarding i_forwarding(
        .Rs_regD(Rs_regD),
        .Rt_regD(Rt_regD),
        .RegWrite_regE(RegWrite_regE),
        .wsel_regE(wsel_regE),
        .RegWrite_regM(RegWrite_regM),
        .wsel_regM(wsel_regM),
        .FU_Asel(FU_Asel),
        .FU_Bsel(FU_Bsel)
    );

    hazard_detection i_hazard_detection(
        .Branch_EX(Branch_regD),
        .equal(equal),
        .branchpred_his(branchpred_his),
        .JumpReg_regD(JumpReg_regD),
        .MemRead_regD(MemRead_regD),
        .Rt_regD(Rt_regD),
        .Rs(Rs),
        .Rt(Rt),
        .ICACHE_stall(ICACHE_stall),
        .DCACHE_stall(DCACHE_stall),
        .stall_lw_use(stall_lw_use),
        .stallcache(stallcache),
        .flush(flush),
        .pred_cond(pred_cond),
        .stall_muldiv(stall_muldiv)
    );

    branch_prediction i_branch_prediction(
        .clk(clk),
        .rst_n(rst_n),
        .branch(Branch_regD),
        .equal(equal),
        .predict(predict),
        .branchpred_his(branchpred_his)
    );

    precontrolDec i_precontrolDec(
        .instruction_next(instruction_next),
        .Jump_IF(Jump_IF),
        .Branch_IF(Branch_IF)
    );

    nextPCcalculator i_nextPCcalculator(
        .PCcur(PCcur),
        .PCplus4(PCplus4),
        .PCplus4_regD(PCplus4_regD),
        .targetAddr(targetAddr),
        .branchOffset_I(branchOffset_I),
        .branchOffset_regD(branchOffset_regD),
        .JumpRegAddr(ALUinA),
        .PCsrc(PCsrc),
        .PCnext(PCnext)
    );

    PCsrcLogic i_PCsrcLogic(
        .pred_cond(pred_cond),
        .Branch_EX(Branch_regD),
        .Branch_IF(Branch_IF),
        .equal(equal),
        .Jump(Jump_IF),
        .JumpReg(JumpReg_regD),
        .predict(predict),
        .stallcache(stallcache),
        .stall_lw_use(stall_lw_use),
        .PCsrc(PCsrc)
    );

    ALU i_ALU(
        .clk(clk),
        .rst_n(rst_n),
        .ALUOp_regD(ALUOp_regD),
    	.funct_regD(funct_regD),
    	.ALUinA(ALUinA),
    	.ALUinB(ALUinB),
    	.ALUout(ALUout),
        .stall_muldiv(stall_muldiv)
	);


//==== combinational circuits =============================
    // ICACHE I/O
    assign instruction_next = ICACHE_rdata;
    assign ICACHE_wen = 0;
    assign ICACHE_ren = rst_n ? 1 : 0;
    assign ICACHE_addr = PCcur[31:2];
    assign ICACHE_wdata = 32'd0;

    // DCACHE I/O
    assign dataOut = DCACHE_rdata;
    assign DCACHE_ren = MemRead_regE;
    assign DCACHE_wen = MemWrite_regE;
    assign DCACHE_addr = ALUout_regE[31:2];
    assign DCACHE_wdata = B_regE;

    // lw-use hazard or wrong branch_prediction or jumpreg
    // need to do NOP to the DEC/EX stage flip-flops
    assign MemRead_m  = (stall_lw_use | flush) ? 1'd0 : MemRead;
    assign MemWrite_m = (stall_lw_use | flush) ? 1'd0 : MemWrite;
    assign RegWrite_m = (stall_lw_use | flush) ? 1'd0 : RegWrite;
    assign Branch_DEC_m = (stall_lw_use | flush) ? 1'd0 : Branch_DEC;
    assign JumpReg_m = (stall_lw_use | flush) ? 1'd0 : JumpReg;
    assign funct_m = flush ? 6'd0 : funct;

    // ALU related
        // use ALUout to store PCplus4
    assign A_f = (MemtoReg == 2'b10) ? 0 : A;
    assign B_f = (MemtoReg == 2'b10) ? PCplus4_regI : B;
        // R-type or I-type
    assign ALUinB = ALUsrc_regD ? tempALUinB : ExtOut_regD;

    // PC-related
    assign PCcur = PCreg;
    assign PCplus4 = PCcur + 32'd4;

    // Judge equal at the EX stage
    assign equal = (ALUout == 32'd0) ? 1 : 0;

    // do jump and branch_prediction at the IF stage
    assign branchOffset_I = instruction_next[15:0];
    assign targetAddr = instruction_next[25:0];

//==== synchronous circuits ===============================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // reset
            PCreg <= 0;
        end
        else begin
            PCreg <= PCnext;
        end
    end

endmodule

//==== IF/DEC pipline register file ============================================
module IF_DEC_regFile(
    clk,
    rst_n,
    flush,             // jr or wrong branch predict
    stallcache,        // cache stall
    stall_lw_use,      // lw-use hazard
    instruction_next,  // instruction from PC
    PCplus4,           // for jal
    branchOffset,      // branch address offset
    opcode,
    Rs,
    Rt,
    Rd,
    shamt,
    funct,
    immediate,
    instruction_regI,      // current instruction in DEC
    PCplus4_regI
);
//==== input/output definition ============================
    input           clk, rst_n, flush, stallcache, stall_lw_use;
    input    [31:0] instruction_next;   // instruction from PC
    input    [31:0] PCplus4;
    output   [15:0] branchOffset;       // branch address offset
    output    [5:0] opcode;
    output    [4:0] Rs;
    output    [4:0] Rt;
    output    [4:0] Rd;
    output    [4:0] shamt;
    output    [5:0] funct;
    output   [15:0] immediate;
    output   [31:0] instruction_regI;     // current instruction in DEC
    output   [31:0] PCplus4_regI;

//==== wire/reg definition =================================
    reg      [31:0] instruction_regI;
    reg      [31:0] PCplus4_regI;
    reg      [31:0] IR_next;
    reg	     [31:0] PC_next;

//==== combinational circuits =============================
    always @(*) begin
    	IR_next = instruction_regI;
    	PC_next = PCplus4_regI;

    	if (~stallcache & ~stall_lw_use) begin
	      IR_next = instruction_next;
	      PC_next = PCplus4;
      end
    end

//==== synchronous circuits ================================
    always@( posedge clk or negedge rst_n )
	begin
        // active low asynchronous reset
        if( ~rst_n )begin
            instruction_regI <= 32'd0;
            PCplus4_regI <= 32'd0;
        end
        else
        begin
            if(flush)begin
                instruction_regI <= 32'd0;
                PCplus4_regI <= 32'd0;
            end
            else begin
            		instruction_regI <= IR_next;
                PCplus4_regI <= PC_next;
            end
        end
	end

//==== combinational circuits =============================
    assign branchOffset  = instruction_regI[15:0];
    assign opcode        = instruction_regI[31:26];
    assign Rs            = instruction_regI[25:21];
    assign Rt            = instruction_regI[20:16];
    assign Rd            = instruction_regI[15:11];
    assign shamt         = instruction_regI[10:6];
    assign funct         = instruction_regI[5:0];
    assign immediate     = instruction_regI[15:0];

endmodule

//==== DEC/EX pipline register file ============================================
module DEC_EX_regFile(
    clk,
    rst_n,
    stallcache,
    MemtoReg,
    ALUOp,
    JumpReg,
    MemRead,
    MemWrite,
    ALUsrc,
    RegWrite,
    Branch,
    PCplus4_regI,
    funct,
    branchOffset_D,
    A,
    B,
    ExtOut,
    Rs,
    Rt,
    wsel,
    MemtoReg_regD,
    ALUOp_regD,
    MemRead_regD,
    MemWrite_regD,
    ALUsrc_regD,
    RegWrite_regD,
    funct_regD,
    A_regD,
    B_regD,
    ExtOut_regD,
    Rs_regD,
    Rt_regD,
    wsel_regD,
    JumpReg_regD,
    Branch_regD,
    PCplus4_regD,
    branchOffset_regD
);
//==== input/output definition ============================
    input          clk, rst_n, stallcache;
    input    [5:0] funct;
    input    [1:0] MemtoReg;
    input    [5:0] ALUOp;
    input          MemRead, MemWrite, RegWrite, JumpReg;
    input          ALUsrc;
    input          Branch;
    input   [31:0] A, B, ExtOut;
    input    [4:0] Rs, Rt, wsel;
    input   [31:0] PCplus4_regI;
    input   [15:0] branchOffset_D;

    output   [5:0] funct_regD;
    output   [1:0] MemtoReg_regD;
    output   [5:0] ALUOp_regD;
    output         MemRead_regD, MemWrite_regD, RegWrite_regD;
    output         ALUsrc_regD;
    output         Branch_regD;
    output  [31:0] A_regD, B_regD, ExtOut_regD;
    output   [4:0] Rs_regD, Rt_regD, wsel_regD;
    output         JumpReg_regD;
    output  [31:0] PCplus4_regD;
    output  [15:0] branchOffset_regD;
//==== wire/reg definition ================================
    reg      [5:0] funct_regD;
    reg      [1:0] MemtoReg_regD;
    reg      [5:0] ALUOp_regD;
    reg            MemRead_regD, MemWrite_regD, RegWrite_regD;
    reg            ALUsrc_regD;
    reg     [31:0] A_regD, B_regD, ExtOut_regD;
    reg      [4:0] Rs_regD, Rt_regD, wsel_regD;
    reg            JumpReg_regD;
    reg            Branch_regD;
    reg     [31:0] PCplus4_regD;
    reg     [15:0] branchOffset_regD;
    // wire
    reg      [5:0] funct_regD_next;
    reg      [1:0] MemtoReg_regD_next;
    reg      [5:0] ALUOp_regD_next;
    reg            MemRead_regD_next, MemWrite_regD_next, RegWrite_regD_next;
    reg            ALUsrc_regD_next;
    reg     [31:0] A_regD_next, B_regD_next, ExtOut_regD_next;
    reg      [4:0] Rs_regD_next, Rt_regD_next, wsel_regD_next;
    reg            JumpReg_regD_next;
    reg            Branch_regD_next;
    reg     [31:0] PCplus4_regD_next;
    reg     [15:0] branchOffset_regD_next;
//==== combinational circuit
    always @(*) begin
        if (stallcache) begin
            funct_regD_next        = funct_regD;
            MemtoReg_regD_next     = MemtoReg_regD;
            ALUOp_regD_next        = ALUOp_regD;
            MemRead_regD_next      = MemRead_regD;
            MemWrite_regD_next     = MemWrite_regD;
            RegWrite_regD_next     = RegWrite_regD;
            ALUsrc_regD_next       = ALUsrc_regD;
            A_regD_next            = A_regD;
            B_regD_next            = B_regD;
            ExtOut_regD_next       = ExtOut_regD;
            Rs_regD_next           = Rs_regD;
            Rt_regD_next           = Rt_regD;
            wsel_regD_next         = wsel_regD;
            JumpReg_regD_next      = JumpReg_regD;
            Branch_regD_next       = Branch_regD;
            PCplus4_regD_next      = PCplus4_regD;
            branchOffset_regD_next = branchOffset_regD;
        end
        else begin
            funct_regD_next        = funct;
            MemtoReg_regD_next     = MemtoReg;
            ALUOp_regD_next        = ALUOp;
            MemRead_regD_next      = MemRead;
            MemWrite_regD_next     = MemWrite;
            RegWrite_regD_next     = RegWrite;
            ALUsrc_regD_next       = ALUsrc;
            A_regD_next            = A;
            B_regD_next            = B;
            ExtOut_regD_next       = ExtOut;
            Rs_regD_next           = Rs;
            Rt_regD_next           = Rt;
            wsel_regD_next         = wsel;
            JumpReg_regD_next      = JumpReg;
            Branch_regD_next       = Branch;
            PCplus4_regD_next      = PCplus4_regI;
            branchOffset_regD_next = branchOffset_D;
        end
    end

//==== synchronous circuit
    always@( posedge clk or negedge rst_n )
    begin
        // active low asynchronous reset
        if( ~rst_n)begin
            funct_regD        <= 0;
            MemtoReg_regD     <= 0;
            ALUOp_regD        <= 0;
            MemRead_regD      <= 0;
            MemWrite_regD     <= 0;
            RegWrite_regD     <= 0;
            ALUsrc_regD       <= 0;
            A_regD            <= 0;
            B_regD            <= 0;
            ExtOut_regD       <= 0;
            Rs_regD           <= 0;
            Rt_regD           <= 0;
            wsel_regD         <= 0;
            JumpReg_regD      <= 0;
            Branch_regD       <= 0;
            PCplus4_regD      <= 0;
            branchOffset_regD <= 0;
        end
        else begin
            funct_regD        <= funct_regD_next   ;
            MemtoReg_regD     <= MemtoReg_regD_next;
            ALUOp_regD        <= ALUOp_regD_next   ;
            MemRead_regD      <= MemRead_regD_next ;
            MemWrite_regD     <= MemWrite_regD_next;
            RegWrite_regD     <= RegWrite_regD_next;
            ALUsrc_regD       <= ALUsrc_regD_next  ;
            A_regD            <= A_regD_next       ;
            B_regD            <= B_regD_next       ;
            ExtOut_regD       <= ExtOut_regD_next  ;
            Rs_regD           <= Rs_regD_next      ;
            Rt_regD           <= Rt_regD_next      ;
            wsel_regD         <= wsel_regD_next    ;
            JumpReg_regD      <= JumpReg_regD_next ;
            Branch_regD       <= Branch_regD_next  ;
            PCplus4_regD      <= PCplus4_regD_next ;
            branchOffset_regD <= branchOffset_regD_next;
        end
    end

endmodule

//==== EX/MEM pipline register file ============================================
module EX_MEM_regFile(
    clk,
    rst_n,
    stallcache,
    MemtoReg_regD,
    MemRead_regD,
    MemWrite_regD,
    RegWrite_regD,
    B_regD,
    wsel_regD,
    ALUout,
    MemtoReg_regE,
    MemRead_regE,
    MemWrite_regE,
    RegWrite_regE,
    B_regE,
    wsel_regE,
    ALUout_regE
);
//==== input/output definition ============================
    input         clk, rst_n, stallcache;
    input   [1:0] MemtoReg_regD;
    input         MemRead_regD, MemWrite_regD, RegWrite_regD;
    input  [31:0] B_regD, ALUout;
    input   [4:0] wsel_regD;

    output  [1:0] MemtoReg_regE;
    output        MemRead_regE, MemWrite_regE, RegWrite_regE;
    output [31:0] B_regE, ALUout_regE;
    output  [4:0] wsel_regE;

//==== wire/reg definition ================================
    reg     [1:0] MemtoReg_regE_next;
    reg           MemRead_regE_next, MemWrite_regE_next, RegWrite_regE_next;
    reg    [31:0] B_regE_next, ALUout_regE_next;
    reg     [4:0] wsel_regE_next;
    reg     [1:0] MemtoReg_regE;
    reg           MemRead_regE, MemWrite_regE, RegWrite_regE;
    reg    [31:0] B_regE, ALUout_regE;
    reg     [4:0] wsel_regE;
//==== combinational circuit
    always @(*) begin
        if (stallcache) begin
            MemtoReg_regE_next = MemtoReg_regE;
            MemRead_regE_next  = MemRead_regE;
            MemWrite_regE_next = MemWrite_regE;
            RegWrite_regE_next = RegWrite_regE;
            B_regE_next        = B_regE;
            ALUout_regE_next   = ALUout_regE;
            wsel_regE_next     = wsel_regE;
        end
        else begin
            MemtoReg_regE_next = MemtoReg_regD;
            MemRead_regE_next  = MemRead_regD;
            MemWrite_regE_next = MemWrite_regD;
            RegWrite_regE_next = RegWrite_regD;
            B_regE_next        = B_regD;
            ALUout_regE_next   = ALUout;
            wsel_regE_next     = wsel_regD;
        end
    end

//==== synchronous circuit
    always@( posedge clk or negedge rst_n )
    begin
        // active low asynchronous reset
        if( ~rst_n )begin
            MemtoReg_regE <= 0;
            MemRead_regE  <= 0;
            MemWrite_regE <= 0;
            RegWrite_regE <= 0;
            B_regE        <= 0;
            ALUout_regE   <= 0;
            wsel_regE     <= 0;
        end
        else begin
            MemtoReg_regE <=  MemtoReg_regE_next;
            MemRead_regE  <=  MemRead_regE_next;
            MemWrite_regE <=  MemWrite_regE_next;
            RegWrite_regE <=  RegWrite_regE_next;
            B_regE        <=  B_regE_next;
            ALUout_regE   <=  ALUout_regE_next;
            wsel_regE     <=  wsel_regE_next;
        end
    end


endmodule

//==== MEM/WB pipline register file ============================================
module MEM_WB_regFile(
    clk,
    rst_n,
    stallcache,
    MemtoReg_regE,
    RegWrite_regE,
    ALUout_regE,
    wsel_regE,
    dataOut,
    MemtoReg_regM,
    RegWrite_regM,
    ALUout_regM,
    wsel_regM,
    dataOut_regM
);
//==== input/output definition ============================
    input         clk, rst_n, stallcache;
    input   [1:0] MemtoReg_regE;
    input         RegWrite_regE;
    input  [31:0] ALUout_regE, dataOut;
    input   [4:0] wsel_regE;

    output  [1:0] MemtoReg_regM;
    output        RegWrite_regM;
    output [31:0] ALUout_regM, dataOut_regM;
    output  [4:0] wsel_regM;

//==== wire/reg definition ================================

    reg     [1:0] MemtoReg_regM;
    reg           RegWrite_regM;
    reg    [31:0] ALUout_regM, dataOut_regM;
    reg     [4:0] wsel_regM;
    reg     [1:0] MemtoReg_regM_next;
    reg           RegWrite_regM_next;
    reg    [31:0] ALUout_regM_next, dataOut_regM_next;
    reg     [4:0] wsel_regM_next;

//==== combinational circuit
    always @(*) begin
        if (stallcache) begin
            MemtoReg_regM_next  = MemtoReg_regM;
            RegWrite_regM_next  = RegWrite_regM;
            ALUout_regM_next    = ALUout_regM;
            dataOut_regM_next   = dataOut_regM;
            wsel_regM_next      = wsel_regM;
        end
        else begin
            MemtoReg_regM_next  = MemtoReg_regE;
            RegWrite_regM_next  = RegWrite_regE;
            ALUout_regM_next    = ALUout_regE;
            dataOut_regM_next   = dataOut;
            wsel_regM_next      = wsel_regE;
        end
    end

//==== synchronous circuit
    always@( posedge clk or negedge rst_n )
    begin
        // active low asynchronous reset
        if( ~rst_n )begin
             MemtoReg_regM <= 0;
             RegWrite_regM <= 0;
             ALUout_regM   <= 0;
             dataOut_regM  <= 0;
             wsel_regM     <= 0;
        end
        else begin
             MemtoReg_regM <= MemtoReg_regM_next;
             RegWrite_regM <= RegWrite_regM_next;
             ALUout_regM   <= ALUout_regM_next;
             dataOut_regM  <= dataOut_regM_next;
             wsel_regM     <= wsel_regM_next;
        end
    end

endmodule

//==== read/write data from 32 registers =======================================
module registerFile(
    clk,
    rst_n,
    rsel1,
    rsel2,
    wsel,
    wen,
    wdata,
    rdata1,
    rdata2
);
//==== input/output definition ============================
    input         clk, rst_n;
    input   [4:0] rsel1,rsel2;
    input   [4:0] wsel;
    input         wen;
    input  [31:0] wdata;
    output [31:0] rdata1, rdata2;

//==== wire/reg definition ================================
    reg    [31:0] register[31:0];
    integer i;

//==== combinational circuit
    assign rdata1 = (wen & (rsel1 == wsel) & (rsel1 != 5'd0)) ? wdata : register[rsel1];
    assign rdata2 = (wen & (rsel2 == wsel) & (rsel2 != 5'd0)) ? wdata : register[rsel2];

//==== synchronous circuit
    always@( posedge clk or negedge rst_n )
	begin
        // active low asynchronous reset
        if( ~rst_n )begin
            for(i=0; i<32; i=i+1)begin
                register[i] <= 32'd0;
            end
        end
        else begin
            if(wen)begin
                register[wsel] <= wdata;
            end
            register[0] <= 32'd0;
        end
	end

endmodule

//==== control signal for all instructions =====================================
module maincontrol(
    opcode,
    funct,
    RegDst,
    MemtoReg,
    ALUOp,
    Branch,
    MemRead,
    MemWrite,
    ALUsrc,
    RegWrite,
    JumpReg,
    ExtOp
);

//==== in/out declaration =================================
    input    [5:0] opcode;
    input    [5:0] funct;
    output   [1:0] RegDst, MemtoReg;
    output   [5:0] ALUOp;          // 4 bits at ref figure, I don't know how many bitswe need--> I use 6 bits to transfer opcode directly.
                                   // ALUOp(0000 is default for NOP)
    output         Branch, ExtOp;  // 2 bits at ref figure, but I think we only need 1 bit
    output         MemRead, MemWrite, ALUsrc, RegWrite, JumpReg;


//==== wire/reg definition ================================
    reg  [1:0] RegDst, MemtoReg;
    reg  [5:0] ALUOp;
    reg        Branch, ExtOp;
    reg        MemRead, MemWrite, ALUsrc, RegWrite, JumpReg;
//==== combinational circuit ==============================
	always@(*) begin
		RegDst   = 2'b01;
		MemtoReg = 2'b01;
		ALUOp    = opcode;
		ExtOp    = 1;
		ALUsrc   = 1;
		RegWrite = 0;

		Branch   = 0;
		MemRead  = 0;
		MemWrite = 0;
		JumpReg  = 0;

		case(opcode)
		//===== R-type ===============
        	6'b000000: begin
        		RegDst   = 2'b01;
        		MemtoReg = 2'b01;
        		ALUOp    = opcode;
        		ExtOp    = 1;
        		ALUsrc   = 1;
        		RegWrite = 1;
                // sll || sra || srl
        		if (funct == 6'b000000 || funct == 6'b000011 || funct == 6'b000010) begin
        			ALUsrc = 0;
        		end
                //jalr
        		else if (funct == 6'b001001) begin
        			MemtoReg = 2'b10;
				    JumpReg  = 1;
        		end
                //jr
			    else if (funct == 6'b001000) begin
        			JumpReg = 1;
			    end
       		end
        //===== I-type ===============
        	6'b001000: begin // addi
        		RegDst   = 2'b00;
        		MemtoReg = 2'b01;
        		ALUOp    = opcode;
        		ExtOp    = 0;
        		ALUsrc   = 0;
        		RegWrite = 1;
        	end
        	6'b001100: begin // andi
        		RegDst   = 2'b00;
        		MemtoReg = 2'b01;
        		ALUOp    = opcode;
        		ExtOp    = 0;
        		ALUsrc   = 0;
        		RegWrite = 1;
        	end
        	6'b001101: begin // ori
        		RegDst   = 2'b00;
        		MemtoReg = 2'b01;
        		ALUOp    = opcode;
        		ExtOp    = 0;
        		ALUsrc   = 0;
        		RegWrite = 1;
        	end
        	6'b001110: begin // xori
        		RegDst   = 2'b00;
        		MemtoReg = 2'b01;
        		ALUOp    = opcode;
        		ExtOp    = 0;
        		ALUsrc   = 0;
        		RegWrite = 1;
        	end
        	6'b001010: begin // slti
        		RegDst   = 2'b00;
        		MemtoReg = 2'b01;
        		ALUOp    = opcode;
        		ExtOp    = 0;
        		ALUsrc   = 0;
        		RegWrite = 1;
        	end
        	6'b100011: begin // lw
        		RegDst   = 2'b00;
        		MemtoReg = 2'b00;
        		ALUOp    = opcode;
        		ExtOp    = 0;
        		ALUsrc   = 0;
        		RegWrite = 1;
         		MemRead = 1;
        	end
        	6'b101011: begin // sw
        		RegDst   = 2'b00;
        		MemtoReg = 2'b00;
        		ALUOp    = opcode;
        		ExtOp    = 0;
        		ALUsrc   = 0;
        		RegWrite = 0;
            	MemWrite = 1;
        	end
       		6'b000100: begin //beq
        		RegDst   = 2'b00;
        		MemtoReg = 2'b01;
        		ALUOp    = opcode;
        		ExtOp    = 0;
        		ALUsrc   = 1;
        		RegWrite = 0;
       			Branch   = 1;
       		end
        //===== J-type ===============
        	6'b000010: begin // j
          		RegDst   = 2'b00;
        		MemtoReg = 2'b01;
        		ALUOp    = opcode;
        		ExtOp    = 0;
        		ALUsrc   = 0;
        		RegWrite = 0;
       		end
       		6'b000011: begin // jal
        		RegDst   = 2'b10;
        		MemtoReg = 2'b10;
        		ALUOp    = opcode;
        		ExtOp    = 0;
        		ALUsrc   = 1;
        		RegWrite = 1;
        	end
			default: begin
				RegDst   = 2'b01;
				MemtoReg = 2'b01;
				ALUOp    = opcode;
				ExtOp    = 1;
				ALUsrc   = 1;
				RegWrite = 0;

				Branch   = 0;
				MemRead  = 0;
				MemWrite = 0;
				JumpReg  = 0;
			end
    	endcase
	end
endmodule

//==== pre-control decode at IF ================================================
module precontrolDec(
    instruction_next,
    Jump_IF,
    Branch_IF
);

//==== in/out declaration =================================
    input    [31:0] instruction_next;
    output          Branch_IF, Jump_IF;

//==== wire/reg definition ================================
    reg  Jump_IF;
    reg  Branch_IF;

//==== combinational circuit ==============================
	always@(*) begin
		Jump_IF = 0;
		Branch_IF = 0;
		if (instruction_next[31:26] == 6'b000010 || instruction_next[31:26] == 6'b000011) begin // J & JAL
			Jump_IF = 1;
		end else if (instruction_next[31:26] == 6'b000100) begin // beq
			Branch_IF = 1;
		end
	end
endmodule

//==== I-type immediate or shift amount ========================================
module extender(
    shamt_i,
    immed_i,
    ExtOp_i,
    ExtOut_o
);
//==== input/output definition ============================
    input   [15:0]  immed_i;
    input    [4:0]  shamt_i;
    input           ExtOp_i;
    output  [31:0]  ExtOut_o;

    assign ExtOut_o = ExtOp_i ? { {27{shamt_i[4]}} , shamt_i }
                            : {{16{immed_i[15]}} , immed_i };
endmodule
//==== arithmetic calculation unit -- Extension: MUL/DIV =======================
//(2) need 1 extra output: stall_muldiv
//(3) need 2 extra input: clk, rst_n
//(4) need 2 MUX to select final ALU inputs
//(5) need 1 6-bit reg for state, 2 1-bit reg for signed bit
//(6) need 2 32-bit reg for results, 1 32-bit reg for multiplier/devisor
//(7) need control unit
//( ) only need to do 31 operations (1 sign bit)
//(8) mult: op/funct = 0/24 ; div: op/funct = 0/26
//(9) mfhi: op/funct = 0/16 ; mflo: op/funct = 0/18
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
                    state_next = 7'd98;
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
                //  a =  b * c + d (a,b,c,d all > 0)
				if(sign_and & sign_er)begin         // -a = (-b) *  c   + (-d)
                    reg_hi_next = hi_com;
				end
				else if(sign_and & (~sign_er))begin // -a =  b   * (-c) + (-d)
				    reg_lo_next = lo_com;
					reg_hi_next = hi_com;
				end
				else if((~sign_and) & sign_er)begin //  a = (-b) * (-c) +  d
					reg_lo_next = lo_com;
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
                reg_hi_next = result_com[63:32];
                reg_lo_next = result_com[31:0];
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

/*
//==== arithmetic calculation unit -- Extension: MUL/DIV =======================
module ALU(
	ALUOp_regD,
    funct_regD,
    ALUinA,
    ALUinB,
    ALUout
);
//==== input/output definition ============================
    input   [5:0] funct_regD;
    input   [5:0] ALUOp_regD;  //dont know how mant bits, use 4 bits temporarily
    input  [31:0] ALUinA, ALUinB;
    //input   [3:0] ALUctrl;
    output [31:0] ALUout;

//==== wire/reg definition ================================
    reg  [31:0] ALUout;
//==== combinational circuits =============================
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
endmodule
*/
//==== detect lw-use and branch hazard =========================================
module hazard_detection(
    Branch_EX,       // instruction in EX is branch type and
    equal,           // data in ALUinA and tempALUinB are same or not
    branchpred_his,  // predict branch in last cycle
    JumpReg_regD,    // if jr/jalr need to flush
                     // note that jump will be executed at IF stage
    MemRead_regD,    // lw
    Rt_regD,         // lw target registers
    Rs,              // Rs in EX
    Rt,              // Rt in EX
    ICACHE_stall,
    DCACHE_stall,
    stall_lw_use,    // stall if lw-use hazard detected
    stallcache,      // stall if cache miss
    flush,           // predict wrong or jr/jalr
    pred_cond,       // predict condition (predict correctly or not)
                     // XOR of equal and branchpred_his
    stall_muldiv
);
//==== input/output definition ============================
    input       Branch_EX;
    input       equal;
    input       branchpred_his;
    input       JumpReg_regD;
    input       MemRead_regD;
    input       ICACHE_stall, DCACHE_stall;
    input [4:0] Rt_regD, Rs, Rt;
    input       stall_muldiv;

    output      stall_lw_use, stallcache;
    output      flush;
    output      pred_cond;    //pass to PCsrcLogic

//==== wire/reg definition ================================
    reg         flush;
    reg         stall_lw_use;

//==== combinational circuit ==============================
    assign      pred_cond = Branch_EX ? (equal ^ branchpred_his) : 0;
    assign      stallcache = ICACHE_stall | DCACHE_stall | stall_muldiv;
    //==== WRONG!! lw-use hazard flush = 0; --> ok
    //==== DIDN'T DEAL WITH WRONG PREDICTION (NEED TO FLUSH) --> ok
    always@(*) begin
        flush = 0;
        stall_lw_use = 0;
        if (JumpReg_regD) begin
            flush = 1;
        end
        else if (MemRead_regD == 1 && (Rt_regD == Rs || Rt_regD == Rt)) begin
            //flush = 1;
            stall_lw_use = 1;
        end
        else if (pred_cond) begin
            flush = 1;
        end
    end

endmodule

//==== provide updated data early ==============================================
module forwarding(
    Rs_regD,
    Rt_regD,
    RegWrite_regE,
    wsel_regE,
    RegWrite_regM,
    wsel_regM,
    FU_Asel,        // 01 for WriteData, 10 for ALUout_regE
    FU_Bsel
);
//==== input/output definition ============================
    input  [4:0] Rs_regD, Rt_regD, wsel_regE, wsel_regM;
    input        RegWrite_regE, RegWrite_regM;
    output [1:0] FU_Asel, FU_Bsel;

//==== wire/reg definition ================================
    reg  [1:0] FU_Asel, FU_Bsel;
//==== combinational circuits =============================
	always@(*) begin
		FU_Asel = 2'b00;
		FU_Bsel = 2'b00;

		if (RegWrite_regM == 1 & wsel_regM != 0 & wsel_regM == Rs_regD) begin
			FU_Asel = 2'b01;
		end
		if (RegWrite_regM == 1 & wsel_regM != 0 & wsel_regM == Rt_regD) begin
			FU_Bsel = 2'b01;
		end
		if (RegWrite_regE == 1 & wsel_regE != 0 & wsel_regE == Rs_regD) begin
			FU_Asel = 2'b10;
		end
		if (RegWrite_regE == 1 & wsel_regE != 0 & wsel_regE == Rt_regD) begin
			FU_Bsel = 2'b10;
		end
	end
endmodule

//==== make input address to 32 bit and choose PCnext ==========================
module nextPCcalculator(
    PCcur,            // current PC (refetch)
    PCplus4,          // PC + 4 of current cycle
    PCplus4_regD,     // PC + 4 of previous 2 cycle
    targetAddr,       // from the instruction of IF stage last 26 bits
                      // << 2 & concatenate
    branchOffset_I,   // from the instruction of IF stage last 16 bits
                      // PCplus4 + branchOffset_I = branchAddr_I
    branchOffset_regD,   // from the instruction of EX stage last 16 bits
                      // PCplus4_regI + branchOffset = branchAddr_D
    JumpRegAddr,      // from ALUinA in EX
    PCsrc,
    PCnext
);
//==== input/output definition ============================
    input  [31:0] PCcur, PCplus4, PCplus4_regD;
    input  [25:0] targetAddr;
    input  [15:0] branchOffset_I, branchOffset_regD;
    input  [31:0] JumpRegAddr;
    input   [2:0] PCsrc;
    output [31:0] PCnext;

//==== wire/reg definition ================================
    reg    [31:0] PCnext;
    reg    [31:0] PCplus4_actual;
    reg    [31:0] branchOffset_actual;
    wire   [31:0] ADDresult;

//==== combinational circuit ==============================
    assign ADDresult = PCplus4_actual + branchOffset_actual;
    // USE 2 MUX 1 ADD
    always@(*) begin
        PCplus4_actual = 32'b0;
        branchOffset_actual = 32'b0;

        if(PCsrc == 3'd4)begin
            PCplus4_actual = PCplus4;
            branchOffset_actual = {14'd0, branchOffset_I, 2'd0};
        end
        else begin
            PCplus4_actual = PCplus4_regD;
            branchOffset_actual = {14'd0, branchOffset_regD, 2'd0};
        end
    end

    always@(*) begin
        PCnext = 0;
        case(PCsrc)
            3'd0:   // current cycle +4
                PCnext = PCplus4;
            3'd1:   // current PC
                PCnext = PCcur;
            3'd2:   // previous 2 cycle PC+4
                PCnext = PCplus4_regD;
            3'd3:   // jump
                PCnext[31:2] = {PCplus4[31:28], targetAddr};
            3'd4:   // branch I
                PCnext = ADDresult;
            3'd5:   // branch D
                PCnext = ADDresult;
            3'd6:   // jump from registerFile in DEC
                PCnext = JumpRegAddr;
            default:
                PCnext = 0;
        endcase
        //$display("PCnext: ", PCnext);
    end

endmodule

//==== pass 3-bit select signal for PCnext MUX in nextPCcalculator =============
module PCsrcLogic(
    pred_cond,      // predict condition b/w last predict and current branch
                    // = 0 --> correct, = 1 --> predict incorrect
    Branch_EX,
    Branch_IF,      // decode branch in IF
    equal,          // if predict wrong, we should fetch correct instruction addr
    Jump,           // get this signal at IF
    JumpReg,        // get this signal at EX
    predict,        // from branch_prediction unit
    stallcache,     // stall due to cache miss
    stall_lw_use,   // stall due to lw-use hazard
    PCsrc           // 3-bit select signal
);
//==== input/output definition ============================
    input        pred_cond, Branch_EX, Branch_IF, equal, predict;
    input        Jump, JumpReg;
    input        stallcache, stall_lw_use;
    output [2:0] PCsrc;

//==== wire/reg definition ================================
    reg    [2:0] PCsrc;

//==== combinational circuit ==============================
    always@(*) begin
        PCsrc = 0;
        // stall
        // order: stall --> JumpReg --> Branch_DEC [wrong or right]
        //        if pred_right --> Do instruction in IF (Jump or branch_IF)
        if(stallcache || stall_lw_use) begin
            PCsrc = 1;
        end
        else if(JumpReg) begin
            PCsrc = 6;
        end
        else if(Branch_EX) begin
            if(pred_cond == 1)  begin // predict wrong, do again
                if(equal) begin       // branch taken
                    PCsrc = 5;
                end
                else begin
                    PCsrc = 2;
                end
            end
            else begin
              if(Jump) begin
                  PCsrc = 3;
              end
              else if(Branch_IF) begin
                if(predict) begin
                    PCsrc = 4;
                end
                else begin
                    PCsrc = 0;
                end
              end
            end
        end
        else begin
            if(Jump) begin
                PCsrc = 3;
            end
            else if(Branch_IF) begin
                if(predict) begin
                    PCsrc = 4;
                end
                else begin
                    PCsrc = 0;
                end
            end
        end
    end
endmodule

//==== predict PCnext for branch-type instruction ==============================
module branch_prediction(
    clk,
    rst_n,
    branch,        // state only change when IR at EX is branch type
    equal,         // control of the finite state machine
    predict,
    branchpred_his
);
//==== input/output definition ============================
    input  clk,rst_n;
    input  branch, equal;
    output predict;
    output branchpred_his;

//==== wire/reg definition ================================
    reg [1:0] state, state_next;
    reg       branchpred_reg;     //output is a store register for predict history
    reg       predict;

//==== combinational circuit ==============================
    assign branchpred_his = branchpred_reg;
    always @(*) begin
        case(state)
            2'b00: begin  // prediction taken layer1
                predict = 1;
                if(branch)begin
                    if(equal)begin
                        state_next = 0;
                    end
                    else begin
                        state_next = 1;
                    end
                end
                else begin
                    state_next = state;
                end
            end
            2'b01: begin  // prediction taken layer0
                predict = 1;
                if(branch)begin
                    if(equal)begin
                        state_next = 0;
                    end
                    else begin
                        state_next = 2;
                    end
                end
                else begin
                    state_next = state;
                end
            end
            2'b10: begin  // prediction not taken layer0
                predict = 0;
                if(branch)begin
                    if(equal)begin
                        state_next = 1;
                    end
                    else begin
                        state_next = 3;
                    end
                end
                else begin
                    state_next = state;
                end
            end
            2'b11: begin  // prediction not taken layer1
                predict = 0;
                if(branch)begin
                    if(equal)begin
                        state_next = 2;
                    end
                    else begin
                        state_next = 3;
                    end
                end
                else begin
                    state_next = state;
                end
            end
        endcase
    end
//==== synchronous circuit
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // reset
            state <= 1;
            branchpred_reg <= 0;
        end
        else begin
            state <= state_next;
            branchpred_reg <= predict;
        end
    end

endmodule

//==== MUX3to1 (5bits) =========================================================
module MUX_5_3to1 ( data0_i, data1_i, data2_i, select_i, data_o);

//==== input/output definition ============================
    input   [4:0]  data0_i;
    input   [4:0]  data1_i;
    input   [4:0]  data2_i;
    input         [1:0]  select_i;
    output  [4:0]  data_o;

//==== wire/reg definition ================================
    reg     [4:0]  data_o;
    always@(*) begin
        case(select_i)
            2'd0:
                data_o = data0_i;
            2'd1:
                data_o = data1_i;
            2'd2:
                data_o = data2_i;
            2'd3:
                data_o = 0;
        endcase
    end

endmodule

//==== MUX3to1 (32bits) =========================================================
module MUX_32_3to1 ( data0_i, data1_i, data2_i, select_i, data_o);

//==== input/output definition ============================
    input   [31:0]  data0_i;
    input   [31:0]  data1_i;
    input   [31:0]  data2_i;
    input         [1:0]  select_i;
    output  [31:0]  data_o;

//==== wire/reg definition ================================
    reg     [31:0]  data_o;
    always@(*) begin
        case(select_i)
            2'd0:
                data_o = data0_i;
            2'd1:
                data_o = data1_i;
            2'd2:
                data_o = data2_i;
            2'd3:
                data_o = 0;
        endcase
    end

endmodule
