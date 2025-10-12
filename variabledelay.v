(* top *) module bitshifter (
  (* iopad_external_pin *) input  wire clk,
  (* iopad_external_pin *) input  wire cs,
  (* iopad_external_pin *) input  wire sdo,
  (* iopad_external_pin *) input  wire in_bit,
  (* iopad_external_pin *) output wire miso,
  (* iopad_external_pin *) output wire o_clk,
  (* iopad_external_pin *) output wire o_cs,
  (* iopad_external_pin *) output wire o_cs_en
);
  reg init1, init2;
  wire por_active = ~init2;
  reg [3:0] len;
  reg [14:0] pipe;
  assign o_clk   = clk;
  assign miso    = sdo;
  assign o_cs_en = 1'b1;
  assign o_cs = (len == 4'd0) ? cs : pipe[len-1];
  integer i;
  always @(posedge clk) begin
    init1 <= 1'b1;
    init2 <= init1;
    if (por_active) begin
      len  <= 4'd0;
      pipe <= 15'd0;
    end else begin
      if (in_bit) begin
        if (len == 4'd15) len <= 4'd0;
        else              len <= len + 4'd1;
      end
      pipe <= {pipe[13:0], cs};
    end
  end
endmodule

