`timescale 1ns/1ps
module tb_arbiter_control;
  reg clk=0,rst=1;
  always #5 clk=~clk;
  reg [16:0] watch_data={5'd12,6'd34,6'd56};
  reg [16:0] stopwatch_data={5'd1,6'd2,6'd3};
  reg [8:0] distance_data=123;
  reg [15:0] humid_temp_data={8'd55,8'd24};
  reg dht11_valid=0,sr04_valid=0,watch_valid=0,stopwatch_valid=0;
  reg fifo_pop=0;
  reg error_occured=0;
  reg [3:0] error_code=0;
  wire error_ready;
  wire dht11_ready,sr04_ready,fifo_empty;
  wire [31:0] fifo_read_data;
  wire fifo_push=dut.w_fifo_push;
  wire fifo_full=dut.w_fifo_full;
  wire [31:0] fifo_write_data=dut.w_fifo_push_data;
  wire [1:0] response_type=fifo_write_data[31:30];
  wire [1:0] write_pointer=dut.U_FIFO.w_wptr;
  wire [1:0] read_pointer=dut.U_FIFO.w_rptr;
  integer phase=0,writes=0,reads=0,fail=0;
  reg [31:0] expected_word[0:12];
  response_arbiter dut(.clk(clk),.rst(rst),
    .i_distance_data(distance_data),.i_distance_valid(sr04_valid),.o_distance_ready(sr04_ready),
    .i_humid_temp_data(humid_temp_data),.i_humid_temp_valid(dht11_valid),.o_humid_temp_ready(dht11_ready),
    .i_watch_data(watch_data),.i_watch_valid(watch_valid),
    .i_stopwatch_data(stopwatch_data),.i_stopwatch_valid(stopwatch_valid),
    .i_error_code(error_code),.error_occured(error_occured),.o_error_ready(error_ready),
    .o_w_pop_data(fifo_read_data),.i_response_fifo_pop(fifo_pop),.o_response_fifo_empty(fifo_empty));
  function [31:0] frame(input integer typ);
    case(typ)
      0:frame={2'b00,5'd12,6'd34,9'd56,9'd0,1'b0};
      1:frame={2'b01,5'd1,6'd2,9'd3,9'd0,1'b0};
      2:frame={2'b10,5'd12,6'd34,9'd123,9'd0,1'b0};
      3:frame={2'b11,5'd12,6'd34,9'd55,9'd24,1'b0};
    endcase
  endfunction
  always @(posedge clk) if(!rst) begin
    if(fifo_full && (fifo_push || dht11_ready || sr04_ready || error_ready)) begin
      fail=fail+1;$display("FAIL Full must block push/ready at %0t",$time);
    end
    if(fifo_push) begin
      if(writes>=13 || fifo_write_data!==expected_word[writes]) begin
        fail=fail+1;$display("FAIL WRITE index=%0d actual=%08h",writes,fifo_write_data);
      end
      $display("WRITE index=%0d phase=%0d error=%0b data=0x%08h time=%0t",writes,phase,fifo_write_data[0],fifo_write_data,$time);
      writes=writes+1;
    end
    if(fifo_pop && !fifo_empty) begin
      if(reads>=13 || fifo_read_data!==expected_word[reads]) begin
        fail=fail+1;$display("FAIL READ index=%0d actual=%08h",reads,fifo_read_data);
      end
      reads=reads+1;
    end
  end
  initial begin
    expected_word[0]=frame(3);expected_word[1]=frame(2);
    expected_word[2]=frame(0);expected_word[3]=frame(1);
    expected_word[4]=frame(3);expected_word[5]=frame(2);
    expected_word[6]=frame(3);expected_word[7]=frame(2);
    expected_word[8]=frame(3);expected_word[9]=frame(2);
    expected_word[10]=frame(0);expected_word[11]=frame(1);
    expected_word[12]=32'h10000001;
    #20;rst=0;
    #20;phase=1;dht11_valid=1;sr04_valid=1;
    #10;dht11_valid=0;
    #10;sr04_valid=0;
    #20;fifo_pop=1;
    #20;fifo_pop=0;
    #20;phase=2;watch_valid=1;
    #10;watch_valid=0;stopwatch_valid=1;
    #10;stopwatch_valid=0;
    #10;phase=3;dht11_valid=1;watch_valid=1;
    #10;dht11_valid=0;watch_valid=0;
    #20;phase=4;sr04_valid=1;stopwatch_valid=1;
    #10;sr04_valid=0;stopwatch_valid=0;
    #30;phase=5;dht11_valid=1;sr04_valid=1;
    #40;fifo_pop=1;
    #10;fifo_pop=0;
    #10;dht11_valid=0;
    #20;fifo_pop=1;
    #10;fifo_pop=0;
    #10;sr04_valid=0;
    #10;phase=6;fifo_pop=1;
    #40;fifo_pop=0;
    #30;

    phase=7;fifo_pop=1;error_code=1;error_occured=1;
    dht11_valid=1;sr04_valid=1;watch_valid=1;
    #10;dht11_valid=0;
    #10;sr04_valid=0;
    #10;watch_valid=0;stopwatch_valid=1;
    #10;stopwatch_valid=0;
    #10;error_occured=0;
    #20;fifo_pop=0;
    #10;
    if(writes!=13 || reads!=13 || !fifo_empty) fail=fail+1;
    $display("RESULT ARBITER_CONTROL writes=%0d reads=%0d fail=%0d",writes,reads,fail);
    $finish;
  end
endmodule
