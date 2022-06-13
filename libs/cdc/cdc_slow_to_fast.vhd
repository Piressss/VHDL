library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
---------------------------------------------------------------------
entity cdc_slow_to_fast is
    port(
        clk_slow_i      : in  std_logic;
        clk_fast_i      : in  std_logic;
        --
        din_i           : in  std_logic;
        dout_o          : out std_logic
    );
end cdc_slow_to_fast;

architecture rtl of cdc_slow_to_fast is

    signal din_s                : std_logic;
    signal din_slow_to_fast_s   : std_logic;

begin


    din_p: process(clk_slow_i)
    begin
        if rising_edge(clk_slow_i) then
            din_s <= din_i;
        end if;
    end process;

    din_slow_to_fast_p: process(clk_fast_i)
    begin
        if rising_edge(clk_fast_i) then
            din_slow_to_fast_s <= din_s;
            dout_o             <= din_slow_to_fast_s;
        end if;
    end process;

end rtl;
