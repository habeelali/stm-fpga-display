library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity svo_openldi is
    port (
        clk    : in  std_logic;
        resetn : in  std_logic;
        de     : in  std_logic;
        vs     : in  std_logic;
        hs     : in  std_logic;
        r      : in  std_logic_vector(5 downto 0);
        g      : in  std_logic_vector(5 downto 0);
        b      : in  std_logic_vector(5 downto 0);
        a0     : out std_logic_vector(6 downto 0);
        a1     : out std_logic_vector(6 downto 0);
        a2     : out std_logic_vector(6 downto 0)
    );
end entity svo_openldi;

architecture rtl of svo_openldi is
begin
    a0 <= g(0) & r(5) & r(4) & r(3) & r(2) & r(1) & r(0);
    a1 <= b(1) & b(0) & g(5) & g(4) & g(3) & g(2) & g(1);
    a2 <= de   & vs   & hs   & b(5) & b(4) & b(3) & b(2);
end architecture rtl;
