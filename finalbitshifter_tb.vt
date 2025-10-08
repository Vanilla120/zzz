// ============================================================================
// 単一モジュール版 可変ビット遅延シフタ（ForgeFPGA向け）
// - 外部IF: clk / rst / btn_raw / in_bit / out
// - 内部で：外部rstの2FF同期 → ボタン整形（デバウンス+ワンショット）→ 遅延可変シフト
// - 加算は len の +1 のみ（キャリー源を極小化）
// - 出力選択は pipe[len] の単純MUX（減算なし）
// - `timescale` はシミュレーション用であり、Bitstream生成には不要
// ============================================================================
(* top *)
module xbitshifter_single #(
  parameter integer N        = 128, // ボタンデバウンス窓（連続サンプル数, 推奨>=2）
  parameter integer MAX_LEN  = 15,  // 遅延長：0..MAX_LEN
  parameter integer RES_INIT = 0    // リセット時 out 初期値（0 or 1）
)(
  input  wire clk,       // クロック（専用GCLKピン割当推奨）
  input  wire rst,       // 外部リセット（押下=1；非同期入力想定→内部で同期化）
  input  wire btn_raw,   // 物理ボタン（非同期）
  input  wire in_bit,    // シリアル入力
  output wire out        // 遅延後ビット出力
);

  // --------------------------------------------------------------------------
  // 0) 外部リセットの2FF同期（以降は同期リセットとして使用）
  // --------------------------------------------------------------------------
  reg rst_ff1, rst_ff2;
  always @(posedge clk) begin
    rst_ff1 <= rst;
    rst_ff2 <= rst_ff1;
  end
  wire rst_sync = rst_ff2;

  // --------------------------------------------------------------------------
  // 1) ボタン整形（2FF同期 → N連続一致で安定判定 → 立上り1クロックパルス）
  //    ※ 加算なし（シフト履歴のみ）でチャタ除去
  // --------------------------------------------------------------------------
  // 2段同期でメタスタ回避
  reg s1, s2;
  always @(posedge clk) begin
    if (rst_sync) begin
      s1 <= 1'b0;
      s2 <= 1'b0;
    end else begin
      s1 <= btn_raw;
      s2 <= s1;
    end
  end

  // N段シフト履歴（N==1 でも動作するようガード）
  wire btn_pulse;
  generate
    if (N >= 2) begin : GEN_BTN_N_GE2
      reg [N-1:0] hist;
      always @(posedge clk) begin
        if (rst_sync) hist <= {N{1'b0}};
        else          hist <= {hist[N-2:0], s2};
      end
      wire all_one  = &hist;
      wire all_zero = ~|hist;

      reg stable, stable_d;
      always @(posedge clk) begin
        if (rst_sync) begin
          stable   <= 1'b0;
          stable_d <= 1'b0;
        end else begin
          // 安定状態の更新（中間は保持）
          if (all_one)       stable <= 1'b1;
          else if (all_zero) stable <= 1'b0;
          // 立上りパルス用の1サイクル遅延
          stable_d <= stable;
        end
      end
      assign btn_pulse = (stable & ~stable_d);

    end else begin : GEN_BTN_N_EQ1
      // s2 が 1 になった瞬間を 1クロックのパルス化
      reg s2_d;
      always @(posedge clk) begin
        if (rst_sync) s2_d <= 1'b0;
        else          s2_d <= s2;
      end
      assign btn_pulse = (s2 & ~s2_d);
    end
  endgenerate

  // --------------------------------------------------------------------------
  // 2) 可変遅延シフタ
  //    - len: ボタン押下の度に 0→1→…→MAX_LEN→0 を循環
  //    - in_bit は1段同期
  //    - 出力は pipe[len] をクロックで取り込み（RES_INIT適用）
  // --------------------------------------------------------------------------
  // 入力同期
  reg in_bit_sync;
  always @(posedge clk) begin
    if (rst_sync) in_bit_sync <= 1'b0;
    else          in_bit_sync <= in_bit;
  end

  // 遅延長カウンタ
  localparam integer LEN_W = (MAX_LEN > 0) ? $clog2(MAX_LEN+1) : 1;
  reg [LEN_W-1:0] len;
  always @(posedge clk) begin
    if (rst_sync) begin
      len <= {LEN_W{1'b0}};
    end else if (btn_pulse) begin
      if (len == MAX_LEN[LEN_W-1:0]) len <= {LEN_W{1'b0}};
      else                           len <= len + 1'b1; // ← 唯一の加算
    end
  end

  // シフトレジスタと出力選択
  generate
    if (MAX_LEN >= 2) begin : GEN_SHIFT_GE2
      reg [MAX_LEN-1:0] shift_reg;
      always @(posedge clk) begin
        if (rst_sync) shift_reg <= {MAX_LEN{1'b0}};
        else          shift_reg <= {shift_reg[MAX_LEN-2:0], in_bit_sync};
      end

      // pipe[0]=in_bit_sync, pipe[k>0]=shift_reg[k-1]
      wire [MAX_LEN:0] pipe = {shift_reg, in_bit_sync};

      reg out_reg;
      always @(posedge clk) begin
        if (rst_sync) out_reg <= (RES_INIT != 0);
        else          out_reg <= pipe[len];
      end
      assign out = out_reg;

    end else if (MAX_LEN == 1) begin : GEN_SHIFT_EQ1
      reg shift1;
      always @(posedge clk) begin
        if (rst_sync) shift1 <= 1'b0;
        else          shift1 <= in_bit_sync;
      end
      wire [1:0] pipe = {shift1, in_bit_sync};

      reg out_reg;
      always @(posedge clk) begin
        if (rst_sync) out_reg <= (RES_INIT != 0);
        else          out_reg <= pipe[len];
      end
      assign out = out_reg;

    end else begin : GEN_SHIFT_EQ0 // MAX_LEN == 0（遅延なし）
      reg out_reg;
      always @(posedge clk) begin
        if (rst_sync) out_reg <= (RES_INIT != 0);
        else          out_reg <= in_bit_sync; // len は常に 0
      end
      assign out = out_reg;
    end
  endgenerate

endmodule

