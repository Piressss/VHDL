---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 27/07/2022
-- @Lib   : CORE LIB
-- @Code  : SENSOR_HC-SR04
-- @Description: Implements a core to read ultrasonic sensor,
--               from the DHT11 Sensor, providing the result as an
--               AXI Stream master interface.
--               The AXI-Stream send a package with 1 valid data words.
--               The data represents the distance measured in cm.
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library base_lib;
use base_lib.base_lib_pkg.all;
---------------------------------------------------------------------
entity sensor_hd_sr04 is
    port(
        clk_50m_i       : in  std_logic;
        rstn_i          : in  std_logic;
        trig_en_i       : in  std_logic;
        -- HC-SR04
        trig_o          : out std_logic;
        echo_i          : in  std_logic;
        ctrl_mq_o       : out std_logic_vector(4 downto 0);
        --
        m_axis_tvalid   : out std_logic;
        m_axis_tready   : in  std_logic;
        m_axis_tlast    : out std_logic;
        m_axis_tdata    : out std_logic_vector(15 downto 0)
    );
end sensor_hd_sr04;

architecture rtl of sensor_hd_sr04 is
    
    ATTRIBUTE X_INTERFACE_INFO: string;
    ATTRIBUTE X_INTERFACE_INFO of m_axis_tvalid: SIGNAL is "xilinx.com:interface:axis:1.0 m_axis TVALID";
    ATTRIBUTE X_INTERFACE_INFO of m_axis_tready: SIGNAL is "xilinx.com:interface:axis:1.0 m_axis TREADY";
    ATTRIBUTE X_INTERFACE_INFO of m_axis_tlast:  SIGNAL is "xilinx.com:interface:axis:1.0 m_axis TLAST";
    ATTRIBUTE X_INTERFACE_INFO of m_axis_tdata:  SIGNAL is "xilinx.com:interface:axis:1.0 m_axis TDATA";
    ATTRIBUTE X_INTERFACE_INFO of clk_50m_i:     SIGNAL is "xilinx.com:signal:clock:1.0 clk_50m_i CLK";
    ATTRIBUTE X_INTERFACE_INFO of rstn_i:        SIGNAL is "xilinx.com:signal:reset:1.0 rstn_i RST";
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER of clk_50m_i: SIGNAL is "ASSOCIATED_BUSIF m_axis, ASSOCIATED_RESET rstn_i";
    ATTRIBUTE X_INTERFACE_PARAMETER of rstn_i:    SIGNAL is "POLARITY ACTIVE_LOW";

    constant CLK_PER_NS_C       : integer := 20;
    constant TRIGGER_CNT_C      : integer := 600; -- > (10us / 20ns)
    constant WAIT_CNT_C         : integer := 3000000; -- 55ms / 20ns
    constant ONE_US_CNT_C       : integer := 50; -- 1us / 20ns
    constant DIVISOR_C          : integer := 58;
    constant DIVISOR_64_C       : integer := 64;
    constant DIVISOR_256_C      : integer := 256;
    constant TIMEOUT_C          : integer := 1250000; -- 25us / 20ns


    type ctrl_mq_t is (idle_st, trigger_st, echo_st, send_st, calc_st);

    signal ctrl_mq          : ctrl_mq_t := idle_st;
    signal rst_s            : std_logic;
    signal wait_ok_s        : std_logic;
    signal wait_cnt         : unsigned(vec_fit(WAIT_CNT_C)-1 downto 0);
    signal trigger_ok_s     : std_logic;
    signal trigger_cnt      : unsigned(vec_fit(TRIGGER_CNT_C)-1 downto 0);
    signal det_dn_s         : std_logic;
    signal echo_cnt         : unsigned(vec_fit(ONE_US_CNT_C)-1 downto 0);
    signal echo_us_cnt      : unsigned(15 downto 0);
    signal dist_div0_s      : unsigned(15 downto 0);
    signal dist_div1_s      : unsigned(15 downto 0);
    signal dist_div_s       : unsigned(15 downto 0);
    signal dist_cm_s        : std_logic_vector(15 downto 0);
    signal delay_s          : std_logic_vector(1 downto 0);
    signal tvalid_s         : std_logic;
    signal echo_reg_s       : std_logic;
    signal timeout_cnt      : unsigned(vec_fit(TIMEOUT_C)-1 downto 0);
    signal timeout_ack_s    : std_logic;

