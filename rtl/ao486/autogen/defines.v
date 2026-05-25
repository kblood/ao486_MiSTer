`define CMDEX_POP_implicit 4'd0
`define CMDEX_TEST_immediate 4'd0
`define CMDEX_JMP_protected_STEP_1 4'd10
`define CMDEX_JMP_protected_STEP_0 4'd9
`define CMDEX_LODS_STEP_0 4'd0
`define CMDEX_XADD_LAST 4'd1
`define CMD_ADD 7'd64
`define CMDEX_PUSH_immediate 4'd2
`define CMD_ADC 7'd66
`define CMDEX_POP_seg_STEP_1 4'd0
`define CMDEX_INC_DEC_implicit 4'd0
`define CMD_SBB 7'd67
`define CMDEX_JMP_Jv_STEP_0 4'd1
`define CMD_LEA 7'd103
`define CMD_MOV 7'd90
`define CMD_NOT 7'd78
`define CMDEX_MOVS_STEP_0 4'd0
`define CMDEX_task_switch_4_STEP_6 4'd6
`define CMDEX_int_2_int_trap_gate_more_STEP_3 4'd9
`define CMDEX_task_switch_4_STEP_5 4'd5
`define CMDEX_int_2_int_trap_gate_more_STEP_2 4'd8
`define CMDEX_task_switch_4_STEP_8 4'd8
`define CMDEX_int_2_int_trap_gate_more_STEP_5 4'd11
`define CMDEX_task_switch_4_STEP_7 4'd7
`define CMDEX_int_2_int_trap_gate_more_STEP_4 4'd10
`define CMDEX_int_2_int_trap_gate_more_STEP_7 4'd13
`define CMDEX_task_switch_4_STEP_9 4'd9
`define CMDEX_int_2_int_trap_gate_more_STEP_6 4'd12
`define CMDEX_PUSH_MOV_SEG_implicit_DS 4'd3
`define CMDEX_int_2_int_trap_gate_more_STEP_9 4'd15
`define CMDEX_int_2_int_trap_gate_more_STEP_8 4'd14
`define CMD_AAM 7'd32
`define CMDEX_int_real_STEP_1 4'd3
`define CMDEX_int_real_STEP_0 4'd2
`define CMDEX_XCHG_modregrm_LAST 4'd2
`define CMDEX_int_real_STEP_3 4'd5
`define CMDEX_int_real_STEP_2 4'd4
`define CMD_PUSH_MOV_SEG 7'd6
`define CMD_SGDT 7'd104
`define CMD_AAS 7'd113
`define CMDEX_int_2_int_trap_gate_more_STEP_1 4'd7
`define CMDEX_int_2_int_trap_gate_more_STEP_0 4'd6
`define CMD_MOVSX 7'd108
`define CMD_SIDT 7'd105
`define CMD_LAHF 7'd91
`define CMDEX_MOV_to_seg_LLDT_LTR_STEP_1 4'd0
`define CMDEX_task_switch_4_STEP_0 4'd0
`define CMDEX_task_switch_4_STEP_1 4'd1
`define CMDEX_task_switch_4_STEP_2 4'd2
`define CMDEX_task_switch_4_STEP_3 4'd3
`define TASK_SWITCH_FROM_IRET 2'd0
`define CMDEX_task_switch_4_STEP_4 4'd4
`define CMDEX_int_int_trap_gate_STEP_0 4'd13
`define CMDEX_int_int_trap_gate_STEP_1 4'd14
`define CMDEX_int_int_trap_gate_STEP_2 4'd15
`define CMDEX_PUSH_MOV_SEG_implicit_CS 4'd1
`define CMD_CMPS 7'd45
`define CMDEX_INVD_STEP_0 4'd0
`define CMD_CBW 7'd92
`define CMDEX_INVD_STEP_1 4'd1
`define CMD_BT 7'd36
`define CMDEX_INVD_STEP_2 4'd2
`define CMDEX_RET_near_imm 4'd1
`define CMD_OUT 7'd89
`define CMD_int_3 7'd30
`define CMD_SCAS 7'd13
`define CMD_int_2 7'd29
`define CMD_INT_INTO 7'd75
`define CMDEX_LAR_LSL_VERR_VERW_STEP_1 4'd0
`define CMDEX_LAR_LSL_VERR_VERW_STEP_2 4'd1
`define CMD_IRET_2 7'd40
`define CMD_load_seg 7'd33
`define CMDEX_XCHG_modregrm 4'd1
`define CMDEX_PUSH_MOV_SEG_modregrm_LDT 4'd14
`define CMD_SAHF 7'd27
`define CMDEX_INS_real_1 4'd0
`define CMDEX_INS_real_2 4'd1
`define CMDEX_PUSH_MOV_SEG_modregrm_CS 4'd9
`define CMDEX_TEST_modregrm 4'd1
`define CMD_LGDT 7'd47
`define CMD_MUL 7'd59
`define CMD_CPUID 7'd76
`define CMDEX_ENTER_LOOP 4'd3
`define CMDEX_RET_far_same_STEP_3 4'd4
`define CMDEX_RET_far_same_STEP_4 4'd5
`define CMDEX_PUSH_MOV_SEG_modregrm_DS 4'd11
`define CMD_AAD 7'd31
`define CMD_AAA 7'd112
`define CMD_Jcc 7'd8
`define CMD_BSWAP 7'd17
`define CMDEX_CALL_2_call_gate_same_STEP_0 4'd8
`define CMDEX_SCAS_STEP_0 4'd0
`define CMDEX_CALL_2_call_gate_same_STEP_2 4'd10
`define CMDEX_CALL_2_call_gate_same_STEP_1 4'd9
`define CMDEX_CALL_2_call_gate_same_STEP_3 4'd11
`define CMD_PUSH 7'd74
`define CMDEX_BTx_modregrm 4'd1
`define CMDEX_SGDT_SIDT_STEP_1 4'd0
`define CMDEX_PUSH_MOV_SEG_modregrm_ES 4'd8
`define CMDEX_SGDT_SIDT_STEP_2 4'd1
`define CMDEX_CLTS_STEP_FIRST 4'd0
`define CMDEX_CALL_2_call_gate_more_STEP_2 4'd14
`define CMDEX_CMPS_FIRST 4'd0
`define CMDEX_CALL_2_call_gate_more_STEP_3 4'd15
`define CMDEX_CALL_2_call_gate_more_STEP_0 4'd12
`define CMDEX_CALL_2_call_gate_more_STEP_1 4'd13
`define CMDEX_WAIT_STEP_0 4'd0
`define CMDEX_PUSH_MOV_SEG_modregrm 4'd8
`define CMD_DIV 7'd42
`define TASK_SWITCH_FROM_INT 2'd1
`define CMDEX_HLT_STEP_0 4'd0
`define CMDEX_BOUND_STEP_FIRST 4'd0
`define CMDEX_LOOP_E 4'd1
`define CMDEX_CALL_3_call_gate_more_STEP_10 4'd6
`define CMDEX_int_STEP_1 4'd1
`define CMD_MOV_to_seg 7'd19
`define CMD_Shift 7'd44
`define CMDEX_PUSH_MOV_SEG_modregrm_FS 4'd12
`define CMDEX_PUSH_modregrm 4'd3
`define CMDEX_INT_INTO_INT3_STEP_0 4'd1
`define CMD_INVLPG 7'd10
`define CMDEX_MOV_modregrm_imm 4'd2
`define CMDEX_IN_protected 4'd2
`define CMD_control_reg 7'd46
`define CMDEX_control_reg_LMSW_STEP_0 4'd1
`define CMDEX_CALL_2_protected_seg_STEP_3 4'd0
`define CMD_io_allow 7'd11
`define CMDEX_control_reg_LMSW_STEP_1 4'd2
`define CMDEX_IN_imm 4'd0
`define CMDEX_CLTS_STEP_LAST 4'd1
`define CMDEX_IRET_protected_STEP_3 4'd9
`define CMDEX_IRET_protected_STEP_2 4'd8
`define CMDEX_CALL_2_protected_seg_STEP_4 4'd1
`define CMDEX_IRET_protected_STEP_1 4'd7
`define CMDEX_IRET_protected_STEP_0 4'd4
`define CMD_IDIV 7'd43
`define CMDEX_OUT_protected 4'd2
`define CMDEX_PUSH_MOV_SEG_implicit_LDT 4'd6
`define CMDEX_Arith_immediate 4'd0
`define CMDEX_task_switch_STEP_3 4'd3
`define CMDEX_task_switch_STEP_2 4'd2
`define CMDEX_task_switch_STEP_1 4'd1
`define CMDEX_task_switch_STEP_7 4'd7
`define CMDEX_task_switch_4_STEP_10 4'd10
`define CMDEX_task_switch_STEP_6 4'd6
`define CMDEX_task_switch_STEP_5 4'd5
`define CMDEX_task_switch_STEP_4 4'd4
`define CMD_task_switch 7'd99
`define CMDEX_task_switch_STEP_9 4'd9
`define CMDEX_task_switch_2_STEP_13 4'd13
`define CMDEX_task_switch_STEP_8 4'd8
`define CMDEX_task_switch_2_STEP_11 4'd11
`define CMDEX_OUT_idle 4'd3
`define CMDEX_LGDT_LIDT_STEP_LAST 4'd10
`define CMDEX_control_reg_SMSW_STEP_0 4'd0
`define CMDEX_CALL_Ep_STEP_1 4'd5
`define CMDEX_CALL_Ep_STEP_0 4'd2
`define CMDEX_INS_protected_2 4'd3
`define CMDEX_INS_protected_1 4'd2
`define CMDEX_control_reg_MOV_load_STEP_1 4'd5
`define CMDEX_control_reg_MOV_load_STEP_0 4'd4
`define CMDEX_LOOP_NE 4'd0
`define CMD_LODS 7'd72
`define CMDEX_JMP_real_v8086_STEP_1 4'd8
`define CMDEX_JMP_real_v8086_STEP_0 4'd7
`define CMD_MOVZX 7'd107
`define CMD_TEST 7'd61
`define CMDEX_IN_dx 4'd1
`define CMD_LIDT 7'd48
`define CMDEX_PUSH_MOV_SEG_implicit 4'd0
`define CMDEX_PUSH_MOV_SEG_implicit_GS 4'd5
`define CMD_MOVS 7'd106
`define CMD_PUSHA 7'd49
`define CMDEX_SHxD_implicit 4'd0
`define CMD_PUSHF 7'd86
`define CMDEX_CALL_real_v8086_STEP_3 4'd10
`define CMDEX_LGDT_LIDT_STEP_1 4'd8
`define CMDEX_CALL_real_v8086_STEP_2 4'd9
`define CMDEX_LGDT_LIDT_STEP_2 4'd9
`define CMD_SETcc 7'd51
`define CMDEX_CALL_real_v8086_STEP_1 4'd8
`define CMDEX_CALL_real_v8086_STEP_0 4'd7
`define CMDEX_Arith_modregrm_imm 4'd2
`define CMD_fpu 7'd50
`define CMDEX_OUTS_protected 4'd1
`define CMDEX_PUSH_MOV_SEG_implicit_FS 4'd4
`define CMD_Arith 7'd64
`define CMDEX_task_switch_STEP_13 4'd13
`define CMDEX_task_switch_STEP_14 4'd14
`define CMDEX_POPF_STEP_1 4'd1
`define CMDEX_task_switch_STEP_11 4'd11
`define CMDEX_POPF_STEP_0 4'd0
`define CMDEX_task_switch_STEP_12 4'd12
`define CMDEX_ESC_STEP_0 4'd1
`define CMDEX_task_switch_STEP_10 4'd10
`define CMDEX_debug_reg_MOV_store_STEP_0 4'd0
`define CMD_LAR 7'd79
`define CMDEX_CALL_Jv_STEP_0 4'd1
`define CMDEX_JMP_Ep_STEP_1 4'd5
`define CMD_DAA 7'd114
`define CMDEX_JMP_Ep_STEP_0 4'd2
`define CMDEX_PUSH_MOV_SEG_implicit_ES 4'd0
`define CMD_WBINVD 7'd58
`define CMDEX_IN_idle 4'd3
`define CMDEX_int_protected_STEP_0 4'd8
`define CMDEX_int_protected_STEP_1 4'd9
`define CMDEX_int_protected_STEP_2 4'd10
`define CMDEX_INC_DEC_increment_modregrm 4'd2
`define CMDEX_INT_INTO_INTO_STEP_0 4'd2
`define CMDEX_IRET_2_idle 4'd0
`define CMDEX_PUSHA_STEP_1 4'd1
`define CMDEX_PUSHA_STEP_2 4'd2
`define CMDEX_PUSHA_STEP_3 4'd3
`define CMDEX_PUSHA_STEP_4 4'd4
`define CMDEX_PUSHA_STEP_5 4'd5
`define CMDEX_CPUID_STEP_LAST 4'd0
`define CMDEX_PUSHA_STEP_6 4'd6
`define CMDEX_PUSHA_STEP_7 4'd7
`define CMD_DAS 7'd115
`define CMDEX_PUSHA_STEP_0 4'd0
`define CMDEX_CALL_protected_seg_STEP_2 4'd15
`define CMDEX_CALL_protected_seg_STEP_1 4'd14
`define CMD_LxS 7'd18
`define CMDEX_CALL_protected_seg_STEP_0 4'd13
`define CMDEX_ENTER_FIRST 4'd0
`define CMDEX_IRET_real_v86_STEP_2 4'd2
`define CMDEX_BTx_modregrm_imm 4'd0
`define CMDEX_IRET_real_v86_STEP_3 4'd3
`define CMDEX_IRET_real_v86_STEP_0 4'd0
`define CMDEX_IRET_real_v86_STEP_1 4'd1
`define CMDEX_CALL_Ev_Jv_STEP_1 4'd4
`define CMDEX_IRET_task_switch_STEP_1 4'd6
`define CMDEX_IRET_task_switch_STEP_0 4'd5
`define CMD_INC_DEC 7'd14
`define CMDEX_POP_modregrm_STEP_1 4'd2
`define CMDEX_Arith_modregrm 4'd1
`define CMD_BSR 7'd117
`define CMDEX_CALL_2_call_gate_STEP_1 4'd6
`define CMDEX_CALL_2_call_gate_STEP_0 4'd5
`define CMD_BSF 7'd116
`define CMDEX_CALL_2_call_gate_STEP_2 4'd7
`define CMDEX_WBINVD_STEP_1 4'd1
`define CMDEX_int_2_int_trap_gate_same_STEP_5 4'd5
`define CMDEX_WBINVD_STEP_0 4'd0
`define CMDEX_int_2_int_trap_gate_same_STEP_4 4'd4
`define CMDEX_int_2_int_trap_gate_same_STEP_3 4'd3
`define CMDEX_WBINVD_STEP_2 4'd2
`define CMDEX_STOS_STEP_0 4'd0
`define CMDEX_int_2_int_trap_gate_same_STEP_2 4'd2
`define CMD_STOS 7'd83
`define CMDEX_int_2_int_trap_gate_same_STEP_1 4'd1
`define CMDEX_LOOP 4'd2
`define CMDEX_int_2_int_trap_gate_same_STEP_0 4'd0
`define CMDEX_INC_DEC_decrement_modregrm 4'd3
`define CMDEX_POP_modregrm_STEP_0 4'd1
`define CMDEX_Shift_modregrm 4'd1
`define CMDEX_POPA_STEP_7 4'd7
`define CMDEX_POPA_STEP_6 4'd6
`define CMDEX_PUSH_implicit 4'd0
`define CMD_IRET 7'd35
`define CMDEX_IRET_2_protected_to_v86_STEP_6 4'd10
`define CMDEX_RET_far_real_STEP_3 4'd3
`define CMDEX_task_switch_3_STEP_0 4'd0
`define CMDEX_task_switch_3_STEP_7 4'd7
`define CMDEX_task_switch_3_STEP_8 4'd8
`define CMD_int 7'd28
`define CMDEX_io_allow_2 4'd1
`define CMDEX_io_allow_1 4'd0
`define CMDEX_PUSH_MOV_SEG_implicit_SS 4'd2
`define CMDEX_IMUL_modregrm 4'd0
`define CMDEX_load_seg_STEP_2 4'd1
`define CMDEX_CALL_2_task_gate_STEP_1 4'd4
`define CMDEX_IMUL_modregrm_imm 4'd1
`define CMDEX_CALL_2_task_gate_STEP_0 4'd3
`define CMD_IMUL 7'd54
`define CMDEX_int_3_int_trap_gate_more_STEP_5 4'd5
`define CMDEX_int_3_int_trap_gate_more_STEP_6 4'd6
`define CMDEX_PUSH_MOV_SEG_implicit_TR 4'd7
`define CMD_LSL 7'd80
`define CMDEX_int_3_int_trap_gate_more_STEP_3 4'd3
`define CMDEX_INVLPG_STEP_1 4'd1
`define CMDEX_int_3_int_trap_gate_more_STEP_4 4'd4
`define CMDEX_INVLPG_STEP_0 4'd0
`define CMD_POPF 7'd94
`define CMDEX_int_3_int_trap_gate_more_STEP_1 4'd1
`define CMDEX_int_3_int_trap_gate_more_STEP_2 4'd2
`define CMDEX_INVLPG_STEP_2 4'd2
`define CMDEX_int_3_int_trap_gate_more_STEP_0 4'd0
`define CMD_POPA 7'd109
`define CMDEX_load_seg_STEP_1 4'd0
`define CMDEX_INC_DEC_modregrm 4'd2
`define CMDEX_IRET_2_protected_outer_STEP_4 4'd7
`define CMDEX_RET_far_STEP_2 4'd2
`define CMDEX_IRET_2_protected_outer_STEP_5 4'd8
`define CMDEX_RET_far_STEP_1 4'd1
`define CMDEX_IRET_2_protected_outer_STEP_6 4'd9
`define CMDEX_IRET_2_protected_outer_STEP_0 4'd3
`define CMDEX_IRET_2_protected_outer_STEP_1 4'd4
`define CMDEX_IRET_2_protected_outer_STEP_2 4'd5
`define CMDEX_CMPS_LAST 4'd1
`define CMDEX_IRET_2_protected_outer_STEP_3 4'd6
`define CMD_OUTS 7'd85
`define CMDEX_MOV_immediate 4'd0
`define CMDEX_JMP_task_switch_STEP_0 4'd13
`define CMDEX_MOV_modregrm 4'd1
`define CMDEX_int_real_STEP_4 4'd6
`define CMD_LTR 7'd21
`define CMDEX_int_real_STEP_5 4'd7
`define TASK_SWITCH_SOURCE_BITS 17:16
`define CMDEX_debug_reg_MOV_load_STEP_0 4'd1
`define CMDEX_debug_reg_MOV_load_STEP_1 4'd2
`define CMDEX_INC_DEC_increment_implicit 4'd0
`define CMDEX_JMP_Ap_STEP_1 4'd6
`define CMDEX_JMP_Ap_STEP_0 4'd3
`define CMD_SUB 7'd69
`define CMDEX_JMP_task_gate_STEP_1 4'd15
`define CMDEX_JMP_task_gate_STEP_0 4'd14
`define CMD_SHRD 7'd57
`define CMDEX_OUT_dx 4'd1
`define CMDEX_PUSH_MOV_SEG_modregrm_TR 4'd15
`define CMD_CALL_2 7'd4
`define CMD_CALL_3 7'd5
`define CMD_CWD 7'd93
`define CMDEX_JMP_2_call_gate_STEP_3 4'd3
`define CMDEX_JMP_2_call_gate_STEP_2 4'd2
`define CMD_STI 7'd96
`define CMD_LEAVE 7'd55
`define CMDEX_JMP_2_call_gate_STEP_1 4'd1
`define CMDEX_JMP_2_call_gate_STEP_0 4'd0
`define CMD_INS 7'd84
`define CMD_STC 7'd25
`define CMDEX_IRET_2_protected_same_STEP_1 4'd2
`define CMD_STD 7'd26
`define CMD_LOOP 7'd60
`define CMD_XLAT 7'd111
`define CMDEX_ENTER_PUSH 4'd2
`define CMDEX_IRET_2_protected_same_STEP_0 4'd1
`define CMDEX_CALL_2_task_switch_STEP_0 4'd2
`define CMDEX_MOV_memoffset 4'd3
`define CMD_BTx 7'd36
`define CMDEX_PUSH_MOV_SEG_modregrm_SS 4'd10
`define CMD_AND 7'd68
`define CMDEX_int_task_gate_STEP_1 4'd12
`define CMDEX_int_task_gate_STEP_0 4'd11
`define CMDEX_CALL_Ev_STEP_0 4'd0
`define CMDEX_Shift_modregrm_imm 4'd2
`define CMDEX_INC_DEC_decrement_implicit 4'd1
`define CMD_POP_seg 7'd34
`define CMD_CALL 7'd3
`define CMDEX_XCHG_implicit 4'd0
`define CMDEX_JMP_protected_seg_STEP_1 4'd12
`define CMDEX_JMP_protected_seg_STEP_0 4'd11
`define CMDEX_POPA_STEP_3 4'd3
`define CMDEX_POPA_STEP_2 4'd2
`define CMDEX_POPA_STEP_5 4'd5
`define CMDEX_POPA_STEP_4 4'd4
`define CMD_BSx 7'd116
`define CMD_NEG 7'd7
`define CMDEX_POPA_STEP_1 4'd1
`define CMDEX_POPA_STEP_0 4'd0
`define CMDEX_Shift_implicit 4'd0
`define CMDEX_MOV_to_seg_LLDT_LTR_STEP_LAST 4'd1
`define CMDEX_task_switch_2_STEP_0 4'd0
`define CMD_BTS 7'd37
`define CMDEX_XADD_FIRST 4'd0
`define CMD_BTR 7'd38
`define CMD_SHxD 7'd56
`define CMD_BTC 7'd39
`define CMD_OR 7'd65
`define CMDEX_task_switch_2_STEP_7 4'd7
`define CMD_task_switch_2 7'd100
`define CMD_task_switch_3 7'd101
`define CMD_task_switch_4 7'd102
`define CMD_CLTS 7'd62
`define CMDEX_RET_near 4'd0
`define CMD_JMP 7'd87
`define CMD_POP 7'd41
`define CMDEX_RET_near_LAST 4'd2
`define CMD_BOUND 7'd97
`define CMDEX_int_STEP_0 4'd0
`define CMD_XOR 7'd70
`define CMD_JCXZ 7'd2
`define CMDEX_ENTER_LAST 4'd1
`define CMDEX_task_switch_3_STEP_15 4'd15
`define CMDEX_OUT_imm 4'd0
`define CMD_JMP_2 7'd88
`define CMDEX_PUSH_MOV_SEG_modregrm_GS 4'd13
`define CMD_CMPXCHG 7'd52
`define CMDEX_task_switch_3_STEP_12 4'd12
`define CMDEX_OUTS_first 4'd0
`define CMDEX_control_reg_MOV_store_STEP_0 4'd3
`define CMD_XADD 7'd1
`define CMDEX_LAR_LSL_VERR_VERW_STEP_LAST 4'd2
`define CMD_RET_far 7'd63
`define CMD_SHLD 7'd56
`define CMD_CMC 7'd24
`define CMDEX_BOUND_STEP_LAST 4'd1
`define CMDEX_SHxD_modregrm_imm 4'd1
`define CMD_HLT 7'd12
`define CMDEX_LxS_STEP_LAST 4'd3
`define CMD_ARPL 7'd16
`define CMDEX_JMP_Ev_Jv_STEP_1 4'd4
`define CMD_ENTER 7'd53
`define CMD_SALC 7'd98
`define CMD_CLD 7'd23
`define CMD_CLC 7'd22
`define CMDEX_INT_INTO_INT_STEP_0 4'd0
`define CMD_CLI 7'd95
`define CMD_LLDT 7'd20
`define CMDEX_INT_INTO_INT1_STEP_0 4'd3
`define CMD_RET_near 7'd15
`define CMD_VERW 7'd82
`define CMDEX_JMP_Ev_STEP_0 4'd0
`define CMD_VERR 7'd81
`define CMDEX_IRET_protected_to_v86_STEP_0 4'd10
`define CMDEX_IRET_protected_to_v86_STEP_1 4'd11
`define CMDEX_IRET_protected_to_v86_STEP_4 4'd14
`define CMDEX_IRET_protected_to_v86_STEP_5 4'd15
`define CMDEX_IRET_protected_to_v86_STEP_2 4'd12
`define CMD_IN 7'd77
`define CMDEX_IRET_protected_to_v86_STEP_3 4'd13
`define CMD_CMP 7'd71
`define CMDEX_SALC_STEP_0 4'd0
`define CMDEX_LxS_STEP_3 4'd2
`define CMDEX_CALL_3_call_gate_more_STEP_8 4'd4
`define CMDEX_CALL_3_call_gate_more_STEP_7 4'd3
`define CMDEX_LxS_STEP_1 4'd0
`define CMDEX_LxS_STEP_2 4'd1
`define CMDEX_CALL_3_call_gate_more_STEP_9 4'd5
`define CMDEX_CALL_3_call_gate_more_STEP_5 4'd1
`define TASK_SWITCH_FROM_JUMP 2'd3
`define CMDEX_CALL_3_call_gate_more_STEP_6 4'd2
`define CMDEX_CALL_3_call_gate_more_STEP_4 4'd0
`define TASK_SWITCH_FROM_CALL 2'd2
`define CMDEX_TEST_modregrm_imm 4'd2
`define CMD_XCHG 7'd73
`define CMD_debug_reg 7'd110
`define CMDEX_CALL_protected_STEP_1 4'd12
`define CMDEX_POP_seg_STEP_LAST 4'd1
`define CMDEX_CALL_protected_STEP_0 4'd11
`define CMDEX_RET_far_outer_STEP_7 4'd10
`define CMDEX_RET_far_outer_STEP_3 4'd6
`define CMDEX_RET_far_outer_STEP_4 4'd7
`define CMDEX_RET_far_outer_STEP_5 4'd8
`define CMDEX_RET_far_outer_STEP_6 4'd9
`define CMDEX_CALL_Ap_STEP_1 4'd6
`define CMDEX_CALL_Ap_STEP_0 4'd3
`define CMD_INVD 7'd9
`define CMDEX_PUSH_immediate_se 4'd1

// --- PR-1a additions: FPU stub command-extension codes + CPUID FPU feature bit ---
`define CMDEX_FN_INIT      4'd2
`define CMDEX_FN_CLEX      4'd3
`define CMDEX_FNSTSW_AX    4'd4
`define CMDEX_FNSTCW_M16   4'd5
`define CPUID_FEATURES_EDX 32'd1

