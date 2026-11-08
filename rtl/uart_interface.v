`timescale 1ns / 1ps

module uart_interface(
    input clk,
    input rst,

    input i_uart_rx,
    output o_uart_tx,

    input [7:0] i_tx_data,
    input i_tx_push,
    output o_tx_can_issue,

    output [7:0]o_rx_data,
    output o_rx_valid,
    input i_rx_ready
    );

    wire w_b_tick;
    wire w_fifo_rx_push;
    wire [7:0] w_rx_fifo_push_data;
    wire [7:0] w_fifo_tx_pop_data;
    wire [7:0] w_rx_data;
    wire w_fifo_tx_full, w_fifo_tx_empty, w_fifo_tx_almost_full;
    wire w_fifo_rx_empty;
    wire w_tx_busy;

    assign o_tx_can_issue = ~w_fifo_tx_almost_full;

    assign o_rx_valid = ~w_fifo_rx_empty;
    assign o_rx_data = w_rx_data;
    baud_tick_gen U_BAUD_TICK_GEN (
        .clk    (clk),
        .rst    (rst),
        .b_tick (w_b_tick)
    );

    uart_rx U_UART_RX (
        .clk     (clk),
        .rst     (rst),
        .b_tick  (w_b_tick),
        .rx      (i_uart_rx),
        .rx_data (w_rx_fifo_push_data),
        .rx_done (w_fifo_rx_push)
    );

    fifo #(.DEPTH(16),
    .DATA_BIT_WIDTH(8))
    U_FIFO_RX
    (
        .clk       (clk),
        .rst       (rst),
        .push      (w_fifo_rx_push),
        .pop       (i_rx_ready),
        .data_push (w_rx_fifo_push_data),
        .data_pop  (w_rx_data),
        .full      (),
        .empty     (w_fifo_rx_empty),
        .almost_full ()
    );

    fifo #(.DEPTH(32),
    .DATA_BIT_WIDTH(8))
    U_FIFO_TX
    (
        .clk       (clk),
        .rst       (rst),
        .push      (i_tx_push),
        .pop       (~w_tx_busy),
        .data_push (i_tx_data),
        .data_pop  (w_fifo_tx_pop_data),
        .full      (w_fifo_tx_full),
        .empty     (w_fifo_tx_empty),
        .almost_full (w_fifo_tx_almost_full)
    );

    uart_tx U_UART_TX (
        .clk      (clk),
        .rst      (rst),
        .tx_start (~w_fifo_tx_empty),
        .tx_data  (w_fifo_tx_pop_data),
        .b_tick   (w_b_tick),
        .tx       (o_uart_tx),
        .tx_busy  (w_tx_busy)
    );

endmodule
