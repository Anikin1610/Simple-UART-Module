library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fifo_buffer is
    generic (
        DATA_WIDTH : integer := 8;
        ADDR_WIDTH : integer := 3
    );
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_wr_en : in std_logic;
        i_wr_data : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        i_rd_en : in std_logic;
        o_rd_data : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        o_rd_valid : out std_logic;
        o_empty : out std_logic;
        o_full : out std_logic
    );
end entity fifo_buffer;

architecture rtl of fifo_buffer is
    type ram_type is array (0 to 2 ** ADDR_WIDTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal ram : ram_type;
    
    signal s_head_index : unsigned(0 to ADDR_WIDTH - 1) := (others => '0');
    signal s_tail_index : unsigned(0 to ADDR_WIDTH - 1) := (others => '0');
    
    signal s_empty : std_logic;
    signal s_full : std_logic;
    signal s_fill_count : unsigned(0 to 2 ** ADDR_WIDTH - 1) := (others => '0');
    
begin
    o_empty <= s_empty;
    o_full <= s_full;
    
    s_empty <= '1' when s_fill_count = 0 else '0';
    s_full <= '1' when s_fill_count =  2 ** ADDR_WIDTH else '0';

    rw_proc: process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            s_fill_count <= (others => '0');
            ram <= (others => (others => '0'));
        elsif rising_edge(i_clk) then
            if i_wr_en = '1' then
                if s_full = '0' then
                    ram(to_integer(s_head_index)) <= i_wr_data;
                    s_head_index <= s_head_index + 1;
                    s_fill_count <= s_fill_count + 1;
                end if;
            end if;

            if i_rd_en = '1' and s_empty = '0' then
                o_rd_data <= ram(to_integer(s_tail_index));
                s_tail_index <= s_tail_index + 1;
                s_fill_count <= s_fill_count - 1;  
                o_rd_valid <= '1';
            else
                o_rd_valid <= '0';
            end if;
        end if;
    end process rw_proc; 
end architecture rtl;