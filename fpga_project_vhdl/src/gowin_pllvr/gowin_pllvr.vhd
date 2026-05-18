library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Gowin_PLLVR is
    port (
        clkout : out std_logic;
        lock   : out std_logic;
        clkin  : in  std_logic
    );
end entity Gowin_PLLVR;

architecture rtl of Gowin_PLLVR is

    component PLLVR
        generic (
            FCLKIN          : string  := "100.0";
            DYN_IDIV_SEL    : string  := "false";
            IDIV_SEL        : integer := 0;
            DYN_FBDIV_SEL   : string  := "false";
            FBDIV_SEL       : integer := 0;
            DYN_ODIV_SEL    : string  := "false";
            ODIV_SEL        : integer := 8;
            PSDA_SEL        : string  := "0000";
            DYN_DA_EN       : string  := "true";
            DUTYDA_SEL      : string  := "1000";
            CLKOUT_FT_DIR   : bit     := '1';
            CLKOUTP_FT_DIR  : bit     := '1';
            CLKOUT_DLY_STEP : integer := 0;
            CLKOUTP_DLY_STEP: integer := 0;
            CLKFB_SEL       : string  := "internal";
            CLKOUT_BYPASS   : string  := "false";
            CLKOUTP_BYPASS  : string  := "false";
            CLKOUTD_BYPASS  : string  := "false";
            DYN_SDIV_SEL    : integer := 2;
            CLKOUTD_SRC     : string  := "CLKOUT";
            CLKOUTD3_SRC    : string  := "CLKOUT";
            DEVICE          : string  := "GW1NSR-4C"
        );
        port (
            CLKOUT   : out std_logic;
            LOCK     : out std_logic;
            CLKOUTP  : out std_logic;
            CLKOUTD  : out std_logic;
            CLKOUTD3 : out std_logic;
            RESET    : in  std_logic;
            RESET_P  : in  std_logic;
            CLKIN    : in  std_logic;
            CLKFB    : in  std_logic;
            FBDSEL   : in  std_logic_vector(5 downto 0);
            IDSEL    : in  std_logic_vector(5 downto 0);
            ODSEL    : in  std_logic_vector(5 downto 0);
            PSDA     : in  std_logic_vector(3 downto 0);
            DUTYDA   : in  std_logic_vector(3 downto 0);
            FDLY     : in  std_logic_vector(3 downto 0);
            VREN     : in  std_logic
        );
    end component;

    signal gw_vcc : std_logic := '1';
    signal gw_gnd : std_logic := '0';
    signal clkoutp_o, clkoutd_o, clkoutd3_o : std_logic;

begin

    pllvr_inst: PLLVR
        generic map (
            FCLKIN           => "27",
            DYN_IDIV_SEL     => "false",
            IDIV_SEL         => 2,
            DYN_FBDIV_SEL    => "false",
            FBDIV_SEL        => 13,
            DYN_ODIV_SEL     => "false",
            ODIV_SEL         => 8,
            PSDA_SEL         => "0000",
            DYN_DA_EN        => "true",
            DUTYDA_SEL       => "1000",
            CLKOUT_FT_DIR    => '1',
            CLKOUTP_FT_DIR   => '1',
            CLKOUT_DLY_STEP  => 0,
            CLKOUTP_DLY_STEP => 0,
            CLKFB_SEL        => "internal",
            CLKOUT_BYPASS    => "false",
            CLKOUTP_BYPASS   => "false",
            CLKOUTD_BYPASS   => "false",
            DYN_SDIV_SEL     => 2,
            CLKOUTD_SRC      => "CLKOUT",
            CLKOUTD3_SRC     => "CLKOUT",
            DEVICE           => "GW1NSR-4C"
        )
        port map (
            CLKOUT   => clkout,
            LOCK     => lock,
            CLKOUTP  => clkoutp_o,
            CLKOUTD  => clkoutd_o,
            CLKOUTD3 => clkoutd3_o,
            RESET    => gw_gnd,
            RESET_P  => gw_gnd,
            CLKIN    => clkin,
            CLKFB    => gw_gnd,
            FBDSEL   => (others => '0'),
            IDSEL    => (others => '0'),
            ODSEL    => (others => '0'),
            PSDA     => (others => '0'),
            DUTYDA   => (others => '0'),
            FDLY     => (others => '0'),
            VREN     => gw_vcc
        );

end architecture rtl;
