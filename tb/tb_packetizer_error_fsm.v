`timescale 1ns/1ps
module tb_packetizer_error_fsm;
  reg clk=0,rst=1,bin_valid=0,tx_can_issue=1;
  always #5 clk=~clk;
  reg [31:0] bin=32'h30000001;
  wire fifo_pop,ascii_valid;
  wire [7:0] ascii_data;
  integer count=0,errors=0;
  reg [175:0] expected={"ERROR: no time value.",8'h0a};
  response_packetizer dut(.clk(clk),.rst(rst),.i_bin(bin),.i_bin_valid(bin_valid),
    .pop_response_fifo(fifo_pop),.i_tx_can_issue(tx_can_issue),
    .o_ascii_data(ascii_data),.o_ascii_data_valid(ascii_valid));
  always @(dut.state_reg) $display("STATE %0t state=%0d",$time,dut.state_reg);
  always @(posedge clk) if(!rst) begin
    if(fifo_pop) $display("POP %0t",$time);
    if(ascii_valid) begin
      if(count>=22) errors=errors+1;
      else if(ascii_data!==expected[(21-count)*8+:8]) errors=errors+1;
      $display("ASCII %0t byte=%0d data=%02h",$time,count,ascii_data);
      count=count+1;
    end
  end
  initial begin
    #20; @(negedge clk); rst=0; bin_valid=1;
    @(posedge clk); @(negedge clk); bin_valid=0;
    wait(count==22); #30;
    $display("RESULT ERROR bytes=%0d errors=%0d state=%0d",count,errors,dut.state_reg); $finish;
  end
  initial begin #10000; $display("TIMEOUT bytes=%0d",count); $finish; end
endmodule
