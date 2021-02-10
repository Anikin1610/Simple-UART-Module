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
    port    (   i_rx_en : in STD_LOGIC;                        -- Input to enable/disable reciever (Active High)
                rst : in STD_LOGIC;                            -- Input to reset the module
                i_clk_baud_os : in STD_LOGIC;                  -- Input clock signal at 16x the baud rate
                i_rx_serial : in STD_LOGIC;                    -- Serial input from the transmitter
                i_parity_en : in STD_LOGIC;                    -- Input to enable the parity
                i_parity_sel : in STD_LOGIC;                   -- Input to select type of parity to be used (0 - Even, 1 - Odd)
                o_rx_busy : out STD_LOGIC;                     -- Output current state of the reciever module (Busy/Idle)
                o_rx_invalid : out STD_LOGIC;                  -- Output the validity of recieved data
                o_rx_data : out std_logic_vector(7 downto 0)); -- 8-Bit output of recieved bits
end UART_rx;

architecture rx_beh of UART_rx is
    type rx_states is (idle, recieve_bits);                     -- The state machine requires only two state : One for when it is idle and one for when it is recieving bits
    signal cState_rx : rx_states := idle;                       -- Current state of state machine
    signal s_rx_parity_valid : STD_LOGIC := '0';                      
    signal s_baud_pulse_counter, s_bit_count, bits_per_frame : unsigned(3 downto 0) := (others => '0'); -- Counters used to counting the clock pulses and count the number of bits recieved respectively
    signal s_rx_reg : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');        -- Shift register used to storing each of the recieved bit (Stores 8 data bits and 1 stop bit and 1 parity bit if enabled)
    signal rx_SYNC_FF1, rx_SYNC_FF2 : STD_LOGIC := '1';                     -- Flip-Flops to synchronize the asynchronous rx_in with the clk_baud_os clock signal
    signal s_rx_parity_gen : STD_LOGIC_VECTOR(8 downto 0);
    signal s_parity_en_reg, s_parity_select_reg : STD_LOGIC := '0';
    
    signal s_rx_frame_err : std_logic := '0';
    signal s_rx_parity_err : std_logic := '0';
    
