`timescale 1ns/1ps
module tb_double_dabble_check;
  reg clk=0, rst=1, start=0;
  always #5 clk=~clk;
  reg [8:0] bin=0;
  wire [11:0] actual;
  wire done;
  integer value, total=0, fail=0;
  double_dabble dut(.clk(clk),.rst(rst),.i_dd_start(start),
    .i_dd(bin),.o_bcd(actual),.o_dd_done(done));

  function automatic [11:0] expected(input integer value);
    begin
      expected[11:8]=value/100;
      expected[7:4]=(value/10)%10;
      expected[3:0]=value%10;
    end
  endfunction

  initial begin
    $display("\n=== TEST 2: DOUBLE DABBLE BIN TO BCD ===");
    $display("CHECK: input 0..511 -> expected hundreds/tens/ones vs actual BCD");
    $display("EXPECTED: n/100, (n/10)%%10, n%%10; wait for done, then compare BCD");
    repeat(3) @(negedge clk); rst=0;
    for(value=0;value<512;value=value+1) begin
      @(negedge clk); bin=value; start=1;
      @(negedge clk); start=0;
      wait(done);
      @(negedge clk);
      total=total+1;
      $display("CASE DD input=%0d expected=%03h actual=%03h pass=%0d",value,expected(value),actual,(done && actual===expected(value)));
      if(!done || actual!==expected(value)) begin
        fail=fail+1;
        $display("FAIL DD input=%0d expected=%03h actual=%03h",value,expected(value),actual);
      end
      @(negedge clk);
    end
    $display("--- DOUBLE DABBLE SCOREBOARD ---");
    $display("RESULT DD total=%0d pass=%0d fail=%0d",total,total-fail,fail);
    $finish;
  end
endmodule
