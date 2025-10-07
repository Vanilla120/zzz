// ============================================================================
// Variable-Length Bit Shifter with Button-Controlled Delay (0..MAX_LEN)
// - Button press cycles len: 0 -> 1 -> ... -> MAX_LEN -> 0 -> ...
// - len = 0 : no delay (out follows in_bit)
// - len > 0 : out = shift_reg[len-1]  (len-clock delay)
// - Includes: button 2-FF sync + debounce, external async reset (active-low)
// - Output is registered for glitch-free external drive (adds +1clk latency)
//
// Adjust CLOCK_HZ for your board clock. Default MAX_LEN = 15.
// ============================================================================

(* top *)
module bitshifter_btn_reset #(
  parameter integer MAX_LEN      = 15,         // max delay (0..MAX_LEN)
  parameter integer CLOCK_HZ     = 12_000_000, // ★ set to your board clock
  parameter integer DEBOUNCE_MS  = 10          // debounce time [ms]
)(
  (* iopad_external_pin *) input  wire ext_clk,
  (* iopad_external_pin *) input  wire in_bit,
  (* iopad_external_pin *) input  wire btn,     // push button, active-HIGH
  (* iopad_external_pin *) input  wire rst_n,   // external reset, active-LOW
  (* iopad_external_pin *) output wire out,
  (* iopad_external_pin *) output wire out_en
);

  // ------------------------------------------------------------
  // 1) Button Synchronization (2-FF) and Debounce
  // ------------------------------------------------------------
  reg btn_sync1, btn_sync2;
  always @(posedge ext_clk or negedge rst_n) begin
    if (!rst_n) begin
      btn_sync1 <= 1'b0;
      btn_sync2 <= 1'b0;
    end else begin
      btn_sync1 <= btn;
      btn_sync2 <= btn_sync1;
    end
  end

  localparam integer DB_CNT_MAX = (CLOCK_HZ/1000)*DEBOUNCE_MS;
  localparam integer DB_CNT_W   = (DB_CNT_MAX > 0) ? $clog2(DB_CNT_MAX+1) : 1;

  reg [DB_CNT_W-1:0] db_cnt;
  reg btn_state;        // debounced stable state
  reg btn_state_prev;   // for edge detect

  wire btn_changed = (btn_sync2 != btn_state);

  always @(posedge ext_clk or negedge rst_n) begin
    if (!rst_n) begin
      db_cnt         <= {DB_CNT_W{1'b0}};
      btn_state      <= 1'b0;
      btn_state_prev <= 1'b0;
    end else begin
      if (btn_changed) begin
        db_cnt <= DB_CNT_MAX[DB_CNT_W-1:0];
      end else if (db_cnt != 0) begin
        db_cnt <= db_cnt - 1'b1;
        if (db_cnt == 1) begin
          btn_state <= btn_sync2;
        end
      end
      btn_state_prev <= btn_state;
    end
  end

  wire btn_rise = (btn_state == 1'b1) && (btn_state_prev == 1'b0);

  // ------------------------------------------------------------
  // 2) Delay Length Counter: len in [0..MAX_LEN]
  // ------------------------------------------------------------
  localparam integer LEN_W = (MAX_LEN > 0) ? $clog2(MAX_LEN+1) : 1;
  reg [LEN_W-1:0] len;

  always @(posedge ext_clk or negedge rst_n) begin
    if (!rst_n) begin
      len <= {LEN_W{1'b0}}; // start from 0 (no delay)
    end else begin
      if (btn_rise) begin
        if (len == MAX_LEN[LEN_W-1:0]) len <= {LEN_W{1'b0}};
        else                           len <= len + 1'b1;
      end
    end
  end

  // ------------------------------------------------------------
  // 3) Shift Register (width = MAX_LEN)
  //    Keep shifting even when len=0 to be ready for change.
  // ------------------------------------------------------------
  reg [MAX_LEN-1:0] shift_reg;

  generate
    if (MAX_LEN >= 2) begin : g_shift
      always @(posedge ext_clk or negedge rst_n) begin
        if (!rst_n) begin
          shift_reg <= {MAX_LEN{1'b0}};
        end else begin
          shift_reg <= {shift_reg[MAX_LEN-2:0], in_bit};
        end
      end
    end else begin : g_shift1
      // MAX_LEN=1 の特例（念のための汎用性確保）
      always @(posedge ext_clk or negedge rst_n) begin
        if (!rst_n) begin
          shift_reg <= {MAX_LEN{1'b0}};
        end else begin
          shift_reg[0] <= in_bit;
        end
      end
    end
  endgenerate

  // ------------------------------------------------------------
  // 4) Output Selection
  //    len=0 -> pass-through (in_bit)
  //    len>0 -> shift_reg[len-1]
  //    Use a simple for-loop MUX; register the output (glitch-free).
  // ------------------------------------------------------------
  reg selected_bit;
  integer i;
  always @* begin
    if (len == {LEN_W{1'b0}}) begin
      selected_bit = in_bit;
    end else begin
      selected_bit = 1'b0;
      for (i = 0; i < MAX_LEN; i = i + 1) begin
        if ((len - 1'b1) == i[LEN_W-1:0]) begin
          selected_bit = shift_reg[i];
        end
      end
    end
  end

  // Register output to avoid glitches on external pin
  reg out_reg;
  always @(posedge ext_clk or negedge rst_n) begin
    if (!rst_n) begin
      out_reg <= 1'b0;
    end else begin
      out_reg <= selected_bit;
    end
  end

  assign out    = out_reg;
  assign out_en = 1'b1;

endmodule

