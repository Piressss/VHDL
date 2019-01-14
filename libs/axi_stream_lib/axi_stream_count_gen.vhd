---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 27/12/2018
-- @Lib   : AXIS LIB
-- @Code  : AXIS_COUNT_GEN
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
---------------------------------------------------------------------
entity axi_stream_count_gen is
    generic(
        counter_bits_g      : integer := 1;
        infinity_loop_g     : boolean := true
    );
    port(
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
        --
        m_axis_tvalid_o     : out std_logic;
        m_axis_tready_i     : in  std_logic;
        m_axis_tlast_o      : out std_logic;
        m_axis_tdata_o      : out std_logic_vector(counter_bits_g-1 downto 0)
    );
end axi_stream_count_gen;

architecture rtl of axi_stream_count_gen is

    constant max_count_c     : integer := 2**counter_bits_g;

    signal count_gen         : unsigned(counter_bits_g-1 downto 0) := (others => '0');
    signal tlast_s           : std_logic := '0';

begin

    -----------------------------------------------------------------
    -- Counter Generator
    -----------------------------------------------------------------
    count_gen_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if rst_i = '1' then
                count_gen <= (others => '0');
            elsif m_axis_tready_i = '1' then
                count_gen <= count_gen + 1;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------
    -- Tlast Generator
    -----------------------------------------------------------------
    tlast_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if rst_i = '1' then
                tlast_s <= '0';
            elsif m_axis_tready_i = '1' then
                if count_gen = max_count_c - 2 then
                    tlast_s <= '1';
                else
                    tlast_s <= '0';
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Tvalid Gen 
    -----------------------------------------------------------------
    tvalid_infinity_gen: if infinity_loop_g = true generate
        m_axis_tvalid_o <= '1';
    end generate;

    tvalid_gen: if infinity_loop_g = false generate
        tvalid_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if rst_i = '1' then
                    m_axis_tvalid_o <= '1';
                elsif m_axis_tready_i = '1' and tlast_s = '1' then
                    m_axis_tvalid_o <= '0';
                end if;
            end if;
        end process;
    end generate;

    -----------------------------------------------------------------
    -- AXIS connection 
    -----------------------------------------------------------------
    m_axis_tlast_o  <= tlast_s;
    m_axis_tdata_o  <= std_logic_vector(count_gen);

end rtl;

