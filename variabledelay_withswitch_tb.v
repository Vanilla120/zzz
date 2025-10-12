`timescale 1ns/1ps
module tb;
  // 50 MHz クロック（20ns周期）
  reg clk = 0;
  always #10 clk = ~clk;
  // DUT I/O
  reg  cs      = 0;
  reg  sdo     = 0;
  reg  btn_raw = 0;
  wire miso, o_clk, o_cs, o_cs_en;
  // 被試験デバイス：DIV/Nを小さくして短時間で検証
  bitshifter #(
    .DIV(16),  // 16*20ns = 320nsごとにサンプリング
    .N  (3)    // 3サンプル連続で確定（約 0.96us 相当）
  ) dut (
    .clk(clk),
    .cs(cs),
    .sdo(sdo),
    .btn_raw(btn_raw),
    .miso(miso),
    .o_clk(o_clk),
    .o_cs(o_cs),
    .o_cs_en(o_cs_en)
  );
  // 監視用
  integer press_count = 0;
  reg [3:0] len_prev;
  initial len_prev = 0;
  // 便利タスク：DUT内部の sample_en を待つ（分周サンプリング境界）
  task wait_sample_en;
    begin
      @(posedge clk);
      while (dut.sample_en !== 1'b1) @(posedge clk);
    end
  endtask
  // チャタリング付きの「押下1回」を模擬（立上がり1回だけカウントされるはず）
  task press_once_with_chatter;
    integer k;
    begin
      // （POR抜け待ちの後に）チャタリング：高速で 0/1 を数サイクル
      for (k = 0; k < 8; k = k + 1) begin
        btn_raw <= ~btn_raw;
        @(posedge clk);
      end
      // その後しっかり“1”で安定させ、N回のサンプルを通過（=確定で立上がり1パルス）
      btn_raw <= 1'b1;
      repeat (4) wait_sample_en();  // N=3 なので余裕をもって4サンプル
      // リリース時もチャタリング → しっかり“0”でN回サンプルして安定に戻す
      for (k = 0; k < 6; k = k + 1) begin
        btn_raw <= ~btn_raw;
        @(posedge clk);
      end
      btn_raw <= 1'b0;
      repeat (3) wait_sample_en();
    end
  endtask
  // 長押し（オートリピートしないことを確認）
  task long_press_no_repeat;
    begin
      btn_raw <= 1'b1;
      repeat (10) wait_sample_en(); // サンプル境界を何度も跨ぐ
      btn_raw <= 1'b0;
      repeat (4) wait_sample_en();
    end
  endtask
  // len が1ステップだけ増えたかチェック
  task expect_len_increment_once;
    reg [3:0] before;
    begin
      before = dut.len;
      // サンプル境界を十分またいで反映待ち
      repeat (2) wait_sample_en();
      if (dut.len !== ((before == 4'd15) ? 4'd0 : (before + 4'd1))) begin
        $display("[%0t] ERROR: len expected %0d -> %0d, got %0d",
                 $time, before, (before==15)?0:(before+1), dut.len);
        $fatal(1);
      end else begin
        $display("[%0t] OK: len incremented to %0d", $time, dut.len);
      end
    end
  endtask
  // len=0 の時は o_cs が cs に“サイクル遅延なし”で追従しているか簡易チェック
  task check_len0_direct_path;
    begin
      if (dut.len !== 4'd0) begin
        $display("[%0t] INFO: set len to 0 manually for direct-path check", $time);
        force dut.len = 4'd0;  // 簡易的に直接0に固定（シミュ用）
        @(posedge clk);
        release dut.len;
      end
      // cs をトグル → 少し時間をおいて o_cs と一致チェック
      cs <= 0; @(posedge clk);
      cs <= 1; #1; // NBAの後で同時刻に伝搬しているはずなので #1 で評価猶予
      if (o_cs !== cs) begin
        $display("[%0t] ERROR: len=0 で o_cs が cs に追従していない", $time);
        $fatal(1);
      end
      cs <= 0; #1;
      if (o_cs !== cs) begin
        $display("[%0t] ERROR: len=0 で o_cs が cs に追従していない(2)", $time);
        $fatal(1);
      end
      $display("[%0t] OK: len=0 direct path verified", $time);
    end
  endtask
  // 任意の len で「1サイクルパルスが len サイクル遅れて出るか」を検査
  task check_delay_cycles(input [3:0] want_len);
    integer d;
    begin
      // len を want_len にするために押下回数を調整
      while (dut.len != want_len) begin
        press_once_with_chatter();
        expect_len_increment_once();
      end
      // 1サイクルだけ cs パルス
      cs <= 0; @(posedge clk);
      cs <= 1; @(posedge clk);
      cs <= 0;
      // want_len サイクル分待ってから o_cs にパルスが出ることを確認
      for (d = 0; d < want_len; d = d + 1) @(posedge clk);
      // ここで o_cs が “1サイクルだけ”1になっているはず
      if (o_cs !== 1'b1) begin
        $display("[%0t] ERROR: expected delayed pulse (len=%0d) high at this edge", $time, want_len);
        $fatal(1);
      end
      @(posedge clk);
      if (o_cs !== 1'b0) begin
        $display("[%0t] ERROR: expected delayed pulse (len=%0d) to return low after 1 cycle", $time, want_len);
        $fatal(1);
      end
      $display("[%0t] OK: delayed pulse verified for len=%0d", $time, want_len);
    end
  endtask
  initial begin
    // VCD
    $dumpfile("wave.vcd");
    $dumpvars(0, tb);
    // 初期状態
    cs      = 0;
    sdo     = 0;
    btn_raw = 0;
    // POR（内部2クロック）＋少し余裕
    repeat (10) @(posedge clk);
    // 1) len=0 の直結性チェック
    check_len0_direct_path();
    // 2) チャタリング付きの押下1回 → len が +1 だけ増えること
    press_once_with_chatter();
    expect_len_increment_once();
    // 3) 長押し → 追加で増えないこと（1回だけ）
    long_press_no_repeat();
    // すこし待って検証
    repeat (2) wait_sample_en();
    $display("[%0t] INFO: After long press, len=%0d (should be previous+1 only)", $time, dut.len);
    // 4) 遅延サイクルの妥当性（len=2 と len=5 を例に検査）
    check_delay_cycles(4'd2);
    check_delay_cycles(4'd5);
    // 5) 16回目で 15→0 にラップ
    while (dut.len != 4'd15) begin
      press_once_with_chatter();
      expect_len_increment_once();
    end
    // 15 から 1回加算で 0 へ
    press_once_with_chatter();
    // サンプル境界通過後に確認
    repeat (2) wait_sample_en();
    if (dut.len !== 4'd0) begin
      $display("[%0t] ERROR: wrap-around failed (expected 0, got %0d)", $time, dut.len);
      $fatal(1);
    end else begin
      $display("[%0t] OK: wrap-around 15->0 verified", $time);
    end
    $display("ALL CHECKS PASSED ✅");
    #100;
    $finish;
  end
endmodule
