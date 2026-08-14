// fyl2x_tb.v
//
// PR-2c.T-2 (iter 188) per-slice unit test for FYL2X / FYL2XP1.  Drives
// fpu_transcendental through the SAME shared floatx80 datapath execute_fpu wires
// it to: the REAL softfloat_mul/add/sub/DIV primitives + shared normalizers +
// round_rc + pack_subn + the shared seq_divider_128_64 — so the divide step runs
// the actual iterative hardware divider, not a stand-in.  No CPU boot.
//
// Golden z = the validated floatx80 engine model (sim/transc_model/fyl2x_model.py,
// shown <=2 ULP from the Bochs float128 oracle).  Finite results pass within
// +/-2 ULP; special cases + flags must match EXACTLY.
//
// Run (ModelSim ASE 17, from sim/modelsim/fpu/):
//   vlog -quiet +incdir+../../../rtl/ao486 \
//        ../../../rtl/ao486/fpu/fpu_transcendental.v \
//        ../../../rtl/ao486/fpu/floatx80_normalize.v ... (all primitives) \
//        ../../../rtl/ao486/fpu/seq_divider_128_64.v \
//        ../../../rtl/ao486/fpu/softfloat_div_x80.v \
//        fyl2x_tb.v
//   vsim -c -do "run -all; quit -f" work.fyl2x_tb

