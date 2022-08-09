---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 29/07/2022
-- @Lib   : CORE LIB
-- @Code  : SENSOR_HC-SR04
-- @Description: -- Converts an AXI-Stream Master to AXI-L Slave
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library base_lib;
use base_lib.base_lib_pkg.all;
---------------------------------------------------------------------
entity axis_to_axil is
    generic(
        DATA_WIDTH_G        : integer := 1;
        ADDR_WIDTH_G        : integer := 1
    )
    port(
        s_axis_clk          : in  std_logic;
        s_axis_rstn         : in  std_logic;
        --
        s_axis_tvalid       : in  std_logic;
        s_axis_tready       : out std_logic;
        s_axis_tlast        : in  std_logic;
        s_axis_tdata        : in  std_logic_vector(DATA_WIDTH_G-1 downto 0);
        s_axis_tdest        : in  std_logic_vector(ADDR_WIDTH_G-1 downto 0);
        --
        m_axi_araddr        : out std_logic_vector(ADDR_WIDTH_G-1 downto 0);
        m_axi_arready       : in  std_logic;
        m_axi_arvalid       : out std_logic;
        m_axi_awaddr        : out std_logic_vector(ADDR_WIDTH_G-1 downto 0);
        m_axi_awready       : in  std_logic;
        m_axi_awvalid       : out std_logic;
        m_axi_bready        : out std_logic;
        m_axi_bvalid        : in  std_logic;
        m_axi_bresp         : in  std_logic_vector(1 downto 0);
        m_axi_rready        : out std_logic;
        m_axi_rvalid        : in  std_logic;
        m_axi_rdata         : in  std_logic_vector(DATA_WIDTH_G-1 downto 0);
        m_axi_rresp         : in  std_logic_vector(1 downto 0);
        m_axi_wdata         : out std_logic_vector(DATA_WIDTH_G-1 downto 0);
        m_axi_wvalid        : out std_logic;
        m_axi_wready        : in  std_logic;
        m_axi_wstrb         : out std_logic_vector(3 downto 0)
    );
end axis_to_axil;
