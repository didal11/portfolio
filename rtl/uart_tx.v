`timescale 1ns / 1ps

module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input  [7:0] tx_data,
    input        b_tick,
    output       tx,
    output       tx_busy
);
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [2:0] c_state, n_state;
    reg [3:0] b_tick_count_reg, b_tick_count_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [7:0] data_reg, data_next;
    reg tx_reg, tx_next;
    reg tx_busy_reg, tx_busy_next;

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            b_tick_count_reg <= 4'b0;
            bit_count_reg <= 3'b0;
            data_reg <= 8'h00;
            tx_reg <= 1'b1;
            tx_busy_reg <= 1'b0;
        end else begin
            c_state <= n_state;
            b_tick_count_reg <= b_tick_count_next;
            bit_count_reg <= bit_count_next;
            data_reg <= data_next;
            tx_reg <= tx_next;
            tx_busy_reg <= tx_busy_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        b_tick_count_next = b_tick_count_reg;
        bit_count_next = bit_count_reg;
        data_next = data_reg;
        tx_next = tx_reg;
        tx_busy_next = tx_busy_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                tx_busy_next = 1'b0;
                if (tx_start) begin
                    b_tick_count_next = 0;
                    data_next = tx_data;
                    bit_count_next = 0;
                    tx_busy_next = 1'b1;
                    n_state   = START;
                end
            end
            START: begin
                tx_next = 1'b0;
                tx_busy_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_count_reg == 15) begin
                        b_tick_count_next = 0;
                        n_state = DATA;
                    end else begin
                        b_tick_count_next = b_tick_count_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_reg[0];
                if (b_tick) begin
                    if (b_tick_count_reg == 15) begin
                        b_tick_count_next = 0;
                        if (bit_count_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            data_next = {1'b0, data_reg[7:1]};
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        b_tick_count_next = b_tick_count_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_count_reg == 15) begin
                        tx_busy_next = 1'b0;
                        n_state = IDLE;
                    end else begin
                        b_tick_count_next = b_tick_count_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
