`timescale 1ns/1ps
module tb_short_nolock;
  // 50 MHz クロック（20ns）
  reg clk = 0;
  always #10 clk = ~clk;
  // DUT I/O
  reg  cs      = 0;
  reg  sdo     = 0;
  reg  btn_raw = 0;
  wire miso, o_clk, o_cs, o_cs_en;
  // ★DUTそのまま（実機相当）でも、短縮版でもOK
  // bitshifter #(.DIV(16),    .N(3)) dut (   // ← 短縮試験用に切り替えたい場合
  bitshifter #(.DIV(50_000), .N(8)) dut (     // ← 実機相当（あなたの現行設定）
    .clk(clk), .cs(cs), .sdo(sdo), .btn_raw(btn_raw),
    .miso(miso), .o_clk(o_clk), .o_cs(o_cs), .o_cs_en(o_cs_en)
  );
  // 進捗表示
  initial begin
    $display("DUT params: DIV=%0d, N=%0d", dut.DIV, dut.N);
  end
  // VCD（最小限）
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_short_nolock.clk, tb_short_nolock.cs, tb_short_nolock.btn_raw,
                 tb_short_nolock.o_cs, tb_short_nolock.dut.len,
                 tb_short_nolock.dut.btn_stable, tb_short_nolock.dut.hist);
  end
  // ---- ユーティリティ：クロック何回待つかで制御（sample_en不使用） ----
  task wait_cycles(input integer n);
    integer k; begin
      for (k = 0; k < n; k = k + 1) @(posedge clk);
    end
  endtask
  // ---- デバウンス通過を保証する押下（高/低とも N回以上サンプリングされる長さ）----
  //   ここでは “(N+1)回 sample_en が来るだけ” 十分なクロック数待ちます
  task debounced_press_once;
    integer high_cycles, low_cycles;
    begin
      // (N+1)回分のサンプル＝ (N+1) * DIV クロック
      high_cycles = (dut.N + 1) * dut.DIV;
      low_cycles  = (dut.N + 1) * dut.DIV;
      // ちょいチャタリング（クロック数ベースなので軽め）
      btn_raw <= 1'b0; wait_cycles(8);
      btn_raw <= 1'b1; wait_cycles(5);
      btn_raw <= 1'b0; wait_cycles(6);
      btn_raw <= 1'b1;
      // 高レベルを十分維持 → 立上がり確定
      wait_cycles(high_cycles);
      // 離す（低レベルも十分維持）
      btn_raw <= 1'b0;
      wait_cycles(low_cycles);
    end
  endtask
  // ---- len が +1（15→0ラップ含む）になったか確認 ----
  task expect_len_increment_once;
    reg [3:0] before, expect;
    begin
      before = dut.len;
      // “押下が確定された後”に少し余裕を見て待つ
      wait_cycles(dut.DIV);   // 1回分余裕
      expect = (before == 4'd15) ? 4'd0 : (before + 4'd1);
      if (dut.len !== expect) begin
        $display("[%0t] ERROR: len expected %0d -> %0d, got %0d",
                 $time, before, expect, dut.len);
        $fatal(1);
      end else begin
        $display("[%0t] OK: len incremented to %0d", $time, dut.len);
      end
    end
  endtask
  // ---- len=0 の直結（“サイクル遅延なし”）簡易チェック ----
  task check_len0_direct_path;
    begin
      // もし0でなければ0になるまで押下して回す
      while (dut.len != 4'd0) begin
        debounced_press_once();
        expect_len_increment_once();
      end
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
  // ---- 任意 len での1サイクル遅延パルス確認（ここでは len=1 を検証）----
  task check_len1_single_cycle_pulse;
    begin
      // len を 1 にする
      while (dut.len != 4'd1) begin
        debounced_press_once();
        expect_len_increment_once();
      end
      // csに1サイクルパルス
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
  // ---- メインシーケンス ----
  initial begin
    // POR抜け（DUTは2クロックで抜けるが余裕を持つ）
    wait_cycles(20);
    // 1) len=0 の直結性
    check_len0_direct_path();
    // 2) ボタン1回で len +1
    debounced_press_once();
    expect_len_increment_once();
    // 3) len=1 で 1サイクル遅延パルス
    check_len1_single_cycle_pulse();
    $display("SMOKE TEST (no-lock) PASSED ✅");
    #200;
    $finish;
  end
endmodule
