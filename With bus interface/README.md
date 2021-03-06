# UART Module with a simple bus interface 

This version of the UART module has a bus interface with separate asynchronous read and synchronous write ports.
In addition it also implements a 8 * 8 FIFO buffer for both the reciever and transmitter.

## Directory Structure:

/srcs has the main UART.vhd file as well as the fifo_buffer.vhd file which implement the UART module + bus interface and the FIFO buffer respectively

/tb contains 3 files. The test bench is implemented using Xilinx's Picoblaze IP for the spartan 6 FPGA. The actual design files for the Picoblaze have to be downloaded from Xilinx's website and is not included. 

The top_module.vhd is used to connect the UART module and the instruction RAM to the Picoblaze processor. This top module is fully synthesizable.

tb_uart_pico.vhd is the file which contains the testbench for top_module.

uart_prog.psm contains a sample program which was used to test the functionality of the UART module. This file has to assembled and converted into a .vhd file using the program available with the Picoblaze IP downloaded from Xilinx.