// --- PR-2b.2b additions: FPU arithmetic CMD code + first arith CMDEX ---
// CMD_fpu_arith is a distinct CMD from CMD_fpu (7'd50) so the arith family
// gets its own CMDEX namespace. Iter-24 ships only CMDEX_FADD_ST0_STi
// (D8 C0+i); the rest of the family (FSUB/FMUL/FDIV/reverse/pop/mem-form)
// lands in PR-2b.3+.
`define CMD_fpu_arith         7'd118
`define CMDEX_FADD_ST0_STi    4'd6

// --- PR-2b.3a additions: FSUB ST(0), ST(i) = D8 E0+i (D8 /4) ---
// Same encoding family as FADD (single ESC byte D8 + reg-form modrm), reg
// field switches from 000 (/0=ADD) to 100 (/4=SUB).
`define CMDEX_FSUB_ST0_STi    4'd7

// --- PR-2b.3b additions: FMUL ST(0), ST(i) = D8 C8+i (D8 /1) ---
// Same family again; reg field = 001 (/1 = MUL).
`define CMDEX_FMUL_ST0_STi    4'd8

// --- PR-2b.3c additions: FDIV ST(0), ST(i) = D8 F0+i (D8 /6) ---
// Same family again; reg field = 110 (/6 = DIV).  First op to exercise the
// FSM's unmasked-exception writeback-gate via real Zero_Divide inputs.
`define CMDEX_FDIV_ST0_STi    4'd9

// --- PR-2b.3d additions: reverse variants FSUBR/FDIVR ---
// FSUBR ST(0), ST(i) = D8 E8+i (D8 /5).  Computes ST(0) <- ST(i) - ST(0)
// (operands swapped vs FSUB).  Reuses softfloat_sub_x80 via an operand
// swap in execute_fpu.v.
// FDIVR ST(0), ST(i) = D8 F8+i (D8 /7).  Computes ST(0) <- ST(i) / ST(0)
// (dividend/divisor swapped vs FDIV).  Reuses softfloat_div_x80 the same
// way.  No new primitive, no new kind in kind_lat -- the reverse flag is
// carried in a separate 1-bit reverse_lat reg captured at op-start.
`define CMDEX_FSUBR_ST0_STi   4'd10
`define CMDEX_FDIVR_ST0_STi   4'd11

// --- PR-2b.3e additions: pop variants (DE family, "all instructions pop FPU stack") ---
// Per Intel SDM Vol. 2 and Bochs fetchdecode_x87.h:
//   DE C0+i = FADDP   ST(i), ST(0) : ST(i) <- ST(i) + ST(0), then FPU_pop()
//   DE C8+i = FMULP   ST(i), ST(0) : ST(i) <- ST(i) * ST(0), then FPU_pop()
//   DE E0+i = FSUBRP  ST(i), ST(0) : ST(i) <- ST(0) - ST(i), then FPU_pop()
//   DE E8+i = FSUBP   ST(i), ST(0) : ST(i) <- ST(i) - ST(0), then FPU_pop()
//   DE F0+i = FDIVRP  ST(i), ST(0) : ST(i) <- ST(0) / ST(i), then FPU_pop()
//   DE F8+i = FDIVP   ST(i), ST(0) : ST(i) <- ST(i) / ST(0), then FPU_pop()
// All six reuse the existing four softfloat primitives; the FSM adds a
// `dst_is_sti_lat` control (rf_wr_idx = abs_stsrc) and a one-cycle S_POP
// state that clears the old ST(0)'s tag to Empty and bumps TOP.
`define CMDEX_FADDP_STi_ST0   4'd12
`define CMDEX_FMULP_STi_ST0   4'd13
`define CMDEX_FSUBP_STi_ST0   4'd14
`define CMDEX_FSUBRP_STi_ST0  4'd15
`define CMDEX_FDIVP_STi_ST0   4'd16
`define CMDEX_FDIVRP_STi_ST0  4'd17

// --- PR-2b.3k additions: FXCH ST(i) = D9 C8+i (D9 /1) ---
// Pure-control op: swap ST(0) data+tag with ST(i) data+tag in one
// op, TOP unchanged.  Reuses the existing arith FSM fetch path
// (S_FETCH_A → S_FETCH_B → S_COMPUTE) to read both slots; the four
// arith primitives still run combinationally but their outputs are
// ignored.  A new is_fxch_lat (captured at S_IDLE→S_FETCH_A) routes
// S_RETIRE to write ST(0) := old-ST(i) and adds a one-cycle S_FXCH2
// state that writes ST(i) := old-ST(0).  flags_lat is forced 6'b0 so
// the writeback-gate and #MF lane stay quiet; exc_flags_set / mf
// stay zero.  No new primitive, no SW change.
`define CMDEX_FXCH_STi        4'd18

