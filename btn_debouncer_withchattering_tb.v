`timescale 1ns/1ps
module btn_debouncer_tb;
  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg  rst;
  reg  btn_raw;
  wire inc_pulse;
  localparam integer DIV = 8;
  localparam integer N   = 3;
  btn_debouncer #(
    .DIV(DIV),
    .N  (N)
  ) dut (
    .clk      (clk),
    .rst      (rst),
    .btn_raw  (btn_raw),
    .inc_pulse(inc_pulse)
  );
  integer pulse_count = 0;
  reg     inc_pulse_d = 0;
  always @(posedge clk) begin
    if (inc_pulse && inc_pulse_d) begin
      $display("[%0t] ERROR: inc_pulse stuck >1 cycle", $time);
      $fatal;
    end
    inc_pulse_d <= inc_pulse;
  end
  always @(posedge clk) begin
    if (inc_pulse) begin
      pulse_count <= pulse_count + 1;
      $display("[%0t] inc_pulse +1 (count=%0d)", $time, pulse_count+1);
    end
  end
  task chatter(input integer cycles);
    integer i;
    begin
      for (i = 0; i < cycles; i = i + 1) begin
        @(posedge clk);
        btn_raw <= ~btn_raw;
      end
    end
  endtask
  task hold_level(input bit level, input integer cycles);
    integer i;
    begin
      btn_raw <= level;
      for (i = 0; i < cycles; i = i + 1) begin
        @(posedge clk);
      end
    end
  endtask
  initial begin
    rst     = 1'b1;
    btn_raw = 1'b0;
    repeat (10) @(posedge clk);
    rst = 1'b0;
    $display("=== Start btn_debouncer chatter test (DIV=%0d, N=%0d) ===", DIV, N);
    localparam integer SETTLE_CYC = (N*DIV) + 4;
    $display("[%0t] Case1: press with chatter, then release with chatter", $time);
    hold_level(1'b0, 30);
    chatter(30);
    hold_level(1'b1, SETTLE_CYC);
    hold_level(1'b1, 20);
    chatter(20);
    hold_level(1'b0, SETTLE_CYC);
    hold_level(1'b0, 20);
    $display("[%0t] Case2: clean press (no chatter)", $time);
    hold_level(1'b1, SETTLE_CYC);
    hold_level(1'b1, 20);
    hold_level(1'b0, SETTLE_CYC);
    $display("[%0t] Final pulse_count=%0d (expected 2)", $time, pulse_count);
    if (pulse_count !== 2) begin
      $display("[%0t] ERROR: pulse_count mismatch!", $time);
      $fatal;
    end
    $display("=== PASS: chatter test OK ===");
    $finish;
  end
  initial begin
    $dumpfile("btn_debouncer_tb.vcd");
    $dumpvars(0, btn_debouncer_tb);
  end
endmodule
