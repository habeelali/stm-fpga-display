library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

entity svo_hdmi is
    generic (
        SVO_MODE           : svo_mode_t := M_640x480V;
        SVO_FRAMERATE      : integer    := 60;
        SVO_BITS_PER_PIXEL : integer    := 24;
        SVO_BITS_PER_RED   : integer    := 8;
        SVO_BITS_PER_GREEN : integer    := 8;
        SVO_BITS_PER_BLUE  : integer    := 8;
        SVO_BITS_PER_ALPHA : integer    := 0
    );
    port (
        clk         : in  std_logic;
        resetn      : in  std_logic;
        clk_pixel   : in  std_logic;
        clk_5x_pixel: in  std_logic;
        locked      : in  std_logic;
        spi_sclk    : in  std_logic;
        spi_cs_n    : in  std_logic;
        spi_mosi    : in  std_logic;

        tmds_clk_n  : out std_logic;
        tmds_clk_p  : out std_logic;
        tmds_d_n    : out std_logic_vector(2 downto 0);
        tmds_d_p    : out std_logic_vector(2 downto 0)
    );
end entity svo_hdmi;

architecture rtl of svo_hdmi is

    component spi_tile_display
        generic (
            SVO_MODE : svo_mode_t;
            SVO_BITS_PER_PIXEL : integer;
            ENABLE_DEBUG : boolean
        );
        port (
            clk : in std_logic; resetn : in std_logic;
            spi_sclk : in std_logic; spi_cs_n : in std_logic; spi_mosi : in std_logic;
            out_axis_tvalid : out std_logic; out_axis_tready : in std_logic;
            out_axis_tdata  : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
            out_axis_tuser  : out std_logic_vector(0 downto 0);
            dbg_map_addr  : in std_logic_vector(10 downto 0);
            dbg_map_data  : out std_logic_vector(7 downto 0);
            dbg_tile_addr : in std_logic_vector(12 downto 0);
            dbg_tile_data : out std_logic_vector(7 downto 0);
            dbg_pal_addr  : in std_logic_vector(3 downto 0);
            dbg_pal_data  : out std_logic_vector(23 downto 0)
        );
    end component;

    component svo_enc
        generic (
            SVO_MODE : svo_mode_t; SVO_FRAMERATE : integer;
            SVO_BITS_PER_PIXEL : integer; SVO_BITS_PER_RED : integer;
            SVO_BITS_PER_GREEN : integer; SVO_BITS_PER_BLUE : integer;
            SVO_BITS_PER_ALPHA : integer
        );
        port (
            clk : in std_logic; resetn : in std_logic;
            in_axis_tvalid : in  std_logic; in_axis_tready : out std_logic;
            in_axis_tdata  : in  std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
            in_axis_tuser  : in  std_logic_vector(0 downto 0);
            out_axis_tvalid : out std_logic; out_axis_tready : in std_logic;
            out_axis_tdata  : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
            out_axis_tuser  : out std_logic_vector(3 downto 0)
        );
    end component;

    component svo_tmds
        port (
            clk : in std_logic; resetn : in std_logic;
            de   : in  std_logic; ctrl : in  std_logic_vector(1 downto 0);
            din  : in  std_logic_vector(7 downto 0);
            dout : out std_logic_vector(9 downto 0)
        );
    end component;

    component OSER10
        port (
            Q     : out std_logic;
            D0    : in  std_logic; D1 : in std_logic; D2 : in std_logic;
            D3    : in  std_logic; D4 : in std_logic; D5 : in std_logic;
            D6    : in  std_logic; D7 : in std_logic; D8 : in std_logic;
            D9    : in  std_logic;
            PCLK  : in  std_logic;
            FCLK  : in  std_logic;
            RESET : in  std_logic
        );
    end component;

    component ELVDS_OBUF
        port (
            I  : in  std_logic;
            O  : out std_logic;
            OB : out std_logic
        );
    end component;

    signal vdma_tvalid : std_logic;
    signal vdma_tready : std_logic;
    signal vdma_tdata  : std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
    signal vdma_tuser  : std_logic_vector(0 downto 0);

    signal enc_tvalid  : std_logic;
    signal enc_tready  : std_logic;
    signal enc_tdata   : std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
    signal enc_tuser   : std_logic_vector(3 downto 0);

    -- TMDS parallel data: 10 bits per channel, 3 channels
    type tmds_bits_t is array (0 to 2) of std_logic_vector(9 downto 0);
    signal tmds_bits : tmds_bits_t;

    -- Serial output per channel
    signal tmds_d : std_logic_vector(2 downto 0);

    signal locked_clk_q       : std_logic_vector(3 downto 0);
    signal resetn_pixel_q      : std_logic_vector(3 downto 0);
    signal clk_resetn          : std_logic;
    signal clk_pixel_resetn    : std_logic;

    signal reset_for_oser : std_logic;
    signal unused_map_data  : std_logic_vector(7 downto 0);
    signal unused_tile_data : std_logic_vector(7 downto 0);
    signal unused_pal_data  : std_logic_vector(23 downto 0);

