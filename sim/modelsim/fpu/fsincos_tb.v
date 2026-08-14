// fsincos_tb.v
//
// PR-2c.T-4 (iter 190) per-slice unit test for FSIN (D9 FE) / FCOS (D9 FF).
// Drives fpu_transcendental through the SAME shared floatx80 datapath execute_fpu
// wires it to: the REAL softfloat_mul/add/sub primitives + shared normalizers +
// round_rc + pack_subn (FSIN/FCOS use NO divider -- only mul/add) -- so the
// 3-part Cody-Waite pi/2 reduction and the sin/cos Horner polynomials run the
// actual hardware arithmetic, not a stand-in.  No CPU boot.
//
// Golden z/flags/c2 = the validated floatx80 engine model
// (sim/transc_model/fsincos_model.py + gen_fsincos_vectors.py): K=3 Cody-Waite
// reduction with a 2-chunk q split, <=2 ULP vs the exact-reduction float128 poly
// reference for |x| < 2^54.  Finite results pass within +/-2 ULP; special cases,
// flags, AND the C2 out-of-range bit must match EXACTLY.
//
// Run (ModelSim ASE 17, from sim/modelsim/fpu/):
//   vlog -quiet ../../../rtl/ao486/fpu/fpu_transcendental.v <all primitives> \
//        ../../../rtl/ao486/fpu/seq_divider_128_64.v softfloat_div_x80.v fsincos_tb.v
//   vsim -c -do "run -all; quit -f" work.fsincos_tb

