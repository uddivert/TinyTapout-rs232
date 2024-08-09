# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_rs232(dut):
    dut._log.info("Start RS-232 Test")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset the device
    dut._log.info("Resetting the device")
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enable the module
    dut._log.info("Enabling the module")
    dut.ena.value = 1

    # Test Case: Transmit Data
    test_data = 0xA5  # Example data to transmit
    dut.ui_in.value = test_data  # Input data to be transmitted

    dut._log.info(f"Transmitting data: {test_data}")
    await RisingEdge(dut.clk)

    # Wait to simulate transmission time
    await ClockCycles(dut.clk, 100)  # Adjust based on the baud rate

    # Assert the transmitter output (TxD) is valid
    assert dut.uio_out.value == test_data & 0x01, f"TxD expected {test_data & 0x01}, got {dut.uio_out.value}"

    # Test Case: Receive Data
    received_data = 0x3C  # Example data to receive
    dut.uio_in.value = received_data  # Simulate receiving this data

    dut._log.info(f"Receiving data: {received_data}")
    await ClockCycles(dut.clk, 100)  # Wait for the receiver to process

    # Assert the received data is valid
    # assert dut.uo_out.value == received_data, f"RxD expected {received_data}, got {dut.uo_out.value}"

    # End of the test
    dut._log.info("Test completed")

