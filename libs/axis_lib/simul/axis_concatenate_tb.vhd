---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 05/08/2020
-- @Lib   : AXIS LIB
-- @Code  : AXIS_CONCATENATE
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
--
library base_lib;
use base_lib.base_lib_pkg.all;
--
library axis_lib;
--
library vunit_lib;
use vunit_lib.axi_stream_pkg.all;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.data_types_context;
---------------------------------------------------------------------
entity axis_concatenate_tb is
    generic(
        runner_cfg      : string
    );
end axis_concatenate_tb;

architecture tb of axis_concatenate_tb is

    constant tready_patt_c      : std_logic_vector(31 downto 0) := x"445F_EDA1";
    constant counter_bits_c     : integer := 4;
    constant tdata_a_width_c    : integer := counter_bits_c;
    constant tdata_b_width_c    : integer := counter_bits_c;
    constant logger                 : logger_t := get_logger("protocol_checker");
    constant protocol_checker       : axi_stream_protocol_checker_t := new_axi_stream_protocol_checker(data_length => tdata_a_width_c+tdata_b_width_c, logger => logger, actor =>
                                      new_actor("protocol_checker"), max_waits => 2048);


    type tdata_a_t is array (natural range<>) of std_logic_vector(tdata_a_width_c-1 downto 0);
    type tdata_b_t is array (natural range<>) of std_logic_vector(tdata_b_width_c-1 downto 0);

    constant tdata_gen_a_c      : tdata_a_t(15 downto 0) := (
                                    0 => std_logic_vector(to_unsigned(7 ,tdata_a_width_c)),
                                    1 => std_logic_vector(to_unsigned(27,tdata_a_width_c)),
                                    2 => std_logic_vector(to_unsigned(16,tdata_a_width_c)),
                                    3 => std_logic_vector(to_unsigned(9 ,tdata_a_width_c)),
                                    4 => std_logic_vector(to_unsigned(22,tdata_a_width_c)),
                                    5 => std_logic_vector(to_unsigned(31,tdata_a_width_c)),
                                    6 => std_logic_vector(to_unsigned(0 ,tdata_a_width_c)),
                                    7 => std_logic_vector(to_unsigned(9 ,tdata_a_width_c)),
                                    8 => std_logic_vector(to_unsigned(19,tdata_a_width_c)),
                                    9 => std_logic_vector(to_unsigned(11,tdata_a_width_c)),
                                   10 => std_logic_vector(to_unsigned(23,tdata_a_width_c)),
                                   11 => std_logic_vector(to_unsigned(7 ,tdata_a_width_c)),
                                   12 => std_logic_vector(to_unsigned(9 ,tdata_a_width_c)),
                                   13 => std_logic_vector(to_unsigned(11,tdata_a_width_c)),
                                   14 => std_logic_vector(to_unsigned(17,tdata_a_width_c)),
                                   15 => std_logic_vector(to_unsigned(30,tdata_a_width_c)));

    constant tdata_gen_b_c      : tdata_b_t(15 downto 0) := (
                                    0 => std_logic_vector(to_unsigned(1 ,tdata_b_width_c)),
                                    1 => std_logic_vector(to_unsigned(17,tdata_b_width_c)),
                                    2 => std_logic_vector(to_unsigned(17,tdata_b_width_c)),
                                    3 => std_logic_vector(to_unsigned(18,tdata_b_width_c)),
                                    4 => std_logic_vector(to_unsigned(12,tdata_b_width_c)),
                                    5 => std_logic_vector(to_unsigned( 1,tdata_b_width_c)),
                                    6 => std_logic_vector(to_unsigned( 0,tdata_b_width_c)),
                                    7 => std_logic_vector(to_unsigned(19,tdata_b_width_c)),
                                    8 => std_logic_vector(to_unsigned(22,tdata_b_width_c)),
                                    9 => std_logic_vector(to_unsigned(22,tdata_b_width_c)),
                                   10 => std_logic_vector(to_unsigned(19,tdata_b_width_c)),
                                   11 => std_logic_vector(to_unsigned(13,tdata_b_width_c)),
                                   12 => std_logic_vector(to_unsigned(12,tdata_b_width_c)),
                                   13 => std_logic_vector(to_unsigned(11,tdata_b_width_c)),
                                   14 => std_logic_vector(to_unsigned(28,tdata_b_width_c)),
                                   15 => std_logic_vector(to_unsigned(31,tdata_b_width_c)));


    signal clk_s                : std_logic := '1';
    signal rst_s                : std_logic := '1';
    signal tvalid_a_s           : std_logic := '0';
    signal tready_a_s           : std_logic := '0';
    signal tlast_a_s            : std_logic := '0';
    signal tdata_a_s            : std_logic_vector(tdata_a_width_c-1 downto 0) := (others => '0');
    signal tvalid_b_s           : std_logic := '0';
    signal tready_b_s           : std_logic := '0';
    signal tlast_b_s            : std_logic := '0';
    signal tdata_b_s            : std_logic_vector(tdata_b_width_c-1 downto 0) := (others => '0');
    signal tdata_gen_a_s        : std_logic_vector(tdata_a_width_c-1 downto 0) := (others => '0');
    signal tdata_gen_b_s        : std_logic_vector(tdata_b_width_c-1 downto 0) := (others => '0');
    signal tvalid_c_s           : std_logic := '0';
    signal tready_c_s           : std_logic := '0';
    signal tlast_c_s            : std_logic := '0';
    signal tdata_c_s            : std_logic_vector(tdata_a_width_c+tdata_b_width_c-1 downto 0) := (others => '0');
    signal tuser_c_s            : std_logic_vector(tdata_a_width_c+tdata_b_width_c-1 downto 0) := (others => '0');
    signal end_pckg_s           : std_logic := '0';

