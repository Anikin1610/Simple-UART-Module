-----------------------------------------------------------------------------------
-- Created by : Anirudh Srinivasan
-- 
-- Design Name: UART Module
-- Component Name: Baud pulse generator
-- Target Device: Spartan 6
-- Description:
--    This generates a clock pulse at a frequency 16 times the baud rate.
-----------------------------------------------------------------------------------
            
            
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity baud_pulse_gen is
    generic	(   clk_freq : integer := 12e6);                -- Clock frequency of the FPGA
    Port ( rst : in std_logic;                              --  Reset input
           clk : in  std_logic;                             --  Clock signal from Crystal Oscillator
           i_count_src_sel : in std_logic;                  --  Input Count source select signal (0 => ROM, 1 => External Count Register)
           i_count_input : in std_logic_vector(31 downto 0);  --  Input from the external count value register
           i_ROM_addr : in std_logic_vector(2 downto 0);    --  Input ROM address for selecting predefined count value
           i_rx_busy : in std_logic;                        --  Input busy flag from reciever
           i_tx_busy : in std_logic;                        --  Input busy flag from transmitter
           o_clk_baud_oversampled : out  std_logic);        --  Output clock pulse at 16x the baud rate
end baud_pulse_gen;

architecture baud_rtl of baud_pulse_gen is
    --------------------------------------------------------------------------------
    --  Initializing a 8x32 ROM with pre-defined values for various baud rates
    --------------------------------------------------------------------------------
    type ROM_type is array(0 to 7) of unsigned(31 downto 0);
    signal count_ROM : ROM_type := (    to_unsigned(clk_freq / (2 * 16 * 1200), 32),
                                        to_unsigned(clk_freq / (2 * 16 * 1800), 32),
                                        to_unsigned(clk_freq / (2 * 16 * 2400), 32),
                                        to_unsigned(clk_freq / (2 * 16 * 4800), 32),
                                        to_unsigned(clk_freq / (2 * 16 * 7200), 32),
                                        to_unsigned(clk_freq / (2 * 16 * 9600), 32), 
                                        to_unsigned(clk_freq / (2 * 16 * 14400), 32),
                                        to_unsigned(clk_freq / (2 * 16 * 19200), 32)); 
                                        
    signal s_clk_pulse_counter : unsigned(31 downto 0) := (others => '0');
    signal s_counter_cmp_val : unsigned(31 downto 0) := (others => '0');
    signal s_count_reg, s_count_reg_prev : unsigned(31 downto 0) := (others => '0');
    signal s_baud_pulse : std_logic := '0';
    signal s_ROM_addr_reg, s_ROM_addr_prev : unsigned(2 downto 0) := "101";
    signal s_use_count_reg, s_use_count_prev : std_logic := '0';
begin
    o_clk_baud_oversampled <= s_baud_pulse;
    
    --------------------------------------------------------------------------------
    --  Process to update the internal control registers only when the reciever and
    --  transmitter are idle and to reset the internal registers
    --------------------------------------------------------------------------------
    update_regs_proc: process(clk, rst)
    begin
        if rst = '1' then
            s_use_count_reg <= '0';
            s_ROM_addr_reg <= "101";
            s_count_reg <= (others => '0');
        elsif rising_edge(clk) then
            if i_rx_busy = '0' and i_tx_busy = '0' then
                s_use_count_reg <= i_count_src_sel;
                s_ROM_addr_reg <= unsigned(i_ROM_addr);
                s_count_reg <= unsigned(i_count_input);
            end if;
        end if;
    end process update_regs_proc;


    --------------------------------------------------------------------------------
    --  Multiplexer logic to choose the clock pulse counter's initial value
    --  Select Line = s_use_count_reg
    --  0 => Use Value from ROM
    --  1 => Use Value from external register
    --------------------------------------------------------------------------------
    count_init_val_sel_proc: process(s_use_count_reg, s_count_reg, s_ROM_addr_reg)
    begin
        if s_use_count_reg = '1' then
            s_counter_cmp_val <= s_count_reg;
        else
            s_counter_cmp_val <= count_ROM(to_integer(s_ROM_addr_reg));
        end if;
    end process count_init_val_sel_proc;


    --------------------------------------------------------------------------------
    --  Process to generate a pulse at 16x the baud rate
    --------------------------------------------------------------------------------
    baud_pulse_gen_proc: process(clk, rst)
    begin
        if rst = '1' then
            s_clk_pulse_counter <= to_unsigned(0, 32);
            s_baud_pulse <= '0';
        elsif rising_edge(clk) then 
            if s_clk_pulse_counter = s_counter_cmp_val then
                s_clk_pulse_counter <= to_unsigned(0, 32);
                s_baud_pulse <= not s_baud_pulse; 
            else
                s_clk_pulse_counter <= s_clk_pulse_counter + 1;
            end if;
        end if;
    end process baud_pulse_gen_proc;
end baud_rtl;

