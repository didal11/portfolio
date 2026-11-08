`timescale 1ns / 1ps

module response_arbiter (
    input clk,
    input rst,

    input [8:0] i_distance_data,
    input i_distance_valid,
    output reg o_distance_ready,

    input [15:0] i_humid_temp_data,
    input i_humid_temp_valid,
    output reg o_humid_temp_ready,

    input [16:0] i_watch_data,
    input i_watch_valid,

    input [16:0] i_stopwatch_data,
    input i_stopwatch_valid,

    input [3:0] i_error_code,
    input error_occured,
    output reg o_error_ready,

    output [31:0] o_w_pop_data,

    input i_response_fifo_pop,
    output  o_response_fifo_empty
);

    localparam WATCH = 2'b00, STOPWATCH = 2'b01, DISTANCE = 2'b10, Temp_Humid = 2'b11;
    reg [31:0] w_fifo_push_data;
    reg w_fifo_push;

    wire [31:0] w_pop_data;

    assign o_w_pop_data = w_pop_data;

    always @(*) begin
        o_distance_ready = 0;
        o_humid_temp_ready = 0;
        o_error_ready = 0;
        w_fifo_push = 0;
        w_fifo_push_data = 0;
        if (~w_fifo_full) begin
            if (i_humid_temp_valid) begin
                o_humid_temp_ready = 1;
                w_fifo_push = 1;
                w_fifo_push_data = {Temp_Humid, i_watch_data[16:12], i_watch_data[11:6], 1'b0, i_humid_temp_data[15:8], 1'b0, i_humid_temp_data[7:0], 1'b0};
            end else if(i_distance_valid) begin
                o_distance_ready = 1;
                w_fifo_push = 1;
                w_fifo_push_data = {DISTANCE, i_watch_data[16:12], i_watch_data[11:6], i_distance_data[8:0], 9'b0_0000_0000, 1'b0};
            end else if(i_watch_valid) begin
                w_fifo_push = 1;
                w_fifo_push_data = {WATCH, i_watch_data[16:12], i_watch_data[11:6], 3'b000, i_watch_data[5:0], 9'b0_0000_0000, 1'b0};
            end else if(i_stopwatch_valid) begin
                w_fifo_push = 1;
                w_fifo_push_data = {STOPWATCH, i_stopwatch_data[16:12], i_stopwatch_data[11:6], 3'b000, i_stopwatch_data[5:0], 10'b00_0000_0000};
            end else if(error_occured) begin
                o_error_ready = 1;
                w_fifo_push = 1;
                w_fifo_push_data = {i_error_code, 27'b0, 1'b1};
            end
        end
    end

    fifo #(.DEPTH(4),
    .DATA_BIT_WIDTH(32))
    U_FIFO (
        .clk      (clk),
        .rst      (rst),
        .push     (w_fifo_push),
        .pop      (i_response_fifo_pop),
        .data_push(w_fifo_push_data),
        .data_pop (w_pop_data),
        .full     (w_fifo_full),
        .empty    (o_response_fifo_empty)
    );

endmodule
