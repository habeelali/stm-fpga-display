library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;
use work.svo_pkg.all;

entity tb_spi_tile_render is
end entity tb_spi_tile_render;

architecture sim of tb_spi_tile_render is
    signal clk             : std_logic := '0';
    signal resetn          : std_logic := '0';
    signal spi_sclk        : std_logic := '0';
    signal spi_cs_n        : std_logic := '1';
    signal spi_mosi        : std_logic := '0';
    signal out_axis_tvalid : std_logic;
    signal out_axis_tready : std_logic := '0';
    signal out_axis_tdata  : std_logic_vector(23 downto 0);
    signal out_axis_tuser  : std_logic_vector(0 downto 0);
    signal dbg_map_addr    : std_logic_vector(10 downto 0) := (others => '0');
    signal dbg_map_data    : std_logic_vector(7 downto 0);
    signal dbg_tile_addr   : std_logic_vector(12 downto 0) := (others => '0');
    signal dbg_tile_data   : std_logic_vector(7 downto 0);
    signal dbg_pal_addr    : std_logic_vector(3 downto 0) := (others => '0');
    signal dbg_pal_data    : std_logic_vector(23 downto 0);

    procedure spi_send_byte(
        signal sclk : out std_logic;
        signal mosi : out std_logic;
        constant value : std_logic_vector(7 downto 0)
    ) is
    begin
        for i in 7 downto 0 loop
            mosi <= value(i);
            wait for 80 ns;
            sclk <= '1';
            wait for 80 ns;
            sclk <= '0';
            wait for 80 ns;
        end loop;
    end procedure;

    procedure spi_begin(signal cs_n : out std_logic) is
    begin
        wait for 100 ns;
        cs_n <= '0';
        wait for 100 ns;
    end procedure;

    procedure spi_end(signal cs_n : out std_logic) is
    begin
        wait for 100 ns;
        cs_n <= '1';
        wait for 300 ns;
    end procedure;
begin
    clk <= not clk after 10 ns;

    u_dut: entity work.spi_tile_display
        generic map (
            SVO_MODE => M_640x480V,
            SVO_BITS_PER_PIXEL => 24,
            ENABLE_DEBUG => false
        )
        port map (
            clk             => clk,
            resetn          => resetn,
            spi_sclk        => spi_sclk,
            spi_cs_n        => spi_cs_n,
            spi_mosi        => spi_mosi,
            out_axis_tvalid => out_axis_tvalid,
            out_axis_tready => out_axis_tready,
            out_axis_tdata  => out_axis_tdata,
            out_axis_tuser  => out_axis_tuser,
            dbg_map_addr    => dbg_map_addr,
            dbg_map_data    => dbg_map_data,
            dbg_tile_addr   => dbg_tile_addr,
            dbg_tile_data   => dbg_tile_data,
            dbg_pal_addr    => dbg_pal_addr,
            dbg_pal_data    => dbg_pal_data
        );

    process
    begin
        wait for 100 ns;
        resetn <= '1';
        wait for 200 ns;

        spi_begin(spi_cs_n);
        spi_send_byte(spi_sclk, spi_mosi, x"01");
        spi_send_byte(spi_sclk, spi_mosi, x"01");
        spi_send_byte(spi_sclk, spi_mosi, x"AA");
        spi_send_byte(spi_sclk, spi_mosi, x"00");
        spi_send_byte(spi_sclk, spi_mosi, x"00");
        spi_end(spi_cs_n);

        spi_begin(spi_cs_n);
        spi_send_byte(spi_sclk, spi_mosi, x"10");
        spi_send_byte(spi_sclk, spi_mosi, x"00");
        for i in 0 to 127 loop
            spi_send_byte(spi_sclk, spi_mosi, x"10");
        end loop;
        spi_end(spi_cs_n);

        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait until rising_edge(clk);
        out_axis_tready <= '1';

        wait until rising_edge(clk) and out_axis_tvalid = '1';
        assert out_axis_tuser(0) = '1' report "first rendered pixel missing SOF" severity failure;
        assert out_axis_tdata = x"AA0000" report "first rendered pixel should use high nibble palette 1" severity failure;

        wait until rising_edge(clk) and out_axis_tvalid = '1';
        assert out_axis_tdata = x"000000" report "second rendered pixel should use low nibble palette 0" severity failure;

        for i in 2 to 15 loop
            wait until rising_edge(clk) and out_axis_tvalid = '1';
        end loop;
        assert out_axis_tdata = x"000000" report "pixel 15 should use low nibble palette 0" severity failure;

        wait until rising_edge(clk) and out_axis_tvalid = '1';
        assert out_axis_tdata = x"AA0000" report "pixel 16 should start next tile high nibble" severity failure;

        report "tb_spi_tile_render passed";
        finish;
    end process;
end architecture sim;
