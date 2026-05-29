// seq_divider_128_64.v
//
// Sequential restoring divider: 128-bit numerator / 64-bit denominator ->
// 64-bit quotient + 64-bit remainder, computed one bit per clock over 64
// cycles.  Synth-unblock (iter 142, Slice 1 of the FPU FPGA-build prep).
//
// PRECONDITION: num[127:64] < den (the high half of the numerator is strictly
// less than the divisor), so the quotient fits in exactly 64 bits.  This holds
// for BOTH 128/64 divides inside softfloat_div_x80:
//   first  divide: num = {a_sig_eff, rem1_init}, a_sig_eff < b_sig = den.
//   second divide: num = {rem_after, 64'd0},     rem_after  < b_sig = den.
// (Each b_sig is a normalized significand, so den >= 2^63 with bit63 set.)
//
// Replaces the combinational native `/` and `%` on 128-bit operands that
// ModelSim flattens but Quartus would balloon into a giant ripple divider
// (the standing FPU synth blocker).  Bit-exact with `num / {64'd0,den}` and
// `num % {64'd0,den}`.
//
// Why this works: in a full 128-bit long division of {num_hi,num_lo}, the
// first 64 MSB-first steps (over num_hi's bits) all emit quotient bit 0 and
// leave the running remainder equal to num_hi (because num_hi < den).  So we
// SKIP them: seed the remainder with num_hi and process only num_lo's 64 bits.
//
// Handshake:
//   start : 1-cycle pulse latches num/den and begins the 64-cycle compute.
//           Ignored while busy.
//   busy  : high during the compute.
//   done  : 1-cycle pulse when quotient/remainder are valid (same edge they
//           are published; they then hold until the next compute).
//
`timescale 1ns / 1ps

module seq_divider_128_64 (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire [127:0] num,
    input  wire [63:0]  den,
    output reg  [63:0]  quotient,
    output reg  [63:0]  remainder,
    output reg          done,
    output wire         busy
);

    localparam S_IDLE = 1'b0;
    localparam S_RUN  = 1'b1;

    reg        state;
    reg [63:0] rem_q;     // running remainder (stays < den, fits in 64 bits)
    reg [63:0] quo_q;     // quotient accumulator (MSB-first, left-shift)
    reg [63:0] num_lo;    // low 64 bits, shifted out MSB-first
    reg [6:0]  cnt;       // counts down 64..1 over the 64 restoring steps

    assign busy = (state == S_RUN);

    // One restoring step: shift remainder left, bring in the next numerator
    // bit (current MSB of num_lo), conditionally subtract the divisor.
    wire [64:0] rem_shift = {rem_q, num_lo[63]};       // (rem<<1)|bit, 65-bit
    wire        sub_ge    = (rem_shift >= {1'b0, den});
    wire [64:0] rem_sub   = rem_shift - {1'b0, den};   // valid only when sub_ge
    wire [63:0] rem_next  = sub_ge ? rem_sub[63:0] : rem_shift[63:0];
    wire [63:0] quo_next  = {quo_q[62:0], sub_ge};

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            done      <= 1'b0;
            quotient  <= 64'd0;
            remainder <= 64'd0;
            rem_q     <= 64'd0;
            quo_q     <= 64'd0;
            num_lo    <= 64'd0;
            cnt       <= 7'd0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (start) begin
                        rem_q  <= num[127:64];   // < den by precondition
                        num_lo <= num[63:0];
                        quo_q  <= 64'd0;
                        cnt    <= 7'd64;
                        state  <= S_RUN;
                    end
                end
                S_RUN: begin
                    rem_q  <= rem_next;
                    quo_q  <= quo_next;
                    num_lo <= {num_lo[62:0], 1'b0};
                    cnt    <= cnt - 7'd1;
                    if (cnt == 7'd1) begin       // 64th (final) step
                        quotient  <= quo_next;
                        remainder <= rem_next;
                        done      <= 1'b1;
                        state     <= S_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
