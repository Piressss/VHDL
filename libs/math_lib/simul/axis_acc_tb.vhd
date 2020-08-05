---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 04/08/2020
-- @Lib   : AXIS LIB
-- @Code  : AXIS_ACC_TB
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
entity axis_acc_tb is
    generic(
        runner_cfg          : string;
        tb_path             : string;
        data_width_g        : integer := 1;
        data_signed_g       : boolean := false;
        result_per_sample_g : boolean := false  -- If TRUE every input sample will generate one output accumulated sample, if FALSE only after Tlast the result will be outputed
    );
end axis_acc_tb;

architecture tb of axis_acc_tb is


    signal clk_s            : std_logic := '1';
    signal rst_s            : std_logic := '1';
    signal tvalid_s         : std_logic := '0';
    signal tready_s         : std_logic := '0';
    signal tlast_s          : std_logic := '0';
    signal tdata_s          : std_logic_vector(data_width_g-1 downto 0) := (others => '0');
    signal tvalid_out_s     : std_logic := '0';
    signal tready_out_s     : std_logic := '0';
    signal tlast_out_s      : std_logic := '0';
    signal tdata_out_s      : std_logic_vector(data_width_g-1 downto 0) := (others => '0');
    signal tuser_out_s      : std_logic_vector(0 downto 0) := (others => '0');

begin

    -----------------------------------------------------------------
    -- CLK/RST
    -----------------------------------------------------------------
    clk_s <= not clk_s after 5 ns;

    rst_p: process
    begin
        for i in 7 downto 0 loop
            wait until rising_edge(clk_s);
        end loop;
        rst_s <= '0';
        wait;
    end process;

    -----------------------------------------------------------------
    -- Data Input Vector
    -----------------------------------------------------------------
    input_vector_p: process(clk_s)
        variable data_v    : integer_array_t;
        variable width_v   : integer;
        variable index_v   : integer := 1;
    begin
        if rising_edge(clk_s) then
            if rst_s = '1' then
                if running_test_case = "result_per_frame_unsigned" then
                    data_v := load_csv(tb_path & "input_rpf_uns.csv");
                    width_v := width(data_v);
                elsif running_test_case = "result_per_frame_signed" then
                    data_v := load_csv(tb_path & "input_rpf_sig.csv");
                    width_v := width(data_v);
                elsif running_test_case = "result_per_sample_unsigned" then
                    data_v := load_csv(tb_path & "input_rps_uns.csv");
                    width_v := width(data_v);
                elsif running_test_case = "result_per_sample_signed" then
                    data_v := load_csv(tb_path & "input_rps_sig.csv");
                    width_v := width(data_v);
                end if;
                
                if data_signed_g = true then
                    tdata_s <= std_logic_vector(to_signed(get(data_v, 0), data_width_g));
                else
                    tdata_s <= std_logic_vector(to_unsigned(get(data_v, 0), data_width_g));
                end if;
            elsif tvalid_s = '1' and tready_s = '1' then
                if data_signed_g = true then
                    tdata_s <= std_logic_vector(to_signed(get(data_v, index_v), data_width_g));
                else
                    tdata_s <= std_logic_vector(to_unsigned(get(data_v, index_v), data_width_g));
                end if;

                if index_v = width_v - 1 then
                    tlast_s <= '1';
                else
                    tlast_s <= '0';
                end if;

                if index_v = width_v - 1 then
                    index_v := 0;
                else
                    index_v := index_v + 1;
                end if;

            end if;
        end if;
    end process;

    tvalid_p: process(clk_s)
    begin
        if rising_edge(clk_s) then
            if rst_s = '0' then
                tvalid_s <= '1';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------
    dut_u: entity math_lib.axis_acc
        generic map(
            data_width_g        => data_width_g, 
            data_signed_g       => data_signed_g, 
            result_per_sample_g => result_per_sample_g
        )
        port map(
            clk_i               => clk_s,
            rst_i               => rst_s,
            --
            s_axis_tvalid_i     => tvalid_s,
            s_axis_tready_o     => tready_s,
            s_axis_tlast_i      => tlast_s,
            s_axis_tdata_i      => tdata_s,
            --
            m_axis_tvalid_o     => tvalid_out_s,
            m_axis_tready_i     => tready_out_s,
            m_axis_tlast_o      => tlast_out_s,
            m_axis_tdata_o      => tdata_out_s,
            m_axis_tuser_o      => tuser_out_s
        );

    -----------------------------------------------------------------
    -- Check
    -----------------------------------------------------------------
    check_p: process(clk_s)
        variable data_v    : integer_array_t;
        variable length_v  : integer;
        variable width_v   : integer;
        variable index_v   : integer := 0;
    begin
        if rising_edge(clk_s) then
            if rst_s = '1' then
                if running_test_case = "result_per_frame_unsigned" then
                    data_v := load_csv(tb_path & "output_rpf_uns.csv");
                    length_v := length(data_v);
                    width_v := width(data_v);
                elsif running_test_case = "result_per_frame_signed" then
                    data_v := load_csv(tb_path & "output_rpf_sig.csv");
                    length_v := length(data_v);
                    width_v := width(data_v);
                elsif running_test_case = "result_per_sample_unsigned" then
                    data_v := load_csv(tb_path & "output_rps_uns.csv");
                    length_v := length(data_v);
                    width_v := width(data_v);
                elsif running_test_case = "result_per_sample_signed" then
                    data_v := load_csv(tb_path & "output_rps_sig.csv");
                    length_v := length(data_v);
                    width_v := width(data_v);
                end if;
            elsif tvalid_out_s = '1' and tready_out_s = '1' then
                
                check_equal(to_integer(unsigned(tuser_out_s)), get(data_v,index_v+width_v), "OVER RANGE ERROR");  

                if data_signed_g = true then
                    check_equal(signed(tdata_out_s), to_signed(get(data_v,index_v),data_width_g), "ACC ERROR");
                else
                    check_equal(unsigned(tdata_out_s), to_unsigned(get(data_v,index_v),data_width_g), "ACC ERROR");
                end if;

                if index_v = width_v - 1 then
                    check_equal(tlast_out_s, '1', "TLAST EXPECTED ERROR");
                else
                    check_equal(tlast_out_s, '0', "TLAST UNEXPECTED ERROR");
                end if;

                if index_v = width_v - 1 then
                    index_v := 0;
                else
                    index_v := index_v + 1;
                end if;
            end if;
        end if;
    end process;

    tready_out_s <= '1';

    -----------------------------------------------------------------
    -- Vunit Process 
    -----------------------------------------------------------------
    main_u: process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("result_per_frame_unsigned") or run("result_per_frame_signed") or run("result_per_sample_unsigned") or run("result_per_sample_signed") then
                wait for 20 us;
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process;

end tb;
