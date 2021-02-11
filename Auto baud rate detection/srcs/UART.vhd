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
    generic	(	baud_rate : integer := 9600;
                clk_freq : integer := 12e6);
    port ( 	clk : in  STD_LOGIC;                        -- Clock signal from the FPGA's crystal oscillator
            rst : in STD_LOGIC;                         -- Input reset signal 
            rx_in : in  STD_LOGIC;                      -- Serial input from a transmitter
            start_tx : in STD_LOGIC;                    -- Input signal to trigger transmission of data
            tx_data_in : in STD_LOGIC_VECTOR(7 downto 0);   -- Input Data to be transmitted serially
            auto_baud_en : in STD_LOGIC;                -- Input to enable auto synchronization (active high)
            parity_en : in STD_LOGIC;                   -- Input to enable the parity
            parity_select : in STD_LOGIC;               -- Input to select type of parity to be used (0 - Even, 1 - Odd)
            rx_tx_synced : out STD_LOGIC;               -- Output state of synchronization
            rx_busy : out STD_LOGIC;                    -- Output current state of the reciever module
            tx_busy : out STD_LOGIC;                    -- Output current state of the transmitter module
            rx_invalid : out STD_LOGIC;                 -- Output the validity of recieved data
            rx_data_out : out STD_LOGIC_VECTOR(7 downto 0); -- Recieved bits as a 8 bit output
            tx_out : out  STD_LOGIC);                   -- Serial output from transmitter module
end UART;

architecture UART_beh of UART is
    
    signal clk_baud_os : STD_LOGIC := '0';
    signal rx_en, tx_en : STD_LOGIC := '0';

begin
    
    --------------------------------------------------------------------------------
    -- Clock signal generator whose frequency is 16x the baud rate
    --------------------------------------------------------------------------------
    clk_gen : entity work.baud_pulse_gen
                    generic map (	baud_rate => baud_rate,
                                    clk_freq => clk_freq)
                    port map	( 	rst => rst,
                                    clk => clk,
                                    sync_byte_in => rx_in,
                                    auto_baud_en => auto_baud_en,
                                    parity_en => parity_en,
                                    rx_tx_synced=> rx_tx_synced,
                                    clk_baud_oversampled => clk_baud_os,
                                    rx_en => rx_en,
                                    tx_en => tx_en);
                                    

    --------------------------------------------------------------------------------
    -- UART reciever module
    --------------------------------------------------------------------------------

    uart_rx : entity work.UART_rx
                    port map	(	rx_en => rx_en,
                                    rst => rst,
                                    clk_baud_os => clk_baud_os,
                                    rx_in => rx_in,
                                    parity_en => parity_en,
                                    parity_select => parity_select,
                                    rx_busy => rx_busy,
                                    rx_invalid => rx_invalid,
                                    rx_data_out => rx_data_out);


    --------------------------------------------------------------------------------
    -- UART transmitter module
    --------------------------------------------------------------------------------
    uart_tx	: entity work.uart_tx
                    port map	(	tx_en => tx_en,
                                    rst => rst,
                                    clk_baud_os => clk_baud_os,
                                    start_tx => start_tx,
                                    tx_data_in => tx_data_in,
                                    parity_en => parity_en,
                                    parity_select => parity_select,
                                    tx_busy => tx_busy,
                                    tx_out => tx_out);
end UART_beh;

