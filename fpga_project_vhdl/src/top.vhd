library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

entity top is
    port (
        clk       : in  std_logic;
        resetn    : in  std_logic;
        spi_sclk  : in  std_logic;
        spi_cs_n  : in  std_logic;
        spi_mosi  : in  std_logic;
        tmds_clk_n: out std_logic;
        tmds_clk_p: out std_logic;
        tmds_d_n  : out std_logic_vector(2 downto 0);
        tmds_d_p  : out std_logic_vector(2 downto 0)
    );
end entity top;

architecture rtl of top is

    component Gowin_PLLVR
        port (
            clkout : out std_logic;
            lock   : out std_logic;
            clkin  : in  std_logic
        );
    end component;

    component Gowin_CLKDIV
        port (
            clkout : out std_logic;
            hclkin : in  std_logic;
            resetn : in  std_logic
        );
    end component;

    component Reset_Sync
        port (
            clk      : in  std_logic;
            ext_reset: in  std_logic;
            resetn   : out std_logic
        );
    end component;

    component svo_hdmi
        generic (
            SVO_MODE           : svo_mode_t;
            SVO_FRAMERATE      : integer;
            SVO_BITS_PER_PIXEL : integer;
            SVO_BITS_PER_RED   : integer;
            SVO_BITS_PER_GREEN : integer;
            SVO_BITS_PER_BLUE  : integer;
            SVO_BITS_PER_ALPHA : integer
        );
        port (
            clk          : in  std_logic;
            resetn       : in  std_logic;
            clk_pixel    : in  std_logic;
            clk_5x_pixel : in  std_logic;
            locked       : in  std_logic;
            spi_sclk     : in  std_logic;
            spi_cs_n     : in  std_logic;
            spi_mosi     : in  std_logic;
            tmds_clk_n   : out std_logic;
            tmds_clk_p   : out std_logic;
            tmds_d_n     : out std_logic_vector(2 downto 0);
            tmds_d_p     : out std_logic_vector(2 downto 0)
        );
    end component;

    signal clk_p5      : std_logic;
    signal clk_p       : std_logic;
    signal pll_lock    : std_logic;
    signal sys_resetn  : std_logic;

begin

    u_pll: Gowin_PLLVR
        port map (
            clkout => clk_p5,
            lock   => pll_lock,
            clkin  => clk
        );

    u_div: Gowin_CLKDIV
        port map (
            clkout => clk_p,
            hclkin => clk_p5,
            resetn => pll_lock
        );

    u_rst: Reset_Sync
        port map (
            clk       => clk_p,
            ext_reset => resetn and pll_lock,
            resetn    => sys_resetn
        );

    u_hdmi: svo_hdmi
        generic map (
            SVO_MODE           => M_640x480V,
            SVO_FRAMERATE      => 60,
            SVO_BITS_PER_PIXEL => 24,
            SVO_BITS_PER_RED   => 8,
            SVO_BITS_PER_GREEN => 8,
            SVO_BITS_PER_BLUE  => 8,
            SVO_BITS_PER_ALPHA => 0
        )
        port map (
            clk          => clk_p,
            resetn       => sys_resetn,
            clk_pixel    => clk_p,
            clk_5x_pixel => clk_p5,
            locked       => pll_lock,
            spi_sclk     => spi_sclk,
            spi_cs_n     => spi_cs_n,
            spi_mosi     => spi_mosi,
            tmds_clk_n   => tmds_clk_n,
            tmds_clk_p   => tmds_clk_p,
            tmds_d_n     => tmds_d_n,
            tmds_d_p     => tmds_d_p
        );

end architecture rtl;


-- Reset_Sync entity
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Reset_Sync is
    port (
        clk       : in  std_logic;
        ext_reset : in  std_logic;
        resetn    : out std_logic
    );
end entity Reset_Sync;

architecture rtl of Reset_Sync is
    signal reset_cnt : unsigned(3 downto 0) := (others => '0');
begin
    resetn <= '1' when reset_cnt = "1111" else '0';

    process(clk, ext_reset)
    begin
        if ext_reset = '0' then
            reset_cnt <= (others => '0');
        elsif rising_edge(clk) then
            if reset_cnt /= "1111" then
                reset_cnt <= reset_cnt + 1;
            end if;
        end if;
    end process;
end architecture rtl;
