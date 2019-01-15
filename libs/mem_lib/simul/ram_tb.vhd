---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 15/01/2019
-- @Lib   : MEM LIB
-- @Code  : RAM_TB 
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--
library mem_lib;
--
library vunit_lib;
use vunit_lib.axi_stream_pkg.all;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.data_types_context;
---------------------------------------------------------------------
entity ram_tb is
    generic(
        runner_cfg      : string;
        addr_width_g    : integer := 1;
        register_en_g   : boolean := false
    );
end ram_tb;

architecture tb of ram_tb is

    constant max_counter_c      : integer := 2**addr_width_g;

    signal clk_s                : std_logic := '0';
    signal rst_s                : std_logic := '1';
    signal data_cnt             : unsigned(addr_width_g-1 downto 0) := (others => '0');
    signal we_s                 : std_logic := '0';
    signal re_s                 : std_logic := '0';
    signal addr_rd_cnt          : unsigned(addr_width_g-1 downto 0) := (others => '0');
    signal data_valid_s         : std_logic := '0';
    signal data_rd_s            : std_logic_vector(addr_width_g-1 downto 0) := (others => '0');
    signal data_check_s         : unsigned(addr_width_g-1 downto 0) := (others => '0');
    signal end_check_s          : std_logic := '0';

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
    -- Gero o contador para escrita
    -----------------------------------------------------------------
    we_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if rst_s = '1' then
                we_s <= '0';
            elsif data_cnt = max_counter_c-1 then
                we_s <= '0';
            else
                we_s <= '1';
            end if;
        end if;
    end process;

    counter_gen_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if rst_s = '1' then
                data_cnt <= (others => '0');
            elsif we_s = '1' then
                if data_cnt < max_counter_c-1 then
                    data_cnt <= data_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- MEM
    -----------------------------------------------------------------
    ram_u: entity mem_lib.ram
        generic map(
            data_width_g        => addr_width_g, 
            addr_width_g        => addr_width_g,
            wr_register_enable_g=> register_en_g,
            rd_register_enable_g=> register_en_g
        )
        port map(
            clk_i               => clk_s,
            rst_i               => rst_s,
            --
            we_i                => we_s,
            data_wr_i           => std_logic_vector(data_cnt),
            addr_wr_i           => std_logic_vector(data_cnt),
            --
            re_i                => re_s,
            addr_rd_i           => std_logic_vector(addr_rd_cnt),
            data_valid_o        => data_valid_s,
            data_rd_o           => data_rd_s
        );

    -----------------------------------------------------------------
    -- Read Enable
    -----------------------------------------------------------------
    re_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if we_s = '0' and data_cnt = max_counter_c - 1 then
                if addr_rd_cnt = max_counter_c - 1 then
                    re_s <= '0';
                else
                    re_s <= '1';
                end if;
            else
                re_s <= '0';
            end if;
        end if;
    end process;

    addr_rd_cnt_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if re_s = '1' then
                if addr_rd_cnt < max_counter_c - 1 then
                    addr_rd_cnt <= addr_rd_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Data Read Check
    -----------------------------------------------------------------
    data_check_p: process(clk_s)
    begin
        if clk_s'event and clk_s = '1' then
            if data_valid_s = '1' then
                data_check_s <= data_check_s + 1;
                check_equal(unsigned(data_rd_s), data_check_s, "DATA READ ERROR");
                if data_check_s = max_counter_c - 1 then
                    end_check_s <= '1';
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
            if run("ram_register_test") or run("ram_no_register_test") then
                wait until end_check_s = '1';
                wait until clk_s'event and clk_s = '1';
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process;

end tb;

