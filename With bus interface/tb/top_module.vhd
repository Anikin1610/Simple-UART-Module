----------------------------------------------------------------------------------
--  Top module for interfacing the UART module with the PicoBlaze processor
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top_module is
    Port ( i_clk12MHz : in  STD_LOGIC;
           i_rx : in std_logic;
           o_tx : out std_logic;
           o_led : out  STD_LOGIC_VECTOR (7 downto 0));
end top_module;

architecture Behavioral of top_module is
	COMPONENT kcpsm6
	PORT(
		instruction : IN std_logic_vector(17 downto 0);
		in_port : IN std_logic_vector(7 downto 0);
		interrupt : IN std_logic;
		sleep : IN std_logic;
		reset : IN std_logic;
		clk : IN std_logic;          
		address : OUT std_logic_vector(11 downto 0);
		bram_enable : OUT std_logic;
		out_port : OUT std_logic_vector(7 downto 0);
		port_id : OUT std_logic_vector(7 downto 0);
		write_strobe : OUT std_logic;
		k_write_strobe : OUT std_logic;
		read_strobe : OUT std_logic;
		interrupt_ack : OUT std_logic
		);
	END COMPONENT;
	
	COMPONENT uart_synth
	generic( 
		C_FAMILY : string := "S6";
		C_RAM_SIZE_KWORDS : integer := 1;
		C_JTAG_LOADER_ENABLE : integer := 0);
	PORT(
		address : IN std_logic_vector(11 downto 0);
		enable : IN std_logic;
		clk : IN std_logic;          
		instruction : OUT std_logic_vector(17 downto 0);
		rdl : OUT std_logic
		);
	END COMPONENT;
		
	signal s_instruction : std_logic_vector(17 downto 0);
	signal s_address : std_logic_vector(11 downto 0);
	signal s_bram_enable : std_logic;
	signal s_kcpsm6_reset : std_logic;
	signal s_port_id : std_logic_vector(7 downto 0);
	signal s_rw_en : std_logic;
	signal s_write_strobe : std_logic;
	signal s_write_bus : std_logic_vector(7 downto 0);
	signal s_read_bus : std_logic_vector(15 downto 0);
    signal s_interrupt : std_logic := '0';
    signal s_interrupt_ack : std_logic := '0';
    signal kcpsm6_interrupt : std_logic := '0';
	
begin

    led_write_proc: process(i_clk12MHz)
    begin
        if rising_edge(i_clk12MHz) then
            if s_port_id = x"05" then
                o_led <= s_write_bus;
            end if;
        end if;
    end process led_write_proc;

	Inst_kcpsm6: kcpsm6 
	PORT MAP(
		address => s_address,
		instruction => s_instruction,
		bram_enable => s_bram_enable,
		in_port => s_read_bus(7 downto 0),
		out_port => s_write_bus,
		port_id => s_port_id,
		write_strobe => s_write_strobe,
		k_write_strobe => open,
		read_strobe => open,
		interrupt => s_interrupt,
		interrupt_ack => s_interrupt_ack,
		sleep => '0',
		reset => s_kcpsm6_reset,
		clk => i_clk12MHz);
	
	Inst_basic_prog: uart_synth 
	generic map( 
		C_FAMILY => "S6",
		C_RAM_SIZE_KWORDS => 1,
		C_JTAG_LOADER_ENABLE => 1)
	PORT MAP(
		address => s_address,
		instruction => s_instruction,
		enable => s_bram_enable,
		rdl => s_kcpsm6_reset,
		clk => i_clk12MHz);
		
	rw_en_proc: process(s_port_id)
	begin
		if s_port_id(7 downto 2) = "000000" then
			s_rw_en <= '1';
		else
			s_rw_en <= '0';
		end if;
	end process rw_en_proc;
    
    interrupt_control: process(i_clk12MHz)
    begin
        if rising_edge(i_clk12MHz) then
            if s_interrupt_ack = '1' then
                s_interrupt <= '0';
            else 
                if kcpsm6_interrupt = '1' then
                    s_interrupt <= '1';
                else 
                    s_interrupt <= s_interrupt;
                end if;
            end if;
        end if;
    end process interrupt_control;
		
	Inst_UART: entity work.UART PORT MAP(
		i_clk => i_clk12MHz,
		i_rst => s_kcpsm6_reset,
		i_rx_in => i_rx,
		i_rw_en => s_rw_en,
		i_write_en => s_write_strobe,
		i_write_addr => s_port_id(1 downto 0),
		i_write_data(15 downto 8) => x"00",
		i_write_data(7 downto 0) => s_write_bus,
		i_read_addr => s_port_id(1 downto 0),
		o_read_data => s_read_bus,
		o_tx_out => o_tx,
        o_intr => kcpsm6_interrupt,
        i_intr_ack => s_interrupt_ack);
end Behavioral;

