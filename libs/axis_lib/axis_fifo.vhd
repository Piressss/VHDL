---------------------------------------------------------------------
-- @Author: Felipe Pires
-- @Date  : 15/01/2019
-- @Lib   : AXIS LIB
-- @Code  : AXIS_FIFO
---------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--
library axis_lib;
--
library mem_lib;
---------------------------------------------------------------------
entity axis_fifo is
    generic(
        addr_width_g        : integer := 1;
        data_width_g        : integer := 1;
        user_width_g        : integer := 0;
        fifo_register_g     : boolean := false
    );
    port(
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
        --
        s_axis_tvalid_i     : in  std_logic;
        s_axis_tready_o     : out std_logic;
        s_axis_tlast_i      : in  std_logic;
        s_axis_tdata_i      : in  std_logic_vector(data_width_g-1 downto 0);
        s_axis_tuser_i      : in  std_logic_vector(user_width_g-1 downto 0) := (others => '0');
        --
        m_axis_tvalid_o     : out std_logic;
        m_axis_tready_i     : in  std_logic;
        m_axis_tlast_o      : out std_logic;
        m_axis_tdata_o      : out std_logic_vector(data_width_g-1 downto 0);
        m_axis_tuser_o      : out std_logic_vector(user_width_g-1 downto 0)
    );
end axis_fifo;

architecture rtl of axis_fifo is

    constant max_size_c     : integer := 2**addr_width_g;
    constant data_ram_c     : integer := data_width_g+user_width_g+1;

    type tdata_t is array (natural range<>) of std_logic_vector(data_width_g-1 downto 0);
    type tuser_t is array (natural range<>) of std_logic_vector(user_width_g-1 downto 0);

    signal tvalid_s         : std_logic_vector(1 downto 0) := (others => '0');
    signal tready_s         : std_logic_vector(1 downto 0) := (others => '0');
    signal tlast_s          : std_logic_vector(1 downto 0) := (others => '0');
    signal tdata_s          : tdata_t(1 downto 0) := (others => (others => '0'));
    signal tuser_s          : tuser_t(1 downto 0) := (others => (others => '0'));
    signal storage_cnt      : unsigned(addr_width_g-1 downto 0) := (others => '0');
    signal wr_opr_s         : std_logic := '0';
    signal rd_opr_s         : std_logic := '0';
    signal rd_en            : std_logic := '0';
    signal addr_wr_s        : unsigned(addr_width_g-1 downto 0) := (others => '0');
    signal addr_rd_s        : unsigned(addr_width_g-1 downto 0) := (others => '0');
    signal data_wr_s        : std_logic_vector(data_ram_c-1 downto 0) := (others => '0');
    signal data_rd_s        : std_logic_vector(data_ram_c-1 downto 0) := (others => '0');

