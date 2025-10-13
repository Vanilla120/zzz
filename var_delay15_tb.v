`timescale 1ns/1ps
module var_delay15_tb;
  reg  clk;
  reg  rst;
  reg  in_sig;
  reg  inc_pulse;
  wire out_sig;
  var_delay15 dut (
    .clk(clk),
    .rst(rst),
    .in_sig(in_sig),
    .inc_pulse(inc_pulse),
    .out_sig(out_sig)
  );
  initial clk = 1'b0;
  always #5 clk = ~clk;
  reg [7:0] cnt;
  always @(posedge clk) begin
    if (rst) begin
      cnt    <= 8'd0;
      in_sig <= 1'b0;
    end else begin
      cnt    <= cnt + 8'd1;
      in_sig <= cnt[2] ^ cnt[0];
    end
  end
  integer k;
  initial begin
    inc_pulse = 1'b0;
    wait (rst == 1'b0);
    repeat (10) @(posedge clk);
    for (k = 0; k < 20; k = k + 1) begin
      repeat (7) @(posedge clk);
      inc_pulse <= 1'b1;
      @(posedge clk);
      inc_pulse <= 1'b0;
    end
    repeat (80) @(posedge clk);
    $display("[%0t] TEST DONE. errors=%0d", $time, error_count);
    $finish;
  end
  initial begin
    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;
  end
  reg  [3:0]  ref_len;
  reg  [14:0] hist;
  wire [14:0] next_hist = {hist[13:0], in_sig};
  wire [3:0]  next_len  = inc_pulse ? ((ref_len == 4'd15) ? 4'd0 : (ref_len + 4'd1)) : ref_len;
  wire        exp_next  = (next_len == 4'd0) ? in_sig : next_hist[next_len - 1];
  integer error_count;
  always @(posedge clk) begin
    if (rst) begin
      ref_len     <= 4'd0;
      hist        <= 15'd0;
      error_count <= 0;
    end else begin
      if (out_sig !== exp_next) begin
        error_count = error_count + 1;
        $display("[%0t] MISMATCH: ref_len=%0d out=%0b exp=%0b (in_sig=%0b hist=%0h)",
                 $time, next_len, out_sig, exp_next, in_sig, next_hist);
      end
      hist    <= next_hist;
      ref_len <= next_len;
    end
  end
  initial begin
    $dumpfile("var_delay15_tb.vcd");
    $dumpvars(0, var_delay15_tb);
  end
endmodule
