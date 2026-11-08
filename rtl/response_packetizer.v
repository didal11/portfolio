`timescale 1ns / 1ps

module response_packetizer (
    input clk,
    input rst,

    input [31:0] i_bin,
    input i_bin_valid,
    output reg pop_response_fifo,

    input i_tx_can_issue,
    output [7:0] o_ascii_data,
    output o_ascii_data_valid
);

    localparam WATCH = 2'b00, STOPWATCH = 2'b01, DISTANCE = 2'b10, Temp_Humid = 2'b11;
    localparam IDLE = 4'b0000, DD_START= 4'b0010, DD_WAIT= 4'b0011, SEND_ASCII = 4'b0100, SEND_TYPE_ASCII = 4'b0101, SEND_LF_ASCII = 4'b0110, SEND_HEADER_ASCII = 4'b0111, SEND_SPACE_ASCII = 4'b1000;

    localparam DECODE_ERROR = 4'b1001, SEND_ERROR = 4'b1010;
    localparam DEFAULT = 4'd0, CMD_NOT_VALID_OPERATION = 4'd1, CMD_NOT_VALID_TARGET = 4'd2,
               CMD_NO_TIME_VALUE = 4'd3, CMD_NOT_VALID_TIME = 4'd4, CMD_TOO_LONG = 4'd5, CMD_TIME_OUT = 4'd6,
               EXE_DISPLAY_MODE = 4'd7, EXE_NOT_DISPLAY_MODE = 4'd8;

    reg [31:0] bin_reg, bin_next;
    reg [3:0] state_reg, state_next;
    reg [1:0] field_cnt_reg, field_cnt_next;
    reg dd_start_reg, dd_start_next;
    reg [7:0] ascii_data_reg, ascii_data_next;
    reg ascii_data_valid_reg, ascii_data_valid_next;
    reg [1:0] digit_cnt_reg, digit_cnt_next;
    reg [8*32-1:0] msg_reg, msg_next;

    reg [8:0] dd;
    wire [11:0] w_bcd;
    wire w_dd_done;

    assign o_ascii_data = ascii_data_reg;
    assign o_ascii_data_valid = ascii_data_valid_reg;

    wire [8:0]hour = {4'b0000, bin_reg[29:25]};
    wire [8:0]min = {3'b000, bin_reg[24:19]};
    wire [8:0]field1 = {bin_reg[18:10]};
    wire [8:0]field2 = {bin_reg[9:1]};

    wire [1:0] last_field;
    assign last_field = (bin_reg[31:30] == Temp_Humid) ? 2'd3 : 2'd2;

    always @(*) begin
        case (field_cnt_reg)
            2'd0: dd = hour;
            2'd1: dd = min;
            2'd2: dd = field1;
            2'd3: dd = field2;
            default: dd = 9'd0;
        endcase
    end

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            bin_reg <= 0;
            state_reg <= 0;
            field_cnt_reg <= 0;
            dd_start_reg <= 0;
            ascii_data_reg <= 0;
            ascii_data_valid_reg <= 0;
            digit_cnt_reg <= 0;
            msg_reg <= 0;
        end else begin
            bin_reg <= bin_next;
            state_reg <= state_next;
            field_cnt_reg <= field_cnt_next;
            dd_start_reg <= dd_start_next;
            ascii_data_reg <= ascii_data_next;
            ascii_data_valid_reg <= ascii_data_valid_next;
            digit_cnt_reg <= digit_cnt_next;
            msg_reg <= msg_next;
        end
    end

    always @(*) begin
        bin_next = bin_reg;
        state_next = state_reg;
        field_cnt_next = field_cnt_reg;
        dd_start_next = 0;
        ascii_data_next = ascii_data_reg;
        ascii_data_valid_next = 0;
        digit_cnt_next = digit_cnt_reg;
        msg_next = msg_reg;
        pop_response_fifo = 0;
        case (state_reg)
            IDLE: begin
                if (i_bin_valid) begin
                    pop_response_fifo = 1;
                    bin_next = i_bin;
                    if (i_bin[0]) begin
                        state_next = DECODE_ERROR;
                    end else begin
                        state_next = SEND_HEADER_ASCII;
                    end

                end
            end

            SEND_HEADER_ASCII: begin
                if(i_tx_can_issue)begin
                    state_next = SEND_SPACE_ASCII;
                    ascii_data_valid_next = 1;
                    case(bin_reg[31:30])
                        WATCH: ascii_data_next = "W";
                        STOPWATCH: ascii_data_next = "S";
                        DISTANCE: ascii_data_next = "D";
                        Temp_Humid: ascii_data_next = "H";
                    endcase
                end
            end

            SEND_SPACE_ASCII: begin
                if(i_tx_can_issue)begin
                    state_next = SEND_TYPE_ASCII;
                    ascii_data_valid_next = 1;
                    ascii_data_next = " ";
                end
            end

            SEND_TYPE_ASCII: begin
                if(i_tx_can_issue)begin
                    state_next = DD_START;
                    ascii_data_valid_next = 1;
                    case(field_cnt_reg)
                        0: ascii_data_next = "H";
                        1: ascii_data_next = "M";
                        2: begin
                            case(bin_reg[31:30])
                                WATCH,STOPWATCH: ascii_data_next = "S";
                                DISTANCE: ascii_data_next = "D";
                                Temp_Humid: ascii_data_next = "H";
                            endcase
                        end
                        3: begin
                            ascii_data_next = "T";
                        end
                    endcase
                end
            end
            DD_START: begin
                dd_start_next = 1;
                state_next = DD_WAIT;
            end

            DD_WAIT: begin
                if (w_dd_done) begin
                    state_next = SEND_ASCII;
                end
            end

            SEND_ASCII: begin
                if (digit_cnt_reg == 2'd3) begin
                    digit_cnt_next = 0;
                    if (field_cnt_reg == last_field) begin
                        field_cnt_next = 0;
                        state_next = SEND_LF_ASCII;
                    end else begin
                        field_cnt_next = field_cnt_reg + 1;
                        state_next = SEND_SPACE_ASCII;
                    end
                end else if (i_tx_can_issue) begin
                    ascii_data_valid_next = 1;
                    digit_cnt_next = digit_cnt_reg + 1;
                    case (digit_cnt_reg)
                        2'd0: begin
                            if (w_bcd[11:8] == 4'd0)
                                ascii_data_valid_next = 0;
                            else
                                ascii_data_next = {4'd3, w_bcd[11:8]};
                        end
                        2'd1: ascii_data_next = {4'd3, w_bcd[7:4]};
                        2'd2: ascii_data_next = {4'd3, w_bcd[3:0]};
                    endcase
                end
            end

            SEND_LF_ASCII: begin
                if(i_tx_can_issue)begin
                    ascii_data_valid_next = 1;
                    ascii_data_next = 8'h0A;
                    state_next = IDLE;
                end
            end

            DECODE_ERROR: begin
                case (bin_reg[31:28])
                    CMD_NOT_VALID_OPERATION: msg_next = {"ERROR: not valid operation.", 8'h0A};
                    CMD_NOT_VALID_TARGET:    msg_next = {"ERROR: not valid target.", 8'h0A};
                    CMD_NO_TIME_VALUE:       msg_next = {"ERROR: no time value.", 8'h0A};
                    CMD_NOT_VALID_TIME:      msg_next = {"ERROR: not valid time.", 8'h0A};
                    CMD_TOO_LONG:            msg_next = {"ERROR: command too long.", 8'h0A};
                    CMD_TIME_OUT:            msg_next = {"ERROR: command time out.", 8'h0A};
                    EXE_DISPLAY_MODE:        msg_next = {"ERROR: now display mode.", 8'h0A};
                    EXE_NOT_DISPLAY_MODE:    msg_next = {"ERROR: not display mode.", 8'h0A};
                    default:                 msg_next = {"ERROR: unknown error.", 8'h0A};
                endcase
                state_next = SEND_ERROR;
            end

            SEND_ERROR: begin
                if (msg_reg == 0) begin
                    state_next = IDLE;
                end else if (msg_reg[8*32-1-:8] == 8'h00) begin
                    msg_next = msg_reg << 8;
                end else if (i_tx_can_issue) begin
                    ascii_data_valid_next = 1;
                    ascii_data_next = msg_reg[8*32-1-:8];
                    msg_next = msg_reg << 8;
                end
            end

            default: begin
                state_next = IDLE;
                ascii_data_valid_next = 0;
            end
        endcase
    end

    double_dabble U_DOUBLE_DABBLE (
        .clk(clk),
        .rst(rst),

        .i_dd_start(dd_start_reg),
        .i_dd(dd),
        .o_bcd(w_bcd),
        .o_dd_done(w_dd_done)

    );

endmodule

module double_dabble (
    input clk,
    input rst,

    input i_dd_start,
    input [8:0] i_dd,
    output [11:0] o_bcd,
    output reg o_dd_done

);

    reg state_reg, state_next;
    reg [3:0] counter_reg, counter_next;
    reg [11:0] bcd_reg, bcd_next;
    wire [11:0] add_3;
    assign o_bcd = bcd_reg;
    assign add_3[3:0] = (bcd_reg[3:0] >= 5) ? bcd_reg[3:0] + 3 : bcd_reg[3:0];
    assign add_3[7:4] = (bcd_reg[7:4] >= 5) ? bcd_reg[7:4] + 3 : bcd_reg[7:4];
    assign add_3[11:8] = (bcd_reg [11:8]>=5) ? bcd_reg [11:8] + 3: bcd_reg [11:8];

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            bcd_reg <= 0;
            counter_reg <= 0;
            state_reg <= 0;
        end else begin
            bcd_reg <= bcd_next;
            counter_reg <= counter_next;
            state_reg <= state_next;
        end
    end

    always @(*) begin
        o_dd_done = 0;
        bcd_next = bcd_reg;
        counter_next = counter_reg;
        state_next = state_reg;
        case (state_reg)
            1'b0: begin
                if (i_dd_start) begin
                    state_next = 1'b1;
                    bcd_next = 0;
                end
            end
            1'b1: begin
                if (counter_reg == 9) begin
                    counter_next = 0;
                    o_dd_done   = 1;
                    state_next  = 1'b0;
                end else begin
                    o_dd_done = 0;
                    bcd_next = {add_3[10:0], i_dd[8-counter_reg]};
                    counter_next = counter_reg + 1;
                end
            end
        endcase
    end
endmodule
