---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 21/01/2019
-- @Lib   : AXIS LIB
-- @Code  : AXIS_PARALLEL_ADDER
-- @brief : Add more than two data words. 
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
entity axis_parallel_adder is
    generic(
        data_width_g        : integer := 1;
        num_words_g         : integer := 3
    );
    port(
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
        --
        s_axis_tvalid_i     : in  std_logic;
        s_axis_tready_o     : out std_logic;
        s_axis_tlast_i      : in  std_logic;
        s_axis_tdata_i      : in  std_logic_vector((data_width_g*num_words_g)-1 downto 0); -- Data to be multiplied
        --
        m_axis_tvalid_o     : out std_logic;
        m_axis_tready_i     : in  std_logic;
        m_axis_tlast_o      : out std_logic;
        m_axis_tdata_o      : out std_logic_vector(data_width_g-1 downto 0);
        overflow_o          : out std_logic
    );
end axis_parallel_adder;

architecture rtl of axis_parallel_adder is

    -- This function defines the number of stages of adder
    function define_stages_f(constant num_words: integer) return integer is
        variable result_v : integer := 0;
    begin
        result_v := vec_fit(num_words_g);
        return result_v;
    end function define_stages_f;

    type tdata_stage_t is array (natural range<>) of unsigned(data_width_g downto 0);

    constant stage_c        : integer := define_stages_f(num_words_g);

    signal tvalid_s         : std_logic_vector(15 downto 0) := (others => '0'); 
    signal tready_s         : std_logic_vector(15 downto 0) := (others => '0'); 
    signal tlast_s          : std_logic_vector(15 downto 0) := (others => '0'); 
    signal tdata_s          : std_logic_vector((data_width_g*num_words_g)-1 downto 0) := (others => '0');
    signal tdata_s0_s       : tdata_stage_t(63 downto 0) := (others => (others => '0'));
    signal tdata_s1_s       : tdata_stage_t(31 downto 0) := (others => (others => '0'));
    signal tdata_s2_s       : tdata_stage_t(15 downto 0) := (others => (others => '0'));
    signal tdata_s3_s       : tdata_stage_t( 7 downto 0) := (others => (others => '0'));
    signal tdata_s4_s       : tdata_stage_t( 3 downto 0) := (others => (others => '0'));
    signal tdata_s5_s       : tdata_stage_t( 1 downto 0) := (others => (others => '0'));
    signal tdata_s6_s       : tdata_stage_t( 0 downto 0) := (others => (others => '0'));
    signal overflow_o_s     : std_logic_vector(0 downto 0) := (others => '0'); 

