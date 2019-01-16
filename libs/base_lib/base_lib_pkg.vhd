---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 27/12/2018
-- @Lib   : BASE LIB
-- @Code  : BASE_LIB_PKG
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
---------------------------------------------------------------------
package base_lib_pkg is

    -- TYPE VECTORS STD_LOGIC_VECTOR
    type bit1vec_t  is array (natural range<>) of std_logic_vector(0 downto 0);
    type bit12vec_t is array (natural range<>) of std_logic_vector(11 downto 0);
    type bit32vec_t is array (natural range<>) of std_logic_vector(31 downto 0);

    -- TYPE VECTORS UNSIGNED 
    type ubit1vec_t  is  array (natural range<>) of std_logic_vector(0 downto 0);
    type ubit12vec_t is  array (natural range<>) of std_logic_vector(11 downto 0);
    type ubit32vec_t is  array (natural range<>) of std_logic_vector(31 downto 0);

    -- Functions
    function vec_fit        (constant input : in integer) return integer;

end base_lib_pkg;
 
package body base_lib_pkg is

    -- Calculates the vector needed to represent the number
    -- - input:   integer we want to vectorize (must be positive)
    -- - output:  N (vector size)
    -- - What is done:
    --   - N = LOG2(input)
    --   - Round up only.
    function vec_fit    (constant input : in integer) return integer is
        variable tmp : integer;
        begin
            tmp := 1;
                if 2**tmp < input then
                    while 2**tmp < input loop
                        tmp := tmp + 1;
                    end loop;
                end if;
            return tmp;
    end vec_fit;
    
end base_lib_pkg;
