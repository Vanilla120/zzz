 module bitshifter (
  input clk,
  input cs,
  input sdo,
  output miso,
  output o_clk,
  output o_cs,
  output o_cs_en
);
  reg [6:0] shift_reg = 7'b0000000;
  assign o_cs = shift_reg[6];
  assign o_cs_en = 1'b1;
  assign o_clk = clk;
  assign miso = sdo;
  always @(posedge clk) begin
    shift_reg <= {shift_reg[5:0], cs};
  end
endmodule
