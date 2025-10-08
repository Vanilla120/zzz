// ============================================================================
// 3) 配線例 top（修正版：これをトップにしてください）
//    - 外部 rst を 2FF 同期して rst_sync を生成
//    - 物理ボタン btn_raw を整形して 1クロックの btn_pulse を生成（内部のみ）
//    - 可変遅延シフタ xbitshifter に接続
//    - これをトップにすることで IOB パッキング警告の主因（外部IOが制御/データを同時に駆動）を回避
// ============================================================================
(* top *)
module top_example(
  input  wire clk,       // ボードのクロック（専用GCLKピンへ割当推奨）
  input  wire rst,       // 外部リセット（押下で1；非同期入力想定→内部で同期化）
  input  wire btn_raw,   // 物理ボタン（非同期入力）
  input  wire in_bit,    // 入力ビット列
  output wire out        // 遅延後出力
);
  // ---- 外部リセットの 2FF 同期（完全同期リセット運用）
  reg rst_ff1, rst_ff2;
  always @(posedge clk) begin
    rst_ff1 <= rst;
    rst_ff2 <= rst_ff1;
  end
  wire rst_sync = rst_ff2;

  // ---- ボタン整形（Nはチャタ時間とクロックに応じて調整）
  // 例：16MHzで N=128 → 約8us程度の安定判定窓
  wire btn_pulse;
  btn_filter_oneshot #(.N(128)) u_btn (
    .clk      (clk),
    .rst      (rst_sync),
    .btn_in   (btn_raw),
    .btn_pulse(btn_pulse)
  );

  // ---- 可変遅延シフタ
  xbitshifter #(
    .MAX_LEN (15),
    .RES_INIT(0)
  ) u_shifter (
    .clk      (clk),
    .rst      (rst_sync),
    .in_bit   (in_bit),
    .btn_pulse(btn_pulse),
    .out      (out),
    .out_en   ()        // 使わなければ未接続でOK
  );
endmodule


