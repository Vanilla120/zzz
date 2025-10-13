(* top *) module bitshifter #(
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
  wire por_active = ~init2;
  reg btn_sync1, btn_sync2;
  reg [31:0] div_cnt;
  wire sample_en = (div_cnt == (DIV-1));
  reg  [N-1:0] hist;
  reg          btn_stable;
  wire [N-1:0] next_hist    = {hist[N-2:0], btn_sync2};
  wire         set_cond     = &next_hist;
  wire         clr_cond     = ~|next_hist;
  wire         next_stable  = set_cond ? 1'b1 :
                              clr_cond ? 1'b0 :
                                         btn_stable;
  wire         btn_inc_pulse= sample_en && (next_stable & ~btn_stable);
  reg  [3:0]  len;
  reg  [14:0] pipe;
  assign o_clk   = clk;
  assign miso    = sdo;
  assign o_cs_en = 1'b1;
  assign o_cs    = (len == 4'd0) ? cs : pipe[len-1];
  integer i;
  always @(posedge clk) begin
    init1 <= 1'b1;
    init2 <= init1;
    btn_sync1 <= btn_raw;
    btn_sync2 <= btn_sync1;
    if (por_active) begin
      div_cnt <= 32'd0;
    end else if (sample_en) begin
      div_cnt <= 32'd0;
    end else begin
      div_cnt <= div_cnt + 32'd1;
    end
    if (por_active) begin
      len        <= 4'd0;
      pipe       <= 15'd0;
      hist       <= {N{1'b0}};
      btn_stable <= 1'b0;
    end else begin
      if (sample_en) begin
        hist       <= next_hist;
        btn_stable <= next_stable;
      end
      if (btn_inc_pulse) begin
        len <= (len == 4'd15) ? 4'd0 : (len + 4'd1);
      end
      pipe <= {pipe[13:0], cs};
    end
  end
endmodule
