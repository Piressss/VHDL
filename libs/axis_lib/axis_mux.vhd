---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 16/10/2021
-- @Lib   : AXIS LIB
-- @Code  : AXIS_MUX
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library base_lib;
use base_lib.base_lib_pkg.all;
library axis_lib;
---------------------------------------------------------------------
entity axis_mux is
    generic(
        tdata_size_g        : integer := 1;
        tuser_size_g        : integer := 1;
        num_ports_g         : integer := 2;
        round_robin_enable_g: boolean := false;  -- If true ignores the select_input_i info and always change after tlast
        timeout_g           : integer := 1       -- Max number of cycles to wait a tvalid high until change the port
    );
    port(
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
        select_input_i      : in  vec_fit((num_ports_g)-1 downto 0);
        --
        s_axis_tvalid_i     : in  std_logic_vector(num_ports_g-1 downto 0);
        s_axis_tready_o     : out std_logic_vector(num_ports_g-1 downto 0);
        s_axis_tlast_i      : in  std_logic_vector(num_ports_g-1 downto 0);
        s_axis_tdata_i      : in  std_logic_vector((tdata_size_g*num_ports_g)-1 downto 0);
        s_axis_tuser_i      : in  std_logic_vector((tuser_size_g*num_ports_g)-1 downto 0) := (others => '0');
        --
        m_axis_tvalid_o     : out std_logic;
        m_axis_tready_i     : in  std_logic;
        m_axis_tlast_o      : out std_logic;
        m_axis_tdata_o      : out std_logic_vector(tdata_size_g-1 downto 0);
        m_axis_tuser_o      : out std_logic_vector(tuser_size_g-1 downto 0)
    );
end axis_mux;

archicture rtl of axis_mux is
    
    signal input_s          : unsigned(select_input_i'length-1 downto 0) := (others => '0');
    
begin
    
    assert TIMETOUT_G >= 10 report "MINIMUM TIMEOUT IS 10" severity failure;
    
    round_robin_enable_gen: if round_robin_enable_g = true generate
        
        input_p: process(clk_i)
        begin
            if rising_edge(clk_i) then
                if rst_i = '1' then
                    input_s <= (others => '0');
                elsif (tvalid_s = '1' and tready_s = '1' and tlast_s = '1') or timeout_cnt = TIMEOUT_G-1 then
                    if input_s = num_ports_g-1 then
                        input_s <= (others => '0');
                    else
                        input_s <= input_s + 1;
                    end if;
                end if;
            end if;
        end process;
                
    end generate round_robin_enable_gen;
                
    switch_by_select_port_gen: if round_robin_enable_g = false generate
        
        input_p: process(clk_i)
        begin
            if rising_edge(clk_i) then
                if rst_i = '1' then
                    input_s <= (others => '0');
                elsif (tvalid_s = '1' and tready_s = '1' and tlast_s = '1') or timeout_cnt = TIMEOUT_G-1 then
                    input_s <= unsigned(select_input_i);
                end if;
            end if;
        end process;
                
    end generate switch_by_select_port_gen;
                
        timeout_p: process(clk_i)
        begin
            if rising_edge(clk_i) then
                if rst_i = '1' then
                    timeout_cnt <= (others => '0');
                elsif tvalid_s = '0' then
                    timeout_cnt <= timeout_cnt + 1;
                    if timeout_cnt = TIMEOUT_G-1 then
                        timeout_cnt <= (others => '0');
                    end if;
                end if;
            end if;
        end process;
                
    tvalid_s <= s_axis_tvalid(to_integer(input_s));
    tlast_s  <= s_axis_tlast(to_integer(input_s));
    tdata_s  <= s_axis_tdata(to_integer(input_s));
    tuser_s  <= s_axis_tuser(to_integer(input_s));
            
    tready_gen: for i in NUM_PORTS_G-1 downto 0 generate
        s_axis_tready(i) <= tready_s when i = input_s else '0';
    end generate tready_gen;
                
    -----------------------------------------------------------------
    -- Output Register
    -----------------------------------------------------------------
    output_register_u: entity axis_lib.axi_stream_register
        generic map(
            tdata_size_g            => s_axis_tdata'length,
            tuser_size_g            => s_axis_tuser'length
        )
        port map(
            clk_i                   => clk_i,
            rst_i                   => rst_i,
            --
            s_axis_tvalid_i         => tvalid_s,
            s_axis_tready_o         => tready_s,
            s_axis_tlast_i          => tlast_s,
            s_axis_tdata_i          => tdata_s,
            s_axis_tuser_i          => tuser_s,
            --
            m_axis_tvalid_o         => m_axis_tvalid_o,
            m_axis_tready_i         => m_axis_tready_i,
            m_axis_tlast_o          => m_axis_tlast_o,
            m_axis_tdata_o          => m_axis_tdata_o,
            m_axis_tuser_o          => m_axis_tuser_o
        );

end rtl;
       
