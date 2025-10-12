`timescale 1ns/1ps
module tb_short_nolock;
  // 50 MHz
  reg clk = 0; always #10 clk = ~clk;
  // DUT I/O
  reg  cs = 0, sdo = 0, btn_raw = 0;
  wire miso, o_clk, o_cs, o_cs_en;
  // ★DUT（実機相当でも短縮でもOK）
  // bitshifter #(.DIV(16),    .N(3)) dut (
  bitshifter #(.DIV(50_000), .N(8)) dut (
    .clk(clk), .cs(cs), .sdo(sdo), .btn_raw(btn_raw),
    .miso(miso), .o_clk(o_clk), .o_cs(o_cs), .o_cs_en(o_cs_en)
  );
  // 進捗
  initial $display("DUT params: DIV=%0d, N=%0d", dut.DIV, dut.N);
  // VCD（最小）
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_short_nolock.clk, tb_short_nolock.cs, tb_short_nolock.btn_raw,
                 tb_short_nolock.o_cs, tb_short_nolock.dut.len,
                 tb_short_nolock.dut.btn_stable, tb_short_nolock.dut.hist);
  end
  // ★ タスク内で使う一時レジスタをモジュール直下に移動
  reg [3:0] tmp_before;
  reg [3:0] tmp_expect;
  // 固定クロック待ち
  task wait_cycles(input integer n); integer k; begin
    for (k=0; k<n; k=k+1) @(posedge clk);
  end endtask
  // デバウンス通過を保証する押下（sample_enは使わない）
  task debounced_press_once;
    integer high_cycles, low_cycles;
    begin
      high_cycles = (dut.N + 1) * dut.DIV;
      low_cycles  = (dut.N + 1) * dut.DIV;
      btn_raw <= 1'b0; wait_cycles(8);
      btn_raw <= 1'b1; wait_cycles(5);
      btn_raw <= 1'b0; wait_cycles(6);
      btn_raw <= 1'b1;
      wait_cycles(high_cycles); // 高で十分維持
      btn_raw <= 1'b0;
      wait_cycles(low_cycles);  // 低で十分維持
    end
  endtask
  // len +1（15→0含む）検証：★タスク内宣言ナシ
  task expect_len_increment_once;
    begin
      tmp_before = dut.len;
      wait_cycles(dut.DIV);  // 反映待ちに少し余裕
      tmp_expect = (tmp_before == 4'd15) ? 4'd0 : (tmp_before + 4'd1);
      if (dut.len !== tmp_expect) begin
        $display("[%0t] ERROR: len expected %0d -> %0d, got %0d",
                 $time, tmp_before, tmp_expect, dut.len);
        $fatal(1);
      end else begin
        $display("[%0t] OK: len incremented to %0d", $time, dut.len);
      end
    end
  endtask
  // len=0 直結性
  task check_len0_direct_path;
    begin
      while (dut.len != 4'd0) begin
        debounced_press_once(); expect_len_increment_once();
      end
      cs <= 0; @(posedge clk);
      cs <= 1; #1;
      if (o_cs !== cs) begin
        $display("[%0t] ERROR: len=0 direct follow failed (rise)", $time); $fatal(1);
      end
      cs <= 0; #1;
      if (o_cs !== cs) begin
        $display("[%0t] ERROR: len=0 direct follow failed (fall)", $time); $fatal(1);
      end
      $display("[%0t] OK: len=0 direct path verified", $time);
    end
  endtask
  // len=1 で1サイクル遅延
  task check_len1_single_cycle_pulse;
    begin
      while (dut.len != 4'd1) begin
        debounced_press_once(); expect_len_increment_once();
      end
      cs <= 0; @(posedge clk);
      cs <= 1; @(posedge clk);
      cs <= 0;
      @(posedge clk);
      if (o_cs !== 1'b1) begin
        $display("[%0t] ERROR: delayed pulse missing at len=1", $time); $fatal(1);
      end
      @(posedge clk);
      if (o_cs !== 1'b0) begin
        $display("[%0t] ERROR: delayed pulse not 1-cycle at len=1", $time); $fatal(1);
      end
      $display("[%0t] OK: delayed 1-cycle pulse verified at len=1", $time);
    end
  endtask
  // メイン
  initial begin
    wait_cycles(20);              // POR抜け
    check_len0_direct_path();     // 1)
    debounced_press_once();       // 2)
    expect_len_increment_once();
    check_len1_single_cycle_pulse(); // 3)
    $display("SMOKE TEST (no-lock) PASSED ✅");
    #200; $finish;
  end
endmodule
