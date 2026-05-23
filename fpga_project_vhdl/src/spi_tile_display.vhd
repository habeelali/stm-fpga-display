library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

entity spi_tile_display is
    generic (
        SVO_MODE           : svo_mode_t := M_640x480V;
        SVO_BITS_PER_PIXEL : integer    := 24;
        ENABLE_DEBUG       : boolean    := false
    );
    port (
        clk             : in  std_logic;
        resetn          : in  std_logic;
        spi_sclk        : in  std_logic;
        spi_cs_n        : in  std_logic;
        spi_mosi        : in  std_logic;
        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        out_axis_tuser  : out std_logic_vector(0 downto 0);
        dbg_map_addr    : in  std_logic_vector(10 downto 0);
        dbg_map_data    : out std_logic_vector(7 downto 0);
        dbg_tile_addr   : in  std_logic_vector(12 downto 0);
        dbg_tile_data   : out std_logic_vector(7 downto 0);
        dbg_pal_addr    : in  std_logic_vector(3 downto 0);
        dbg_pal_data    : out std_logic_vector(23 downto 0)
    );
end entity spi_tile_display;

architecture rtl of spi_tile_display is
    constant SCREEN_W       : integer := get_hor_pixels(SVO_MODE);
    constant SCREEN_H       : integer := get_ver_pixels(SVO_MODE);
    constant TILE_SIZE      : integer := 16;
    constant MAP_COLS       : integer := SCREEN_W / TILE_SIZE;
    constant MAP_ROWS       : integer := SCREEN_H / TILE_SIZE;
    constant MAP_SIZE       : integer := MAP_COLS * MAP_ROWS;
    constant TILE_COUNT     : integer := 64;
    constant TILE_BYTES     : integer := 128;
    constant TILE_RAM_BYTES : integer := TILE_COUNT * TILE_BYTES;

    constant CMD_SET_PALETTE     : std_logic_vector(7 downto 0) := x"01";
    constant CMD_WRITE_TILE      : std_logic_vector(7 downto 0) := x"10";
    constant CMD_WRITE_TILE_RECT : std_logic_vector(7 downto 0) := x"20";
    constant CMD_FILL_TILEMAP    : std_logic_vector(7 downto 0) := x"21";

    type palette_t is array (0 to 15) of std_logic_vector(23 downto 0);
    type parser_state_t is (
        ST_IDLE,
        ST_PAL_INDEX, ST_PAL_R, ST_PAL_G, ST_PAL_B,
        ST_TILE_ID, ST_TILE_DATA,
        ST_RECT_X, ST_RECT_Y, ST_RECT_W, ST_RECT_H, ST_RECT_DATA,
        ST_FILL_ID, ST_FILL_RUN
    );

    signal rx_valid : std_logic;
    signal rx_data  : std_logic_vector(7 downto 0);
    signal cs_sync   : std_logic_vector(2 downto 0) := (others => '1');

    component spi_byte_rx
        port (
            clk        : in  std_logic;
            resetn     : in  std_logic;
            spi_sclk   : in  std_logic;
            spi_cs_n   : in  std_logic;
            spi_mosi   : in  std_logic;
            byte_valid : out std_logic;
            byte_data  : out std_logic_vector(7 downto 0)
        );
    end component;

    component spi_dp_ram
        generic (
            ADDR_WIDTH : integer;
            DATA_WIDTH : integer
        );
        port (
            clk   : in  std_logic;
            we    : in  std_logic;
            waddr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            wdata : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            raddr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            rdata : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

    signal palette  : palette_t := (
        0  => x"000000",
        1  => x"FFFFFF",
        2  => x"FF0000",
        3  => x"00FF00",
        4  => x"0000FF",
        5  => x"00FFFF",
        6  => x"FF00FF",
        7  => x"FFFF00",
        8  => x"808080",
        9  => x"800000",
        10 => x"008000",
        11 => x"000080",
        12 => x"008080",
        13 => x"800080",
        14 => x"808000",
        15 => x"202020"
    );

    signal parser_state : parser_state_t := ST_IDLE;
    signal pal_index    : unsigned(3 downto 0) := (others => '0');
    signal pal_r        : std_logic_vector(7 downto 0) := (others => '0');
    signal pal_g        : std_logic_vector(7 downto 0) := (others => '0');
    signal tile_id      : unsigned(5 downto 0) := (others => '0');
    signal tile_byte    : unsigned(6 downto 0) := (others => '0');
    signal rect_x       : unsigned(5 downto 0) := (others => '0');
    signal rect_y       : unsigned(4 downto 0) := (others => '0');
    signal rect_w       : unsigned(5 downto 0) := (others => '0');
    signal rect_h       : unsigned(4 downto 0) := (others => '0');
    signal rect_col     : unsigned(5 downto 0) := (others => '0');
    signal rect_row     : unsigned(4 downto 0) := (others => '0');
    signal fill_index   : unsigned(10 downto 0) := (others => '0');
    signal fill_value   : std_logic_vector(7 downto 0) := (others => '0');

    signal hcursor : unsigned(SVO_XYBITS-1 downto 0) := (others => '0');
    signal vcursor : unsigned(SVO_XYBITS-1 downto 0) := (others => '0');
    signal s_tvalid : std_logic := '0';

    signal tile_wr_en   : std_logic := '0';
    signal tile_wr_addr : std_logic_vector(12 downto 0) := (others => '0');
    signal tile_wr_data : std_logic_vector(7 downto 0) := (others => '0');
    signal tile_rd_addr : std_logic_vector(12 downto 0) := (others => '0');
    signal tile_rd_data : std_logic_vector(7 downto 0);
    signal tile_ram_raddr : std_logic_vector(12 downto 0);

    signal map_wr_en   : std_logic := '0';
    signal map_wr_addr : std_logic_vector(10 downto 0) := (others => '0');
    signal map_wr_data : std_logic_vector(7 downto 0) := (others => '0');
    signal map_rd_addr : std_logic_vector(10 downto 0) := (others => '0');
    signal map_rd_data : std_logic_vector(7 downto 0);
    signal map_ram_raddr : std_logic_vector(10 downto 0);

    signal pipe1_valid   : std_logic := '0';
    signal pipe1_sof     : std_logic := '0';
    signal pipe1_local_x : unsigned(3 downto 0) := (others => '0');
    signal pipe1_local_y : unsigned(3 downto 0) := (others => '0');
    signal pipe2_valid   : std_logic := '0';
    signal pipe2_sof     : std_logic := '0';
    signal pipe2_local_x : unsigned(3 downto 0) := (others => '0');
begin
    u_spi_rx: spi_byte_rx
        port map (
            clk        => clk,
            resetn     => resetn,
            spi_sclk   => spi_sclk,
            spi_cs_n   => spi_cs_n,
            spi_mosi   => spi_mosi,
            byte_valid => rx_valid,
            byte_data  => rx_data
        );

    out_axis_tvalid <= s_tvalid;

    gen_debug_addr: if ENABLE_DEBUG generate
        map_ram_raddr  <= dbg_map_addr;
        tile_ram_raddr <= dbg_tile_addr;
    end generate;

    gen_render_addr: if not ENABLE_DEBUG generate
        map_ram_raddr  <= map_rd_addr;
        tile_ram_raddr <= tile_rd_addr;
    end generate;

    u_map_ram: spi_dp_ram
        generic map (
            ADDR_WIDTH => 11,
            DATA_WIDTH => 8
        )
        port map (
            clk   => clk,
            we    => map_wr_en,
            waddr => map_wr_addr,
            wdata => map_wr_data,
            raddr => map_ram_raddr,
            rdata => map_rd_data
        );

    u_tile_ram: spi_dp_ram
        generic map (
            ADDR_WIDTH => 13,
            DATA_WIDTH => 8
        )
        port map (
            clk   => clk,
            we    => tile_wr_en,
            waddr => tile_wr_addr,
            wdata => tile_wr_data,
            raddr => tile_ram_raddr,
            rdata => tile_rd_data
        );

    gen_debug: if ENABLE_DEBUG generate
        dbg_map_data  <= map_rd_data;
        dbg_tile_data <= tile_rd_data;
        dbg_pal_data  <= palette(to_integer(unsigned(dbg_pal_addr)));
    end generate;

    gen_no_debug: if not ENABLE_DEBUG generate
        dbg_map_data  <= (others => '0');
        dbg_tile_data <= (others => '0');
        dbg_pal_data  <= (others => '0');
    end generate;

    process(clk)
        variable rx_int       : integer;
        variable tile_addr    : integer;
        variable map_addr     : integer;
        variable next_col     : unsigned(5 downto 0);
        variable next_row     : unsigned(4 downto 0);
        variable fill_byte    : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            tile_wr_en <= '0';
            map_wr_en  <= '0';

            if resetn = '0' then
                parser_state <= ST_IDLE;
                pal_index    <= (others => '0');
                pal_r        <= (others => '0');
                pal_g        <= (others => '0');
                tile_id      <= (others => '0');
                tile_byte    <= (others => '0');
                rect_x       <= (others => '0');
                rect_y       <= (others => '0');
                rect_w       <= (others => '0');
                rect_h       <= (others => '0');
                rect_col     <= (others => '0');
                rect_row     <= (others => '0');
                fill_index   <= (others => '0');
                fill_value   <= (others => '0');
                cs_sync      <= (others => '1');
            elsif parser_state = ST_FILL_RUN then
                cs_sync <= cs_sync(1 downto 0) & spi_cs_n;
                map_wr_en   <= '1';
                map_wr_addr <= std_logic_vector(fill_index);
                map_wr_data <= fill_value;
                if fill_index = MAP_SIZE-1 then
                    parser_state <= ST_IDLE;
                else
                    fill_index <= fill_index + 1;
                end if;
            elsif cs_sync(2 downto 1) = "01" then
                cs_sync <= cs_sync(1 downto 0) & spi_cs_n;
                parser_state <= ST_IDLE;
                tile_byte    <= (others => '0');
                rect_col     <= (others => '0');
                rect_row     <= (others => '0');
            elsif rx_valid = '1' then
                cs_sync <= cs_sync(1 downto 0) & spi_cs_n;
                rx_int := to_integer(unsigned(rx_data));

                case parser_state is
                    when ST_IDLE =>
                        if rx_data = CMD_SET_PALETTE then
                            parser_state <= ST_PAL_INDEX;
                        elsif rx_data = CMD_WRITE_TILE then
                            parser_state <= ST_TILE_ID;
                        elsif rx_data = CMD_WRITE_TILE_RECT then
                            parser_state <= ST_RECT_X;
                        elsif rx_data = CMD_FILL_TILEMAP then
                            parser_state <= ST_FILL_ID;
                        else
                            parser_state <= ST_IDLE;
                        end if;

                    when ST_PAL_INDEX =>
                        pal_index <= unsigned(rx_data(3 downto 0));
                        parser_state <= ST_PAL_R;

                    when ST_PAL_R =>
                        pal_r <= rx_data;
                        parser_state <= ST_PAL_G;

                    when ST_PAL_G =>
                        pal_g <= rx_data;
                        parser_state <= ST_PAL_B;

                    when ST_PAL_B =>
                        palette(to_integer(pal_index)) <= pal_r & pal_g & rx_data;
                        parser_state <= ST_IDLE;

                    when ST_TILE_ID =>
                        tile_id <= unsigned(rx_data(5 downto 0));
                        tile_byte <= (others => '0');
                        parser_state <= ST_TILE_DATA;

                    when ST_TILE_DATA =>
                        tile_addr := to_integer(tile_id) * TILE_BYTES + to_integer(tile_byte);
                        if tile_addr < TILE_RAM_BYTES then
                            tile_wr_en   <= '1';
                            tile_wr_addr <= std_logic_vector(to_unsigned(tile_addr, tile_wr_addr'length));
                            tile_wr_data <= rx_data;
                        end if;
                        if tile_byte = TILE_BYTES-1 then
                            parser_state <= ST_IDLE;
                        else
                            tile_byte <= tile_byte + 1;
                        end if;

                    when ST_RECT_X =>
                        if rx_int < MAP_COLS then
                            rect_x <= to_unsigned(rx_int, rect_x'length);
                        else
                            rect_x <= to_unsigned(MAP_COLS-1, rect_x'length);
                        end if;
                        parser_state <= ST_RECT_Y;

                    when ST_RECT_Y =>
                        if rx_int < MAP_ROWS then
                            rect_y <= to_unsigned(rx_int, rect_y'length);
                        else
                            rect_y <= to_unsigned(MAP_ROWS-1, rect_y'length);
                        end if;
                        parser_state <= ST_RECT_W;

                    when ST_RECT_W =>
                        if rx_int = 0 then
                            rect_w <= (others => '0');
                        elsif to_integer(rect_x) + rx_int > MAP_COLS then
                            rect_w <= to_unsigned(MAP_COLS - to_integer(rect_x), rect_w'length);
                        else
                            rect_w <= to_unsigned(rx_int, rect_w'length);
                        end if;
                        parser_state <= ST_RECT_H;

                    when ST_RECT_H =>
                        if rx_int = 0 then
                            rect_h <= (others => '0');
                        elsif to_integer(rect_y) + rx_int > MAP_ROWS then
                            rect_h <= to_unsigned(MAP_ROWS - to_integer(rect_y), rect_h'length);
                        else
                            rect_h <= to_unsigned(rx_int, rect_h'length);
                        end if;
                        rect_col <= (others => '0');
                        rect_row <= (others => '0');
                        parser_state <= ST_RECT_DATA;

                    when ST_RECT_DATA =>
                        if rect_w = 0 or rect_h = 0 then
                            parser_state <= ST_IDLE;
                        else
                            map_addr := (to_integer(rect_y) + to_integer(rect_row)) * MAP_COLS +
                                        to_integer(rect_x) + to_integer(rect_col);
                            if map_addr < MAP_SIZE then
                                map_wr_en   <= '1';
                                map_wr_addr <= std_logic_vector(to_unsigned(map_addr, map_wr_addr'length));
                                map_wr_data <= "00" & rx_data(5 downto 0);
                            end if;

                            next_col := rect_col + 1;
                            next_row := rect_row;
                            if next_col = rect_w then
                                next_col := (others => '0');
                                next_row := rect_row + 1;
                            end if;

                            if next_row = rect_h then
                                parser_state <= ST_IDLE;
                            end if;
                            rect_col <= next_col;
                            rect_row <= next_row;
                        end if;

                    when ST_FILL_ID =>
                        fill_byte := "00" & rx_data(5 downto 0);
                        fill_index <= (others => '0');
                        fill_value <= fill_byte;
                        parser_state <= ST_FILL_RUN;

                    when ST_FILL_RUN =>
                        parser_state <= ST_FILL_RUN;
                end case;
            else
                cs_sync <= cs_sync(1 downto 0) & spi_cs_n;
            end if;
        end if;
    end process;

    process(clk)
        variable x_int       : integer;
        variable y_int       : integer;
        variable tile_x      : integer;
        variable tile_y      : integer;
        variable local_x     : integer;
        variable local_y     : integer;
        variable map_index   : integer;
        variable tile_index  : integer;
        variable tile_offset : integer;
        variable pal_index_v : integer;
        variable advance     : boolean;
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                hcursor <= (others => '0');
                vcursor <= (others => '0');
                s_tvalid <= '0';
                out_axis_tdata <= (others => '0');
                out_axis_tuser <= (others => '0');
                pipe1_valid <= '0';
                pipe2_valid <= '0';
                pipe1_sof <= '0';
                pipe2_sof <= '0';
                pipe1_local_x <= (others => '0');
                pipe1_local_y <= (others => '0');
                pipe2_local_x <= (others => '0');
                map_rd_addr <= (others => '0');
                tile_rd_addr <= (others => '0');
            else
                advance := (s_tvalid = '0') or (out_axis_tready = '1');

                if advance then
                    if pipe2_valid = '1' then
                        if pipe2_local_x(0) = '0' then
                            pal_index_v := to_integer(unsigned(tile_rd_data(7 downto 4)));
                        else
                            pal_index_v := to_integer(unsigned(tile_rd_data(3 downto 0)));
                        end if;
                        out_axis_tdata <= palette(pal_index_v);
                        out_axis_tuser(0) <= pipe2_sof;
                        s_tvalid <= '1';
                    else
                        out_axis_tdata <= (others => '0');
                        out_axis_tuser(0) <= '0';
                        s_tvalid <= '0';
                    end if;

                    tile_index := to_integer(unsigned(map_rd_data(5 downto 0)));
                    tile_offset := tile_index * TILE_BYTES +
                                   to_integer(pipe1_local_y) * 8 +
                                   to_integer(pipe1_local_x) / 2;
                    tile_rd_addr <= std_logic_vector(to_unsigned(tile_offset, tile_rd_addr'length));
                    pipe2_valid <= pipe1_valid;
                    pipe2_sof <= pipe1_sof;
                    pipe2_local_x <= pipe1_local_x;

                    x_int := to_integer(hcursor);
                    y_int := to_integer(vcursor);
                    tile_x := x_int / TILE_SIZE;
                    tile_y := y_int / TILE_SIZE;
                    local_x := x_int mod TILE_SIZE;
                    local_y := y_int mod TILE_SIZE;
                    map_index := tile_y * MAP_COLS + tile_x;
                    map_rd_addr <= std_logic_vector(to_unsigned(map_index, map_rd_addr'length));
                    pipe1_valid <= '1';
                    if hcursor = 0 and vcursor = 0 then
                        pipe1_sof <= '1';
                    else
                        pipe1_sof <= '0';
                    end if;
                    pipe1_local_x <= to_unsigned(local_x, pipe1_local_x'length);
                    pipe1_local_y <= to_unsigned(local_y, pipe1_local_y'length);

                    if hcursor = to_unsigned(SCREEN_W-1, SVO_XYBITS) then
                        hcursor <= (others => '0');
                        if vcursor = to_unsigned(SCREEN_H-1, SVO_XYBITS) then
                            vcursor <= (others => '0');
                        else
                            vcursor <= vcursor + 1;
                        end if;
                    else
                        hcursor <= hcursor + 1;
                    end if;
                else
                    s_tvalid <= s_tvalid;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