begin

    rst_s <= not rstn_i;

    -----------------------------------------------------------------
    -- CTRL MQ
    -----------------------------------------------------------------
    ctrl_mq_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                ctrl_mq <= idle_st;
            else
                case ctrl_mq is
                    when idle_st =>
                        if wait_ok_s = '1' and trig_en_i = '1' then
                            ctrl_mq <= trigger_st;
                        end if;
                    when trigger_st =>
                        if trigger_ok_s = '1' then
                            ctrl_mq <= echo_st;
                        end if;
                    when echo_st =>
                        if det_dn_s = '1' then
                            ctrl_mq <= calc_st;
                        elsif timeout_ack_s = '1' then
                            ctrl_mq <= idle_st;
                        end if;
                    when calc_st =>
                        if delay_s = "11" then
                            ctrl_mq <= send_st;
                        end if;
                    when send_st =>
                        if tvalid_s = '1' and m_axis_tready = '1' then
                            ctrl_mq <= idle_st;
                        end if;
                end case;
            end if;
        end if;
    end process;

    trig_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if ctrl_mq = trigger_st then
                trig_o <= '1';
            else
                trig_o <= '0';
            end if;
        end if;
    end process;

    ctrl_mq_out_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if ctrl_mq = idle_st then
                ctrl_mq_o <= "00001";
            elsif ctrl_mq = trigger_st then
                ctrl_mq_o <= "00010";
            elsif ctrl_mq = echo_st then
                ctrl_mq_o <= "00100";
            elsif ctrl_mq = calc_st then
                ctrl_mq_o <= "01000";
            elsif ctrl_mq = send_st then
                ctrl_mq_o <= "10000";
            end if;
        end if;
    end process;

    
    -----------------------------------------------------------------
    -- WAIT COUNTER
    -----------------------------------------------------------------
    wait_cnt_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                wait_cnt <= (others => '0');
            elsif ctrl_mq = idle_st then
                wait_cnt <= wait_cnt + 1;
            else
                wait_cnt <= (others => '0');
            end if;
        end if;
    end process;

    wait_ok_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                wait_ok_s <= '0';
            elsif wait_cnt = WAIT_CNT_C - 1 then
                wait_ok_s <= '1';
            elsif trig_en_i = '1' then
                wait_ok_s <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- TRIGGER COUNTER
    -----------------------------------------------------------------
    trigger_cnt_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                trigger_cnt <= (others => '0');
            elsif ctrl_mq = trigger_st then
                trigger_cnt <= trigger_cnt + 1;
            else
                trigger_cnt <= (others => '0');
            end if;
        end if;
    end process;

    trigger_ok_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                trigger_ok_s <= '0';
            elsif trigger_cnt = TRIGGER_CNT_C-1 then
                trigger_ok_s <= '1';
            else
                trigger_ok_s <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Det Down
    -----------------------------------------------------------------
    det_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            echo_reg_s <= echo_i;
            if rstn_i = '0' then
                det_dn_s <= '0';
            else
                if echo_i = '0' and echo_reg_s = '1' then
                    det_dn_s <= '1';
                else
                    det_dn_s <= '0';
                end if;
            end if;
        end if;
    end process;

    timeout_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                timeout_cnt <= (others => '0');
            elsif ctrl_mq = echo_st then
                timeout_cnt <= timeout_cnt + 1;
            else
                timeout_cnt <= (others => '0');
            end if;
        end if;
    end process;

    timeout_ack_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                timeout_ack_s <= '0';
            elsif timeout_cnt = TIMEOUT_C-1 then
                timeout_ack_s <= '1';
            else
                timeout_ack_s <= '0';
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------
    -- ECHO COUNTER
    -----------------------------------------------------------------
    echo_cnt_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                echo_cnt <= (others => '0');
            elsif ctrl_mq = idle_st then
                echo_cnt <= (others => '0');
            elsif echo_i = '1' and ctrl_mq = echo_st then
                if echo_cnt = ONE_US_CNT_C-1 then
                    echo_cnt <= (others => '0');
                else
                    echo_cnt <= echo_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    echo_us_cnt_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                echo_us_cnt <= (others => '0');
            elsif ctrl_mq = idle_st then
                echo_us_cnt <= (others => '0');
            elsif echo_i = '1' and ctrl_mq = echo_st and echo_cnt = ONE_US_CNT_C-1 then
                echo_us_cnt <= echo_us_cnt + 1;
            end if;
        end if;
    end process;

    -- The Maximum lost expected represents 980ns = 0.01689 cm
    
    -----------------------------------------------------------------
    -- COMPUTE DISTANCE
    -----------------------------------------------------------------
    -- the initial equation is: cm = us / 58
    -- will implement a new equation: cm = (us / 64) + (us / 256)
    -- the result will have a dif of +1.95%
    dist_div_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                dist_div0_s <= (others => '0');
                dist_div1_s <= (others => '0');
                dist_div_s <= (others => '0');
            elsif ctrl_mq = calc_st then
                dist_div0_s <= "000000" & echo_us_cnt(15 downto 6);
                dist_div1_s <= "00000000000" & echo_us_cnt(15 downto 11);
                dist_div_s  <= dist_div0_s + dist_div1_s;
            end if;
        end if;
    end process;

    -- delay to div operation
    delay_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                delay_s <= (others => '0');
            elsif ctrl_mq = calc_st then
                delay_s <= delay_s(0) & '1';
            else
                delay_s <= (others => '0');
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------
    -- SEND DATA
    -----------------------------------------------------------------
    m_axis_tvalid_p: process(clk_50m_i)
    begin
        if rising_edge(clk_50m_i) then
            if rstn_i = '0' then
                tvalid_s <= '0';
                m_axis_tlast <= '0';
                m_axis_tdata <= (others => '0');
            elsif ctrl_mq = send_st then
                if tvalid_s = '0' then
                    tvalid_s <= '1';
                    m_axis_tlast <= '1';
                    m_axis_tdata <= std_logic_vector(dist_div_s);
                elsif m_axis_tready = '1' then
                    tvalid_s <= '0';
                    m_axis_tlast <= '0';
                    m_axis_tdata <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    m_axis_tvalid <= tvalid_s;

end rtl;