begin

    -- Sync locked into clk domain
    process(clk) begin
        if rising_edge(clk) then
            locked_clk_q <= locked_clk_q(2 downto 0) & locked;
        end if;
    end process;

    -- Sync resetn into clk_pixel domain
    process(clk_pixel) begin
        if rising_edge(clk_pixel) then
            resetn_pixel_q <= resetn_pixel_q(2 downto 0) & resetn;
        end if;
    end process;

    clk_resetn       <= resetn and locked_clk_q(3);
    clk_pixel_resetn <= locked and resetn_pixel_q(3);
    reset_for_oser   <= not clk_pixel_resetn;

    enc_tready <= '1';

    -- SPI-controlled tile source
    u_tile: spi_tile_display
        generic map (
            SVO_MODE => SVO_MODE,
            SVO_BITS_PER_PIXEL => SVO_BITS_PER_PIXEL,
            ENABLE_DEBUG => false
        )
        port map (
            clk             => clk_pixel,
            resetn          => clk_pixel_resetn,
            spi_sclk        => spi_sclk,
            spi_cs_n        => spi_cs_n,
            spi_mosi        => spi_mosi,
            out_axis_tvalid => vdma_tvalid,
            out_axis_tready => vdma_tready,
            out_axis_tdata  => vdma_tdata,
            out_axis_tuser  => vdma_tuser,
            dbg_map_addr    => (others => '0'),
            dbg_map_data    => unused_map_data,
            dbg_tile_addr   => (others => '0'),
            dbg_tile_data   => unused_tile_data,
            dbg_pal_addr    => (others => '0'),
            dbg_pal_data    => unused_pal_data
        );

    -- Encoder
    u_enc: svo_enc
        generic map (
            SVO_MODE => SVO_MODE, SVO_FRAMERATE => SVO_FRAMERATE,
            SVO_BITS_PER_PIXEL => SVO_BITS_PER_PIXEL,
            SVO_BITS_PER_RED => SVO_BITS_PER_RED,
            SVO_BITS_PER_GREEN => SVO_BITS_PER_GREEN,
            SVO_BITS_PER_BLUE => SVO_BITS_PER_BLUE,
            SVO_BITS_PER_ALPHA => SVO_BITS_PER_ALPHA
        )
        port map (
            clk             => clk_pixel,
            resetn          => clk_pixel_resetn,
            in_axis_tvalid  => vdma_tvalid,
            in_axis_tready  => vdma_tready,
            in_axis_tdata   => vdma_tdata,
            in_axis_tuser   => vdma_tuser,
            out_axis_tvalid => enc_tvalid,
            out_axis_tready => enc_tready,
            out_axis_tdata  => enc_tdata,
            out_axis_tuser  => enc_tuser
        );

    -- TMDS encoders for each channel
    -- Channel 0: Blue  = enc_tdata[7:0],   ctrl = enc_tuser[2:1] (hsync/vsync)
    -- Channel 1: Green = enc_tdata[15:8],  ctrl = "00"
    -- Channel 2: Red   = enc_tdata[23:16], ctrl = "00"
    u_tmds0: svo_tmds
        port map (
            clk    => clk_pixel,
            resetn => clk_pixel_resetn,
            de     => not enc_tuser(3),
            ctrl   => enc_tuser(2 downto 1),
            din    => enc_tdata(7 downto 0),
            dout   => tmds_bits(0)
        );

    u_tmds1: svo_tmds
        port map (
            clk    => clk_pixel,
            resetn => clk_pixel_resetn,
            de     => not enc_tuser(3),
            ctrl   => "00",
            din    => enc_tdata(15 downto 8),
            dout   => tmds_bits(1)
        );

    u_tmds2: svo_tmds
        port map (
            clk    => clk_pixel,
            resetn => clk_pixel_resetn,
            de     => not enc_tuser(3),
            ctrl   => "00",
            din    => enc_tdata(23 downto 16),
            dout   => tmds_bits(2)
        );

    -- OSER10 serializers (one per channel)
    gen_serdes: for i in 0 to 2 generate
        u_oser: OSER10
            port map (
                Q     => tmds_d(i),
                D0    => tmds_bits(i)(0),
                D1    => tmds_bits(i)(1),
                D2    => tmds_bits(i)(2),
                D3    => tmds_bits(i)(3),
                D4    => tmds_bits(i)(4),
                D5    => tmds_bits(i)(5),
                D6    => tmds_bits(i)(6),
                D7    => tmds_bits(i)(7),
                D8    => tmds_bits(i)(8),
                D9    => tmds_bits(i)(9),
                PCLK  => clk_pixel,
                FCLK  => clk_5x_pixel,
                RESET => reset_for_oser
            );
    end generate;

    -- LVDS output buffers for data channels
    gen_bufds: for i in 0 to 2 generate
        u_buf: ELVDS_OBUF
            port map (
                I  => tmds_d(i),
                O  => tmds_d_p(i),
                OB => tmds_d_n(i)
            );
    end generate;

    -- LVDS output buffer for clock channel
    u_clkbuf: ELVDS_OBUF
        port map (
            I  => clk_pixel,
            O  => tmds_clk_p,
            OB => tmds_clk_n
        );

end architecture rtl;
