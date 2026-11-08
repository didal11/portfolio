`timescale 1ns/1ps
module tb_frame_check;
  reg clk=0,rst=1;
  always #5 clk=~clk;
  reg [8:0] distance_data=0;
  reg [15:0] ht_data=0;
  reg [16:0] watch_data=0,stopwatch_data=0;
  reg [3:0] valid=0;
  reg error_occured=0;
  reg [3:0] error_code=0;
  wire [31:0] actual;
  wire empty,dr,hr;
  integer t,k,total=0,fail=0;
  integer type_fail[0:3];
  response_arbiter dut(.clk(clk),.rst(rst),
    .i_distance_data(distance_data),.i_distance_valid(valid[2]),.o_distance_ready(dr),
    .i_humid_temp_data(ht_data),.i_humid_temp_valid(valid[3]),.o_humid_temp_ready(hr),
    .i_watch_data(watch_data),.i_watch_valid(valid[0]),
    .i_stopwatch_data(stopwatch_data),.i_stopwatch_valid(valid[1]),
    .i_error_code(error_code),.error_occured(error_occured),.o_error_ready(),
    .o_w_pop_data(actual),.i_response_fifo_pop(1'b0),.o_response_fifo_empty(empty));

  function automatic [31:0] expected(input integer typ);
    reg [4:0] h;
    reg [5:0] m;
    reg [8:0] f1,f2;
    begin
      h=(typ==1)?stopwatch_data[16:12]:watch_data[16:12];
      m=(typ==1)?stopwatch_data[11:6]:watch_data[11:6];
      f2=0;
      case(typ)
        0:f1=watch_data[5:0];
        1:f1=stopwatch_data[5:0];
        2:f1=distance_data;
        3:begin f1=ht_data[15:8];f2=ht_data[7:0];end
      endcase
      expected={typ[1:0],h,m,f1,f2,1'b0};
    end
  endfunction

  initial begin
    $display("\n=== TEST 1: RESPONSE FRAME COMPOSITION ===");
    $display("CHECK: TYPE | HOUR | MIN | FIELD1 | FIELD2 | RESERVED");
    $display("CASES: each type = zero + maximum + 100 random");
    for(t=0;t<4;t=t+1) type_fail[t]=0;
    for(t=0;t<4;t=t+1) for(k=0;k<102;k=k+1) begin
      @(negedge clk);rst=1;valid=0;
      repeat(2) @(negedge clk);
      if(k==0)begin watch_data=0;stopwatch_data=0;distance_data=0;ht_data=0;end
      else if(k==1)begin watch_data=17'h1ffff;stopwatch_data=17'h1ffff;distance_data=9'h1ff;ht_data=16'hffff;end
      else begin
        watch_data=$random();stopwatch_data=$random();
        distance_data=$random();ht_data=$random();
      end
      rst=0;valid=1<<t;
      @(negedge clk);valid=0;#1;total=total+1;
      $display("CASE FRAME type=%0d case=%0d watch=%05h stopwatch=%05h distance=%03h ht=%04h expected=%08h actual=%08h pass=%0d",
        t,k,watch_data,stopwatch_data,distance_data,ht_data,expected(t),actual,(empty===0 && actual===expected(t)));
      if(empty!==0 || actual!==expected(t))begin
        fail=fail+1;
        type_fail[t]=type_fail[t]+1;
        $display("FAIL FRAME type=%0d expected=%08h actual=%08h",t,expected(t),actual);
      end
    end
    $display("--- FRAME SCOREBOARD ---");
    $display("Watch     : total=102 PASS=%0d FAIL=%0d",102-type_fail[0],type_fail[0]);
    $display("Stopwatch : total=102 PASS=%0d FAIL=%0d",102-type_fail[1],type_fail[1]);
    $display("Distance  : total=102 PASS=%0d FAIL=%0d",102-type_fail[2],type_fail[2]);
    $display("Temp/Hum  : total=102 PASS=%0d FAIL=%0d",102-type_fail[3],type_fail[3]);
    for(k=1;k<=8;k=k+1) begin
      @(negedge clk);rst=1;valid=0;error_occured=0;
      repeat(2) @(negedge clk);
      rst=0;error_code=k;error_occured=1;
      @(negedge clk);error_occured=0;#1;total=total+1;
      if(empty!==0 || actual!=={error_code,27'b0,1'b1}) fail=fail+1;
      $display("ERROR FRAME code=%0d expected=%08h actual=%08h PASS=%0d",
        k,{error_code,27'b0,1'b1},actual,(empty===0 && actual==={error_code,27'b0,1'b1}));
    end
    $display("RESULT FRAME total=%0d pass=%0d fail=%0d",total,total-fail,fail);
    $finish;
  end
endmodule
