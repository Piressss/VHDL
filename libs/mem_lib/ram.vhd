---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 15/01/2019
-- @Lib   : MEM LIB
-- @Code  : RAM
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
---------------------------------------------------------------------
entity ram is
    generic(
        data_width_g        : integer := 1;
        addr_width_g        : integer := 1;
        wr_register_enable_g: boolean := false; -- Register all write signals
        rd_register_enable_g: boolean := false  -- Register all read signals
    );
    port(
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
        -- Write Port
        we_i                : in  std_logic; -- Write Enable
        data_wr_i           : in  std_logic_vector(data_width_g-1 downto 0);
        addr_wr_i           : in  std_logic_vector(addr_width_g-1 downto 0);
        -- Read Port
        re_i                : in  std_logic; -- Read Enable
        addr_rd_i           : in  std_logic_vector(addr_width_g-1 downto 0);
        data_valid_o        : out std_logic;
        data_rd_o           : out std_logic_vector(data_width_g-1 downto 0)
    );
end ram;

architecture rtl of ram is 

    type ram_t is array (natural range<>) of std_logic_vector(data_width_g-1 downto 0);

    signal we_s             : std_logic := '0';
    signal re_s             : std_logic := '0';
    signal data_wr_s        : std_logic_vector(data_wr_i'length-1 downto 0) := (others => '0');
    signal addr_wr_s        : unsigned(addr_wr_i'length-1 downto 0) := (others => '0');
    signal addr_rd_s        : unsigned(addr_rd_i'length-1 downto 0) := (others => '0');
    signal data_valid_s     : std_logic := '0';
    signal data_rd_s        : std_logic_vector(data_rd_o'length-1 downto 0) := (others => '0');
    signal ram_data_s       : ram_t((2**addr_width_g)-1 downto 0) := (others => (others => '0'));

begin

    -----------------------------------------------------------------
    -- Register Write Signals
    -----------------------------------------------------------------
    no_wr_register_gen: if wr_register_enable_g = false generate
        we_s      <= we_i;
        data_wr_s <= data_wr_i;
        addr_wr_s <= unsigned(addr_wr_i);
    end generate;

    wr_register_gen: if wr_register_enable_g = true generate
        wr_register_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if rst_i = '1' then
                    we_s      <= '0';
                else
                    we_s      <= we_i;
                    data_wr_s <= data_wr_i;
                    addr_wr_s <= unsigned(addr_wr_i);
                end if;
            end if;
        end process;
    end generate;
   
    -----------------------------------------------------------------
    -- Write Port
    -----------------------------------------------------------------
    write_data_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if rst_i = '1' then
                ram_data_s <= (others => (others => '0'));
            elsif we_s = '1' then
                ram_data_s(to_integer(addr_wr_s)) <= data_wr_s;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Register Read Signals
    -----------------------------------------------------------------
    no_rd_register_gen: if rd_register_enable_g = false generate
        re_s         <= re_i;
        data_valid_o <= data_valid_s;
        data_rd_o    <= data_rd_s;
        addr_rd_s    <= unsigned(addr_rd_i);
    end generate;

    rd_register_gen: if rd_register_enable_g = true generate
        rd_register_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if rst_i = '1' then
                    re_s         <= '0';
                    data_valid_o <= '0'; 
                    data_rd_o    <= (others => '0'); 
                else
                    re_s         <= re_i;
                    data_valid_o <= data_valid_s;
                    data_rd_o    <= data_rd_s;
                    addr_rd_s    <= unsigned(addr_rd_i);
                end if;
            end if;
        end process;
    end generate;

    -----------------------------------------------------------------
    -- Read Port
    -----------------------------------------------------------------
    read_data_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if rst_i = '1' then
                data_valid_s <= '0';
                data_rd_s <= (others => '0');
            elsif re_s = '1' then
                data_valid_s <= '1';
                data_rd_s <= ram_data_s(to_integer(addr_rd_s));
            else
                data_valid_s <= '0';
                data_rd_s <= (others => '0');
            end if;
        end if;
    end process;

end rtl;
        
