
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use STD.ENV.FINISH;

entity uart_tb is
end uart_tb;

architecture tb_beh of uart_tb is
    constant baud_rate_tb : integer := 9600;
    constant clk_rate_tb : integer := 12e6;
    constant baud : time := 104.16666us;			-- (1 / 9600) seconds
    signal clk_12MHz : STD_LOGIC := '0';
    signal rst, start_tx, rx, tx, rx_busy, tx_busy, rx_invalid : STD_LOGIC := '0';
    signal rx_data, tx_data : STD_LOGIC_VECTOR(7 downto 0);
begin
    
    rx <= tx;			-- Gives the serial output of the transmitter back to the serial input of reciever 
    
    DUT:entity work.UART 
            generic map	(  baud_rate => baud_Rate_tb,
                           clk_rate => clk_Rate_tb)
            Port map ( 	clk => clk_12MHz,
                        rst => rst,
                        rx => rx,
                        start_tx => start_tx,
                        rx_busy => rx_busy,
                        rx_invalid => rx_invalid,
                        rx_data => rx_data,
                        tx_busy => tx_busy,
                        tx_data => tx_data,
                        tx => tx);
                        
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process to generate 12MHz clock signal.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------	
    clk_gen:process
    begin
        clk_12MHz <= '0';
        wait for 41.666666666ns;  
        clk_12MHz <= '1';
        wait for 41.666666666ns;  
    end process clk_gen;
    
--    tb_proc:process
--    begin
--        rx <= '1';
--        wait for 2 * baud;
--        rx <= '0';
--        wait for baud / 4;
--        wait for 1.13 us;
--        rx <= '1';
--        wait for 2.5 * baud;
--        wait for 13 us;
--        rx <= '0';
--        wait for baud;
--        rx <= '1';
--        wait for baud;
--        rx <= '0';
--        wait for baud;
--        rx <= '1';
--        wait for baud;
--        rx <= '0';
--        wait for baud;
--        rx <= '1';
--        wait for baud;
--        rx <= '0';
--        wait for baud;
--        rx <= '1';
--        wait for baud;
--        rx <= '0';
--        wait for baud;
--        rx <= '0';
--        wait for 3 * baud;
--        wait for 1.37 us;
--        rst <= '1';
--        wait for 10 us;
--        rst <= '0';
--        wait for 3 * baud;
--        finish;
                
--    end process tb_proc;

    tb_proc:process
    begin
        rst <= '1';
        wait for 10 us;
        rst <= '0';
        wait for 3 * baud;
        tx_data <= "01010101";
        wait for 2 * baud;
        start_tx <= '1';
        wait for baud;
        start_tx <= '0';
        wait for 1 ms;
        tx_data <= "01101001";
        wait for 2 * baud;
        start_tx <= '1';
        wait for baud;
        start_tx <= '0';
        wait for 5 ms;
        
        finish;
    end process tb_proc;
    
end tb_beh;
