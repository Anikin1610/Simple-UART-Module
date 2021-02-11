------------------------------------------------------------------------------------------
-- Created by : Anirudh Srinivasan
-- 
-- Design Name: UART Module
-- Component Name: UART_tx
-- Target Device: Spartan 6
-- Description:
--    This module consists of the state machine to transmit the input byte serially
------------------------------------------------------------------------------------------
            

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_tx is
    port    (   i_clk : in std_logic;                           --  Input clock signal
                i_tx_en : in std_logic;                         --  Input to enable/disable transmitter (Active High) 
                rst : in std_logic;                             --  Input to reset the module
                i_tx_data : in std_logic_vector(7 downto 0);    --  Input bits to be transmitted 
                i_parity_en : in std_logic;                     --  Input to enable the parity
                i_parity_sel : in std_logic;                    --  Input to select type of parity to be used (0 - Even, 1 - Odd)
                i_rom_count_val : in std_logic_vector(15 downto 0); --  Input number of clock pulse for 1 baud period
                o_tx_busy : out std_logic;                      --  Output current state of transmitter (Busy/Idle)
                o_tx_serial : out std_logic);                   --  Serial output to external reciever
end UART_tx;

architecture tx_beh of UART_tx is                           
    type tx_states is (idle, start_bit, transmit_data_bits, transmit_parity_bit, transmit_stop_bit);         -- The state machine uses 5 states : One for when it is idle, one to transmit start bit, one for transmitting the data bits, one for transmitting the parity bit if enable and one to transmit stop bit.
    signal cState_tx : tx_states := idle;                           --  Current state of state machine.
    signal s_bit_counter : unsigned(2 downto 0) := (others => '0'); --  Counters to count the number of bits transmitted
    signal s_tx_data_prev : std_logic_vector(7 downto 0);           --  Previous value of i_tx_data
    signal s_tx_parity_bit : std_logic;                             --  Generated parity bit to be trasnmitted

    signal s_tx_parity_gen : std_logic_vector(7 downto 0);          --  Internal parity generation logic
    signal s_parity_en_reg, s_parity_select_reg : std_logic := '0'; --  Internal registers to hold the control signal for parity_en and parity_sel during transmission

    signal s_clk_pulse_counter : unsigned(15 downto 0);             --  16-Bit counter for counting the input clock pulse  
    signal s_clk_count_val_reg : unsigned(15 downto 0);             --  16-Bit register which holds the value for number clock pulses required for 1 bit

