------------------------------------------------------------------------------------------
-- Created by : Anirudh Srinivasan
-- 
-- Design Name: UART Module
-- Component Name: UART_rx
-- Target Device: Spartan 6
-- Description:
--    This module consists of the state machine to recieve and store the incoming bits
------------------------------------------------------------------------------------------
            
            
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_rx is
    port    (   i_clk : std_logic;                       --   Input clock signal
                i_rx_en : in std_logic;                  --   Input to enable/disable reciever (Active High)
                rst : in std_logic;                      --   Input to reset the module
                i_rx_serial : in std_logic;              --   Serial input from the external transmitter
                i_parity_en : in std_logic;              --   Input to enable the parity
                i_parity_sel : in std_logic;             --   Input to select type of parity to be used (0 - Even, 1 - Odd)
                i_rom_count_val : in std_logic_vector(15 downto 0); --  Input number of clock pulse for 1 baud period
                o_rx_busy : out std_logic;               --   Output current state of the reciever module (Busy/Idle)
                o_rx_invalid : out std_logic;            --   Output the validity of recieved data
                o_rx_data : out std_logic_vector(7 downto 0));      --  8-Bit output of recieved bits
end UART_rx;

architecture rx_beh of UART_rx is
    type rx_states is (idle, recieve_bits);                 --  The state machine requires only two state : One for when it is idle and one for when it is recieving bits
    signal cState_rx : rx_states := idle;                   --  Current state of state machine
    signal s_rx_parity_valid : std_logic := '0';            --  Internal signal which denotes the validity of the input bits based on parity      
    signal s_bit_count, bits_per_frame : unsigned(3 downto 0) := (others => '0');   --  Counters to count the number of bits recieved 
    signal s_rx_reg : std_logic_vector(9 downto 0) := (others => '0');              --  Shift register used to storing each of the recieved bit (Stores 8 data bits and 1 stop bit and 1 parity bit if enabled)
    signal rx_SYNC_FF1, rx_SYNC_FF2 : std_logic := '1';     --  Flip-Flops to synchronize the asynchronous rx_in with the i_clk clock signal
    
    signal s_rx_parity_gen : std_logic_vector(8 downto 0);  --  Internal parity generation logic  
    signal s_parity_en_reg, s_parity_sel_reg : std_logic := '0'; --  Internal registers to hold the control signal for parity_en and parity_sel during recieving
    
    signal s_clk_pulse_counter : unsigned(15 downto 0);     --  16-Bit counter for counting the input clock pulse
    signal s_clk_count_val_reg : unsigned(15 downto 0);     --  16-Bit register which holds the value for number clock pulses required for 1 bit

    signal s_rx_frame_err : std_logic := '0';               --  Internal signal for denoting a framing error in the recieved bits
    signal s_rx_parity_err : std_logic := '0';              --  Internal signal for denoting a parity error in the recieved bits
    
