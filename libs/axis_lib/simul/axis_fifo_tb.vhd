---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 16/01/2019
-- @Lib   : AXIS LIB
-- @Code  : AXIS_FIFO
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
entity axis_fifo_tb is
    generic(
        runner_cfg      : string;
        addr_width_g    : integer := 1;
        data_width_g    : integer := 1;
        user_width_g    : integer := 1;
        fifo_register_g : boolean := false
    );
end axis_fifo_tb;

architecture tb of axis_fifo_tb is

    type tdata_t is array (natural range<>) of std_logic_vector(data_width_g-1 downto 0);
    type tuser_t is array (natural range<>) of std_logic_vector(user_width_g-1 downto 0);

    constant logger                 : logger_t := get_logger("protocol_checker");
    constant protocol_checker       : axi_stream_protocol_checker_t := new_axi_stream_protocol_checker(data_length => data_width_g, logger => logger, actor =>
                                      new_actor("protocol_checker"), max_waits => 2**addr_width_g);

    signal clk_s                : std_logic := '0';
    signal rst_s                : std_logic := '1';
    signal rstn_s               : std_logic := '0';
    signal counter_cnt          : unsigned(data_width_g-1 downto 0) := (others => '0');
    signal tvalid_s             : std_logic_vector(1 downto 0) := (others => '0');
    signal tready_s             : std_logic_vector(1 downto 0) := (others => '0');
    signal tlast_s              : std_logic_vector(1 downto 0) := (others => '0');
    signal tdata_s              : tdata_t(1 downto 0) := (others => (others => '0'));
    signal tuser_s              : tuser_t(1 downto 0) := (others => (others => '0'));
    signal tvalid_lock_cnt      : unsigned(vec_fit(addr_width_g) downto 0) := (others => '0');
    signal tready_lock_cnt      : unsigned(vec_fit(addr_width_g) downto 0) := (others => '0');

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
    -- Gero o contador para comparacao
    -----------------------------------------------------------------
    counter_gen_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if rst_s = '1' then
                counter_cnt <= (others => '0');
            elsif tvalid_s(1) = '1' and tready_s(1) = '1' then
                counter_cnt <= counter_cnt + 1;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Counter Gen 
    -----------------------------------------------------------------
    counter_u: entity axis_lib.axi_stream_count_gen
        generic map(
            counter_bits_g      => data_width_g,
            infinity_loop_g     => false
        )
        port map(
            clk_i               => clk_s,
            rst_i               => rst_s,
            --
            m_axis_tvalid_o     => tvalid_s(0),
            m_axis_tready_i     => tready_s(0),
            m_axis_tlast_o      => tlast_s(0),
            m_axis_tdata_o      => tdata_s(0)
        );
        
    -----------------------------------------------------------------
    -- AXIS FIFO 
    -----------------------------------------------------------------
    axis_fifo_u: entity axis_lib.axis_fifo
        generic map(
            addr_width_g        => addr_width_g, 
            data_width_g        => data_width_g, 
            user_width_g        => user_width_g, 
            fifo_register_g     => fifo_register_g
        )
        port map(
            clk_i               => clk_s,
            rst_i               => rst_s,
            --
            s_axis_tvalid_i     => tvalid_s(0),
            s_axis_tready_o     => tready_s(0),
            s_axis_tlast_i      => tlast_s(0),
            s_axis_tdata_i      => tdata_s(0),
            s_axis_tuser_i      => tuser_s(0),
            --
            m_axis_tvalid_o     => tvalid_s(1),
            m_axis_tready_i     => tready_s(1),
            m_axis_tlast_o      => tlast_s(1),
            m_axis_tdata_o      => tdata_s(1),
            m_axis_tuser_o      => tuser_s(1)
        );
            
    -----------------------------------------------------------------
    -- Check Tdata 
    -----------------------------------------------------------------
    tdata_check_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s(1) = '1' and tready_s(1) = '1' then
                check_equal(unsigned(tdata_s(1)), counter_cnt, "TDATA ERROR");
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Check Tlast 
    -----------------------------------------------------------------
    tlast_check_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s(1) = '1' and tready_s(1) = '1' then
                if tlast_s(1) = '1' then
                    check(counter_cnt = (2**data_width_g) - 1, "TLAST ERROR");
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
            tdata                   => tdata_s(1)
        );
            
        rand_p: process(clk_s)
            variable seed1: positive;
            variable seed2: positive;
            variable rand: real;
            variable range_of_rand: real := 1000.0;
            variable result : std_logic_vector(9 downto 0);
        begin
            if clk_s'event and clk_s = '1' then
                uniform(seed1, seed2, rand);    -- generate random number
                result := std_logic_vector(to_unsigned(integer(rand*range_of_rand),10));
                tready_s(1) <= result(0);
            end if;
        end process;

    -----------------------------------------------------------------
    -- Pipeline Locked
    -----------------------------------------------------------------
    locked_check_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s(1) = '1' and tready_s(1) = '0' then
                tready_lock_cnt <= tready_lock_cnt + 1;
                tvalid_lock_cnt <= (others => '0');
            elsif tvalid_s(1) = '0' and tready_s(1) = '1' then
                tready_lock_cnt <= (others => '0');
                tvalid_lock_cnt <= tvalid_lock_cnt + 1;
            else
                tready_lock_cnt <= (others => '0');
                tvalid_lock_cnt <= (others => '0');
            end if;

            check(tvalid_lock_cnt < 2**addr_width_g, "TREADY LOCK ERROR");
            check(tready_lock_cnt < 2**addr_width_g, "TVALID LOCK ERROR");
        end if;
    end process;

    -----------------------------------------------------------------
    -- Vunit Process 
    -----------------------------------------------------------------
    main_u: process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("axis_fifo_test0") or run("axis_fifo_test1") or run("axis_fifo_test2") then
                wait until tlast_s(1) = '1';
                wait until clk_s'event and clk_s = '1';
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process;

end tb;

