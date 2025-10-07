// 可変遅延(0..15)のシリアル・ビットシフタ
// - ボタンを押すたびに len が 0→1→…→15→0 と巡回
// - len=0 のときは入力 in_bit をそのまま out に出す（無遅延）
// - len>0 のときは shift_reg[len-1] を out に出す（len クロック分の遅延）
//
// ★調整ポイント：CLOCK_HZ をボードの外部クロックに合わせる
//   例: 12MHz → 12_000_000, 24MHz → 24_000_000
//
// ForgeFPGAピン属性は例として ext_clk/in_bit/btn/out/out_en に付与。
// 必要に応じてポート名やピン割り当ては上位で行ってください。

(* top *)
module bitshifter_btn #(
  parameter integer MAX_LEN   = 15,         // 遅延の最大値(0..MAX_LEN)。15固定要求に合わせています
  parameter integer CLOCK_HZ  = 12_000_000, // ★要調整: ボードのクロック周波数(Hz)
  parameter integer DEBOUNCE_MS = 10        // デバウンス時間 [ms]
)(
  (* iopad_external_pin *) input  wire ext_clk,
  (* iopad_external_pin *) input  wire in_bit,
  (* iopad_external_pin *) input  wire btn,     // プッシュボタン（アクティブHigh想定）
  (* iopad_external_pin *) output wire out,
  (* iopad_external_pin *) output wire out_en
);

  // ========= 1) ボタン同期化 + デバウンス =========
  // 2段同期化
  reg btn_sync1, btn_sync2;
  always @(posedge ext_clk) begin
    btn_sync1 <= btn;
    btn_sync2 <= btn_sync1;
  end

  // デバウンス用カウンタ
  localparam integer DB_CNT_MAX = (CLOCK_HZ/1000)*DEBOUNCE_MS;
  localparam integer DB_CNT_W   = $clog2(DB_CNT_MAX+1);

  reg [DB_CNT_W-1:0] db_cnt = 0;
  reg btn_state = 1'b0;        // デバウンス後の安定状態
  reg btn_state_prev = 1'b0;   // 立下り/立上り検出用

  wire btn_changed = (btn_sync2 != btn_state);
  always @(posedge ext_clk) begin
    if (btn_changed) begin
      // 変化を検出したらカウンタ再スタート
      db_cnt <= DB_CNT_MAX[DB_CNT_W-1:0];
    end else if (db_cnt != 0) begin
      db_cnt <= db_cnt - 1'b1;
      if (db_cnt == 1) begin
        // 所定時間安定 → 状態を確定
        btn_state <= btn_sync2;
      end
    end
    btn_state_prev <= btn_state;
  end

  wire btn_rise = (btn_state == 1'b1) && (btn_state_prev == 1'b0); // 立ち上がりエッジ

  // ========= 2) 遅延長カウンタ len: 0..MAX_LEN =========
  localparam integer LEN_W = $clog2(MAX_LEN+1); // 0..MAX_LEN の表現に必要
  reg [LEN_W-1:0] len = {LEN_W{1'b0}};          // 初期0（無遅延）

  always @(posedge ext_clk) begin
    if (btn_rise) begin
      if (len == MAX_LEN[LEN_W-1:0]) len <= {LEN_W{1'b0}};
      else                           len <= len + 1'b1;
    end
  end

  // ========= 3) シフトレジスタ（幅 MAX_LEN） =========
  // len=0 でも動かしておく（将来のlen>0にすぐ追従）
  reg [MAX_LEN-1:0] shift_reg = {MAX_LEN{1'b0}};
  always @(posedge ext_clk) begin
    // 左シフト（LSB側に in_bit を注入）
    shift_reg <= {shift_reg[MAX_LEN-2:0], in_bit};
  end

  // ========= 4) 出力選択 =========
  // len=0 → 直結 (in_bit)
  // len>0 → shift_reg[len-1]
  reg out_sel;
  always @* begin
    case (len)
      // 0 は無遅延で in_bit をそのまま出力
      {LEN_W{1'b0}}: out_sel = in_bit;
      default: begin
        // 可変インデックスの安全な合成のため case で展開
        // len は 1..MAX_LEN
        // tap = len-1 → 0..(MAX_LEN-1)
        case (len - 1'b1)
          // MAX_LEN=15 を前提に 0..14 を列挙
          4'd0:  out_sel = shift_reg[0];
          4'd1:  out_sel = shift_reg[1];
          4'd2:  out_sel = shift_reg[2];
          4'd3:  out_sel = shift_reg[3];
          4'd4:  out_sel = shift_reg[4];
          4'd5:  out_sel = shift_reg[5];
          4'd6:  out_sel = shift_reg[6];
          4'd7:  out_sel = shift_reg[7];
          4'd8:  out_sel = shift_reg[8];
          4'd9:  out_sel = shift_reg[9];
          4'd10: out_sel = shift_reg[10];
          4'd11: out_sel = shift_reg[11];
          4'd12: out_sel = shift_reg[12];
          4'd13: out_sel = shift_reg[13];
          4'd14: out_sel = shift_reg[14];
          default: out_sel = 1'b0; // 到達しない
        endcase
      end
    endcase
  end

  assign out    = out_sel;
  assign out_en = 1'b1;

endmodule

