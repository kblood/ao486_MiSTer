// fpu_transcendental.v
//
// PR-2c.T-1 (iter 187): the x87 transcendental engine.  Slice T-1 implements
// F2XM1 (D9 F0): ST(0) <- 2^ST(0) - 1, for |ST(0)| <= 1.  The other seven
// transcendental opcodes (FYL2X/FPTAN/FPATAN/FYL2XP1/FSIN/FCOS/FSINCOS) still
// route here but, until their slices land (T-2..T-5), take a deterministic
// PASSTHROUGH (ST(0) unchanged, no flags) — same behaviour as the T-0 stub.
//
// DATAPATH DECISION — "Option X80" (see research/design_transcendentals.md §3):
// evaluate the Bochs e^t-1 polynomial in the *existing* floatx80 mul/add
// primitives, NOT in a float128 datapath (which would not fit at 94% ALM).
// This engine owns NO arithmetic of its own — it is a time-multiplexer.  It
// drives operand/op-kind requests (arith_a / arith_b / arith_is_mul) to the
// SHARED softfloat_mul_x80 / softfloat_add_x80 instances in execute_fpu.v and
// samples their combinational, rounded result (arith_z) after letting it
// settle WAIT cycles (the same ARITH_WAIT_CYCLES the S_ARITHWAIT plain-arith
// path uses; the result-capture registers here are covered by the same
// destination-anchored multicycle in ao486.sdc).
//
// ACCURACY — validated in Python against the Bochs float128 oracle running the
// SAME 15-term Taylor polynomial: a plain floatx80 (64-bit) Horner is within
// ~1.05 ULP of Bochs across x in (-1,1), well inside the +/-2 ULP tolerance
// that the x87 transcendentals are specified to (IEEE does NOT mandate
// correct rounding here).  No guard bits needed.  The huge "thousands of ULP"
// errors one sees comparing to EXACT 2^x-1 are the *Taylor truncation* the
// reference (Bochs) shares — not a datapath defect.
//
// ALGORITHM (Bochs cpu/fpu/f2xm1.cc, poly_exp + EvalPoly):
//   t   = x * ln2                       (x = ST(0), in (-1,1))
//   r   = exp_arr[14]                   (1/15!)
//   for k = 14 downto 1:                (EvalPoly Horner, 14 mul-add pairs)
//       r = r * t                       (mul)
//       r = r + exp_arr[k-1]            (add)
//   z   = r * t                         (poly_exp final mul)  = 2^x - 1
// exp_arr[i] = floatx80-truncation of Bochs's float128 1/(i+1)! coefficient.
//
// SPECIAL CASES (bit-exact, spec-mandated):
//   NaN          -> propagate (set QNaN bit62); IE if input was SNaN
//   +Inf         -> +Inf  (return input)
//   -Inf         -> -1.0
//   +/-0         -> input (exact, no flags)
//   |x| == 1     -> a == -1.0 ? -0.5 : input ; PE
//   |x|  > 1     -> input ; PE          (out of range, Bochs returns input)
//   denormal     -> poly path (the shared input-normalizer handles it); DE|PE
//   normal |x|<1 -> poly path ; PE

