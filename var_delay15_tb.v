`timescale 1ns/1ps
module var_delay15_tb;
  reg  clk;
  reg  rst;
  reg  in_sig;
  reg  inc_pulse;
  wire out_sig;
  var_delay15 dut (
    .clk      (clk),
    .rst      (rst),
    .in_sig   (in_sig),
    .inc_pulse(inc_pulse),
    .out_sig  (out_sig)
  );
  initial clk = 1'b0;
  always #5 clk = ~clk;
  initial begin
    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;
  end
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
  integer i;
  initial begin
    inc_pulse = 1'b0;
    @(negedge rst);
    repeat (10) @(posedge clk);
    for (i = 0; i < 20; i = i + 1) begin
      repeat (6) @(posedge clk);
      inc_pulse <= 1'b1;
      @(posedge clk);
      inc_pulse <= 1'b0;
    end
    repeat (100) @(posedge clk);
    $finish;
  end
  initial begin
    $dumpfile("var_delay15_tb.vcd");
    $dumpvars(0, var_delay15_tb);
  end
endmodule