// ============================================================================
// 1) Button Debounce + One-shot (no adders / no counters)
//    - 2FF同期 → N連続一致で安定判定（シフト履歴のみ） → 立上り1クロックパルス
//    - 加算・減算を使わないので carry 由来の警告を誘発しにくい
//    - N は 2 以上を推奨（チャタ時間とクロック周期に応じて調整）
// ============================================================================
module btn_filter_oneshot #(
  parameter integer N = 16  // 連続サンプル数（クロック数, 推奨 >= 2）
)(
  input  wire clk,
  input  wire rst,       // 同期リセット（正論理）
  input  wire btn_in,    // 物理ボタン入力（非同期）
  output wire btn_pulse  // 1クロック幅パルス（立上りのみ）
);
  // 2段同期でメタスタ回避
  reg s1, s2;
  always @(posedge clk) begin
    if (rst) begin
      s1 <= 1'b0;
      s2 <= 1'b0;
    end else begin
      s1 <= btn_in;
      s2 <= s1;
    end
  end

  // N段シフト履歴（加算なし）
  // N==1 のときも動くようにガード（全1/全0 判定は s2 を使う）
  generate
    if (N >= 2) begin : GEN_HIST
      reg [N-1:0] hist;
      always @(posedge clk) begin
        if (rst) hist <= {N{1'b0}};
        else     hist <= {hist[N-2:0], s2};
      end
      wire all_one  = &hist;
      wire all_zero = ~|hist;

      // 安定状態を保持
      reg stable;
      always @(posedge clk) begin
        if (rst)           stable <= 1'b0;
        else if (all_one)  stable <= 1'b1;
        else if (all_zero) stable <= 1'b0;
        // 中間は保持
      end

      // 立上りエッジ検出で1クロックパルス
      reg stable_d;
      always @(posedge clk) begin
        if (rst) stable_d <= 1'b0;
        else     stable_d <= stable;
      end
      assign btn_pulse = (stable & ~stable_d);

    end else begin : GEN_MINIMAL  // N == 1 の簡略系
      // s2 が 1 になった瞬間だけ 1クロックのパルス
      reg s2_d;
      always @(posedge clk) begin
        if (rst) s2_d <= 1'b0;
        else     s2_d <= s2;
      end
      assign btn_pulse = (s2 & ~s2_d);
    end
  endgenerate
endmodule


// ============================================================================
// 2) 可変ビット遅延シフタ（ForgeFPGA向け 簡潔版）
//    - ボタンは 1クロック幅の btn_pulse 前提（上のモジュールで整形）
//    - 算術は len の +1 のみ（キャリー源を極小化）
//    - 出力選択は pipe[len] の単純MUX（減算なし）
// ============================================================================
module xbitshifter #(
  parameter integer MAX_LEN  = 15,  // 遅延長：0..MAX_LEN
  parameter integer RES_INIT = 0    // リセット時の out 初期値（0 or 1）
)(
  input  wire clk,        // クロック
  input  wire rst,        // 同期リセット（正論理）
  input  wire in_bit,     // シリアル入力
  input  wire btn_pulse,  // 1クロック幅インクリメントパルス（内部生成推奨）
  output wire out,        // 遅延後ビット
  output wire out_en      // 常時 '1'
);
  // 入力同期（外部 in_bit を1段取り込み）
  reg in_bit_sync;
  always @(posedge clk) begin
    if (rst) in_bit_sync <= 1'b0;
    else     in_bit_sync <= in_bit;
  end

  // 遅延長カウンタ（0 → MAX_LEN → 0 …）
  localparam integer LEN_W = (MAX_LEN > 0) ? $clog2(MAX_LEN+1) : 1;
  reg [LEN_W-1:0] len;
  always @(posedge clk) begin
    if (rst) begin
      len <= {LEN_W{1'b0}};
    end else if (btn_pulse) begin
      if (len == MAX_LEN[LEN_W-1:0]) len <= {LEN_W{1'b0}};
      else                           len <= len + 1'b1;  // ← 唯一の加算
    end
  end

  // シフトレジスタ（MAX_LEN==0/1/>=2 の全ケースをケア）
  generate
    if (MAX_LEN >= 2) begin : GEN_SHIFT_GE2
      reg [MAX_LEN-1:0] shift_reg;
      always @(posedge clk) begin
        if (rst) shift_reg <= {MAX_LEN{1'b0}};
        else     shift_reg <= {shift_reg[MAX_LEN-2:0], in_bit_sync};
      end
      // 出力選択：pipe[0]=in_bit_sync, pipe[k>0]=shift_reg[k-1]
      wire [MAX_LEN:0] pipe = {shift_reg, in_bit_sync};

      reg out_reg;
      always @(posedge clk) begin
        if (rst) out_reg <= (RES_INIT != 0);
        else     out_reg <= pipe[len];
      end
      assign out    = out_reg;
      assign out_en = 1'b1;

    end else if (MAX_LEN == 1) begin : GEN_SHIFT_EQ1
      reg shift1;
      always @(posedge clk) begin
        if (rst) shift1 <= 1'b0;
        else     shift1 <= in_bit_sync;
      end
      wire [1:0] pipe = {shift1, in_bit_sync};

      reg out_reg;
      always @(posedge clk) begin
        if (rst) out_reg <= (RES_INIT != 0);
        else     out_reg <= pipe[len];
      end
      assign out    = out_reg;
      assign out_en = 1'b1;

    end else begin : GEN_SHIFT_EQ0  // MAX_LEN == 0（遅延なし）
      reg out_reg;
      always @(posedge clk) begin
        if (rst) out_reg <= (RES_INIT != 0);
        else     out_reg <= in_bit_sync; // len は常に 0
      end
      assign out    = out_reg;
      assign out_en = 1'b1;
    end
  endgenerate
endmodule
