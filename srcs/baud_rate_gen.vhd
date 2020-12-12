-----------------------------------------------------------------------------------
-- Created by : Anirudh Srinivasan
-- 
-- Design Name: UART Module
-- Component Name: Baud pulse generator
-- Target Device: Spartan 6
-- Description:
--    This module can auto detect the incoming baud rate and
--	  generates a clock pulse at a frequency 16 times the baud rate.
-----------------------------------------------------------------------------------
            
            

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity baud_pulse_gen is
     generic	(	baud_rate : integer := 9600;        -- Parameter to specify the baud rate
                    clk_freq : integer := 12e6);        -- Clock frequency of the FPGA
    Port ( rst : in STD_LOGIC;                          -- Reset input
           clk : in  STD_LOGIC;                         -- Clock signal from Crystal Oscillator
           sync_byte_in : in STD_LOGIC;                 -- Serial input used for recieveing the sync character 
           parity_en : in STD_LOGIC;                    -- Input to specify whether parity is enabled
           auto_baud_en : in STD_LOGIC;                 -- Input to activate auto detection of baud rate
           clk_baud_oversampled : out  STD_LOGIC;       -- Output clock pulse at 16x the baud rate
           rx_en : out STD_LOGIC;                       -- Output to enable reciever
           tx_en : out STD_LOGIC;                       -- Output to enable transmitter
           rx_tx_synced : out STD_LOGIC);               -- Output the current state of synchronization	
end baud_pulse_gen;

architecture baud_beh of baud_pulse_gen is
    
    type sync_states is (desynced, syncing, finish_sync, synced);
    signal cState : sync_states := desynced;
    
    signal tick_count, bit_count, bit_count_os, baud_count : unsigned(11 downto 0) := (others => '0');
    signal num_bits, bits_per_frame : unsigned(3 downto 0) := (others => '0');
    signal baud_os : STD_LOGIC := '0';
    signal rx_SYNC_FF1, rx_SYNC_FF2 : STD_LOGIC := '0';
    signal auto_baud_en_reg, parity_en_reg : STD_LOGIC := '0';

    
begin

    clk_baud_oversampled <= baud_os;
    bits_per_frame <= to_unsigned(9, 4) when parity_en_reg = '0' else   -- Number bits transmitted in one UART Frame
                      to_unsigned(10, 4);
     
    sync_proc:process(clk)
    begin
        if rising_edge(clk) then
            rx_SYNC_FF1 <= sync_byte_in;
            rx_SYNC_FF2 <= rx_SYNC_FF1;
            if rst = '1' then                           -- Reset all counters and registers to 0 and check whether auto baud rate and parity have been enabled/disabled
                rx_tx_synced <= '0';
                rx_en <= '0';
                tx_en <= '0';
                cState <= desynced;
                baud_count <= to_unsigned(0, 12);
                baud_os <= '0';
                bit_count <= to_unsigned(0, 12);
                bit_count_os <= to_unsigned(0, 12);
                tick_count <= to_unsigned(0, 12);
                auto_baud_en_reg <= auto_baud_en;
                parity_en_reg <= parity_en;
            else
                case cState is			
                    when desynced =>
                        if auto_baud_en = '0' then      -- If auto baud rate is disabled then use default baud rate.
                            cState <= synced;
                            bit_count_os <= to_unsigned(clk_freq / (2 * 16 * baud_rate), 12);
                        else
                            rx_tx_synced <= '0';
                            rx_en <= '0';
                            tx_en <= '0';
                            if rx_SYNC_FF2 = '0' then
                                bit_count_os <= to_unsigned(0, 12);
                                cState <= syncing;
                            else
                                cState <= desynced;
                            end if;
                        end if;	
                            
                    when syncing =>                     -- Count number of clock pulses between falling edge of start bit and rising edge of LSB of data
                        rx_tx_synced <= '0';
                        rx_en <= '0';
                        tx_en <= '0';
                        if rx_SYNC_FF2 = '1' then
                            bit_count_os <= "00000" & tick_count(11 downto 5);
                            bit_count <= tick_count;
                            cState <= finish_sync;
                        else
                            tick_count <= tick_count + 1;
                            cState <= syncing;
                        end if;
                        
                    when finish_sync =>                 -- Wait for transmission of the rest of the bits	
                        rx_tx_synced <= '0';
                        rx_en <= '0';
                        tx_en <= '0';
                        if num_bits < bits_per_frame then
                            if baud_count < bit_count then 
                                baud_count <= baud_count + 1;
                                cState <= finish_sync;
                            else
                                baud_count <= to_unsigned(0, 12);
                                num_bits <= num_bits + 1;
                                cState <= finish_sync;
                            end if;
                        else
                            baud_count <= to_unsigned(0, 12);
                               cState <= synced;
                        end if;
                    
                    when synced =>                      -- Once synchronization has been achieved generate required oversampled baud pulse until the module is reset
                        rx_tx_synced <= '1';
                        rx_en <= '1';
                        tx_en <= '1';
                        if to_integer(baud_count) < to_integer(bit_count_os) then
                            baud_count <= baud_count + 1;
                            cState <= synced;
                        else
                            baud_count <= to_unsigned(0, 12);
                            baud_os <= not baud_os;
                            cState <= synced;
                        end if;
                        
                    when others =>
                        cState <= desynced;
                        bit_count_os <= to_unsigned(0, 12);
                    end case;
            end if;
        end if;
    end process sync_proc;
    
end baud_beh;