begin  
    o_rx_invalid <= s_rx_frame_err or s_rx_parity_err;      --  Assert the output invalid flag if either framing error or parity error occurs
    
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
    bits_per_frame <= to_unsigned(9, 4) when s_parity_en_reg = '0' else       
                      to_unsigned(10, 4);

    --------------------------------------------------------------------------------
    -- Combinational process to check validity of recieved parity bit
    --------------------------------------------------------------------------------
    parity_check:process(s_parity_en_reg, s_parity_sel_reg, s_rx_parity_gen)  
    begin
        if s_parity_en_reg = '1' and s_parity_sel_reg = '0' then                -- If even parity is enabled.
            if s_rx_parity_gen(8) = '0' then 
                s_rx_parity_valid <= '1';
            else
                s_rx_parity_valid <= '0';
            end if;
        elsif s_parity_en_reg = '1' and s_parity_sel_reg = '1' then             -- If odd parity is enabled.
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
    rx_process:process(i_clk, rst)
    begin
        if rst = '1' then                                                       --  When the reset input is high clear all counters and shift registers.
            cState_rx <= idle;
            s_clk_pulse_counter <= to_unsigned(0, 16);
            s_clk_count_val_reg <= to_unsigned(0, 16);
            s_bit_count <= to_unsigned(0, 4);
            s_rx_reg <= (others => '0');
            rx_SYNC_FF1 <= '1';
            rx_SYNC_FF2 <= '1';
            s_parity_en_reg <= '0';
            s_parity_sel_reg <= '0';
            o_rx_busy <= '0';
            o_rx_data <= (others => '0');
                
        elsif rising_edge(i_clk) then
            if i_rx_en = '1' then
                rx_SYNC_FF1 <= i_rx_serial;
                rx_SYNC_FF2 <= rx_SYNC_FF1;
                case cState_rx is
                    when idle =>
                        s_clk_count_val_reg <= unsigned(i_rom_count_val);
                        --------------------------------------------------------------------------------
                        -- Change the control registers only when idle
                        --------------------------------------------------------------------------------
                        s_rx_parity_err <= s_rx_parity_err;                     
                        s_rx_frame_err <= s_rx_frame_err;
                        s_parity_en_reg <= i_parity_en;	 
                        s_parity_sel_reg <= i_parity_sel;
                       
                        o_rx_busy <= '0';               	                --  Deassert the busy flag 
                        if rx_SYNC_FF2 = '0' and s_clk_pulse_counter < s_clk_count_val_reg / 2 then     -- Wait for half the baud period  
                            s_clk_pulse_counter <= s_clk_pulse_counter + 1;
                            cState_rx <= idle;
                        elsif rx_SYNC_FF2 = '0' and s_clk_pulse_counter = s_clk_count_val_reg / 2 then  -- After half a baud period if the input is still '0' start recieving the bits
                            cState_rx <= recieve_bits;
                            s_clk_pulse_counter <= to_unsigned(0, 16);
                            s_rx_parity_err <= '0';                         --  Deassert the parity error flag while beginning to recieve data
                            s_rx_frame_err <= '0';                          --  Deassert the frame error flag while beginning to recieve data

                        else                                                --  Else clear the clock pulse counter and stay in idle state.
                            cState_rx <= idle;
                            s_clk_pulse_counter <= to_unsigned(0, 16);
                        end if;   
                            
                    when recieve_bits =>    
                        o_rx_busy <= '1';                                   --  Assert the busy flag
                        if s_bit_count < bits_per_frame and s_clk_pulse_counter < s_clk_count_val_reg then	-- Wait for a baud period before sampling the serial input
                            s_clk_pulse_counter <= s_clk_pulse_counter + 1;
                        
                        elsif s_bit_count < bits_per_frame then             --  If less that 10 bits (if parity) or 9 bits (if parity is not enabled) have been recieved, sample the input
                            s_rx_reg <= rx_SYNC_FF2 & s_rx_reg(9 downto 1);
                            s_bit_count <= s_bit_count + 1;
                            s_clk_pulse_counter <= to_unsigned(0, 16);
                            cState_rx <= recieve_bits;
                        else                                                --  If all the bits have been recieved check framing and parity and go to idle state   
                            if s_parity_en_reg = '0' then                   --  If parity is not enabled, ignore parity error
                                o_rx_data <= s_rx_reg(8 downto 1);
                                s_rx_parity_err <= '0';
                            else                                            --  If parity is enabled, raise parity error if parity is incorrect
                                o_rx_data <= s_rx_reg(7 downto 0);
                                if s_rx_parity_valid = '1' then
                                    s_rx_parity_err <= '0';
                                else
                                    s_rx_parity_err <= '1';
                                end if;
                            end if;
                            
                            if s_rx_reg(to_integer(bits_per_frame) - 1) = '1' then  --  If stop bit is not recieved raise framing error
                                s_rx_frame_err <= '0';
                            else
                                s_rx_frame_err <= '1';
                            end if;
                            
                            cState_rx <= idle;
                            s_bit_count <= to_unsigned(0, 4);
                        end if;
                                        
                    when others =>                                          --  Default case
                        o_rx_busy <= '0';
                        cState_rx <= idle;
                        s_clk_pulse_counter <= to_unsigned(0, 16);
                        s_bit_count <= to_unsigned(0, 4);
                        s_rx_reg <= (others => '0');
                end case;
            end if;
        end if;
     end process rx_process;
end rx_beh;
