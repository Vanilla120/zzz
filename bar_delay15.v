module var_delay15 (
  input  wire clk,
  input  wire rst,
  input  wire in_sig,
  input  wire inc_pulse,
  output wire out_sig
);
  reg  [3:0]  len;
  reg  [14:0] pipe;
  assign out_sig = (len == 4'd0) ? in_sig : pipe[len-1];
  always @(posedge clk) begin
    if (rst) begin
      len  <= 4'd0;
      pipe <= 15'd0;
    end else begin
      pipe <= {pipe[13:0], in_sig};
      if (inc_pulse) begin
        len <= (len == 4'd15) ? 4'd0 : (len + 4'd1);
      end
    end
  end
endmodule

