---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 22/01/2019
-- @Lib   : AXIS LIB
-- @Code  : AXIS_PARALLEL_ADDER_TB
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
--
library base_lib;
use base_lib.base_lib_pkg.all;
--
library math_lib;
--
library vunit_lib;
use vunit_lib.axi_stream_pkg.all;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.data_types_context;
---------------------------------------------------------------------
entity axis_parallel_adder_tb is
    generic(
        runner_cfg      : string;
        data_width_g    : integer := 1;
        num_words_g     : integer := 1;
        pckg_size_g     : integer := 1
    );
end axis_parallel_adder_tb;

architecture tb of axis_parallel_adder_tb is

    type tdata_t is array (natural range<>) of std_logic_vector(data_width_g-1 downto 0);
    type buffer_t is array (natural range<>) of unsigned(data_width_g downto 0);
    
    constant logger                 : logger_t := get_logger("protocol_checker");
    constant protocol_checker       : axi_stream_protocol_checker_t := new_axi_stream_protocol_checker(data_length => data_width_g, logger => logger, actor =>
                                      new_actor("protocol_checker"), max_waits => 2**pckg_size_g);

    constant buffer_size_c          : integer := 64;

    signal clk_s            : std_logic := '1';
    signal rst_s            : std_logic := '1';
    signal rstn_s           : std_logic := '0';
    signal tdata_gen_s      : tdata_t(num_words_g-1 downto 0) := (others => (others => '0'));
    signal tvalid_s         : std_logic_vector(1 downto 0) := (others => '0');
    signal tready_s         : std_logic_vector(1 downto 0) := (others => '0');
    signal tlast_s          : std_logic_vector(1 downto 0) := (others => '0');
    signal tdata_vec_s      : std_logic_vector((data_width_g*num_words_g)-1 downto 0) := (others => '0');
    signal tdata_result_s   : std_logic_vector(data_width_g-1 downto 0) := (others => '0');
    signal overflow_s       : std_logic := '0';
    signal tlast_cnt        : unsigned(vec_fit(pckg_size_g)-1 downto 0) := (others => '0');
    signal tlast_check_cnt  : unsigned(vec_fit(pckg_size_g)-1 downto 0) := (others => '0');
    signal end_pckg_s       : std_logic := '0';
    signal buffer_reg_s     : buffer_t(buffer_size_c-1 downto 0) := (others => (others => '0')); 
    signal buffer_wr_s      : unsigned(vec_fit(buffer_size_c)-1 downto 0) := (others => '0');
    signal buffer_rd_s      : unsigned(vec_fit(buffer_size_c)-1 downto 0) := (others => '0');

