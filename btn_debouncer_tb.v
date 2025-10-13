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
    .N(N)
  ) dut (
    .clk(clk),
    .rst(rst),
    .btn_raw(btn_raw),
    .inc_pulse(inc_pulse)
  );
  reg [31:0] tb_cnt = 0;
  wire tb_sample_en = (tb_cnt == (DIV-1));
  always @(posedge clk) begin
    if (rst)            tb_cnt <= 0;
    else if (tb_sample_en) tb_cnt <= 0;
    else                tb_cnt <= tb_cnt + 1;
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
  task chatter_half_periods(input integer halves);
    integer i;
    begin
      for (i = 0; i < halves; i = i + 1) begin
        repeat (DIV/2) @(posedge clk);
        btn_raw = ~btn_raw;
      end
    end
  endtask
  integer pulse_count = 0;
  always @(posedge clk) begin
    if (inc_pulse) pulse_count <= pulse_count + 1;
  end
  reg inc_pulse_d1;
  always @(posedge clk) inc_pulse_d1 <= inc_pulse;
  initial begin
    $dumpfile("btn_debouncer_tb.vcd");
    $dumpvars(0, tb_btn_debouncer);
    btn_raw = 1'b0;
    repeat (5) @(posedge clk);
    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;
    set_and_hold_samples(1'b0, N + 2);
    chatter_half_periods(3);
    set_and_hold_samples(1'b1, N + 1);
    wait_samples(3);
    if (pulse_count !== 1) begin
      $display("[ERROR] Expected pulse_count=1 after debounced press, got %0d", pulse_count);
      $fatal;
    end else begin
      $display("[OK] Debounced press generated exactly one pulse.");
    end
    set_and_hold_samples(1'b1, N + 3);
    if (pulse_count !== 1) begin
      $display("[ERROR] Holding should not create extra pulses. pulse_count=%0d", pulse_count);
      $fatal;
    end else begin
      $display("[OK] Holding produced no extra pulses.");
    end
    chatter_half_periods(2);
    set_and_hold_samples(1'b0, N + 2);
    if (pulse_count !== 1) begin
      $display("[ERROR] Release (with/without chatter) must not create pulses. pulse_count=%0d", pulse_count);
      $fatal;
    end else begin
      $display("[OK] Release created no pulses.");
    end
    set_and_hold_samples(1'b1, N-1);
    set_and_hold_samples(1'b0, N+1);
    if (pulse_count !== 1) begin
      $display("[ERROR] Short press should be ignored (no new pulse). pulse_count=%0d", pulse_count);
      $fatal;
    end else begin
      $display("[OK] Short press was correctly ignored.");
    end
    $display("[PASS] All scenarios passed. Total pulses = %0d", pulse_count);
    $finish;
  end
endmodule
