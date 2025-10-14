`timescale 1ns/1ps
`default_nettype none
module bitshifter_tb;
  reg  clk  = 1'b0;
  reg  cs   = 1'b0;
  reg  sdo  = 1'b0;
  wire miso;
  wire o_clk;
  wire o_cs;
  wire o_cs_en;
  bitshifter dut (
    .clk    (clk),
    .cs     (cs),
    .sdo    (sdo),
    .miso   (miso),
    .o_clk  (o_clk),
    .o_cs   (o_cs),
    .o_cs_en(o_cs_en)
  );
  always #10 clk = ~clk;
  initial begin
    $dumpfile("bitshifter_tb.vcd");
    $dumpvars(0, bitshifter_tb);
  end
  task drive_cs(input integer b);
    begin
      @(negedge clk);
      cs = (b != 0) ? 1'b1 : 1'b0;
      @(posedge clk);
    end
  endtask
  initial begin
    repeat (4) begin
      #35 sdo = ~sdo;
    end
    forever begin
      #77 sdo = ~sdo;
    end
  end
  initial begin
    cs  = 1'b0;
    sdo = 1'b0;
    repeat (3) @(posedge clk);
    drive_cs(1);
    drive_cs(0);
    drive_cs(1);
    drive_cs(1);
    drive_cs(0);
    drive_cs(0);
    drive_cs(1);
    drive_cs(0);
    drive_cs(1);
    drive_cs(0);
    drive_cs(0);
    drive_cs(1);
    repeat (20) @(posedge clk);
    $finish;
  end
endmodule
`default_nettype wire