// --- PR-2b.3l additions: FLD ST(i) = D9 C0+i (D9 /0) ---
// Pure-control "push" op: TOP-- and new ST(0) := old ST(i) (data+tag).
// Read of old ST(i) happens BEFORE TOP shifts — so the regfile read
// uses the pre-shift abs_stsrc = (top_lat + rm) & 7, then the S_RETIRE
// write targets (top_lat - 1) & 7 = the new ST(0) slot, and the same
// cycle pulses top_we with top_din = top_lat - 1.  Single-cycle write
// (no S_FXCH2 / S_POP companion).  Like FXCH, flags_lat is forced 6'b0
// in S_COMPUTE so the writeback-gate / #MF / CSR OR-lane all stay
// quiet; exc_flags_set / mf stay zero.  #IS on Empty ST(i) is advisory
// only (stsrc_empty_lat is captured but not yet faulted on).  No new
// primitive, no SW change.
`define CMDEX_FLD_STi         4'd19

// --- PR-2b.3m additions: FST ST(i) = D9 D0+i (D9 /2) ---
// --- PR-2b.3m additions: FSTP ST(i) = DD D8+i (DD /3) ---
// Pure-control "store" ops, completing the swap/push/store control-op
// trio that started with FXCH (iter 42) and FLD (iter 43).  FST writes
// ST(0) data+tag into ST(i); TOP unchanged.  FSTP composes FST with a
// pop (tag-clear at old ST(0), TOP++) via the existing iter-34
// dst_is_sti_lat + pop_after_lat machinery — the only new control flag
// is is_fst_lat (which covers BOTH FST and FSTP) and merely overrides
// rf_wr_data → a_lat (= ST(0)) and rf_wr_tag → st0_tag_lat (= ST(0)'s
// tag).  The destination muxing (dst_is_sti_lat → abs_stsrc) and the
// pop side-effects (pop_after_lat → S_POP cleanup) are reused from
// iter 34.  flags_lat is forced 6'b0 in S_COMPUTE (merge predicate
// extended) so the writeback-gate / #MF / CSR OR-lane stay quiet.  No
// new primitive, no SW change.  FST: dest=abs_stsrc, no pop, TOP
// unchanged.  FSTP: dest=abs_stsrc, then S_POP (Empty at abs_st0,
// TOP++).
`define CMDEX_FST_STi         4'd20
`define CMDEX_FSTP_STi        4'd21

// --- PR-2b.3n additions: unary control ops on ST(0) (no source ST(i)) ---
// FCHS = D9 E0 : ST(0) <- ST(0) with bit 79 toggled (sign flip).
// FABS = D9 E1 : ST(0) <- ST(0) with bit 79 cleared (magnitude).
// FXAM = D9 E5 : classify ST(0) and drive {C3,C2,C1,C0} into the CSR's cc
//                lane.  C1 carries ST(0)'s sign; C3/C2/C0 encode the class
//                (Empty / NaN / Normal / Inf / Zero / Denormal / Unsupported)
//                per Intel SDM Vol 1 §8.3.5 / Bochs FXAM table.
// All three are dispatched via a NEW `CMD_fpu_unary` (7'd119) so they get
// a fresh 4-bit CMDEX namespace.  This is necessary because the existing
// CMD_fpu_arith namespace is FULL — 16 distinct CMDEX values (4'd0..4'd15)
// are already assigned across FADD/FSUB/FMUL/FDIV/FSUBR/FDIVR plus the
// FADDP/FMULP/FSUBP/FSUBRP/FDIVP/FDIVRP pop variants plus FXCH/FLD/FST/FSTP.
// Note: the existing iter-23..44 CMDEX literals 4'd16..4'd21 silently
// truncate (Verilog drops upper bits when the literal value exceeds the
// declared width) into 4'd0..4'd5; that "works" only because no two
// arith-namespace ops collide post-truncation.  Naively extending with
// 4'd22 (truncates to 4'd6 = CMDEX_FADD) WOULD collide — hence the
// separate CMD code here.
`define CMD_fpu_unary         7'd119
`define CMDEX_FCHS            4'd0
`define CMDEX_FABS            4'd1
`define CMDEX_FXAM            4'd2
// PR-2b.3p (iter 47) — FTST = D9 E4 : compare ST(0) to +0.0.  No source
// operand; the existing FETCH path reads ST(rm) but execute_fpu's cmp
// classifier overrides cmp_b_v = 80'h0 when is_ftst_lat is set, so the
// FCOM-encoded {C3,C2,C1=0,C0} drops out of the same machinery.  Raises
// IE on any NaN (FCOM-class — not FUCOM).  Same dispatch family as
// FCHS/FABS/FXAM (CMD_fpu_unary) but flows through is_cmp_now in
// execute_fpu.v so the cmp lane (cc_we + flags_lat IE override) engages.
`define CMDEX_FTST            4'd3

