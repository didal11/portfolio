`timescale 1ns/1ps
module tb_ascii_check;
  localparam WATCH=0, STOPWATCH=1, DISTANCE=2, DHT11=3;
  reg clk=0,rst=1,bin_valid=0;
  always #5 clk=~clk;
  reg [31:0] bin=0;
  wire pop,ascii_valid;
  wire [7:0] ascii_data;
  integer response_type,k,hour,minute,field1,field2,cycles,index,errors;
  integer total=0,fail=0;
  integer type_fail[0:3];
  reg [7:0] want [0:31];
  integer length,j,n;
  reg [255:0] error_message;
  response_packetizer dut(.clk(clk),.rst(rst),.i_bin(bin),
    .i_bin_valid(bin_valid),.pop_response_fifo(pop),.i_tx_can_issue(1'b1),
    .o_ascii_data(ascii_data),.o_ascii_data_valid(ascii_valid));

  function [7:0] expected(input integer value,place);
    expected=8'h30+(value/place)%10;
  endfunction

  initial begin
    $display("\n=== TEST 3: ASCII PACKET CONTENT ===");
    $display("CHECK: header, field letters, decimal digits, spaces, LF, extra bytes");
    $display("CASES: each type = zero + maximum + 100 random");
    $display("tx_can_issue=1; byte-by-byte comparison on ascii_valid");
    for(response_type=0;response_type<4;response_type=response_type+1) type_fail[response_type]=0;
    repeat(3) @(negedge clk);rst=0;
    for(response_type=0;response_type<4;response_type=response_type+1) for(k=0;k<102;k=k+1) begin
      if(k==0)begin hour=0;minute=0;field1=0;field2=0;end
      else if(k==1)begin hour=23;minute=59;field1=(response_type==2)?511:(response_type==3)?255:59;field2=255;end
      else begin
        hour=(($random & 32'h7fffffff) % (23+1));
        minute=(($random & 32'h7fffffff) % (59+1));
        case(response_type)
          WATCH,STOPWATCH:field1=(($random & 32'h7fffffff) % (59+1));
          DISTANCE:field1=(($random & 32'h7fffffff) % (511+1));
          DHT11:field1=(($random & 32'h7fffffff) % (255+1));
        endcase
        field2=(($random & 32'h7fffffff) % (255+1));
      end

      case(response_type)
        WATCH:want[0]="W";
        STOPWATCH:want[0]="S";
        DISTANCE:want[0]="D";
        DHT11:want[0]="H";
      endcase
      length=1;
      for(j=0;j<((response_type==3)?4:3);j=j+1) begin
        want[length]=" ";
        case(j)
          0:begin want[length+1]="H";n=hour;end
          1:begin want[length+1]="M";n=minute;end
          2:begin
            n=field1;
            case(response_type)
              0,1:want[length+1]="S";
              2:want[length+1]="D";
              3:want[length+1]="H";
            endcase
          end
          3:begin want[length+1]="T";n=field2;end
        endcase
        length=length+2;
        if(n>=100) begin
          want[length]=expected(n,100);length=length+1;
        end
        want[length]=expected(n,10);
        want[length+1]=expected(n,1);
        length=length+2;
      end
      want[length]=8'h0a;length=length+1;
      @(negedge clk);
      bin=(response_type<<30)|(hour<<25)|(minute<<19)|(field1<<10)|((response_type==3)?(field2<<1):0);
      bin_valid=1;
      @(negedge clk);bin_valid=0;index=0;errors=0;cycles=0;

      while(index<length && cycles<1000)begin
        if(ascii_valid)begin
          if(ascii_data!==want[index])begin
            errors=errors+1;
            $display("FAIL ASCII type=%0d word=%08h byte=%0d expected=%02h actual=%02h",
              response_type,bin,index,want[index],ascii_data);
          end
          index=index+1;
        end
        @(negedge clk);cycles=cycles+1;
      end
      if(index!=length)begin errors=errors+1;$display("FAIL ASCII timeout word=%08h",bin);end
      repeat(4)begin
        if(ascii_valid)begin errors=errors+1;$display("FAIL ASCII extra byte=%02h",ascii_data);end
        @(negedge clk);
      end
      total=total+1;if(errors!=0)begin fail=fail+1;type_fail[response_type]=type_fail[response_type]+1;end
      if(errors==0)
        $display("PASS ASCII type=%0d case=%0d hour=%0d min=%0d field1=%0d field2=%0d bytes=%0d",
          response_type,k,hour,minute,field1,field2,index);
    end
    $display("--- ASCII PACKET SCOREBOARD ---");
    $display("Watch     [W H.. M.. S.. LF]     : total=102 PASS=%0d FAIL=%0d",102-type_fail[0],type_fail[0]);
    $display("Stopwatch [S H.. M.. S.. LF]     : total=102 PASS=%0d FAIL=%0d",102-type_fail[1],type_fail[1]);
    $display("Distance  [D H.. M.. D.. LF]     : total=102 PASS=%0d FAIL=%0d",102-type_fail[2],type_fail[2]);
    $display("Temp/Hum  [H H.. M.. H.. T.. LF] : total=102 PASS=%0d FAIL=%0d",102-type_fail[3],type_fail[3]);
    for(k=1;k<=9;k=k+1) begin
      case(k)
        1:error_message={"ERROR: not valid operation.",8'h0a};
        2:error_message={"ERROR: not valid target.",8'h0a};
        3:error_message={"ERROR: no time value.",8'h0a};
        4:error_message={"ERROR: not valid time.",8'h0a};
        5:error_message={"ERROR: command too long.",8'h0a};
        6:error_message={"ERROR: command time out.",8'h0a};
        7:error_message={"ERROR: now display mode.",8'h0a};
        8:error_message={"ERROR: not display mode.",8'h0a};
        9:error_message={"ERROR: unknown error.",8'h0a};
      endcase
      length=0;
      for(j=31;j>=0;j=j-1) begin
        if(error_message[j*8+:8]!=0) begin
          want[length]=error_message[j*8+:8];length=length+1;
        end
      end
      @(negedge clk);bin=(k<<28)|1;bin_valid=1;
      @(negedge clk);bin_valid=0;index=0;errors=0;cycles=0;
      while(index<length && cycles<1000) begin
        if(ascii_valid) begin
          if(ascii_data!==want[index]) errors=errors+1;
          index=index+1;
        end
        @(negedge clk);cycles=cycles+1;
      end
      if(index!=length) errors=errors+1;
      repeat(4) begin
        if(ascii_valid) errors=errors+1;
        @(negedge clk);
      end
      total=total+1;if(errors!=0) fail=fail+1;
      $display("ERROR ASCII code=%0d bytes=%0d PASS=%0d",k,index,(errors==0));
    end
    $display("RESULT ASCII total=%0d pass=%0d fail=%0d",total,total-fail,fail);
    $finish;
  end
endmodule
