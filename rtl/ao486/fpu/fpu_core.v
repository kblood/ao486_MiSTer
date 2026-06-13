// fpu_core.v
//
// PR-1a FPU control-op handler. Drives the side-effect pulses for the four
// no-arithmetic ops that PR-1a needs to make CPUID-FPU advertisement honest:
//   - FNINIT   (DB E3)  : pulse fninit_pulse -> external fpu_csr resets to
//                         CW=0x037F, SW=0; external fpu_regfile sets all
//                         tags = Empty.
//   - FNCLEX   (DB E2)  : pulse fnclex_pulse -> external fpu_csr clears
//                         exception flags + SF.
//   - FNSTSW AX (DF E0) : reads SW input; pipeline mux routes to AX
//                         (handled in autogen execute_commands.v via the
//                         SET(exe_result, {16'd0, fpu_sw}) arm).
//   - FNSTCW m16 (D9/7) : reads CW input; pipeline mux routes to memory
//                         (SET(exe_result, {16'd0, fpu_cw}) arm + the
//                         standard dst-is-memory writeback path).
//
// Refactor history:
//   PR-2b.1 — fpu_regfile lifted from this module up to execute.v so the
//             arithmetic FSM (execute_fpu) and the PR-1a control ops can
//             share one regfile.  This module emitted `fninit_pulse` for
//             the shared regfile's `init` port.
//   PR-2b.2d — fpu_csr also lifted up to execute.v so execute_fpu can OR
//             its exception-flag deltas into the shared CSR via the
//             exc_flags_set lane.  cw/sw now flow IN to this module from
//             the externally-instantiated CSR; fnclex_pulse joins
//             fninit_pulse as a side-effect output.  This module is now
//             a pure command decoder — it owns no state.
//
// Arithmetic ops (FLD/FSTP/FADD/...) land in PR-2b+ via execute_fpu.v's
// FSM-driven datapath, oracle-validated against sim/testfloat/glue/.

`timescale 1ns / 1ps

module fpu_core (
    input             clk,
    input             reset,

    // Command from execute stage
    input      [3:0]  cmdex,            // CMDEX_FN_INIT / FN_CLEX / FNSTSW_AX / FNSTCW_M16 / ...
    input             cmd_valid,        // 1-cycle pulse, high when exe_cmd == CMD_fpu
    output            cmd_done,         // 1-cycle ack — these ops all retire in 1 cycle

    // CW/SW from the externally-instantiated fpu_csr (lifted PR-2b.2d).
    input      [15:0] sw,
    input      [15:0] cw,

    // Side-effect pulses to the external fpu_csr + fpu_regfile.
    // Each is high for the 1 cycle the corresponding op retires.
    output            fninit_pulse,     // -> fpu_csr.init  + fpu_regfile.init
    output            fnclex_pulse,     // -> fpu_csr.exc_flags_clear_all

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
        CMDEX_FNSTSW_M16  = 4'd9,   // iter-229: FNSTSW m16 (DD /7) memory store
        CMDEX_UNIMPL      = 4'd15;

    wire fninit_now    = cmd_valid && cmdex == CMDEX_FN_INIT;
    wire fnclex_now    = cmd_valid && cmdex == CMDEX_FN_CLEX;
    wire fnstsw_ax_now = cmd_valid && cmdex == CMDEX_FNSTSW_AX;
    wire fnstcw_now    = cmd_valid && cmdex == CMDEX_FNSTCW_M16;
    // iter-229: FNSTSW m16 stores the 16-bit SW to memory via the SAME generic
    // exe_result + dst_is_memory path as FNSTCW (execute_commands.v provides
    // {16'd0, fpu_sw}); it only needs to retire here so the pipeline completes.
    wire fnstsw_m16_now = cmd_valid && cmdex == CMDEX_FNSTSW_M16;

    assign fninit_pulse = fninit_now;
    assign fnclex_pulse = fnclex_now;

    // Memory-write request for FNSTCW m16; pipeline.v drives the actual
    // memory transaction using exe_address / exe_size already in flight.
    assign mem_we_req  = fnstcw_now;
    assign mem_we_data = cw;

    // All these ops retire in a single cycle.
    assign cmd_done = cmd_valid && (fninit_now | fnclex_now | fnstsw_ax_now | fnstcw_now | fnstsw_m16_now);

    // Suppress unused-input warnings: this module never reads sw / reset
    // directly (reset effects flow through the external CSR + regfile).
    // synthesis translate_off
    wire _unused_ok = &{ 1'b0, sw, reset, clk, 1'b0 };
    // synthesis translate_on

endmodule