// PR-2b.3o (iter 46) — x87 comparison ops on ST(0) vs ST(i): FCOM / FCOMP /
// FUCOM / FUCOMP.  Read BOTH ST(0) and ST(i) via the existing fetch path;
// classify result (much like FXAM but on the comparison outcome); pulse
// `cc_we` to the CSR with {C3,C2,C1=0,C0} per Intel SDM Vol 1 §8.3.6.
// No regfile data writeback (rf_wr_en gated off).  FCOMP / FUCOMP pop
// after compare via the iter-30 `pop_after_lat=1` mechanism.
//   FCOM   = D8 D0+i (modrm reg=2)
//   FCOMP  = D8 D8+i (modrm reg=3)
//   FUCOM  = DD E0+i (modrm reg=4)
//   FUCOMP = DD E8+i (modrm reg=5)
// Dispatched via a NEW `CMD_fpu_cmp` (7'd120) so they get a fresh 4-bit
// CMDEX namespace — same reasoning as CMD_fpu_unary iter-45 (arith CMDEX
// namespace is FULL).  FCOM raises IE on ANY NaN; FUCOM raises IE only on
// SNaN — the difference is captured by `is_fucom_lat` in execute_fpu.v.
`define CMD_fpu_cmp           7'd120
`define CMDEX_FCOM            4'd0
`define CMDEX_FCOMP           4'd1
`define CMDEX_FUCOM           4'd2
`define CMDEX_FUCOMP          4'd3

// PR-2b.3q (iter 48) — FCOMPP / FUCOMPP : x87 cmp + double-pop ops.
//   FCOMPP  = DE D9   (unique 2-byte opcode, no modrm sub-field — like FTST)
//   FUCOMPP = DA E9   (unique 2-byte opcode)
// Same dispatch family as FCOM/FCOMP/FUCOM/FUCOMP (CMD_fpu_cmp); the cmp
// classifier in execute_fpu.v fires unchanged.  FCOMPP shares FCOM's IE
// policy (raise on any NaN); FUCOMPP shares FUCOM's (silent QNaN, raise
// on SNaN only).  Differentiating feature: BOTH pop ST(0) and ST(1) —
// driven by a new `pop_twice_lat` reg + a new S_POP2 FSM state that
// mirrors S_POP for the second tag-clear + TOP++ cycle.
`define CMDEX_FCOMPP          4'd4
`define CMDEX_FUCOMPP         4'd5

// PR-2b.3u (iter 52) — FCOMI / FUCOMI / FCOMIP / FUCOMIP : P6-era cmp ops
// that write the INTEGER EFLAGS register (CF, ZF, PF) instead of the FPU
// CSR cc bits (C0..C3).  Mirror of iter-51 FCMOVcc: where FCMOVcc CONSUMES
// integer EFLAGS, FCOMI PRODUCES them.  Reuses the iter-46 cmp classifier
// 100% — same sign-aware compare, same NaN detection, same ±0 equality
// rules.  Differentiating feature: at S_RETIRE, drive the new
// `eflags_we` / `eflags_value` output ports (mapping cmp_cc → {ZF,PF,CF}
// per Intel SDM Vol 1 §8.3.6:
//    greater    cc=0000 → ZF=0 PF=0 CF=0
//    less       cc=0001 → ZF=0 PF=0 CF=1
//    equal      cc=1000 → ZF=1 PF=0 CF=0
//    unordered  cc=1101 → ZF=1 PF=1 CF=1)
// instead of cc_we / cc_din.  The CSR cc lane stays silent for FCOMI ops
// (the SDM-mandated C1=0 partial-write is deferred — see iter-52 log).
//
// Encodings (per Intel SDM Vol 2):
//   FCOMI   ST,ST(i)  = DB F0+i   (mod=11, reg=110, no pop)
//   FCOMIP  ST,ST(i)  = DF F0+i   (mod=11, reg=110, pop)
//   FUCOMI  ST,ST(i)  = DB E8+i   (mod=11, reg=101, no pop)
//   FUCOMIP ST,ST(i)  = DF E8+i   (mod=11, reg=101, pop)
//
// IE policy mirrors FCOM/FUCOM: FCOMI/FCOMIP raise on ANY NaN;
// FUCOMI/FUCOMIP raise IE only on SNaN (QNaN silent — joins
// is_cmp_unord_now).  FCOMIP/FUCOMIP pop via existing pop_after_lat=1.
`define CMDEX_FCOMI           4'd6
`define CMDEX_FCOMIP          4'd7
`define CMDEX_FUCOMI          4'd8
`define CMDEX_FUCOMIP         4'd9

// PR-2b.3r (iter 49) — x87 stack-control ops on ST(i): FFREE (DD C0+i).
//   FFREE ST(i)  = DD C0+i (modrm reg=000, mod=11) — free (mark Empty) ST(i).
// Tag-only write of Empty to ST(i).  Data preserved (regfile write uses
// b_lat = ST(i)'s data as captured in the FETCH path so the write is a
// data-preserving + tag-stomping operation rather than data-stomping).
// No TOP change, no flags, no #MF.
// Dispatched via a NEW `CMD_fpu_stack_ctrl` (7'd121) — distinct from
// CMD_fpu_unary (which targets ST(0)) because FFREE is the first stack-
// control op that targets ST(i).  Future tag-manipulation / TOP-only
// ops (FNOP, FINCSTP, FDECSTP) can also land in this namespace.
`define CMD_fpu_stack_ctrl    7'd121
`define CMDEX_FFREE           4'd0

// PR-2b.3s (iter 50) — three more stack-control ops joining the
// CMD_fpu_stack_ctrl namespace established at iter 49:
//   FNOP    = D9 D0  (no-op — no regfile / TOP / cc / flags change)
//   FDECSTP = D9 F6  (TOP -= 1; no tag change, no data write)
//   FINCSTP = D9 F7  (TOP += 1; no tag change, no data write)
// All three walk the existing IDLE→FETCH→COMPUTE→POST→RETIRE FSM
// (FETCH reads are discarded).  FNOP retires with NO side-effects;
// FDECSTP and FINCSTP pulse top_we at S_RETIRE with top_din = top_lat
// ∓ 1.  No FSM state additions, no new ports.  Demonstrates the
// multi-occupant scaling of the iter-49 namespace.
`define CMDEX_FNOP            4'd1
`define CMDEX_FDECSTP         4'd2
`define CMDEX_FINCSTP         4'd3

