library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Gowin_CLKDIV is
    port (
        clkout : out std_logic;
        hclkin : in  std_logic;
        resetn : in  std_logic
    );
end entity Gowin_CLKDIV;

architecture rtl of Gowin_CLKDIV is

    component CLKDIV
        generic (
            DIV_MODE : string  := "2";
            GSREN    : string  := "false"
        );
        port (
            CLKOUT : out std_logic;
            HCLKIN : in  std_logic;
            RESETN : in  std_logic;
            CALIB  : in  std_logic
        );
    end component;

    signal gw_gnd : std_logic := '0';

begin

    clkdiv_inst: CLKDIV
        generic map (
            DIV_MODE => "5",
            GSREN    => "false"
        )
        port map (
            CLKOUT => clkout,
            HCLKIN => hclkin,
            RESETN => resetn,
            CALIB  => gw_gnd
        );

end architecture rtl;
