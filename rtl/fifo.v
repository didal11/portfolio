`timescale 1ns / 1ps

module fifo #(
    parameter DEPTH = 4,
    DATA_BIT_WIDTH = 8,
    A_BIT_WIDTH = $clog2(DEPTH)
) (
    input clk,
    input rst,
    input push,
    input pop,
    input [DATA_BIT_WIDTH -1:0] data_push,
    output [DATA_BIT_WIDTH -1 :0] data_pop,
    output full,
    output empty,
    output almost_full
);

    wire [A_BIT_WIDTH-1 : 0] w_wptr, w_rptr;
    assign almost_full = full || ((w_wptr + 1'b1) == w_rptr);
    register_file #(
        .DEPTH(DEPTH),
        .DATA_BIT_WIDTH(DATA_BIT_WIDTH)
    ) U_REG_FILE (
        .clk(clk),
        .we((~full) & (push)),
        .wdata(data_push),
        .waddr(w_wptr),
        .raddr(w_rptr),
        .rdata(data_pop)
    );

    fifo_control_unit #(
        .A_BIT_WIDTH($clog2(DEPTH))
    ) U_CONTROL_UNIT (
        .clk  (clk),
        .rst  (rst),
        .push (push),
        .pop  (pop),
        .waddr(w_wptr),
        .raddr(w_rptr),
        .full (full),
        .empty(empty)
    );

endmodule

module register_file #(
    parameter DEPTH = 4,
    A_BIT_WIDTH = $clog2(DEPTH),
    DATA_BIT_WIDTH = 8
) (
    input                          clk,
    input                          we,
    input  [ DATA_BIT_WIDTH - 1:0] wdata,
    input  [      A_BIT_WIDTH-1:0] waddr,
    input  [      A_BIT_WIDTH-1:0] raddr,
    output [DATA_BIT_WIDTH -1 : 0] rdata
);

    reg [DATA_BIT_WIDTH-1:0] register_file[0:DEPTH-1];

    always @(posedge clk) begin
        if (we) begin
            register_file[waddr] <= wdata;
        end
    end

    assign rdata = register_file[raddr];

endmodule

module fifo_control_unit #(
    parameter A_BIT_WIDTH = 2
) (
    input clk,
    input rst,
    input push,
    input pop,
    output [A_BIT_WIDTH-1:0] waddr,
    output [A_BIT_WIDTH-1:0] raddr,
    output full,
    output empty
);

    reg [A_BIT_WIDTH-1 : 0] wptr_reg, wptr_next, rptr_reg, rptr_next;

    reg full_reg, full_next;
    reg empty_reg, empty_next;

    assign full = full_reg;
    assign empty = empty_reg;
    assign waddr = wptr_reg;
    assign raddr = rptr_reg;

    always @(posedge clk, posedge rst)
        if (rst) begin
            wptr_reg  <= 1'b0;
            rptr_reg  <= 1'b0;
            full_reg  <= 1'b0;
            empty_reg <= 1'b1;

        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end

    always @(*) begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;
        case ({
            push, pop
        })
            2'b10: begin
                if (!full_reg) begin
                    empty_next = 1'b0;
                    wptr_next  = wptr_reg + 1;
                    if (wptr_next == rptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end
            2'b01: begin
                if (!empty_reg) begin
                    full_next = 1'b0;
                    rptr_next = rptr_reg + 1;
                    if (rptr_next == wptr_reg) begin
                        empty_next = 1'b1;
                    end
                end
            end
            2'b11: begin
                if (full_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end else if (empty_reg) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    rptr_next = rptr_reg + 1;
                    wptr_next = wptr_reg + 1;
                end
            end
        endcase
    end
endmodule
