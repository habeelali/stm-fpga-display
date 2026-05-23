library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

entity tb_spi_byte_rx is
end entity tb_spi_byte_rx;

architecture sim of tb_spi_byte_rx is
    signal clk        : std_logic := '0';
    signal resetn     : std_logic := '0';
    signal spi_sclk   : std_logic := '0';
    signal spi_cs_n   : std_logic := '1';
    signal spi_mosi   : std_logic := '0';
    signal byte_valid : std_logic;
    signal byte_data  : std_logic_vector(7 downto 0);
    signal seen_count : integer := 0;
    signal last_byte  : std_logic_vector(7 downto 0) := (others => '0');

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
begin
    clk <= not clk after 10 ns;

    u_dut: entity work.spi_byte_rx
        port map (
            clk        => clk,
            resetn     => resetn,
            spi_sclk   => spi_sclk,
            spi_cs_n   => spi_cs_n,
            spi_mosi   => spi_mosi,
            byte_valid => byte_valid,
            byte_data  => byte_data
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if byte_valid = '1' then
                seen_count <= seen_count + 1;
                last_byte <= byte_data;
            end if;
        end if;
    end process;

    process
        variable count_before : integer;
    begin
        wait for 100 ns;
        resetn <= '1';
        wait for 100 ns;

        spi_cs_n <= '0';
        spi_send_byte(spi_sclk, spi_mosi, x"A5");
        wait until rising_edge(clk);
        assert seen_count = 1 report "first byte not emitted" severity failure;
        assert last_byte = x"A5" report "first byte mismatch" severity failure;

        spi_send_byte(spi_sclk, spi_mosi, x"3C");
        wait until rising_edge(clk);
        assert seen_count = 2 report "second byte not emitted" severity failure;
        assert last_byte = x"3C" report "second byte mismatch" severity failure;
        spi_cs_n <= '1';
        wait for 200 ns;

        count_before := seen_count;
        spi_cs_n <= '0';
        spi_send_byte(spi_sclk, spi_mosi, x"F0");
        wait for 360 ns;
        spi_cs_n <= '1';
        wait for 300 ns;
        assert seen_count = count_before + 1 report "complete third byte should have been emitted once" severity failure;

        count_before := seen_count;
        spi_cs_n <= '0';
        for i in 7 downto 4 loop
            spi_mosi <= '1';
            wait for 80 ns;
            spi_sclk <= '1';
            wait for 80 ns;
            spi_sclk <= '0';
            wait for 80 ns;
        end loop;
        spi_cs_n <= '1';
        wait for 300 ns;
        assert seen_count = count_before report "partial byte should not be emitted after CS reset" severity failure;

        report "tb_spi_byte_rx passed";
        finish;
    end process;
end architecture sim;
