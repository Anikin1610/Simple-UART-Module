library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use STD.ENV.FINISH;

entity uart_tb is
end uart_tb;

architecture tb_beh of uart_tb is

    constant baud : time := 104.16666us;			-- (1 / 9600) seconds
    signal clk_12MHz, tb_baud_clk : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';
    signal tb_rx_in : std_logic := '1';
    signal tb_rw_en : std_logic;
    signal tb_write_en : std_logic;
    signal tb_write_addr : std_logic_vector(1 downto 0);
    signal tb_write_data : std_logic_vector(15 downto 0);
    signal tb_read_addr : std_logic_vector(1 downto 0);
    signal tb_read_data : std_logic_vector(15 downto 0);
    signal tb_tx_out : std_logic;
    
    signal reset, start_up, write_count, start_tx : std_logic := '1';
    signal start_rx : std_logic := '0';
    
    signal rx_data : std_logic_vector(10 downto 0) := "11010101010";
    signal i : integer := 0;
    
    
begin
    
--    tb_rx_in <= tb_tx_out;
    
    DUT:entity work.UART 
            Port map ( 	i_clk => clk_12MHz,
                        rst => rst,
                        i_rx_in => tb_rx_in,
                        i_rw_en => tb_rw_en,
                        i_write_en => tb_write_en,
                        i_write_addr => tb_write_addr,
                        i_write_data => tb_write_data,
                        i_read_addr => tb_read_addr,
                        o_read_data => tb_read_data,
                        o_interrupt => open,
                        o_tx_out => tb_tx_out);
                        
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
    
    baud_gen:process
    begin
        tb_baud_clk <= '0';
        wait for baud / 2;
        tb_baud_clk <= '1';
        wait for baud / 2;
    end process;
    
    tb_proc:process(clk_12MHz)
    begin
        if rising_edge(clk_12MHz) then
            if reset = '1' then
                rst <= '1';
                reset <= '0';
            elsif write_count = '1' then
                rst <= '0';
                tb_rw_en <= '1';
                tb_write_en <= '1';
                tb_write_addr <= "01";
                tb_write_data <= x"FFFF";
                write_count <= '0';
            elsif start_up = '1' then
                tb_write_addr <= "00";
                tb_write_data(7 downto 0) <= "11010101";
                tb_write_data(15 downto 8) <= (others => '0');
                start_rx <= '1';
                start_up <= '0';
            elsif start_tx = '1' then
                tb_write_addr <= "10";
                tb_write_data(7 downto 0) <= "01010101";
                tb_write_data(15 downto 8) <= (others => '0');
                start_tx <= '0';
            else
                tb_rw_en <= '0';
                tb_write_en <= '0';
            end if;
        end if;   
    end process tb_proc;
    
    rx_proc:process(tb_baud_clk)
    begin
        if rising_edge(tb_baud_clk) then
            if start_rx = '1' then
                if i < 10 then
                    tb_rx_in <= rx_data(i);
                    i <= i + 1;
                elsif i < 15 then
                    tb_rx_in <= '1';
                    i <= i + 1;
                else
                    finish;
                end if;
            else
                tb_rx_in <= '1';
            end if;
        end if;
    end process rx_proc;
    
end tb_beh;