begin  
    o_rx_invalid <= s_rx_frame_err or s_rx_parity_err;
    
    bits_per_frame <= to_unsigned(9, 4) when s_parity_en_reg = '0' else       -- Number of bits per UART frame (8 data bits + 1 stop bit and 1 parity bit if enabled)
                      to_unsigned(10, 4);

    
    s_rx_parity_gen(0) <= s_rx_reg(0);
    rx_parity_gen:for i in 1 to 8 generate                                  -- Parity logic generator
        s_rx_parity_gen(i) <= s_rx_parity_gen(i - 1) xor s_rx_reg(i); 
    end generate;

    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process to check parity.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    parity_check:process(s_parity_en_reg, s_parity_select_reg, s_rx_parity_gen)  
    begin
        if s_parity_en_reg = '1' and s_parity_select_reg = '0' then             -- If even parity is enabled.
            if s_rx_parity_gen(8) = '0' then 
                s_rx_parity_valid <= '1';
            else
                s_rx_parity_valid <= '0';
            end if;
        elsif s_parity_en_reg = '1' and s_parity_select_reg = '1' then          -- If odd parity is enabled.
            if s_rx_parity_gen(8) = '1' then 
                s_rx_parity_valid <= '1';
            else
                s_rx_parity_valid <= '0';
            end if;
        else                                                                -- If parity is disabled.
            s_rx_parity_valid <= '1';
        end if;
    end process parity_check;
    
    
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process which implements the actual state machine.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    rx_process:process(i_clk_baud_os, rst)
    begin
        if rst = '1' then                   -- When the reset input is high clear all counters and shift registers.
                cState_rx <= idle;
                s_baud_pulse_counter <= to_unsigned(0, 4);
                s_bit_count <= to_unsigned(0, 4);
                s_rx_reg <= (others => '0');
                o_rx_data <= (others => '0');
                rx_SYNC_FF1 <= '1';
                rx_SYNC_FF2 <= '1';
                s_parity_en_reg <= '0';
                s_parity_select_reg <= '0';
                o_rx_busy <= '0';
                
         elsif rising_edge(i_clk_baud_os) then
            if i_rx_en = '1' then
                rx_SYNC_FF1 <= i_rx_serial;
                rx_SYNC_FF2 <= rx_SYNC_FF1;
                case cState_rx is
                    when idle =>
                        s_rx_parity_err <= s_rx_parity_err;
                        s_rx_frame_err <= s_rx_frame_err;
                        s_parity_en_reg <= i_parity_en;	                     -- Enable/Disable parity when rx is idle
                        s_parity_select_reg <= i_parity_sel;              -- Change type of parity used when rx is idle
                        o_rx_busy <= '0';               	             -- Deassert the busy flag
                        if rx_SYNC_FF2 = '0' and s_baud_pulse_counter < 8 then     -- Wait for 8 clock periods (1 clock period = baud rate / 16) before sampling the start bit. 
                            s_baud_pulse_counter <= s_baud_pulse_counter + 1;
                            cState_rx <= idle;
                        elsif rx_SYNC_FF2 = '0' and s_baud_pulse_counter = 8 then  -- If the recieved bit is '0' after 8 clock periods then a start bit has been encountered so we start recieveing the data bits.
                            cState_rx <= recieve_bits;
                            s_baud_pulse_counter <= to_unsigned(0, 4);
                            s_rx_parity_err <= '0';                      --  Deassert the parity error flag while recieveing data
                            s_rx_frame_err <= '0';                       --  Deassert the frame error flag while recieveing data

                        else                                             -- Else clear the s_baud_pulse_counter and stay in idle state.
                            cState_rx <= idle;
                            s_baud_pulse_counter <= to_unsigned(0, 4);
                        end if;   
                            
                    when recieve_bits =>    
                        o_rx_busy <= '1';                                     -- Assert the busy flag
                        if s_bit_count < bits_per_frame and s_baud_pulse_counter < 15 then	-- Wait for 16 clock periods before sampling the recieved bit
                            s_baud_pulse_counter <= s_baud_pulse_counter + 1;
                        
                        elsif s_bit_count < bits_per_frame then                   -- If less that 10 bits (8 data bits + 1 parity bit + 1 stop bit) have been recieved shift the recieved bit into shift register
                            s_rx_reg <= rx_SYNC_FF2 & s_rx_reg(9 downto 1);
                            s_bit_count <= s_bit_count + 1;
                            s_baud_pulse_counter <= to_unsigned(0, 4);
                            cState_rx <= recieve_bits;
                        else                                                    -- If all the bits have been recieved clear the bit_count counter and go to idle state   
                            if s_parity_en_reg = '0' then
                                o_rx_data <= s_rx_reg(8 downto 1);
                                s_rx_parity_err <= '0';
                            else
                                o_rx_data <= s_rx_reg(7 downto 0);
                                if s_rx_parity_valid = '1' then
                                    s_rx_parity_err <= '0';
                                else
                                    s_rx_parity_err <= '1';
                                end if;
                            end if;
                            
                            if s_rx_reg(to_integer(bits_per_frame) - 1) = '1' then
                                s_rx_frame_err <= '0';
                            else
                                s_rx_frame_err <= '1';
                            end if;
                            
                            cState_rx <= idle;
                            s_bit_count <= to_unsigned(0, 4);
                        end if;
                                        
                    when others =>                                  -- Default case
                        o_rx_busy <= '0';
                        cState_rx <= idle;
                        s_baud_pulse_counter <= to_unsigned(0, 4);
                        s_bit_count <= to_unsigned(0, 4);
                        s_rx_reg <= (others => '0');
                end case;
            end if;
        end if;
     end process rx_process;
end rx_beh;
