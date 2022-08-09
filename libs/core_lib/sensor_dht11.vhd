---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 25/07/2022
-- @Lib   : CORE LIB
-- @Code  : SENSOR_DHT11
-- @Description: Implements a core to read temperature and humidity,
--               from the DHT11 Sensor, providing the result as an
--               AXI Stream master interface.
--               The AXI-Stream send a package with 2 valid data words.
--               The first one represents the humidity and second the
--               temperature.
--               The sensor checksum is validated internally, in case 
--               of a invalid transfer from the sensor, the data will not
--               send to the AXI-Stream interface.
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library base_lib;
use base_lib.base_lib_pkg.all;
---------------------------------------------------------------------
entity sensor_dht11 is
    generic(
        CLK_FREQ_MHZ_G      : integer := 100
    );
    port(
        clk_i               : in  std_logic;
        rstn_i              : in  std_logic;
        --
        req_read_i          : in  std_logic;    -- Set '1' to enable 1 read operation
        -- IO Ctrl
        IO_input_i          : in  std_logic;
        OI_output_o         : out std_logic;
        IO_3state_o         : out std_logic;    -- Set Input when '1', set Output when '0'
        -- AXI-Stream
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : out std_logic;
        m_axis_tlast        : out std_logic;
        m_axis_tdata        : out std_logic_vector(15 downto 0)
    );
end sensor_dht11;

architecture rtl of sensor_dht11 is

    -- FUNCTIONS
    function clk_per_f return time is
        variable result_v : time;
    begin
        result_v := (1000/CLK_FREQ_MHZ_G) * 1 ns;
        return result_v;
    end function;

    -- CONSTANTS
    constant TIME_BEFORE_INIT_C     : time := 1000 ms;
    constant HOST_START_TIME_C      : time := 18 ms;
    constant SLAVE_START_TIME_C     : time := 80 us;
    constant BIT_LOW_TIME_C         : time := 50 us;
    constant BIT_HIGH_0_TIME_C      : time := 27 us;
    constant BIT_HIGH_1_TIME_C      : time := 70 us;

    constant CLK_PER_C              : time := clk_per_f;
    constant CYCLES_BEFORE_INIT_C   : integer := integer(TIME_BEFORE_INIT_C/CLK_PER_C);
    constant CYCLES_HOST_START_C    : integer := integer(HOST_START_TIME_C /CLK_PER_C);
    constant CYCLES_SLAVE_START_C   : integer := integer(SLAVE_START_TIME_C/CLK_PER_C);
    constant CYCLES_BIT_LOW_C       : integer := integer(BIT_LOW_TIME_C    /CLK_PER_C);
    constant CYCLES_BIT_HIGH_0_C    : integer := integer(BIT_HIGH_0_TIME_C /CLK_PER_C);
    constant CYCLES_BIT_HIGH_1_C    : integer := integer(BIT_HIGH_1_TIME_C /CLK_PER_C);
    constant BITS_EXPECTED_C        : integer := 40;

    -- SIGNALS
    type ctrl_mq_t is (wait_power_on_st, idle_st, host_st, slave_st, error_st, send_st);
    type slave_mq_t is (idle_st, start_st, data_st, error_st, ready_st);

    signal ctrl_mq                  : ctrl_mq_t := wait_power_on_st;
    signal slave_mq                 : slave_mq_t := idle_st;
    signal counter_s                : unsigned(vec_fit(CYCLES_BEFORE_INIT_C)-1 downto 0);
    signal wait_power_on_ack_s      : std_logic := '0';
    signal wait_host_start_ack_s    : std_logic := '0';
    signal wait_slave_start_ack_s   : std_logic_vector(1 downto 0);
    signal wait_data_low_ack_s      : std_logic;
    signal wait_data_high_ack_s     : std_logic;
    signal det_up_s                 : std_logic;
    signal det_dn_s                 : std_logic;
    signal IO_reg_s                 : std_logic;
    signal slave_start_err_s        : std_logic;
    signal slave_data_err_s         : std_logic;
    signal data_cnt                 : unsigned(vec_fit(BITS_EXPECTED_C)-1 downto 0);

