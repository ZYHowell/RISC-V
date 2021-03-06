`include "defines.v"
module BP(
  input clk, 
  input rst, 
  input rdy, 
  input wire predEn, 
  input wire[`InstAddrBus]  predPC, 
  input wire[`InstBus]      predInst, 
  output reg predOutEn, 
  output reg pred, //0 for not taken and 1 for taken
  output reg[`InstAddrBus] predAddr, 
  input wire BranchEn, 
  input wire BranchMisTaken
);
    reg [1:0] gshare;
    reg[1:0] misG[1:0];
    reg[1:0] corG[1:0];
    wire[`DataBus] Bimm;
    assign Bimm = {{`immFillLen{predInst[31]}}, predInst[7], predInst[30:25], predInst[11:8], 1'b0};

    always @(posedge clk) begin
        if (rst) begin
            pred <= 0;
            predAddr <= 0;
            pred <= 0;
            misG[0] <= 2'b01;
            misG[1] <= 2'b10;
            corG[0] <= 2'b00;
            corG[1] <= 2'b11;
            gshare  <= 2'b00;
        end else if (rdy) begin
            predOutEn <= predEn;
            pred <= gshare[1];
            predAddr <= gshare[1] ? predPC + Bimm : predPC + 4;
            if (BranchEn) begin
                gshare <= BranchMisTaken ? misG[gshare[0]] : corG[gshare[1]];
            end
        end
    end
endmodule