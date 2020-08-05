---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 05/08/2020
-- @Lib   : AXIS LIB
-- @Code  : AXIS_CONCATENATE
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--
library axis_lib;
---------------------------------------------------------------------
entity axis_concatenate is
    generic(
        tdata_a_width_g     : integer := 1;
        tdata_b_width_g     : integer := 1;
        tuser_a_width_g     : integer := 1;
        tuser_b_width_g     : integer := 1;
        tid_a_width_g       : integer := 1;
        tid_b_width_g       : integer := 1
    );
    port(
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
        -- PORT A (LSB RESULT)
        s_axis_tvalid_a_i   : in  std_logic;
        s_axis_tready_a_o   : out std_logic;
        s_axis_tlast_a_i    : in  std_logic;
        s_axis_tdata_a_i    : in  std_logic_vector(tdata_a_width_g-1 downto 0);
        s_axis_tuser_a_i    : in  std_logic_vector(tuser_a_width_g-1 downto 0) := (others => '0');
        s_axis_tid_a_i      : in  std_logic_vector(tid_a_width_g-1 downto 0) := (others => '0');
        -- PORT B (LSB RESULT)
        s_axis_tvalid_b_i   : in  std_logic;
        s_axis_tready_b_o   : out std_logic;
        s_axis_tlast_b_i    : in  std_logic;
        s_axis_tdata_b_i    : in  std_logic_vector(tdata_b_width_g-1 downto 0);
        s_axis_tuser_b_i    : in  std_logic_vector(tuser_b_width_g-1 downto 0) := (others => '0');
        s_axis_tid_b_i      : in  std_logic_vector(tid_b_width_g-1 downto 0) := (others => '0');
        -- Result
        m_axis_tvalid_o     : out std_logic;
        m_axis_tready_i     : in  std_logic;
        m_axis_tlast_o      : out std_logic;
        m_axis_tdata_o      : out std_logic_vector(tdata_a_width_g+tdata_b_width_g-1 downto 0);
        m_axis_tuser_o      : out std_logic_vector(tuser_a_width_g+tuser_b_width_g-1 downto 0);
        m_axis_tid_o        : out std_logic_vector(tid_a_width_g+tid_b_width_g-1 downto 0);
        -- Error
        tlast_error_o       : out std_logic     -- Indicates when the Frame A and Frame B have diferent size, in this case will be propagate the Tlast_A
    );
end axis_concatenate;

