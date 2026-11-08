`timescale 1ns/1ps
module tb_almost_compare;
reg clk=0,rst=1; always #5 clk=~clk;
wire [7:0] data_full,data_almost;
wire push_full,push_almost,full_only,full_almost,almost_only,almost_fixed;
wire can_full=~full_only,can_almost=~almost_fixed;
wire write_full=push_full & ~full_only,write_almost=push_almost & ~full_almost;
wire drop_full=push_full & full_only,drop_almost=push_almost & full_almost;
integer saved_full=0,saved_almost=0,lost_full=0,lost_almost=0;
response_packetizer P_FULL(.clk(clk),.rst(rst),.i_bin(32'h50000001),.i_bin_valid(~rst),.pop_response_fifo(),.i_tx_can_issue(can_full),.o_ascii_data(data_full),.o_ascii_data_valid(push_full));
response_packetizer P_ALMOST(.clk(clk),.rst(rst),.i_bin(32'h50000001),.i_bin_valid(~rst),.pop_response_fifo(),.i_tx_can_issue(can_almost),.o_ascii_data(data_almost),.o_ascii_data_valid(push_almost));
fifo #(.DEPTH(32),.DATA_BIT_WIDTH(8)) F_FULL(.clk(clk),.rst(rst),.push(push_full),.pop(1'b0),.data_push(data_full),.data_pop(),.full(full_only),.empty(),.almost_full(almost_only));
fifo #(.DEPTH(32),.DATA_BIT_WIDTH(8)) F_ALMOST(.clk(clk),.rst(rst),.push(push_almost),.pop(1'b0),.data_push(data_almost),.data_pop(),.full(full_almost),.empty(),.almost_full(almost_fixed));
always @(posedge clk) if(!rst) begin
 if(write_full) saved_full=saved_full+1;
 if(write_almost) saved_almost=saved_almost+1;
 if(drop_full) begin lost_full=lost_full+1;$display("DROP full time=%0t data=%h",$time,data_full);end
 if(drop_almost) lost_almost=lost_almost+1;
 if(saved_full>=30 || saved_almost>=30) $display("EDGE %0t saved=%0d/%0d push=%b/%b full=%b/%b almost=%b/%b",$time,saved_full,saved_almost,push_full,push_almost,full_only,full_almost,almost_only,almost_fixed);
end
initial begin #20;rst=0;#1200;$display("RESULT saved=%0d/%0d dropped=%0d/%0d",saved_full,saved_almost,lost_full,lost_almost);$finish;end
endmodule
