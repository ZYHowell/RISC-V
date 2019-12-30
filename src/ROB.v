`include "defines.v"

module ROB(
    input wire clk, 
    input wire rst, 
    input wire rdy, 
    //input from alu
    input wire enWrtO, 
    input wire[`TagBus]     WrtTagO, 
    input wire[`DataBus]    WrtDataO, 
    //communicate with dispatcher: about write out
    input wire[`TagBus] ReadTagO, 
    input wire[`TagBus] ReadTagT, 
    output wire enReadO, 
    output wire enReadT, 
    output wire[`DataBus] ReadDataO, 
    output wire[`DataBus] ReadDataT, 
    //output: commit to regfile
    output wire ROBfree, 
    output reg enComO, 
    output reg[`TagBus]     ComTagO, 
    output reg[`DataBus]    ComDataO, 
    //communicate with Dispatcher: about tagW
    input wire dispatchEn, 
    input wire[`BranchTagBus] dispBranchTag, 
    output wire[`TagRootBus] freeTag, 
    //
    input wire                  bFreeEn, 
    input wire[1:0]             bFreeNum, 
    input wire misTaken
);
    reg [`ROBsize - 1 : 0] empty;
    wire[`ROBsize - 1 : 0] ready;

    reg[`DataBus] rsData[`ROBsize - 1 : 0];
    reg[`TagBus]  rsTagW[`ROBsize - 1 : 0];
    reg[`BranchTagBus] rsBranchTag[`ROBsize - 1 : 0];
    wire[`BranchTagBus] nxtBranchTag[`ROBsize - 1 : 0];
    wire[`ROBsize - 1 : 0] nxtPosEmpty;
    wire[`ROBsize - 1 : 0] discard;
    reg[`ROBsize - 1 : 0] valid;

    reg[`rsSize - 1 : 0] allocEnO;
    reg[`DataBus]     AllocPostDataO;
    reg[`TagBus]      AllocPostTagO;

    reg [`TagRootBus]   head, tail;
    wire [`TagRootBus]  nxtPosTail;
    wire canIssue;
    wire headMove;
    //the head is the head while the tail is the next;

    assign nxtPosTail = (tail + 1 < `ROBsize) ? tail + 1 : 0;
    assign ROBfree = dispatchEn ? (head == nxtPosTail) : (head == tail);
    assign freeTag = tail;//0 is the prefix
    assign headMove = (~valid[head] & (head != tail)) | ready[head] | discard[head];

    assign enReadO = (ReadTagO == `tagFree) ? `Disable : 
                     (ReadTagO == WrtTagO) ? `Enable : 
                     (~empty[ReadTagO[`TagRootBus]] & ~ReadTagO[3]) ? `Enable : `Disable;
    assign ReadDataO = (ReadTagO == `tagFree) ? `dataFree : 
                       (ReadTagO == WrtTagO) ? WrtDataO : 
                       (~empty[ReadTagO[`TagRootBus]]) ? rsData[ReadTagO[`TagRootBus]] : `dataFree;
    
    assign enReadT = (ReadTagT == `tagFree) ? `Disable : 
                     (ReadTagT == WrtTagO) ? `Enable : 
                     (~empty[ReadTagT[`TagRootBus]] & ~ReadTagT[3]) ? `Enable : `Disable;
    assign ReadDataT = (ReadTagT == `tagFree) ? `dataFree : 
                       (ReadTagT == WrtTagO) ? WrtDataO : 
                       (~empty[ReadTagT[`TagRootBus]]) ? rsData[ReadTagT[`TagRootBus]] : `dataFree;

    generate
      genvar j;
      for (j = 0; j < `ROBsize;j = j + 1) begin: ROBline
        assign discard[j] = misTaken & rsBranchTag[j][bFreeNum];
        assign ready[j] = (~empty[j]) & (!nxtBranchTag[j]) & ~discard[j];
        assign nxtBranchTag[j] = (bFreeEn & rsBranchTag[j][bFreeNum]) ? (rsBranchTag[j] ^ (1 << bFreeNum)) : rsBranchTag[j];
        assign nxtPosEmpty[j] = (empty[j] & ~allocEnO[j]) | discard[j];

        always @(posedge clk) begin
          if (rst) begin
            empty[j] <= 1'b1;

            valid[j] <= 0;
            rsBranchTag[j] <= 0;

            rsData[j] <= `dataFree;
            rsTagW[j] <= `tagFree;
          end else if (rdy) begin
            if (headMove & (j == head)) empty[j] <= 1;
            else empty[j] <= nxtPosEmpty[j];

            if (dispatchEn && (j == tail)) begin
              rsBranchTag[j] <= dispBranchTag;
              valid[j] <= 1;
            end else begin
              rsBranchTag[j] <= nxtBranchTag[j];
              if (j == head && headMove) begin
                valid[j] <= 0;
              end else begin
                valid[j] <= valid[j] & ~discard[j];
              end
            end

            if (allocEnO[j]) begin
              rsData[j] <= AllocPostDataO;
              rsTagW[j] <= AllocPostTagO;
            end
          end
        end

      end
    endgenerate

    always @(*) begin
      allocEnO = 0;
      allocEnO[WrtTagO[`TagRootBus]] = enWrtO;
      AllocPostDataO = WrtDataO;
      AllocPostTagO = WrtTagO;
    end

    always @ (posedge clk) begin
      if (rst) begin
        head <= 0;
        tail <= 0;
        enComO <= `Disable; 
        ComTagO<= `tagFree; 
        ComDataO <= `dataFree; 
      end else if (rdy) begin
        //give the dispatcher a tag(at post edge)
        if (dispatchEn)
          tail <= nxtPosTail;
        //commit below
        if (headMove) 
          head <= (head + 1 < `ROBsize) ? head + 1 : 0;
        if (ready[head]) begin
          enComO <= `Enable;
          ComDataO <= rsData[head];
          ComTagO <= rsTagW[head];
        end else begin
          enComO <= `Disable;
          ComDataO <= `dataFree;
          ComTagO <= `tagFree;
        end
      end
    end
endmodule