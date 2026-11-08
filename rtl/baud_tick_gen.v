`timescale 1ns / 1ps

module baud_tick_gen (
    input      clk,
    input      rst,
    output reg b_tick
);

    parameter F_COUNT = 100_000_000 / (9600 * 16);

    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            b_tick <= 1'b0;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick <= 1'b1;
            end
        end
    end

endmodule
