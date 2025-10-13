module btn_debouncer #(
  parameter integer DIV = 50_000,
  parameter integer N   = 8
)(
  input  wire clk,
  input  wire rst,
  input  wire btn_raw,
  output wire inc_pulse
);
  reg btn_sync1, btn_sync2;
  always @(posedge clk) begin
    if (rst) begin
      btn_sync1 <= 1'b0;
      btn_sync2 <= 1'b0;
    end else begin
      btn_sync1 <= btn_raw;
      btn_sync2 <= btn_sync1;
    end
  end
  reg [31:0] div_cnt;
  wire sample_en = (div_cnt == (DIV-1));
  always @(posedge clk) begin
    if (rst) begin
      div_cnt <= 32'd0;
    end else if (sample_en) begin
      div_cnt <= 32'd0;
    end else begin
      div_cnt <= div_cnt + 32'd1;
    end
  end
  reg  [N-1:0] hist;
  reg          btn_stable;
  wire [N-1:0] next_hist   = {hist[N-2:0], btn_sync2};
  wire         set_cond    = &next_hist;
  wire         clr_cond    = ~|next_hist;
  wire         next_stable = set_cond ? 1'b1 :
                             clr_cond ? 1'b0 :
                                        btn_stable;
  assign inc_pulse = sample_en && (next_stable & ~btn_stable);
  always @(posedge clk) begin
    if (rst) begin
      hist       <= {N{1'b0}};
      btn_stable <= 1'b0;
    end else if (sample_en) begin
      hist       <= next_hist;
      btn_stable <= next_stable;
    end
  end
endmodule

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

(* top *)
module bitshifter #(
  parameter integer DIV     = 50_000,
  parameter integer N       = 8
)(
  input  wire clk,
  input  wire cs,
  input  wire sdo,
  input  wire btn_raw,
  output wire miso,
  output wire o_clk,
  output wire o_cs,
  output wire o_cs_en
);
  reg init1, init2;
  always @(posedge clk) begin
    init1 <= 1'b1;
    init2 <= init1;
  end
  wire por_active = ~init2;
  wire btn_inc_pulse;
  btn_debouncer #(
    .DIV(DIV),
    .N  (N)
  ) u_debouncer (
    .clk       (clk),
    .rst       (por_active),
    .btn_raw   (btn_raw),
    .inc_pulse (btn_inc_pulse)
  );
  var_delay15 u_delay (
    .clk       (clk),
    .rst       (por_active),
    .in_sig    (cs),
    .inc_pulse (btn_inc_pulse),
    .out_sig   (o_cs)
  );
  assign o_clk   = clk;
  assign miso    = sdo;
  assign o_cs_en = 1'b1;
endmodule
