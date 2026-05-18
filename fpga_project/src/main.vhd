library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity main is
    port (
        sys_clk : in  std_logic;
        led     : out std_logic
    );
end entity main;

architecture rtl of main is
    signal cnt : unsigned(27 downto 0) := (others => '0');
    signal phase : unsigned(1 downto 0);
begin

    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            cnt <= cnt + 1;
        end if;
    end process;

    phase <= cnt(27 downto 26);

    process(phase, cnt)
    begin
        case phase is
            -- slow blink ~1.6 Hz
            when "00" => led <= cnt(24);
            -- fast blink ~6.4 Hz
            when "01" => led <= cnt(22);
            -- double-pulse: on, off, on, long off
            when "10" =>
                case cnt(23 downto 21) is
                    when "000"  => led <= '1';
                    when "001"  => led <= '0';
                    when "010"  => led <= '1';
                    when others => led <= '0';
                end case;
            -- SOS-ish: fast triple then pause
            when others =>
                case cnt(22 downto 20) is
                    when "000" | "010" | "100" => led <= cnt(19);
                    when others                => led <= '0';
                end case;
        end case;
    end process;

end architecture rtl;
