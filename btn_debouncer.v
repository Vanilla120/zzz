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