`timescale 1ns / 1ps

module fsincos_tb;

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
    wire        c2;

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

    // shared seq_divider + softfloat_div_x80 (unused by FSIN/FCOS, kept for parity)
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
        .done(done), .z(z), .flags(flags), .c2(c2));

    // ---- vectors -----------------------------------------------------------
    localparam NV = 60;
    reg [79:0] va  [0:NV-1];
    reg [3:0]  cx  [0:NV-1];
    reg [79:0] gz  [0:NV-1];
    reg [5:0]  gfl [0:NV-1];
    reg        gc2 [0:NV-1];
    reg [8*7-1:0] lbl [0:NV-1];

    integer i, pass, fail;
    reg [79:0] gotz; reg [5:0] gotfl; reg gotc2;
    reg signed [80:0] magdiff;

    initial begin
        // ---- FSIN (cmdex=5) ----
        lbl[0]="s0.3  "; cx[0]=4'd5; va[0]=80'h3ffd9999999999999800; gz[0]=80'h3ffd974e6cadd5d19aa4; gfl[0]=6'b100000; gc2[0]=0;
        lbl[1]="s0.7  "; cx[1]=4'd5; va[1]=80'h3ffeb333333333333000; gz[1]=80'h3ffea4eb734a30cdc035; gfl[1]=6'b100000; gc2[1]=0;
        lbl[2]="s1.0  "; cx[2]=4'd5; va[2]=80'h3fff8000000000000000; gz[2]=80'h3ffed76aa47848677020; gfl[2]=6'b100000; gc2[2]=0;
        lbl[3]="spi/4 "; cx[3]=4'd5; va[3]=80'h3ffec90fdaa22168c000; gz[3]=80'h3ffeb504f333f9de62f5; gfl[3]=6'b100000; gc2[3]=0;
        lbl[4]="s1.5  "; cx[4]=4'd5; va[4]=80'h3fffc000000000000000; gz[4]=80'h3ffeff5bd4d9636c56f3; gfl[4]=6'b100000; gc2[4]=0;
        lbl[5]="spi/2 "; cx[5]=4'd5; va[5]=80'h3fffc90fdaa22168c000; gz[5]=80'h3fff8000000000000000; gfl[5]=6'b100000; gc2[5]=0;
        lbl[6]="s2.0  "; cx[6]=4'd5; va[6]=80'h40008000000000000000; gz[6]=80'h3ffee8c7b7568da22efd; gfl[6]=6'b100000; gc2[6]=0;
        lbl[7]="s3.0  "; cx[7]=4'd5; va[7]=80'h4000c000000000000000; gz[7]=80'h3ffc9081c36db6aada79; gfl[7]=6'b100000; gc2[7]=0;
        lbl[8]="spi   "; cx[8]=4'd5; va[8]=80'h4000c90fdaa22168c000; gz[8]=80'h3fca8d313198a2e03707; gfl[8]=6'b100000; gc2[8]=0;
        lbl[9]="s4.0  "; cx[9]=4'd5; va[9]=80'h40018000000000000000; gz[9]=80'hbffec1bdceeee0f57387; gfl[9]=6'b100000; gc2[9]=0;
        lbl[10]="s3pi/2"; cx[10]=4'd5; va[10]=80'h400196cbe3f9990e9000; gz[10]=80'hbfff8000000000000000; gfl[10]=6'b100000; gc2[10]=0;
        lbl[11]="s6.0  "; cx[11]=4'd5; va[11]=80'h4001c000000000000000; gz[11]=80'hbffd8f0f8c55851601d3; gfl[11]=6'b100000; gc2[11]=0;
        lbl[12]="s2pi  "; cx[12]=4'd5; va[12]=80'h4001c90fdaa22168c000; gz[12]=80'hbfcb8d313198a2e03707; gfl[12]=6'b100000; gc2[12]=0;
        lbl[13]="s10   "; cx[13]=4'd5; va[13]=80'h4002a000000000000000; gz[13]=80'hbffe8b44f7af9a7a92cf; gfl[13]=6'b100000; gc2[13]=0;
        lbl[14]="s100  "; cx[14]=4'd5; va[14]=80'h4005c800000000000000; gz[14]=80'hbffe81a12dbc626dc038; gfl[14]=6'b100000; gc2[14]=0;
        lbl[15]="s1000 "; cx[15]=4'd5; va[15]=80'h4008fa00000000000000; gz[15]=80'h3ffed3ae60a851035ac9; gfl[15]=6'b100000; gc2[15]=0;
        lbl[16]="s1e6  "; cx[16]=4'd5; va[16]=80'h4012f424000000000000; gz[16]=80'hbffdb332592b46c33a4c; gfl[16]=6'b100000; gc2[16]=0;
        lbl[17]="s-0.7 "; cx[17]=4'd5; va[17]=80'hbffeb333333333333000; gz[17]=80'hbffea4eb734a30cdc035; gfl[17]=6'b100000; gc2[17]=0;
        lbl[18]="s-2.5 "; cx[18]=4'd5; va[18]=80'hc000a000000000000000; gz[18]=80'hbffe9935786e7e558405; gfl[18]=6'b100000; gc2[18]=0;
        lbl[19]="s-10  "; cx[19]=4'd5; va[19]=80'hc002a000000000000000; gz[19]=80'h3ffe8b44f7af9a7a92cf; gfl[19]=6'b100000; gc2[19]=0;
        lbl[20]="s65536"; cx[20]=4'd5; va[20]=80'h400f8000599999999800; gz[20]=80'h3ffb83b0d75b869f65d5; gfl[20]=6'b100000; gc2[20]=0;
        lbl[21]="s2^40 "; cx[21]=4'd5; va[21]=80'h40278000000000400000; gz[21]=80'hbffecb5315f38ab5b316; gfl[21]=6'b100000; gc2[21]=0;
        lbl[22]="s2^45 "; cx[22]=4'd5; va[22]=80'h402c8000000000010000; gz[22]=80'h3ffede448cbd1b7e8078; gfl[22]=6'b100000; gc2[22]=0;
        lbl[23]="s2^50 "; cx[23]=4'd5; va[23]=80'h40318000000000000800; gz[23]=80'h3ffeb21bb2472f53b5d9; gfl[23]=6'b100000; gc2[23]=0;
        lbl[24]="s-2^42"; cx[24]=4'd5; va[24]=80'hc0298000000000166800; gz[24]=80'hbffeb2489a140b5b4654; gfl[24]=6'b100000; gc2[24]=0;
        lbl[25]="s+0   "; cx[25]=4'd5; va[25]=80'h00000000000000000000; gz[25]=80'h00000000000000000000; gfl[25]=6'b000000; gc2[25]=0;
        lbl[26]="s-0   "; cx[26]=4'd5; va[26]=80'h80000000000000000000; gz[26]=80'h80000000000000000000; gfl[26]=6'b000000; gc2[26]=0;
        lbl[27]="s+inf "; cx[27]=4'd5; va[27]=80'h7fff8000000000000000; gz[27]=80'hffffc000000000000000; gfl[27]=6'b000001; gc2[27]=0;
        lbl[28]="snan  "; cx[28]=4'd5; va[28]=80'h7fffc000000000000000; gz[28]=80'h7fffc000000000000000; gfl[28]=6'b000000; gc2[28]=0;
        lbl[29]="soor  "; cx[29]=4'd5; va[29]=80'h43fe8000000000000000; gz[29]=80'h43fe8000000000000000; gfl[29]=6'b000000; gc2[29]=1;
        // ---- FCOS (cmdex=6) ----
        lbl[30]="c0.3  "; cx[30]=4'd6; va[30]=80'h3ffd9999999999999800; gz[30]=80'h3ffef490eea1784dd306; gfl[30]=6'b100000; gc2[30]=0;
        lbl[31]="c0.7  "; cx[31]=4'd6; va[31]=80'h3ffeb333333333333000; gz[31]=80'h3ffec3ccb294fcec951c; gfl[31]=6'b100000; gc2[31]=0;
        lbl[32]="c1.0  "; cx[32]=4'd6; va[32]=80'h3fff8000000000000000; gz[32]=80'h3ffe8a51407da8345c92; gfl[32]=6'b100000; gc2[32]=0;
        lbl[33]="cpi/4 "; cx[33]=4'd6; va[33]=80'h3ffec90fdaa22168c000; gz[33]=80'h3ffeb504f333f9de6614; gfl[33]=6'b100000; gc2[33]=0;
        lbl[34]="c1.5  "; cx[34]=4'd6; va[34]=80'h3fffc000000000000000; gz[34]=80'h3ffb90deaa7e2fcd3a1f; gfl[34]=6'b100000; gc2[34]=0;
        lbl[35]="cpi/2 "; cx[35]=4'd6; va[35]=80'h3fffc90fdaa22168c000; gz[35]=80'h3fc98d313198a2e03707; gfl[35]=6'b100000; gc2[35]=0;
        lbl[36]="c2.0  "; cx[36]=4'd6; va[36]=80'h40008000000000000000; gz[36]=80'hbffdd51132ba9b902522; gfl[36]=6'b100000; gc2[36]=0;
        lbl[37]="c3.0  "; cx[37]=4'd6; va[37]=80'h4000c000000000000000; gz[37]=80'hbffefd7025f42f2e9308; gfl[37]=6'b100000; gc2[37]=0;
        lbl[38]="cpi   "; cx[38]=4'd6; va[38]=80'h4000c90fdaa22168c000; gz[38]=80'hbfff8000000000000000; gfl[38]=6'b100000; gc2[38]=0;
        lbl[39]="c4.0  "; cx[39]=4'd6; va[39]=80'h40018000000000000000; gz[39]=80'hbffea7553036d9260622; gfl[39]=6'b100000; gc2[39]=0;
        lbl[40]="c3pi/2"; cx[40]=4'd6; va[40]=80'h400196cbe3f9990e9000; gz[40]=80'hbfcad3c9ca64f450528b; gfl[40]=6'b100000; gc2[40]=0;
        lbl[41]="c6.0  "; cx[41]=4'd6; va[41]=80'h4001c000000000000000; gz[41]=80'h3ffef5cdb84bc117abd7; gfl[41]=6'b100000; gc2[41]=0;
        lbl[42]="c2pi  "; cx[42]=4'd6; va[42]=80'h4001c90fdaa22168c000; gz[42]=80'h3fff8000000000000000; gfl[42]=6'b100000; gc2[42]=0;
        lbl[43]="c10   "; cx[43]=4'd6; va[43]=80'h4002a000000000000000; gz[43]=80'hbffed6cd64486358f905; gfl[43]=6'b100000; gc2[43]=0;
        lbl[44]="c100  "; cx[44]=4'd6; va[44]=80'h4005c800000000000000; gz[44]=80'h3ffedcc0edfb32fefb20; gfl[44]=6'b100000; gc2[44]=0;
        lbl[45]="c1000 "; cx[45]=4'd6; va[45]=80'h4008fa00000000000000; gz[45]=80'h3ffe8ff8133c9f8ddbb9; gfl[45]=6'b100000; gc2[45]=0;
        lbl[46]="c1e6  "; cx[46]=4'd6; va[46]=80'h4012f424000000000000; gz[46]=80'h3ffeefcefcc836996358; gfl[46]=6'b100000; gc2[46]=0;
        lbl[47]="c-0.7 "; cx[47]=4'd6; va[47]=80'hbffeb333333333333000; gz[47]=80'h3ffec3ccb294fcec951c; gfl[47]=6'b100000; gc2[47]=0;
        lbl[48]="c-2.5 "; cx[48]=4'd6; va[48]=80'hc000a000000000000000; gz[48]=80'hbffecd17bf7c2c5be958; gfl[48]=6'b100000; gc2[48]=0;
        lbl[49]="c-10  "; cx[49]=4'd6; va[49]=80'hc002a000000000000000; gz[49]=80'hbffed6cd64486358f905; gfl[49]=6'b100000; gc2[49]=0;
        lbl[50]="c65536"; cx[50]=4'd6; va[50]=80'h400f8000599999999800; gz[50]=80'hbffeff785f25592b6a0b; gfl[50]=6'b100000; gc2[50]=0;
        lbl[51]="c2^40 "; cx[51]=4'd6; va[51]=80'h40278000000000400000; gz[51]=80'hbffe9b8c3e425ce41a73; gfl[51]=6'b100000; gc2[51]=0;
        lbl[52]="c2^45 "; cx[52]=4'd6; va[52]=80'h402c8000000000010000; gz[52]=80'h3ffdfe08233f471c0914; gfl[52]=6'b100000; gc2[52]=0;
        lbl[53]="c2^50 "; cx[53]=4'd6; va[53]=80'h40318000000000000800; gz[53]=80'h3ffeb7e2681d5329df1f; gfl[53]=6'b100000; gc2[53]=0;
        lbl[54]="c-2^42"; cx[54]=4'd6; va[54]=80'hc0298000000000166800; gz[54]=80'hbffeb7b6dec9233317b6; gfl[54]=6'b100000; gc2[54]=0;
        lbl[55]="c+0   "; cx[55]=4'd6; va[55]=80'h00000000000000000000; gz[55]=80'h3fff8000000000000000; gfl[55]=6'b000000; gc2[55]=0;
        lbl[56]="c-0   "; cx[56]=4'd6; va[56]=80'h80000000000000000000; gz[56]=80'h3fff8000000000000000; gfl[56]=6'b000000; gc2[56]=0;
        lbl[57]="c+inf "; cx[57]=4'd6; va[57]=80'h7fff8000000000000000; gz[57]=80'hffffc000000000000000; gfl[57]=6'b000001; gc2[57]=0;
        lbl[58]="cnan  "; cx[58]=4'd6; va[58]=80'h7fffc000000000000000; gz[58]=80'h7fffc000000000000000; gfl[58]=6'b000000; gc2[58]=0;
        lbl[59]="coor  "; cx[59]=4'd6; va[59]=80'h43fe8000000000000000; gz[59]=80'h43fe8000000000000000; gfl[59]=6'b000000; gc2[59]=1;

        pass=0; fail=0;
        rst=1; start=0; @(negedge clk); @(negedge clk); rst=0; @(negedge clk);

        for (i=0; i<NV; i=i+1) begin
            cmdex = cx[i]; a = va[i]; b = 80'd0;
            start = 1'b1; @(negedge clk); start = 1'b0;
            while (done !== 1'b1) @(negedge clk);
            gotz = z; gotfl = flags; gotc2 = c2;
            magdiff = $signed({2'b0, gotz[78:0]}) - $signed({2'b0, gz[i][78:0]});
            if (magdiff < 0) magdiff = -magdiff;
            if ((gotz[79] === gz[i][79]) && (magdiff <= 2) && (gotfl === gfl[i]) && (gotc2 === gc2[i])) begin
                pass = pass + 1;
                $display("PASS [%0d] %s got z=%020h fl=%06b c2=%0b  (ulp_d=%0d)", i, lbl[i], gotz, gotfl, gotc2, magdiff);
            end else begin
                fail = fail + 1;
                $display("FAIL [%0d] %s", i, lbl[i]);
                $display("        got z=%020h fl=%06b c2=%0b", gotz, gotfl, gotc2);
                $display("        exp z=%020h fl=%06b c2=%0b  (ulp_d=%0d)", gz[i], gfl[i], gc2[i], magdiff);
            end
            @(negedge clk);
        end

        $display("==== FSIN/FCOS unit TB: %0d/%0d PASS, %0d FAIL ====", pass, NV, fail);
        if (fail==0) $display("RESULT: GREEN"); else $display("RESULT: RED");
        $finish;
    end

    initial begin
        #40000000;  // 40 ms watchdog (no divides; ~55 mul/add steps/vector)
        $display("WATCHDOG TIMEOUT — engine never asserted done");
        $finish;
    end

endmodule
