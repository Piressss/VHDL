---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 14/01/2019
-- @Lib   : AXIS LIB
-- @Code  : AXIS_REGISTER_TB
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
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
entity axi_stream_register_tb is
    generic(
        runner_cfg      : string
    );
end axi_stream_register_tb;

architecture tb of axi_stream_register_tb is
    
    constant counter_bits_c     : integer := 12;
    constant max_counter_c      : integer := 2**counter_bits_c;
    constant logger                 : logger_t := get_logger("protocol_checker");
    constant protocol_checker       : axi_stream_protocol_checker_t := new_axi_stream_protocol_checker(data_length => counter_bits_c, logger => logger, actor =>
                                      new_actor("protocol_checker"), max_waits => 2**counter_bits_c);

    signal clk_s                : std_logic := '0';
    signal rst_s                : std_logic := '1';
    signal rstn_s               : std_logic := '0';
    signal counter_cnt          : unsigned(counter_bits_c-1 downto 0) := (others => '0');
    signal tvalid_s             : std_logic_vector(1 downto 0) := (others => '0');
    signal tready_s             : std_logic_vector(1 downto 0) := (others => '0');
    signal tlast_s              : std_logic_vector(1 downto 0) := (others => '0');
    signal tdata_s              : bit12vec_t(1 downto 0) := (others => (others => '0'));
    signal tvalid_lock_cnt      : unsigned(vec_fit(counter_bits_c) downto 0) := (others => '0');
    signal tready_lock_cnt      : unsigned(vec_fit(counter_bits_c) downto 0) := (others => '0');

begin

    -----------------------------------------------------------------
    -- CLK/RST 
    -----------------------------------------------------------------
    clk_s <= not clk_s after 5 ns;
    
    rst_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            rst_s <= '0';
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
                if counter_cnt = max_counter_c-1 then
                    counter_cnt <= (others => '0');
                else
                    counter_cnt <= counter_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Counter 
    -----------------------------------------------------------------
    counter_u: entity axis_lib.axi_stream_count_gen
        generic map(
            counter_bits_g      => counter_bits_c,
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
    -- AXIS Protocol Checker 
    -----------------------------------------------------------------
    axis_checker_0_u: entity vunit_lib.axi_stream_protocol_checker
        generic map(
            protocol_checker        => protocol_checker
        )
        port map(
            aclk                    => clk_s,
            areset_n                => rstn_s,
            --
            tvalid                  => tvalid_s(0),
            tready                  => tready_s(0),
            tlast                   => tlast_s(0),
            tdata                   => tdata_s(0)
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
                    check(counter_cnt = max_counter_c - 1, "TLAST ERROR");
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- AXIS REGISTER 
    -----------------------------------------------------------------
        register_u: entity axis_lib.axi_stream_register
            generic map(
                tdata_size_g        => counter_bits_c,
                tuser_size_g        => 1
            )
            port map(
                clk_i               => clk_s,
                rst_i               => rst_s,
                --
                s_axis_tvalid_i     => tvalid_s(0),
                s_axis_tready_o     => tready_s(0),
                s_axis_tlast_i      => tlast_s(0),
                s_axis_tdata_i      => tdata_s(0),
                s_axis_tuser_i      => (others => '0'),
                --
                m_axis_tvalid_o     => tvalid_s(1),
                m_axis_tready_i     => tready_s(1),
                m_axis_tlast_o      => tlast_s(1),
                m_axis_tdata_o      => tdata_s(1),
                m_axis_tuser_o      => open 
            );

        tready_s(1) <= '1';
    
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

            check(tvalid_lock_cnt < 2**counter_bits_c, "TREADY LOCK ERROR");
            check(tready_lock_cnt < 2**counter_bits_c, "TVALID LOCK ERROR");
        end if;
    end process;

    -----------------------------------------------------------------
    -- Vunit Process 
    -----------------------------------------------------------------
    main_u: process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("axi_stream_register_test") then
                wait until tlast_s(1) = '1';
                wait until clk_s'event and clk_s = '1';
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process;

end tb;
