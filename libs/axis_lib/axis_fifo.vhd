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
    type buffer_t is array (natural range<>) of std_logic_vector(data_ram_c-1 downto 0);

    signal tvalid_s         : std_logic_vector(1 downto 0) := (others => '0');
    signal tready_s         : std_logic_vector(1 downto 0) := (others => '0');
    signal tlast_s          : std_logic_vector(1 downto 0) := (others => '0');
    signal tdata_s          : tdata_t(1 downto 0) := (others => (others => '0'));
    signal tuser_s          : tuser_t(1 downto 0) := (others => (others => '0'));
    signal storage_cnt      : unsigned(addr_width_g-1 downto 0) := (others => '0');
    signal wr_opr_s         : std_logic := '0';
    signal rd_opr_s         : std_logic := '0';
    signal rd_en            : std_logic := '0';
    signal rd_en_async_s    : std_logic := '0';
    signal addr_wr_s        : unsigned(addr_width_g-1 downto 0) := (others => '0');
    signal addr_rd_s        : unsigned(addr_width_g-1 downto 0) := (others => '0');
    signal data_wr_s        : std_logic_vector(data_ram_c-1 downto 0) := (others => '0');
    signal data_rd_s        : std_logic_vector(data_ram_c-1 downto 0) := (others => '0');
    signal buffer_en        : std_logic := '0';
    signal buffer_cnt       : unsigned(1 downto 0) := (others => '0');
    signal data_valid_s     : std_logic := '0';
    signal buffer_wr_s      : unsigned(1 downto 0) := (others => '0');
    signal buffer_rd_s      : unsigned(1 downto 0) := (others => '0');
    signal buffer_s         : buffer_t(3 downto 0) := (others => (others => '0'));

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
            re_i                    => rd_opr_s,
            addr_rd_i               => std_logic_vector(addr_rd_s),
            data_valid_o            => data_valid_s,
            data_rd_o               => data_rd_s
        );
            
    no_user_gen: if user_width_g = 0 generate
        data_wr_s <= tlast_s(0) & tdata_s(0);

        --tlast_s(1) <= data_rd_s(data_rd_s'high) when buffer_en = '0' else
        --              buffer_0_s(buffer_0_s'high) when buffer_rd_s = '0' else
        --              buffer_1_s(buffer_1_s'high) when buffer_rd_s = '1' else
        --              '0';
        tlast_s(1) <= buffer_s(to_integer(buffer_rd_s))(data_ram_c-1);

        --tdata_s(1) <= data_rd_s(data_ram_c-2 downto 0) when buffer_en = '0' else
        --              buffer_0_s(data_ram_c-2 downto 0) when buffer_rd_s = '0' else
        --              buffer_1_s(data_ram_c-2 downto 0) when buffer_rd_s = '1' else
        --              (others => '0');
        tdata_s(1) <= buffer_s(to_integer(buffer_rd_s))(data_ram_c-2 downto 0);

    end generate;

    user_gen: if user_width_g > 0 generate
        data_wr_s <= tlast_s(0) & tuser_s(0) & tdata_s(0);

        --tlast_s(1) <= data_rd_s(data_rd_s'high) when buffer_en = '0' else
        --              buffer_0_s(buffer_0_s'high) when buffer_rd_s = '0' else
        --              buffer_1_s(buffer_1_s'high) when buffer_rd_s = '1' else
        --              '0';
        tlast_s(1) <= buffer_s(to_integer(buffer_rd_s))(data_ram_c-1);

        --tuser_s(1) <= data_rd_s(data_ram_c-2 downto data_width_g) when buffer_en = '0' else
        --              buffer_0_s(data_ram_c-2 downto data_width_g) when buffer_rd_s = '0' else
        --              buffer_1_s(data_ram_c-2 downto data_width_g) when buffer_rd_s = '1' else
        --              (others => '0');
        tuser_s(1) <= buffer_s(to_integer(buffer_rd_s))(data_ram_c-2 downto data_width_g);

        --tdata_s(1) <= data_rd_s(data_ram_c-2-user_width_g downto 0) when buffer_en = '0' else
        --              buffer_0_s(data_ram_c-2-user_width_g downto 0) when buffer_rd_s = '0' else
        --              buffer_1_s(data_ram_c-2-user_width_g downto 0) when buffer_rd_s = '1' else
        --              (others => '0');
        tdata_s(1) <= buffer_s(to_integer(buffer_rd_s))(data_ram_c-2-user_width_g downto 0);
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
                elsif rd_opr_s = '1' then
                    addr_rd_s <= addr_rd_s + 1;
                end if;
            end if;
        end process;

    -----------------------------------------------------------------
    -- Contador de Ocupacao 
    -----------------------------------------------------------------
    wr_opr_s <= tvalid_s(0) and tready_s(0);
    rd_opr_s <= rd_en and rd_en_async_s;

    storage_cnt_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if wr_opr_s = '1' and rd_opr_s = '0' then
                storage_cnt <= storage_cnt + 1;
            elsif wr_opr_s = '0' and rd_opr_s = '1' then
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

    rd_en_async_s <= '0' when tvalid_s(1) = '1' and tready_s(1) = '0' else 
                     '0' when m_axis_tvalid_o = '1' and m_axis_tready_i = '0' else
                     '0' when buffer_cnt = 3 else
                     --'0' when data_valid_s = '1' and buffer_en = '1' else
                     '1';
    
    -----------------------------------------------------------------
    -- Controle de Leitura 
    -----------------------------------------------------------------
    rd_en_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if rst_i = '1' then
                rd_en <= '0';
            elsif storage_cnt > 0 then
                rd_en <= '1';
            elsif storage_cnt = 0 and wr_opr_s = '1' then
                rd_en <= '1';
            else
                rd_en <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Buffer 
    -----------------------------------------------------------------
    buffer_en_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if rst_i = '1' then
                buffer_en <= '0';
            --elsif data_valid_s = '1' and tready_s(1) = '0' then
            --    buffer_en <= '1';
            --elsif data_valid_s = '0' and buffer_en = '1' and tready_s(1) = '1' and buffer_cnt = 1 then
            --    buffer_en <= '0';
            elsif data_valid_s = '1' then
                buffer_en <= '1';
            elsif buffer_en = '1' and tready_s(1) = '1' then
                if buffer_cnt = 1 then
                    buffer_en <= '0';
                end if;
            end if;
        end if;
    end process;

    buffer_cnt_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if rst_i = '1' then
                buffer_cnt <= (others => '0');
            --elsif data_valid_s = '1' and tready_s(1) = '0' then
            --    buffer_cnt <= buffer_cnt + 1;
            --elsif data_valid_s = '0' and tready_s(1) = '1' and buffer_en = '1' then
            --    buffer_cnt <= buffer_cnt - 1;
            elsif data_valid_s = '1' then
                if buffer_en = '1' and tready_s(1) = '0' then
                    buffer_cnt <= buffer_cnt + 1;
                elsif buffer_en = '0' then
                    buffer_cnt <= buffer_cnt + 1;
                end if;
            else
                if buffer_en = '1' and tready_s(1) = '1' then
                    buffer_cnt <= buffer_cnt - 1;
                end if;
            end if;
        end if;
    end process;

    buffer_wr_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if data_valid_s = '1' then
                buffer_wr_s <= buffer_wr_s + 1;
            end if;
        end if;
    end process;

    buffer_rd_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            if tvalid_s(1) = '1' and tready_s(1) = '1' then
                buffer_rd_s <= buffer_rd_s + 1;
            end if;
        end if;
    end process;

    buffer_p: process(clk_i)
    begin
        if clk_i'event and clk_i = '1' then
            --if data_valid_s = '1' and (tready_s(1) = '0' or buffer_en = '1') then
            --    if buffer_cnt = 0 or buffer_cnt = 2 then
            --        buffer_0_s <= data_rd_s;
            --    elsif buffer_cnt = 1 then
            --        if buffer_rd_s = '0' then
            --            buffer_1_s <= data_rd_s;
            --        else
            --            buffer_0_s <= data_rd_s;
            --        end if;
            --    end if;
            --end if;
            if data_valid_s = '1' then
                buffer_s(to_integer(buffer_wr_s)) <= data_rd_s;
            end if;
        end if;
    end process;

   -- tvalid_s(1) <= data_valid_s or buffer_en;
    tvalid_s(1) <= buffer_en;

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
        
