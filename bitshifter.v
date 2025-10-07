(* top *) module bitshifter (
  (* iopad_external_pin *) input ext_clk,
  (* iopad_external_pin *) input in_bit,
  (* iopad_external_pin *) output out,
  (* iopad_external_pin *) output out_en,
);
  reg [3:0] shift_reg = 4'b0000;
  assign out = shift_reg[3];
  assign out_en = 1'b1;
  always @(posedge ext_clk) begin
    shift_reg <= {shift_reg[2:0], in_bit};
  end
endmodule
