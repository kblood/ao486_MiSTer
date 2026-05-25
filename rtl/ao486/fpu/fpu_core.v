// fpu_core.v
//
// PR-1 FPU stub. Owns fpu_regfile + fpu_csr. Handles the four no-arithmetic
// ops that PR-1 needs to make CPUID-FPU advertisement honest:
//   - FNINIT   (DB E3)  : pulse init -> CW=0x037F, SW=0, tags=all-empty
//   - FNCLEX   (DB E2)  : clear exception flags + SF
//   - FNSTSW AX (DF E0) : drive AX <- SW (host pipeline mux)
//   - FNSTCW m16 (D9/7) : drive memory-write port with CW
//
// Arithmetic ops (FLD/FSTP/FADD/...) land in PR-2 via microcode softfloatx80
// (see research/design_fpu_paths.md, Path A).
//
// Integration: pipeline.v instantiates this in the `exe` stage and decodes
// CMDEX_* from CMD_fpu.txt (see research/pr1_patches.md Patch 3).

`timescale 1ns / 1ps

module fpu_core (
    input             clk,
    input             reset,

    // Command from execute stage
    input      [3:0]  cmdex,            // CMDEX_FN_INIT / FN_CLEX / FNSTSW_AX / FNSTCW_M16 / ...
    input             cmd_valid,        // 1-cycle pulse, high when exe_cmd == CMD_fpu
    output            cmd_done,         // 1-cycle ack — these ops all retire in 1 cycle

    // Status word + control word readouts for pipeline mux
    output     [15:0] sw,
    output     [15:0] cw,

    // Memory-write helpers (for FNSTCW m16 etc.)
    output            mem_we_req,
    output     [15:0] mem_we_data
);

    // CMDEX encoding must match CMD_fpu.txt
    localparam [3:0]
        CMDEX_WAIT_STEP_0 = 4'd0,
        CMDEX_ESC_STEP_0  = 4'd1,
        CMDEX_FN_INIT     = 4'd2,
        CMDEX_FN_CLEX     = 4'd3,
        CMDEX_FNSTSW_AX   = 4'd4,
        CMDEX_FNSTCW_M16  = 4'd5,
        CMDEX_UNIMPL      = 4'd15;

    wire fninit_now    = cmd_valid && cmdex == CMDEX_FN_INIT;
    wire fnclex_now    = cmd_valid && cmdex == CMDEX_FN_CLEX;
    wire fnstsw_ax_now = cmd_valid && cmdex == CMDEX_FNSTSW_AX;
    wire fnstcw_now    = cmd_valid && cmdex == CMDEX_FNSTCW_M16;

    // Connect to CSR
    wire [15:0] cw_w, sw_w;
    fpu_csr u_csr (
        .clk                 (clk),
        .reset               (reset),
        .init                (fninit_now),

        .cw_we               (1'b0),
        .cw_din              (16'h0),
        .cw                  (cw_w),

        .sw_we               (1'b0),
        .sw_din              (16'h0),
        .sw                  (sw_w),

        .exc_flags_set       (6'b0),
        .exc_flags_clear_all (fnclex_now),

        .cc_we               (1'b0),
        .cc_din              (4'b0),

        .top                 (),
        .top_din             (3'b0),
        .top_we              (1'b0),

        .sf_set              (1'b0),

        .rc                  (),
        .pc                  (),
        .exc_mask            ()
    );

    // Connect a regfile so FNINIT also wipes the tag word.
    wire [79:0] r0_w, r1_w, r2_w, r3_w, r4_w, r5_w, r6_w, r7_w;
    wire [15:0] tag_w;
    fpu_regfile u_rf (
        .clk     (clk),
        .reset   (reset),
        .rd_idx  (3'd0),
        .rd_data (),
        .rd_tag  (),
        .wr_idx  (3'd0),
        .wr_data (80'd0),
        .wr_tag  (2'b00),
        .wr_en   (1'b0),
        .init    (fninit_now),
        .r0(r0_w), .r1(r1_w), .r2(r2_w), .r3(r3_w),
        .r4(r4_w), .r5(r5_w), .r6(r6_w), .r7(r7_w),
        .tag_word(tag_w)
    );

    assign sw       = sw_w;
    assign cw       = cw_w;

    // Memory-write request for FNSTCW m16; pipeline.v drives the actual
    // memory transaction using exe_address / exe_size already in flight.
    assign mem_we_req  = fnstcw_now;
    assign mem_we_data = cw_w;

    // All four ops retire in a single cycle.
    assign cmd_done = cmd_valid && (fninit_now | fnclex_now | fnstsw_ax_now | fnstcw_now);

endmodule
