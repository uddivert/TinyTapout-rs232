`define SIMULATION

module async_receiver(
    input clk,
    input RxD,
    input rst_n,
    output reg RxD_data_ready,
    output reg [7:0] RxD_data,  // data received, valid only (for one clock cycle) when RxD_data_ready is asserted

    // We also detect if a gap occurs in the received stream of characters
    // That can be useful if multiple characters are sent in burst
    // so that multiple characters can be treated as a "packet"
    output RxD_idle,  // asserted when no data has been received for a while
    output reg RxD_endofpacket  // asserted for one clock cycle when a packet has been detected (i.e. RxD_idle is going high)
);

parameter ClkFrequency = 25000000; // 25MHz
parameter Baud = 115200;

parameter Oversampling = 8;  // needs to be a power of 2
// we oversample the RxD line at a fixed rate to capture each RxD data bit at the "right" time
// 8 times oversampling by default, use 16 for higher quality reception

generate
    if (ClkFrequency < Baud * Oversampling)
        ASSERTION_ERROR PARAMETER_OUT_OF_RANGE("Frequency too low for Baud rate and oversampling");
    if (Oversampling < 8 || ((Oversampling & (Oversampling - 1)) != 0))
        ASSERTION_ERROR PARAMETER_OUT_OF_RANGE("Invalid oversampling value");
endgenerate

// Internal signals
reg [3:0] RxD_state = 0;

`ifdef SIMULATION
    wire RxD_bit = RxD;
    wire sampleNow = 1'b1;  // receive one bit per clock cycle

`else
    wire OversamplingTick;
    BaudGen #(ClkFrequency, Baud, Oversampling) tickgen(
        .clk(clk),
        .enable(1'b1),
        .tick(OversamplingTick)
    );

    // Flip flops are used. to ensure that the value of RxD_sync are timed
    // with the clock
    //
    // For example: if the value of RxD_sync is 2'b01 and the incoming value
    // of Rxd is 1'b1, then on the next tick the value of RxD_sync will be
    // 2'b11. Now the value of RxD_sync is aligned with the clock!
    reg [1:0] RxD_sync = 2'b11;
    always @(posedge clk)
        if (OversamplingTick)
            RxD_sync <= {RxD_sync[0], RxD};

    // Simple Digitial Debounce filter is used to smoothen the signal
    reg [1:0] Filter_cnt = 2'b11;
    reg RxD_bit = 1'b1;

    always @(posedge clk)
    if (OversamplingTick) begin
        if (RxD_sync[1] == 1'b1 && Filter_cnt != 2'b11)
            Filter_cnt <= Filter_cnt + 1'd1;
        else if (RxD_sync[1] == 1'b0 && Filter_cnt != 2'b00)
            Filter_cnt <= Filter_cnt - 1'd1;
        if (Filter_cnt == 2'b11)
            RxD_bit <= 1'b1;
        else if (Filter_cnt == 2'b00)
            RxD_bit <= 1'b0;
    end

    function integer log2(input integer v);
        begin
            log2 = 0;
            while (v >> log2)
                log2 = log2 + 1; 
        end
    endfunction

    localparam l2o = log2(Oversampling);
    reg [l2o-2:0] OversamplingCnt = 0;
    always @(posedge clk)
        if (OversamplingTick)
            OversamplingCnt <= (RxD_state == 0) ? 1'd0 : OversamplingCnt + 1'd1;
    wire sampleNow = OversamplingTick && (OversamplingCnt == Oversampling / 2 - 1);
`endif

// now we can accumulate the RxD bits in a shift-register
// Reset logic handled separately
always @(posedge clk) begin
    if (!rst_n) begin
        RxD_data_ready <= 0;
        RxD_data <= 8'b0;
        RxD_endofpacket <= 0;
    end

    if (sampleNow && RxD_state[3])
        RxD_data <= {RxD_bit, RxD_data[7:1]};
    if (sampleNow && RxD_state == 4'b0010 && RxD_bit)
        RxD_data_ready <= 1;
    else
        RxD_data_ready <= 0;

    case (RxD_state)
        4'b0000: if (~RxD_bit) RxD_state <= `ifdef SIMULATION 4'b1000 `else 4'b0001 `endif;  // start bit found?
        4'b0001: if (sampleNow) RxD_state <= 4'b1000;  // sync start bit to sampleNow
        4'b1000: if (sampleNow) RxD_state <= 4'b1001;  // bit 0
        4'b1001: if (sampleNow) RxD_state <= 4'b1010;  // bit 1
        4'b1010: if (sampleNow) RxD_state <= 4'b1011;  // bit 2
        4'b1011: if (sampleNow) RxD_state <= 4'b1100;  // bit 3
        4'b1100: if (sampleNow) RxD_state <= 4'b1101;  // bit 4
        4'b1101: if (sampleNow) RxD_state <= 4'b1110;  // bit 5
        4'b1110: if (sampleNow) RxD_state <= 4'b1111;  // bit 6
        4'b1111: if (sampleNow) RxD_state <= 4'b0010;  // bit 7
        4'b0010: if (sampleNow) RxD_state <= 4'b0000;  // stop bit
        default: RxD_state <= 4'b0000;
    endcase
end

`ifdef SIMULATION
    assign RxD_idle = 0;
`else
    reg [l2o+1:0] GapCnt = 0;
    always @(posedge clk)
        if (RxD_state != 0)
            GapCnt <= 0;
        else if (OversamplingTick & ~GapCnt[log2(Oversampling) + 1])
            GapCnt <= GapCnt + 1'h1;
    assign RxD_idle = GapCnt[l2o + 1];
    always @(posedge clk)
        RxD_endofpacket <= OversamplingTick & ~GapCnt[l2o + 1] & &GapCnt[l2o:0];
`endif

endmodule

