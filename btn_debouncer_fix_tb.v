`timescale 1ns/1ps
module tb_btn_debouncer;
  localparam integer DIV = 8;
  localparam integer N   = 4;
  reg  clk = 1'b0;
  reg  rst = 1'b1;
  reg  btn_raw = 1'b0;
  wire inc_pulse;
  always #10 clk = ~clk;
  btn_debouncer #(
    .DIV(DIV),
    .N  (N)
  ) dut (
    .clk(clk),
    .rst(rst),
    .btn_raw(btn_raw),
    .inc_pulse(inc_pulse)
  );
  reg  [$clog2((DIV<=1)?1:DIV)-1:0] tb_cnt = '0;
  wire tb_sample_en = (tb_cnt == (DIV-1));
  always @(posedge clk) begin
    if (rst)                 tb_cnt <= '0;
    else if (tb_sample_en)   tb_cnt <= '0;
    else                     tb_cnt <= tb_cnt + 1'b1;
  end
  task wait_samples(input integer k);
    integer i;
    begin
      for (i = 0; i < k; i = i + 1) begin
        @(posedge clk);
        while (!tb_sample_en) @(posedge clk);
      end
    end
  endtask
  task set_and_hold_samples(input bit val, input integer k);
    begin
      while (!tb_sample_en) @(posedge clk);
      @(posedge clk);
      btn_raw = val;
      wait_samples(k);
    end
  endtask
  task short_press_less_than_N;
    begin
      set_and_hold_samples(1'b1, N-1);
      set_and_hold_samples(1'b0, N+1);
    end
  endtask
  task debounced_press_once;
    begin
      set_and_hold_samples(1'b1, N+1);
    end
  endtask
  task debounced_release;
    begin
      set_and_hold_samples(1'b0, N+2);
    end
  endtask
  integer pulse_count = 0;
  always @(posedge clk) if (inc_pulse) pulse_count <= pulse_count + 1;
  reg inc_pulse_d1;
  always @(posedge clk) inc_pulse_d1 <= inc_pulse;
  initial begin
    $dumpfile("tb_btn_debouncer.vcd");
    $dumpvars(0, tb_btn_debouncer);
    btn_raw = 1'b0;
    repeat (5) @(posedge clk);
    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;
    set_and_hold_samples(1'b0, N + 2);
    debounced_press_once();
    wait_samples(2);
    if (pulse_count !== 1) begin
      $display("[ERROR] after press#1: expected pulse_count=1, got %0d", pulse_count);
      $fatal;
    end else $display("[OK] press#1 produced exactly one pulse.");
    set_and_hold_samples(1'b1, N + 2);
    if (pulse_count !== 1) begin
      $display("[ERROR] holding should not add pulses. pulse_count=%0d", pulse_count);
      $fatal;
    end else $display("[OK] holding added no extra pulses.");
    debounced_release();
    if (pulse_count !== 1) begin
      $display("[ERROR] release should not add pulses. pulse_count=%0d", pulse_count);
      $fatal;
    end else $display("[OK] release added no pulse.");
    short_press_less_than_N();
    if (pulse_count !== 1) begin
      $display("[ERROR] short press must not produce a pulse. pulse_count=%0d", pulse_count);
      $fatal;
    end else $display("[OK] short press was correctly ignored.");
    debounced_press_once();
    wait_samples(2);
    if (pulse_count !== 2) begin
      $display("[ERROR] after press#2: expected pulse_count=2, got %0d", pulse_count);
      $fatal;
    end else $display("[OK] press#2 produced exactly one pulse (total 2).");
    $display("[PASS] All scenarios passed. Total pulses = %0d", pulse_count);
    $finish;
  end
endmodule
