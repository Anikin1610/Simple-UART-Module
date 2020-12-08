--------------------------------------------------------------------------------
-- Created by : Anirudh Srinivasan
-- 
-- Design Name: UART Module
-- Component Name: Baud pulse generator
-- Target Device: Spartan 6
-- Description:
--    This module generates a clock pulse at 16 times the baud rate.
--------------------------------------------------------------------------------
			
			

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity baud_pulse_gen is
	 generic	(	baud_rate : integer := 9600;		-- Parameter to specify the baud rate
					clk_rate : integer := 12e6);		-- Clock frequency of the FPGA
    Port ( clk : in  STD_LOGIC;							-- Clock signal from Crystal Oscillator
           baud_oversampled : out  STD_LOGIC);			-- Output clock pulse at 16x the baud rate
end baud_rate_gen;

architecture baud_beh of baud_pulse_gen is

    signal baud_os : STD_LOGIC := '0';
	signal counter : integer range 0 to (clk_rate / (2 * 16 * baud_rate)) := 0;
	
begin

    baud_oversampled <= baud_os;
	
	baud_oversampled_gen:process(clk)
	begin
		if rising_edge(clk) then
            if counter < (clk_rate / (2 * 16 * baud_rate)) then	-- For 50% Duty cycle, the generated clock pulse will remain high or low for clk_rate / (2 * 16 * baud_rate) clock periods
				counter <= counter + 1;
			else
				counter <= 0;
				baud_os <= not baud_os;							
			end if;
		end if;
	end process baud_oversampled_gen;
end baud_beh;

