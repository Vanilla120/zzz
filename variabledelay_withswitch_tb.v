`timescale 1ns/1ps
module tb_short;
  // 50 MHz クロック（20ns周期）
  reg clk = 0;
  always #10 clk = ~clk;
  // DUT I/O
  reg  cs      = 0;
  reg  sdo     = 0;
  reg  btn_raw = 0;
  wire miso, o_clk, o_cs, o_cs_en;
  // 被試験デバイス：短時間シム用に小さな DIV/N でインスタンス
  bitshifter #(
    .DIV(16),  // 16クロックごとに sample_en（=約320ns間隔）
    .N  (3)    // 3サンプル連続一致で確定（約0.96us相当）
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
  // 監視・一時変数（タスクで使用）
  reg [3:0] tmp_before;
  // ---- 進捗/パラメータ表示 ----
  initial begin
    $display("DUT params: DIV=%0d, N=%0d", dut.DIV, dut.N);
  end
  // ---- VCD（必要最小限 & 短時間のみ）----
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_short.clk, tb_short.cs, tb_short.btn_raw,
                 tb_short.o_cs, tb_short.dut.len, tb_short.dut.sample_en,
                 tb_short.dut.btn_stable, tb_short.dut.hist);
    // 最初の 20us だけ記録（十分）
    #0      $dumpon;
    #20000  $dumpoff;
  end
  // ---- sample_en 待ち（ウォッチドッグ付きで永久待ちを回避）----
  task wait_sample_en;
    integer guard;
    begin
      guard = 0;
      @(posedge clk);
      while (dut.sample_en !== 1'b1) begin
        @(posedge clk);
        guard = guard + 1;
        if (guard > 10000) begin
          $display("[%0t] TIMEOUT waiting for sample_en (DIV=%0d,N=%0d)",
                   $time, dut.DIV, dut.N);
          $fatal(1);
        end
      end
    end
  endtask
  // ---- “軽め”の押下（チャタリング少なめ）----
  task press_once_light;
    integer k;
    begin
      // ちょいチャタリング
      for (k = 0; k < 4; k = k + 1) begin
        btn_raw <= ~btn_raw; @(posedge clk);
      end
      // 安定 1 にして N サンプル通過
      btn_raw <= 1'b1;
      repeat (3) wait_sample_en();
      // リリース側も安定 0 に戻す
      btn_raw <= 1'b0;
      repeat (2) wait_sample_en();
    end
  endtask
  // ---- len が +1（15→0 でラップ）になったか確認 ----
  task expect_len_increment_once;
    begin
      tmp_before = dut.len;
      // 反映のためサンプル2回程度待つ
      repeat (2) wait_sample_en();
      if (dut.len !== ((tmp_before == 4'd15) ? 4'd0 : (tmp_before + 4'd1))) begin
        $display("[%0t] ERROR: len expected %0d -> %0d, got %0d",
                 $time, tmp_before, (tmp_before==15)?0:(tmp_before+1), dut.len);
        $fatal(1);
      end else begin
        $display("[%0t] OK: len incremented to %0d", $time, dut.len);
      end
    end
  endtask
  // ---- len=0 の直結（サイクル遅延なし）を簡易チェック ----
  task check_len0_direct_path;
    begin
      // 念のため len が 0 でない場合は軽く戻す（強制は使わない）
      while (dut.len != 4'd0) begin
        press_once_light(); expect_len_increment_once();
        if (dut.len == 4'd0) disable fork;
      end
      // cs をトグルして、#1 で o_cs 追従を確認
      cs <= 0; @(posedge clk);
      cs <= 1; #1;
      if (o_cs !== cs) begin
        $display("[%0t] ERROR: len=0 direct follow failed (rise)", $time);
        $fatal(1);
      end
      cs <= 0; #1;
      if (o_cs !== cs) begin
        $display("[%0t] ERROR: len=0 direct follow failed (fall)", $time);
        $fatal(1);
      end
      $display("[%0t] OK: len=0 direct path verified", $time);
    end
  endtask
  // ---- len=1 で 1サイクル遅延パルスが出るか ----
  task check_len1_single_cycle_pulse;
    begin
      // len を 1 にする
      while (dut.len != 4'd1) begin
        press_once_light(); expect_len_increment_once();
      end
      // cs に 1サイクルパルス
      cs <= 0; @(posedge clk);
      cs <= 1; @(posedge clk);
      cs <= 0;
      // len=1 なので 1サイクル後に o_cs==1、さらにその次で 0
      @(posedge clk);
      if (o_cs !== 1'b1) begin
        $display("[%0t] ERROR: delayed pulse missing at len=1 (high)", $time);
        $fatal(1);
      end
      @(posedge clk);
      if (o_cs !== 1'b0) begin
        $display("[%0t] ERROR: delayed pulse not 1-cycle at len=1", $time);
        $fatal(1);
      end
      $display("[%0t] OK: delayed 1-cycle pulse verified at len=1", $time);
    end
  endtask
  // ---- テストシーケンス ----
  initial begin
    // POR 抜け待ち（DUTは2クロックで抜けるが余裕を持って）
    repeat (10) @(posedge clk);
    // 1) len=0 の直結性
    check_len0_direct_path();
    // 2) ボタン1回で len が +1
    press_once_light();
    expect_len_increment_once();
    // 3) len=1 で 1サイクル遅延パルス
    check_len1_single_cycle_pulse();
    $display("SMOKE TEST PASSED ✅");
    #200; // 少し待って終了
    $finish;
  end
endmodule
