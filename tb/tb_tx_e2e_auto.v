`timescale 1ns/1ps
module tb_tx_e2e_auto;
  parameter BAUD_TIME=104160;
  reg clk=0,rst=1;
  always #5 clk=~clk;
  reg [3:0] valid=0,error_code=0;
  reg error_occured=0;
  reg [16:0] watch_data=0,stopwatch_data=0;
  reg [8:0] distance_data=0;
  reg [15:0] ht_data=0;
  wire error_ready,response_empty,response_pop,tx_can_issue,ascii_valid,tx;
  wire [31:0] response_data;
  wire [7:0] ascii_data;
  reg [7:0] expected [0:1023];
  reg [7:0] received=0;
  integer kind[0:27],case_number[0:27];
  integer expected_len=0,sent=0,byte_count=0,packet_count=0;
  integer fail=0,packet_errors=0,packet_bytes=0,failed_packets=0;
  integer typ,k,hour,minute,field1,field2,b;
  integer checked[0:4],passed[0:4],failed[0:4];
  integer summary_index;

  response_arbiter U_ARB(.clk(clk),.rst(rst),
    .i_distance_data(distance_data),.i_distance_valid(valid[2]),.o_distance_ready(),
    .i_humid_temp_data(ht_data),.i_humid_temp_valid(valid[3]),.o_humid_temp_ready(),
    .i_watch_data(watch_data),.i_watch_valid(valid[0]),
    .i_stopwatch_data(stopwatch_data),.i_stopwatch_valid(valid[1]),
    .i_error_code(error_code),.error_occured(error_occured),.o_error_ready(error_ready),
    .o_w_pop_data(response_data),.i_response_fifo_pop(response_pop),
    .o_response_fifo_empty(response_empty));
  response_packetizer U_PACKETIZER(.clk(clk),.rst(rst),
    .i_bin(response_data),.i_bin_valid(~response_empty),.pop_response_fifo(response_pop),
    .i_tx_can_issue(tx_can_issue),.o_ascii_data(ascii_data),.o_ascii_data_valid(ascii_valid));
  uart_interface U_UART(.clk(clk),.rst(rst),.i_uart_rx(1'b1),.o_uart_tx(tx),
    .i_tx_data(ascii_data),.i_tx_push(ascii_valid),.o_tx_can_issue(tx_can_issue),
    .o_rx_data(),.o_rx_valid(),.i_rx_ready(1'b0));

  function [7:0] expected_digit;
    input integer value,place;
    begin expected_digit=8'h30+(value/place)%10; end
  endfunction
  task put;
    input [7:0] value;
    begin expected[expected_len]=value;expected_len=expected_len+1;end
  endtask
  task number;
    input integer value;
    begin
      if(value>=100) put(expected_digit(value,100));
      put(expected_digit(value,10));put(expected_digit(value,1));
    end
  endtask
  task normal_expected;
    input integer response_type,h,m,f1,f2;
    begin
      case(response_type)
        0:put("W");1:put("S");2:put("D");3:put("H");
      endcase
      put(" ");put("H");number(h);
      put(" ");put("M");number(m);
      put(" ");
      case(response_type)
        0,1:put("S");2:put("D");3:put("H");
      endcase
      number(f1);
      if(response_type==3) begin put(" ");put("T");number(f2);end
      put(8'h0a);
    end
  endtask
  task error_expected;
    input integer code;
    reg [255:0] message;
    integer j;
    begin
      case(code)
        1:message={"ERROR: not valid operation.",8'h0a};
        2:message={"ERROR: not valid target.",8'h0a};
        3:message={"ERROR: no time value.",8'h0a};
        4:message={"ERROR: not valid time.",8'h0a};
        5:message={"ERROR: command too long.",8'h0a};
        6:message={"ERROR: command time out.",8'h0a};
        7:message={"ERROR: now display mode.",8'h0a};
        8:message={"ERROR: not display mode.",8'h0a};
      endcase
      for(j=31;j>=0;j=j-1)
        if(message[j*8+:8]!=0) put(message[j*8+:8]);
    end
  endtask

  initial begin
    for(summary_index=0;summary_index<5;summary_index=summary_index+1) begin
      checked[summary_index]=0;passed[summary_index]=0;failed[summary_index]=0;
    end
    $display("E2E: actual UART TX pin, 9600 bps setting, 8N1");
    $display("Normal: each type = zero + maximum + 3 random; Error: codes 1..8");
    #20;rst=0;
    for(typ=0;typ<4;typ=typ+1) for(k=0;k<5;k=k+1) begin
      if(k==0) begin hour=0;minute=0;field1=0;field2=0;end
      else if(k==1) begin
        hour=23;minute=59;
        case(typ) 0,1:field1=59;2:field1=511;3:field1=255;endcase
        field2=255;
      end else begin
        hour=($random & 32'h7fffffff)%24;
        minute=($random & 32'h7fffffff)%60;
        case(typ)
          0,1:field1=($random & 32'h7fffffff)%60;
          2:field1=($random & 32'h7fffffff)%512;
          3:field1=($random & 32'h7fffffff)%256;
        endcase
        field2=($random & 32'h7fffffff)%256;
      end

      wait(!U_ARB.w_fifo_full);
      @(negedge clk);
      watch_data={hour[4:0],minute[5:0],field1[5:0]};
      stopwatch_data=watch_data;distance_data=field1;ht_data={field1[7:0],field2[7:0]};
      normal_expected(typ,hour,minute,field1,field2);
      kind[sent]=typ;case_number[sent]=k;sent=sent+1;
      valid=1<<typ;
      @(negedge clk);valid=0;
    end
    for(k=1;k<=8;k=k+1) begin
      wait(!U_ARB.w_fifo_full);
      @(negedge clk);
      error_expected(k);kind[sent]=4;case_number[sent]=k;sent=sent+1;
      error_code=k;error_occured=1;
      @(negedge clk);error_occured=0;
    end
    wait(packet_count==28);
    #(2*BAUD_TIME);
    if(byte_count!=expected_len || !response_empty || U_UART.w_tx_busy || !U_UART.w_fifo_tx_empty)
      fail=fail+1;
    $display("RESULT E2E normal=20 error=8 packets=%0d failed_packets=%0d expected_bytes=%0d received_bytes=%0d fail=%0d",
      packet_count,failed_packets,expected_len,byte_count,fail);
    $display("--- E2E SUMMARY ---");
    $display("TYPE        CHECKED   PASS   FAIL");
    $display("Watch       %7d%7d%7d",checked[0],passed[0],failed[0]);
    $display("Stopwatch   %7d%7d%7d",checked[1],passed[1],failed[1]);
    $display("SR04        %7d%7d%7d",checked[2],passed[2],failed[2]);
    $display("DHT11       %7d%7d%7d",checked[3],passed[3],failed[3]);
    $display("Error       %7d%7d%7d",checked[4],passed[4],failed[4]);
    $display("TOTAL packets=%0d PASS=%0d FAIL=%0d",packet_count,packet_count-failed_packets,failed_packets);
    $display("UART bytes: expected=%0d received=%0d",expected_len,byte_count);
    $display("COMPARE errors=%0d",fail);
    if(fail==0) $display("FINAL RESULT: PASS");
    else $display("FINAL RESULT: FAIL");
    $finish;
  end

  initial begin
    wait(!rst);
    forever begin
      @(negedge tx);
      #(BAUD_TIME+BAUD_TIME/2);
      for(b=0;b<8;b=b+1) begin received[b]=tx;#BAUD_TIME;end
      if(tx!==1'b1) begin fail=fail+1;packet_errors=packet_errors+1;end
      if(byte_count>=expected_len) begin fail=fail+1;packet_errors=packet_errors+1;end
      else if(received!==expected[byte_count]) begin
        fail=fail+1;packet_errors=packet_errors+1;
        $display("FAIL byte=%0d expected=0x%02h received=0x%02h",byte_count,expected[byte_count],received);
      end
      byte_count=byte_count+1;packet_bytes=packet_bytes+1;
      if(received==8'h0a) begin
        checked[kind[packet_count]]=checked[kind[packet_count]]+1;
        if(packet_errors==0) passed[kind[packet_count]]=passed[kind[packet_count]]+1;
        else failed[kind[packet_count]]=failed[kind[packet_count]]+1;
        if(packet_errors!=0) failed_packets=failed_packets+1;
        case(kind[packet_count])
          0:$display("WATCH case=%0d bytes=%0d PASS=%0d",case_number[packet_count],packet_bytes,packet_errors==0);
          1:$display("STOPWATCH case=%0d bytes=%0d PASS=%0d",case_number[packet_count],packet_bytes,packet_errors==0);
          2:$display("SR04 case=%0d bytes=%0d PASS=%0d",case_number[packet_count],packet_bytes,packet_errors==0);
          3:$display("DHT11 case=%0d bytes=%0d PASS=%0d",case_number[packet_count],packet_bytes,packet_errors==0);
          4:$display("ERROR code=%0d bytes=%0d PASS=%0d",case_number[packet_count],packet_bytes,packet_errors==0);
        endcase
        packet_count=packet_count+1;packet_bytes=0;packet_errors=0;
      end
    end
  end
  initial begin
    #800000000;$display("TIMEOUT packets=%0d bytes=%0d",packet_count,byte_count);$finish;
  end
endmodule
