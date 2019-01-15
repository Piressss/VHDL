---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 27/12/2018
-- @Lib   : AXIS LIB
-- @Code  : AXIS_REGISTER
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
---------------------------------------------------------------------
entity axi_stream_register is
    generic(
        tdata_size_g        : integer := 1;
        tuser_size_g        : integer := 1
    );
    port(
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
        --
        s_axis_tvalid_i     : in  std_logic;
        s_axis_tready_o     : out std_logic;
        s_axis_tlast_i      : in  std_logic;
        s_axis_tdata_i      : in  std_logic_vector(tdata_size_g-1 downto 0);
        s_axis_tuser_i      : in  std_logic_vector(tuser_size_g-1 downto 0);
        --
        m_axis_tvalid_o     : out std_logic;
        m_axis_tready_i     : in  std_logic;
        m_axis_tlast_o      : out std_logic;
        m_axis_tdata_o      : out std_logic_vector(tdata_size_g-1 downto 0);
        m_axis_tuser_o      : out std_logic_vector(tuser_size_g-1 downto 0)
    );
end axi_stream_register;

architecture rtl of axi_stream_register is

    signal tvalid_s         : std_logic := '0';
    signal tready_s         : std_logic := '0';
    signal tlast_s          : std_logic := '0';
    signal tdata_s          : std_logic_vector(tdata_size_g-1 downto 0) := (others => '0');
    signal tuser_s          : std_logic_vector(tuser_size_g-1 downto 0) := (others => '0');

begin

    -----------------------------------------------------------------
    -- Register all signals
    -----------------------------------------------------------------
    register_signals_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if rst_i = '1' then
                tvalid_s <= '0';
                tlast_s  <= '0';
                tdata_s  <= (others => '0');
                tuser_s  <= (others => '0');
            elsif tready_s = '1' then
                tvalid_s <= s_axis_tvalid_i;
                tlast_s  <= s_axis_tlast_i;
                tdata_s  <= s_axis_tdata_i;
                tuser_s  <= s_axis_tuser_i;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Ctrl the TREADY based on the Master Port 
    -----------------------------------------------------------------
    tready_s <= '0' when tvalid_s = '1' and m_axis_tready_i = '0' else '1';

    s_axis_tready_o <= tready_s;
    
    -----------------------------------------------------------------
    -- Connect all register signals to the Master Port 
    -----------------------------------------------------------------
    m_axis_tvalid_o <= tvalid_s;
    m_axis_tlast_o  <= tlast_s;
    m_axis_tdata_o  <= tdata_s;
    m_axis_tuser_o  <= tuser_s;

end rtl;

