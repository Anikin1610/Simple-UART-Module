------------------------------------------------------------------------------------------
-- Created by : Anirudh Srinivasan
-- 
-- Design Name: UART Module
-- Component Name: UART
-- Target Device: Spartan 6
-- Description:
--    This is the which implements the bus interface to interface with the 
--    reciever and transmitter
------------------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART is
    generic (   clk_rate : integer := 12e6);
    port ( 	i_clk : in  STD_LOGIC;                      --  Clock signal from the FPGA's crystal oscillator
            rst : in STD_LOGIC;                         --  Input reset signal 
            i_rx_in : in  STD_LOGIC;                    --  Serial input from a transmitter
            i_rw_en : in std_logic;                     --  Bus read/write enable Input
            i_write_en : in std_logic;                  --  Bus write enable Input
            i_write_addr : in std_logic_vector(1 downto 0);     --  Input write address
            i_write_data : in std_logic_vector(15 downto 0);    --  Input write data
            i_read_addr : in std_logic_vector(1 downto 0);      --  Input read address
            o_read_data : out std_logic_vector(15 downto 0);    --  Output read data
            o_interrupt : out STD_LOGIC;                --  Output interrupt signal
            o_tx_out : out  STD_LOGIC);                 --  Serial output from transmitter module
end UART;

architecture UART_beh of UART is

    constant clk_freq : integer := 12e6;

    signal s_rx_en : std_logic;                         --  Internal reciever enable signal
    signal s_tx_en : std_logic;                         --  Internal transmitter enable signal
    signal s_parity_en : std_logic;                     --  Internal parity enable signal
    signal s_parity_sel : std_logic;                    --  Internal parity type select signal
    signal s_use_count_reg : std_logic;                 --  Internal baud period enable signal
    signal s_ROM_addr : std_logic_vector(2 downto 0);   --  Internal ROM address signal
    signal s_control_reg : std_logic_vector(7 downto 0) := (others => '0');             --  Internal control register
    signal s_rx_reg, s_rx_data_out : std_logic_vector(7 downto 0) := (others => '0');   --  Internal recieved data register
    signal s_tx_reg : std_logic_vector(7 downto 0) := (others => '0');                  --  Internal transmission data register
    signal s_count_reg : std_logic_vector(15 downto 0);                                 --  Internal baud period count register
    signal s_count_val_mux : std_logic_vector(15 downto 0);                             --  Baud period selection multiplexer
    signal s_rx_invalid : std_logic;                    --  Internal data reception failed signal
    signal s_rx_busy : std_logic;                       --  Internal reciever busy signal
    signal s_tx_busy : std_logic;                       --  Internal transmitter busy signal

    type ROM_type is array(0 to 7) of unsigned(15 downto 0);                            --  Type of 8 x 16 ROM for storing counts for pre-defined baud periods
    signal s_count_ROM : ROM_type := (  to_unsigned(clk_freq / 1200, 16),               --  Internal ROM for storing counts for various baud periods
                                        to_unsigned(clk_freq / 1800, 16),
                                        to_unsigned(clk_freq / 2400, 16),
                                        to_unsigned(clk_freq / 4800, 16),
                                        to_unsigned(clk_freq / 7200, 16),
                                        to_unsigned(clk_freq / 9600, 16), 
                                        to_unsigned(clk_freq / 14400, 16),
                                        to_unsigned(clk_freq / 19200, 16)); 