begin

    -----------------------------------------------------------------
    -- Input Register
    -----------------------------------------------------------------
    input_register_u: entity axis_lib.axi_stream_register
        generic map(
            tdata_size_g            => data_width_g,
            tuser_size_g            => user_width_g
        )
        port map(
            clk_i                   => clk_i,
            rst_i                   => rst_i,
            --
            s_axis_tvalid_i         => s_axis_tvalid_i,
            s_axis_tready_o         => s_axis_tready_o,
            s_axis_tlast_i          => s_axis_tlast_i,
            s_axis_tdata_i          => s_axis_tdata_i,
            s_axis_tuser_i          => s_axis_tuser_i,
            --
            m_axis_tvalid_o         => tvalid_s(0),
            m_axis_tready_i         => tready_s(0),
            m_axis_tlast_o          => tlast_s(0),
            m_axis_tdata_o          => tdata_s(0),
            m_axis_tuser_o          => tuser_s(0)
        );

    -----------------------------------------------------------------
    -- RAM
    -----------------------------------------------------------------
    ram_u: entity mem_lib.ram
        generic map(
            data_width_g            => data_ram_c, 
            addr_width_g            => addr_width_g, 
            wr_register_enable_g    => fifo_register_g,
            rd_register_enable_g    => fifo_register_g
        )
        port map(
            clk_i                   => clk_i,
            rst_i                   => rst_i,
            --
            we_i                    => wr_opr_s,
            data_wr_i               => data_wr_s,
            addr_wr_i               => std_logic_vector(addr_wr_s),
            --
            re_i                    => rd_en,
            addr_rd_i               => std_logic_vector(addr_rd_s),
            data_valid_o            => tvalid_s(1),
            data_rd_o               => data_rd_s
        );
            
    no_user_gen: if user_width_g = 0 generate
        data_wr_s <= tlast_s(0) & tdata_s(0);

        tlast_s(1) <= data_rd_s(data_rd_s'high);
        tdata_s(1) <= data_rd_s(data_ram_c-2 downto 0);
    end generate;

    user_gen: if user_width_g > 0 generate
        data_wr_s <= tlast_s(0) & tuser_s(0) & tdata_s(0);

        tlast_s(1) <= data_rd_s(data_rd_s'high);
        tuser_s(1) <= data_rd_s(data_ram_c-2 downto data_width_g);
        tdata_s(1) <= data_rd_s(data_ram_c-2-user_width_g downto 0);
    end generate;
    -----------------------------------------------------------------
    -- Endereco de Escrita/Leitura 
    -----------------------------------------------------------------
        addr_wr_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if rst_i = '1' then
                    addr_wr_s <= (others => '0');
                elsif wr_opr_s = '1' then
                    addr_wr_s <= addr_wr_s + 1;
                end if;
            end if;
        end process;
        
        addr_rd_p: process(clk_i)
        begin
            if clk_i'event and clk_i = '1' then
                if rst_i = '1' then
                    addr_rd_s <= (others => '0');
                elsif rd_en = '1' then
                    addr_rd_s <= addr_rd_s + 1;
                end if;
            end if;
        end process;

    -----------------------------------------------------------------
    -- Contador de Ocupacao 
    -----------------------------------------------------------------
    wr_opr_s <= tvalid_s(0) and tready_s(0);
    rd_opr_s <= tvalid_s(1) and tready_s(1);

    storage_cnt_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if wr_opr_s = '1' and rd_en = '0' then
                storage_cnt <= storage_cnt + 1;
            elsif wr_opr_s = '0' and rd_en = '1' then
                storage_cnt <= storage_cnt - 1;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Controle de Escrita 
    -----------------------------------------------------------------
    tready_wr_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if rst_i = '1' then
                tready_s(0) <= '0';
            elsif storage_cnt > max_size_c - 3 then
                tready_s(0) <= '0';
            else
                tready_s(0) <= '1';
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------
    -- Controle de Leitura 
    -----------------------------------------------------------------
    rd_en_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if rst_i = '1' then
                rd_en <= '0';
            elsif storage_cnt > 1 then
                rd_en <= '1';
            elsif storage_cnt = 1 and rd_en = '1' then
                rd_en <= '0';
            else
                rd_en <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Output Register
    -----------------------------------------------------------------
    output_register_u: entity axis_lib.axi_stream_register
        generic map(
            tdata_size_g            => data_width_g,
            tuser_size_g            => user_width_g
        )
        port map(
            clk_i                   => clk_i,
            rst_i                   => rst_i,
            --
            s_axis_tvalid_i         => tvalid_s(1),
            s_axis_tready_o         => tready_s(1),
            s_axis_tlast_i          => tlast_s(1),
            s_axis_tdata_i          => tdata_s(1),
            s_axis_tuser_i          => tuser_s(1),
            --
            m_axis_tvalid_o         => m_axis_tvalid_o,
            m_axis_tready_i         => m_axis_tready_i,
            m_axis_tlast_o          => m_axis_tlast_o,
            m_axis_tdata_o          => m_axis_tdata_o,
            m_axis_tuser_o          => m_axis_tuser_o 
        );

end rtl;
        
