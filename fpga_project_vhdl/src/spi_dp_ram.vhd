library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_dp_ram is
    generic (
        ADDR_WIDTH : integer := 8;
        DATA_WIDTH : integer := 8
    );
    port (
        clk   : in  std_logic;
        we    : in  std_logic;
        waddr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        wdata : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        raddr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        rdata : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity spi_dp_ram;

architecture rtl of spi_dp_ram is
    type ram_t is array (0 to (2 ** ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram : ram_t := (others => (others => '0'));
    signal rdata_q : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
begin
    rdata <= rdata_q;

    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram(to_integer(unsigned(waddr))) <= wdata;
            end if;
            rdata_q <= ram(to_integer(unsigned(raddr)));
        end if;
    end process;
end architecture rtl;
