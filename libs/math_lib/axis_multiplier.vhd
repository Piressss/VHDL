---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 17/01/2019
-- @Lib   : AXIS LIB
-- @Code  : AXIS_MULTIPLIER
-- @brief : Multiplies two data input signals.
--          Signals if happened an overflow.
--          If the multiplier is power of 2, the result is achieved more fast.
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--
library axis_lib;
---------------------------------------------------------------------
entity axis_multiplier is
    generic(
        buffer_size_g           : integer := 1;      -- Number of bits to represent the maximum buffer address
        data_width_g            : integer := 1
    );
    port(
        clk_i                   : in  std_logic;
        rst_i                   : in  std_logic;
        --
        s_axis_tvalid_i     : in  std_logic;
        s_axis_tready_o     : out std_logic;
        s_axis_tlast_i      : in  std_logic;
        s_axis_tdata_i      : in  std_logic_vector(data_width_g-1 downto 0); -- Data to be multiplied
        s_axis_tuser_i      : in  std_logic_vector(data_width_g-1 downto 0); -- Multiplier
        --
        m_axis_tvalid_o     : out std_logic;
        m_axis_tready_i     : in  std_logic;
        m_axis_tlast_o      : out std_logic;
        m_axis_tdata_o      : out std_logic_vector(data_width_g-1 downto 0);
        overflow_o          : out std_logic
    );
end axis_multiplier;

architecture rtl of axis_multiplier is

    type tdata_t is array (natural range<>) of std_logic_vector(data_width_g-1 downto 0);

    function ref_gen_f(constant ref_size: integer) return tdata_t
        variable result : tdata_t(ref_size-1 downto 0);
    begin
        for i in ref_size-1 downto 0 loop
            result := std_logic_vector(to_unsigned(2**i,ref_size));
        end loop;
        return result;
    end function;

    constant ref_rom_c          : tdata_t(data_width_g-1 downto 0) := ref_gen_f(data_width_g);

begin

end rtl;
        
