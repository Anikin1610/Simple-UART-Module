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
                clk_rate : integer := 12e6);
    port ( 	clk : in  STD_LOGIC;						-- Clock signal from the FPGA's crystal oscillator
            rst : in STD_LOGIC;							-- Input reset signal 
            rx : in  STD_LOGIC;							-- Serial input from a transmitter
            start_tx : in STD_LOGIC;					-- Input signal to trigger transmission of data
            tx_data : in STD_LOGIC_VECTOR(7 downto 0);	-- Data to be transmitted serially
            
            rx_busy : out STD_LOGIC;					-- Output busy flag for the reciever module
            tx_busy : out STD_LOGIC;					-- Output busy flag for the transmitter module
            rx_invalid : out STD_LOGIC;					-- Output invalid flag for the reciever module
            rx_data : out STD_LOGIC_VECTOR(7 downto 0);	-- Recieved bits as a 8 bit output
            tx : out  STD_LOGIC);						-- Serial output from transmitter module
end UART;

architecture UART_beh of UART is
    
    signal baud_os : STD_LOGIC := '0';

begin
    
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Clock signal generator whose frqquency is 16x the baud rate
    ---------------------------------------------------------------------------------------------------------------------------------------------------------

    clk_gen : entity work.baud_pulse_gen
                    generic map (	baud_rate => baud_rate,
                                    clk_rate => clk_rate)
                    port map	( 	clk => clk,
                                    baud_oversampled => baud_os);
                                    

    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- UART reciever module
    ---------------------------------------------------------------------------------------------------------------------------------------------------------

    uart_rx : entity work.UART_rx
                    port map	(	rst => rst,
                                    baud_os => baud_os,
                                    rx_in => rx,
                                    rx_busy => rx_busy,
                                    rx_invalid => rx_invalid,
                                    rx_data => rx_data);

    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- UART transmitter module
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    
    uart_tx	: entity work.uart_tx
                    port map	(	rst => rst,
                                    baud_os => baud_os,
                                    start_tx => start_tx,
                                    tx_data => tx_data,
                                    tx_busy => tx_busy,
                                    tx => tx);


end UART_beh;

