//======================================================== conditions
wire cond_0 = dec_ready_2byte_modregrm && { decoder[7:1], 1'b0 } == 8'hC0;
wire cond_1 = prefix_group_1_lock  && `DEC_MODREGRM_IS_MOD_11;
wire cond_2 = decoder[0] == 1'b0;
wire cond_3 = dec_ready_one_one && decoder[7:0] == 8'hE3;
wire cond_4 = prefix_group_1_lock ;
wire cond_5 = dec_ready_call_jmp_imm && (decoder[7:0] == 8'h9A || decoder[7:0] == 8'hE8);
wire cond_6 = decoder[1] == 1'b0;
wire cond_7 = dec_ready_modregrm_one && decoder[7:0] == 8'hFF && (decoder[13:11] == 3'd2 || decoder[13:11] == 3'd3);
wire cond_8 = prefix_group_1_lock  || (decoder[13:11] == 3'd3 && `DEC_MODREGRM_IS_MOD_11);
wire cond_9 = decoder[11] == 1'b0;
wire cond_10 = (dec_ready_one && (decoder[7:0] == 8'h06 || decoder[7:0] == 8'h16 || decoder[7:0] == 8'h0E || decoder[7:0] == 8'h1E)) || (dec_ready_2byte_one && (decoder[7:0] == 8'hA0 || decoder[7:0] == 8'hA8));
wire cond_11 = dec_ready_modregrm_one && decoder[7:0] == 8'h8C;
wire cond_12 = prefix_group_1_lock  || decoder[13:11] >= 3'd6;
wire cond_13 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h00 && decoder[13:11] == 3'd0;
wire cond_14 = prefix_group_1_lock  || ~(protected_mode);
wire cond_15 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h00 && decoder[13:11] == 3'd1;
wire cond_16 = dec_ready_modregrm_one && { decoder[7:1], 1'b0 } == 8'hF6 && decoder[13:11] == 3'd3;
wire cond_17 = (dec_ready_one_one && decoder[7:4] == 4'h7) || (dec_ready_2byte_imm && decoder[7:4] == 4'h8);
wire cond_18 = ~(dec_prefix_2byte);
wire cond_19 = dec_prefix_2byte;
wire cond_20 = dec_ready_2byte_one && decoder[7:0] == 8'h08;
wire cond_21 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h01 && decoder[13:11] == 3'd7;
wire cond_22 = prefix_group_1_lock  || `DEC_MODREGRM_IS_MOD_11;
wire cond_23 = dec_ready_one && decoder[7:0] == 8'hF4;
wire cond_24 = dec_ready_one && { decoder[7:1], 1'b0 } == 8'hAE;
wire cond_25 = dec_prefix_group_1_rep != 2'd0;
wire cond_26 = dec_ready_one && decoder[7:4] == 4'h4;
wire cond_27 = dec_ready_modregrm_one && { decoder[7:1], 1'b0 } == 8'hFE && { decoder[13:12], 1'b0 } == 3'b000;
wire cond_28 = (dec_ready_one && decoder[7:0] == 8'hC3) || (dec_ready_one_two && decoder[7:0] == 8'hC2);
wire cond_29 = dec_ready_modregrm_one && decoder[7:0] == 8'h63;
wire cond_30 = dec_ready_2byte_one && { decoder[7:3], 3'b000 } == 8'hC8;
wire cond_31 = (dec_ready_modregrm_one && (decoder[7:0] == 8'hC4 || decoder[7:0] == 8'hC5)) || (dec_ready_2byte_modregrm && (decoder[7:0] == 8'hB2 || decoder[7:0] == 8'hB4 || decoder[7:0] == 8'hB5));
wire cond_32 = dec_ready_modregrm_one && decoder[7:0] == 8'h8E;
wire cond_33 = prefix_group_1_lock  || decoder[13:11] >= 3'd6 || decoder[13:11] == 3'd1;
wire cond_34 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h00 && decoder[13:11] == 3'd2;
wire cond_35 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h00 && decoder[13:11] == 3'd3;
wire cond_36 = dec_ready_one && decoder[7:0] == 8'hF8;
wire cond_37 = dec_ready_one && decoder[7:0] == 8'hFC;
wire cond_38 = dec_ready_one && decoder[7:0] == 8'hF5;
wire cond_39 = dec_ready_one && decoder[7:0] == 8'hF9;
wire cond_40 = dec_ready_one && decoder[7:0] == 8'hFD;
wire cond_41 = dec_ready_one && decoder[7:0] == 8'h9E;
wire cond_42 = dec_ready_one_one && decoder[7:0] == 8'hD5;
wire cond_43 = dec_ready_one_one && decoder[7:0] == 8'hD4;
wire cond_44 = (dec_ready_one && (decoder[7:0] == 8'h07 || decoder[7:0] == 8'h17 || decoder[7:0] == 8'h1F)) || (dec_ready_2byte_one && (decoder[7:0] == 8'hA1 || decoder[7:0] == 8'hA9));
wire cond_45 = (dec_ready_2byte_modregrm && decoder[7:0] == 8'hA3) || (dec_ready_2byte_modregrm_imm && decoder[7:0] == 8'hBA && decoder[13:11] == 3'd4);
wire cond_46 = (dec_ready_2byte_modregrm && decoder[7:0] == 8'hB3) || (dec_ready_2byte_modregrm_imm && decoder[7:0] == 8'hBA && decoder[13:11] == 3'd6);
wire cond_47 = (dec_ready_2byte_modregrm && decoder[7:0] == 8'hAB) || (dec_ready_2byte_modregrm_imm && decoder[7:0] == 8'hBA && decoder[13:11] == 3'd5);
wire cond_48 = (dec_ready_2byte_modregrm && decoder[7:0] == 8'hBB) || (dec_ready_2byte_modregrm_imm && decoder[7:0] == 8'hBA && decoder[13:11] == 3'd7);
wire cond_49 = dec_ready_one && decoder[7:0] == 8'hCF;
wire cond_50 = ~(protected_mode);
wire cond_51 = dec_ready_one && { decoder[7:3], 3'b0 } == 8'h58;
wire cond_52 = dec_ready_modregrm_one && decoder[7:0] == 8'h8F && decoder[13:11] == 3'd0;
wire cond_53 = dec_ready_modregrm_one && { decoder[7:1], 1'b0 } == 8'hF6 && decoder[13:11] == 3'd6;
wire cond_54 = dec_ready_modregrm_one && { decoder[7:1], 1'b0 } == 8'hF6 && decoder[13:11] == 3'd7;
wire cond_55 = dec_ready_modregrm_one && { decoder[7:2], 2'b0 } == 8'hD0;
wire cond_56 = decoder[1];
wire cond_57 = dec_ready_modregrm_imm && { decoder[7:1], 1'b0 } == 8'hC0;
wire cond_58 = dec_ready_one && { decoder[7:1], 1'b0 } == 8'hA6;
wire cond_59 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h01 && decoder[13:11] == 3'd4;
wire cond_60 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h01 && decoder[13:11] == 3'd6;
wire cond_61 = dec_ready_2byte_modregrm && { decoder[7:2], 1'b0, decoder[0] } == 8'h20;
wire cond_62 = prefix_group_1_lock  || (decoder[13:11] != 3'd0 && decoder[13:11] != 3'd2 && decoder[13:11] != 3'd3);
wire cond_63 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h01 && decoder[13:11] == 3'd2;
wire cond_64 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h01 && decoder[13:11] == 3'd3;
wire cond_65 = dec_ready_one && decoder[7:0] == 8'h60;
wire cond_66 = dec_ready_one && decoder[7:0] == 8'h9B;
// PR-2b.4h (iter 59): gate the legacy D8..DF catch-all to reg-form only.
// Before: catch-all fired for ANY modrm byte, dispatching to CMD_fpu /
// CMDEX_ESC_STEP_0 (legacy stub) and shadowing the more specific
// cond_144..147 (PR-1a) and cond_148..205 (PR-2b) at runtime.  After: cond_67
// only matches reg-form (mod=11) opcodes, so mem-form D8/DC opcodes
// (cond_190..205) and mem-form D9 /7 FNSTCW (cond_147) can win in the
// dispatch cascade — unblocking real DOS-workload runtime testing of every
// iter-55..58 mem-form op + PR-1a FNSTCW m16.  Reg-form PR-2b ops
// (cond_148..170, etc.) still lose to cond_67 in the cascade; reg-form
// runtime dispatch is a separate follow-up iter.  Trade-off: mem-form
// D9 /0..6, DA, DB, DD, DE, DF instructions no longer hit the legacy stub
// (which silently no-op'd them); they now fail to decode and would hang
// the CPU at runtime.  Those ops were never actually implemented anyway —
// the previous behaviour was "silent no-op", the new behaviour is "explicit
// hang" — both are wrong, but the new shape is louder and pushes the
// missing-ops work forward instead of hiding it.
wire cond_67 = dec_ready_modregrm_one && { decoder[7:3], 3'b0 } == 8'hD8 && `DEC_MODREGRM_IS_MOD_11;
wire cond_68 = dec_ready_2byte_modregrm && decoder[7:4] == 4'h9;
wire cond_69 = dec_ready_2byte_modregrm && { decoder[7:1], 1'b0 } == 8'hB0;
wire cond_70 = dec_ready_one_three && decoder[7:0] == 8'hC8;
wire cond_71 = (dec_ready_modregrm_one && ({ decoder[7:1], 1'b0 } == 8'hF6 && decoder[13:11] == 3'd5)) || (dec_ready_2byte_modregrm && decoder[7:0] == 8'hAF);
wire cond_72 = dec_ready_modregrm_imm && (decoder[7:0] == 8'h69 || decoder[7:0] == 8'h6B);
wire cond_73 = dec_ready_one && decoder[7:0] == 8'hC9;
wire cond_74 = (dec_ready_2byte_modregrm && decoder[7:0] == 8'hA5) || (dec_ready_2byte_modregrm_imm && decoder[7:0] == 8'hA4);
wire cond_75 = decoder[0];
wire cond_76 = (dec_ready_2byte_modregrm && decoder[7:0] == 8'hAD) || (dec_ready_2byte_modregrm_imm && decoder[7:0] == 8'hAC);
wire cond_77 = dec_ready_2byte_one && decoder[7:0] == 8'h09;
wire cond_78 = dec_ready_one_imm && decoder[7:6] == 2'b00 && decoder[2:1] == 2'b10;
wire cond_79 = dec_ready_modregrm_one && decoder[7:6] == 2'b00 && decoder[2] == 1'b0;
wire cond_80 = prefix_group_1_lock  && (decoder[1] == 1'b1 || `DEC_MODREGRM_IS_MOD_11 || decoder[5:3] == 3'b111);
wire cond_81 = dec_ready_modregrm_imm && { decoder[7:2], 2'b00 } == 8'h80;
wire cond_82 = prefix_group_1_lock  && (decoder[13:11] == 3'b111 || `DEC_MODREGRM_IS_MOD_11);
wire cond_83 = dec_ready_modregrm_one && { decoder[7:1], 1'b0 } == 8'hF6 && decoder[13:11] == 3'd4;
wire cond_84 = dec_ready_one_one && (decoder[7:0] == 8'hE0 || decoder[7:0] == 8'hE1 || decoder[7:0] == 8'hE2);
wire cond_85 = dec_ready_one_imm && { decoder[7:1], 1'b0 } == 8'hA8;
wire cond_86 = dec_ready_modregrm_one && { decoder[7:1], 1'b0 } == 8'h84;
wire cond_87 = dec_ready_modregrm_imm && { decoder[7:1], 1'b0 } == 8'hF6 && { decoder[13:12], 1'b0 } == 3'd0;
wire cond_88 = dec_ready_2byte_one && decoder[7:0] == 8'h06;
wire cond_89 = (dec_ready_one && decoder[7:0] == 8'hCB) || (dec_ready_one_two && decoder[7:0] == 8'hCA);
wire cond_90 = dec_ready_one && { decoder[7:1], 1'b0 } == 8'hAC;
wire cond_91 = dec_ready_one && { decoder[7:3], 3'b0 } == 8'h90;
wire cond_92 = dec_ready_modregrm_one && { decoder[7:1], 1'b0 } == 8'h86;
wire cond_93 = dec_ready_one && { decoder[7:3], 3'b0 } == 8'h50;
wire cond_94 = dec_ready_one_imm && (decoder[7:0] == 8'h6A || decoder[7:0] == 8'h68);
wire cond_95 = dec_ready_modregrm_one && decoder[7:0] == 8'hFF && decoder[13:11] == 3'd6;
wire cond_96 = (dec_ready_one && (decoder[7:0] == 8'hCC || decoder[7:0] == 8'hCE || decoder[7:0] == 8'hF1)) || (dec_ready_one_one && decoder[7:0] == 8'hCD);
wire cond_97 = (decoder[0] ^ decoder[2]) == 1'b1;
wire cond_98 = dec_ready_2byte_one && decoder[7:0] == 8'hA2;
wire cond_99 = (dec_ready_one && { decoder[7:1], 1'b0 } == 8'hEC) || (dec_ready_one_one && { decoder[7:1], 1'b0 } == 8'hE4);
wire cond_100 = decoder[3];
wire cond_101 = decoder[3] == 1'b1;
wire cond_102 = dec_ready_modregrm_one && { decoder[7:1], 1'b0 } == 8'hF6 && decoder[13:11] == 3'd2;
wire cond_103 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h00 && decoder[13:11] == 3'd4;
wire cond_104 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h00 && decoder[13:11] == 3'd5;
wire cond_105 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h02;
wire cond_106 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h03;
wire cond_107 = dec_ready_one && { decoder[7:1], 1'b0 } == 8'hAA;
wire cond_108 = dec_ready_one && { decoder[7:1], 1'b0 } == 8'h6C;
wire cond_109 = dec_ready_one && { decoder[7:1], 1'b0 } == 8'h6E;
wire cond_110 = dec_ready_one && decoder[7:0] == 8'h9C;
wire cond_111 = dec_ready_call_jmp_imm && (decoder[7:0] == 8'hEA || decoder[7:0] == 8'hE9 || decoder[7:0] == 8'hEB);
wire cond_112 = decoder[3:0] == 4'hB;
wire cond_113 = dec_ready_modregrm_one && decoder[7:0] == 8'hFF && (decoder[13:11] == 3'd4 || decoder[13:11] == 3'd5);
wire cond_114 = prefix_group_1_lock  || (decoder[13:11] == 3'd5 && `DEC_MODREGRM_IS_MOD_11);
wire cond_115 = (dec_ready_one && { decoder[7:1], 1'b0 } == 8'hEE) || (dec_ready_one_one && { decoder[7:1], 1'b0 } == 8'hE6);
wire cond_116 = dec_ready_mem_offset && { decoder[7:2], 2'b0 } == 8'hA0;
wire cond_117 = dec_ready_one_imm && decoder[7:4] == 4'hB;
wire cond_118 = decoder[3] == 1'b0;
wire cond_119 = dec_ready_modregrm_one && { decoder[7:2], 2'b0 } == 8'h88;
wire cond_120 = dec_ready_modregrm_imm && { decoder[7:1], 1'b0 } == 8'hC6 && decoder[13:11] == 3'd0;
wire cond_121 = dec_ready_one && decoder[7:0] == 8'h9F;
wire cond_122 = dec_ready_one && decoder[7:0] == 8'h98;
wire cond_123 = dec_ready_one && decoder[7:0] == 8'h99;
wire cond_124 = dec_ready_one && decoder[7:0] == 8'h9D;
wire cond_125 = dec_ready_one && decoder[7:0] == 8'hFA;
wire cond_126 = dec_ready_one && decoder[7:0] == 8'hFB;
wire cond_127 = dec_ready_modregrm_one && decoder[7:0] == 8'h62;
wire cond_128 = dec_ready_one && decoder[7:0] == 8'hD6;
wire cond_129 = dec_ready_modregrm_one && decoder[7:0] == 8'h8D;
wire cond_130 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h01 && decoder[13:11] == 3'd0;
wire cond_131 = dec_ready_2byte_modregrm && decoder[7:0] == 8'h01 && decoder[13:11] == 3'd1;
wire cond_132 = dec_ready_one && { decoder[7:1], 1'b0 } == 8'hA4;
wire cond_133 = dec_ready_2byte_modregrm && { decoder[7:1], 1'b0 } == 8'hB6;
wire cond_134 = dec_ready_2byte_modregrm && { decoder[7:1], 1'b0 } == 8'hBE;
wire cond_135 = dec_ready_one && decoder[7:0] == 8'h61;
wire cond_136 = dec_ready_2byte_modregrm && { decoder[7:2], 1'b0, decoder[0] } == 8'h21;
wire cond_137 = dec_ready_one && decoder[7:0] == 8'hD7;
wire cond_138 = dec_ready_one && decoder[7:0] == 8'h37;
wire cond_139 = dec_ready_one && decoder[7:0] == 8'h3F;
wire cond_140 = dec_ready_one && decoder[7:0] == 8'h27;
wire cond_141 = dec_ready_one && decoder[7:0] == 8'h2F;
wire cond_142 = dec_ready_2byte_modregrm && decoder[7:0] == 8'hBC;
wire cond_143 = dec_ready_2byte_modregrm && decoder[7:0] == 8'hBD;
// --- PR-1a additions: 4 new FPU-stub decode predicates ---
// cond_144: FNINIT       = DB E3   (the 9B WAIT prefix is handled separately)
// cond_145: FNCLEX       = DB E2
// cond_146: FNSTSW AX    = DF E0
// cond_147: FNSTCW m16   = D9 /7   (mem form, mod != 11)
//
// Iter-25 fix: PR-1a (iter 12) wrote these with the byte slices reversed
// (decoder[15:8] for opcode, decoder[7:0] for modrm) AND cond_144..146
// gated on dec_ready_2byte_one — that ready flag requires dec_prefix_2byte
// (set only after a 0F escape in decode_prefix.v:163), so the conds were
// unreachable. They never fired in PR-1a runtime testing because runtime
// testing never ran. The correct convention is opcode in decoder[7:0],
// modrm in decoder[15:8] (matches cond_29 / cond_16 / cond_148), and the
// ready flag for a 1-byte-opcode + modrm form is dec_ready_modregrm_one.
wire cond_144 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[15:8] == 8'hE3;
wire cond_145 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[15:8] == 8'hE2;
wire cond_146 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDF && decoder[15:8] == 8'hE0;
wire cond_147 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[13:11] == 3'b111 && decoder[15:14] != 2'b11;
// iter-229: FNSTSW m16 = DD /7 mem-form (mod != 11).  Structural twin of FNSTCW
// cond_147 (D9 /7): same byte layout (opcode in decoder[7:0], modrm in
// decoder[15:8]); routes to CMD_fpu + CMDEX_FNSTSW_M16.  Was previously
// undecoded (only FNSTSW AX = DF E0 existed) — the FX Fighter freeze root cause.
wire cond_250 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDD && decoder[13:11] == 3'b111 && decoder[15:14] != 2'b11;

// PR-2b.2b: FADD ST(0), ST(i) = D8 C0+i.  Single-byte ESC opcode (D8) + modrm
// with mod=11 (register form) and reg=000 (/0 = ADD).  Source ST(i) index in
// modrm.rm = decoder[10:8].
//
// NOTE on byte positions: dec_ready_modregrm_one is the no-0F-prefix path, so
// decoder[7:0] holds the opcode and decoder[15:8] holds the modrm byte.
// (cond_29 and cond_16 above use the same layout.  PR-1a's cond_144..147
// have these byte slices swapped — known latent bug, tracked separately.)
wire cond_148 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd0;
// PR-2b.3a: FSUB ST(0), ST(i) = D8 E0+i.  Same family as cond_148; reg=100
// (/4 = SUB).  modrm.rm = decoder[10:8] carries the source ST(i) index;
// reused unchanged by execute_fpu's is_arith_st0_sti dispatch.
wire cond_149 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd4;
// PR-2b.3b: FMUL ST(0), ST(i) = D8 C8+i.  Same family again; reg=001
// (/1 = MUL).  Same dispatch — third entry in execute_fpu's kind_lat
// selector.
wire cond_150 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd1;
// PR-2b.3c: FDIV ST(0), ST(i) = D8 F0+i.  Same family again; reg=110
// (/6 = DIV).  Fourth entry in execute_fpu's kind_lat selector;
// also first op to fire the unmasked-exception writeback-gate
// (when b=0 + ZE-unmasked, ST(0) is preserved and #MF raises).
wire cond_151 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd6;
// PR-2b.3d: FSUBR ST(0), ST(i) = D8 E8+i  (reg=101 = /5).  Reuses
// softfloat_sub_x80 via an operand swap in execute_fpu (reverse_lat=1
// captured at op-start when is_fsubr_st0_sti).
wire cond_152 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd5;
// PR-2b.3d: FDIVR ST(0), ST(i) = D8 F8+i  (reg=111 = /7).  Reuses
// softfloat_div_x80 the same way (reverse_lat=1 when is_fdivr_st0_sti).
wire cond_153 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd7;

// PR-2b.3e: pop variants — DE family, "all instructions pop FPU stack"
// (Bochs fetchdecode_x87.h line 353 note).  Opcode byte 0xDE, modrm with
// mod=11 (reg-form), reg field selects the arithmetic op; rm carries the
// destination ST(i) index.  Per Intel SDM Vol 2:
//   DE C0+i = FADDP  ST(i), ST(0)  (reg=000, /0)
//   DE C8+i = FMULP  ST(i), ST(0)  (reg=001, /1)
//   DE E0+i = FSUBRP ST(i), ST(0)  (reg=100, /4) - dst <- ST(0) - ST(i)
//   DE E8+i = FSUBP  ST(i), ST(0)  (reg=101, /5) - dst <- ST(i) - ST(0)
//   DE F0+i = FDIVRP ST(i), ST(0)  (reg=110, /6) - dst <- ST(0) / ST(i)
//   DE F8+i = FDIVP  ST(i), ST(0)  (reg=111, /7) - dst <- ST(i) / ST(0)
// Same dispatcher as the D8 family, with two extra control bits added
// in execute_fpu.v: dst_is_sti_lat and pop_after_lat.
//
// PR-2b.5DC (iter-307): the NON-POPPING DC register forms share these SIX
// conds — 0xDC mod=11 reg r has IDENTICAL operand routing / op / destination
// (ST(i)) as 0xDE mod=11 reg r, differing ONLY in that DC does NOT pop:
//   DC C0+i = FADD  ST(i), ST(0)   (reg=000, /0)  -> CMDEX_FADDP_STi_ST0,  no pop
//   DC C8+i = FMUL  ST(i), ST(0)   (reg=001, /1)  -> CMDEX_FMULP_STi_ST0,  no pop
//   DC E0+i = FSUBR ST(i), ST(0)   (reg=100, /4)  -> CMDEX_FSUBRP_STi_ST0, no pop
//   DC E8+i = FSUB  ST(i), ST(0)   (reg=101, /5)  -> CMDEX_FSUBP_STi_ST0,  no pop
//   DC F0+i = FDIVR ST(i), ST(0)   (reg=110, /6)  -> CMDEX_FDIVRP_STi_ST0, no pop
//   DC F8+i = FDIV  ST(i), ST(0)   (reg=111, /7)  -> CMDEX_FDIVP_STi_ST0,  no pop
// These were COMPLETELY UNDECODED before (silent no-op on AO486) — the
// Quake "8e8" root cause: DJGPP's Q_atof emits `fdiv st(1),st(0)` (DC F9)
// for decimal scaling.  CMD_fpu_arith's 4-bit cmdex namespace is FULL, so we
// reuse the DE pop-form cmdex and suppress the pop in execute_fpu via a
// decoded "DC arith reg-form" bit derived from the 0xDC opcode byte (see
// execute.v exe_fpu_arith_nopop + execute_fpu.v pop_after_now gate).
wire cond_154 = dec_ready_modregrm_one   && (decoder[7:0] == 8'hDE || decoder[7:0] == 8'hDC) && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd0;
wire cond_155 = dec_ready_modregrm_one   && (decoder[7:0] == 8'hDE || decoder[7:0] == 8'hDC) && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd1;
wire cond_156 = dec_ready_modregrm_one   && (decoder[7:0] == 8'hDE || decoder[7:0] == 8'hDC) && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd4;
wire cond_157 = dec_ready_modregrm_one   && (decoder[7:0] == 8'hDE || decoder[7:0] == 8'hDC) && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd5;
wire cond_158 = dec_ready_modregrm_one   && (decoder[7:0] == 8'hDE || decoder[7:0] == 8'hDC) && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd6;
wire cond_159 = dec_ready_modregrm_one   && (decoder[7:0] == 8'hDE || decoder[7:0] == 8'hDC) && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd7;

// PR-2b.3k: FXCH ST(i) = D9 C8+i.  Opcode 0xD9 + modrm with mod=11
// (reg-form) and reg=001 (/1).  rm carries the destination ST(i) index.
// Pure-control op (no math), swaps ST(0) ↔ ST(i).  Routed through
// CMD_fpu_arith / CMDEX_FXCH_STi; execute_fpu.v owns the FSM.
wire cond_160 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd1;

// PR-2b.3l: FLD ST(i) = D9 C0+i.  Opcode 0xD9 + modrm with mod=11
// (reg-form) and reg=000 (/0).  rm carries the source ST(i) index.
// Pure-control "push" op (no math): TOP-- and new ST(0) := old ST(i)
// (data+tag).  Routed through CMD_fpu_arith / CMDEX_FLD_STi;
// execute_fpu.v owns the FSM and the TOP write.
wire cond_161 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd0;

// PR-2b.3m: FST ST(i) = DD D0+i.  Opcode 0xDD + modrm with mod=11
// (reg-form) and reg=010 (/2).  rm carries the destination ST(i) index.
// Pure-control "store" op (no math): ST(i) := ST(0) (data+tag); TOP
// unchanged.  Routed through CMD_fpu_arith / CMDEX_FST_STi;
// execute_fpu.v owns the FSM (reuses dst_is_sti_lat for the abs_stsrc
// destination + is_fst_lat for the data/tag-source override).
// PR-2b.5FST (iter 310): the original cond matched 0xD9 (= FNOP/reserved
// reg-form space), so the REAL FST ST(i) at DD D0+i fell through cond_67
// to a SILENT NO-OP (decode-completeness audit, same class as the iter-307
// DC-regform gap).  FST ST(i) is the missing member of the DD reg-form
// family (FFREE=DD/0 cond_174, FSTP=DD/3 cond_163, FUCOM/FUCOMP=DD/4,5).
// Re-point to 0xDD; the CMDEX_FST_STi execute path is unchanged + already
// proven.  FNOP (D9 D0, cond_175) no longer overlaps so its `& ~cond_162`
// gate is now a harmless always-true.
wire cond_162 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDD && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd2;

// PR-2b.3m: FSTP ST(i) = DD D8+i.  Opcode 0xDD + modrm with mod=11
// (reg-form) and reg=011 (/3).  rm carries the destination ST(i) index.
// Pure-control "store-then-pop" op (no math): ST(i) := ST(0) (data+tag),
// then tag-clear at old ST(0) and TOP++.  Composes FST with the
// existing iter-34 pop_after_lat path (S_RETIRE → S_POP cleanup).
// Routed through CMD_fpu_arith / CMDEX_FSTP_STi.
wire cond_163 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDD && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd3;

// PR-2b.3n: FCHS = D9 E0.  Unique 2-byte opcode (no modrm sub-fields):
// the rm-byte is the whole opcode-extension.  Match the entire low 16 bits:
// decoder[7:0]=0xD9, decoder[15:8]=0xE0.
wire cond_164 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hE0;

// PR-2b.3n: FABS = D9 E1.
wire cond_165 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hE1;

// PR-2b.3n: FXAM = D9 E5.  First op to drive the CSR's cc lane (C0/C1/C2/C3).
wire cond_166 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hE5;

// PR-2b.3o (iter 46): FCOM ST(i)   = D8 D0+i (reg=3'd2, ordered  , no pop).
wire cond_167 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd2;
// PR-2b.3o: FCOMP ST(i)  = D8 D8+i (reg=3'd3, ordered  , pop).
wire cond_168 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd3;
// PR-2b.3o: FUCOM ST(i)  = DD E0+i (reg=3'd4, unordered, no pop).
wire cond_169 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDD && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd4;
// PR-2b.3o: FUCOMP ST(i) = DD E8+i (reg=3'd5, unordered, pop).
wire cond_170 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDD && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd5;

// PR-2b.3p (iter 47): FTST = D9 E4.  Unique 2-byte opcode like FCHS/FABS/FXAM —
// the rm-byte is the entire opcode-extension.  Compare ST(0) to +0.0 and
// set C0/C2/C3 in the cc lane (no regfile write).  Dispatched through
// CMD_fpu_unary + CMDEX_FTST; execute_fpu.v includes is_ftst in is_cmp_now
// so the cmp classifier engages with cmp_b_v overridden to 80'h0.
wire cond_171 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hE4;

// PR-2b.3q (iter 48): FCOMPP = DE D9.  Unique 2-byte opcode (modrm.rm=001
// happens to land src on ST(1), which is exactly what FCOMPP compares ST(0)
// against — no override needed; the existing FETCH path reads ST(1)
// naturally).  Pops ST(0) AND ST(1) after the compare — new pop_twice_lat
// + S_POP2 state in execute_fpu.v.  FCOM-class IE policy (any NaN raises).
wire cond_172 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDE && decoder[15:8] == 8'hD9;
// PR-2b.3q: FUCOMPP = DA E9.  Same shape as FCOMPP but FUCOM-class IE
// policy (QNaN silent, SNaN raises) — differentiated by is_fucom_lat.
wire cond_173 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:8] == 8'hE9;

// PR-2b.3r (iter 49): FFREE ST(i) = DD C0+i (modrm reg=000, mod=11).
// Tag-only write of Empty to ST(i); data preserved.  Dispatched via the
// new CMD_fpu_stack_ctrl namespace.
wire cond_174 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDD && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd0;

// PR-2b.3s (iter 50): three more stack-control ops in CMD_fpu_stack_ctrl.
// Each is a unique 2-byte opcode (D9 prefix + specific second byte).
//   FNOP    = D9 D0 — no-op
//   FDECSTP = D9 F6 — TOP -= 1
//   FINCSTP = D9 F7 — TOP += 1
wire cond_175 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hD0;
wire cond_176 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hF6;
wire cond_177 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hF7;

// PR-2b.3t (iter 51): FCMOVcc family.  Eight mod=11 mnemonics under two
// opcode bytes (DA = non-negated, DB = negated).  modrm.reg selects the
// condition source (B/E/BE/U); modrm.rm carries the source ST(i) index
// — same dispatch shape as cond_148 (FADD ST0,ST(i)).
wire cond_178 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd0; // FCMOVB
wire cond_179 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd1; // FCMOVE
wire cond_180 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd2; // FCMOVBE
wire cond_181 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd3; // FCMOVU
wire cond_182 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd0; // FCMOVNB
wire cond_183 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd1; // FCMOVNE
wire cond_184 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd2; // FCMOVNBE
wire cond_185 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd3; // FCMOVNU
// PR-2b.3u (iter 52): FCOMI / FUCOMI / FCOMIP / FUCOMIP — P6 cmp variants that write integer EFLAGS.
wire cond_186 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd6; // FCOMI    DB F0+i
wire cond_187 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd5; // FUCOMI   DB E8+i
wire cond_188 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDF && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd6; // FCOMIP   DF F0+i
wire cond_189 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDF && decoder[15:14] == 2'b11 && decoder[13:11] == 3'd5; // FUCOMIP  DF E8+i
// PR-2b.4d (iter 55): first mem-form FPU arith — FADD m32fp (D8 /0, mod!=11)
// and FADD m64fp (DC /0, mod!=11).  Both dispatched via the new
// CMD_fpu_arith_mem CMD code (7'd123) so execute_fpu can derive
// is_mem_form_lat directly from cmd, without needing a new decoder lane.
// mod!=11 is the canonical mem-form encoding; cond_148 (D8 /0 mod=11)
// already shadows the reg-form variant for the unit-TB elab path.  At
// runtime the cond_67 catch-all still wins in the dispatch cascade (known
// decoder priority quirk shared across cond_148..189); the unit TB drives
// execute_fpu signals directly, so the cond_190/191 additions are
// elab-clean shadows of the eventual runtime dispatch.
wire cond_190 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd0; // FADD m32fp
wire cond_191 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDC && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd0; // FADD m64fp
// PR-2b.4e (iter 56): mem-form FMUL/FSUB/FDIV non-reverse arms.  Same cond_67
// runtime-priority caveat applies — these are elab-clean shadows; reg-form
// unit TBs bypass the decoder via tb_issue_arith_mem.
wire cond_192 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd1; // FMUL m32fp
wire cond_193 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDC && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd1; // FMUL m64fp
wire cond_194 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd4; // FSUB m32fp
wire cond_195 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDC && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd4; // FSUB m64fp
wire cond_196 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd6; // FDIV m32fp
wire cond_197 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDC && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd6; // FDIV m64fp
// PR-2b.4f (iter 57): mem-form FSUBR/FDIVR reverse arms.  Same cond_67 runtime-
// priority caveat as iter 55+56 — these are elab-clean shadows; reg-form unit
// TBs bypass the decoder via tb_issue_arith_mem.  Completes the D8/DC mem-form
// arith decode space: /0 FADD, /1 FMUL, /4 FSUB, /5 FSUBR, /6 FDIV, /7 FDIVR.
wire cond_198 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd5; // FSUBR m32fp
wire cond_199 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDC && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd5; // FSUBR m64fp
wire cond_200 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd7; // FDIVR m32fp
wire cond_201 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDC && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd7; // FDIVR m64fp
// PR-2b.4g (iter 58): mem-form FCOM/FCOMP.  Same cond_67 runtime-priority caveat
// as iters 55/56/57.  Completes the D8/DC mem-form modrm.reg decode space.
wire cond_202 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd2; // FCOM  m32fp
wire cond_203 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDC && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd2; // FCOM  m64fp
wire cond_204 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD8 && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd3; // FCOMP m32fp
wire cond_205 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDC && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd3; // FCOMP m64fp

// PR-2b.4k (iter 75) — FLD m32fp (D9 /0 mod!=11) and FLD m64fp (DD /0 mod!=11).
// Mem-form load to FPU stack; extends the D9 family beyond FNSTCW M16
// (cond_147 = D9 /7 mem) and the D8/DC mem-form arith (cond_190..205).
// Destination is implicit ST(new TOP) after TOP-- (push semantics).
wire cond_206 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd0; // FLD m32fp
wire cond_207 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDD && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd0; // FLD m64fp
// PR-2b.4n (iter 112): FPU constant loads (D9 E8..EE), full-byte opcodes
// like FCHS (cond_164).  Each pushes a hardcoded 80-bit constant.
wire cond_208 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hE8; // FLD1
wire cond_209 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hE9; // FLDL2T
wire cond_210 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hEA; // FLDL2E
wire cond_211 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hEB; // FLDPI
wire cond_212 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hEC; // FLDLG2
wire cond_213 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hED; // FLDLN2
wire cond_214 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hEE; // FLDZ
// PR-2b.5a (iter 113): FSTP m80fp = DB /7 mem-form (mod != 11).  Same byte
// layout as FNSTCW cond_147 (opcode in decoder[7:0], modrm in decoder[15:8],
// reg field in decoder[13:11]).  Dispatched above cond_67 like the other
// mem-form FPU ops so it wins before the legacy CMD_fpu stub.
wire cond_215 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[13:11] == 3'b111 && decoder[15:14] != 2'b11; // FSTP m80fp
wire cond_216 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[13:11] == 3'b011 && decoder[15:14] != 2'b11; // FSTP m32fp (D9 /3)
wire cond_217 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDD && decoder[13:11] == 3'b011 && decoder[15:14] != 2'b11; // FSTP m64fp (DD /3)
// PR-2b.5e (iter 118): FST m32fp (D9 /2) / FST m64fp (DD /2) — NO-POP store
// variants.  Identical byte layout to FSTP except reg-field == 3'b010 (/2).
// Same CMD_fpu_store_mem dispatch + narrowing converters + write FSM as FSTP;
// the no-pop semantic is carried in execute_fpu (is_fst_m32/m64 NOT added to
// pop_after_now), so ST(0) is retained after the store.
wire cond_218 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[13:11] == 3'b010 && decoder[15:14] != 2'b11; // FST m32fp (D9 /2)
wire cond_219 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDD && decoder[13:11] == 3'b010 && decoder[15:14] != 2'b11; // FST m64fp (DD /2)
// PR-2b.5g (iter 124): FLD m80fp = DB /5 mem-form (mod != 11).  DB /5 reg-form
// is FUCOMI (cond_187, gated mod==11), so the mem-form is free.  Routes to
// CMD_fpu_load_mem / CMDEX_FLD_M80 — the raw 80-bit load twin of FSTP m80.
wire cond_220 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[13:11] == 3'b101 && decoder[15:14] != 2'b11; // FLD m80fp (DB /5)
// PR-2b.5n (iter 127): FRNDINT = D9 FC (reg-form, full ModRM byte).  Same
// dispatch family as FCHS (cond_164, D9 E0): CMD_fpu_unary / CMDEX_FRNDINT,
// consumes the ModRM byte, no source operand beyond ST(0).
wire cond_221 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hFC; // FRNDINT (D9 FC)
// PR-2b.5o (iter 129): FLDCW m16 = D9 /5 mem-form (mod != 11).  The inbound
// twin of FNSTCW (cond_147 = D9 /7 mem-form): same byte layout (opcode in
// decoder[7:0], modrm in decoder[15:8], reg field decoder[13:11], mod
// decoder[15:14]).  D9 /5 reg-form is the FLDxxx constant family (cond_208..
// 214, gated on full-byte decoder[15:8]==E8..EE), so the mem-form is free.
// Routes to CMD_fpu / CMDEX_FLDCW_M16 — handled at execute.v, not execute_fpu.
wire cond_222 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[13:11] == 3'b101 && decoder[15:14] != 2'b11; // FLDCW m16 (D9 /5)
// PR-2b.5p (iter 130): FSCALE = D9 FD (reg-form, full ModRM byte).  Same
// dispatch family as FRNDINT (cond_221, D9 FC): CMD_fpu_unary / CMDEX_FSCALE,
// consumes the ModRM byte; reads ST(0) and ST(1) inside execute_fpu.
wire cond_223 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hFD; // FSCALE (D9 FD)
// PR-2b.5q (iter 131): FXTRACT = D9 F4 (reg-form, full ModRM byte).  Same
// dispatch family as FRNDINT/FSCALE (CMD_fpu_unary / CMDEX_FXTRACT), consumes
// the ModRM byte; reads ST(0), writes ST(0)+ST(1) and pushes inside execute_fpu.
wire cond_224 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hF4; // FXTRACT (D9 F4)
// PR-2b.5r (iter 135): FPREM = D9 F8 / FPREM1 = D9 F5 (reg-form, full ModRM byte).
// Same dispatch family as FSCALE (cond_223): CMD_fpu_unary / CMDEX_FPREM(1),
// consumes the ModRM byte; reads ST(0) and ST(1) inside execute_fpu (src_lat=1).
wire cond_225 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hF8; // FPREM  (D9 F8)
wire cond_226 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hF5; // FPREM1 (D9 F5)
// PR-2b.5t (iter 137): FSQRT = D9 FA (reg-form, full ModRM byte).  Same dispatch
// family as FRNDINT (cond_221, D9 FC): CMD_fpu_unary / CMDEX_FSQRT, consumes the
// ModRM byte, single source ST(0) (no src_lat override inside execute_fpu).
wire cond_227 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hFA; // FSQRT  (D9 FA)
// PR-2c.T (iter 185+): x87 TRANSCENDENTAL group — all 2-byte, prefix D9,
// reg-form (full ModRM byte: opcode decoder[7:0], 2nd byte decoder[15:8]).
// Dispatched to the NEW CMD_fpu_transcendental code (each with its own CMDEX)
// and placed ABOVE cond_67 in every cascade so they win over the legacy
// no-op catch-all.  Single-source ops (F2XM1/FSIN/FCOS/FSINCOS) take ST(0);
// two-source ops (FYL2X/FPATAN/FYL2XP1) force src_lat=1 in execute_fpu.
// See research/design_transcendentals.md.
wire cond_238 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hF0; // F2XM1   (D9 F0)
wire cond_239 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hF1; // FYL2X   (D9 F1)
wire cond_240 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hF2; // FPTAN   (D9 F2)
wire cond_241 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hF3; // FPATAN  (D9 F3)
wire cond_242 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hF9; // FYL2XP1 (D9 F9)
wire cond_243 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hFE; // FSIN    (D9 FE)
wire cond_244 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hFF; // FCOS    (D9 FF)
wire cond_245 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[15:8] == 8'hFB; // FSINCOS (D9 FB)
// PR-2b.5v (iter 140): FILD m32 (DB /0), FILD m16 (DF /0), FILD m64 (DF /5) —
// signed-integer memory loads, mem-form (mod != 11).  Same byte layout as the
// FLD m32/m64 mem-form loads (cond_206/207): opcode in decoder[7:0], modrm in
// decoder[15:8], reg field decoder[13:11], mod decoder[15:14].  DB reg-form /0
// is undefined and DF reg-form is FFREEP/FUCOMIP/FCOMIP (gated mod==11), so the
// mem-forms are free.  All dispatch to CMD_fpu_load_mem; CMDEX selects width.
wire cond_228 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[13:11] == 3'b000 && decoder[15:14] != 2'b11; // FILD m32 (DB /0)
wire cond_229 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDF && decoder[13:11] == 3'b000 && decoder[15:14] != 2'b11; // FILD m16 (DF /0)
wire cond_230 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDF && decoder[13:11] == 3'b101 && decoder[15:14] != 2'b11; // FILD m64 (DF /5)
// PR-2b.5w (iter 141): FIST/FISTP m16/m32/m64 — signed-integer memory STORES,
// mem-form (mod != 11).  Dispatch to CMD_fpu_store_mem (same store FSM as the
// float stores); CMDEX selects width + pop.  reg-field decoder[13:11] selects
// the variant: /2=FIST, /3=FISTP, /7=FISTP m64.  DB and DF opcodes already host
// FILD (cond_228..230); these are the disjoint reg-field cases.
wire cond_231 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[13:11] == 3'b010 && decoder[15:14] != 2'b11; // FIST  m32 (DB /2)
wire cond_232 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDB && decoder[13:11] == 3'b011 && decoder[15:14] != 2'b11; // FISTP m32 (DB /3)
wire cond_233 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDF && decoder[13:11] == 3'b010 && decoder[15:14] != 2'b11; // FIST  m16 (DF /2)
wire cond_234 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDF && decoder[13:11] == 3'b011 && decoder[15:14] != 2'b11; // FISTP m16 (DF /3)
wire cond_235 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDF && decoder[13:11] == 3'b111 && decoder[15:14] != 2'b11; // FISTP m64 (DF /7)
// PR-2b.5z (iter 152): FBLD m80 (DF /4) + FBSTP m80 (DF /6) — packed-BCD load
// and store, mem-form (mod != 11).  Same DF-group byte layout as FILD m16/FISTP
// (opcode in decoder[7:0], modrm in decoder[15:8], reg field decoder[13:11], mod
// decoder[15:14]).  reg-field /4 = FBLD -> CMD_fpu_load_mem, /6 = FBSTP ->
// CMD_fpu_store_mem.  DF reg-form /4 and /6 are undefined, so the mem-forms are
// free.  The 80-bit read/write reuse the FLD m80 / FSTP m80 multi-beat FSMs.
wire cond_236 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDF && decoder[13:11] == 3'b100 && decoder[15:14] != 2'b11; // FBLD  m80 (DF /4)
wire cond_237 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDF && decoder[13:11] == 3'b110 && decoder[15:14] != 2'b11; // FBSTP m80 (DF /6)
// PR-2c.ENV (iter 210+): x87 env save/restore mem-form ops (D9/DD /4,/6) — the
// iter-207 freeze fix.  Same byte layout as FNSTCW (cond_147, D9 /7 mem): opcode
// in decoder[7:0], modrm decoder[15:8], reg field decoder[13:11], mod
// decoder[15:14].  Without these arms the decoder can't length the opcode
// (consume=0 -> dec_acceptable=0 -> dec_gp_fault -> #GP storm = the freeze).
// cond_247 (FNSTENV) lands FIRST with its 14-byte store datapath; the load arm
// (FLDENV) + the 94-byte FNSAVE/FRSTOR follow.  See research/design_envsave.md.
wire cond_247 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[13:11] == 3'b110 && decoder[15:14] != 2'b11; // FNSTENV (D9 /6)
wire cond_246 = dec_ready_modregrm_one   && decoder[7:0] == 8'hD9 && decoder[13:11] == 3'b100 && decoder[15:14] != 2'b11; // FLDENV  (D9 /4)
// iter-213: env-only first cut of the 94-byte pair (DD /4,/6).  FNSAVE reuses the
// FNSTENV 14-byte store + re-inits; FRSTOR reuses the FLDENV qword load.  The
// 80-byte ST area is a documented later correctness slice.
wire cond_249 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDD && decoder[13:11] == 3'b110 && decoder[15:14] != 2'b11; // FNSAVE  (DD /6)
wire cond_248 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDD && decoder[13:11] == 3'b100 && decoder[15:14] != 2'b11; // FRSTOR  (DD /4)
// PR-2b.5Y (iter 236): x87 integer-arith MEMORY forms — the last structural hole
// in x87 mem-form decode (audit_fpu_mem_form_twins.md).  DA /0../7 (m32int) and
// DE /0../7 (m16int): FIADD/FIMUL/FICOM/FICOMP/FISUB/FISUBR/FIDIV/FIDIVR.  They
// REUSE CMD_fpu_arith_mem + the existing FADD/FMUL/.../FCOM/FCOMP CMDEX values
// (op selection is identical; the only differences are (a) the memory operand is
// a signed integer → routed through int_to_floatx80 in execute_fpu, keyed off the
// DA/DE opcode there, and (b) the fetch width).  DA → the _M32 (even) CMDEX slot,
// DE → the _M64 (odd) CMDEX slot, so mem_fmt_now[0] (==rd_cmdex[0]) carries the
// DA(0)=m32int / DE(1)=m16int width to execute_fpu's int converter.  read_commands
// overrides the m16int (DE) fetch to a WORD (cond_264 would otherwise read qword).
wire cond_251 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd0; // FIADD  m32int
wire cond_252 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDE && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd0; // FIADD  m16int
wire cond_253 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd1; // FIMUL  m32int
wire cond_254 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDE && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd1; // FIMUL  m16int
wire cond_255 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd2; // FICOM  m32int
wire cond_256 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDE && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd2; // FICOM  m16int
wire cond_257 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd3; // FICOMP m32int
wire cond_258 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDE && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd3; // FICOMP m16int
wire cond_259 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd4; // FISUB  m32int
wire cond_260 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDE && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd4; // FISUB  m16int
wire cond_261 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd5; // FISUBR m32int
wire cond_262 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDE && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd5; // FISUBR m16int
wire cond_263 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd6; // FIDIV  m32int
wire cond_264 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDE && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd6; // FIDIV  m16int
wire cond_265 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDA && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd7; // FIDIVR m32int
wire cond_266 = dec_ready_modregrm_one   && decoder[7:0] == 8'hDE && decoder[15:14] != 2'b11 && decoder[13:11] == 3'd7; // FIDIVR m16int
//======================================================== saves
//======================================================== always
//======================================================== sets
assign consume_mem_offset =
    (cond_116 && ~cond_4)? (`TRUE) :
    1'd0;
// ===== PR-2c.DECFIX (iter 206): x87 dispatch one-hot collapse =====
// The ~100 mutually-exclusive FPU decode arms below were a serial priority
// cascade that dominated the decode->microcode (mc_eip/mc_consumed) setup path
// and pushed clk_sys 90 MHz WSS to -12.2 ns.  They are pairwise-disjoint over
// every (D8..DF x modrm) input (exhaustively verified), so the cascade is
// rewritten as a single balanced ONE-HOT select.  SOLE overlap D9 D0
// (cond_162 FST_STi vs cond_175 FNOP) keeps original priority via & ~cond_162.
// cond_67 (reg-form ESC catch-all) stays BELOW the group, unchanged.
wire fpu_cmd_hit = cond_144 | cond_145 | cond_146 | cond_147 | cond_222 | cond_148 | cond_149 | cond_150 | cond_151 | cond_152 | cond_153 | cond_154 | cond_155 | cond_156 | cond_157 | cond_158 | cond_159 | cond_160 | cond_161 | cond_162 | cond_163 | cond_164 | cond_221 | cond_223 | cond_224 | cond_225 | cond_226 | cond_227 | cond_238 | cond_239 | cond_240 | cond_241 | cond_242 | cond_243 | cond_244 | cond_245 | cond_165 | cond_166 | cond_167 | cond_168 | cond_169 | cond_170 | cond_171 | cond_172 | cond_173 | cond_174 | cond_175 | cond_176 | cond_177 | cond_178 | cond_179 | cond_180 | cond_181 | cond_182 | cond_183 | cond_184 | cond_185 | cond_186 | cond_187 | cond_188 | cond_189 | cond_190 | cond_191 | cond_192 | cond_193 | cond_194 | cond_195 | cond_196 | cond_197 | cond_198 | cond_199 | cond_200 | cond_201 | cond_202 | cond_203 | cond_204 | cond_205 | cond_206 | cond_207 | cond_220 | cond_228 | cond_229 | cond_230 | cond_236 | cond_208 | cond_209 | cond_210 | cond_211 | cond_212 | cond_213 | cond_214 | cond_215 | cond_216 | cond_217 | cond_218 | cond_219 | cond_231 | cond_232 | cond_233 | cond_234 | cond_235 | cond_237 | cond_247 | cond_246 | cond_249 | cond_248 | cond_250 | cond_251 | cond_252 | cond_253 | cond_254 | cond_255 | cond_256 | cond_257 | cond_258 | cond_259 | cond_260 | cond_261 | cond_262 | cond_263 | cond_264 | cond_265 | cond_266;
wire [6:0] fpu_cmd_val =
    ({7{cond_144}} & (`CMD_fpu))
  |     ({7{cond_145}} & (`CMD_fpu))
  |     ({7{cond_146}} & (`CMD_fpu))
  |     ({7{cond_147}} & (`CMD_fpu))
  |     ({7{cond_250}} & (`CMD_fpu))            // iter-229: FNSTSW m16 (DD /7)
  |     ({7{cond_247}} & (`CMD_fpu_store_mem))  // FNSTENV — reuses the store FSM
  |     ({7{cond_246}} & (`CMD_fpu_load_mem))   // FLDENV  — reuses the load read path
  |     ({7{cond_249}} & (`CMD_fpu_store_mem))  // FNSAVE  — reuses the store FSM + re-init
  |     ({7{cond_248}} & (`CMD_fpu_load_mem))   // FRSTOR  — reuses the load read path
  |     ({7{cond_222}} & (`CMD_fpu))
  |     ({7{cond_148}} & (`CMD_fpu_arith))
  |     ({7{cond_149}} & (`CMD_fpu_arith))
  |     ({7{cond_150}} & (`CMD_fpu_arith))
  |     ({7{cond_151}} & (`CMD_fpu_arith))
  |     ({7{cond_152}} & (`CMD_fpu_arith))
  |     ({7{cond_153}} & (`CMD_fpu_arith))
  |     ({7{cond_154}} & (`CMD_fpu_arith))
  |     ({7{cond_155}} & (`CMD_fpu_arith))
  |     ({7{cond_156}} & (`CMD_fpu_arith))
  |     ({7{cond_157}} & (`CMD_fpu_arith))
  |     ({7{cond_158}} & (`CMD_fpu_arith))
  |     ({7{cond_159}} & (`CMD_fpu_arith))
  |     ({7{cond_160}} & (`CMD_fpu_arith))
  |     ({7{cond_161}} & (`CMD_fpu_arith))
  |     ({7{cond_162}} & (`CMD_fpu_arith))
  |     ({7{cond_163}} & (`CMD_fpu_arith))
  |     ({7{cond_164}} & (`CMD_fpu_unary))
  |     ({7{cond_221}} & (`CMD_fpu_unary))
  |     ({7{cond_223}} & (`CMD_fpu_unary))
  |     ({7{cond_224}} & (`CMD_fpu_unary))
  |     ({7{cond_225}} & (`CMD_fpu_unary))
  |     ({7{cond_226}} & (`CMD_fpu_unary))
  |     ({7{cond_227}} & (`CMD_fpu_unary))
  |     ({7{cond_238}} & (`CMD_fpu_transcendental))
  |     ({7{cond_239}} & (`CMD_fpu_transcendental))
  |     ({7{cond_240}} & (`CMD_fpu_transcendental))
  |     ({7{cond_241}} & (`CMD_fpu_transcendental))
  |     ({7{cond_242}} & (`CMD_fpu_transcendental))
  |     ({7{cond_243}} & (`CMD_fpu_transcendental))
  |     ({7{cond_244}} & (`CMD_fpu_transcendental))
  |     ({7{cond_245}} & (`CMD_fpu_transcendental))
  |     ({7{cond_165}} & (`CMD_fpu_unary))
  |     ({7{cond_166}} & (`CMD_fpu_unary))
  |     ({7{cond_167}} & (`CMD_fpu_cmp))
  |     ({7{cond_168}} & (`CMD_fpu_cmp))
  |     ({7{cond_169}} & (`CMD_fpu_cmp))
  |     ({7{cond_170}} & (`CMD_fpu_cmp))
  |     ({7{cond_171}} & (`CMD_fpu_unary))
  |     ({7{cond_172}} & (`CMD_fpu_cmp))
  |     ({7{cond_173}} & (`CMD_fpu_cmp))
  |     ({7{cond_174}} & (`CMD_fpu_stack_ctrl))
  |     ({7{cond_175 & ~cond_162}} & (`CMD_fpu_stack_ctrl))
  |     ({7{cond_176}} & (`CMD_fpu_stack_ctrl))
  |     ({7{cond_177}} & (`CMD_fpu_stack_ctrl))
  |     ({7{cond_178}} & (`CMD_fpu_cmov))
  |     ({7{cond_179}} & (`CMD_fpu_cmov))
  |     ({7{cond_180}} & (`CMD_fpu_cmov))
  |     ({7{cond_181}} & (`CMD_fpu_cmov))
  |     ({7{cond_182}} & (`CMD_fpu_cmov))
  |     ({7{cond_183}} & (`CMD_fpu_cmov))
  |     ({7{cond_184}} & (`CMD_fpu_cmov))
  |     ({7{cond_185}} & (`CMD_fpu_cmov))
  |     ({7{cond_186}} & (`CMD_fpu_cmp))
  |     ({7{cond_187}} & (`CMD_fpu_cmp))
  |     ({7{cond_188}} & (`CMD_fpu_cmp))
  |     ({7{cond_189}} & (`CMD_fpu_cmp))
  |     ({7{cond_190}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_191}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_192}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_193}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_194}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_195}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_196}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_197}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_198}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_199}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_200}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_201}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_202}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_203}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_204}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_205}} & (`CMD_fpu_arith_mem))
  |     ({7{cond_251}} & (`CMD_fpu_arith_mem))   // FIADD  m32int (DA /0)
  |     ({7{cond_252}} & (`CMD_fpu_arith_mem))   // FIADD  m16int (DE /0)
  |     ({7{cond_253}} & (`CMD_fpu_arith_mem))   // FIMUL  m32int (DA /1)
  |     ({7{cond_254}} & (`CMD_fpu_arith_mem))   // FIMUL  m16int (DE /1)
  |     ({7{cond_255}} & (`CMD_fpu_arith_mem))   // FICOM  m32int (DA /2)
  |     ({7{cond_256}} & (`CMD_fpu_arith_mem))   // FICOM  m16int (DE /2)
  |     ({7{cond_257}} & (`CMD_fpu_arith_mem))   // FICOMP m32int (DA /3)
  |     ({7{cond_258}} & (`CMD_fpu_arith_mem))   // FICOMP m16int (DE /3)
  |     ({7{cond_259}} & (`CMD_fpu_arith_mem))   // FISUB  m32int (DA /4)
  |     ({7{cond_260}} & (`CMD_fpu_arith_mem))   // FISUB  m16int (DE /4)
  |     ({7{cond_261}} & (`CMD_fpu_arith_mem))   // FISUBR m32int (DA /5)
  |     ({7{cond_262}} & (`CMD_fpu_arith_mem))   // FISUBR m16int (DE /5)
  |     ({7{cond_263}} & (`CMD_fpu_arith_mem))   // FIDIV  m32int (DA /6)
  |     ({7{cond_264}} & (`CMD_fpu_arith_mem))   // FIDIV  m16int (DE /6)
  |     ({7{cond_265}} & (`CMD_fpu_arith_mem))   // FIDIVR m32int (DA /7)
  |     ({7{cond_266}} & (`CMD_fpu_arith_mem))   // FIDIVR m16int (DE /7)
  |     ({7{cond_206}} & (`CMD_fpu_load_mem))
  |     ({7{cond_207}} & (`CMD_fpu_load_mem))
  |     ({7{cond_220}} & (`CMD_fpu_load_mem))
  |     ({7{cond_228}} & (`CMD_fpu_load_mem))
  |     ({7{cond_229}} & (`CMD_fpu_load_mem))
  |     ({7{cond_230}} & (`CMD_fpu_load_mem))
  |     ({7{cond_236}} & (`CMD_fpu_load_mem))
  |     ({7{cond_208}} & (`CMD_fpu_const))
  |     ({7{cond_209}} & (`CMD_fpu_const))
  |     ({7{cond_210}} & (`CMD_fpu_const))
  |     ({7{cond_211}} & (`CMD_fpu_const))
  |     ({7{cond_212}} & (`CMD_fpu_const))
  |     ({7{cond_213}} & (`CMD_fpu_const))
  |     ({7{cond_214}} & (`CMD_fpu_const))
  |     ({7{cond_215}} & (`CMD_fpu_store_mem))
  |     ({7{cond_216}} & (`CMD_fpu_store_mem))
  |     ({7{cond_217}} & (`CMD_fpu_store_mem))
  |     ({7{cond_218}} & (`CMD_fpu_store_mem))
  |     ({7{cond_219}} & (`CMD_fpu_store_mem))
  |     ({7{cond_231}} & (`CMD_fpu_store_mem))
  |     ({7{cond_232}} & (`CMD_fpu_store_mem))
  |     ({7{cond_233}} & (`CMD_fpu_store_mem))
  |     ({7{cond_234}} & (`CMD_fpu_store_mem))
  |     ({7{cond_235}} & (`CMD_fpu_store_mem))
  |     ({7{cond_237}} & (`CMD_fpu_store_mem));

assign dec_cmd =
    (cond_0 && ~cond_1)? ( `CMD_XADD) :
    (cond_3 && ~cond_4)? ( `CMD_JCXZ) :
    (cond_5 && ~cond_4)? ( `CMD_CALL) :
    (cond_7 && ~cond_8)? ( `CMD_CALL) :
    (cond_10 && ~cond_4)? ( `CMD_PUSH_MOV_SEG) :
    (cond_11 && ~cond_12)? ( `CMD_PUSH_MOV_SEG) :
    (cond_13 && ~cond_14)? ( `CMD_PUSH_MOV_SEG) :
    (cond_15 && ~cond_14)? ( `CMD_PUSH_MOV_SEG) :
    (cond_16 && ~cond_1)? ( `CMD_NEG) :
    (cond_17 && ~cond_4)? ( `CMD_Jcc) :
    (cond_20 && ~cond_4)? ( `CMD_INVD) :
    (cond_21 && ~cond_22)? ( `CMD_INVLPG) :
    (cond_23 && ~cond_4)? ( `CMD_HLT) :
    (cond_24 && ~cond_4)? ( `CMD_SCAS) :
    (cond_26 && ~cond_4)? ( `CMD_INC_DEC) :
    (cond_27 && ~cond_1)? ( `CMD_INC_DEC) :
    (cond_28 && ~cond_4)? ( `CMD_RET_near) :
    (cond_29 && ~cond_14)? ( `CMD_ARPL) :
    (cond_30 && ~cond_4)? ( `CMD_BSWAP) :
    (cond_31 && ~cond_22)? ( `CMD_LxS) :
    (cond_32 && ~cond_33)? ( `CMD_MOV_to_seg) :
    (cond_34 && ~cond_14)? ( `CMD_LLDT) :
    (cond_35 && ~cond_14)? ( `CMD_LTR) :
    (cond_36 && ~cond_4)? ( `CMD_CLC) :
    (cond_37 && ~cond_4)? ( `CMD_CLD) :
    (cond_38 && ~cond_4)? ( `CMD_CMC) :
    (cond_39 && ~cond_4)? ( `CMD_STC) :
    (cond_40 && ~cond_4)? ( `CMD_STD) :
    (cond_41 && ~cond_4)? ( `CMD_SAHF) :
    (cond_42 && ~cond_4)? ( `CMD_AAD) :
    (cond_43 && ~cond_4)? ( `CMD_AAM) :
    (cond_44 && ~cond_4)? ( `CMD_POP_seg) :
    (cond_45 && ~cond_4)? ( `CMD_BT) :
    (cond_46 && ~cond_1)? ( `CMD_BTR) :
    (cond_47 && ~cond_1)? ( `CMD_BTS) :
    (cond_48 && ~cond_1)? ( `CMD_BTC) :
    (cond_49 && ~cond_4)? ( `CMD_IRET) :
    (cond_51 && ~cond_4)? ( `CMD_POP) :
    (cond_52 && ~cond_4)? ( `CMD_POP) :
    (cond_53 && ~cond_4)? ( `CMD_DIV) :
    (cond_54 && ~cond_4)? ( `CMD_IDIV) :
    (cond_55 && ~cond_4)? ( `CMD_Shift) :
    (cond_57 && ~cond_4)? ( `CMD_Shift) :
    (cond_58 && ~cond_4)? ( `CMD_CMPS) :
    (cond_59 && ~cond_4)? ( `CMD_control_reg) :
    (cond_60 && ~cond_4)? ( `CMD_control_reg) :
    (cond_61 && ~cond_62)? ( `CMD_control_reg) :
    (cond_63 && ~cond_22)? ( `CMD_LGDT) :
    (cond_64 && ~cond_22)? ( `CMD_LIDT) :
    (cond_65 && ~cond_4)? ( `CMD_PUSHA) :
    (cond_66 && ~cond_4)? ( `CMD_fpu) :
    // PR-2b.4i (iter 60): cond_67 reg-form catch-all moved BELOW the
    // PR-1a / PR-2b cond_144..205 arms so the more-specific decode
    // wins.  See the cascade tail after cond_205 below.
    (fpu_cmd_hit && ~cond_4)? ( fpu_cmd_val ) :
    // PR-2b.4i (iter 60): cond_67 reg-form catch-all relocated here, BELOW
    // cond_144..205, so reg-form D8..DF + modregrm_one falls back to the
    // legacy CMD_fpu / CMDEX_ESC_STEP_0 stub ONLY when no more-specific
    // PR-1a / PR-2b cond catches the opcode first.  Unblocks runtime
    // dispatch for every reg-form PR-2b op (cond_148..189) + PR-1a
    // FNINIT/FNCLEX/FNSTSW AX (cond_144..146) — those previously won
    // their dispatch arms inside cond_67's shadow at line 404 and now
    // get their proper CMDEX values.  Reg-form D8..DF opcodes NOT
    // covered by any cond_144..205 still fall through to the legacy
    // stub here (no functional regression for un-implemented ops).
    (cond_67 && ~cond_4)? ( `CMD_fpu) :
    (cond_68 && ~cond_4)? ( `CMD_SETcc) :
    (cond_69 && ~cond_1)? ( `CMD_CMPXCHG) :
    (cond_70 && ~cond_4)? ( `CMD_ENTER) :
    (cond_71 && ~cond_4)? ( `CMD_IMUL) :
    (cond_72 && ~cond_4)? ( `CMD_IMUL) :
    (cond_73 && ~cond_4)? ( `CMD_LEAVE) :
    (cond_74 && ~cond_4)? ( `CMD_SHLD) :
    (cond_76 && ~cond_4)? ( `CMD_SHRD) :
    (cond_77 && ~cond_4)? ( `CMD_WBINVD) :
    (cond_78 && ~cond_4)? ( {`CMD_Arith | { 4'd0, decoder[5:3] } }) :
    (cond_79 && ~cond_80)? ( {`CMD_Arith | { 4'd0, decoder[5:3] } }) :
    (cond_81 && ~cond_82)? ( {`CMD_Arith | { 4'd0, decoder[13:11] } }) :
    (cond_83 && ~cond_4)? ( `CMD_MUL) :
    (cond_84 && ~cond_4)? ( `CMD_LOOP) :
    (cond_85 && ~cond_4)? ( `CMD_TEST) :
    (cond_86 && ~cond_4)? ( `CMD_TEST) :
    (cond_87 && ~cond_4)? ( `CMD_TEST) :
    (cond_88 && ~cond_4)? ( `CMD_CLTS) :
    (cond_89 && ~cond_4)? ( `CMD_RET_far) :
    (cond_90 && ~cond_4)? ( `CMD_LODS) :
    (cond_91 && ~cond_4)? ( `CMD_XCHG) :
    (cond_92 && ~cond_1)? ( `CMD_XCHG) :
    (cond_93 && ~cond_4)? ( `CMD_PUSH) :
    (cond_94 && ~cond_4)? ( `CMD_PUSH) :
    (cond_95 && ~cond_4)? ( `CMD_PUSH) :
    (cond_96 && ~cond_4)? ( `CMD_INT_INTO) :
    (cond_98 && ~cond_4)? ( `CMD_CPUID) :
    (cond_99 && ~cond_4)? ( `CMD_IN) :
    (cond_102 && ~cond_1)? ( `CMD_NOT) :
    (cond_103 && ~cond_14)? ( `CMD_VERR) :
    (cond_104 && ~cond_14)? ( `CMD_VERW) :
    (cond_105 && ~cond_14)? ( `CMD_LAR) :
    (cond_106 && ~cond_14)? ( `CMD_LSL) :
    (cond_107 && ~cond_4)? ( `CMD_STOS) :
    (cond_108 && ~cond_4)? ( `CMD_INS) :
    (cond_109 && ~cond_4)? ( `CMD_OUTS) :
    (cond_110 && ~cond_4)? ( `CMD_PUSHF) :
    (cond_111 && ~cond_4)? ( `CMD_JMP) :
    (cond_113 && ~cond_114)? ( `CMD_JMP) :
    (cond_115 && ~cond_4)? ( `CMD_OUT) :
    (cond_116 && ~cond_4)? ( `CMD_MOV) :
    (cond_117 && ~cond_4)? ( `CMD_MOV) :
    (cond_119 && ~cond_4)? ( `CMD_MOV) :
    (cond_120 && ~cond_4)? ( `CMD_MOV) :
    (cond_121 && ~cond_4)? ( `CMD_LAHF) :
    (cond_122 && ~cond_4)? ( `CMD_CBW) :
    (cond_123 && ~cond_4)? ( `CMD_CWD) :
    (cond_124 && ~cond_4)? ( `CMD_POPF) :
    (cond_125 && ~cond_4)? ( `CMD_CLI) :
    (cond_126 && ~cond_4)? ( `CMD_STI) :
    (cond_127 && ~cond_22)? ( `CMD_BOUND) :
    (cond_128 && ~cond_4)? ( `CMD_SALC) :
    (cond_129 && ~cond_22)? ( `CMD_LEA) :
    (cond_130 && ~cond_22)? ( `CMD_SGDT) :
    (cond_131 && ~cond_22)? ( `CMD_SIDT) :
    (cond_132 && ~cond_4)? ( `CMD_MOVS) :
    (cond_133 && ~cond_4)? ( `CMD_MOVZX) :
    (cond_134 && ~cond_4)? ( `CMD_MOVSX) :
    (cond_135 && ~cond_4)? ( `CMD_POPA) :
    (cond_136 && ~cond_4)? ( `CMD_debug_reg) :
    (cond_137 && ~cond_4)? ( `CMD_XLAT) :
    (cond_138 && ~cond_4)? ( `CMD_AAA) :
    (cond_139 && ~cond_4)? ( `CMD_AAS) :
    (cond_140 && ~cond_4)? ( `CMD_DAA) :
    (cond_141 && ~cond_4)? ( `CMD_DAS) :
    (cond_142 && ~cond_4)? ( `CMD_BSF) :
    (cond_143 && ~cond_4)? ( `CMD_BSR) :
    7'd0;
assign dec_is_complex =
    (cond_0 && ~cond_1)? (`TRUE) :
    (cond_5 && ~cond_4)? (`TRUE) :
    (cond_7 && ~cond_8)? (`TRUE) :
    (cond_20 && ~cond_4)? (`TRUE) :
    (cond_21 && ~cond_22)? (`TRUE) :
    (cond_23 && ~cond_4)? (`TRUE) :
    (cond_24 && ~cond_4 && cond_25)? (`TRUE) :
    (cond_28 && ~cond_4)? (`TRUE) :
    (cond_31 && ~cond_22)? (`TRUE) :
    (cond_32 && ~cond_33)? (`TRUE) :
    (cond_34 && ~cond_14)? (`TRUE) :
    (cond_35 && ~cond_14)? (`TRUE) :
    (cond_44 && ~cond_4)? (`TRUE) :
    (cond_49 && ~cond_4)? (`TRUE) :
    (cond_52 && ~cond_4)? (`TRUE) :
    (cond_58 && ~cond_4)? (`TRUE) :
    (cond_60 && ~cond_4)? (`TRUE) :
    (cond_61 && ~cond_62 && cond_56)? (`TRUE) :
    (cond_63 && ~cond_22)? (`TRUE) :
    (cond_64 && ~cond_22)? (`TRUE) :
    (cond_65 && ~cond_4)? (`TRUE) :
    (cond_70 && ~cond_4)? (`TRUE) :
    (cond_77 && ~cond_4)? (`TRUE) :
    (cond_88 && ~cond_4)? (`TRUE) :
    (cond_89 && ~cond_4)? (`TRUE) :
    (cond_90 && ~cond_4 && cond_25)? (`TRUE) :
    (cond_92 && ~cond_1)? (`TRUE) :
    (cond_96 && ~cond_4)? (`TRUE) :
    (cond_98 && ~cond_4)? (`TRUE) :
    (cond_99 && ~cond_4)? (`TRUE) :
    (cond_103 && ~cond_14)? (`TRUE) :
    (cond_104 && ~cond_14)? (`TRUE) :
    (cond_105 && ~cond_14)? (`TRUE) :
    (cond_106 && ~cond_14)? (`TRUE) :
    (cond_107 && ~cond_4 && cond_25)? (`TRUE) :
    (cond_108 && ~cond_4)? (`TRUE) :
    (cond_109 && ~cond_4)? (`TRUE) :
    (cond_111 && ~cond_4)? (`TRUE) :
    (cond_113 && ~cond_114)? (`TRUE) :
    (cond_115 && ~cond_4)? (`TRUE) :
    (cond_124 && ~cond_4)? (`TRUE) :
    (cond_127 && ~cond_22)? (`TRUE) :
    (cond_130 && ~cond_22)? (`TRUE) :
    (cond_131 && ~cond_22)? (`TRUE) :
    (cond_132 && ~cond_4 && cond_25)? (`TRUE) :
    (cond_135 && ~cond_4)? (`TRUE) :
    (cond_136 && ~cond_4 && cond_56)? (`TRUE) :
    1'd0;
assign consume_one_two =
    (cond_28 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_89 && ~cond_4 && cond_2)? (`TRUE) :
    1'd0;
assign consume_modregrm_imm =
    (cond_45 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_46 && ~cond_1 && cond_2)? (`TRUE) :
    (cond_47 && ~cond_1 && cond_2)? (`TRUE) :
    (cond_48 && ~cond_1 && cond_2)? (`TRUE) :
    (cond_57 && ~cond_4)? (`TRUE) :
    (cond_72 && ~cond_4)? (`TRUE) :
    (cond_74 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_76 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_81 && ~cond_82)? (`TRUE) :
    (cond_87 && ~cond_4)? (`TRUE) :
    (cond_120 && ~cond_4)? (`TRUE) :
    1'd0;
assign consume_one =
    (cond_10 && ~cond_4)? (`TRUE) :
    (cond_20 && ~cond_4)? (`TRUE) :
    (cond_23 && ~cond_4)? (`TRUE) :
    (cond_24 && ~cond_4)? (`TRUE) :
    (cond_26 && ~cond_4)? (`TRUE) :
    (cond_28 && ~cond_4 && ~cond_2)? (`TRUE) :
    (cond_30 && ~cond_4)? (`TRUE) :
    (cond_36 && ~cond_4)? (`TRUE) :
    (cond_37 && ~cond_4)? (`TRUE) :
    (cond_38 && ~cond_4)? (`TRUE) :
    (cond_39 && ~cond_4)? (`TRUE) :
    (cond_40 && ~cond_4)? (`TRUE) :
    (cond_41 && ~cond_4)? (`TRUE) :
    (cond_44 && ~cond_4)? (`TRUE) :
    (cond_49 && ~cond_4)? (`TRUE) :
    (cond_51 && ~cond_4)? (`TRUE) :
    (cond_58 && ~cond_4)? (`TRUE) :
    (cond_65 && ~cond_4)? (`TRUE) :
    (cond_66 && ~cond_4)? (`TRUE) :
    (cond_73 && ~cond_4)? (`TRUE) :
    (cond_77 && ~cond_4)? (`TRUE) :
    (cond_88 && ~cond_4)? (`TRUE) :
    (cond_89 && ~cond_4 && ~cond_2)? (`TRUE) :
    (cond_90 && ~cond_4)? (`TRUE) :
    (cond_91 && ~cond_4)? (`TRUE) :
    (cond_93 && ~cond_4)? (`TRUE) :
    (cond_96 && ~cond_4 && cond_97)? (`TRUE) :
    (cond_98 && ~cond_4)? (`TRUE) :
    (cond_99 && ~cond_4 && cond_101)? (`TRUE) :
    (cond_107 && ~cond_4)? (`TRUE) :
    (cond_108 && ~cond_4)? (`TRUE) :
    (cond_109 && ~cond_4)? (`TRUE) :
    (cond_110 && ~cond_4)? (`TRUE) :
    (cond_115 && ~cond_4 && cond_101)? (`TRUE) :
    (cond_121 && ~cond_4)? (`TRUE) :
    (cond_122 && ~cond_4)? (`TRUE) :
    (cond_123 && ~cond_4)? (`TRUE) :
    (cond_124 && ~cond_4)? (`TRUE) :
    (cond_125 && ~cond_4)? (`TRUE) :
    (cond_126 && ~cond_4)? (`TRUE) :
    (cond_128 && ~cond_4)? (`TRUE) :
    (cond_132 && ~cond_4)? (`TRUE) :
    (cond_135 && ~cond_4)? (`TRUE) :
    (cond_137 && ~cond_4)? (`TRUE) :
    (cond_138 && ~cond_4)? (`TRUE) :
    (cond_139 && ~cond_4)? (`TRUE) :
    (cond_140 && ~cond_4)? (`TRUE) :
    (cond_141 && ~cond_4)? (`TRUE) :
    1'd0;
assign consume_one_one =
    (cond_3 && ~cond_4)? (`TRUE) :
    (cond_17 && ~cond_4 && ~cond_19)? (`TRUE) :
    (cond_42 && ~cond_4)? (`TRUE) :
    (cond_43 && ~cond_4)? (`TRUE) :
    (cond_84 && ~cond_4)? (`TRUE) :
    (cond_96 && ~cond_4 && ~cond_97)? (`TRUE) :
    (cond_99 && ~cond_4 && ~cond_101)? (`TRUE) :
    (cond_115 && ~cond_4 && ~cond_101)? (`TRUE) :
    1'd0;
assign exception_ud =
    (cond_0 && cond_1)? (`TRUE) :
    (cond_3 && cond_4)? (`TRUE) :
    (cond_5 && cond_4)? (`TRUE) :
    (cond_7 && cond_8)? (`TRUE) :
    (cond_10 && cond_4)? (`TRUE) :
    (cond_11 && cond_12)? (`TRUE) :
    (cond_13 && cond_14)? (`TRUE) :
    (cond_15 && cond_14)? (`TRUE) :
    (cond_16 && cond_1)? (`TRUE) :
    (cond_17 && cond_4)? (`TRUE) :
    (cond_20 && cond_4)? (`TRUE) :
    (cond_21 && cond_22)? (`TRUE) :
    (cond_23 && cond_4)? (`TRUE) :
    (cond_24 && cond_4)? (`TRUE) :
    (cond_26 && cond_4)? (`TRUE) :
    (cond_27 && cond_1)? (`TRUE) :
    (cond_28 && cond_4)? (`TRUE) :
    (cond_29 && cond_14)? (`TRUE) :
    (cond_30 && cond_4)? (`TRUE) :
    (cond_31 && cond_22)? (`TRUE) :
    (cond_32 && cond_33)? (`TRUE) :
    (cond_34 && cond_14)? (`TRUE) :
    (cond_35 && cond_14)? (`TRUE) :
    (cond_36 && cond_4)? (`TRUE) :
    (cond_37 && cond_4)? (`TRUE) :
    (cond_38 && cond_4)? (`TRUE) :
    (cond_39 && cond_4)? (`TRUE) :
    (cond_40 && cond_4)? (`TRUE) :
    (cond_41 && cond_4)? (`TRUE) :
    (cond_42 && cond_4)? (`TRUE) :
    (cond_43 && cond_4)? (`TRUE) :
    (cond_44 && cond_4)? (`TRUE) :
    (cond_45 && cond_4)? (`TRUE) :
    (cond_46 && cond_1)? (`TRUE) :
    (cond_47 && cond_1)? (`TRUE) :
    (cond_48 && cond_1)? (`TRUE) :
    (cond_49 && cond_4)? (`TRUE) :
    (cond_51 && cond_4)? (`TRUE) :
    (cond_52 && cond_4)? (`TRUE) :
    (cond_53 && cond_4)? (`TRUE) :
    (cond_54 && cond_4)? (`TRUE) :
    (cond_55 && cond_4)? (`TRUE) :
    (cond_57 && cond_4)? (`TRUE) :
    (cond_58 && cond_4)? (`TRUE) :
    (cond_59 && cond_4)? (`TRUE) :
    (cond_60 && cond_4)? (`TRUE) :
    (cond_61 && cond_62)? (`TRUE) :
    (cond_63 && cond_22)? (`TRUE) :
    (cond_64 && cond_22)? (`TRUE) :
    (cond_65 && cond_4)? (`TRUE) :
    (cond_66 && cond_4)? (`TRUE) :
    (cond_67 && cond_4)? (`TRUE) :
    (cond_68 && cond_4)? (`TRUE) :
    (cond_69 && cond_1)? (`TRUE) :
    (cond_70 && cond_4)? (`TRUE) :
    (cond_71 && cond_4)? (`TRUE) :
    (cond_72 && cond_4)? (`TRUE) :
    (cond_73 && cond_4)? (`TRUE) :
    (cond_74 && cond_4)? (`TRUE) :
    (cond_76 && cond_4)? (`TRUE) :
    (cond_77 && cond_4)? (`TRUE) :
    (cond_78 && cond_4)? (`TRUE) :
    (cond_79 && cond_80)? (`TRUE) :
    (cond_81 && cond_82)? (`TRUE) :
    (cond_83 && cond_4)? (`TRUE) :
    (cond_84 && cond_4)? (`TRUE) :
    (cond_85 && cond_4)? (`TRUE) :
    (cond_86 && cond_4)? (`TRUE) :
    (cond_87 && cond_4)? (`TRUE) :
    (cond_88 && cond_4)? (`TRUE) :
    (cond_89 && cond_4)? (`TRUE) :
    (cond_90 && cond_4)? (`TRUE) :
    (cond_91 && cond_4)? (`TRUE) :
    (cond_92 && cond_1)? (`TRUE) :
    (cond_93 && cond_4)? (`TRUE) :
    (cond_94 && cond_4)? (`TRUE) :
    (cond_95 && cond_4)? (`TRUE) :
    (cond_96 && cond_4)? (`TRUE) :
    (cond_98 && cond_4)? (`TRUE) :
    (cond_99 && cond_4)? (`TRUE) :
    (cond_102 && cond_1)? (`TRUE) :
    (cond_103 && cond_14)? (`TRUE) :
    (cond_104 && cond_14)? (`TRUE) :
    (cond_105 && cond_14)? (`TRUE) :
    (cond_106 && cond_14)? (`TRUE) :
    (cond_107 && cond_4)? (`TRUE) :
    (cond_108 && cond_4)? (`TRUE) :
    (cond_109 && cond_4)? (`TRUE) :
    (cond_110 && cond_4)? (`TRUE) :
    (cond_111 && cond_4)? (`TRUE) :
    (cond_113 && cond_114)? (`TRUE) :
    (cond_115 && cond_4)? (`TRUE) :
    (cond_116 && cond_4)? (`TRUE) :
    (cond_117 && cond_4)? (`TRUE) :
    (cond_119 && cond_4)? (`TRUE) :
    (cond_120 && cond_4)? (`TRUE) :
    (cond_121 && cond_4)? (`TRUE) :
    (cond_122 && cond_4)? (`TRUE) :
    (cond_123 && cond_4)? (`TRUE) :
    (cond_124 && cond_4)? (`TRUE) :
    (cond_125 && cond_4)? (`TRUE) :
    (cond_126 && cond_4)? (`TRUE) :
    (cond_127 && cond_22)? (`TRUE) :
    (cond_128 && cond_4)? (`TRUE) :
    (cond_129 && cond_22)? (`TRUE) :
    (cond_130 && cond_22)? (`TRUE) :
    (cond_131 && cond_22)? (`TRUE) :
    (cond_132 && cond_4)? (`TRUE) :
    (cond_133 && cond_4)? (`TRUE) :
    (cond_134 && cond_4)? (`TRUE) :
    (cond_135 && cond_4)? (`TRUE) :
    (cond_136 && cond_4)? (`TRUE) :
    (cond_137 && cond_4)? (`TRUE) :
    (cond_138 && cond_4)? (`TRUE) :
    (cond_139 && cond_4)? (`TRUE) :
    (cond_140 && cond_4)? (`TRUE) :
    (cond_141 && cond_4)? (`TRUE) :
    (cond_142 && cond_4)? (`TRUE) :
    (cond_143 && cond_4)? (`TRUE) :
    1'd0;
assign consume_one_imm =
    (cond_17 && ~cond_4 && cond_19)? (`TRUE) :
    (cond_78 && ~cond_4)? (`TRUE) :
    (cond_85 && ~cond_4)? (`TRUE) :
    (cond_94 && ~cond_4)? (`TRUE) :
    (cond_117 && ~cond_4)? (`TRUE) :
    1'd0;
assign consume_call_jmp_imm =
    (cond_5 && ~cond_4)? (`TRUE) :
    (cond_111 && ~cond_4)? (`TRUE) :
    1'd0;
assign consume_modregrm_one =
    (cond_0 && ~cond_1)? (`TRUE) :
    (cond_7 && ~cond_8)? (`TRUE) :
    (cond_11 && ~cond_12)? (`TRUE) :
    (cond_13 && ~cond_14)? (`TRUE) :
    (cond_15 && ~cond_14)? (`TRUE) :
    (cond_16 && ~cond_1)? (`TRUE) :
    (cond_21 && ~cond_22)? (`TRUE) :
    (cond_27 && ~cond_1)? (`TRUE) :
    (cond_29 && ~cond_14)? (`TRUE) :
    (cond_31 && ~cond_22)? (`TRUE) :
    (cond_32 && ~cond_33)? (`TRUE) :
    (cond_34 && ~cond_14)? (`TRUE) :
    (cond_35 && ~cond_14)? (`TRUE) :
    (cond_45 && ~cond_4 && ~cond_2)? (`TRUE) :
    (cond_46 && ~cond_1 && ~cond_2)? (`TRUE) :
    (cond_47 && ~cond_1 && ~cond_2)? (`TRUE) :
    (cond_48 && ~cond_1 && ~cond_2)? (`TRUE) :
    (cond_52 && ~cond_4)? (`TRUE) :
    (cond_53 && ~cond_4)? (`TRUE) :
    (cond_54 && ~cond_4)? (`TRUE) :
    (cond_55 && ~cond_4)? (`TRUE) :
    (cond_59 && ~cond_4)? (`TRUE) :
    (cond_60 && ~cond_4)? (`TRUE) :
    (cond_61 && ~cond_62)? (`TRUE) :
    (cond_63 && ~cond_22)? (`TRUE) :
    (cond_64 && ~cond_22)? (`TRUE) :
    // PR-2b.4i (iter 60): cond_67 relocated below cond_205 in this cascade
    // so PR-1a (cond_144..147) and PR-2b (cond_148..205) win first; cond_67
    // remains as a fall-through for un-implemented reg-form D8..DF.
    // DECFIX prototype (decode->mc_eip 90 MHz timing): the 102 per-op x87
    // cond_N (cond_144..245, cond_206..237) each only asserted consume_modregrm_one
    // for INSTRUCTION LENGTH -- every D8..DF ESC opcode + modrm consumes identically,
    // so the 102-wide OR was needless depth on the decoder[4]->dec_eip->mc_eip cone.
    // Collapse to one opcode-range test (D8..DF = decoder[7:3]==5'b11011). Per-op
    // cond_N still drive execute dispatch (mc_cmd/cmdex), a separate registered path.
    (dec_ready_modregrm_one && decoder[7:3] == 5'b11011 && ~cond_4)? (`TRUE) :
    // PR-2b.4i (iter 60): cond_67 reg-form catch-all relocated here so
    // un-implemented reg-form D8..DF + modregrm_one still asserts
    // consume_modregrm_one (advancing the decoder past the instruction)
    // via the legacy stub fallback.
    (cond_67 && ~cond_4)? (`TRUE) :
    (cond_68 && ~cond_4)? (`TRUE) :
    (cond_69 && ~cond_1)? (`TRUE) :
    (cond_71 && ~cond_4)? (`TRUE) :
    (cond_74 && ~cond_4 && ~cond_2)? (`TRUE) :
    (cond_76 && ~cond_4 && ~cond_2)? (`TRUE) :
    (cond_79 && ~cond_80)? (`TRUE) :
    (cond_83 && ~cond_4)? (`TRUE) :
    (cond_86 && ~cond_4)? (`TRUE) :
    (cond_92 && ~cond_1)? (`TRUE) :
    (cond_95 && ~cond_4)? (`TRUE) :
    (cond_102 && ~cond_1)? (`TRUE) :
    (cond_103 && ~cond_14)? (`TRUE) :
    (cond_104 && ~cond_14)? (`TRUE) :
    (cond_105 && ~cond_14)? (`TRUE) :
    (cond_106 && ~cond_14)? (`TRUE) :
    (cond_113 && ~cond_114)? (`TRUE) :
    (cond_119 && ~cond_4)? (`TRUE) :
    (cond_127 && ~cond_22)? (`TRUE) :
    (cond_129 && ~cond_22)? (`TRUE) :
    (cond_130 && ~cond_22)? (`TRUE) :
    (cond_131 && ~cond_22)? (`TRUE) :
    (cond_133 && ~cond_4)? (`TRUE) :
    (cond_134 && ~cond_4)? (`TRUE) :
    (cond_136 && ~cond_4)? (`TRUE) :
    (cond_142 && ~cond_4)? (`TRUE) :
    (cond_143 && ~cond_4)? (`TRUE) :
    1'd0;
assign consume_one_three =
    (cond_70 && ~cond_4)? (`TRUE) :
    1'd0;
assign dec_is_8bit =
    (cond_0 && ~cond_1 && cond_2)? (`TRUE) :
    (cond_3 && ~cond_4)? (`TRUE) :
    (cond_16 && ~cond_1 && cond_2)? (`TRUE) :
    (cond_17 && ~cond_4 && cond_18)? (`TRUE) :
    (cond_24 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_27 && ~cond_1 && cond_2)? (`TRUE) :
    (cond_42 && ~cond_4)? (`TRUE) :
    (cond_43 && ~cond_4)? (`TRUE) :
    (cond_53 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_54 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_55 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_57 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_58 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_68 && ~cond_4)? (`TRUE) :
    (cond_69 && ~cond_1 && cond_2)? (`TRUE) :
    (cond_71 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_78 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_79 && ~cond_80 && cond_2)? (`TRUE) :
    (cond_81 && ~cond_82 && cond_2)? (`TRUE) :
    (cond_83 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_84 && ~cond_4)? (`TRUE) :
    (cond_85 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_86 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_87 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_90 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_92 && ~cond_1 && cond_2)? (`TRUE) :
    (cond_99 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_102 && ~cond_1 && cond_2)? (`TRUE) :
    (cond_107 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_108 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_109 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_111 && ~cond_4 && cond_112)? (`TRUE) :
    (cond_115 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_116 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_117 && ~cond_4 && cond_118)? (`TRUE) :
    (cond_119 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_120 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_132 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_133 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_134 && ~cond_4 && cond_2)? (`TRUE) :
    (cond_137 && ~cond_4)? (`TRUE) :
    (cond_138 && ~cond_4)? (`TRUE) :
    (cond_139 && ~cond_4)? (`TRUE) :
    (cond_140 && ~cond_4)? (`TRUE) :
    (cond_141 && ~cond_4)? (`TRUE) :
    1'd0;
// ===== PR-2c.DECFIX (iter 206): x87 dispatch one-hot collapse =====
// The ~100 mutually-exclusive FPU decode arms below were a serial priority
// cascade that dominated the decode->microcode (mc_eip/mc_consumed) setup path
// and pushed clk_sys 90 MHz WSS to -12.2 ns.  They are pairwise-disjoint over
// every (D8..DF x modrm) input (exhaustively verified), so the cascade is
// rewritten as a single balanced ONE-HOT select.  SOLE overlap D9 D0
// (cond_162 FST_STi vs cond_175 FNOP) keeps original priority via & ~cond_162.
// cond_67 (reg-form ESC catch-all) stays BELOW the group, unchanged.
wire fpu_cmdex_hit = cond_144 | cond_145 | cond_146 | cond_147 | cond_222 | cond_148 | cond_149 | cond_150 | cond_151 | cond_152 | cond_153 | cond_154 | cond_155 | cond_156 | cond_157 | cond_158 | cond_159 | cond_160 | cond_161 | cond_162 | cond_163 | cond_164 | cond_221 | cond_223 | cond_224 | cond_225 | cond_226 | cond_227 | cond_238 | cond_239 | cond_240 | cond_241 | cond_242 | cond_243 | cond_244 | cond_245 | cond_165 | cond_166 | cond_167 | cond_168 | cond_169 | cond_170 | cond_171 | cond_172 | cond_173 | cond_174 | cond_175 | cond_176 | cond_177 | cond_178 | cond_179 | cond_180 | cond_181 | cond_182 | cond_183 | cond_184 | cond_185 | cond_186 | cond_187 | cond_188 | cond_189 | cond_190 | cond_191 | cond_192 | cond_193 | cond_194 | cond_195 | cond_196 | cond_197 | cond_198 | cond_199 | cond_200 | cond_201 | cond_202 | cond_203 | cond_204 | cond_205 | cond_206 | cond_207 | cond_220 | cond_228 | cond_229 | cond_230 | cond_236 | cond_208 | cond_209 | cond_210 | cond_211 | cond_212 | cond_213 | cond_214 | cond_215 | cond_216 | cond_217 | cond_218 | cond_219 | cond_231 | cond_232 | cond_233 | cond_234 | cond_235 | cond_237 | cond_247 | cond_246 | cond_249 | cond_248 | cond_250 | cond_251 | cond_252 | cond_253 | cond_254 | cond_255 | cond_256 | cond_257 | cond_258 | cond_259 | cond_260 | cond_261 | cond_262 | cond_263 | cond_264 | cond_265 | cond_266;
wire [3:0] fpu_cmdex_val =
    ({4{cond_144}} & (`CMDEX_FN_INIT))
  |     ({4{cond_145}} & (`CMDEX_FN_CLEX))
  |     ({4{cond_146}} & (`CMDEX_FNSTSW_AX))
  |     ({4{cond_147}} & (`CMDEX_FNSTCW_M16))
  |     ({4{cond_250}} & (`CMDEX_FNSTSW_M16))   // iter-229: FNSTSW m16 (DD /7)
  |     ({4{cond_247}} & (`CMDEX_FNSTENV_M14))
  |     ({4{cond_246}} & (`CMDEX_FLDENV_M14))
  |     ({4{cond_249}} & (`CMDEX_FNSAVE_M94))
  |     ({4{cond_248}} & (`CMDEX_FRSTOR_M94))
  |     ({4{cond_222}} & (`CMDEX_FLDCW_M16))
  |     ({4{cond_148}} & (`CMDEX_FADD_ST0_STi))
  |     ({4{cond_149}} & (`CMDEX_FSUB_ST0_STi))
  |     ({4{cond_150}} & (`CMDEX_FMUL_ST0_STi))
  |     ({4{cond_151}} & (`CMDEX_FDIV_ST0_STi))
  |     ({4{cond_152}} & (`CMDEX_FSUBR_ST0_STi))
  |     ({4{cond_153}} & (`CMDEX_FDIVR_ST0_STi))
  |     ({4{cond_154}} & (`CMDEX_FADDP_STi_ST0))
  |     ({4{cond_155}} & (`CMDEX_FMULP_STi_ST0))
  |     ({4{cond_156}} & (`CMDEX_FSUBRP_STi_ST0))
  |     ({4{cond_157}} & (`CMDEX_FSUBP_STi_ST0))
  |     ({4{cond_158}} & (`CMDEX_FDIVRP_STi_ST0))
  |     ({4{cond_159}} & (`CMDEX_FDIVP_STi_ST0))
  |     ({4{cond_160}} & (`CMDEX_FXCH_STi))
  |     ({4{cond_161}} & (`CMDEX_FLD_STi))
  |     ({4{cond_162}} & (`CMDEX_FST_STi))
  |     ({4{cond_163}} & (`CMDEX_FSTP_STi))
  |     ({4{cond_164}} & (`CMDEX_FCHS))
  |     ({4{cond_221}} & (`CMDEX_FRNDINT))
  |     ({4{cond_223}} & (`CMDEX_FSCALE))
  |     ({4{cond_224}} & (`CMDEX_FXTRACT))
  |     ({4{cond_225}} & (`CMDEX_FPREM))
  |     ({4{cond_226}} & (`CMDEX_FPREM1))
  |     ({4{cond_227}} & (`CMDEX_FSQRT))
  |     ({4{cond_238}} & (`CMDEX_F2XM1))
  |     ({4{cond_239}} & (`CMDEX_FYL2X))
  |     ({4{cond_240}} & (`CMDEX_FPTAN))
  |     ({4{cond_241}} & (`CMDEX_FPATAN))
  |     ({4{cond_242}} & (`CMDEX_FYL2XP1))
  |     ({4{cond_243}} & (`CMDEX_FSIN))
  |     ({4{cond_244}} & (`CMDEX_FCOS))
  |     ({4{cond_245}} & (`CMDEX_FSINCOS))
  |     ({4{cond_165}} & (`CMDEX_FABS))
  |     ({4{cond_166}} & (`CMDEX_FXAM))
  |     ({4{cond_167}} & (`CMDEX_FCOM))
  |     ({4{cond_168}} & (`CMDEX_FCOMP))
  |     ({4{cond_169}} & (`CMDEX_FUCOM))
  |     ({4{cond_170}} & (`CMDEX_FUCOMP))
  |     ({4{cond_171}} & (`CMDEX_FTST))
  |     ({4{cond_172}} & (`CMDEX_FCOMPP))
  |     ({4{cond_173}} & (`CMDEX_FUCOMPP))
  |     ({4{cond_174}} & (`CMDEX_FFREE))
  |     ({4{cond_175 & ~cond_162}} & (`CMDEX_FNOP))
  |     ({4{cond_176}} & (`CMDEX_FDECSTP))
  |     ({4{cond_177}} & (`CMDEX_FINCSTP))
  |     ({4{cond_178}} & (`CMDEX_FCMOVB))
  |     ({4{cond_179}} & (`CMDEX_FCMOVE))
  |     ({4{cond_180}} & (`CMDEX_FCMOVBE))
  |     ({4{cond_181}} & (`CMDEX_FCMOVU))
  |     ({4{cond_182}} & (`CMDEX_FCMOVNB))
  |     ({4{cond_183}} & (`CMDEX_FCMOVNE))
  |     ({4{cond_184}} & (`CMDEX_FCMOVNBE))
  |     ({4{cond_185}} & (`CMDEX_FCMOVNU))
  |     ({4{cond_186}} & (`CMDEX_FCOMI))
  |     ({4{cond_187}} & (`CMDEX_FUCOMI))
  |     ({4{cond_188}} & (`CMDEX_FCOMIP))
  |     ({4{cond_189}} & (`CMDEX_FUCOMIP))
  |     ({4{cond_190}} & (`CMDEX_FADD_M32))
  |     ({4{cond_191}} & (`CMDEX_FADD_M64))
  |     ({4{cond_192}} & (`CMDEX_FMUL_M32))
  |     ({4{cond_193}} & (`CMDEX_FMUL_M64))
  |     ({4{cond_194}} & (`CMDEX_FSUB_M32))
  |     ({4{cond_195}} & (`CMDEX_FSUB_M64))
  |     ({4{cond_196}} & (`CMDEX_FDIV_M32))
  |     ({4{cond_197}} & (`CMDEX_FDIV_M64))
  |     ({4{cond_198}} & (`CMDEX_FSUBR_M32))
  |     ({4{cond_199}} & (`CMDEX_FSUBR_M64))
  |     ({4{cond_200}} & (`CMDEX_FDIVR_M32))
  |     ({4{cond_201}} & (`CMDEX_FDIVR_M64))
  |     ({4{cond_202}} & (`CMDEX_FCOM_M32))
  |     ({4{cond_203}} & (`CMDEX_FCOM_M64))
  |     ({4{cond_204}} & (`CMDEX_FCOMP_M32))
  |     ({4{cond_205}} & (`CMDEX_FCOMP_M64))
  |     ({4{cond_251}} & (`CMDEX_FADD_M32))    // FIADD  m32int → FADD  op, DA/even=m32int width
  |     ({4{cond_252}} & (`CMDEX_FADD_M64))    // FIADD  m16int → FADD  op, DE/odd =m16int width
  |     ({4{cond_253}} & (`CMDEX_FMUL_M32))    // FIMUL  m32int
  |     ({4{cond_254}} & (`CMDEX_FMUL_M64))    // FIMUL  m16int
  |     ({4{cond_255}} & (`CMDEX_FCOM_M32))    // FICOM  m32int
  |     ({4{cond_256}} & (`CMDEX_FCOM_M64))    // FICOM  m16int
  |     ({4{cond_257}} & (`CMDEX_FCOMP_M32))   // FICOMP m32int
  |     ({4{cond_258}} & (`CMDEX_FCOMP_M64))   // FICOMP m16int
  |     ({4{cond_259}} & (`CMDEX_FSUB_M32))    // FISUB  m32int
  |     ({4{cond_260}} & (`CMDEX_FSUB_M64))    // FISUB  m16int
  |     ({4{cond_261}} & (`CMDEX_FSUBR_M32))   // FISUBR m32int
  |     ({4{cond_262}} & (`CMDEX_FSUBR_M64))   // FISUBR m16int
  |     ({4{cond_263}} & (`CMDEX_FDIV_M32))    // FIDIV  m32int
  |     ({4{cond_264}} & (`CMDEX_FDIV_M64))    // FIDIV  m16int
  |     ({4{cond_265}} & (`CMDEX_FDIVR_M32))   // FIDIVR m32int
  |     ({4{cond_266}} & (`CMDEX_FDIVR_M64))   // FIDIVR m16int
  |     ({4{cond_206}} & (`CMDEX_FLD_M32))
  |     ({4{cond_207}} & (`CMDEX_FLD_M64))
  |     ({4{cond_220}} & (`CMDEX_FLD_M80))
  |     ({4{cond_228}} & (`CMDEX_FILD_M32))
  |     ({4{cond_229}} & (`CMDEX_FILD_M16))
  |     ({4{cond_230}} & (`CMDEX_FILD_M64))
  |     ({4{cond_236}} & (`CMDEX_FBLD))
  |     ({4{cond_208}} & (`CMDEX_FLD1))
  |     ({4{cond_209}} & (`CMDEX_FLDL2T))
  |     ({4{cond_210}} & (`CMDEX_FLDL2E))
  |     ({4{cond_211}} & (`CMDEX_FLDPI))
  |     ({4{cond_212}} & (`CMDEX_FLDLG2))
  |     ({4{cond_213}} & (`CMDEX_FLDLN2))
  |     ({4{cond_214}} & (`CMDEX_FLDZ))
  |     ({4{cond_215}} & (`CMDEX_FSTP_M80))
  |     ({4{cond_216}} & (`CMDEX_FSTP_M32))
  |     ({4{cond_217}} & (`CMDEX_FSTP_M64))
  |     ({4{cond_218}} & (`CMDEX_FST_M32))
  |     ({4{cond_219}} & (`CMDEX_FST_M64))
  |     ({4{cond_231}} & (`CMDEX_FIST_M32))
  |     ({4{cond_232}} & (`CMDEX_FISTP_M32))
  |     ({4{cond_233}} & (`CMDEX_FIST_M16))
  |     ({4{cond_234}} & (`CMDEX_FISTP_M16))
  |     ({4{cond_235}} & (`CMDEX_FISTP_M64))
  |     ({4{cond_237}} & (`CMDEX_FBSTP));

assign dec_cmdex =
    (cond_5 && ~cond_4 && cond_6)? ( `CMDEX_CALL_Jv_STEP_0) :
    (cond_5 && ~cond_4 && ~cond_6)? ( `CMDEX_CALL_Ap_STEP_0) :
    (cond_7 && ~cond_8 && cond_9)? ( `CMDEX_CALL_Ev_STEP_0) :
    (cond_7 && ~cond_8 && ~cond_9)? ( `CMDEX_CALL_Ep_STEP_0) :
    (cond_10 && ~cond_4)? ( `CMDEX_PUSH_MOV_SEG_implicit | { 1'b0, decoder[5:3] }) :
    (cond_11 && ~cond_12)? ( `CMDEX_PUSH_MOV_SEG_modregrm | { 1'b0, decoder[13:11] }) :
    (cond_13 && ~cond_14)? ( `CMDEX_PUSH_MOV_SEG_modregrm_LDT) :
    (cond_15 && ~cond_14)? ( `CMDEX_PUSH_MOV_SEG_modregrm_TR) :
    (cond_20 && ~cond_4)? ( `CMDEX_INVD_STEP_0) :
    (cond_21 && ~cond_22)? ( `CMDEX_INVLPG_STEP_0) :
    (cond_23 && ~cond_4)? ( `CMDEX_HLT_STEP_0) :
    (cond_24 && ~cond_4)? ( `CMDEX_SCAS_STEP_0) :
    (cond_26 && ~cond_4)? ( `CMDEX_INC_DEC_increment_implicit | { 3'd0, decoder[3] }) :
    (cond_27 && ~cond_1)? ( `CMDEX_INC_DEC_increment_modregrm | { 3'd0, decoder[11] }) :
    (cond_28 && ~cond_4 && cond_2)? ( `CMDEX_RET_near_imm) :
    (cond_28 && ~cond_4 && ~cond_2)? ( `CMDEX_RET_near) :
    (cond_31 && ~cond_22)? ( `CMDEX_LxS_STEP_1) :
    (cond_32 && ~cond_33)? ( `CMDEX_MOV_to_seg_LLDT_LTR_STEP_1) :
    (cond_34 && ~cond_14)? ( `CMDEX_MOV_to_seg_LLDT_LTR_STEP_1) :
    (cond_35 && ~cond_14)? ( `CMDEX_MOV_to_seg_LLDT_LTR_STEP_1) :
    (cond_44 && ~cond_4)? ( `CMDEX_POP_seg_STEP_1) :
    (cond_45 && ~cond_4 && cond_2)? ( `CMDEX_BTx_modregrm_imm) :
    (cond_45 && ~cond_4 && ~cond_2)? ( `CMDEX_BTx_modregrm) :
    (cond_46 && ~cond_1 && cond_2)? ( `CMDEX_BTx_modregrm_imm) :
    (cond_46 && ~cond_1 && ~cond_2)? ( `CMDEX_BTx_modregrm) :
    (cond_47 && ~cond_1 && cond_2)? ( `CMDEX_BTx_modregrm_imm) :
    (cond_47 && ~cond_1 && ~cond_2)? ( `CMDEX_BTx_modregrm) :
    (cond_48 && ~cond_1 && cond_2)? ( `CMDEX_BTx_modregrm_imm) :
    (cond_48 && ~cond_1 && ~cond_2)? ( `CMDEX_BTx_modregrm) :
    (cond_49 && ~cond_4 && cond_50)? ( `CMDEX_IRET_real_v86_STEP_0) :
    (cond_49 && ~cond_4 && ~cond_50)? ( `CMDEX_IRET_protected_STEP_0) :
    (cond_51 && ~cond_4)? ( `CMDEX_POP_implicit) :
    (cond_52 && ~cond_4)? ( `CMDEX_POP_modregrm_STEP_0) :
    (cond_55 && ~cond_4 && cond_56)? ( `CMDEX_Shift_implicit) :
    (cond_55 && ~cond_4 && ~cond_56)? ( `CMDEX_Shift_modregrm) :
    (cond_57 && ~cond_4)? ( `CMDEX_Shift_modregrm_imm) :
    (cond_58 && ~cond_4)? (`CMDEX_CMPS_FIRST) :
    (cond_59 && ~cond_4)? ( `CMDEX_control_reg_SMSW_STEP_0) :
    (cond_60 && ~cond_4)? ( `CMDEX_control_reg_LMSW_STEP_0) :
    (cond_61 && ~cond_62 && cond_56)? ( `CMDEX_control_reg_MOV_load_STEP_0) :
    (cond_61 && ~cond_62 && ~cond_56)? ( `CMDEX_control_reg_MOV_store_STEP_0) :
    (cond_63 && ~cond_22)? ( `CMDEX_LGDT_LIDT_STEP_1) :
    (cond_64 && ~cond_22)? ( `CMDEX_LGDT_LIDT_STEP_1) :
    (cond_65 && ~cond_4)? ( `CMDEX_PUSHA_STEP_0) :
    (cond_66 && ~cond_4)? ( `CMDEX_WAIT_STEP_0) :
    // PR-2b.4i (iter 60): cond_67's CMDEX_ESC_STEP_0 arm relocated to
    // the tail of this cascade so PR-1a / PR-2b CMDEXes win first.
    (fpu_cmdex_hit && ~cond_4)? ( fpu_cmdex_val ) :
    // PR-2b.4i (iter 60): cond_67's CMDEX_ESC_STEP_0 fallback for any
    // reg-form D8..DF not caught by cond_144..205.
    (cond_67 && ~cond_4)? ( `CMDEX_ESC_STEP_0) :
    (cond_70 && ~cond_4)? ( `CMDEX_ENTER_FIRST) :
    (cond_71 && ~cond_4)? ( `CMDEX_IMUL_modregrm) :
    (cond_72 && ~cond_4)? ( `CMDEX_IMUL_modregrm_imm) :
    (cond_74 && ~cond_4 && cond_75)? ( `CMDEX_SHxD_implicit) :
    (cond_74 && ~cond_4 && ~cond_75)? ( `CMDEX_SHxD_modregrm_imm) :
    (cond_76 && ~cond_4 && cond_75)? ( `CMDEX_SHxD_implicit) :
    (cond_76 && ~cond_4 && ~cond_75)? ( `CMDEX_SHxD_modregrm_imm) :
    (cond_77 && ~cond_4)? ( `CMDEX_WBINVD_STEP_0) :
    (cond_78 && ~cond_4)? ( `CMDEX_Arith_immediate) :
    (cond_79 && ~cond_80)? ( `CMDEX_Arith_modregrm) :
    (cond_81 && ~cond_82)? ( `CMDEX_Arith_modregrm_imm) :
    (cond_84 && ~cond_4)? ( (decoder[1:0] == 2'b00)? `CMDEX_LOOP_NE : (decoder[1:0] == 2'b01)? `CMDEX_LOOP_E : `CMDEX_LOOP) :
    (cond_85 && ~cond_4)? ( `CMDEX_TEST_immediate) :
    (cond_86 && ~cond_4)? ( `CMDEX_TEST_modregrm) :
    (cond_87 && ~cond_4)? ( `CMDEX_TEST_modregrm_imm) :
    (cond_88 && ~cond_4)? (`CMDEX_CLTS_STEP_FIRST) :
    (cond_89 && ~cond_4)? ( `CMDEX_RET_far_STEP_1) :
    (cond_90 && ~cond_4)? ( `CMDEX_LODS_STEP_0) :
    (cond_91 && ~cond_4)? ( `CMDEX_XCHG_implicit) :
    (cond_92 && ~cond_1)? ( `CMDEX_XCHG_modregrm) :
    (cond_93 && ~cond_4)? ( `CMDEX_PUSH_implicit) :
    (cond_94 && ~cond_4 && cond_56)? ( `CMDEX_PUSH_immediate_se) :
    (cond_94 && ~cond_4 && ~cond_56)? ( `CMDEX_PUSH_immediate) :
    (cond_95 && ~cond_4)? ( `CMDEX_PUSH_modregrm) :
    (cond_96 && ~cond_4)? ( (decoder[2:0] == 3'b100)? `CMDEX_INT_INTO_INT3_STEP_0 : (decoder[2:0] == 3'b101)? `CMDEX_INT_INTO_INT_STEP_0 : (decoder[2:0] == 3'b110)? `CMDEX_INT_INTO_INTO_STEP_0 : `CMDEX_INT_INTO_INT1_STEP_0) :
    (cond_98 && ~cond_4)? ( `CMDEX_CPUID_STEP_LAST) :
    (cond_99 && ~cond_4 && cond_100)? ( `CMDEX_IN_dx) :
    (cond_99 && ~cond_4 && ~cond_100)? ( `CMDEX_IN_imm) :
    (cond_103 && ~cond_14)? ( `CMDEX_LAR_LSL_VERR_VERW_STEP_1) :
    (cond_104 && ~cond_14)? ( `CMDEX_LAR_LSL_VERR_VERW_STEP_1) :
    (cond_105 && ~cond_14)? (`CMDEX_LAR_LSL_VERR_VERW_STEP_1) :
    (cond_106 && ~cond_14)? ( `CMDEX_LAR_LSL_VERR_VERW_STEP_1) :
    (cond_107 && ~cond_4)? ( `CMDEX_STOS_STEP_0) :
    (cond_108 && ~cond_4)? ( `CMDEX_INS_real_1) :
    (cond_109 && ~cond_4)? ( `CMDEX_OUTS_first) :
    (cond_111 && ~cond_4 && cond_2)? ( `CMDEX_JMP_Ap_STEP_0) :
    (cond_111 && ~cond_4 && ~cond_2)? ( `CMDEX_JMP_Jv_STEP_0) :
    (cond_113 && ~cond_114 && cond_9)? ( `CMDEX_JMP_Ev_STEP_0) :
    (cond_113 && ~cond_114 && ~cond_9)? ( `CMDEX_JMP_Ep_STEP_0) :
    (cond_115 && ~cond_4 && cond_100)? ( `CMDEX_OUT_dx) :
    (cond_115 && ~cond_4 && ~cond_100)? ( `CMDEX_OUT_imm) :
    (cond_116 && ~cond_4)? ( `CMDEX_MOV_memoffset) :
    (cond_117 && ~cond_4)? ( `CMDEX_MOV_immediate) :
    (cond_119 && ~cond_4)? ( `CMDEX_MOV_modregrm) :
    (cond_120 && ~cond_4)? ( `CMDEX_MOV_modregrm_imm) :
    (cond_124 && ~cond_4)? ( `CMDEX_POPF_STEP_0) :
    (cond_127 && ~cond_22)? ( `CMDEX_BOUND_STEP_FIRST) :
    (cond_128 && ~cond_4)? ( `CMDEX_SALC_STEP_0) :
    (cond_130 && ~cond_22)? ( `CMDEX_SGDT_SIDT_STEP_1) :
    (cond_131 && ~cond_22)? ( `CMDEX_SGDT_SIDT_STEP_1) :
    (cond_132 && ~cond_4)? ( `CMDEX_MOVS_STEP_0) :
    (cond_135 && ~cond_4)? ( `CMDEX_POPA_STEP_0) :
    (cond_136 && ~cond_4 && cond_56)? ( `CMDEX_debug_reg_MOV_load_STEP_0) :
    (cond_136 && ~cond_4 && ~cond_56)? ( `CMDEX_debug_reg_MOV_store_STEP_0) :
    4'd0;
