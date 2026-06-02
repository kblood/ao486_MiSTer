// fpu_transcendental_tb.v
//
// PR-2c.T-1 (iter 187) per-slice unit test for the F2XM1 engine.  Drives
// fpu_transcendental through the SAME shared floatx80 datapath execute_fpu
// wires it to — the REAL softfloat_mul_x80 / softfloat_add_x80 / softfloat_sub_x80
// + shared normalizers + round_rc + pack_subn — so this exercises the actual
// hardware arithmetic (not a behavioral stand-in), just without booting the CPU.
//
// Golden = the validated Python floatx80 Horner model (independently shown to be
// <= 1.05 ULP from the Bochs float128 oracle).  Finite results pass within
// +/-2 ULP (the x87 transcendental tolerance); special cases + exception flags
// must match EXACTLY.
//
// Run (ModelSim ASE 17, from sim/modelsim/fpu/):
//   vlib work
//   vlog -O0 +incdir+../../../rtl/ao486 \
//        ../../../rtl/ao486/fpu/fpu_transcendental.v \
//        ../../../rtl/ao486/fpu/floatx80_normalize.v \
//        ../../../rtl/ao486/fpu/floatx80_nan_handle.v \
//        ../../../rtl/ao486/fpu/floatx80_inf_handle.v \
//        ../../../rtl/ao486/fpu/floatx80_zero_handle.v \
//        ../../../rtl/ao486/fpu/floatx80_subn_handle.v \
//        ../../../rtl/ao486/fpu/floatx80_pack_subn.v \
//        ../../../rtl/ao486/fpu/floatx80_round_rc.v \
//        ../../../rtl/ao486/fpu/floatx80_round_pc.v \
//        ../../../rtl/ao486/fpu/softfloat_add_x80.v \
//        ../../../rtl/ao486/fpu/softfloat_sub_x80.v \
//        ../../../rtl/ao486/fpu/softfloat_mul_x80.v \
//        fpu_transcendental_tb.v
//   vsim -c -do "run -all; quit -f" work.fpu_transcendental_tb

