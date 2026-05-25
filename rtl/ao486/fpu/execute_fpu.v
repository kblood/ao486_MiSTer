// execute_fpu.v
//
// PR-2b.0 SKELETON.  Multi-cycle FPU arithmetic FSM.  Sister module to
// execute_multiply.v / execute_divide.v — owns the per-op busy signal,
// drives fpu_regfile read/write, posts SW updates back to fpu_csr, and
// raises #MF on unmasked FPU exceptions.
//
// This iter (PR-2b.0) is the *skeleton only*:
//   - Full port list matches research/execute_fpu_design.md §2.
//   - 5-state FSM (IDLE / FETCH / COMPUTE / POST / RETIRE) is wired.
//   - S_COMPUTE is a single-cycle no-op for every op — no arithmetic
//     datapath yet; the result is just the ST(0) operand passed through.
//   - All outputs tied to safe defaults under !fpu_busy so the module
//     is a true behavioural no-op until PR-2b.1 lifts the regfile
//     instantiation up to execute.v and PR-2b.2+ fills in S_COMPUTE.
//
// Goal of this commit: elaborate clean (0 err / 0 warn) so the port
// list and FSM transitions can be reviewed in isolation before any
// arithmetic lands.

`timescale 1ns / 1ps
`include "defines.v"

