# Simple-UART-Module
An easy to use UART module with parameters to accept different clock frequencies and baud rates as per use case.

The UART reciever expects 1 Start bit, 8 data bits and 1 Stop bit and no parity bit.

The UART transmitter transmits 1 Start bit, 8 data bits and 1 Stop bit and no parity bit.

The module was synthesized and tested on a SPARTAN-6 FPGA.

The test bench included tests the module by connecting the Serial input and serial output of the module together and sending the data bits from the transmitter(UART_tx) and recieving it through the reciever(UART_rx). 
