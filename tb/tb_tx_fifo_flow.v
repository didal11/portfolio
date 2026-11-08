`timescale 1ns/1ps
module tb_tx_fifo_flow;
  reg clk=0, rst=1, watch_valid=0;
  always #5 clk=~clk;
  wire [16:0] watch_data={5'd12,6'd34,6'd56};
  wire rsp_pop, rsp_empty, tx_can_issue, tx_fifo_push, tx;
  wire [31:0] rsp_read_data;
  wire [7:0] tx_fifo_push_data;
  integer count=0, errors=0;
  reg [111:0] expected={"W H12 M34 S56",8'h0a};
  response_arbiter U_ARB(.clk(clk),.rst(rst),
    .i_distance_data(9'd0),.i_distance_valid(1'b0),.o_distance_ready(),
    .i_humid_temp_data(16'd0),.i_humid_temp_valid(1'b0),.o_humid_temp_ready(),
    .i_watch_data(watch_data),.i_watch_valid(watch_valid),
    .i_stopwatch_data(17'd0),.i_stopwatch_valid(1'b0),
    .i_error_code(4'd0),.error_occured(1'b0),.o_error_ready(),
    .o_w_pop_data(rsp_read_data),.i_response_fifo_pop(rsp_pop),.o_response_fifo_empty(rsp_empty));
  response_packetizer U_PACKETIZER(.clk(clk),.rst(rst),.i_bin(rsp_read_data),
    .i_bin_valid(~rsp_empty),.pop_response_fifo(rsp_pop),.i_tx_can_issue(tx_can_issue),
    .o_ascii_data(tx_fifo_push_data),.o_ascii_data_valid(tx_fifo_push));
  uart_interface U_UART(.clk(clk),.rst(rst),.i_uart_rx(1'b1),.o_uart_tx(tx),
    .i_tx_data(tx_fifo_push_data),.i_tx_push(tx_fifo_push),.o_tx_can_issue(tx_can_issue),
    .o_rx_data(),.o_rx_valid(),.i_rx_ready(1'b0));
  always @(posedge clk) if (!rst) begin
    if (U_ARB.w_fifo_push) $display("RSP_PUSH %0t data=%08h",$time,U_ARB.w_fifo_push_data);
    if (rsp_pop) $display("RSP_POP %0t data=%08h",$time,rsp_read_data);
    if (tx_fifo_push) begin
      if(count>=14) errors=errors+1;
      else if(tx_fifo_push_data!==expected[(13-count)*8+:8]) errors=errors+1;
      $display("TX_FIFO_PUSH %0t byte=%0d data=%02h",$time,count,tx_fifo_push_data);
      count=count+1;
    end
  end
  initial begin
    #20; rst=0;
    #20; watch_valid=1;
    #10; watch_valid=0;
    wait(count==14);
    #30; $display("RESULT TX_FIFO_FLOW bytes=%0d errors=%0d",count,errors); $finish;
  end
  initial begin #10000; $display("TIMEOUT bytes=%0d",count); $finish; end
endmodule
