library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;
use work.svo_pkg.all;

entity tb_spi_tile_protocol is
end entity tb_spi_tile_protocol;

architecture sim of tb_spi_tile_protocol is
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
            ENABLE_DEBUG => true
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
        variable b : std_logic_vector(7 downto 0);
    begin
        wait for 100 ns;
        resetn <= '1';
        wait for 200 ns;

        spi_begin(spi_cs_n);
        spi_send_byte(spi_sclk, spi_mosi, x"01");
        spi_send_byte(spi_sclk, spi_mosi, x"02");
        spi_end(spi_cs_n);

        spi_begin(spi_cs_n);
        spi_send_byte(spi_sclk, spi_mosi, x"01");
        spi_send_byte(spi_sclk, spi_mosi, x"03");
        spi_send_byte(spi_sclk, spi_mosi, x"11");
        spi_send_byte(spi_sclk, spi_mosi, x"22");
        spi_send_byte(spi_sclk, spi_mosi, x"33");
        spi_end(spi_cs_n);
        dbg_pal_addr <= x"3";
        wait until rising_edge(clk);
        assert dbg_pal_data = x"112233" report "palette write failed" severity failure;

        spi_begin(spi_cs_n);
        spi_send_byte(spi_sclk, spi_mosi, x"10");
        spi_send_byte(spi_sclk, spi_mosi, x"05");
        for i in 0 to 127 loop
            b := std_logic_vector(to_unsigned(i, 8));
            spi_send_byte(spi_sclk, spi_mosi, b);
        end loop;
        spi_end(spi_cs_n);
        dbg_tile_addr <= std_logic_vector(to_unsigned(5 * 128, dbg_tile_addr'length));
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert dbg_tile_data = x"00" report "first tile byte write failed" severity failure;
        dbg_tile_addr <= std_logic_vector(to_unsigned(5 * 128 + 127, dbg_tile_addr'length));
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert dbg_tile_data = x"7F" report "last tile byte write failed" severity failure;

        spi_begin(spi_cs_n);
        spi_send_byte(spi_sclk, spi_mosi, x"20");
        spi_send_byte(spi_sclk, spi_mosi, x"02");
        spi_send_byte(spi_sclk, spi_mosi, x"03");
        spi_send_byte(spi_sclk, spi_mosi, x"02");
        spi_send_byte(spi_sclk, spi_mosi, x"02");
        spi_send_byte(spi_sclk, spi_mosi, x"01");
        spi_send_byte(spi_sclk, spi_mosi, x"02");
        spi_send_byte(spi_sclk, spi_mosi, x"03");
        spi_send_byte(spi_sclk, spi_mosi, x"04");
        spi_end(spi_cs_n);
        dbg_map_addr <= std_logic_vector(to_unsigned(3 * 40 + 2, dbg_map_addr'length));
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert dbg_map_data = x"01" report "rect map[0,0] failed" severity failure;
        dbg_map_addr <= std_logic_vector(to_unsigned(4 * 40 + 3, dbg_map_addr'length));
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert dbg_map_data = x"04" report "rect map[1,1] failed" severity failure;

        spi_begin(spi_cs_n);
        spi_send_byte(spi_sclk, spi_mosi, x"21");
        spi_send_byte(spi_sclk, spi_mosi, x"07");
        spi_end(spi_cs_n);
        wait for 30 us;
        dbg_map_addr <= std_logic_vector(to_unsigned(1199, dbg_map_addr'length));
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert dbg_map_data = x"07" report "fill tilemap failed" severity failure;

        report "tb_spi_tile_protocol passed";
        finish;
    end process;
end architecture sim;