begin

    -----------------------------------------------------------------
    -- Ctrl Machine
    -----------------------------------------------------------------
    ctrl_mq_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                ctrl_mq <= wait_power_on_st;
            else
                case ctrl_mq is 
                    when wait_power_on_st =>
                        if wait_power_on_ack_s = '1' then
                            ctrl_mq <= idle_st;
                        end if;
                    when idle_st =>
                        if req_read_i = '1' then
                            ctrl_mq <= host_st;
                        end if;
                    when host_st =>
                        if wait_host_start_ack_s = '1' then
                            ctrl_mq <= slave_st;
                        end if;
                    when slave_st =>
                        if slave_mq = ready_st or slave_mq = error_st then
                            ctrl_mq <= idle_st;
                        end if;
                    when error_st =>
                        ctrl_mq <= idle_st;
                    when send_st =>
                        if m_axis_tvalid = '1' and m_axis_tready = '1' and m_axis_tlast = '1' then
                            ctrl_mq <= idle_st;
                        end if;
                end case;
            end if;
        end if;
    end process;

    slave_mq_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                slave_mq <= idle_st;
            else
                case slave_mq is
                    when idle_st =>
                        if ctrl_mq = slave_st then
                            slave_mq <= start_st;
                        end if;
                    when start_st =>
                        if wait_slave_start_ack_s = "11" then
                            slave_mq <= data_st;
                        elsif slave_start_err_s = '1' then
                            slave_mq <= error_st;
                        end if;
                    when data_st =>
                        if slave_data_err_s = '1' then
                            slave_mq <= error_st;
                        elsif wait_data_high_ack_s = '1' and data_cnt = BITS_EXPECTED_C-1 then
                            slave_mq <= idle_st;
                        end if;
                    when error_st =>
                        slave_mq <= idle_st;
                end case;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Counter
    -----------------------------------------------------------------
    Counter_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                counter_s <= (others => '0');
            elsif wait_power_on_ack_s = '1' then
                counter_s <= (others => '0');
            elsif wait_host_start_ack_s = '1' then
                counter_s <= (others => '0');
            elsif det_up_s = '1' and wait_slave_start_ack_s = "00" then
                counter_s <= (others => '0');
            elsif det_dn_s = '1' and wait_slave_start_ack_s = "01" then
                counter_s <= (others => '0');
            elsif wait_data_low_ack_s = '1' then
                counter_s <= (others => '0');
            elsif wait_data_high_ack_s = '1' then
                counter_s <= (others => '0');
            elsif slave_start_err_s = '1' then
                counter_s <= (others => '0');
            elsif slave_data_err_s = '1' then
                counter_s <= (others => '0');
            end if;
        end if;
    end process;


    wait_power_on_ack_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                wait_power_on_ack_s <= '0';
            elsif ctrl_mq = wait_power_on_st and counter_s = CYCLES_BEFORE_INIT_C-1 then
                wait_power_on_ack_s <= '1';
            else
                wait_power_on_ack_s <= '0';
            end if;
        end if;
    end process;

    wait_host_start_ack_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                wait_host_start_ack_s <= '0';
            elsif ctrl_mq = host_st and counter_s = CYCLES_HOST_START_C-1 then
                wait_host_start_ack_s <= '1';
            else
                wait_host_start_ack_s <= '0';
            end if;
        end if;
    end process;

    wait_slave_start_ack_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                wait_slave_start_ack_s <= (others => '0');
            elsif slave_mq = start_st and (det_up_s = '1' or det_dn_s = '1') and counter_s = CYCLES_SLAVE_START_C-1 then
                wait_slave_start_ack_s <= wait_slave_start_ack_s(0) & '1';
            elsif ctrl_mq /= slave_st then
                wait_slave_start_ack_s <= (others => '0');
            end if;
        end if;
    end process;

    slave_start_err_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                slave_start_err_s <= '0';
            elsif ctrl_mq = slave_st and wait_slave_start_ack_s /= "11" and counter_s = (CYCLES_SLAVE_START_C*2)-1 then
                slave_start_err_s <= '1';
            else
                slave_start_err_s <= '0';
            end if;
        end if;
    end process;

    wait_data_low_ack_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                wait_data_low_ack_s <= '0';
            elsif slave_mq = data_st then
                if det_up_s = '1' and counter_s = CYCLES_BIT_LOW_C-1 then
                    wait_data_low_ack_s <= '1';
                else
                    wait_data_low_ack_s <= '0';
                end if;
            else
                wait_data_low_ack_s <= '0';
            end if;
        end if;
    end process;

    wait_data_high_ack_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                wait_data_high_ack_s <= '0';
            elsif slave_mq = data_st then 
                if det_dn_s = '1' and (counter_s = CYCLES_BIT_HIGH_0_C-1 or counter_s = CYCLES_BIT_HIGH_1_C-1) then
                    wait_data_high_ack_s <= '1';
                else
                    wait_data_high_ack_s <= '0';
                end if;
            else
                wait_data_high_ack_s <= '0';
            end if;
        end if;
    end process;

    slave_data_err_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                slave_data_err_s <= '0';
            elsif slave_mq = data_st then
                if counter_s > (CYCLES_BIT_LOW_C + CYCLES_BIT_HIGH_1_C) then
                    slave_data_err_s <= '1';
                end if;
            else
                slave_data_err_s <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Det Up/Down
    -----------------------------------------------------------------
    det_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            IO_reg_s <= IO_input_i;

            if rstn_i = '0' then
                det_up_s <= '0';
                det_dn_s <= '0';
            else
                if IO_input_i = '0' and IO_reg_s = '1' then
                    det_dn_s <= '1';
                else
                    det_dn_s <= '0';
                end if;

                if IO_input_i = '1' and IO_reg_s = '0' then
                    det_up_s <= '1';
                else
                    det_up_s <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------
    -- Data Counter
    -----------------------------------------------------------------
    data_cnt_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                data_cnt <= (others => '0');
            elsif slave_mq = data_st then
                if wait_data_high_ack_s = '1' then
                    data_cnt <= data_cnt + 1;
                end if;
            else
                data_cnt <= (others => '0');
            end if;
        end if;
    end process;


end rtl;