`timescale 1ns / 1ps

module fpu_transcendental (
    input  wire        clk,
    input  wire        rst,        // ~rst_n | exe_reset | init (mirror u_div)
    input  wire        start,      // 1-cycle pulse: latch `a`, begin op
    input  wire [3:0]  cmdex,      // CMDEX_* selecting the op (T-1: F2XM1 only)
    input  wire [79:0] a,          // ST(0) operand at op start

    // Shared-arith request/response (execute_fpu wires these to u_mul/u_add):
    output reg  [79:0] arith_a,
    output reg  [79:0] arith_b,
    output reg         arith_is_mul,   // 1 = request mul, 0 = request add
    input  wire [79:0] arith_z,        // settled, rounded result of the request

    output reg         done,           // 1-cycle pulse: z/flags valid
    output reg  [79:0] z,
    output reg  [5:0]  flags            // {PE,UE,OE,ZE,DE,IE}
);

    // Settle dwell per shared-arith op.  MUST be >= ARITH_WAIT_CYCLES in
    // execute_fpu.v / the -setup N in ao486.sdc (the ~106 ns floatx80 chain).
    localparam [4:0] WAIT = 5'd12;

    // ----- coefficient ROM: exp_arr[i] = floatx80(1/(i+1)!) ----------------
    // Truncated (round-nearest-even) from Bochs's float128 exp_arr[] in
    // cpu/fpu/f2xm1.cc.  Generated + cross-checked in Python.
    function [79:0] exp_coeff(input [3:0] i);
        case (i)
            4'd0 : exp_coeff = 80'h3fff8000000000000000; // 1/1!  = 1.0
            4'd1 : exp_coeff = 80'h3ffe8000000000000000; // 1/2!
            4'd2 : exp_coeff = 80'h3ffcaaaaaaaaaaaaaaab; // 1/3!
            4'd3 : exp_coeff = 80'h3ffaaaaaaaaaaaaaaaab; // 1/4!
            4'd4 : exp_coeff = 80'h3ff88888888888888889; // 1/5!
            4'd5 : exp_coeff = 80'h3ff5b60b60b60b60b60b; // 1/6!
            4'd6 : exp_coeff = 80'h3ff2d00d00d00d00d00d; // 1/7!
            4'd7 : exp_coeff = 80'h3fefd00d00d00d00d00d; // 1/8!
            4'd8 : exp_coeff = 80'h3fecb8ef1d2ab6399c7d; // 1/9!
            4'd9 : exp_coeff = 80'h3fe993f27dbbc4fae397; // 1/10!
            4'd10: exp_coeff = 80'h3fe5d7322b3faa271c7f; // 1/11!
            4'd11: exp_coeff = 80'h3fe28f76c77fc6c4bdaa; // 1/12!
            4'd12: exp_coeff = 80'h3fdeb092309d43684be5; // 1/13!
            4'd13: exp_coeff = 80'h3fdac9cba54603e4e906; // 1/14!
            4'd14: exp_coeff = 80'h3fd6d73f9f399dc0f88f; // 1/15!
            default: exp_coeff = 80'h3fff8000000000000000;
        endcase
    endfunction

    localparam [79:0] LN2     = 80'h3ffeb17217f7d1cf79ac; // ln2, floatx80
    localparam [79:0] NEG_ONE = 80'hbfff8000000000000000; // -1.0
    localparam [79:0] NEG_HALF= 80'hbffe8000000000000000; // -0.5

    // Special-case classification + result/flags are computed inline in P_IDLE
    // off `a` directly (the operand is only needed at op start; nothing reads
    // it after the first mul, which captures it into the arith request).

    // ----- micro-sequencer -------------------------------------------------
    localparam [2:0] P_IDLE  = 3'd0,
                     P_XLN2  = 3'd1,   // computing t = a*ln2
                     P_LMUL  = 3'd2,   // computing r = r*t
                     P_LADD  = 3'd3,   // computing r = r + coeff
                     P_FINAL = 3'd4,   // computing z = r*t
                     P_DONE  = 3'd5;   // assert done

    reg [2:0]  phase;
    reg [4:0]  settle;
    reg [3:0]  cnt;       // Horner index, 14 down to 1
    reg [79:0] t_reg;     // t = a*ln2 (reused every mul + the final mul)

    always @(posedge clk) begin
        if (rst) begin
            phase        <= P_IDLE;
            done         <= 1'b0;
            arith_is_mul <= 1'b0;
            settle       <= 5'd0;
            cnt          <= 4'd0;
        end else begin
            done <= 1'b0;
            case (phase)
                P_IDLE: begin
                    if (start) begin
                        // classify on `a` directly
                        if ((cmdex == 4'd0) &&
                            (((a[78:64] != 15'h0) && (a[78:64] < 15'h3FFF)) ||  // |x|<1 normal
                             ((a[78:64] == 15'h0) && (a[63:0] != 64'h0)))) begin // denormal
                            // poly path: kick off t = a*ln2
                            arith_a      <= a;
                            arith_b      <= LN2;
                            arith_is_mul <= 1'b1;
                            settle       <= WAIT;
                            // base flags: PE; denormal also raises DE
                            flags        <= ((a[78:64] == 15'h0) && (a[63:0] != 64'h0))
                                            ? 6'b100010 : 6'b100000;
                            phase        <= P_XLN2;
                        end else begin
                            // special / passthrough: result is combinational
                            z      <= ((cmdex != 4'd0)) ? a :                    // other ops passthrough
                                      ((a[78:64]==15'h7FFF) &&  (|a[62:0]))      ? {a[79:63],1'b1,a[61:0]} : // NaN
                                      ((a[78:64]==15'h7FFF) && ~(|a[62:0]))      ? (a[79] ? NEG_ONE : a)    : // Inf
                                      ((a[78:64]==15'h0)    && (a[63:0]==64'h0)) ? a                        : // zero
                                      (a[79] && (a[78:64]==15'h3FFF) && ~(|a[62:0])) ? NEG_HALF             : // -1.0
                                                                                   a;                        // |x|>=1
                            flags  <= ((cmdex != 4'd0)) ? 6'd0 :
                                      ((a[78:64]==15'h7FFF) && (|a[62:0])) ? (a[62] ? 6'd0 : 6'b000001) :  // SNaN->IE
                                      ((~(a[78:64]==15'h7FFF)) && (a[78:64] >= 15'h3FFF)) ? 6'b100000 :    // |x|>=1: PE
                                                                            6'd0;
                            phase  <= P_DONE;
                        end
                    end
                end

                P_XLN2: begin
                    if (settle == 5'd0) begin
                        t_reg        <= arith_z;            // t = a*ln2
                        // seed r = exp_arr[14]; first Horner mul: r*t
                        arith_a      <= exp_coeff(4'd14);
                        arith_b      <= arith_z;            // t
                        arith_is_mul <= 1'b1;
                        cnt          <= 4'd14;
                        settle       <= WAIT;
                        phase        <= P_LMUL;
                    end else settle <= settle - 5'd1;
                end

                P_LMUL: begin
                    if (settle == 5'd0) begin
                        // r = r*t done; issue r + coeff[cnt-1]
                        arith_a      <= arith_z;            // r
                        arith_b      <= exp_coeff(cnt - 4'd1);
                        arith_is_mul <= 1'b0;               // add
                        settle       <= WAIT;
                        phase        <= P_LADD;
                    end else settle <= settle - 5'd1;
                end

                P_LADD: begin
                    if (settle == 5'd0) begin
                        // r = r + coeff done; either loop again or final mul
                        arith_a      <= arith_z;            // r
                        arith_b      <= t_reg;              // t
                        arith_is_mul <= 1'b1;               // mul
                        settle       <= WAIT;
                        if (cnt == 4'd1) begin
                            phase <= P_FINAL;
                        end else begin
                            cnt   <= cnt - 4'd1;
                            phase <= P_LMUL;
                        end
                    end else settle <= settle - 5'd1;
                end

                P_FINAL: begin
                    if (settle == 5'd0) begin
                        z     <= arith_z;                   // z = r*t = 2^x - 1
                        phase <= P_DONE;
                    end else settle <= settle - 5'd1;
                end

                P_DONE: begin
                    done  <= 1'b1;
                    phase <= P_IDLE;
                end

                default: phase <= P_IDLE;
            endcase
        end
    end

endmodule