architecture rtl of axis_concatenate is

    signal tvalid_a_s       : std_logic := '0';
    signal tready_a_s       : std_logic := '0';
    signal tlast_a_s        : std_logic := '0';
    signal tdata_a_s        : std_logic_vector(s_axis_tdata_a_i'length-1 downto 0) := (others => '0');
    signal tuser_a_s        : std_logic_vector(s_axis_tuser_a_i'length-1 downto 0) := (others => '0');
    signal tid_a_s          : std_logic_vector(s_axis_tid_a_i'length-1 downto 0) := (others => '0');
    signal tvalid_b_s       : std_logic := '0';
    signal tready_b_s       : std_logic := '0';
    signal tlast_b_s        : std_logic := '0';
    signal tdata_b_s        : std_logic_vector(s_axis_tdata_b_i'length-1 downto 0) := (others => '0');
    signal tuser_b_s        : std_logic_vector(s_axis_tuser_b_i'length-1 downto 0) := (others => '0');
    signal tid_b_s          : std_logic_vector(s_axis_tid_b_i'length-1 downto 0) := (others => '0');
    signal tvalid_c_s       : std_logic := '0';
    signal tready_c_s       : std_logic := '0';
    signal tlast_c_s        : std_logic := '0';
    signal tdata_c_s        : std_logic_vector(s_axis_tdata_a_i'length+s_axis_tdata_b_i'length-1 downto 0) := (others => '0');
    signal tuser_c_s        : std_logic_vector(s_axis_tuser_a_i'length+s_axis_tuser_b_i'length-1 downto 0) := (others => '0');
    signal tid_c_s          : std_logic_vector(s_axis_tid_a_i'length+s_axis_tid_b_i'length-1 downto 0) := (others => '0');

begin

    -----------------------------------------------------------------
    -- Input Register
    -----------------------------------------------------------------
    input_register_a_u: entity axis_lib.axi_stream_register
        generic map(
            tdata_size_g            => tdata_a_width_g,
            tuser_size_g            => tuser_a_width_g,
            tid_size_g              => tid_a_width_g
        )
        port map(
            clk_i                   => clk_i,
            rst_i                   => rst_i,
            --
            s_axis_tvalid_i         => s_axis_tvalid_a_i,
            s_axis_tready_o         => s_axis_tready_a_o,
            s_axis_tlast_i          => s_axis_tlast_a_i,
            s_axis_tdata_i          => s_axis_tdata_a_i,
            s_axis_tuser_i          => s_axis_tuser_a_i,
            s_axis_tid_i            => s_axis_tid_a_i,
            --
            m_axis_tvalid_o         => tvalid_a_s,
            m_axis_tready_i         => tready_a_s,
            m_axis_tlast_o          => tlast_a_s,
            m_axis_tdata_o          => tdata_a_s,
            m_axis_tuser_o          => tuser_a_s,
            m_axis_tid_o            => tid_a_s
        );
    
    input_register_b_u: entity axis_lib.axi_stream_register
        generic map(
            tdata_size_g            => tdata_b_width_g,
            tuser_size_g            => tuser_b_width_g,
            tid_size_g              => tid_b_width_g
        )
        port map(
            clk_i                   => clk_i,
            rst_i                   => rst_i,
            --
            s_axis_tvalid_i         => s_axis_tvalid_b_i,
            s_axis_tready_o         => s_axis_tready_b_o,
            s_axis_tlast_i          => s_axis_tlast_b_i,
            s_axis_tdata_i          => s_axis_tdata_b_i,
            s_axis_tuser_i          => s_axis_tuser_b_i,
            s_axis_tid_i            => s_axis_tid_b_i,
            --
            m_axis_tvalid_o         => tvalid_b_s,
            m_axis_tready_i         => tready_b_s,
            m_axis_tlast_o          => tlast_b_s,
            m_axis_tdata_o          => tdata_b_s,
            m_axis_tuser_o          => tuser_b_s,
            m_axis_tid_o            => tid_b_s
        );

    -----------------------------------------------------------------
    -- Concatenate
    -----------------------------------------------------------------
    tvalid_c_s <= tvalid_b_s and tvalid_a_s;
    tlast_c_s  <= tlast_a_s;
    tdata_c_s  <= tdata_b_s & tdata_a_s;
    tuser_c_s  <= tuser_b_s & tuser_a_s;
    tid_c_s    <= tid_b_s & tid_a_s;

    tready_a_s <= tready_c_s when tvalid_b_s = '1' and tvalid_a_s = '1' else '0';
    tready_b_s <= tready_c_s when tvalid_b_s = '1' and tvalid_a_s = '1' else '0';

    tlast_error_o <= '1' when tlast_a_s /= tlast_b_s else '0';
    
    -----------------------------------------------------------------
    -- Output Register
    -----------------------------------------------------------------
    output_register_u: entity axis_lib.axi_stream_register
        generic map(
            tdata_size_g            => tdata_a_width_g+tdata_b_width_g,
            tuser_size_g            => tuser_a_width_g+tuser_b_width_g,
            tid_size_g              => tid_a_width_g+tid_b_width_g
        )
        port map(
            clk_i                   => clk_i,
            rst_i                   => rst_i,
            --
            s_axis_tvalid_i         => tvalid_c_s,
            s_axis_tready_o         => tready_c_s,
            s_axis_tlast_i          => tlast_c_s,
            s_axis_tdata_i          => tdata_c_s,
            s_axis_tuser_i          => tuser_c_s,
            s_axis_tid_i            => tid_c_s,
            --
            m_axis_tvalid_o         => m_axis_tvalid_o,
            m_axis_tready_i         => m_axis_tready_i,
            m_axis_tlast_o          => m_axis_tlast_o,
            m_axis_tdata_o          => m_axis_tdata_o,
            m_axis_tuser_o          => m_axis_tuser_o,
            m_axis_tid_o            => m_axis_tid_o
        );

end rtl;