begin

    -----------------------------------------------------------------
    -- CLK/RST
    -----------------------------------------------------------------
    clk_s <= not clk_s after 5 ns;

    rst_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            rst_s  <= '0';
            rstn_s <= '1';
        end if;
    end process;

    -----------------------------------------------------------------
    -- Generate Data to be Add
    -----------------------------------------------------------------
    words_gen: for i in num_words_g-1 downto 0 generate
        data_gen_p: process(clk_s)
            variable seed1: positive;
            variable seed2: positive;
            variable rand: real;
            variable range_of_rand: real := real(100000 * (i+1));
            variable result : std_logic_vector(data_width_g-1 downto 0);
        begin
            if clk_s'event and clk_s = '1' then
                if tvalid_s(0) = '1' and tready_s(0) = '1' then
                    uniform(seed1, seed2, rand);    -- generate random number
                    result := std_logic_vector(to_unsigned(integer(rand*range_of_rand),data_width_g));
                    tdata_gen_s(i) <= result;
                    tdata_vec_s((i+1)*data_width_g -1 downto i*data_width_g) <= result;
                end if;
            end if;
        end process;
    end generate;

    tvalid_p: process(clk_s)
        variable seed1: positive;
        variable seed2: positive;
        variable rand: real;
        variable range_of_rand: real := 65535.0;
        variable result : std_logic_vector(15 downto 0);
    begin
        if clk_s'event and clk_s = '1' then
            uniform(seed1, seed2, rand);    -- generate random number
            result := std_logic_vector(to_unsigned(integer(rand*range_of_rand),16));
            if tready_s(0) = '1' then
                tvalid_s(0) <= result(3);
            end if;
            tready_s(1) <= result(5);
        end if;
    end process;

    -----------------------------------------------------------------
    -- Tlast 
    -----------------------------------------------------------------
    tlast_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s(0) = '1' and tready_s(0) = '1' then
                if tlast_cnt = pckg_size_g - 1 then
                    tlast_cnt <= (others => '0');
                    tlast_s(0) <= '0';
                elsif tlast_cnt = pckg_size_g - 2 then
                    tlast_cnt <= tlast_cnt + 1;
                    tlast_s(0) <= '1';
                else
                    tlast_cnt <= tlast_cnt + 1;
                    tlast_s(0) <= '0';
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- DUT 
    -----------------------------------------------------------------
    dut_u: entity math_lib.axis_parallel_adder
        generic map(
            data_width_g        => data_width_g,
            num_words_g         => num_words_g
        )
        port map(
            clk_i               => clk_s,
            rst_i               => rst_s,
            --
            s_axis_tvalid_i     => tvalid_s(0),
            s_axis_tready_o     => tready_s(0),
            s_axis_tlast_i      => tlast_s(0),
            s_axis_tdata_i      => tdata_vec_s, 
            --
            m_axis_tvalid_o     => tvalid_s(1),
            m_axis_tready_i     => tready_s(1),
            m_axis_tlast_o      => tlast_s(1),
            m_axis_tdata_o      => tdata_result_s,
            overflow_o          => overflow_s
        );

    -----------------------------------------------------------------
    -- Tlast Check 
    -----------------------------------------------------------------
    tlast_check_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s(1) = '1' and tready_s(1) = '1' then
                if tlast_s(1) = '1' then
                    check(tlast_check_cnt = pckg_size_g - 1, "TLAST ERROR");
                    tlast_check_cnt <= (others => '0');
                else
                    tlast_check_cnt <= tlast_check_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- AXIS Protocol Checker 
    -----------------------------------------------------------------
    axis_checker_1_u: entity vunit_lib.axi_stream_protocol_checker
        generic map(
            protocol_checker        => protocol_checker
        )
        port map(
            aclk                    => clk_s,
            areset_n                => rstn_s,
            --
            tvalid                  => tvalid_s(1),
            tready                  => tready_s(1),
            tlast                   => tlast_s(1),
            tdata                   => tdata_result_s(data_width_g-1 downto 0)
        );

    -----------------------------------------------------------------
    -- TB Calculate Adder
    -----------------------------------------------------------------
    adder_p: process(clk_s)
        variable adder_v : unsigned(data_width_g downto 0) := (others => '0');
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s(0) = '1' and tready_s(0) = '1' then
                adder_v := (others => '0');
                for i in num_words_g-1 downto 0 loop
                    adder_v := adder_v + unsigned(tdata_gen_s(i)); 
                end loop;
                buffer_reg_s(to_integer(buffer_wr_s)) <= adder_v;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Buffer the result expected 
    -----------------------------------------------------------------
    buffer_wr_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s(0) = '1' and tready_s(0) = '1' then
                buffer_wr_s <= buffer_wr_s + 1;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Check Tdata result 
    -----------------------------------------------------------------
    buffer_rd_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s(1) = '1' and tready_s(1) = '1' then
                buffer_rd_s <= buffer_rd_s + 1;
            end if;
        end if;
    end process;

    check_result_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s(1) = '1' and tready_s(1) = '1' then
                check_equal(unsigned(tdata_result_s), buffer_reg_s(to_integer(buffer_rd_s))(data_width_g-1 downto 0), "RESULT ERROR");
            end if;
        end if;
    end process;

    check_overflow_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s(1) = '1' and tready_s(1) = '1' then
                check_equal(overflow_s, buffer_reg_s(to_integer(buffer_rd_s))(data_width_g), "OVERFLOW ERROR");
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Vunit Process 
    -----------------------------------------------------------------
    end_pckg_s <= tvalid_s(1) and tready_s(1) and tlast_s(1);

    main_u: process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("axis_add_test_0") or run("axis_add_test_1") or run("axis_add_test_2") then
                wait until clk_s'event and clk_s = '1';
                wait for 250 us;
                wait until end_pckg_s = '1';
                wait for 10 ns;
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process;
    

end tb;

        
