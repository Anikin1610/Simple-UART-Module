# UART Module with Auto baud rate detector
An easy to use UART module with parity and auto baud rate detection.

## Introduction
  UART is a serial communication system which doesn't require a clock to synchronize between the transmitter and reciever. It sends data 1 bit at a time from the LSB to MSB and is framed by a start bit (generally logic '0') and a stop bit (generally logic '1').
  
## Implementation
  The actual HDL files are present in srcs directory and are divided into 4 files
  
  #### Baud pulse generator : 
      The baud pulse generator has two functions - if the auto baud rate detection is enabled then it determines the baud rate and then it generates a clock pulse with a frequency 16 times the baud rate. 
      If the auto baud rate detection is enabled, the module will expect any odd valued data to be transmitted (i.e. LSB = '1'). Commonly used synchronization characters are 'u' and 'a'.
      The minimum baud rate achievable with a 16 bit counter at 12MHz clock frequency is 300 bps. The size of the counter can be made smaller or bigger according to the application.
      
  #### UART reciever module :
       The UART reciever expects 1 Start bit, 8 data bits and 1 Stop bit at a minimum. 
       The parity bit and type of parity used can be configured at run time using the parity_en and parity_select inputs. 
       The module expects a clock signal oversampled at 16 times the baud rate.

  #### UART transmitter module :
        The UART transmitter transmits a minimum of 1 Start bit, 8 data bits and 1 Stop bit. 
        Transmission of parity bit and the type of parity used can be configured at run time using the parity_en and parity_select inputs. 
        The module expects a clock signal oversampled at 16 times the baud rate.
        
  ### UART module
        This is simply a top module used to connect the Baud pulse generator to the UART reciever and transmitter modules.

The module was synthesized and tested on a SPARTAN-6 FPGA.

The testbench in the tb directory tests the module by daisy chaining the serial input and serial output of the module and sending the data bits from the transmitter(UART_tx) and recieving it through the reciever(UART_rx). This test bench hasn't been updated to test the parity and the auto baud rate detection features. 

## Known Issues

* Using a clock frequency of 12 MHz the maximum baud rate at which data could be reliably recieved and transmitted was 38400 bps.

