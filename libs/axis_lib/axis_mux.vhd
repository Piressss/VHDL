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
---------------------------------------------------------------------
entity axis_mux is
    generic(
        tdata_size_g        : integer := 1;
        tuser_size_g        : integer := 1;
        num_ports_g         : integer := 2;
        switch_by_tlast_g   : boolean := false;
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
    
begin
    
end rtl;
       
