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
    port    (   i_tx_en : in STD_LOGIC;                           -- Input to enable/disable transmitter (Active High) 
                rst : in STD_LOGIC;                             -- Input to reset the module
                i_clk_baud_os : in STD_LOGIC;                   -- Input clock signal at 16x the baud rate                    
                i_start_tx : in STD_LOGIC;                        -- Input to trigger the transmission process
                i_tx_data : in std_logic_vector(7 downto 0);   -- Input bits to be transmitted serially
                i_parity_en : in STD_LOGIC;                       -- Input to enable the parity
                i_parity_sel : in STD_LOGIC;                   -- Input to select type of parity to be used (0 - Even, 1 - Odd)
                o_tx_busy : out STD_LOGIC;                        -- Output current state of transmitter (Busy/Idle)
                o_tx_serial : out STD_LOGIC);                        -- Serial output 
end UART_tx;

architecture tx_beh of UART_tx is                           
    type tx_states is (idle, start_bit, transmit_data_bits, transmit_parity_bit, transmit_stop_bit);         -- The state machine uses 5 states : One for when it is idle, one to transmit start bit, one for transmitting the data bits, one for transmitting the parity bit if enable and one to transmit stop bit.
    signal cState_tx : tx_states := idle;                                   -- Current state of state machine.
    signal s_baud_pulse_counter : unsigned(3 downto 0) := (others => '0');            -- Counters used to counting the clock pulses and count the number of bits recieved respectively.
    signal s_bit_counter : unsigned(2 downto 0) := (others => '0');
    signal s_tx_parity_gen : STD_LOGIC_VECTOR(7 downto 0);
    signal s_tx_data_prev : std_logic_vector(7 downto 0);
    signal s_txt_parity : STD_LOGIC;                                           -- Generated parity bit
    signal s_parity_en_reg, s_parity_select_reg : STD_LOGIC := '0';
begin
    
    s_tx_parity_gen(0) <= i_tx_data(0);
    rx_parity_gen:for i in 1 to 7 generate                                  -- Parity logic generator
        s_tx_parity_gen(i) <= s_tx_parity_gen(i - 1) xor i_tx_data(i); 
    end generate;

    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process to generate parity bit.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    parity_gen:process(s_parity_en_reg, s_parity_select_reg, s_tx_parity_gen)
    begin
        if s_parity_en_reg = '1' and s_parity_select_reg = '0' then             -- If even parity is enabled.
            if s_tx_parity_gen(7) = '1' then
                s_txt_parity <= '1';
            else
                s_txt_parity <= '0';
            end if;
        elsif s_parity_en_reg = '1' and s_parity_select_reg = '1' then          -- If odd parity is enabled.
            if s_tx_parity_gen(7) = '0' then
                s_txt_parity <= '1';
            else
                s_txt_parity <= '0';
            end if;
		  else
				s_txt_parity <= '0';
        end if;
    end process parity_gen;	
    
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process which implements the actual state machine.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    tx_process:process(i_clk_baud_os, rst)
    begin
        if rst = '1' then                                     -- When the reset input is high clear all counters and shift registers  
                s_baud_pulse_counter <= to_unsigned(0, 4);
                s_bit_counter <= to_unsigned(0, 3);
                o_tx_busy <= '0';
                cState_tx <= idle;
                s_parity_en_reg <= '0';
                s_parity_select_reg <= '0';
                o_tx_serial <= '1';
        elsif rising_edge(i_clk_baud_os) then
            s_tx_data_prev <= i_tx_data;
            if i_tx_en = '1' then
                case cState_tx is 
                    when idle =>                        
                        o_tx_serial <= '1';
                        s_parity_en_reg <= i_parity_en;       -- Enable/Disable parity when rx is idle
                        s_parity_select_reg <= i_parity_sel;  -- Change type of parity used when rx is idle

                        if s_tx_data_prev /= i_tx_data then   -- When the FSM is "idle" and i_start_tx is high change state to "start_bit"
                            cState_tx <= start_bit;
                            o_tx_busy <= '1';
                        else
                            cState_tx <= idle;
                            o_tx_busy <= '0';
                        end if;
                
                    when start_bit =>
                        o_tx_serial <= '0';                     -- Transmit start bit '0' for 16 clock periods (1 clock period = baud rate / 16)
                        if s_baud_pulse_counter < 15 then
                            s_baud_pulse_counter <= s_baud_pulse_counter + 1;
                        else
                            cState_tx <= transmit_data_bits;    -- Once 16 clock periods are over change state to "transmit_bits"
                            s_baud_pulse_counter <= to_unsigned(0, 4);
                        end if;
                    
                    when transmit_data_bits =>
                        o_tx_serial <= i_tx_data(to_integer(s_bit_counter));    -- Implements a multiplexer to transmit one of the 8 data bits based on value of s_bit_counter 
                        if s_baud_pulse_counter < 15 then                 -- Wait for 16 clock periods
                            s_baud_pulse_counter <= s_baud_pulse_counter + 1;
                        elsif s_bit_counter < 7 then                -- Once 16 clock periods are done, start transmitting next bit if all 8 bits haven't been transmitted
                            cState_tx <= transmit_data_bits;
                            s_baud_pulse_counter <= to_unsigned(0, 4);
                            s_bit_counter <= s_bit_counter + 1;
                        else                                    
                            if s_parity_en_reg = '1' then         -- If parity is enabled start transmitting parity bit
                                cState_tx <= transmit_parity_bit;
                                s_baud_pulse_counter <= to_unsigned(0, 4);
                                s_bit_counter <= to_unsigned(0, 3);
                            else
                                cState_tx <= transmit_stop_bit; -- Else transmit stop bit
                                s_baud_pulse_counter <= to_unsigned(0, 4);
                                s_bit_counter <= to_unsigned(0, 3);
                            end if;
                        end if;
                    
                    when transmit_parity_bit =>
                        o_tx_serial <= s_txt_parity;                    -- Parity bit generated using parity logic
                        if s_baud_pulse_counter < 15 then                 -- Wait for 16 clock periods
                            s_baud_pulse_counter <= s_baud_pulse_counter + 1;
                        else
                            cState_tx <= transmit_stop_bit;
                            s_baud_pulse_counter <= to_unsigned(0, 4);
                        end if;
                    
                    when transmit_stop_bit => 
                        o_tx_serial <= '1';                          -- Stop bit
                        if s_baud_pulse_counter < 15 then                 -- Wait for 16 clock periods
                            s_baud_pulse_counter <= s_baud_pulse_counter + 1;
                        else
                            cState_tx <= idle;
                            o_tx_busy <= '0';
                            s_baud_pulse_counter <= to_unsigned(0, 4);
                        end if;
                        
                    when others =>
                        s_baud_pulse_counter <= to_unsigned(0, 4);
                        s_bit_counter <= to_unsigned(0, 3);
                        o_tx_busy <= '0';
                        cState_tx <= idle;
                end case;
            end if;
        end if;
    end process tx_process;
end tx_beh;
