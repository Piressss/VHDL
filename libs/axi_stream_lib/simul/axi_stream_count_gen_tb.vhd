---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 10/01/2019
-- @Lib   : AXIS LIB
-- @Code  : AXIS_COUNT_GEN_TB
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--
library axis_lib;
--
library vunit_lib;
context vunit_lib.vunit_context;
---------------------------------------------------------------------
entity axi_stream_count_gen_tb is
    generic(
        runner_cfg      : string;
        counter_bits_g  : integer := 1
    );
end axi_stream_count_gen_tb;

architecture tb of axi_stream_count_gen_tb is

    constant max_counter_c      : integer := 2**counter_bits_g;

    signal clk_s                : std_logic := '0';
    signal rst_s                : std_logic := '1';
    signal counter_cnt          : unsigned(counter_bits_g-1 downto 0) := (others => '0');
    signal tvalid_s             : std_logic := '0';
    signal tready_s             : std_logic := '0';
    signal tlast_s              : std_logic := '0';
    signal tdata_s              : std_logic_vector(counter_bits_g-1 downto 0) := (others => '0');

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
    -- Gero o contador para comparacao
    -----------------------------------------------------------------
    counter_gen_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if rst_s = '1' then
                counter_cnt <= (others => '0');
            elsif tvalid_s = '1' and tready_s = '1' then
                if counter_cnt = max_counter_c-1 then
                    counter_cnt <= (others => '0');
                else
                    counter_cnt <= counter_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Tready 
    -----------------------------------------------------------------
    tready_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if rst_s = '1' then
                tready_s <= '0';
            else
                tready_s <= '1';
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------
    -- Counter 
    -----------------------------------------------------------------
    counter_u: entity axis_lib.axi_stream_count_gen
        generic map(
            counter_bits_g      => counter_bits_g
        )
        port map(
            clk_i               => clk_s,
            rst_i               => rst_s,
            --
            m_axis_tvalid_o     => tvalid_s,
            m_axis_tready_i     => tready_s,
            m_axis_tlast_o      => tlast_s,
            m_axis_tdata_o      => tdata_s
        );

    -----------------------------------------------------------------
    -- Check Tdata 
    -----------------------------------------------------------------
    tdata_check_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s = '1' and tready_s = '1' then
                check_equal(unsigned(tdata_s), counter_cnt, "TDATA ERROR");
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Check Tlast 
    -----------------------------------------------------------------
    tlast_check_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if tvalid_s = '1' and tready_s = '1' then
                if tlast_s = '1' then
                    check(counter_cnt = max_counter_c - 1, "TLAST ERROR");
                end if;
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
            if run("axi_stream_count_gen_test") then
                wait until tlast_s = '1';
                wait for 1 us;
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process;

end tb;
