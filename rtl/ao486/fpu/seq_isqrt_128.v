// seq_isqrt_128.v
//
// Sequential restoring 128-bit integer square root: M[127:0] -> 64-bit root
// floor(sqrt(M)) + 128-bit residual (M - root^2), computed one digit per clock
// over 64 cycles.  Synth-unblock (iter 147, Slice 4a -- the LAST FPU FPGA-build
// blocker).
//
// Replaces the combinational 64-iteration restoring isqrt unrolled in an
// always@* for-loop inside floatx80_sqrt.v: ModelSim flattens the loop fine but
// Quartus would infer a deep combinational ripple (or balloon area) and tank
// Fmax, exactly like softfloat_div_x80 / floatx80_remainder's native divides.
// Bit-exact with that comb loop (the recurrence below is identical).
//
// For the FSQRT operand the shifted significand M lands in [2^126, 2^128) so the
// root lands in [2^63, 2^64) (J-bit set); the primitive itself works for any
// M in [0, 2^128).
//
// Why a digit-by-digit restoring isqrt: `one` walks 2^126, 2^124, ... , 2^0 over
// 64 iterations; at each step it tries to set the next root digit (subtracting
// res+one from the running operand when it fits, then halving res).  After 64
// steps res = floor(sqrt(M)) and op = M - root^2.
//
// Handshake (mirrors seq_divider_128_64):
//   start : 1-cycle pulse latches M and begins the 64-cycle compute.  Ignored
//           while busy.
//   busy  : high during the compute.
//   done  : 1-cycle pulse when root/resid are valid (same edge they are
//           published; they then hold until the next compute).
//
`timescale 1ns / 1ps

module seq_isqrt_128 (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire [127:0] M,
    output reg  [63:0]  root,
    output reg  [127:0] resid,
    output reg          done,
    output wire         busy
);

    localparam S_IDLE = 1'b0;
    localparam S_RUN  = 1'b1;

    reg         state;
    reg [127:0] op_q;    // running operand (residual-in-progress)
    reg [127:0] res_q;   // running root accumulator
    reg [127:0] one_q;   // current digit weight: 2^126, 2^124, ... , 2^0
    reg [6:0]   cnt;     // counts down 64..1 over the 64 restoring steps

    assign busy = (state == S_RUN);

    // PR-2c.16 (iter 165f): each restoring step is now split across TWO clock cycles
    // to halve the per-cycle combinational depth.  The single-cycle recurrence chained
    // TWO serial 128-bit adders -- res_plus_one = res_q + one_q, THEN op_q - res_plus_one
    // (the compare `ge` is that same subtract's borrow) -- a ~28 ns path that could not
    // close at 90 MHz (STA: op_q = -17 ns) and, being an every-cycle iteration register,
    // CANNOT be multicycled.  Now phase 0 computes res_plus_one into the registered
    // rpo_q (one 128-bit add); phase 1 consumes rpo_q to produce op_next/res_next (one
    // 128-bit subtract + mux).  The recurrence is BIT-IDENTICAL to before -- rpo_q is
    // res_q + one_q evaluated while res_q/one_q are still the step's input values, and
    // op_q/res_q/one_q advance only on phase 1 -- so the FSQRT golden is unchanged.
    // Compute now takes 64*2 = 128 cycles (FSQRT is rare; S_SQRTWAIT just waits on done).
    reg         phase;   // sub-step: 0 = compute res_plus_one, 1 = apply
    reg [127:0] rpo_q;   // registered res_q + one_q (carried from phase 0 to phase 1)

    // phase-1 next-state -- IDENTICAL recurrence to floatx80_sqrt.v's comb loop, but
    // reading the REGISTERED rpo_q instead of a live (res_q + one_q):
    //   if (op >= rpo) { op -= rpo; res = (res>>1)+one; } else { res = res>>1; } one>>=2;
    wire         ge        = (op_q >= rpo_q);
    wire [127:0] op_next   = ge ? (op_q - rpo_q)          : op_q;
    wire [127:0] res_next  = ge ? ((res_q >> 1) + one_q)  : (res_q >> 1);
    wire [127:0] one_next  = one_q >> 2;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            done  <= 1'b0;
            root  <= 64'd0;
            resid <= 128'd0;
            op_q  <= 128'd0;
            res_q <= 128'd0;
            one_q <= 128'd0;
            rpo_q <= 128'd0;
            phase <= 1'b0;
            cnt   <= 7'd0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (start) begin
                        op_q  <= M;
                        res_q <= 128'd0;
                        one_q <= 128'd1 << 126;
                        cnt   <= 7'd64;
                        phase <= 1'b0;
                        state <= S_RUN;
                    end
                end
                S_RUN: begin
                    if (phase == 1'b0) begin
                        // phase 0: register res_plus_one for this digit
                        rpo_q <= res_q + one_q;
                        phase <= 1'b1;
                    end else begin
                        // phase 1: apply the restoring step using rpo_q
                        op_q  <= op_next;
                        res_q <= res_next;
                        one_q <= one_next;
                        cnt   <= cnt - 7'd1;
                        phase <= 1'b0;
                        if (cnt == 7'd1) begin   // 64th (final) step
                            root  <= res_next[63:0];
                            resid <= op_next;
                            done  <= 1'b1;
                            state <= S_IDLE;
                        end
                    end
                end
            endcase
        end
    end

endmodule
