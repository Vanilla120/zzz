(* top *) module bitshifter (
  (* iopad_external_pin *) input  wire clk,
  (* iopad_external_pin *) input  wire cs,
  (* iopad_external_pin *) input  wire sdo,
  (* iopad_external_pin *) output wire miso,
  (* iopad_external_pin *) output wire o_clk,
  (* iopad_external_pin *) output wire o_cs,
  (* iopad_external_pin *) output wire o_cs_en
);
  reg init1, init2;
  wire por_active;
  reg [6:0] shift_reg;
  assign por_active = ~init2;
  assign o_clk   = clk;
  assign o_cs    = shift_reg[6];
  assign o_cs_en = 1'b1;
  assign miso    = sdo;
  always @(posedge clk) begin
    init1 <= 1'b1;
    init2 <= init1;
    if (por_active) begin
      shift_reg <= 7'b0000000;
    end else begin
      shift_reg <= {shift_reg[5:0], cs};
    end
  end
endmodule

