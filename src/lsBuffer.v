`include "defines.v"
module LSbufLine(
    input clk, 
    input rst, 
    //
    input wire enWrtO, 
    input wire[`TagBus] WrtTagO, 
    input wire[`DataBus]  WrtDataO, 
    input wire enWrtT, 
    input wire[`TagBus] WrtTagT,
    input wire[`DataBus] WrtDataT, 
    //
    input wire allocEn, 
    input wire[`DataBus]    allocOperandO, 
    input wire[`DataBus]    allocOperandT, 
    input wire[`TagBus]     allocTagO, 
    input wire[`TagBus]     allocTagT,
    input wire[`TagBus]     allocTagW,
    input wire[`NameBus]    allocNameW,  
    input wire[`OpBus]      allocOp, 
    input wire[`InstAddrBus]allocImm, 
    input wire[`BranchTagBus] allocBranchTag, 
    //
    input wire empty, 
    output wire ready, 
    output wire[`DataBus] issueOperandO, 
    output wire[`DataBus] issueOperandT, 
    output wire[`OpBus]   issueOp,  
    output wire[`NameBus] issueNameW, 
    output wire[`TagBus]  issueTagW,
    output wire[`DataBus] issueImm,
    //the imm is pc in alu, is imm in ls; but ls needs to clear branchTag before issuing
    input wire        bFreeEn, 
    input wire[1:0]   bFreeNum
);
    reg[`TagBus]  rsTagO, rsTagT;
    reg[`DataBus] rsDataO, rsDataT;
    reg[`NameBus] rsNameW;
    reg[`TagBus]  rsTagW;
    reg[`DataBus] rsImm;
    reg[`OpBus]   rsOp;
    reg[`BranchTagBus] BranchTag;
    wire[`TagBus] nxtPosTagO, nxtPosTagT;
    wire[`DataBus] nxtPosDataO, nxtPosDataT;
    wire[`BranchTagBus] nxtPosBranchTag;

    assign ready = (~empty & (nxtPosTagO == `tagFree) & (nxtPosTagT == `tagFree)) && (!nxtPosBranchTag);
    assign issueOperandO = (nxtPosTagO == `tagFree) ? nxtPosDataO : rsDataO;
    assign issueOperandT = (nxtPosTagT == `tagFree) ? nxtPosDataT : rsDataT;
    assign issueOp = rsOp;
    assign issueNameW = rsNameW;
    assign issueImm = rsImm;
    assign issueTagW = rsTagW;
    assign nxtPosBranchTag = (bFreeEn & BranchTag[bFreeNum]) ? (BranchTag ^ (1 << bFreeNum)) : BranchTag;

    nxtPosCal nxtPosCalO(
      .enWrtO(enWrtO), 
      .WrtTagO(WrtTagO), 
      .WrtDataO(WrtDataO), 
      .enWrtT(enWrtT), 
      .WrtTagT(WrtTagT), 
      .WrtDataT(WrtDataT), 
      .dataNow(rsDataO), 
      .tagNow(rsTagO), 
      .dataNxtPos(nxtPosDataO),
      .tagNxtPos(nxtPosTagO)
    );
    nxtPosCal nxtPosCalT(
      .enWrtO(enWrtO), 
      .WrtTagO(WrtTagO), 
      .WrtDataO(WrtDataO), 
      .enWrtT(enWrtT), 
      .WrtTagT(WrtTagT), 
      .WrtDataT(WrtDataT), 
      .dataNow(rsDataT), 
      .tagNow(rsTagT), 
      .dataNxtPos(nxtPosDataT),
      .tagNxtPos(nxtPosTagT)
    );
    always @(posedge clk or posedge rst) begin
      if (rst) begin
        rsTagO <= `tagFree;
        rsTagT <= `tagFree;
        rsDataO <= `dataFree;
        rsDataT <= `dataFree;
        rsNameW <= `nameFree;
        rsTagW <= `tagFree;
        rsImm <= `dataFree;
        rsOp <= `NOP;
        BranchTag <= 0;
      end else if (allocEn == `Enable) begin
        rsTagO <= allocTagO;
        rsTagT <= allocTagT;
        rsDataO <= allocOperandO;
        rsDataT <= allocOperandT;
        rsNameW <= allocNameW;
        rsTagW <= allocTagW;
        rsImm <= allocImm;
        rsOp <= allocOp;
        BranchTag <= allocBranchTag;
      end else begin
        rsTagO <= nxtPosTagO;
        rsTagT <= nxtPosTagT;
        rsDataO <= nxtPosDataO;
        rsDataT <= nxtPosDataT;
        BranchTag <= nxtPosBranchTag;
      end
    end
endmodule
module lsBuffer(
    input rst, 
    input clk, 
    //from ALU and LS
    input wire enALUwrt, 
    input wire[`TagBus] ALUtag, 
    input wire[`DataBus]  ALUdata, 
    input wire enLSwrt, 
    input wire[`TagBus] LStag,
    input wire[`DataBus] LSdata, 
    //input from dispatcher
    input wire LSen, 
    input wire[`DataBus]        LSoperandO, 
    input wire[`DataBus]        LSoperandT, 
    input wire[`TagBus]         LStagO, 
    input wire[`TagBus]         LStagT, 
    input wire[`TagBus]         LStagW, 
    input wire[`NameBus]        LSnameW, 
    input wire[`OpBus]          LSop, 
    input wire[`DataBus]        LSimm, 
    input wire[`BranchTagBus]   BranchTag, 
    //from the LS
    input wire LSreadEn, 
    input wire LSdone,
    //to LS
    output reg LSworkEn, 
    output reg[`DataBus]        operandO, 
    output reg[`DataBus]        operandT,
    output reg[`DataBus]        imm, 
    output reg[`TagBus]         wrtTag, 
    output reg[`NameBus]        wrtName, 
    output reg[`OpBus]          opCode, 
    //to dispatcher
    output wire[`TagRootBus] LSfreeTag, 
    output wire LSbufFree, 
    //
    input wire                  bFreeEn, 
    input wire[1:0]             bFreeNum
);
    reg [`rsSize - 1 : 0] empty;
    wire[`rsSize - 1 : 0] ready;

    reg[`rsSize - 1 : 0] allocEn;
    reg[`DataBus]     AllocPostOperandO; 
    reg[`DataBus]     AllocPostOperandT; 
    reg[`TagBus]      AllocPostTagO; 
    reg[`TagBus]      AllocPostTagT;
    reg[`TagBus]      AllocPostTagW;
    reg[`NameBus]     AllocPostNameW;  
    reg[`OpBus]       AllocPostOp; 
    reg[`DataBus]     AllocPostImm; 
    reg[`BranchTagBus] AllocBranchTag;

    wire[`DataBus] issueOperandO[`rsSize - 1 : 0];
    wire[`DataBus] issueOperandT[`rsSize - 1 : 0];
    wire[`OpBus]   issueOp[`rsSize - 1 : 0]; 
    wire[`NameBus] issueNameW[`rsSize - 1 : 0];
    wire[`TagBus] issueTagW[`rsSize - 1 : 0];
    wire[`DataBus] issueImm[`rsSize - 1 : 0];

    reg [`TagRootBus]   head, tail, num, judgeIssue;
    wire canIssue;
    //the head is the head while the tail is the next;
    integer i;

    assign canIssue = ready[judgeIssue];
    assign LSfreeTag = (tail != head) ? tail : 
                        num ? `NoFreeTag : tail;
    assign LSbufFree = (num + LSen + 1) < `rsSize ? 1 : 0;

    generate
      genvar j;
      for (j = 0; j < `rsSize;j = j + 1) begin: LSbufLine
        LSbufLine LSbufLine(
          .clk(clk), 
          .rst(rst), 
          //
          .enWrtO(enALUwrt), 
          .WrtTagO(ALUtag), 
          .WrtDataO(ALUdata), 
          .enWrtT(enLSwrt), 
          .WrtTagT(LStag),
          .WrtDataT(LSdata), 
          //
          .allocEn(allocEn[j]), 
          .allocOperandO(AllocPostOperandO), 
          .allocOperandT(AllocPostOperandT), 
          .allocTagO(AllocPostTagO), 
          .allocTagT(AllocPostTagT),
          .allocTagW(AllocPostTagW),
          .allocNameW(AllocPostNameW),
          .allocOp(AllocPostOp), 
          .allocImm(AllocPostImm), 
          .allocBranchTag(AllocBranchTag), 
          //
          .empty(empty[j]), 
          .ready(ready[j]), 
          .issueOperandO(issueOperandO[j]), 
          .issueOperandT(issueOperandT[j]), 
          .issueOp(issueOp[j]), 
          .issueNameW(issueNameW[j]), 
          .issueTagW(issueTagW[j]), 
          .issueImm(issueImm[j]),
          .bFreeEn(bFreeEn), 
          .bFreeNum(bFreeNum) 
        );
      end
    endgenerate

    always @(*) begin
      allocEn = 0;
      allocEn[tail] = LSen;
      AllocPostImm = LSimm;
      AllocPostOp = LSop;
      AllocPostOperandO = LSoperandO;
      AllocPostOperandT = LSoperandT;
      AllocPostTagO = LStagO;
      AllocPostTagT = LStagT;
      AllocPostTagW = LStagW;
      AllocPostNameW = LSnameW;
      AllocBranchTag = BranchTag;
    end

    always @ (posedge clk or posedge rst) begin
      if (rst) begin
        judgeIssue <= 0;
        head <= 0;
        tail <= 0;
        num <= 0;
        empty <= {`rsSize{1'b1}};
        LSworkEn <= `Disable; 
        operandO <= `dataFree; 
        operandT <= `dataFree;
        imm <= `dataFree;
        wrtTag <= `tagFree; 
        wrtName <= `nameFree; 
        opCode <= `NOP; 
      end else begin
        if (LSen) begin
          empty[tail]   <= 0;
          tail <= (tail == `rsSize - 1) ? 0 : tail + 1;
        end
        if (LSdone) begin
          head <= judgeIssue;
          empty[head] <= 1;
          num <= LSen ? num : (num - 1);
        end else begin
          num <= LSen ? num + 1 : num;
        end
        if ((LSreadEn == `Enable) && canIssue) begin
          LSworkEn <= `Enable;
          operandO <= issueOperandO[judgeIssue];
          operandT <= issueOperandT[judgeIssue];
          opCode <= issueOp[judgeIssue];
          wrtName <= issueNameW[judgeIssue];
          wrtTag <= issueTagW[judgeIssue];
          imm <= issueImm[judgeIssue];
          judgeIssue <= (judgeIssue == `rsSize - 1) ? 0 : judgeIssue + 1;
        end else begin
          LSworkEn <= `Disable;
          operandO <= `dataFree;
          operandT <= `dataFree;
          opCode <= `NOP;
          wrtName <= `nameFree;
          wrtTag <= `tagFree;
          imm <= `dataFree;
        end
      end
    end
endmodule