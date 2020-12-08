------------------------------------------------------------------------------------------
-- Created by : Anirudh Srinivasan
-- 
-- Design Name: UART Module
-- Component Name: UART_rx
-- Target Device: Spartan 6
-- Description:
--    This module consists of the state machine to recieve and store the incoming bits
------------------------------------------------------------------------------------------
            
            

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_rx is
    port    (   rst : in STD_LOGIC;                             -- Input to reset the module
                baud_os : in STD_LOGIC;                         -- Input clock signal at 16x the baud rate
                rx_in : in STD_LOGIC;                           -- Serial input from the transmitter
                rx_busy : out STD_LOGIC;                        -- Output flag to signify that transmission over UART is taking place 
                rx_invalid : out STD_LOGIC;                     -- Output flag to signify that the recieved bits are invalid
                rx_data : out std_logic_vector(7 downto 0));    -- Parallel output of the recieved bits
end UART_rx;

architecture rx_beh of UART_rx is
    type rx_states is (idle, recieve_bits);                     -- The state machine requires only two state : One for when it is idle and one for when it is recieving bits
    signal cState_rx : rx_states := idle;                       -- Current state of state machine
    signal rx_busy_sig : STD_LOGIC := '0';                      
    signal baud_count, bit_count : unsigned(3 downto 0) := (others => '0'); -- Counters used to counting the clock pulses and count the number of bits recieved respectively
    signal rx_reg : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');        -- Shift register used to storing each of the recieved bit (Stores 8 data bits and 1 stop bit)
begin

    rx_data <= rx_reg(7 downto 0);                              -- Only the data bits are required as output
    rx_busy <= rx_busy_sig;

    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process to assert the invalid flag.
    -- Since parity is not be implemented the recieved bits are invalid if the stop bit is not encountered.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    
    invalid_check:process(rst, rx_busy_sig)                     
    begin
       if rst = '1' then
           rx_invalid <= '0';	       
       elsif falling_edge(rx_busy_sig) then
           if rx_reg(8) = '0' then
               rx_invalid <= '1';
           else
               rx_invalid <= '0';
           end if;
       end if;
    end process invalid_check;



    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process which implements the actual state machine.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------

    rx_process:process(baud_os)
    begin
        if rising_edge(baud_os) then
            if rst = '1' then                   -- When the reset input is high clear all counters and shift registers.
                cState_rx <= idle;
                baud_count <= to_unsigned(0, 4);
                bit_count <= to_unsigned(0, 4);
                rx_reg <= (others => '0');
            else
                case cState_rx is
                    when idle =>
                        rx_busy_sig <= '0';                     -- Deassert the busy flag
                        if rx_in = '0' and baud_count < 8 then  -- Wait for 8 clock periods (1 clock period = baud rate / 16) before sampling the start bit. 
                            baud_count <= baud_count + 1;
                            cState_rx <= idle;
                        elsif rx_in = '0' and baud_count = 8 then   -- If the recieved bit is '0' after 8 clock periods then a start bit has been encountered so we start recieveing the data bits.
                            cState_rx <= recieve_bits;
                            baud_count <= to_unsigned(0, 4);
                        else                                    -- Else clear the baud_count counter and stay in idle state.
                            cState_rx <= idle;
                            baud_count <= to_unsigned(0, 4);
                        end if;   
                            
                    when recieve_bits =>    
                        rx_busy_sig <= '1';                         -- Assert the busy flag
                        if bit_count < 9 and baud_count < 15 then   -- Wait for 16 clock periods before sampling the recieved bit
                            baud_count <= baud_count + 1;
                        
                        elsif bit_count < 9 then                    -- If less that 9 bits (8 data bits + 1 stop bit) have been recieved shift the recieved bit into shift register
                            rx_reg <= rx_in & rx_reg(8 downto 1);
                            bit_count <= bit_count + 1;
                            baud_count <= to_unsigned(0, 4);
                            cState_rx <= recieve_bits;
                        else                                        -- If 9 bits have been recieved clear the bit_count counter and go to idle state   
                            cState_rx <= idle;
                            bit_count <= to_unsigned(0, 4);
                        end if;
                                        
                    when others =>                                  -- Default case
                        rx_busy_sig <= '0';
                        cState_rx <= idle;
                        baud_count <= to_unsigned(0, 4);
                        bit_count <= to_unsigned(0, 4);
                        rx_reg <= (others => '0');
                end case;
            end if;
        end if;
    end process rx_process;

end rx_beh;