// PR-2b.3t (iter 51) — FCMOVcc family (P6 conditional move on EFLAGS).
//   DA C0+i .. C7+i  FCMOVB   ST(0), ST(i)   if CF=1
//   DA C8+i .. CF+i  FCMOVE   ST(0), ST(i)   if ZF=1
//   DA D0+i .. D7+i  FCMOVBE  ST(0), ST(i)   if (CF|ZF)=1
//   DA D8+i .. DF+i  FCMOVU   ST(0), ST(i)   if PF=1
//   DB C0+i .. C7+i  FCMOVNB  ST(0), ST(i)   if CF=0
//   DB C8+i .. CF+i  FCMOVNE  ST(0), ST(i)   if ZF=0
//   DB D0+i .. D7+i  FCMOVNBE ST(0), ST(i)   if (CF|ZF)=0
//   DB D8+i .. DF+i  FCMOVNU  ST(0), ST(i)   if PF=0
// Dispatched via a NEW `CMD_fpu_cmov` (7'd122) — first FPU CMD that reads
// non-FPU CPU state (the integer-side EFLAGS lane).  execute_fpu.v gains
// three new inputs (cflag/zflag/pflag) plumbed from execute.v's
// already-in-scope EFLAGS bundle.  When the condition is taken, ST(0)
// := ST(i) (data + tag); when not taken, ST(0) is left unchanged
// (rf_wr_en gated off).  No TOP change, no pop, no flags.  CMDEX bits
// are sequential (0..7) so the dispatch table in decode_commands.v
// stays a flat 8-way match — the cond-evaluation and invert logic
// live entirely in execute_fpu.v.
`define CMD_fpu_cmov          7'd122
`define CMDEX_FCMOVB          4'd0
`define CMDEX_FCMOVE          4'd1
`define CMDEX_FCMOVBE         4'd2
`define CMDEX_FCMOVU          4'd3
`define CMDEX_FCMOVNB         4'd4
`define CMDEX_FCMOVNE         4'd5
`define CMDEX_FCMOVNBE        4'd6
`define CMDEX_FCMOVNU         4'd7

// PR-2b.4d (iter 55) — first mem-form FPU op: FADD m32fp (D8 /0 mod!=11) and
// FADD m64fp (DC /0 mod!=11).  The iter-53 plumbing wired exe_mem_data into
// execute_fpu's port surface; iter-54 landed the float32/float64 -> floatx80
// converters as standalone primitives.  This iter activates both end-to-end
// by dispatching mem-form FADD through a NEW `CMD_fpu_arith_mem` (7'd123) so
// it gets a fresh 4-bit CMDEX namespace — the existing CMD_fpu_arith one is
// already FULL (iter-45 note: 4'd0..4'd15 all assigned across reg-form arith
// + pop variants + FXCH/FLD/FST/FSTP).  CMDEX encodes the operand width:
//   CMDEX_FADD_M32 (4'd0) — m32fp source (D8 /0 mod!=11)
//   CMDEX_FADD_M64 (4'd1) — m64fp source (DC /0 mod!=11)
// execute_fpu derives `is_mem_form_lat` and `mem_fmt_lat` from these CMDEX
// values directly — so the external exe_is_mem_form / exe_mem_fmt ports stay
// quiet for now (they'll be driven by the decoder lane the design doc plans
// when later sub-iters expand the mem-form set to FSUB/FMUL/FDIV/etc.).
// Destination is ST(0) for both (matches D8/DC mem-form SDM canonical).
`define CMD_fpu_arith_mem     7'd123
`define CMDEX_FADD_M32        4'd0
`define CMDEX_FADD_M64        4'd1