`timescale 1ns / 1ps

module fyl2x_tb;

    localparam [1:0] KIND_ADD=2'd0, KIND_SUB=2'd1, KIND_MUL=2'd2, KIND_DIV=2'd3;
    localparam [15:0] CW = 16'h037F;   // FNINIT default: RC=00(RNE), PC=11(ext)

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg         rst   = 1'b1;
    reg         start = 1'b0;
    reg  [3:0]  cmdex = 4'd0;
    reg  [79:0] a     = 80'd0;
    reg  [79:0] b     = 80'd0;

    // engine <-> shared datapath
    wire [79:0] arith_a, arith_b;
    wire [1:0]  arith_op;
    wire        div_start;
    wire [79:0] div_z;
    wire        div_done;
    wire        done;
    wire [79:0] z;
    wire [5:0]  flags;

    // replicate execute_fpu's op_a/op_b + eff_kind (engine drives arith_op)
    wire [79:0] op_a = arith_a;
    wire [79:0] op_b = arith_b;
    wire [1:0]  eff_kind = arith_op;

    // shared normalizers
    wire               na_sign, nb_sign;
    wire signed [16:0] na_exp,  nb_exp;
    wire        [63:0] na_sig,  nb_sig;
    floatx80_normalize u_norm_a (.a(op_a), .sign_out(na_sign), .exp_out(na_exp), .sig_out(na_sig));
    floatx80_normalize u_norm_b (.a(op_b), .sign_out(nb_sign), .exp_out(nb_exp), .sig_out(nb_sig));

    // per-primitive pre-round triples
    wire               pr_sign_add, pr_sign_sub, pr_sign_mul, pr_sign_div;
    wire signed [16:0] pr_exp_add,  pr_exp_sub,  pr_exp_mul,  pr_exp_div;
    wire        [63:0] pr_sig0_add, pr_sig0_sub, pr_sig0_mul, pr_sig0_div;
    wire        [63:0] pr_sig1_add, pr_sig1_sub, pr_sig1_mul, pr_sig1_div;
    wire [79:0] add_z, sub_z, mul_z;
    wire [5:0]  add_flags, sub_flags, mul_flags, div_flags;

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
            KIND_DIV: begin spr_sign=pr_sign_div; spr_exp=pr_exp_div; spr_sig0=pr_sig0_div; spr_sig1=pr_sig1_div; end
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

    // shared seq_divider + softfloat_div_x80 (no FPREM here -> pick_rem=0 always)
    wire         sd_start, sd_done;
    wire [127:0] sd_num;
    wire [63:0]  sd_den, sd_q, sd_r;
    seq_divider_128_64 u_seqdiv (
        .clk(clk), .rst(rst), .start(sd_start), .num(sd_num), .den(sd_den),
        .quotient(sd_q), .remainder(sd_r), .done(sd_done), .busy());
    softfloat_div_x80 u_div (
        .clk(clk), .rst(rst), .start(div_start), .a(op_a), .b(op_b),
        .precision(CW[9:8]), .rc(CW[11:10]),
        .pr_sign(pr_sign_div), .pr_exp(pr_exp_div), .pr_sig0(pr_sig0_div), .pr_sig1(pr_sig1_div),
        .shared_round_z(shared_round_z), .shared_round_flags(shared_round_flags),
        .shared_subn_z(shared_subn_z), .shared_subn_pe(shared_subn_pe),
        .na_sign(na_sign), .na_exp(na_exp), .na_sig(na_sig),
        .nb_sign(nb_sign), .nb_exp(nb_exp), .nb_sig(nb_sig),
        .sd_start(sd_start), .sd_num(sd_num), .sd_den(sd_den),
        .sd_q(sd_q), .sd_r(sd_r), .sd_done(sd_done),
        .done(div_done), .z(div_z), .flags(div_flags));

    wire use_sub = (op_a[79] ^ op_b[79]) ^ eff_kind[0];
    wire [79:0] addsub_z = use_sub ? sub_z : add_z;
    wire [79:0] arith_z  = (eff_kind == KIND_MUL) ? mul_z : addsub_z;

    fpu_transcendental u_dut (
        .clk(clk), .rst(rst), .start(start), .cmdex(cmdex), .a(a), .b(b),
        .arith_a(arith_a), .arith_b(arith_b), .arith_op(arith_op), .arith_z(arith_z),
        .div_start(div_start), .div_z(div_z), .div_done(div_done),
        .done(done), .z(z), .flags(flags));

    // ---- vectors -----------------------------------------------------------
    localparam NV = 18;
    reg [79:0] va  [0:NV-1];
    reg [79:0] vb  [0:NV-1];
    reg [3:0]  cx  [0:NV-1];
    reg [79:0] gz  [0:NV-1];
    reg [5:0]  gfl [0:NV-1];
    reg [8*7-1:0] lbl [0:NV-1];

    integer i, pass, fail;
    reg [79:0] gotz; reg [5:0] gotfl;
    reg signed [80:0] magdiff;

    initial begin
        // ---- FYL2X (cmdex=1) ----
        lbl[0]="2^1*1 "; cx[0]=4'd1; va[0]=80'h40008000000000000000; vb[0]=80'h3fff8000000000000000; gz[0]=80'h3fff8000000000000000; gfl[0]=6'b100000;
        lbl[1]="8->3  "; cx[1]=4'd1; va[1]=80'h40028000000000000000; vb[1]=80'h3fff8000000000000000; gz[1]=80'h4000c000000000000000; gfl[1]=6'b100000;
        lbl[2]="0.5->-1"; cx[2]=4'd1; va[2]=80'h3ffe8000000000000000; vb[2]=80'h3fff8000000000000000; gz[2]=80'hbfff8000000000000000; gfl[2]=6'b100000;
        lbl[3]="10*y2 "; cx[3]=4'd1; va[3]=80'h4002a000000000000000; vb[3]=80'h40008000000000000000; gz[3]=80'h4001d49a784bcd1b8afe; gfl[3]=6'b100000;
        lbl[4]="3.0   "; cx[4]=4'd1; va[4]=80'h4000c000000000000000; vb[4]=80'h3fff8000000000000000; gz[4]=80'h3fffcae00d1cfdeb444d; gfl[4]=6'b100000;
        lbl[5]="1.5   "; cx[5]=4'd1; va[5]=80'h3fffc000000000000000; vb[5]=80'h3fff8000000000000000; gz[5]=80'h3ffe95c01a39fbd6889a; gfl[5]=6'b100000;
        lbl[6]="1234.5"; cx[6]=4'd1; va[6]=80'h40099a50000000000000; vb[6]=80'h3fff8000000000000000; gz[6]=80'h4002a450bc9bcacfd715; gfl[6]=6'b100000;
        lbl[7]="0.1*y "; cx[7]=4'd1; va[7]=80'h3ffbcccccccccccccccd; vb[7]=80'h4000c000000000000000; gz[7]=80'hc0029f73da38d9d4a83e; gfl[7]=6'b100000;
        lbl[8]="a=1->0"; cx[8]=4'd1; va[8]=80'h3fff8000000000000000; vb[8]=80'h4000c000000000000000; gz[8]=80'h00000000000000000000; gfl[8]=6'b000000;
        lbl[9]="b=0->0"; cx[9]=4'd1; va[9]=80'h3ffe8000000000000000; vb[9]=80'h00000000000000000000; gz[9]=80'h00000000000000000000; gfl[9]=6'b000000;
        // ---- FYL2XP1 (cmdex=4) ----
        lbl[10]="0->0  "; cx[10]=4'd4; va[10]=80'h00000000000000000000; vb[10]=80'h4001a000000000000000; gz[10]=80'h00000000000000000000; gfl[10]=6'b000000;
        lbl[11]="1->1  "; cx[11]=4'd4; va[11]=80'h3fff8000000000000000; vb[11]=80'h3fff8000000000000000; gz[11]=80'h3fff8000000000000000; gfl[11]=6'b100000;
        lbl[12]="0.5*y2"; cx[12]=4'd4; va[12]=80'h3ffe8000000000000000; vb[12]=80'h40008000000000000000; gz[12]=80'h3fff95c01a39fbd6889a; gfl[12]=6'b100000;
        lbl[13]="0.1   "; cx[13]=4'd4; va[13]=80'h3ffbcccccccccccccccd; vb[13]=80'h3fff8000000000000000; gz[13]=80'h3ffc8ccdb9465ce83fff; gfl[13]=6'b100000;
        lbl[14]="0.01y3"; cx[14]=4'd4; va[14]=80'h3ff8a3d70a3d70a3d70a; vb[14]=80'h4000c000000000000000; gz[14]=80'h3ffab065d8d95424cf71; gfl[14]=6'b100000;
        lbl[15]="-0.5  "; cx[15]=4'd4; va[15]=80'hbffe8000000000000000; vb[15]=80'h3fff8000000000000000; gz[15]=80'hbfff8000000000000000; gfl[15]=6'b100000;
        lbl[16]="3->2  "; cx[16]=4'd4; va[16]=80'h4000c000000000000000; vb[16]=80'h3fff8000000000000000; gz[16]=80'h40008000000000000000; gfl[16]=6'b100000;
        lbl[17]="-0.1  "; cx[17]=4'd4; va[17]=80'hbffbcccccccccccccccd; vb[17]=80'h40008000000000000000; gz[17]=80'hbffd9ba6b2ecf30472e8; gfl[17]=6'b100000;

        pass=0; fail=0;
        rst=1; start=0; @(negedge clk); @(negedge clk); rst=0; @(negedge clk);

        for (i=0; i<NV; i=i+1) begin
            cmdex = cx[i]; a = va[i]; b = vb[i];
            start = 1'b1; @(negedge clk); start = 1'b0;
            while (done !== 1'b1) @(negedge clk);
            gotz = z; gotfl = flags;
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

        $display("==== FYL2X/FYL2XP1 unit TB: %0d/%0d PASS, %0d FAIL ====", pass, NV, fail);
        if (fail==0) $display("RESULT: GREEN"); else $display("RESULT: RED");
        $finish;
    end

    initial begin
        #5000000;  // 5 ms watchdog
        $display("WATCHDOG TIMEOUT — engine never asserted done");
        $finish;
    end

endmodule
