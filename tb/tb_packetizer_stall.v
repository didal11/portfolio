`timescale 1ns/1ps
module tb_packetizer_stall;
  reg clk=0, rst=1;
  always #5 clk=~clk;
  reg [31:0] bin={2'b00,5'd12,6'd34,9'd56,9'd0,1'b0};
  reg bin_valid=0, tx_can_issue=1;
  wire fifo_pop, ascii_valid;
  wire [7:0] ascii_data;
  integer errors=0;
  response_packetizer dut(.clk(clk),.rst(rst),.i_bin(bin),
    .i_bin_valid(bin_valid),.pop_response_fifo(fifo_pop),
    .i_tx_can_issue(tx_can_issue),.o_ascii_data(ascii_data),
    .o_ascii_data_valid(ascii_valid));

  initial begin
    #20; @(negedge clk); rst=0; bin_valid=1;
    @(posedge clk); $display("MARK POP %0t",$time); if(!fifo_pop) errors=errors+1;
    @(negedge clk); bin_valid=0;

    wait(ascii_valid && ascii_data=="1");
    @(negedge clk); tx_can_issue=0; $display("MARK STALL %0t",$time);
    repeat(8) begin
      @(posedge clk); #1;
      if(dut.state_reg!=4 || dut.field_cnt_reg!=0 || dut.digit_cnt_reg!=2 ||
         dut.bin_reg!==bin || ascii_valid || fifo_pop) errors=errors+1;
    end
    @(negedge clk); tx_can_issue=1; $display("MARK RESUME %0t",$time);
    @(posedge clk); #1;
    $display("MARK NEXT_DIGIT %0t",$time-1); if(!ascii_valid || ascii_data!="2") errors=errors+1;
    $display("RESULT PACKETIZER STALL errors=%0d",errors);
    #40; $finish;
  end
  initial begin #5000; $display("TIMEOUT"); $finish; end
endmodule
