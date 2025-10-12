`timescale 1ns/1ps
module tb;
  // 50 MHz
  reg clk = 0;
  always #10 clk = ~clk;
  reg  cs      = 0;
  reg  sdo     = 0;
  reg  btn_raw = 0;
  wire miso, o_clk, o_cs, o_cs_en;
  // 被試験DUT（シム短縮用にDIV/Nを小さく）
  bitshifter #(.DIV(16), .N(3)) dut (
    .clk(clk), .cs(cs), .sdo(sdo), .btn_raw(btn_raw),
    .miso(miso), .o_clk(o_clk), .o_cs(o_cs), .o_cs_en(o_cs_en)
  );
  // ★ タスク内で使う一時変数をモジュール直下で宣言
  reg [3:0] tmp_before;
  // sample_en待ち
  task wait_sample_en;
    begin
      @(posedge clk);
      while (dut.sample_en !== 1'b1) @(posedge clk);
    end
  endtask
  // チャタリング付き押下1回
  task press_once_with_chatter;
    integer k;
    begin
      for (k = 0; k < 8; k = k + 1) begin
        btn_raw <= ~btn_raw; @(posedge clk);
      end
      btn_raw <= 1'b1;
      repeat (4) wait_sample_en();   // N=3想定
      for (k = 0; k < 6; k = k + 1) begin
        btn_raw <= ~btn_raw; @(posedge clk);
      end
      btn_raw <= 1'b0;
      repeat (3) wait_sample_en();
    end
  endtask
  // 長押し（オートリピートしない確認）
  task long_press_no_repeat;
    begin
      btn_raw <= 1'b1;
      repeat (10) wait_sample_en();
      btn_raw <= 1'b0;
      repeat (4)  wait_sample_en();
    end
  endtask
  // ★ len が1だけ増えたか確認（モジュール変数 tmp_before を使用）
  task expect_len_increment_once;
    begin
      tmp_before = dut.len;
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
  // len=0 の直結性
  task check_len0_direct_path;
    begin
      if (dut.len !== 4'd0) begin
        $display("[%0t] INFO: set len to 0 manually for direct-path check", $time);
        force dut.len = 4'd0;
        @(posedge clk);
        release dut.len;
      end
      cs <= 0; @(posedge clk);
      cs <= 1; #1;
      if (o_cs !== cs) begin
        $display("[%0t] ERROR: len=0 direct follow failed", $time); $fatal(1);
      end
      cs <= 0; #1;
      if (o_cs !== cs) begin
        $display("[%0t] ERROR: len=0 direct follow failed(2)", $time); $fatal(1);
      end
      $display("[%0t] OK: len=0 direct path verified", $time);
    end
  endtask
  // 指定lenで1サイクル遅延パルス確認
  task check_delay_cycles(input [3:0] want_len);
    integer d;
    begin
      while (dut.len != want_len) begin
        press_once_with_chatter();
        expect_len_increment_once();
      end
      cs <= 0; @(posedge clk);
      cs <= 1; @(posedge clk);
      cs <= 0;
      for (d = 0; d < want_len; d = d + 1) @(posedge clk);
      if (o_cs !== 1'b1) begin
        $display("[%0t] ERROR: delayed pulse (len=%0d) not high", $time, want_len); $fatal(1);
      end
      @(posedge clk);
      if (o_cs !== 1'b0) begin
        $display("[%0t] ERROR: delayed pulse (len=%0d) not 1-cycle", $time, want_len); $fatal(1);
      end
      $display("[%0t] OK: delayed pulse verified (len=%0d)", $time, want_len);
    end
  endtask
  initial begin
    $dumpfile("wave.vcd"); $dumpvars(0, tb);
    cs=0; sdo=0; btn_raw=0;
    repeat (10) @(posedge clk);          // POR抜け
    check_len0_direct_path();
    press_once_with_chatter(); expect_len_increment_once();
    long_press_no_repeat(); repeat (2) wait_sample_en();
    check_delay_cycles(4'd2);
    check_delay_cycles(4'd5);
    while (dut.len != 4'd15) begin
      press_once_with_chatter(); expect_len_increment_once();
    end
    press_once_with_chatter(); repeat (2) wait_sample_en();
    if (dut.len !== 4'd0) begin
      $display("[%0t] ERROR: wrap 15->0 failed, got %0d", $time, dut.len); $fatal(1);
    end
    $display("ALL CHECKS PASSED ✅");
    #100; $finish;
  end
endmodule
