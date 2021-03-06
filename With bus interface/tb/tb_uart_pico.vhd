LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
ENTITY tb_uart_pico IS
END tb_uart_pico;
 
ARCHITECTURE behavior OF tb_uart_pico IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT top_module
    PORT(
         i_clk12MHz : IN  std_logic;
         i_rx : IN  std_logic;
         o_tx : OUT  std_logic;
         o_led : OUT  std_logic_vector(7 downto 0)
		);
    END COMPONENT;
    

   --Inputs
   signal i_clk12MHz : std_logic := '0';
   signal i_rx : std_logic := '1';

 	--Outputs
   signal o_tx : std_logic;
   signal o_led : std_logic_vector(7 downto 0);
   -- No clocks detected in port list. Replace <clock> below with 
   -- appropriate port name 
 
   constant clk_period : time := 83.333333 ns;
	constant baud_period : time := 104.166666 us;

	signal start_rx : std_logic := '0';
 
BEGIN
 
    i_rx <= o_tx;
 
	-- Instantiate the Unit Under Test (UUT)
   uut: top_module PORT MAP (
          i_clk12MHz => i_clk12MHz,
          i_rx => i_rx,
          o_tx => o_tx,
          o_led => o_led
        );

   -- Clock process definitions
   i_clk12MHz_process :process
   begin
		i_clk12MHz <= '0';
		wait for clk_period/2;
		i_clk12MHz <= '1';
		wait for clk_period/2;
   end process;
END;
