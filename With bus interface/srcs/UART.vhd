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
            i_rst : in STD_LOGIC;                       --  Input reset signal 
            i_rx_in : in  STD_LOGIC;                    --  Serial input from a transmitter
            i_rw_en : in std_logic;                     --  Bus read/write enable Input
            i_write_en : in std_logic;                  --  Bus write enable Input
            i_write_addr : in std_logic_vector(1 downto 0);     --  Input write address
            i_write_data : in std_logic_vector(15 downto 0);    --  Input write data
            i_read_addr : in std_logic_vector(1 downto 0);      --  Input read address
            o_read_data : out std_logic_vector(15 downto 0);    --  Output read data
            o_tx_out : out  STD_LOGIC;                  --  Serial output from transmitter module
            o_intr : out STD_LOGIC;                     --  Output interrupt signal
            i_intr_ack : in STD_LOGIC);                 --  Input interrupt acknowledge signal

end UART;

architecture UART_beh of UART is

    constant clk_freq : integer := 12e6;

    signal s_rx_en : std_logic;                                                         --  Internal reciever enable signal
    signal s_tx_en : std_logic;                                                         --  Internal transmitter enable signal
    signal s_parity_en : std_logic;                                                     --  Internal parity enable signal
    signal s_parity_sel : std_logic;                                                    --  Internal parity type select signal
    signal s_use_count_reg : std_logic;                                                 --  Internal baud period enable signal
    signal s_ROM_addr : std_logic_vector(2 downto 0) := (others => '0');                --  Internal ROM address signal
    signal s_control_reg : std_logic_vector(7 downto 0) := (others => '0');             --  Internal control register
    signal s_rx_data : std_logic_vector(7 downto 0) := (others => '0');                 --  Internal recieved data register
    signal s_count_reg : std_logic_vector(15 downto 0) := (others => '0');              --  Internal baud period count register
    signal s_count_val_mux : std_logic_vector(15 downto 0) := (others => '0');          --  Baud period selection multiplexer
    signal s_rx_busy : std_logic := '0';                                                --  Internal reciever busy signal
    signal s_rx_busy_prev : std_logic := '0';
    signal s_tx_busy : std_logic := '0';                                                --  Internal transmitter busy signal
    signal s_tx_start : std_logic := '0';                                               --  Internal transmitter start signal register

    type ROM_type is array(0 to 7) of unsigned(15 downto 0);                            --  Type of 8 x 16 ROM for storing counts for pre-defined baud periods
    signal s_count_ROM : ROM_type := (  to_unsigned(clk_freq / 1200, 16),               --  Internal ROM for storing counts for various baud periods
                                        to_unsigned(clk_freq / 1800, 16),
                                        to_unsigned(clk_freq / 2400, 16),
                                        to_unsigned(clk_freq / 4800, 16),
                                        to_unsigned(clk_freq / 7200, 16),
                                        to_unsigned(clk_freq / 9600, 16), 
                                        to_unsigned(clk_freq / 14400, 16),
                                        to_unsigned(clk_freq / 19200, 16)); 
    
    type intr_states is (intr_assert, intr_deassert);
    signal intr_cState : intr_states := intr_deassert;

    type tx_states is (idle, transmit_start_bit, transmit_data_bits, transmit_parity_bit, transmit_stop_bit);         -- The state machine uses 5 states : One for when it is idle, one to transmit start bit, one for transmitting the data bits, one for transmitting the parity bit if enable and one to transmit stop bit.
    signal cState_tx : tx_states := idle;                                               --  Current state of state machine.
    signal s_tx_bit_count : unsigned(2 downto 0) := (others => '0');                  --  Counters to count the number of bits transmitted
    signal s_tx_data_reg : std_logic_vector(7 downto 0) := (others => '0');             --  Previous value of i_tx_data
    signal s_tx_parity_bit : std_logic := '0';                                          --  Generated parity bit to be trasnmitted

    signal s_tx_parity_gen : std_logic_vector(7 downto 0) := (others => '0');           --  Internal parity generation logic
    signal s_tx_parity_en_reg, s_tx_parity_sel_reg : std_logic := '0';                  --  Internal registers to hold the control signal for parity_en and parity_sel during transmission

    signal s_tx_clk_pulse_counter : unsigned(15 downto 0) := (others => '0');           --  16-Bit counter for counting the input clock pulse  
    signal s_tx_clk_count_val_reg : unsigned(15 downto 0) := (others => '0');           --  16-Bit register which holds the value for number clock pulses required for 1 bit

    type rx_states is (idle, recieve_bits);                 --  The state machine requires only two state : One for when it is idle and one for when it is recieving bits
    signal cState_rx : rx_states := idle;                   --  Current state of state machine
    signal s_rx_parity_valid : std_logic := '0';            --  Internal signal which denotes the validity of the input bits based on parity      
    signal s_rx_bit_count, s_bits_per_frame : unsigned(3 downto 0) := (others => '0');  --  Counters to count the number of bits recieved 
    signal s_rx_reg : std_logic_vector(9 downto 0) := (others => '0');                  --  Shift register used to storing each of the recieved bit (Stores 8 data bits and 1 stop bit and 1 parity bit if enabled)
    signal rx_SYNC_FF1, rx_SYNC_FF2 : std_logic := '1';     							--  Flip-Flops to synchronize the asynchronous rx_in with the i_clk clock signal
    
    signal s_rx_parity_gen : std_logic_vector(8 downto 0) := (others => '0');    	    --  Internal parity generation logic  
    signal s_rx_parity_en_reg, s_rx_parity_sel_reg : std_logic := '0'; 					    --  Internal registers to hold the control signal for parity_en and parity_sel during recieving
    
    signal s_rx_clk_pulse_counter : unsigned(15 downto 0) := (others => '0');     		--  16-Bit counter for counting the input clock pulse
    signal s_rx_clk_count_val_reg : unsigned(15 downto 0) := (others => '0');     		--  16-Bit register which holds the value for number clock pulses required for 1 bit

    signal s_rx_frame_err : std_logic := '0';               --  Internal signal for denoting a framing error in the recieved bits
    signal s_rx_parity_err : std_logic := '0';              --  Internal signal for denoting a parity error in the recieved bits


    signal s_rx_wr_en : std_logic;
    signal s_rx_wr_data : std_logic_vector(7 downto 0);
    signal s_rx_rd_en : std_logic;
    signal s_rx_rd_data : std_logic_vector(7 downto 0);
    signal s_rx_empty : std_logic;
    signal s_rx_full : std_logic;

    signal s_tx_wr_en : std_logic;
    signal s_tx_wr_data : std_logic_vector(7 downto 0);
    signal s_tx_rd_en : std_logic;
    signal s_tx_rd_data : std_logic_vector(7 downto 0);
    signal s_tx_empty : std_logic;
    signal s_tx_full : std_logic;
    
    signal s_rx_buffer_overflow : std_logic;
    signal s_tx_buffer_overflow : std_logic;
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
    --  FSM for asserting and deasserting interrupt
    --------------------------------------------------------------------------------
    intr_cState_proc: process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            intr_cState <= intr_deassert;
        elsif rising_edge(i_clk) then
            case intr_cState is
                when intr_deassert =>
                    if s_rx_frame_err = '1' or s_rx_parity_err = '1' or (s_rx_wr_en = '1' and s_rx_full = '1') or (s_tx_wr_en = '1' and s_tx_full = '1') then
                        intr_cState <= intr_assert;
                    else
                        intr_cState <= intr_deassert;
                    end if;
                when intr_assert =>
                    if i_intr_ack = '1' then
                        intr_cState <= intr_deassert;
                    else
                        intr_cState <= intr_assert;
                    end if;
            end case;
        end if;
    end process intr_cState_proc;
    
    intr_output_proc: process(i_clk, intr_cState)
    begin
        if intr_cState = intr_deassert then
            o_intr <= '0';
        else
            o_intr <= '1';
        end if;
    end process intr_output_proc;

    --------------------------------------------------------------------------------
    --  Process for synchronous writes to the control registers using bus interface
    --------------------------------------------------------------------------------
    reg_write_proc: process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            s_count_reg <= (others => '0');
            s_control_reg <= (others => '0');
        elsif rising_edge(i_clk) then
            if i_rw_en = '1' and i_write_en = '1' then
                if i_write_addr = "00" then
                    s_control_reg <= i_write_data(7 downto 0);
                elsif i_write_addr = "01" then
                    s_count_reg <= i_write_data(15 downto 0);
                end if;
            end if;
        end if;
    end process reg_write_proc;

    --------------------------------------------------------------------------------
    --  Process for asynchronous reads using bus interface
    --------------------------------------------------------------------------------
    reg_read_proc: process(i_rw_en, i_write_en, i_read_addr, s_control_reg, s_rx_rd_data, s_tx_full, s_rx_empty)
    begin
        if i_rw_en = '1' and i_write_en = '0' then
            if i_read_addr = "00" then
                o_read_data(7 downto 0) <= s_control_reg;   --  Returns the contents of the control register
                o_read_data(15 downto 8) <= (others => '0');
            elsif i_read_addr = "01" then
                o_read_data(0) <= s_tx_full;                --  Can be read to find out whether transmit buffer is full
                o_read_data(15 downto 1) <= (others => '0'); 
            elsif i_read_addr = "10" then
                o_read_data(0) <= s_rx_empty;               --  Can be read to find out whether recieve buffer is empty
                o_read_data(15 downto 1) <= (others => '0');
            elsif i_read_addr = "11" then
                o_read_data(7 downto 0) <= s_rx_rd_data;    --  Returns the data at the tail of recieve buffer
                o_read_data(15 downto 8) <= (others => '0');
            else
                o_read_data <= (others => '1');
            end if;
        else 
            o_read_data <= (others => 'Z');
        end if;    
    end process reg_read_proc;                       
    

    --------------------------------------------------------------------------------
    -- FIFO Buffer for reciever    
    --------------------------------------------------------------------------------
    fifo_rx_inst : entity work.fifo_buffer
    generic map (
      DATA_WIDTH => 8,
      ADDR_WIDTH => 3
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_wr_en => s_rx_wr_en,
      i_wr_data => s_rx_wr_data,
      i_rd_en => s_rx_rd_en,
      o_rd_data => s_rx_rd_data,
      o_empty => s_rx_empty,
      o_full => s_rx_full
    );
    
    s_rx_wr_data <= s_rx_data;
    
    --------------------------------------------------------------------------------
    -- Process to assert read enable of recieve FIFO buffer 
    --------------------------------------------------------------------------------    
    rx_rd_buffer_proc: process(s_rx_full, i_write_en, i_rw_en, i_read_addr, s_rx_empty)
    begin
        if i_read_addr = "11" and i_write_en = '0' and i_rw_en = '1' then
            if s_rx_empty = '0' then
                s_rx_rd_en <= '1';
            else
                s_rx_rd_en <= '0';
            end if;
        else
            s_rx_rd_en <= '0';
        end if;
    end process rx_rd_buffer_proc;
    
    --------------------------------------------------------------------------------
    -- Process to update value of rx_busy_prev register    
    --------------------------------------------------------------------------------    
    rx_busy_prev_proc: process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            s_rx_busy_prev <= '0';
        elsif rising_edge(i_clk) then
            s_rx_busy_prev <= s_rx_busy;
        end if;
    end process rx_busy_prev_proc;
    
    --------------------------------------------------------------------------------
    -- Process to write to recieve buffer
    -- Writes happen only when the reciever has just become idle.
    --------------------------------------------------------------------------------
    rx_wr_buffer_proc: process(s_rx_busy, s_rx_busy_prev)
    begin
        if s_rx_busy = '0' and s_rx_busy_prev = '1' then
                s_rx_wr_en <= '1';
        else    
                s_rx_wr_en <= '0';
        end if;
    end process rx_wr_buffer_proc;


    --------------------------------------------------------------------------------
    -- UART RECIEVER MODULE
    --------------------------------------------------------------------------------  
    rx_data_sel_mux: process(s_rx_parity_en_reg, s_rx_reg)
    begin
        if s_rx_parity_en_reg = '0' then
            s_rx_data <= s_rx_reg(8 downto 1);
        else
            s_rx_data <= s_rx_reg(7 downto 0);
        end if;
    end process rx_data_sel_mux;

    --------------------------------------------------------------------------------
    --  Parity bit generation logic
    --------------------------------------------------------------------------------
    s_rx_parity_gen(0) <= s_rx_reg(0);
    rx_parity_gen:for i in 1 to 8 generate                                  
        s_rx_parity_gen(i) <= s_rx_parity_gen(i - 1) xor s_rx_reg(i); 
    end generate;

    --------------------------------------------------------------------------------
    --  Multiplexer logic for choosing the number bits to be recieved
    --  If parity is enabled: 10 bits (8 data bits + 1 stop bit and 1 parity bit)
    --  Else: 9 bits (8 data bits + 1 stop bit)
    --------------------------------------------------------------------------------
    s_bits_per_frame <= to_unsigned(9, 4) when s_rx_parity_en_reg = '0' else       
                      to_unsigned(10, 4);

    --------------------------------------------------------------------------------
    -- Combinational process to check validity of recieved parity bit
    --------------------------------------------------------------------------------
    parity_check:process(s_rx_parity_en_reg, s_rx_parity_sel_reg, s_rx_parity_gen)  
    begin
        if s_rx_parity_en_reg = '1' and s_rx_parity_sel_reg = '0' then                -- If even parity is enabled.
            if s_rx_parity_gen(8) = '0' then 
                s_rx_parity_valid <= '1';
            else
                s_rx_parity_valid <= '0';
            end if;
        elsif s_rx_parity_en_reg = '1' and s_rx_parity_sel_reg = '1' then             -- If odd parity is enabled.
            if s_rx_parity_gen(8) = '1' then 
                s_rx_parity_valid <= '1';
            else
                s_rx_parity_valid <= '0';
            end if;
        else                                                                    -- If parity is disabled.
            s_rx_parity_valid <= '1';
        end if;
    end process parity_check;
    
    
    --------------------------------------------------------------------------------
    -- Process which implements the reciever state machine.
    --------------------------------------------------------------------------------
    rx_process:process(i_clk, i_rst)
    begin
        if i_rst = '1' then                                                       --  When the reset input is high clear all counters and shift registers.
            cState_rx <= idle;
            s_rx_clk_pulse_counter <= to_unsigned(0, 16);
            s_rx_clk_count_val_reg <= to_unsigned(0, 16);
            s_rx_bit_count <= to_unsigned(0, 4);
            s_rx_reg <= (others => '0');
            rx_SYNC_FF1 <= '1';
            rx_SYNC_FF2 <= '1';
            s_rx_parity_en_reg <= '0';
            s_rx_parity_sel_reg <= '0';
            s_rx_busy <= '0';
               
        elsif rising_edge(i_clk) then
            if s_rx_en = '1' then
                rx_SYNC_FF1 <= i_rx_in;
                rx_SYNC_FF2 <= rx_SYNC_FF1;
                case cState_rx is
                    when idle =>
                        --------------------------------------------------------------------------------
                        -- Change the control registers only when idle
                        --------------------------------------------------------------------------------
                        s_rx_clk_count_val_reg <= unsigned(s_count_val_mux);
                        s_rx_parity_en_reg <= s_parity_en;	 
                        s_rx_parity_sel_reg <= s_parity_sel;
                       
                        s_rx_busy <= '0';               	                --  Deassert the busy flag 
                        
                        if s_rx_parity_err = '1' or s_rx_frame_err = '1' then
                            if i_intr_ack = '1' then
                                s_rx_parity_err <= '0';                         --  Deassert the parity error flag while beginning to recieve data
                                s_rx_frame_err <= '0';                          --  Deassert the frame error flag while beginning to recieve data
                            end if;
                        end if;
                        
                        if rx_SYNC_FF2 = '0' and s_rx_clk_pulse_counter < s_rx_clk_count_val_reg / 2 then     -- Wait for half the baud period  
                            s_rx_clk_pulse_counter <= s_rx_clk_pulse_counter + 1;
                            cState_rx <= idle;
                        elsif rx_SYNC_FF2 = '0' and s_rx_clk_pulse_counter = s_rx_clk_count_val_reg / 2 then  -- After half a baud period if the input is still '0' start recieving the bits
                            cState_rx <= recieve_bits;
                            s_rx_clk_pulse_counter <= to_unsigned(0, 16);   
                        else                                                --  Else clear the clock pulse counter and stay in idle state.
                            cState_rx <= idle;
                            s_rx_clk_pulse_counter <= to_unsigned(0, 16);
                        end if;   
                            
                    when recieve_bits =>    
                        s_rx_busy <= '1';                                   --  Assert the busy flag
                        if s_rx_bit_count < s_bits_per_frame and s_rx_clk_pulse_counter < s_rx_clk_count_val_reg then	-- Wait for a baud period before sampling the serial input
                            s_rx_clk_pulse_counter <= s_rx_clk_pulse_counter + 1;
                        
                        elsif s_rx_bit_count < s_bits_per_frame then        --  If less that 10 bits (if parity) or 9 bits (if parity is not enabled) have been recieved, sample the input
                            s_rx_reg <= rx_SYNC_FF2 & s_rx_reg(9 downto 1);
                            s_rx_bit_count <= s_rx_bit_count + 1;
                            s_rx_clk_pulse_counter <= to_unsigned(0, 16);
                            cState_rx <= recieve_bits;
                        else                                                --  If all the bits have been recieved check framing and parity and go to idle state   
                            if s_rx_parity_en_reg = '0' then                --  If parity is not enabled, ignore parity error
                                s_rx_parity_err <= '0';
                            else                                            --  If parity is enabled, assert parity error if parity is incorrect
                                if s_rx_parity_valid = '1' then
                                    s_rx_parity_err <= '0';
                                else
                                    s_rx_parity_err <= '1';
                                end if;
                            end if;
                            
                            if s_rx_reg(9) = '1' then                       --  If stop bit is not recieved raise framing error
                                s_rx_frame_err <= '0';
                            else
                                s_rx_frame_err <= '1';
                            end if;
                            
                            cState_rx <= idle;
                            s_rx_bit_count <= to_unsigned(0, 4);
                        end if;
                                        
                    when others =>                                          --  Default case
                        s_rx_busy <= '0';
                        cState_rx <= idle;
                        s_rx_clk_pulse_counter <= to_unsigned(0, 16);
                        s_rx_bit_count <= to_unsigned(0, 4);
                        s_rx_reg <= (others => '0');
                end case;
            end if;
        end if;
    end process rx_process;



    --------------------------------------------------------------------------------
    -- FIFO Buffer for transmitter
    --------------------------------------------------------------------------------
    fifo_tx_inst : entity work.fifo_buffer
    generic map (
      DATA_WIDTH => 8,
      ADDR_WIDTH => 3
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_wr_en => s_tx_wr_en,
      i_wr_data => s_tx_wr_data,
      i_rd_en => s_tx_rd_en,
      o_rd_data => s_tx_rd_data,
      o_empty => s_tx_empty,
      o_full => s_tx_full
    );
    
    s_tx_wr_data <= i_write_data(7 downto 0);

    --------------------------------------------------------------------------------
    --  Process to assert read enable of transmit FIFO buffer 
    --  Only asserted when trasnmitter is ready to transmit and interrupt is 
    --  deasserted.
    --------------------------------------------------------------------------------
    tx_fifo_rd_proc: process(s_tx_busy, s_tx_empty, intr_cState)
    begin
        if s_tx_busy = '0' and s_tx_empty = '0' and intr_cState = intr_deassert then
            s_tx_rd_en <= '1';
        else
             s_tx_rd_en <= '0';
        end if;
    end process tx_fifo_rd_proc;

    --------------------------------------------------------------------------------
    -- Process to write to the transmit buffer    
    --------------------------------------------------------------------------------
    tx_buffer_proc: process(s_tx_full, i_write_en, i_write_addr)
    begin
        if i_write_addr = "10" and i_write_en = '1' then
            s_tx_wr_en <= '1';
        else
            s_tx_wr_en <= '0';
        end if;
    end process tx_buffer_proc;

    --------------------------------------------------------------------------------
    --  Process to start the transmission of data
    --  Transmission start when the transmit buffer is not empty and the transmitter
    --  is not busy.
    --------------------------------------------------------------------------------
    start_tx_proc: process(s_tx_empty, s_tx_busy, intr_cState)
    begin
        if s_tx_empty = '0' and s_tx_busy = '0' and intr_cState = intr_deassert then
            s_tx_start <= '1';
        else
            s_tx_start <= '0';
        end if; 
    end process start_tx_proc;

    --------------------------------------------------------------------------------
    -- UART TRANSMITTER MODULE                                                                                                                              
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --  Parity bit generation logic
    --------------------------------------------------------------------------------
    s_tx_parity_gen(0) <= s_tx_data_reg(0);
    tx_parity_gen:for i in 1 to 7 generate                                  
        s_tx_parity_gen(i) <= s_tx_parity_gen(i - 1) xor s_tx_data_reg(i); 
    end generate;

    parity_gen:process(s_tx_parity_en_reg, s_tx_parity_sel_reg, s_tx_parity_gen)
    begin
        if s_tx_parity_en_reg = '1' and s_tx_parity_sel_reg = '0' then             -- If even parity is enabled.
            if s_tx_parity_gen(7) = '1' then
                s_tx_parity_bit <= '1';
            else
                s_tx_parity_bit <= '0';
            end if;
        elsif s_tx_parity_en_reg = '1' and s_tx_parity_sel_reg = '1' then          -- If odd parity is enabled.
            if s_tx_parity_gen(7) = '0' then
                s_tx_parity_bit <= '1';
            else
                s_tx_parity_bit <= '0';
            end if;
		  else
				s_tx_parity_bit <= '0';
        end if;
    end process parity_gen;	

    
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Process which implements the transmission state machine.
    ---------------------------------------------------------------------------------------------------------------------------------------------------------
    tx_process:process(i_clk, i_rst)
    begin
        if i_rst = '1' then                                         -- When the reset input is high clear all counters and shift registers  
            cState_tx <= idle;
            s_tx_clk_pulse_counter <= to_unsigned(0, 16);
            s_tx_data_reg <= (others => '0');
            s_tx_clk_count_val_reg <= to_unsigned(0, 16);
            s_tx_bit_count <= to_unsigned(0, 3);
            s_tx_parity_en_reg <= '0';
            s_tx_parity_sel_reg <= '0';
            o_tx_out <= '1';
            s_tx_busy <= '0';

        elsif rising_edge(i_clk) then                          
            if s_tx_en = '1' then
                case cState_tx is 
                    when idle =>
                        --------------------------------------------------------------------------------
                        --  Update control and internal data registers when transmitter is idle
                        --------------------------------------------------------------------------------
                        s_tx_clk_count_val_reg <= unsigned(s_count_val_mux);
                        s_tx_parity_en_reg <= s_parity_en;       
                        s_tx_parity_sel_reg <= s_parity_sel;  

                        o_tx_out <= '1';                            --  When idle, hold serial output high.  

                        --------------------------------------------------------------------------------
                        --  Start transmission of bits if the start_tx signal is active 
                        --------------------------------------------------------------------------------
                        if s_tx_start = '1' then 
                            s_tx_data_reg <= s_tx_rd_data;
                            cState_tx <= transmit_start_bit;
                            s_tx_busy <= '1';
                        else
                            cState_tx <= idle;
                            s_tx_busy <= '0';
                        end if;
                    
                    --------------------------------------------------------------------------------
                    --  Hold the serial output low for 1 baud period to signal start bit
                    --------------------------------------------------------------------------------
                    when transmit_start_bit =>
                        o_tx_out <= '0';                     
                        if s_tx_clk_pulse_counter < s_tx_clk_count_val_reg then
                            s_tx_clk_pulse_counter <= s_tx_clk_pulse_counter + 1;
                        else
                            cState_tx <= transmit_data_bits;    
                            s_tx_clk_pulse_counter <= to_unsigned(0, 16);

                        end if;
                    
                    --------------------------------------------------------------------------------
                    --  Start transmission of data bits after signalling the start bit
                    --------------------------------------------------------------------------------
                    when transmit_data_bits =>
                        o_tx_out <= s_tx_data_reg(to_integer(s_tx_bit_count));
                        if s_tx_clk_pulse_counter < s_tx_clk_count_val_reg then                 
                            s_tx_clk_pulse_counter <= s_tx_clk_pulse_counter + 1;   --  Hold the data bit on serial output for 1 baud period
                        
                        elsif s_tx_bit_count < 7 then                             --  If all 8 bits are not transmitted remain in same state
                            cState_tx <= transmit_data_bits;
                            s_tx_clk_pulse_counter <= to_unsigned(0, 16);
                            s_tx_bit_count <= s_tx_bit_count + 1;
                        
                        else
                            --------------------------------------------------------------------------------
                            --  If parity is enabled start transmission of parity bit                                    
                            --------------------------------------------------------------------------------
                            if s_tx_parity_en_reg = '1' then         
                                cState_tx <= transmit_parity_bit;
                                s_tx_clk_pulse_counter <= to_unsigned(0, 16);
                                s_tx_bit_count <= to_unsigned(0, 3);
                            --------------------------------------------------------------------------------
                            --  Else start transmission of stop bit
                            --------------------------------------------------------------------------------
                            else
                                cState_tx <= transmit_stop_bit; -- Else transmit stop bit
                                s_tx_clk_pulse_counter <= to_unsigned(0, 16);
                                s_tx_bit_count <= to_unsigned(0, 3);
                            end if;
                        end if;
                    
                    --------------------------------------------------------------------------------
                    --  If parity is enabled, transmit parity bit
                    --------------------------------------------------------------------------------
                    when transmit_parity_bit =>
                        o_tx_out <= s_tx_parity_bit;                                --  Parity bit generated using parity logic
                        if s_tx_clk_pulse_counter < s_tx_clk_count_val_reg then
                            s_tx_clk_pulse_counter <= s_tx_clk_pulse_counter + 1;   --  Hold the parity bit on serial output for 1 baud period
                        else
                            cState_tx <= transmit_stop_bit;                         --  Start transmission of stop bit
                            s_tx_clk_pulse_counter <= to_unsigned(0, 16);
                        end if;
                    
                    --------------------------------------------------------------------------------
                    --  Hold the serial output high for 1 baud period to signal stop bit
                    --------------------------------------------------------------------------------
                    when transmit_stop_bit => 
                        o_tx_out <= '1';                                         
                        if s_tx_clk_pulse_counter < s_tx_clk_count_val_reg then
                            s_tx_clk_pulse_counter <= s_tx_clk_pulse_counter + 1;
                        else
                            cState_tx <= idle;
                            s_tx_busy <= '0';
                            s_tx_clk_pulse_counter <= to_unsigned(0, 16);
                        end if;
                        
                    when others =>                                                  --  Default case
                        s_tx_clk_pulse_counter <= to_unsigned(0, 16);
                        s_tx_bit_count <= to_unsigned(0, 3);
                        s_tx_busy <= '0';
                        cState_tx <= idle;
                end case;
            else
                o_tx_out <= '1';
            end if;
        end if;
    end process tx_process;
end UART_beh;

