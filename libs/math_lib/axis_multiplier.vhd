---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 17/01/2019
-- @Lib   : AXIS LIB
-- @Code  : AXIS_MULTIPLIER
-- @brief : Multiplies two data input signals.
--          If an overflow happen data will lost and the overlow will be signaling.
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--
library axis_lib;
---------------------------------------------------------------------
entity axis_multiplier is
    generic(
        data_width_g        : integer := 1
    );
    port(
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
        --
        s_axis_tvalid_i     : in  std_logic;
        s_axis_tready_o     : out std_logic;
        s_axis_tlast_i      : in  std_logic;
        s_axis_tdata_i      : in  std_logic_vector(data_width_g-1 downto 0); -- Data to be multiplied
        s_axis_tuser_i      : in  std_logic_vector(data_width_g-1 downto 0); -- Multiplier
        --
        m_axis_tvalid_o     : out std_logic;
        m_axis_tready_i     : in  std_logic;
        m_axis_tlast_o      : out std_logic;
        m_axis_tdata_o      : out std_logic_vector(data_width_g-1 downto 0);
        overflow_o          : out std_logic
    );
end axis_multiplier;

architecture rtl of axis_multiplier is

    type tdata_t is array (natural range<>) of std_logic_vector(data_width_g-1 downto 0);

    signal tvalid_s         : std_logic_vector(2 downto 0) := (others => '0');
    signal tready_s         : std_logic_vector(2 downto 0) := (others => '0');
    signal tlast_s          : std_logic_vector(2 downto 0) := (others => '0');
    signal tdata_s          : tdata_t(2 downto 0) := (others => (others => '0'));
    signal tuser_s          : tdata_t(2 downto 0) := (others => (others => '0'));
    signal tdata_sum_en     : std_logic := '0';
    signal tdata_sum_s      : tdata_t(data_width_g-1 downto 0) := (others => (others => '0'));

begin

    -----------------------------------------------------------------
    -- Register input 
    -----------------------------------------------------------------
    input_register_u: entity axis_lib.axi_stream_register
        generic map(
            tdata_size_g        => data_width_g,
            tuser_size_g        => data_width_g
        )
        port map(
            clk_i               => clk_i,
            rst_i               => rst_i,
            --
            s_axis_tvalid_i     => s_axis_tvalid_i,
            s_axis_tready_o     => s_axis_tready_o,
            s_axis_tlast_i      => s_axis_tlast_i,
            s_axis_tdata_i      => s_axis_tdata_i,
            s_axis_tuser_i      => s_axis_tuser_i,
            --
            m_axis_tvalid_o     => tvalid_s(0),
            m_axis_tready_i     => tready_s(0),
            m_axis_tlast_o      => tlast_s(0),
            m_axis_tdata_o      => tdata_s(0),
            m_axis_tuser_o      => tuser_s(0)
        );

    -----------------------------------------------------------------
    -- Baseado nos bits do tdata vou gerar os dados que serao somados 
    -----------------------------------------------------------------
    tdata_sum_gen: for i in data_width_g-1 downto 0 generate
        tdata_sum_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if rst_i = '1' then
                    tdata_sum_s(i) <= (others => '0');
                elsif tvalid_s(0) = '1' and tready_s(0) = '1' then
                    if tdata_s(0)(i) = '1' then
                        tdata_sum_s(i) <= tuser_s(0) sll i;
                    else
                        tdata_sum_s(i) <= (others => '0');
                    end if;
                end if;
            end if;
        end process;
    end generate;
    
    tdata_sum_en_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if tvalid_s(0) = '1' and tready_s(0) = '1' then
                tdata_sum_en <= '1';
            elsif tvalid_s(1) = '1' and tready_s(1) = '1' then
                tdata_sum_en <= '0';
            end if;
        end if;
    end process;

    tready_s(0) <= '1' when tdata_sum_en = '0' else
                   '1' when tdata_sum_en = '1' and tready_s(1) = '1' else
                   '0';

    tvalid_s(1) <= tvalid_s(0);
    tlast_s(1)  <= tlast_s(0);

    -----------------------------------------------------------------
    -- Register Tdata_sum 
    -----------------------------------------------------------------
    --tdata_sum_register_u: entity axis_lib.axi_stream_register
    --    generic map(
    --        tdata_size_g        => data_width_g,
    --        tuser_size_g        => 0
    --    )
    --    port map(
    --        clk_i               => clk_i,
    --        rst_i               => rst_i,
    --        --
    --        s_axis_tvalid_i     => tvalid_s(1),
    --        s_axis_tready_o     => tready_s(1),
    --        s_axis_tlast_i      => tlast_s(1),
    --        s_axis_tdata_i      => tdata_sum_s,
    --        --
    --        m_axis_tvalid_o     => tvalid_s(2),
    --        m_axis_tready_i     => tready_s(2),
    --        m_axis_tlast_o      => tlast_s(2),
    --        m_axis_tdata_o      => tdata_s(2)
    --    );

                

end rtl;
        