begin

    assert num_words_g > 2 report "Number of words must to be greather than 2." severity failure;
    assert num_words_g < 65 report "Number of words must to be less than 65." severity failure;

    -----------------------------------------------------------------
    -- Register input 
    -----------------------------------------------------------------
    input_register_u: entity axis_lib.axi_stream_register
        generic map(
            tdata_size_g        => data_width_g*num_words_g
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
            m_axis_tdata_o      => tdata_s
        );
        
    tdata_gen: for i in num_words_g-1 downto 0 generate
        tdata_s0_s(i)(data_width_g-1 downto 0) <= unsigned(tdata_s((i+1)*data_width_g -1 downto (i*data_width_g)));
    end generate;
    
    -----------------------------------------------------------------
    -- Stage 0 - 32 Adders 
    -----------------------------------------------------------------
    stage_0_gen: if stage_c >= 6 generate
        
        stage_0_adder_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if tvalid_s(0) = '1' and tready_s(0) = '1' then
                    tvalid_s(1) <= '1';
                    tlast_s(1)  <= tlast_s(0);
                    for i in 31 downto 0 loop
                        tdata_s1_s(i) <= tdata_s0_s(i*2) + tdata_s0_s((i*2)+1);
                    end loop;
                elsif tvalid_s(1) = '1' and tready_s(1) = '0' then
                    tvalid_s(1) <= '1';
                    tlast_s(1)  <= tlast_s(1);
                    tdata_s1_s  <= tdata_s1_s;
                else
                    tvalid_s(1) <= '0';
                end if;
            end if;
        end process;

    else generate

        tvalid_s(1) <= tvalid_s(0);
        tlast_s(1)  <= tlast_s(0);
        tdata_s1_s  <= tdata_s0_s(31 downto 0);
        
    end generate;
        
    tready_s(0) <= tready_s(1);

    -----------------------------------------------------------------
    -- Stage 1 - 16 Adders 
    -----------------------------------------------------------------
    stage_1_gen: if stage_c >= 5 generate
        
        stage_1_adder_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if tvalid_s(1) = '1' and tready_s(1) = '1' then
                    tvalid_s(2) <= '1';
                    tlast_s(2)  <= tlast_s(1);
                    for i in 15 downto 0 loop
                        tdata_s2_s(i) <= tdata_s1_s(i*2) + tdata_s1_s((i*2)+1);
                    end loop;
                elsif tvalid_s(2) = '1' and tready_s(2) = '0' then
                    tvalid_s(2) <= '1';
                    tlast_s(2)  <= tlast_s(2);
                    tdata_s2_s  <= tdata_s2_s;
                else
                    tvalid_s(2) <= '0';
                end if;
            end if;
        end process;

    else generate

        tvalid_s(2) <= tvalid_s(1);
        tlast_s(2)  <= tlast_s(1);
        tdata_s2_s  <= tdata_s1_s(15 downto 0);
        
    end generate;
        
    tready_s(1) <= tready_s(2);

    -----------------------------------------------------------------
    -- Stage 2 - 8 Adders 
    -----------------------------------------------------------------
    stage_2_gen: if stage_c >= 4 generate
        
        stage_2_adder_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if tvalid_s(2) = '1' and tready_s(2) = '1' then
                    tvalid_s(3) <= '1';
                    tlast_s(3)  <= tlast_s(2);
                    for i in 7 downto 0 loop
                        tdata_s3_s(i) <= tdata_s2_s(i*2) + tdata_s2_s((i*2)+1);
                    end loop;
                elsif tvalid_s(3) = '1' and tready_s(3) = '0' then
                    tvalid_s(3) <= '1';
                    tlast_s(3)  <= tlast_s(3);
                    tdata_s3_s  <= tdata_s3_s;
                else
                    tvalid_s(3) <= '0';
                end if;
            end if;
        end process;

    else generate

        tvalid_s(3) <= tvalid_s(2);
        tlast_s(3)  <= tlast_s(2);
        tdata_s3_s  <= tdata_s2_s(7 downto 0);
        
    end generate;
        
    tready_s(2) <= tready_s(3);
    
    -----------------------------------------------------------------
    -- Stage 3 - 4 Adders 
    -----------------------------------------------------------------
    stage_3_gen: if stage_c >= 3 generate
        
        stage_3_adder_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if tvalid_s(3) = '1' and tready_s(3) = '1' then
                    tvalid_s(4) <= '1';
                    tlast_s(4)  <= tlast_s(3);
                    for i in 3 downto 0 loop
                        tdata_s4_s(i) <= tdata_s3_s(i*2) + tdata_s3_s((i*2)+1);
                    end loop;
                elsif tvalid_s(4) = '1' and tready_s(4) = '0' then
                    tvalid_s(4) <= '1';
                    tlast_s(4)  <= tlast_s(4);
                    tdata_s4_s  <= tdata_s4_s;
                else
                    tvalid_s(4) <= '0';
                end if;
            end if;
        end process;

    else generate

        tvalid_s(4) <= tvalid_s(3);
        tlast_s(4)  <= tlast_s(3);
        tdata_s4_s  <= tdata_s3_s(3 downto 0);
        
    end generate;
        
    tready_s(3) <= tready_s(4);
    
    -----------------------------------------------------------------
    -- Stage 4 - 2 Adders 
    -----------------------------------------------------------------
    stage_4_gen: if stage_c >= 2 generate
        
        stage_4_adder_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if tvalid_s(4) = '1' and tready_s(4) = '1' then
                    tvalid_s(5) <= '1';
                    tlast_s(5)  <= tlast_s(4);
                    for i in 1 downto 0 loop
                        tdata_s5_s(i) <= tdata_s4_s(i*2) + tdata_s4_s((i*2)+1);
                    end loop;
                elsif tvalid_s(5) = '1' and tready_s(5) = '0' then
                    tvalid_s(5) <= '1';
                    tlast_s(5)  <= tlast_s(5);
                    tdata_s5_s  <= tdata_s5_s;
                else
                    tvalid_s(5) <= '0';
                end if;
            end if;
        end process;

    else generate

        tvalid_s(5) <= tvalid_s(4);
        tlast_s(5)  <= tlast_s(4);
        tdata_s5_s  <= tdata_s4_s(1 downto 0);
        
    end generate;
    
    tready_s(4) <= tready_s(5);
    
    -----------------------------------------------------------------
    -- Stage 5 - 1 Adder
    -----------------------------------------------------------------
    stage_5_gen: if stage_c >= 1 generate
        
        stage_4_adder_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if tvalid_s(5) = '1' and tready_s(5) = '1' then
                    tvalid_s(6) <= '1';
                    tlast_s(6)  <= tlast_s(5);
                    for i in 0 downto 0 loop
                        tdata_s6_s(i) <= tdata_s5_s(i*2) + tdata_s5_s((i*2)+1);
                    end loop;
                elsif tvalid_s(6) = '1' and tready_s(6) = '0' then
                    tvalid_s(6) <= '1';
                    tlast_s(6)  <= tlast_s(6);
                    tdata_s6_s  <= tdata_s6_s;
                else
                    tvalid_s(6) <= '0';
                end if;
            end if;
        end process;

    else generate

        tvalid_s(6) <= tvalid_s(5);
        tlast_s(6)  <= tlast_s(5);
        tdata_s6_s  <= tdata_s5_s(0 downto 0);
        
    end generate;
        
    tready_s(5) <= tready_s(6);
    
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
            s_axis_tvalid_i     => tvalid_s(6), 
            s_axis_tready_o     => tready_s(6),
            s_axis_tlast_i      => tlast_s(6),
            s_axis_tdata_i      => std_logic_vector(tdata_s6_s(0)(data_width_g-1 downto 0)),
            s_axis_tuser_i      => std_logic_vector(tdata_s6_s(0)(data_width_g downto data_width_g)),
            --
            m_axis_tvalid_o     => m_axis_tvalid_o, 
            m_axis_tready_i     => m_axis_tready_i,
            m_axis_tlast_o      => m_axis_tlast_o,
            m_axis_tdata_o      => m_axis_tdata_o,
            m_axis_tuser_o      => overflow_o_s
        );

        overflow_o <= overflow_o_s(0);
        
end rtl;
