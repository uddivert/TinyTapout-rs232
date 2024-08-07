`define SIMULATION

module async_transmitter(
    input clk,
    input TxD_start,
    input [7:0] TxD_data,
    input rst_n,
    output TxD,
    output TxD_busy
);

// Assert TxD_start for (at least) one clock cycle to start transmission of TxD_data
// TxD_data is latched so that it doesn't have to stay valid while it is being sent
parameter ClkFrequency = 25000000; // 25MHz
parameter Baud = 115200;
parameter Oversampling = 1;        // Oversampling rate

`ifdef SIMULATION
    wire BitTick = 1'b1;  // output one bit per clock cycle
`else
    wire BitTick;

    BaudTickGen #(ClkFrequency, Baud, Oversampling) tickgen(
        .clk(clk),
        .enable(TxD_busy),
        .tick(BitTick)
    );
`endif

// Checks if frequency and baud rate make sense
generate
    if (ClkFrequency < Baud * 8 && (ClkFrequency % Baud != 0)) ASSERTION_ERROR PARAMETER_OUT_OF_RANGE("Frequency incompatible with baud rate");
endgenerate

reg [3:0] TxD_state;
reg [7:0] TxD_shift;
reg TxD_reg;

// handle resets
always @(posedge clk) begin
    if (!rst_n) begin
        TxD_state <= 4'b0;
        TxD_shift <= 8'b0;
        TxD_reg <= 1'b1; // Idle state of UART TX line is high
    end else begin
        if (TxD_state == 0 && TxD_start) begin
            TxD_shift <= TxD_data; // Load data to shift register
            TxD_state <= 4'b0100;  // Move to start bit state
        end else if (BitTick) begin
            case (TxD_state)
                4'b0100: TxD_state <= 4'b1000;  // Start bit
                4'b1000: begin
                    TxD_reg <= TxD_shift[0];   // Transmit bit 0
                    TxD_shift <= TxD_shift >> 1;
                    TxD_state <= 4'b1001;
                end
                4'b1001: begin
                    TxD_reg <= TxD_shift[0];   // Transmit bit 1
                    TxD_shift <= TxD_shift >> 1;
                    TxD_state <= 4'b1010;
                end
                4'b1010: begin
                    TxD_reg <= TxD_shift[0];   // Transmit bit 2
                    TxD_shift <= TxD_shift >> 1;
                    TxD_state <= 4'b1011;
                end
                4'b1011: begin
                    TxD_reg <= TxD_shift[0];   // Transmit bit 3
                    TxD_shift <= TxD_shift >> 1;
                    TxD_state <= 4'b1100;
                end
                4'b1100: begin
                    TxD_reg <= TxD_shift[0];   // Transmit bit 4
                    TxD_shift <= TxD_shift >> 1;
                    TxD_state <= 4'b1101;
                end
                4'b1101: begin
                    TxD_reg <= TxD_shift[0];   // Transmit bit 5
                    TxD_shift <= TxD_shift >> 1;
                    TxD_state <= 4'b1110;
                end
                4'b1110: begin
                    TxD_reg <= TxD_shift[0];   // Transmit bit 6
                    TxD_shift <= TxD_shift >> 1;
                    TxD_state <= 4'b1111;
                end
                4'b1111: begin
                    TxD_reg <= TxD_shift[0];   // Transmit bit 7
                    TxD_state <= 4'b0010;
                end
                4'b0010: begin
                    TxD_reg <= 1'b1;  // Stop bit 1
                    TxD_state <= 4'b0011;
                end
                4'b0011: begin
                    TxD_reg <= 1'b1;  // Stop bit 2
                    TxD_state <= 4'b0000; // Return to idle state
                end
            endcase
        end
    end
end

assign TxD_busy = (TxD_state != 4'b0000);
assign TxD = TxD_reg;

endmodule

