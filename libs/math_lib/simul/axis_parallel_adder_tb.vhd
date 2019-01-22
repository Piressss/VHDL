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
        num_words_g      : integer := 1
    );
end axis_parallel_adder_tb;

architecture tb of axis_parallel_adder_tb is

    type tdata_t is array (natural range<>) of std_logic_vector(data_width_g-1 downto 0);

    signal clk_s            : std_logic := '1';
    signal rst_s            : std_logic := '1';
    signal tdata_gen_s      : tdata_t(num_words_g-1 downto 0) := (others => (others => '0'));
    signal tvalid_s         : std_logic_vector(1 downto 0) := (others => '0');
    signal tready_s         : std_logic_vector(1 downto 0) := (others => '0');
    signal tlast_s          : std_logic_vector(1 downto 0) := (others => '0');
    signal tdata_vec_s      : std_logic_vector((data_width_g*num_words_g)-1 downto 0) := (others => '0');
    signal tdata_result_s   : std_logic_vector(data_width_g-1 downto 0) := (others => '0');
    signal overflow_s       : std_logic := '0';

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
            tvalid_s(0) <= result(3);
            tready_s(1) <= result(5);
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
    -- Vunit Process 
    -----------------------------------------------------------------
    main_u: process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("axis_add_test_0") then
                wait until clk_s'event and clk_s = '1';
                wait for 250 us;
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process;
    

end tb;

        