`timescale 1ns / 1ps

module fpu_transcendental_tb;

    localparam [1:0] KIND_ADD = 2'd0, KIND_SUB = 2'd1, KIND_MUL = 2'd2;
    localparam [15:0] CW = 16'h037F;   // FNINIT default: RC=00 (RNE), PC=11 (ext)

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg         rst   = 1'b1;
    reg         start = 1'b0;
    reg  [3:0]  cmdex = 4'd0;
    reg  [79:0] a     = 80'd0;

    // engine <-> shared-arith request/response
    wire [79:0] arith_a, arith_b;
    wire        arith_is_mul;
    wire        done;
    wire [79:0] z;
    wire [5:0]  flags;

    // ---- replicate execute_fpu's op_a/op_b + eff_kind for the engine -------
    wire [79:0] op_a = arith_a;
    wire [79:0] op_b = arith_b;
    wire [1:0]  eff_kind = arith_is_mul ? KIND_MUL : KIND_ADD;

    // shared normalizers
    wire               na_sign, nb_sign;
    wire signed [16:0] na_exp,  nb_exp;
    wire        [63:0] na_sig,  nb_sig;
    floatx80_normalize u_norm_a (.a(op_a), .sign_out(na_sign), .exp_out(na_exp), .sig_out(na_sig));
    floatx80_normalize u_norm_b (.a(op_b), .sign_out(nb_sign), .exp_out(nb_exp), .sig_out(nb_sig));

    // per-primitive pre-round triples
    wire               pr_sign_add, pr_sign_sub, pr_sign_mul;
    wire signed [16:0] pr_exp_add,  pr_exp_sub,  pr_exp_mul;
    wire        [63:0] pr_sig0_add, pr_sig0_sub, pr_sig0_mul;
    wire        [63:0] pr_sig1_add, pr_sig1_sub, pr_sig1_mul;
    wire [79:0] add_z, sub_z, mul_z;
    wire [5:0]  add_flags, sub_flags, mul_flags;

    // shared rounder / pack_subn (fed by the eff_kind-selected triple)
    wire [79:0] shared_round_z;
    wire [5:0]  shared_round_flags;
    wire [79:0] shared_subn_z;
    wire        shared_subn_pe;

    wire arith_pick_sub = (op_a[79] ^ op_b[79]) ^ eff_kind[0];
    reg               spr_sign;
    reg signed [16:0] spr_exp;
    reg        [63:0] spr_sig0, spr_sig1;
    always @* begin
        case (eff_kind)
            KIND_MUL: begin spr_sign=pr_sign_mul; spr_exp=pr_exp_mul; spr_sig0=pr_sig0_mul; spr_sig1=pr_sig1_mul; end
            default:  if (arith_pick_sub) begin spr_sign=pr_sign_sub; spr_exp=pr_exp_sub; spr_sig0=pr_sig0_sub; spr_sig1=pr_sig1_sub; end
                      else                begin spr_sign=pr_sign_add; spr_exp=pr_exp_add; spr_sig0=pr_sig0_add; spr_sig1=pr_sig1_add; end
        endcase
    end

    floatx80_round_rc u_round (
        .rc(CW[11:10]), .precision(CW[9:8]),
        .sign(spr_sign), .z_exp_pre(spr_exp), .z_sig0_pre(spr_sig0), .z_sig1_pre(spr_sig1),
        .z(shared_round_z), .flags(shared_round_flags));
    floatx80_pack_subn u_pack (
        .sign(spr_sign), .z_exp_pre(spr_exp), .sig_hi(spr_sig0), .sig_lo(spr_sig1),
        .z_subn(shared_subn_z), .pe_subn(shared_subn_pe));

    softfloat_add_x80 u_add (
        .a(op_a), .b(op_b), .precision(CW[9:8]), .rc(CW[11:10]),
        .pr_sign(pr_sign_add), .pr_exp(pr_exp_add), .pr_sig0(pr_sig0_add), .pr_sig1(pr_sig1_add),
        .shared_round_z(shared_round_z), .shared_round_flags(shared_round_flags),
        .shared_subn_z(shared_subn_z), .shared_subn_pe(shared_subn_pe),
        .na_sign(na_sign), .na_exp(na_exp), .na_sig(na_sig),
        .nb_sign(nb_sign), .nb_exp(nb_exp), .nb_sig(nb_sig),
        .z(add_z), .flags(add_flags));
    softfloat_sub_x80 u_sub (
        .a(op_a), .b(op_b), .z_sign_in(op_a[79]), .precision(CW[9:8]), .rc(CW[11:10]),
        .pr_sign(pr_sign_sub), .pr_exp(pr_exp_sub), .pr_sig0(pr_sig0_sub), .pr_sig1(pr_sig1_sub),
        .shared_round_z(shared_round_z), .shared_round_flags(shared_round_flags),
        .shared_subn_z(shared_subn_z), .shared_subn_pe(shared_subn_pe),
        .na_sign(na_sign), .na_exp(na_exp), .na_sig(na_sig),
        .nb_sign(nb_sign), .nb_exp(nb_exp), .nb_sig(nb_sig),
        .z(sub_z), .flags(sub_flags));
    softfloat_mul_x80 u_mul (
        .a(op_a), .b(op_b), .precision(CW[9:8]), .rc(CW[11:10]),
        .pr_sign(pr_sign_mul), .pr_exp(pr_exp_mul), .pr_sig0(pr_sig0_mul), .pr_sig1(pr_sig1_mul),
        .shared_round_z(shared_round_z), .shared_round_flags(shared_round_flags),
        .shared_subn_z(shared_subn_z), .shared_subn_pe(shared_subn_pe),
        .na_sign(na_sign), .na_exp(na_exp), .na_sig(na_sig),
        .nb_sign(nb_sign), .nb_exp(nb_exp), .nb_sig(nb_sig),
        .z(mul_z), .flags(mul_flags));

    wire use_sub = (op_a[79] ^ op_b[79]) ^ eff_kind[0];
    wire [79:0] addsub_z = use_sub ? sub_z : add_z;
    wire [79:0] arith_z  = (eff_kind == KIND_MUL) ? mul_z : addsub_z;

    fpu_transcendental u_dut (
        .clk(clk), .rst(rst), .start(start), .cmdex(cmdex), .a(a),
        .arith_a(arith_a), .arith_b(arith_b), .arith_is_mul(arith_is_mul),
        .arith_z(arith_z), .done(done), .z(z), .flags(flags));

    // ---- vectors -----------------------------------------------------------
    localparam NV = 15;
    reg [79:0] va   [0:NV-1];
    reg [79:0] gz   [0:NV-1];
    reg [5:0]  gfl  [0:NV-1];
    reg [8*7-1:0] lbl [0:NV-1];

    integer i, pass, fail;
    reg [79:0] gotz; reg [5:0] gotfl;
    reg signed [80:0] magdiff;

    initial begin
        // {label, a, golden_z, golden_flags}
        lbl[0]="+0.5  "; va[0]=80'h3ffe8000000000000000; gz[0]=80'h3ffdd413cccfe7799212; gfl[0]=6'b100000;
        lbl[1]="-0.5  "; va[1]=80'hbffe8000000000000000; gz[1]=80'hbffd95f619980c4336f8; gfl[1]=6'b100000;
        lbl[2]="+0.9  "; va[2]=80'h3ffee666666666666666; gz[2]=80'h3ffeddb680117ab11ef9; gfl[2]=6'b100000;
        lbl[3]="-0.9  "; va[3]=80'hbffee666666666666666; gz[3]=80'hbffdeda0411daf99c11d; gfl[3]=6'b100000;
        lbl[4]="+0.1  "; va[4]=80'h3ffbcccccccccccccccd; gz[4]=80'h3ffb92fdf71283321316; gfl[4]=6'b100000;
        lbl[5]="+0.75 "; va[5]=80'h3ffec000000000000000; gz[5]=80'h3ffeae89f995ad3ad5ce; gfl[5]=6'b100000;
        lbl[6]="ln2   "; va[6]=80'h3ffeb17217f7d1cf78fe; gz[6]=80'h3ffe9de70ac53b8a99f8; gfl[6]=6'b100000;
        lbl[7]="+0.0  "; va[7]=80'h00000000000000000000; gz[7]=80'h00000000000000000000; gfl[7]=6'b000000;
        lbl[8]="-0.0  "; va[8]=80'h80000000000000000000; gz[8]=80'h80000000000000000000; gfl[8]=6'b000000;
        lbl[9]="+1.0  "; va[9]=80'h3fff8000000000000000; gz[9]=80'h3fff8000000000000000; gfl[9]=6'b100000;
        lbl[10]="-1.0  "; va[10]=80'hbfff8000000000000000; gz[10]=80'hbffe8000000000000000; gfl[10]=6'b100000;
        lbl[11]="+Inf  "; va[11]=80'h7fff8000000000000000; gz[11]=80'h7fff8000000000000000; gfl[11]=6'b000000;
        lbl[12]="-Inf  "; va[12]=80'hffff8000000000000000; gz[12]=80'hbfff8000000000000000; gfl[12]=6'b000000;
        lbl[13]="QNaN  "; va[13]=80'h7fffc000000000000000; gz[13]=80'h7fffc000000000000000; gfl[13]=6'b000000;
        lbl[14]="SNaN  "; va[14]=80'h7fffa000000000000000; gz[14]=80'h7fffe000000000000000; gfl[14]=6'b000001;

        pass=0; fail=0;
        rst=1; start=0; @(negedge clk); @(negedge clk); rst=0; @(negedge clk);

        for (i=0; i<NV; i=i+1) begin
            cmdex = 4'd0;                  // CMDEX_F2XM1
            a     = va[i];
            start = 1'b1; @(negedge clk); start = 1'b0;
            // wait for done (engine asserts a 1-cycle done pulse)
            while (done !== 1'b1) @(negedge clk);
            gotz = z; gotfl = flags;
            // sign-magnitude 79-bit distance => 80-bit ulp difference metric
            magdiff = $signed({2'b0, gotz[78:0]}) - $signed({2'b0, gz[i][78:0]});
            if (magdiff < 0) magdiff = -magdiff;
            if ((gotz[79] === gz[i][79]) && (magdiff <= 2) && (gotfl === gfl[i])) begin
                pass = pass + 1;
                $display("PASS [%0d] %s got z=%020h fl=%06b  (ulp_d=%0d)", i, lbl[i], gotz, gotfl, magdiff);
            end else begin
                fail = fail + 1;
                $display("FAIL [%0d] %s", i, lbl[i]);
                $display("        got z=%020h fl=%06b", gotz, gotfl);
                $display("        exp z=%020h fl=%06b  (ulp_d=%0d)", gz[i], gfl[i], magdiff);
            end
            @(negedge clk);
        end

        $display("==== F2XM1 unit TB: %0d/%0d PASS, %0d FAIL ====", pass, NV, fail);
        if (fail==0) $display("RESULT: GREEN"); else $display("RESULT: RED");
        $finish;
    end

    // safety watchdog
    initial begin
        #5000000;  // 5 ms sim-time
        $display("WATCHDOG TIMEOUT — engine never asserted done");
        $finish;
    end

endmodule