begin

    --------------------------------------------------------------------------------
    --  8-Bit Control register mapping:
    --  Bits 2 to 0 -> Input address for ROM
    --  Bit 3   ->  0 => Use ROM value, 1 => Use count register value
    --  Bit 4   ->  0 => Disable parity, 1 => Enable parity
    --  Bit 5   ->  0 => Use even parity, 1 => Use odd parity
    --  Bit 6   ->  0 => Disable Tx, 1 => Enable Tx 
    --  Bit 7   ->  0 => Disable Rx, 1 => Enable Rx
    --------------------------------------------------------------------------------
    s_rx_en <= s_control_reg(7);                        
    s_tx_en <= s_control_reg(6);
    s_parity_sel <= s_control_reg(5);
    s_parity_en <= s_control_reg(4);
    s_use_count_reg <= s_control_reg(3);
    s_ROM_addr <= s_control_reg(2 downto 0);
    
    --------------------------------------------------------------------------------
    --  Raise interrupt if the recieved byte is invalid
    --------------------------------------------------------------------------------
    o_interrupt <= s_rx_invalid;
    
    --------------------------------------------------------------------------------
    --  Multiplexer for switching between ROM output and counter register
    --------------------------------------------------------------------------------
    count_val_mux_proc: process(s_use_count_reg, s_ROM_addr, s_count_reg)
    begin
        if s_use_count_reg = '1' then
            s_count_val_mux <= s_count_reg;
        else
            s_count_val_mux <= std_logic_vector(s_count_ROM(to_integer(unsigned(s_ROM_addr))));
        end if;
    end process count_val_mux_proc;

    --------------------------------------------------------------------------------
    --  Process for synchronous writes using bus interface
    --------------------------------------------------------------------------------
    reg_write_proc: process(i_clk, rst)
    begin
        if rst = '1' then
            s_tx_reg <= (others => '0');
            s_count_reg <= (others => '0');
            s_control_reg <= (others => '0');
            s_rx_reg <= (others => '0');
        elsif rising_edge(i_clk) then
            s_rx_reg <= s_rx_data_out;
            if i_rw_en = '1' and i_write_en = '1' then
                if i_write_addr = "00" then
                    s_control_reg <= i_write_data(7 downto 0);
                elsif i_write_addr = "01" then
                    s_count_reg <= i_write_data(15 downto 0);
                elsif i_write_addr = "10" then
                    s_tx_reg <= i_write_data(7 downto 0);
                end if;
            end if;
        end if;
    end process reg_write_proc;

    --------------------------------------------------------------------------------
    --  Process for asynchronous reads using bus interface
    --------------------------------------------------------------------------------
    reg_read_proc: process(i_rw_en, i_write_en, i_read_addr, s_control_reg, s_count_reg, s_tx_reg, s_rx_reg)
    begin
        if i_rw_en = '1' and i_write_en = '0' then
            if i_read_addr = "00" then
                o_read_data(7 downto 0) <= s_control_reg; 
                o_read_data(15 downto 8) <= (others => '0');
            elsif i_read_addr = "01" then
                o_read_data(15 downto 0) <= s_count_reg; 
            elsif i_read_addr = "10" then
                o_read_data(7 downto 0) <= s_tx_reg; 
                o_read_data(15 downto 8) <= (others => '0');
            elsif i_read_addr = "11" then
                o_read_data(7 downto 0) <= s_rx_reg; 
                o_read_data(15 downto 8) <= (others => '0');
            else
                o_read_data <= (others => '1');
            end if;
        else 
            o_read_data <= (others => 'Z');
        end if;    
    end process reg_read_proc;                                

    --------------------------------------------------------------------------------
    -- UART reciever module                                                                                                                                 
    --------------------------------------------------------------------------------
    uart_rx : entity work.UART_rx
                    port map	(	i_clk => i_clk,
                                    i_rx_en => s_rx_en,
                                    rst => rst,
                                    i_rx_serial => i_rx_in,
                                    i_parity_en => s_parity_en,
                                    i_parity_sel => s_parity_sel,
                                    i_rom_count_val => s_count_val_mux,
                                    o_rx_busy => s_rx_busy,
                                    o_rx_invalid => s_rx_invalid,
                                    o_rx_data => s_rx_data_out);

    --------------------------------------------------------------------------------
    -- UART transmitter module                                                                                                                              
    --------------------------------------------------------------------------------
    uart_tx	: entity work.uart_tx
                    port map	(	i_clk => i_clk,
                                    i_tx_en => s_tx_en,
                                    rst => rst,
                                    i_tx_data => s_tx_reg,
                                    i_parity_en => s_parity_en,
                                    i_parity_sel => s_parity_sel,
                                    i_rom_count_val => s_count_val_mux,
                                    o_tx_busy => s_tx_busy,
                                    o_tx_serial => o_tx_out);
end UART_beh;

