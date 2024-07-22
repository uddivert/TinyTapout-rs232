`timescale 1ns / 1ps

module tt_um_uddivert_rs232(
    input  wire [7:0] ui_in,    // Dedicated inputs 
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset);
);

// Internal signals
reg [7:0] tx_data;
reg tx_start;
wire tx_busy;
wire rx_data_ready;
wire [7:0] rx_data;
wire rx_idle;
wire rx_endofpacket;

// Transmit data when enabled
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_data <= 8'b0;
        tx_start <= 1'b0;
    end else if (ena) begin
        tx_data <= ui_in;    // Transmit the data from ui_in
        tx_start <= 1'b1;    // Start transmission
    end else begin
        tx_start <= 1'b0;
    end
end

// Instantiate the transmitter
async_transmitter transmitter (
    .clk(clk),
    .TxD_start(tx_start),
    .TxD_data(tx_data),
    .TxD(uio_out[0]),   // Use the first bit of uio_out for TxD
    .TxD_busy(tx_busy)
);

// Instantiate the receiver
async_receiver receiver (
    .clk(clk),
    .RxD(uio_in[1]),    // Use the second bit of uio_in for RxD
    .RxD_data_ready(rx_data_ready),
    .RxD_data(rx_data),
    .RxD_idle(rx_idle),
    .RxD_endofpacket(rx_endofpacket)
);

// Output the received data to uo_out
assign uo_out[7:0] = rx_data_ready ? rx_data[7:0] : 8'b0;

// Configure uio_oe to set the direction of uio_out
assign uio_oe = 8'b1; // Set bit uio_out[0] as output and uio_in[1] as input

endmodule

