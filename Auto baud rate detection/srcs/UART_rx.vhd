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
    port    (   rx_en : in STD_LOGIC;                           -- Input to enable/disable reciever (Active High)
                rst : in STD_LOGIC;                             -- Input to reset the module
                clk_baud_os : in STD_LOGIC;                     -- Input clock signal at 16x the baud rate
                rx_in : in STD_LOGIC;                           -- Serial input from the transmitter
                parity_en : in STD_LOGIC;                       -- Input to enable the parity
                parity_select : in STD_LOGIC;                   -- Input to select type of parity to be used (0 - Even, 1 - Odd)
                rx_busy : out STD_LOGIC;                        -- Output current state of the reciever module (Busy/Idle)
                rx_invalid : out STD_LOGIC;                     -- Output the validity of recieved data
                rx_data_out : out std_logic_vector(7 downto 0));-- Parallel output of the recieved bits
end UART_rx;

architecture rx_beh of UART_rx is
    type rx_states is (idle, recieve_bits);                     -- The state machine requires only two state : One for when it is idle and one for when it is recieving bits
    signal cState_rx : rx_states := idle;                       -- Current state of state machine
    signal rx_busy_sig, rx_parity_valid : STD_LOGIC := '0';                      
    signal baud_count, bit_count, bits_per_frame : unsigned(3 downto 0) := (others => '0'); -- Counters used to counting the clock pulses and count the number of bits recieved respectively
    signal rx_reg : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');        -- Shift register used to storing each of the recieved bit (Stores 8 data bits and 1 stop bit and 1 parity bit if enabled)
    signal rx_SYNC_FF1, rx_SYNC_FF2 : STD_LOGIC := '1';                     -- Flip-Flops to synchronize the asynchronous rx_in with the clk_baud_os clock signal
    signal rx_parity_gen_logic : STD_LOGIC_VECTOR(8 downto 0);
    signal parity_en_reg, parity_select_reg : STD_LOGIC := '0';
begin

    rx_busy <= rx_busy_sig;
    bits_per_frame <= to_unsigned(9, 4) when parity_en_reg = '0' else       -- Number of bits per UART frame (8 data bits + 1 stop bit and 1 parity bit if enabled)
                      to_unsigned(10, 4);

    
    rx_parity_gen_logic(0) <= rx_reg(0);
    rx_parity_gen:for i in 1 to 8 generate                                  -- Parity logic generator
        rx_parity_gen_logic(i) <= rx_parity_gen_logic(i - 1) xor rx_reg(i); 
    end generate;

    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process to check parity.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    parity_check:process
    begin
        if parity_en_reg = '1' and parity_select_reg = '0' then             -- If even parity is enabled.
            if rx_parity_gen_logic(8) = '0' then 
                rx_parity_valid <= '1';
            else
                rx_parity_valid <= '0';
            end if;
        elsif parity_en_reg = '1' and parity_select_reg = '1' then          -- If odd parity is enabled.
            if rx_parity_gen_logic(8) = '1' then 
                rx_parity_valid <= '1';
            else
                rx_parity_valid <= '0';
            end if;
        else                                                                -- If parity is disabled.
            rx_parity_valid <= '1';
        end if;
    end process parity_check;
    
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process to assert the invalid flag if there is framing error or the parity is incorrect.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    
    invalid_check:process(rst, rx_busy_sig)                     
    begin
       if rst = '1' then
           rx_invalid <= '0';       
       elsif falling_edge(rx_busy_sig) then
           if rx_reg(to_integer(bits_per_frame) - 1) = '1' and rx_parity_valid = '1' then
               rx_invalid <= '0';
           else
               rx_invalid <= '1';
           end if;
       end if;
    end process invalid_check;



    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process which implements the actual state machine.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------

    rx_process:process(clk_baud_os, rst)
    begin
        
        if rst = '1' then                   -- When the reset input is high clear all counters and shift registers.
                cState_rx <= idle;
                baud_count <= to_unsigned(0, 4);
                bit_count <= to_unsigned(0, 4);
                rx_reg <= (others => '0');
                rx_data_out <= (others => '0');
                rx_SYNC_FF1 <= '1';
                rx_SYNC_FF2 <= '1';
                parity_en_reg <= '0';
                parity_select_reg <= '0';
                
         elsif rising_edge(clk_baud_os) then
            if rx_en = '1' then
                rx_SYNC_FF1 <= rx_in;
                rx_SYNC_FF2 <= rx_SYNC_FF1;
                case cState_rx is
                    when idle =>
                        parity_en_reg <= parity_en;	                      -- Enable/Disable parity when rx is idle
                        parity_select_reg <= parity_select;               -- Change type of parity used when rx is idle
                        rx_busy_sig <= '0';               	              -- Deassert the busy flag
                        if rx_SYNC_FF2 = '0' and baud_count < 8 then      -- Wait for 8 clock periods (1 clock period = baud rate / 16) before sampling the start bit. 
                            baud_count <= baud_count + 1;
                            cState_rx <= idle;
                        elsif rx_SYNC_FF2 = '0' and baud_count = 8 then   -- If the recieved bit is '0' after 8 clock periods then a start bit has been encountered so we start recieveing the data bits.
                            cState_rx <= recieve_bits;
                            baud_count <= to_unsigned(0, 4);
                        else                                              -- Else clear the baud_count counter and stay in idle state.
                            cState_rx <= idle;
                            baud_count <= to_unsigned(0, 4);
                        end if;   
                            
                    when recieve_bits =>    
                        rx_busy_sig <= '1';                                     -- Assert the busy flag
                        if bit_count < bits_per_frame and baud_count < 15 then	-- Wait for 16 clock periods before sampling the recieved bit
                            baud_count <= baud_count + 1;
                        
                        elsif bit_count < bits_per_frame then                   -- If less that 10 bits (8 data bits + 1 parity bit + 1 stop bit) have been recieved shift the recieved bit into shift register
                            rx_reg <= rx_SYNC_FF2 & rx_reg(9 downto 1);
                            bit_count <= bit_count + 1;
                            baud_count <= to_unsigned(0, 4);
                            cState_rx <= recieve_bits;
                        else                                                    -- If all the bits have been recieved clear the bit_count counter and go to idle state   
                            if parity_en_reg = '0' then
                                rx_data_out <= rx_reg(8 downto 1);
                            else
                                rx_data_out <= rx_reg(7 downto 0);
                            end if;
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
