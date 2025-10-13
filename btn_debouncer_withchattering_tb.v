`timescale 1ns/1ps
module btn_debouncer_tb;
  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg  rst;
  reg  btn_raw;
  wire inc_pulse;
  localparam integer DIV = 8;
  localparam integer N   = 3;
  localparam integer SETTLE_CYC = (N*DIV) + 4;
  btn_debouncer #(
    .DIV(DIV),
    .N  (N)
  ) dut (
    .clk      (clk),
    .rst      (rst),
    .btn_raw  (btn_raw),
    .inc_pulse(inc_pulse)
  );
  reg mark_caseA = 1'b0;
  reg mark_caseB = 1'b0;
  reg mark_caseC = 1'b0;
  reg mark_caseD = 1'b0;
  reg [7:0] inc_pulse_cnt = 8'd0;
  always @(posedge clk) begin
    if (rst) begin
      inc_pulse_cnt <= 8'd0;
    end else if (inc_pulse) begin
      inc_pulse_cnt <= inc_pulse_cnt + 8'd1;
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
    mark_caseA <= 1'b1;
      hold_level(1'b0, 30);
      chatter(30);
      hold_level(1'b1, SETTLE_CYC);
      hold_level(1'b1, 20);
      chatter(20);
      hold_level(1'b0, SETTLE_CYC);
    mark_caseA <= 1'b0;
    mark_caseB <= 1'b1;
      hold_level(1'b1, SETTLE_CYC);
      hold_level(1'b1, 20);
      hold_level(1'b0, SETTLE_CYC);
    mark_caseB <= 1'b0;
    mark_caseC <= 1'b1;
      hold_level(1'b1, (N*DIV/2));
      hold_level(1'b0, SETTLE_CYC);
    mark_caseC <= 1'b0;
    mark_caseD <= 1'b1;
      chatter(100);
      hold_level(1'b0, SETTLE_CYC);
    mark_caseD <= 1'b0;
    #100;
    $finish;
  end
  initial begin
    $dumpfile("btn_debouncer_tb.vcd");
    $dumpvars(0, btn_debouncer_tb);
  end
endmodule
