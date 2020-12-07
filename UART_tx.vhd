------------------------------------------------------------------------------------------
-- Created by : Anirudh Srinivasan
-- 
-- Design Name: UART Module
-- Component Name: UART_tx
-- Target Device: Spartan 6
-- Description:
--    This module consists of the state machine to transmit the given bits serially
------------------------------------------------------------------------------------------
			
			

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_tx is
    port    (   baud_os : in STD_LOGIC;                         -- Input clock signal at 16x the baud rate                    
                rst : in STD_LOGIC;                             -- Input to reset the module
                start_tx : in STD_LOGIC;                        -- Input to trigger the transmission process
                tx_data : in std_logic_vector(7 downto 0);      -- Input bits to be transmitted serially
                tx_busy : out STD_LOGIC;                        -- Output flag to signify that transmission over UART is taking place
                tx : out STD_LOGIC);                            -- Serial output to reciever
end UART_tx;

architecture tx_beh of UART_tx is                           
    type tx_states is (idle, start_bit, transmit_bits);         -- The state machine uses 3 state : One for when it is idle, one to transmit start bit and one for transmitting the data + stop bits
    signal cState_tx : tx_states := idle;                       -- Current state of state machine
    signal baud_count, bit_count : unsigned(3 downto 0) := (others => '0'); -- Counters used to counting the clock pulses and count the number of bits recieved respectively
    signal tx_reg : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');    -- Register used to storing the bits to be transmitted (Stores 8 data bits and 1 stop bit)
begin
    tx_reg <= '1' & tx_data;        -- Append the stop bit ('1') to the MSB of the data bits
    
    
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process which implements the actual state machine.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------

    tx_process:process(baud_os)
    begin
        if rising_edge(baud_os) then
            if rst = '1' then                           -- When the reset input is high clear all counters and shift registers  
                baud_count <= to_unsigned(0, 4);
                bit_count <= to_unsigned(0, 4);
                tx_busy <= '0';
                cState_tx <= idle;
            
            else
                case cState_tx is 
                    when idle =>                        
                        tx <= '1';
                        if start_tx = '1' then          -- When the FSM is "idle" and start_tx is high change state to "start_bit"
                            cState_tx <= start_bit;
                            tx_busy <= '1';
                        else
                            cState_tx <= idle;
                            tx_busy <= '0';
                        end if;
                
                    when start_bit =>
                        tx <= '0';                      -- Transmit start bit '0' for 16 clock periods (1 clock period = baud rate / 16)
                        if baud_count < 15 then
                            baud_count <= baud_count + 1;
                        else
                            cState_tx <= transmit_bits; -- Once 16 clock periods are over change state to "transmit_bits"
                            baud_count <= to_unsigned(0, 4);
                        end if;
                    
                    when transmit_bits =>
                        tx <= tx_reg(to_integer(bit_count));    -- Implements a multiplexer to transmit one of the 9 bits based on value of bit_count counter
                        if baud_count < 15 then                 -- Wait for 16 clock periods
                            baud_count <= baud_count + 1;
                        elsif bit_count < 8 then                -- Once 16 clock periods are done, start transmitting next bit if all 9 bits haven't been transmitted
                            cState_tx <= transmit_bits;
                            baud_count <= to_unsigned(0, 4);
                            bit_count <= bit_count + 1;
                        else                                    -- If all the 9 bits (8 data bits + 1 stop bit) are transmitted change state to "idle"
                            cState_tx <= idle;
                            tx_busy <= '0';
                            baud_count <= to_unsigned(0, 4);
                            bit_count <= to_unsigned(0, 4);
                        end if;
                    
                    when others =>
                        baud_count <= to_unsigned(0, 4);
                        bit_count <= to_unsigned(0, 4);
                        tx_busy <= '0';
                        cState_tx <= idle;
                end case;
            end if;    
        end if;
    end process tx_process;


end tx_beh;
