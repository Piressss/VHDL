---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 04/08/2020
-- @Lib   : AXIS LIB
-- @Code  : AXIS_ACC
-- @brief : Accumulator with over range signal. The Tlast signal ends the
-- accumulation.
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--
library base_lib;
use base_lib.base_lib_pkg.all;
--
library axis_lib;
---------------------------------------------------------------------
entity axis_acc is
    generic(
        data_width_g        : integer := 8;
        data_signed_g       : boolean := false;
        result_per_sample_g : boolean := false  -- If TRUE every input sample will generate one output accumulated sample, if FALSE only after Tlast the result will be outputed
    );
    port(
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
        --
        s_axis_tvalid_i     : in  std_logic;
        s_axis_tready_o     : out std_logic;
        s_axis_tlast_i      : in  std_logic;
        s_axis_tdata_i      : in  std_logic_vector(data_width_g-1 downto 0);
        --
        m_axis_tvalid_o     : out std_logic;
        m_axis_tready_i     : in  std_logic;
        m_axis_tlast_o      : out std_logic;
        m_axis_tdata_o      : out std_logic_vector(data_width_g-1 downto 0);
        m_axis_tuser_o      : out std_logic_vector(0 downto 0)                  -- Identify the over range
    );
end axis_acc;
        
architecture rtl of axis_acc is

    type tdata_t is array (natural range<>) of std_logic_vector(data_width_g-1 downto 0);

    constant bus_vector_c   : integer := 2;

    signal tvalid_s         : std_logic_vector(bus_vector_c-1 downto 0) := (others => '0'); 
    signal tready_s         : std_logic_vector(bus_vector_c-1 downto 0) := (others => '0'); 
    signal tlast_s          : std_logic_vector(bus_vector_c-1 downto 0) := (others => '0'); 
    signal tdata_s          : tdata_t(bus_vector_c-1 downto 0) := (others => (others => '0'));
    signal tuser_s          : bit1vec_t(bus_vector_c-1 downto 0) := (others => (others => '0'));
    signal acc_uns_s        : unsigned(data_width_g-1 downto 0) := (others => '0');
    signal acc_sig_s        : signed(data_width_g-1 downto 0) := (others => '0');
    signal result_uns_s     : unsigned(data_width_g-1 downto 0) := (others => '0');
    signal result_sig_s     : signed(data_width_g-1 downto 0) := (others => '0');
    signal over_range_uns_s : std_logic := '0';
    signal over_range_sig_s : std_logic := '0';
    signal over_range_uns_reg_s : std_logic := '0';
    signal over_range_sig_reg_s : std_logic := '0';

begin

    -----------------------------------------------------------------
    -- Register input 
    -----------------------------------------------------------------
    input_register_u: entity axis_lib.axi_stream_register
        generic map(
            tdata_size_g        => data_width_g
        )
        port map(
            clk_i               => clk_i,
            rst_i               => rst_i,
            --
            s_axis_tvalid_i     => s_axis_tvalid_i,
            s_axis_tready_o     => s_axis_tready_o,
            s_axis_tlast_i      => s_axis_tlast_i,
            s_axis_tdata_i      => s_axis_tdata_i,
            --
            m_axis_tvalid_o     => tvalid_s(0),
            m_axis_tready_i     => tready_s(0),
            m_axis_tlast_o      => tlast_s(0),
            m_axis_tdata_o      => tdata_s(0)
        );

    -----------------------------------------------------------------
    -- Acc
    -----------------------------------------------------------------
    acc_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                acc_uns_s <= (others => '0');
                acc_sig_s <= (others => '0');
            elsif tvalid_s(0) = '1' and tready_s(0) = '1' then
                if tlast_s(0) = '1' then
                    acc_uns_s <= (others => '0');
                    acc_sig_s <= (others => '0');
                else
                    if data_signed_g = false then
                        acc_uns_s <= acc_uns_s + unsigned(tdata_s(0));
                    else
                        acc_sig_s <= acc_sig_s + signed(tdata_s(0));
                    end if;
                end if;
            end if;
        end if;
    end process;

    over_range_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                over_range_uns_reg_s <= '0';
                over_range_sig_reg_s <= '0';
            elsif tvalid_s(0) = '1' and tready_s(0) = '1' then
                if tlast_s(0) = '1' then
                    over_range_uns_reg_s <= '0';
                    over_range_sig_reg_s <= '0';
                else
                    if over_range_uns_s = '1' then
                        over_range_uns_reg_s <= '1';
                    elsif over_range_sig_s = '1' then
                        over_range_sig_reg_s <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    over_range_uns_s <= '1' when (resize(acc_uns_s,acc_uns_s'length+1) + unsigned(tdata_s(0))) >= 2**acc_uns_s'length else '0';

    over_range_sig_s <= '1' when (resize(acc_sig_s, acc_sig_s'length+1) + resize(signed(tdata_s(0)),acc_sig_s'length+1)) >  (2**(acc_sig_s'length-1))-1 else
                        '1' when (resize(acc_sig_s, acc_sig_s'length+1) + resize(signed(tdata_s(0)),acc_sig_s'length+1)) < -(2**(acc_sig_s'length-1)) else 
                        '0';

    tvalid_s(1) <= tvalid_s(0) when result_per_sample_g = true else
                   tvalid_s(0) and tlast_s(0);

    tlast_s(1)  <= tlast_s(0);

    result_uns_s <= acc_uns_s + unsigned(tdata_s(0));
    result_sig_s <= acc_sig_s + signed(tdata_s(0));
    
    tdata_s(1)  <= std_logic_vector(result_uns_s) when data_signed_g = false else
                   std_logic_vector(result_sig_s);

    tready_s(0) <= tready_s(1) when result_per_sample_g = true else
                   '1' when result_per_sample_g = false and tlast_s(0) = '0' else
                   tready_s(1) when result_per_sample_g = false and tlast_s(0) = '1' else
                   '0';

    tuser_s(1)(0) <= (over_range_uns_s or over_range_uns_reg_s) when data_signed_g = false else
                     (over_range_sig_s or over_range_sig_reg_s);

    -----------------------------------------------------------------
    -- Register output 
    -----------------------------------------------------------------
    output_register_u: entity axis_lib.axi_stream_register
        generic map(
            tdata_size_g        => data_width_g,
            tuser_size_g        => 1
        )
        port map(
            clk_i               => clk_i,
            rst_i               => rst_i,
            --
            s_axis_tvalid_i     => tvalid_s(1), 
            s_axis_tready_o     => tready_s(1),
            s_axis_tlast_i      => tlast_s(1),
            s_axis_tdata_i      => tdata_s(1),
            s_axis_tuser_i      => tuser_s(1),
            --
            m_axis_tvalid_o     => m_axis_tvalid_o, 
            m_axis_tready_i     => m_axis_tready_i,
            m_axis_tlast_o      => m_axis_tlast_o,
            m_axis_tdata_o      => m_axis_tdata_o,
            m_axis_tuser_o      => m_axis_tuser_o
        );

end rtl;
