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
    port    (   tx_en : in STD_LOGIC;                           -- Input to enable/disable transmitter (Active High) 
                clk_baud_os : in STD_LOGIC;                     -- Input clock signal at 16x the baud rate                    
                rst : in STD_LOGIC;                             -- Input to reset the module
                start_tx : in STD_LOGIC;                        -- Input to trigger the transmission process
                tx_data_in : in std_logic_vector(7 downto 0);   -- Input bits to be transmitted serially
                parity_en : in STD_LOGIC;                       -- Input to enable the parity
                parity_select : in STD_LOGIC;                   -- Input to select type of parity to be used (0 - Even, 1 - Odd)
                tx_busy : out STD_LOGIC;                        -- Output current state of transmitter (Busy/Idle)
                tx_out : out STD_LOGIC);                        -- Serial output 
end UART_tx;

architecture tx_beh of UART_tx is                           
    type tx_states is (idle, start_bit, transmit_data_bits, transmit_parity_bit, transmit_stop_bit);         -- The state machine uses 5 states : One for when it is idle, one to transmit start bit, one for transmitting the data bits, one for transmitting the parity bit if enable and one to transmit stop bit.
    signal cState_tx : tx_states := idle;                                   -- Current state of state machine.
    signal baud_count, bit_count : unsigned(3 downto 0) := (others => '0'); -- Counters used to counting the clock pulses and count the number of bits recieved respectively.
    signal tx_reg : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');        -- Register used to storing the bits to be transmitted (Stores 8 data bits and 1 stop bit).
    signal tx_parity_gen_logic : STD_LOGIC_VECTOR(7 downto 0);
    signal tx_parity : STD_LOGIC;                                           -- Generated parity bit
    signal parity_en_reg, parity_select_reg : STD_LOGIC := '0';
begin
    
    tx_parity_gen_logic(0) <= tx_data_in(0);
    rx_parity_gen:for i in 1 to 7 generate                                  -- Parity logic generator
        tx_parity_gen_logic(i) <= tx_parity_gen_logic(i - 1) xor tx_data_in(i); 
    end generate;

    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process to generate parity bit.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    parity_gen:process
    begin
        if parity_en_reg = '1' and parity_select_reg = '0' then             -- If even parity is enabled.
            if tx_parity_gen_logic(7) = '1' then
                tx_parity <= '1';
            else
                tx_parity <= '0';
            end if;
        elsif parity_en_reg = '1' and parity_select_reg = '1' then          -- If odd parity is enabled.
            if tx_parity_gen_logic(7) = '0' then
                tx_parity <= '1';
            else
                tx_parity <= '0';
            end if;
        end if;
    end process parity_gen;	
    
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process which implements the actual state machine.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------

    tx_process:process(clk_baud_os)
    begin
        if rising_edge(clk_baud_os) then
            if rst = '1' then                                   -- When the reset input is high clear all counters and shift registers  
                baud_count <= to_unsigned(0, 4);
                bit_count <= to_unsigned(0, 4);
                tx_busy <= '0';
                cState_tx <= idle;
                parity_en_reg <= '0';
                parity_select_reg <= '0';
                
            else
                if tx_en = '1' then
                    case cState_tx is 
                        when idle =>                        
                            tx_out <= '1';
                            parity_en_reg <= parity_en;          -- Enable/Disable parity when rx is idle
                            parity_select_reg <= parity_select;  -- Change type of parity used when rx is idle

                            if start_tx = '1' then               -- When the FSM is "idle" and start_tx is high change state to "start_bit"
                                cState_tx <= start_bit;
                                tx_busy <= '1';
                            else
                                cState_tx <= idle;
                                tx_busy <= '0';
                            end if;
                    
                        when start_bit =>
                            tx_out <= '0';                       -- Transmit start bit '0' for 16 clock periods (1 clock period = baud rate / 16)
                            if baud_count < 15 then
                                baud_count <= baud_count + 1;
                            else
                                cState_tx <= transmit_data_bits; -- Once 16 clock periods are over change state to "transmit_bits"
                                baud_count <= to_unsigned(0, 4);
                            end if;
                        
                        when transmit_data_bits =>
                            tx_out <= tx_data_in(to_integer(bit_count));    -- Implements a multiplexer to transmit one of the 8 data bits based on value of bit_count counter
                            if baud_count < 15 then                 -- Wait for 16 clock periods
                                baud_count <= baud_count + 1;
                            elsif bit_count < 7 then                -- Once 16 clock periods are done, start transmitting next bit if all 8 bits haven't been transmitted
                                cState_tx <= transmit_data_bits;
                                baud_count <= to_unsigned(0, 4);
                                bit_count <= bit_count + 1;
                            else                                    
                                if parity_en_reg = '1' then         -- If parity is enabled start transmitting parity bit
                                    cState_tx <= transmit_parity_bit;
                                    baud_count <= to_unsigned(0, 4);
                                    bit_count <= to_unsigned(0, 4);
                                else
                                    cState_tx <= transmit_stop_bit; -- Else transmit stop bit
                                    baud_count <= to_unsigned(0, 4);
                                    bit_count <= to_unsigned(0, 4);
                                end if;
                            end if;
                        
                        when transmit_parity_bit =>
                            tx_out <= tx_parity;                    -- Parity bit generated using parity logic
                            if baud_count < 15 then                 -- Wait for 16 clock periods
                                baud_count <= baud_count + 1;
                            else
                                cState_tx <= transmit_stop_bit;
                                baud_count <= to_unsigned(0, 4);
                            end if;
                        
                        when transmit_stop_bit => 
                            tx_out <= '1';                          -- Stop bit
                            if baud_count < 15 then                 -- Wait for 16 clock periods
                                baud_count <= baud_count + 1;
                            else
                                cState_tx <= idle;
                                tx_busy <= '0';
                                baud_count <= to_unsigned(0, 4);
                            end if;
                            
                        when others =>
                            baud_count <= to_unsigned(0, 4);
                            bit_count <= to_unsigned(0, 4);
                            tx_busy <= '0';
                            cState_tx <= idle;
                    end case;
                end if;
            end if;    
        end if;
    end process tx_process;


end tx_beh;
