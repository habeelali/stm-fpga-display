library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_byte_rx is
    port (
        clk        : in  std_logic;
        resetn     : in  std_logic;
        spi_sclk   : in  std_logic;
        spi_cs_n   : in  std_logic;
        spi_mosi   : in  std_logic;
        byte_valid : out std_logic;
        byte_data  : out std_logic_vector(7 downto 0)
    );
end entity spi_byte_rx;

architecture rtl of spi_byte_rx is
    signal sclk_sync : std_logic_vector(2 downto 0) := (others => '0');
    signal cs_sync   : std_logic_vector(2 downto 0) := (others => '1');
    signal mosi_sync : std_logic_vector(2 downto 0) := (others => '0');
    signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_count : unsigned(2 downto 0) := (others => '0');
begin
    process(clk)
        variable next_shift : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                sclk_sync  <= (others => '0');
                cs_sync    <= (others => '1');
                mosi_sync  <= (others => '0');
                shift_reg  <= (others => '0');
                bit_count  <= (others => '0');
                byte_valid <= '0';
                byte_data  <= (others => '0');
            else
                sclk_sync <= sclk_sync(1 downto 0) & spi_sclk;
                cs_sync   <= cs_sync(1 downto 0) & spi_cs_n;
                mosi_sync <= mosi_sync(1 downto 0) & spi_mosi;

                byte_valid <= '0';

                if cs_sync(2) = '1' then
                    bit_count <= (others => '0');
                    shift_reg <= (others => '0');
                elsif sclk_sync(2 downto 1) = "01" then
                    next_shift := shift_reg(6 downto 0) & mosi_sync(2);
                    shift_reg <= next_shift;

                    if bit_count = 7 then
                        byte_data  <= next_shift;
                        byte_valid <= '1';
                        bit_count  <= (others => '0');
                    else
                        bit_count <= bit_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