module execute_fpu (
    input               clk,
    input               rst_n,

    input               exe_reset,
    input               exe_ready,           // pipeline retire pulse — frees the FSM

    // Command stream from execute_commands.v
    input       [6:0]   exe_cmd,             // CMD_fpu_arith / CMD_fpu_compare / ... (PR-2b.2+)
    input       [3:0]   exe_cmdex,           // CMDEX_FADD / CMDEX_FSUB / ...
    input       [2:0]   exe_modregrm_reg_3b, // ST(src) or ST(dst) — already 3-bit
    input               exe_is_mem_form,     // 1 = mem-source op, 0 = reg-reg
    input               exe_pop_after,       // FPU_pop() after writeback

    // Memory-form operand (driven by the existing load path)
    input       [63:0]  exe_mem_data,
    input       [1:0]   exe_mem_fmt,         // 00=m32, 01=m64, 10=m80 (PR-2b.4+)
    input               exe_mem_data_valid,

    // CSR snapshot
    input       [15:0]  cw,
    input       [15:0]  sw_in,

    //--------------------------------------------------------------------
    // Outputs to execute.v
    //--------------------------------------------------------------------
    output              fpu_busy,
    output              fpu_done,            // 1-cycle pulse on RETIRE
    output      [15:0]  sw_out,
    output              sw_we,

    // Regfile write port
    output      [2:0]   rf_wr_idx,
    output      [79:0]  rf_wr_data,
    output      [1:0]   rf_wr_tag,
    output              rf_wr_en,

    // TOP-pointer mutation (FPU_push / FPU_pop)
    output      [2:0]   top_din,
    output              top_we,

    // Exception lane (vector 16, #MF) — fires when post-step sees
    // any unmasked SW.IE/DE/ZE/OE/UE/PE/SF.
    output              exe_trigger_mf_fault,

    //--------------------------------------------------------------------
    // Regfile read port (combinational request + 1-cycle synchronous
    // data; matches fpu_regfile.v's 1R1W interface).
    //--------------------------------------------------------------------
    output      [2:0]   rf_rd_idx,
    input       [79:0]  rf_rd_data,
    input       [1:0]   rf_rd_tag
);

    //--------------------------------------------------------------------
    // CMD recognition.  These CMD codes will be added in PR-2b's autogen
    // wave; for the skeleton we accept any CMD_fpu_* by reading exe_cmd's
    // high bits.  Adjust to the real `CMD_fpu_arith etc. when those land.
    //--------------------------------------------------------------------
    wire op_active = exe_ready && (
        // Placeholder match: real CMD_fpu_arith macros land with PR-2b.2.
        // For PR-2b.0 elaboration smoke, never fire.
        1'b0
    );

    //--------------------------------------------------------------------
    // 5-state FSM (matches design doc §3).
    //--------------------------------------------------------------------
    localparam [2:0]
        S_IDLE    = 3'd0,
        S_FETCH   = 3'd1,
        S_COMPUTE = 3'd2,
        S_POST    = 3'd3,
        S_RETIRE  = 3'd4;

    reg [2:0] state;
    reg [7:0] compute_counter;     // 8-bit: room for ~50 cycles of FDIV + margin for transcendentals
    reg [2:0] stnr_lat;            // latched src/dst index (after exe_ready captures it)
    reg       pop_lat;
    reg       mem_form_lat;
    reg       stack_fault_lat;     // set in S_FETCH if either operand tag = Empty

    //--------------------------------------------------------------------
    // FSM transitions
    //--------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n || exe_reset) begin
            state           <= S_IDLE;
            compute_counter <= 8'd0;
            stnr_lat        <= 3'd0;
            pop_lat         <= 1'b0;
            mem_form_lat    <= 1'b0;
            stack_fault_lat <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (op_active) begin
                        state        <= S_FETCH;
                        stnr_lat     <= exe_modregrm_reg_3b;
                        pop_lat      <= exe_pop_after;
                        mem_form_lat <= exe_is_mem_form;
                    end
                end

                S_FETCH: begin
                    // Read ST(0) and ST(src) tags via rf_rd_*; in this
                    // skeleton we accept whatever the regfile returns and
                    // ALWAYS proceed (no real stack-fault detection until
                    // PR-2b.1 wires the real read mux).
                    stack_fault_lat <= 1'b0;
                    compute_counter <= 8'd1;   // single-cycle placeholder
                    state           <= S_COMPUTE;
                end

                S_COMPUTE: begin
                    // PR-2b.0 placeholder: count down to zero, then advance.
                    if (compute_counter != 8'd0)
                        compute_counter <= compute_counter - 8'd1;
                    if (compute_counter == 8'd1)
                        state <= S_POST;
                end

                S_POST: begin
                    // Combinational exception classification will live
                    // outside the FSM in PR-2b.2; for the skeleton just
                    // proceed to retire.
                    state <= S_RETIRE;
                end

                S_RETIRE: begin
                    // 1-cycle pulse of fpu_done / rf_wr_en / top_we — but
                    // all are gated to 0 in PR-2b.0 since there's no real
                    // result to write.
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    //--------------------------------------------------------------------
    // Outputs
    //--------------------------------------------------------------------
    assign fpu_busy = (state != S_IDLE);
    assign fpu_done = (state == S_RETIRE);

    // PR-2b.0: never write back, never mutate TOP, never raise #MF.
    assign sw_out               = sw_in;
    assign sw_we                = 1'b0;
    assign rf_wr_idx            = 3'd0;
    assign rf_wr_data           = 80'd0;
    assign rf_wr_tag            = 2'b00;
    assign rf_wr_en             = 1'b0;
    assign top_din              = 3'd0;
    assign top_we               = 1'b0;
    assign exe_trigger_mf_fault = 1'b0;

    // Read-port index: ST(0) by default, ST(src) when fetching the
    // second operand.  Real mux happens in PR-2b.2 once compute_counter
    // splits into multiple sub-states.
    assign rf_rd_idx = (state == S_FETCH) ? stnr_lat : 3'd0;

    //--------------------------------------------------------------------
    // synthesis translate_off
    // Suppress unused-wire warnings on inputs the skeleton doesn't yet
    // read (they get exercised by PR-2b.2+).
    wire _unused_ok = &{ 1'b0,
                         exe_cmd,
                         exe_cmdex,
                         exe_mem_data,
                         exe_mem_fmt,
                         exe_mem_data_valid,
                         cw,
                         rf_rd_data,
                         rf_rd_tag,
                         mem_form_lat,
                         stack_fault_lat,
                         1'b0 };
    // synthesis translate_on

endmodule
