`timescale 1ns/1ps

module tb_delay_extclk;

  // --------------------------
  // TB driven inputs
  // --------------------------
  reg ext_clk_in;
  reg nreset;
  reg sclk_in;
  reg cs;
  reg sdo;

  // --------------------------
  // Loopback clocks (TB wires)
  // --------------------------
  wire lac0_clk;
  wire lac1_clk;

  // --------------------------
  // DUT outputs
  // --------------------------
  wire ref_lac0_out;
  wire ref_lac1_out;
  wire lac0_en;
  wire lac1_en;

  wire div16_out;
  wire div16_out_oe;

  wire miso;
  wire miso_en;

  wire sclk_out;
  wire sclk_out_en;

  wire cs_out;
  wire cs_out_en;

  // --------------------------
  // Instantiate DUT
  // --------------------------
  delay_extclk dut (
    .lac0_clk     (lac0_clk),
    .lac1_clk     (lac1_clk),
    .nreset       (nreset),
    .ext_clk_in   (ext_clk_in),
    .sclk_in      (sclk_in),
    .cs           (cs),
    .sdo          (sdo),
    .ref_lac0_out (ref_lac0_out),
    .ref_lac1_out (ref_lac1_out),
    .lac0_en      (lac0_en),
    .lac1_en      (lac1_en),
    .div16_out    (div16_out),
    .div16_out_oe (div16_out_oe),
    .miso         (miso),
    .miso_en      (miso_en),
    .sclk_out     (sclk_out),
    .sclk_out_en  (sclk_out_en),
    .cs_out       (cs_out),
    .cs_out_en    (cs_out_en)
  );

  // --------------------------
  // Simulate board loopback:
  // REF_LOGIC_AS_CLKx -> LOGIC_AS_CLKx
  // --------------------------
  assign lac0_clk = ref_lac0_out;
  assign lac1_clk = ref_lac1_out;

  // --------------------------
  // External clock generator
  // Choose ext_clk fast enough so that lac1_clk (= ext/16) oversamples sclk_in.
  // Example:
  //   ext_clk = 160 MHz (6.25 ns period)
  //   lac1_clk = 10 MHz
  //   sclk_in  = 1 MHz  => lac1_clk is 10x sclk_in
  // --------------------------
  localparam real EXTCLK_PERIOD_NS = 6.25; // 160 MHz
  initial begin
    ext_clk_in = 1'b0;
    forever #(EXTCLK_PERIOD_NS/2.0) ext_clk_in = ~ext_clk_in;
  end

  // --------------------------
  // SCLK generator (manual pulses)
  // --------------------------
  task automatic sclk_pulse(input real half_period_ns);
    begin
      // rising edge
      #(half_period_ns) sclk_in = 1'b1;
      #(half_period_ns) sclk_in = 1'b0;
    end
  endtask

  // --------------------------
  // TB reference model
  // Mirrors DUT behavior at lac1_clk domain:
  // - cs_sync_model <= cs sampled on posedge lac1_clk
  // - event_ff1_model <= sclk_in sampled on posedge lac1_clk
  // - event_ff2_model <= event_ff1_model
  // - on rising edge of event_ff2_model, shift_model shifts in cs_sync_model
  // - if cs_sync_model==1 then shift_model forced to 7'b1111111
  // --------------------------
  reg nrst1_model;
  reg cs_sync_model;
  reg event_ff1_model, event_ff2_model;
  reg event_prev_model;
  reg [6:0] shift_model;

  always @(posedge lac1_clk) begin
    nrst1_model <= nreset;

    if (!nrst1_model) begin
      cs_sync_model    <= 1'b0;
      event_ff1_model  <= 1'b0;
      event_ff2_model  <= 1'b0;
      event_prev_model <= 1'b0;
      shift_model      <= 7'b1111111;
    end else begin
      cs_sync_model   <= cs;
      event_ff1_model <= sclk_in;
      event_ff2_model <= event_ff1_model;

      // rising edge detect on event_ff2_model
      if (event_ff2_model & ~event_prev_model) begin
        shift_model <= {shift_model[5:0], cs_sync_model};
      end

      event_prev_model <= event_ff2_model;

      // cs_sync dominates (same always block ordering in DUT is not relied upon here;
      // we implement the intended priority explicitly)
      if (cs_sync_model) begin
        shift_model <= 7'b1111111;
      end
    end
  end

  // --------------------------
  // Check helper
  // --------------------------
  task automatic check_cs_out(input [255:0] tag);
    begin
      // Wait a bit for lac1 logic to settle
      @(posedge lac1_clk);
      if (cs_out !== shift_model[6]) begin
        $display("[FAIL] %s cs_out=%b expected=%b (shift_model=%b) @t=%0t",
                 tag, cs_out, shift_model[6], shift_model, $time);
        $stop;
      end else begin
        $display("[PASS] %s cs_out=%b (shift_model=%b) @t=%0t",
                 tag, cs_out, shift_model, $time);
      end
    end
  endtask

  // --------------------------
  // Main stimulus
  // --------------------------
  integer i;
  initial begin
    $dumpfile("tb_delay_extclk.vcd");
    $dumpvars(0, tb_delay_extclk);

    // init
    nreset = 1'b0;
    sclk_in = 1'b0;
    cs = 1'b1;   // idle high
    sdo = 1'b0;

    // hold reset for some ext clocks
    repeat (40) @(posedge ext_clk_in);
    nreset = 1'b1;

    // wait for div16/lac1 to run a bit
    repeat (40) @(posedge lac1_clk);

    // sanity: when cs is high, cs_out should be high
    check_cs_out("idle cs=1");

    // Start "transaction": pull CS low, then apply SCLK pulses.
    // Expectation: cs_out stays high initially, then after ~7 detected SCLK edges,
    // it should reflect low (depending on model sampling).
    cs = 1'b0;

    // Let cs propagate into cs_sync_model and DUT
    repeat (5) @(posedge lac1_clk);
    check_cs_out("after cs falls, before sclk pulses");

    // Send 12 SCLK pulses at 1 MHz (500 ns half-period)
    // This is slow compared to lac1_clk=10 MHz in this TB setup.
    for (i = 0; i < 12; i = i + 1) begin
      sclk_pulse(500.0);
      // After each pulse, allow sampling to occur
      repeat (5) @(posedge lac1_clk);
      check_cs_out({"after sclk pulse ",8'd48+i}); // tag is crude but ok
    end

    // End transaction: raise CS high, observe cs_out returns high quickly (after cs_sync sampling)
    cs = 1'b1;
    repeat (5) @(posedge lac1_clk);
    check_cs_out("after cs rises");

    // Toggle sdo and confirm miso passthrough
    sdo = 1'b1;
    #10;
    if (miso !== 1'b1) begin
      $display("[FAIL] miso passthrough expected 1 got %b", miso);
      $stop;
    end else begin
      $display("[PASS] miso passthrough");
    end

    $display("[TB] DONE");
    $finish;
  end

endmodule

