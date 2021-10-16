---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 16/10/2021
-- @Lib   : FIFO LIB
-- @Code  : FIFO_SINGLE
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library mem_lib;
library base_lib;
use base_lib.base_lib_pkg.all;
---------------------------------------------------------------------
entity fifo_single is
    generic(
        FIFO_DEPTH_G        : integer := 2;
        DATA_WIDTH_G        : integer := 1
    );
    port(
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
        --
        we_i                : in  std_logic; -- Write Enable
        data_wr_i           : in  std_logic_vector(data_width_g-1 downto 0);
        --
        re_i                : in  std_logic; -- Read Enable
        data_valid_o        : out std_logic;
        data_rd_o           : out std_logic_vector(data_width_g-1 downto 0);
        --
        overflow_o          : out std_logic;
        underflow_o         : out std_logic
    );
end fifo_single;

architecture rtl of fifo_single is
    
    signal data_cnt         : unsigned(vec_fit(FIFO_DEPTH_G)-1 downto 0) := (others => '0');
    
begin
    
    -- Counter the number of valid words
    data_cnt_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                data_cnt <= (others => '0');
            elsif we_i = '1' and re_i = '0' then
                data_cnt <= data_cnt + 1;
            elsif we_i = '0' and re_i = '1' then
                data_cnt <= data_cnt - 1;
            end if;
        end if;
    end process;
            
    -- Check Overflow
    overFlow_p: process(clk_i)
    being
        if rising_edge(clk_i) then
            if rst_i = '1' then
                overflow_o <= '0';
            elsif we_i = '1' and re_i = '0' and data_cnt = FIFO_DEPTH_G-1 then
                overflow_o <= '1';
            else
                overflow_o <= '0';
            end if;
        end if;
    end process;
            
    -- Check Underflow
    underFlow_p: process(clk_i)
    being
        if rising_edge(clk_i) then
            if rst_i = '1' then
                underflow_o <= '0';
            elsif we_i = '0' and re_i = '1' and data_cnt = 0 then
                underflow_o <= '1';
            else
                underflow_o <= '0';
            end if;
        end if;
    end process;
            
    -- Memory
    mem_u: entity mem_lib.ram
        generic map(
            data_width_g        => data_width_g,
            addr_width_g        => vec_fit(FIFO_DEPTH_G),
            wr_register_enable_g=> true,
            rd_register_enable_g=> true
        )
        port map(
            clk_i               => clk_i,
            rst_i               => rst_i,
            --
            we_i                => we_i,
            data_wr_i           => data_wr_i,
            addr_wr_i           => ,
            --
    
end rtl;
