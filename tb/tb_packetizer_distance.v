`timescale 1ns/1ps
module tb_packetizer_distance;
  reg clk=0,rst=1,bin_valid=0,tx_can_issue=1;
  always #5 clk=~clk;
  reg [31:0] bin={2'b10,5'd12,6'd34,9'd123,9'd0,1'b0};
  wire fifo_pop,ascii_valid;
  wire [7:0] ascii_data;
  integer errors=0,count=0;
  reg [119:0] expected={"D H12 M34 D123",8'h0a};
  response_packetizer dut(.clk(clk),.rst(rst),.i_bin(bin),.i_bin_valid(bin_valid),
    .pop_response_fifo(fifo_pop),.i_tx_can_issue(tx_can_issue),
    .o_ascii_data(ascii_data),.o_ascii_data_valid(ascii_valid));
  always @(posedge clk) if (!rst) begin
    if (fifo_pop) $display("POP %0t",$time);
    if (dut.dd_start_reg) $display("DD_START %0t field=%0d bin=%0d",$time,dut.field_cnt_reg,dut.dd);
    if (dut.w_dd_done) $display("DD_DONE %0t field=%0d bcd=%03h",$time,dut.field_cnt_reg,dut.w_bcd);
    if (ascii_valid) begin
      if (count>=15) errors=errors+1;
      else if (ascii_data!==expected[(14-count)*8+:8]) errors=errors+1;
      $display("ASCII %0t byte=%0d data=%02h",$time,count,ascii_data);
      count=count+1;
    end
  end
  initial begin
    #20; @(negedge clk); rst=0; bin_valid=1;
    @(posedge clk); @(negedge clk); bin_valid=0;
    wait(count==15); #30;
    $display("RESULT DISTANCE bytes=%0d errors=%0d",count,errors); $finish;
  end
  initial begin #10000; $display("TIMEOUT bytes=%0d",count); $finish; end
endmodule