begin
   
    --------------------------------------------------------------------------------
    --  Parity bit generation logic
    --------------------------------------------------------------------------------
    s_tx_parity_gen(0) <= i_tx_data(0);
    rx_parity_gen:for i in 1 to 7 generate                                  
        s_tx_parity_gen(i) <= s_tx_parity_gen(i - 1) xor i_tx_data(i); 
    end generate;

    parity_gen:process(s_parity_en_reg, s_parity_select_reg, s_tx_parity_gen)
    begin
        if s_parity_en_reg = '1' and s_parity_select_reg = '0' then             -- If even parity is enabled.
            if s_tx_parity_gen(7) = '1' then
                s_tx_parity_bit <= '1';
            else
                s_tx_parity_bit <= '0';
            end if;
        elsif s_parity_en_reg = '1' and s_parity_select_reg = '1' then          -- If odd parity is enabled.
            if s_tx_parity_gen(7) = '0' then
                s_tx_parity_bit <= '1';
            else
                s_tx_parity_bit <= '0';
            end if;
		  else
				s_tx_parity_bit <= '0';
        end if;
    end process parity_gen;	

    
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process which implements the transmission state machine.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    tx_process:process(i_clk, rst)
    begin
        if rst = '1' then                                       -- When the reset input is high clear all counters and shift registers  
            cState_tx <= idle;
            s_clk_pulse_counter <= to_unsigned(0, 16);
            s_clk_count_val_reg <= to_unsigned(0, 16);
            s_bit_counter <= to_unsigned(0, 3);
            s_parity_en_reg <= '0';
            s_parity_select_reg <= '0';
            o_tx_serial <= '1';
            o_tx_busy <= '0';

        elsif rising_edge(i_clk) then
            s_tx_data_prev <= i_tx_data;                          
            if i_tx_en = '1' then
                case cState_tx is 
                    when idle =>
                        --------------------------------------------------------------------------------
                        --  Update control registers when transmitter is idle
                        --------------------------------------------------------------------------------
                        s_clk_count_val_reg <= unsigned(i_rom_count_val);
                        s_parity_en_reg <= i_parity_en;       
                        s_parity_select_reg <= i_parity_sel;  

                        o_tx_serial <= '1';                     --  When idle, hold serial output high.  

                        --------------------------------------------------------------------------------
                        --  Start transmission of bits if the previous value of input data is different 
                        --  from the current value of input data   
                        --------------------------------------------------------------------------------
                        if s_tx_data_prev /= i_tx_data then    
                            cState_tx <= start_bit;
                            o_tx_busy <= '1';
                        else
                            cState_tx <= idle;
                            o_tx_busy <= '0';
                        end if;
                    
                    --------------------------------------------------------------------------------
                    --  Hold the serial output low for 1 baud period to signal start bit
                    --------------------------------------------------------------------------------
                    when start_bit =>
                        o_tx_serial <= '0';                     
                        if s_clk_pulse_counter < s_clk_count_val_reg then
                            s_clk_pulse_counter <= s_clk_pulse_counter + 1;
                        else
                            cState_tx <= transmit_data_bits;    
                            s_clk_pulse_counter <= to_unsigned(0, 16);

                        end if;
                    
                    --------------------------------------------------------------------------------
                    --  Start transmission of data bits after signalling the start bit
                    --------------------------------------------------------------------------------
                    when transmit_data_bits =>
                        o_tx_serial <= i_tx_data(to_integer(s_bit_counter));
                        if s_clk_pulse_counter < s_clk_count_val_reg then                 
                            s_clk_pulse_counter <= s_clk_pulse_counter + 1;         --  Hold the data bit on serial output for 1 baud period
                        elsif s_bit_counter < 7 then                                --  If all 8 bits are not transmitted remain in same state
                            cState_tx <= transmit_data_bits;
                            s_clk_pulse_counter <= to_unsigned(0, 16);
                            s_bit_counter <= s_bit_counter + 1;
                        else
                            --------------------------------------------------------------------------------
                            --  If parity is enabled start transmission of parity bit                                    
                            --------------------------------------------------------------------------------
                            if s_parity_en_reg = '1' then         
                                cState_tx <= transmit_parity_bit;
                                s_clk_pulse_counter <= to_unsigned(0, 16);
                                s_bit_counter <= to_unsigned(0, 3);
                            --------------------------------------------------------------------------------
                            --  Else start transmission of stop bit
                            --------------------------------------------------------------------------------
                            else
                                cState_tx <= transmit_stop_bit; -- Else transmit stop bit
                                s_clk_pulse_counter <= to_unsigned(0, 16);
                                s_bit_counter <= to_unsigned(0, 3);
                            end if;
                        end if;
                    
                    --------------------------------------------------------------------------------
                    --  If parity is enabled, transmit parity bit
                    --------------------------------------------------------------------------------
                    when transmit_parity_bit =>
                        o_tx_serial <= s_tx_parity_bit;                             --  Parity bit generated using parity logic
                        if s_clk_pulse_counter < s_clk_count_val_reg then
                            s_clk_pulse_counter <= s_clk_pulse_counter + 1;         --  Hold the parity bit on serial output for 1 baud period
                        else
                            cState_tx <= transmit_stop_bit;                         --  Start transmission of stop bit
                            s_clk_pulse_counter <= to_unsigned(0, 16);
                        end if;
                    
                    --------------------------------------------------------------------------------
                    --  Hold the serial output high for 1 baud period to signal stop bit
                    --------------------------------------------------------------------------------
                    when transmit_stop_bit => 
                        o_tx_serial <= '1';                                         
                        if s_clk_pulse_counter < s_clk_count_val_reg then
                            s_clk_pulse_counter <= s_clk_pulse_counter + 1;
                        else
                            cState_tx <= idle;
                            o_tx_busy <= '0';
                            s_clk_pulse_counter <= to_unsigned(0, 16);
                        end if;
                        
                    when others =>                                                  --  Default case
                        s_clk_pulse_counter <= to_unsigned(0, 16);
                        s_bit_counter <= to_unsigned(0, 3);
                        o_tx_busy <= '0';
                        cState_tx <= idle;
                end case;
            end if;
        end if;
    end process tx_process;
end tx_beh;
