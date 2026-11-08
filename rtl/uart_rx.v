`timescale 1ns / 1ps

module uart_rx (
    input clk,
    input rst,
    input rx,
    input b_tick,
    output [7:0] rx_data,
    output rx_done
);

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [1:0] c_state, n_state;
    reg [3:0] b_tick_count_reg, b_tick_count_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [7:0] rx_data_reg, rx_data_next;
    reg rx_done_reg, rx_done_next;

    assign rx_data = rx_data_reg;
    assign rx_done = rx_done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            b_tick_count_reg <= 4'b0;
            bit_count_reg <= 3'b0;
            rx_data_reg <= 8'h00;
            rx_done_reg <= 1'b0;
        end else begin
            c_state <= n_state;
            b_tick_count_reg <= b_tick_count_next;
            bit_count_reg <= bit_count_next;
            rx_data_reg <= rx_data_next;
            rx_done_reg <= rx_done_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        b_tick_count_next = b_tick_count_reg;
        bit_count_next = bit_count_reg;
        rx_data_next = rx_data_reg;
        rx_done_next = rx_done_reg;
        case (c_state)
            IDLE: begin
                rx_done_next = 1'b0;
                if (b_tick && rx == 0) n_state = START;
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_count_reg == 7) begin
                        b_tick_count_next = 0;
                        if (rx == 0) begin
                            n_state = DATA;
                            bit_count_next = 0;
                            rx_data_next = 8'h00;
                        end else begin
                            n_state = IDLE;
                        end
                    end else begin
                        b_tick_count_next = b_tick_count_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_count_reg == 15) begin
                        rx_data_next = {rx, rx_data_reg[7:1]};
                        b_tick_count_next = 0;
                        if (bit_count_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        b_tick_count_next = b_tick_count_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_count_reg == 15) begin
                        n_state = IDLE;
                        b_tick_count_next = 0;
                        rx_done_next = 1'b1;
                    end else begin
                        b_tick_count_next = b_tick_count_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
