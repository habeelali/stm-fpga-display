library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity svo_tmds is
    port (
        clk    : in  std_logic;
        resetn : in  std_logic;
        de     : in  std_logic;
        ctrl   : in  std_logic_vector(1 downto 0);
        din    : in  std_logic_vector(7 downto 0);
        dout   : out std_logic_vector(9 downto 0)
    );
end entity svo_tmds;

architecture rtl of svo_tmds is

    function N1(bits : std_logic_vector(7 downto 0)) return unsigned is
        variable cnt : unsigned(3 downto 0);
    begin
        cnt := (others => '0');
        for i in 0 to 7 loop
            if bits(i) = '1' then cnt := cnt + 1; end if;
        end loop;
        return cnt;
    end function;

    function N0(bits : std_logic_vector(7 downto 0)) return unsigned is
        variable cnt : unsigned(3 downto 0);
    begin
        cnt := (others => '0');
        for i in 0 to 7 loop
            if bits(i) = '0' then cnt := cnt + 1; end if;
        end loop;
        return cnt;
    end function;

    signal dout_buf2 : std_logic_vector(9 downto 0);
    signal q_out     : std_logic_vector(9 downto 0);
    signal cnt       : signed(7 downto 0);

begin

    process(clk)
        variable q_m        : std_logic_vector(8 downto 0);
        variable N0_q_m     : unsigned(3 downto 0);
        variable N1_q_m     : unsigned(3 downto 0);
        variable cnt_next   : signed(7 downto 0);
        variable cnt_tmp    : signed(7 downto 0);
        variable q_out_next : std_logic_vector(9 downto 0);
        variable D          : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            D := din;
            if resetn = '0' then
                cnt   <= (others => '0');
                q_out <= (others => '0');
            elsif de = '0' then
                cnt <= (others => '0');
                case ctrl is
                    when "00"   => q_out <= "1101010100";
                    when "01"   => q_out <= "0010101011";
                    when "10"   => q_out <= "0101010100";
                    when others => q_out <= "1010101011";
                end case;
            else
                if (N1(D) > 4) or (N1(D) = 4 and D(0) = '0') then
                    q_m(0) := D(0);
                    q_m(1) := q_m(0) xnor D(1);
                    q_m(2) := q_m(1) xnor D(2);
                    q_m(3) := q_m(2) xnor D(3);
                    q_m(4) := q_m(3) xnor D(4);
                    q_m(5) := q_m(4) xnor D(5);
                    q_m(6) := q_m(5) xnor D(6);
                    q_m(7) := q_m(6) xnor D(7);
                    q_m(8) := '0';
                else
                    q_m(0) := D(0);
                    q_m(1) := q_m(0) xor D(1);
                    q_m(2) := q_m(1) xor D(2);
                    q_m(3) := q_m(2) xor D(3);
                    q_m(4) := q_m(3) xor D(4);
                    q_m(5) := q_m(4) xor D(5);
                    q_m(6) := q_m(5) xor D(6);
                    q_m(7) := q_m(6) xor D(7);
                    q_m(8) := '1';
                end if;

                N0_q_m := N0(q_m(7 downto 0));
                N1_q_m := N1(q_m(7 downto 0));

                if (cnt = 0) or (N1_q_m = N0_q_m) then
                    q_out_next(9)          := not q_m(8);
                    q_out_next(8)          := q_m(8);
                    if q_m(8) = '1' then
                        q_out_next(7 downto 0) := q_m(7 downto 0);
                    else
                        q_out_next(7 downto 0) := not q_m(7 downto 0);
                    end if;
                    if q_m(8) = '0' then
                        cnt_next := cnt + signed(resize(N0_q_m, 8) - resize(N1_q_m, 8));
                    else
                        cnt_next := cnt + signed(resize(N1_q_m, 8) - resize(N0_q_m, 8));
                    end if;
                elsif ((cnt > 0) and (N1_q_m > N0_q_m)) or
                      ((cnt < 0) and (N0_q_m > N1_q_m)) then
                    q_out_next(9)          := '1';
                    q_out_next(8)          := q_m(8);
                    q_out_next(7 downto 0) := not q_m(7 downto 0);
                    cnt_tmp := cnt + signed(resize(N0_q_m, 8) - resize(N1_q_m, 8));
                    if q_m(8) = '1' then
                        cnt_next := cnt_tmp + 2;
                    else
                        cnt_next := cnt_tmp;
                    end if;
                else
                    q_out_next(9)          := '0';
                    q_out_next(8)          := q_m(8);
                    q_out_next(7 downto 0) := q_m(7 downto 0);
                    cnt_tmp := cnt + signed(resize(N1_q_m, 8) - resize(N0_q_m, 8));
                    if q_m(8) = '1' then
                        cnt_next := cnt_tmp;
                    else
                        cnt_next := cnt_tmp - 2;
                    end if;
                end if;

                cnt   <= cnt_next;
                q_out <= q_out_next;
            end if;

            dout_buf2 <= q_out;
            dout      <= dout_buf2;
        end if;
    end process;

end architecture rtl;