begin
    -----------------------------------------------------------------
    -- CLK/RST 
    -----------------------------------------------------------------
    clk_s <= not clk_s after 5 ns;
    
    rst_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            rst_s <= '0';
        end if;
    end process;

    -----------------------------------------------------------------
    -- Counter A
    -----------------------------------------------------------------
    counter_a_u: entity axis_lib.axi_stream_count_gen
        generic map(
            counter_bits_g      => counter_bits_c,
            tvalid_patt_gen_g   => x"F442_13AC"
        )
        port map(
            clk_i               => clk_s,
            rst_i               => rst_s,
            --
            m_axis_tvalid_o     => tvalid_a_s,
            m_axis_tready_i     => tready_a_s,
            m_axis_tlast_o      => tlast_a_s,
            m_axis_tdata_o      => tdata_a_s
        );

    tdata_gen_a_s <= tdata_gen_a_c(to_integer(unsigned(tdata_a_s)));

    -----------------------------------------------------------------
    -- Counter B
    -----------------------------------------------------------------
    counter_b_u: entity axis_lib.axi_stream_count_gen
        generic map(
            counter_bits_g      => counter_bits_c,
            tvalid_patt_gen_g   => x"D12A_DEAC"
        )
        port map(
            clk_i               => clk_s,
            rst_i               => rst_s,
            --
            m_axis_tvalid_o     => tvalid_b_s,
            m_axis_tready_i     => tready_b_s,
            m_axis_tlast_o      => tlast_b_s,
            m_axis_tdata_o      => tdata_b_s
        );

    tdata_gen_b_s <= tdata_gen_b_c(to_integer(unsigned(tdata_b_s)));

    -----------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------
    dut_u: entity axis_lib.axis_concatenate
        generic map(
            tdata_a_width_g     => tdata_a_width_c, 
            tdata_b_width_g     => tdata_b_width_c,
            tuser_a_width_g     => tdata_a_width_c, 
            tuser_b_width_g     => tdata_b_width_c
        )
        port map(
            clk_i               => clk_s, 
            rst_i               => rst_s, 
            -- PORT A (LSB RESULT)
            s_axis_tvalid_a_i   => tvalid_a_s,
            s_axis_tready_a_o   => tready_a_s, 
            s_axis_tlast_a_i    => tlast_a_s, 
            s_axis_tdata_a_i    => tdata_gen_a_s, 
            s_axis_tuser_a_i    => tdata_a_s,
            -- PORT B (LSB RESULT)
            s_axis_tvalid_b_i   => tvalid_b_s,  
            s_axis_tready_b_o   => tready_b_s,  
            s_axis_tlast_b_i    => tlast_b_s,   
            s_axis_tdata_b_i    => tdata_gen_b_s,
            s_axis_tuser_b_i    => tdata_b_s,
            --
            m_axis_tvalid_o     => tvalid_c_s,  
            m_axis_tready_i     => tready_c_s,  
            m_axis_tlast_o      => tlast_c_s,   
            m_axis_tdata_o      => tdata_c_s,
            m_axis_tuser_o      => tuser_c_s
        );

    end_pckg_s <= tvalid_c_s and tready_c_s and tlast_c_s;
            
    -----------------------------------------------------------------
    -- Tready
    -----------------------------------------------------------------
    tready_c_p: process(clk_s)
        variable tready_patt_v : std_logic_vector(31 downto 0) := (others => '0');
    begin
        if rising_edge(clk_s) then
            if rst_s = '1' then
                tready_patt_v := tready_patt_c;
            else
                tready_patt_v := tready_patt_v rol 1;
            end if;

            tready_c_s <= tready_patt_v(tready_patt_v'high);
        end if;
    end process;

    -----------------------------------------------------------------
    -- AXIS Protocol Checker 
    -----------------------------------------------------------------
    axis_checker_u: entity vunit_lib.axi_stream_protocol_checker
        generic map(
            protocol_checker        => protocol_checker
        )
        port map(
            aclk                    => clk_s,
            areset_n                => not rst_s,
            --
            tvalid                  => tvalid_c_s,
            tready                  => tready_c_s,
            tlast                   => tlast_c_s,
            tdata                   => tdata_c_s
        );
    
    -----------------------------------------------------------------
    -- Check
    -----------------------------------------------------------------
    check_p: process(clk_s)
        variable expected_data_v : std_logic_vector(tdata_a_width_c+tdata_b_width_c-1 downto 0);
        variable index_v :  integer;
    begin
        if rising_edge(clk_s) then
            if tvalid_c_s = '1' and tready_c_s = '1' then
                index_v := to_integer(unsigned(tuser_c_s(tdata_a_width_c-1 downto 0)));
                expected_data_v := tdata_gen_b_c(index_v) & tdata_gen_a_c(index_v);
                check_equal(tdata_c_s, expected_data_v, "TDATA ERROR");
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Vunit Process 
    -----------------------------------------------------------------
    main_u: process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("debug") then
                wait until end_pckg_s = '1';
                wait until clk_s'event and clk_s = '1';
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process;

end tb;
