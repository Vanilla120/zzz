(* top *) module bitshifter (
  (* iopad_external_pin *) input clk,
  (* iopad_external_pin *) input cs,
  (* iopad_external_pin *) input sdo,
  (* iopad_external_pin *) output miso,
  (* iopad_external_pin *) output o_clk,
  (* iopad_external_pin *) output o_cs,
  (* iopad_external_pin *) output o_cs_en
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
