------------------------------------------------------------------------------------------
-- Created by : Anirudh Srinivasan
-- 
-- Design Name: UART Module
-- Component Name: UART
-- Target Device: Spartan 6
-- Description:
--    This is the top module which ties together the clock pulse generator,
--	  the UART reciever module and UART transmitter
------------------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART is
    generic (   clk_rate : integer := 12e6);
    port ( 	clk : in  STD_LOGIC;                        -- Clock signal from the FPGA's crystal oscillator
            rst : in STD_LOGIC;                         -- Input reset signal 
            i_rx_in : in  STD_LOGIC;                      -- Serial input from a transmitter
            i_rw_en : in std_logic;
            i_write_en : in std_logic;
            i_write_addr : in std_logic_vector(1 downto 0);   -- Input Data to be transmitted serially
            i_write_data : in std_logic_vector(31 downto 0);  -- Input to enable the parity
            i_read_addr : in std_logic_vector(1 downto 0);    -- Input to select type of parity to be used (0 - Even, 1 - Odd)
            o_read_data : out std_logic_vector(31 downto 0);  -- Output current state of the reciever module
            o_interrupt : out STD_LOGIC;                -- Output current state of the transmitter module
            o_tx_out : out  STD_LOGIC);                   -- Serial output from transmitter module
end UART;

architecture UART_beh of UART is

    signal s_rx_en : std_logic;
    signal s_tx_en : std_logic;
    signal s_parity_en : std_logic;
    signal s_parity_sel : std_logic;
    signal s_use_count_reg : std_logic;
    signal s_ROM_addr : std_logic_vector(2 downto 0);
    signal s_clk_baud_os : STD_LOGIC := '0';
    signal s_control_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal s_rx_reg, s_rx_data_out : std_logic_vector(7 downto 0) := (others => '0');
    signal s_tx_reg, s_tx_prev_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal s_count_reg : std_logic_vector(31 downto 0);
    signal s_rx_invalid : std_logic;
    signal s_rx_busy : std_logic;
    signal s_tx_busy : std_logic;
    signal s_start_tx : std_logic;
    signal idle : std_logic;

begin

    s_rx_en <= s_control_reg(7);
    s_tx_en <= s_control_reg(6);
    s_parity_en <= s_control_reg(5);
    s_parity_sel <= s_control_reg(4);
    s_use_count_reg <= s_control_reg(3);
    s_ROM_addr <= s_control_reg(2 downto 0);
    
    o_interrupt <= s_rx_invalid;
    
    reg_write_proc: process(clk, rst)
    begin
        if rst = '1' then
            s_tx_reg <= (others => '0');
            s_count_reg <= (others => '0');
            s_control_reg <= (others => '0');
            s_rx_reg <= (others => '0');
            s_tx_prev_reg <= (others => '0');
        elsif rising_edge(clk) then
            s_tx_prev_reg <= s_tx_reg;
            s_rx_reg <= s_rx_data_out;
            if i_rw_en = '1' and i_write_en = '1' then
                if i_write_addr = "00" then
                    s_control_reg <= i_write_data(7 downto 0);
                elsif i_write_addr = "01" then
                    s_count_reg <= i_write_data;
                elsif i_write_addr = "10" then
                    s_tx_reg <= i_write_data(7 downto 0);
                end if;
            end if;
        end if;
    end process reg_write_proc;

    reg_read_proc: process(i_rw_en, i_write_en, i_read_addr, s_control_reg, s_count_reg, s_tx_reg, s_rx_reg)
    begin
        if i_rw_en = '1' and i_write_en = '0' then
            if i_read_addr = "00" then
                o_read_data(7 downto 0) <= s_control_reg; 
                o_read_data(31 downto 8) <= (others => '0');
            elsif i_read_addr = "01" then
                o_read_data <= s_count_reg; 
            elsif i_read_addr = "10" then
                o_read_data(7 downto 0) <= s_tx_reg; 
                o_read_data(31 downto 8) <= (others => '0');
            elsif i_read_addr = "11" then
                o_read_data(7 downto 0) <= s_rx_reg; 
                o_read_data(31 downto 8) <= (others => '0');
            else
                o_read_data <= (others => '1');
            end if;
        else 
            o_read_data <= (others => 'Z');
        end if;    
    end process reg_read_proc;

    start_tx_proc: process(clk, rst)
    begin
        if rst = '1' then
            s_start_tx <= '0';
        elsif rising_edge(clk) then
            if s_tx_reg /= s_tx_prev_reg and s_tx_busy = '0' then
                s_start_tx <= '1';
            elsif s_tx_reg = s_tx_prev_reg and s_tx_busy = '1' then
                s_start_tx <= '0';
            end if; 
        end if;
    end process start_tx_proc;

    --------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Clock signal generator whose frequency is 16x the baud rate                                                                                          
    --------------------------------------------------------------------------------------------------------------------------------------------------------
    clk_gen : entity work.baud_pulse_gen
                    port map	( 	rst => rst,
                                    clk => clk,
                                    i_count_src_sel => s_use_count_reg,
                                    i_count_input => s_count_reg,
                                    i_ROM_addr => s_ROM_addr,
                                    i_rx_busy => s_rx_busy,
                                    i_tx_busy => s_tx_busy,
                                    o_clk_baud_oversampled => s_clk_baud_os);
                                    

    --------------------------------------------------------------------------------------------------------------------------------------------------------
    -- UART reciever module                                                                                                                                 
    --------------------------------------------------------------------------------------------------------------------------------------------------------
    uart_rx : entity work.UART_rx
                    port map	(	i_rx_en => s_rx_en,
                                    rst => rst,
                                    i_clk_baud_os => s_clk_baud_os,
                                    i_rx_serial => i_rx_in,
                                    i_parity_en => s_parity_en,
                                    i_parity_sel => s_parity_sel,
                                    o_rx_busy => s_rx_busy,
                                    o_rx_invalid => s_rx_invalid,
                                    o_rx_data => s_rx_data_out);

    --------------------------------------------------------------------------------------------------------------------------------------------------------
    -- UART transmitter module                                                                                                                              
    --------------------------------------------------------------------------------------------------------------------------------------------------------
    uart_tx	: entity work.uart_tx
                    port map	(	i_tx_en => s_tx_en,
                                    rst => rst,
                                    i_clk_baud_os => s_clk_baud_os,
                                    i_start_tx => s_start_tx,
                                    i_tx_data => s_tx_reg,
                                    i_parity_en => s_parity_en,
                                    i_parity_sel => s_parity_sel,
                                    o_tx_busy => s_tx_busy,
                                    o_tx_serial => o_tx_out);
end UART_beh;

