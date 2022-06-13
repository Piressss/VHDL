library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
---------------------------------------------------------------------
entity cdc_fast_to_slow is
    port(
        clk_fast_i      : in  std_logic;
        clk_slow_i      : in  std_logic;
        --
        din_i           : in  std_logic;
        dout_o          : out std_logic
    );
end cdc_fast_to_slow;

architecture rtl of cdc_fast_to_slow is

    signal din_dl_s     : std_logic;
    signal din_up_s     : std_logic;
    signal ack_det_up_s : std_logic;
    signal det_up_cdc_s : std_logic;

begin

    -- Det Up
    din_up_p: process(clk_fast_i)
        variable din_dl_v : std_logic;
    begin
        if rising_edge(clk_fast_i) then
            if din_i = '1' and din_dl_s = '0' then
                din_up_s <= '1';
            elsif din_i = '0' and din_dl_s = '1' then
                din_up_s <= '0';
            end if;
        end if;
    end process;

    din_dl_p: process(clk_fast_i)
    begin
        if rising_edge(clk_fast_i) then
            din_dl_s <= din_i;
        end if;
    end process;

    -- Cross Det Up
    det_up_cdc_p: process(clk_slow_i)
    begin
        if rising_edge(clk_slow_i) then
            det_up_cdc_s <= din_up_s;
        end if;
    end process;

    -- Dout
    dout_p: process(clk_slow_i)
    begin
        if rising_edge(clk_slow_i) then
            dout_o <= det_up_cdc_s;
        end if;
    end process;

end rtl;
