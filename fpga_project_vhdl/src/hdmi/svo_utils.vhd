library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

-- svo_axis_pipe
entity svo_axis_pipe is
    generic (
        TDATA_WIDTH : integer := 8;
        TUSER_WIDTH : integer := 1
    );
    port (
        clk    : in  std_logic;
        resetn : in  std_logic;

        in_axis_tvalid : in  std_logic;
        in_axis_tready : out std_logic;
        in_axis_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
        in_axis_tuser  : in  std_logic_vector(TUSER_WIDTH-1 downto 0);

        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(TDATA_WIDTH-1 downto 0);
        out_axis_tuser  : out std_logic_vector(TUSER_WIDTH-1 downto 0);

        pipe_in_tdata   : out std_logic_vector(TDATA_WIDTH-1 downto 0);
        pipe_out_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
        pipe_in_tuser   : out std_logic_vector(TUSER_WIDTH-1 downto 0);
        pipe_out_tuser  : in  std_logic_vector(TUSER_WIDTH-1 downto 0);
        pipe_in_tvalid  : out std_logic;
        pipe_out_tvalid : in  std_logic;
        pipe_enable     : out std_logic
    );
end entity svo_axis_pipe;

architecture rtl of svo_axis_pipe is
    signal tvalid_q0 : std_logic;
    signal tvalid_q1 : std_logic;
    signal tdata_q0  : std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal tdata_q1  : std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal tuser_q0  : std_logic_vector(TUSER_WIDTH-1 downto 0);
    signal tuser_q1  : std_logic_vector(TUSER_WIDTH-1 downto 0);
    signal s_pipe_enable : std_logic;
begin
    in_axis_tready  <= not tvalid_q1;
    out_axis_tvalid <= tvalid_q0 or tvalid_q1;
    out_axis_tdata  <= tdata_q1 when tvalid_q1 = '1' else tdata_q0;
    out_axis_tuser  <= tuser_q1 when tvalid_q1 = '1' else tuser_q0;

    s_pipe_enable   <= in_axis_tvalid and (not tvalid_q1);
    pipe_enable     <= s_pipe_enable;
    pipe_in_tdata   <= in_axis_tdata;
    pipe_in_tuser   <= in_axis_tuser;
    pipe_in_tvalid  <= in_axis_tvalid;

    process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                tvalid_q0 <= '0';
                tvalid_q1 <= '0';
            else
                if s_pipe_enable = '1' then
                    tdata_q0  <= pipe_out_tdata;
                    tdata_q1  <= tdata_q0;
                    tuser_q0  <= pipe_out_tuser;
                    tuser_q1  <= tuser_q0;
                    tvalid_q0 <= pipe_out_tvalid;
                    tvalid_q1 <= tvalid_q0 and not out_axis_tready;
                elsif out_axis_tready = '1' then
                    if tvalid_q1 = '1' then
                        tvalid_q1 <= '0';
                    else
                        tvalid_q0 <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;


-- svo_buf
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

entity svo_buf is
    generic (
        TUSER_WIDTH        : integer    := 1;
        SVO_MODE           : svo_mode_t := M_640x480V;
        SVO_FRAMERATE      : integer    := 60;
        SVO_BITS_PER_PIXEL : integer    := 24;
        SVO_BITS_PER_RED   : integer    := 8;
        SVO_BITS_PER_GREEN : integer    := 8;
        SVO_BITS_PER_BLUE  : integer    := 8;
        SVO_BITS_PER_ALPHA : integer    := 0
    );
    port (
        clk    : in  std_logic;
        resetn : in  std_logic;

        in_axis_tvalid : in  std_logic;
        in_axis_tready : out std_logic;
        in_axis_tdata  : in  std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        in_axis_tuser  : in  std_logic_vector(TUSER_WIDTH-1 downto 0);

        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        out_axis_tuser  : out std_logic_vector(TUSER_WIDTH-1 downto 0)
    );
end entity svo_buf;

architecture rtl of svo_buf is

    component svo_axis_pipe
        generic (
            TDATA_WIDTH : integer := 8;
            TUSER_WIDTH : integer := 1
        );
        port (
            clk    : in  std_logic;
            resetn : in  std_logic;
            in_axis_tvalid  : in  std_logic;
            in_axis_tready  : out std_logic;
            in_axis_tdata   : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
            in_axis_tuser   : in  std_logic_vector(TUSER_WIDTH-1 downto 0);
            out_axis_tvalid : out std_logic;
            out_axis_tready : in  std_logic;
            out_axis_tdata  : out std_logic_vector(TDATA_WIDTH-1 downto 0);
            out_axis_tuser  : out std_logic_vector(TUSER_WIDTH-1 downto 0);
            pipe_in_tdata   : out std_logic_vector(TDATA_WIDTH-1 downto 0);
            pipe_out_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
            pipe_in_tuser   : out std_logic_vector(TUSER_WIDTH-1 downto 0);
            pipe_out_tuser  : in  std_logic_vector(TUSER_WIDTH-1 downto 0);
            pipe_in_tvalid  : out std_logic;
            pipe_out_tvalid : in  std_logic;
            pipe_enable     : out std_logic
        );
    end component;

    signal pipe_in_tdata   : std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
    signal pipe_out_tdata  : std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
    signal pipe_in_tuser   : std_logic_vector(TUSER_WIDTH-1 downto 0);
    signal pipe_out_tuser  : std_logic_vector(TUSER_WIDTH-1 downto 0);
    signal pipe_in_tvalid  : std_logic;
    signal pipe_out_tvalid : std_logic;
    signal pipe_enable     : std_logic;

begin

    u_pipe: svo_axis_pipe
        generic map (
            TDATA_WIDTH => SVO_BITS_PER_PIXEL,
            TUSER_WIDTH => TUSER_WIDTH
        )
        port map (
            clk             => clk,
            resetn          => resetn,
            in_axis_tvalid  => in_axis_tvalid,
            in_axis_tready  => in_axis_tready,
            in_axis_tdata   => in_axis_tdata,
            in_axis_tuser   => in_axis_tuser,
            out_axis_tvalid => out_axis_tvalid,
            out_axis_tready => out_axis_tready,
            out_axis_tdata  => out_axis_tdata,
            out_axis_tuser  => out_axis_tuser,
            pipe_in_tdata   => pipe_in_tdata,
            pipe_out_tdata  => pipe_out_tdata,
            pipe_in_tuser   => pipe_in_tuser,
            pipe_out_tuser  => pipe_out_tuser,
            pipe_in_tvalid  => pipe_in_tvalid,
            pipe_out_tvalid => pipe_out_tvalid,
            pipe_enable     => pipe_enable
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                pipe_out_tvalid <= '0';
            elsif pipe_enable = '1' then
                pipe_out_tdata  <= pipe_in_tdata;
                pipe_out_tuser  <= pipe_in_tuser;
                pipe_out_tvalid <= pipe_in_tvalid;
            end if;
        end if;
    end process;

end architecture rtl;


-- svo_dim
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

entity svo_dim is
    generic (
        SVO_MODE           : svo_mode_t := M_640x480V;
        SVO_FRAMERATE      : integer    := 60;
        SVO_BITS_PER_PIXEL : integer    := 24;
        SVO_BITS_PER_RED   : integer    := 8;
        SVO_BITS_PER_GREEN : integer    := 8;
        SVO_BITS_PER_BLUE  : integer    := 8;
        SVO_BITS_PER_ALPHA : integer    := 0
    );
    port (
        clk    : in  std_logic;
        resetn : in  std_logic;
        enable : in  std_logic;

        in_axis_tvalid : in  std_logic;
        in_axis_tready : out std_logic;
        in_axis_tdata  : in  std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        in_axis_tuser  : in  std_logic_vector(0 downto 0);

        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        out_axis_tuser  : out std_logic_vector(0 downto 0)
    );
end entity svo_dim;

architecture rtl of svo_dim is

    component svo_axis_pipe
        generic (TDATA_WIDTH : integer := 8; TUSER_WIDTH : integer := 1);
        port (
            clk : in std_logic; resetn : in std_logic;
            in_axis_tvalid : in std_logic; in_axis_tready : out std_logic;
            in_axis_tdata : in std_logic_vector(TDATA_WIDTH-1 downto 0);
            in_axis_tuser : in std_logic_vector(TUSER_WIDTH-1 downto 0);
            out_axis_tvalid : out std_logic; out_axis_tready : in std_logic;
            out_axis_tdata : out std_logic_vector(TDATA_WIDTH-1 downto 0);
            out_axis_tuser : out std_logic_vector(TUSER_WIDTH-1 downto 0);
            pipe_in_tdata : out std_logic_vector(TDATA_WIDTH-1 downto 0);
            pipe_out_tdata : in std_logic_vector(TDATA_WIDTH-1 downto 0);
            pipe_in_tuser : out std_logic_vector(TUSER_WIDTH-1 downto 0);
            pipe_out_tuser : in std_logic_vector(TUSER_WIDTH-1 downto 0);
            pipe_in_tvalid : out std_logic; pipe_out_tvalid : in std_logic;
            pipe_enable : out std_logic
        );
    end component;

    signal pipe_in_tdata   : std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
    signal pipe_out_tdata  : std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
    signal pipe_in_tuser   : std_logic_vector(0 downto 0);
    signal pipe_out_tuser  : std_logic_vector(0 downto 0);
    signal pipe_in_tvalid  : std_logic;
    signal pipe_out_tvalid : std_logic;
    signal pipe_enable     : std_logic;

    -- Extract R/G/B channels from pixel word [B|G|R] layout
    signal p_r : std_logic_vector(SVO_BITS_PER_RED-1   downto 0);
    signal p_g : std_logic_vector(SVO_BITS_PER_GREEN-1 downto 0);
    signal p_b : std_logic_vector(SVO_BITS_PER_BLUE-1  downto 0);

begin

    p_r <= pipe_in_tdata(SVO_BITS_PER_RED-1 downto 0);
    p_g <= pipe_in_tdata(SVO_BITS_PER_RED+SVO_BITS_PER_GREEN-1 downto SVO_BITS_PER_RED);
    p_b <= pipe_in_tdata(SVO_BITS_PER_RED+SVO_BITS_PER_GREEN+SVO_BITS_PER_BLUE-1 downto SVO_BITS_PER_RED+SVO_BITS_PER_GREEN);

    u_pipe: svo_axis_pipe
        generic map (TDATA_WIDTH => SVO_BITS_PER_PIXEL, TUSER_WIDTH => 1)
        port map (
            clk => clk, resetn => resetn,
            in_axis_tvalid => in_axis_tvalid, in_axis_tready => in_axis_tready,
            in_axis_tdata => in_axis_tdata, in_axis_tuser => in_axis_tuser,
            out_axis_tvalid => out_axis_tvalid, out_axis_tready => out_axis_tready,
            out_axis_tdata => out_axis_tdata, out_axis_tuser => out_axis_tuser,
            pipe_in_tdata => pipe_in_tdata, pipe_out_tdata => pipe_out_tdata,
            pipe_in_tuser => pipe_in_tuser, pipe_out_tuser => pipe_out_tuser,
            pipe_in_tvalid => pipe_in_tvalid, pipe_out_tvalid => pipe_out_tvalid,
            pipe_enable => pipe_enable
        );

    process(clk)
        variable r_dim : std_logic_vector(SVO_BITS_PER_RED-1   downto 0);
        variable g_dim : std_logic_vector(SVO_BITS_PER_GREEN-1 downto 0);
        variable b_dim : std_logic_vector(SVO_BITS_PER_BLUE-1  downto 0);
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                pipe_out_tvalid <= '0';
            elsif pipe_enable = '1' then
                r_dim := '0' & p_r(SVO_BITS_PER_RED-1   downto 1);
                g_dim := '0' & p_g(SVO_BITS_PER_GREEN-1 downto 1);
                b_dim := '0' & p_b(SVO_BITS_PER_BLUE-1  downto 1);
                if enable = '1' then
                    pipe_out_tdata <= b_dim & g_dim & r_dim;
                else
                    pipe_out_tdata <= pipe_in_tdata;
                end if;
                pipe_out_tuser  <= pipe_in_tuser;
                pipe_out_tvalid <= pipe_in_tvalid;
            end if;
        end if;
    end process;

end architecture rtl;


-- svo_overlay
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

entity svo_overlay is
    generic (
        SVO_MODE           : svo_mode_t := M_640x480V;
        SVO_FRAMERATE      : integer    := 60;
        SVO_BITS_PER_PIXEL : integer    := 24;
        SVO_BITS_PER_RED   : integer    := 8;
        SVO_BITS_PER_GREEN : integer    := 8;
        SVO_BITS_PER_BLUE  : integer    := 8;
        SVO_BITS_PER_ALPHA : integer    := 0
    );
    port (
        clk    : in  std_logic;
        resetn : in  std_logic;
        enable : in  std_logic;

        in_axis_tvalid : in  std_logic;
        in_axis_tready : out std_logic;
        in_axis_tdata  : in  std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        in_axis_tuser  : in  std_logic_vector(0 downto 0);

        over_axis_tvalid : in  std_logic;
        over_axis_tready : out std_logic;
        over_axis_tdata  : in  std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        over_axis_tuser  : in  std_logic_vector(1 downto 0);

        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        out_axis_tuser  : out std_logic_vector(0 downto 0)
    );
end entity svo_overlay;

architecture rtl of svo_overlay is

    component svo_buf
        generic (
            TUSER_WIDTH : integer := 1;
            SVO_MODE : svo_mode_t := M_640x480V;
            SVO_FRAMERATE : integer := 60;
            SVO_BITS_PER_PIXEL : integer := 24;
            SVO_BITS_PER_RED : integer := 8;
            SVO_BITS_PER_GREEN : integer := 8;
            SVO_BITS_PER_BLUE : integer := 8;
            SVO_BITS_PER_ALPHA : integer := 0
        );
        port (
            clk : in std_logic; resetn : in std_logic;
            in_axis_tvalid : in std_logic; in_axis_tready : out std_logic;
            in_axis_tdata : in std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
            in_axis_tuser : in std_logic_vector(TUSER_WIDTH-1 downto 0);
            out_axis_tvalid : out std_logic; out_axis_tready : in std_logic;
            out_axis_tdata : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
            out_axis_tuser : out std_logic_vector(TUSER_WIDTH-1 downto 0)
        );
    end component;

    signal buf_in_tvalid  : std_logic;
    signal buf_in_tready  : std_logic;
    signal buf_in_tdata   : std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
    signal buf_in_tuser   : std_logic_vector(0 downto 0);

    signal buf_over_tvalid : std_logic;
    signal buf_over_tready : std_logic;
    signal buf_over_tdata  : std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
    signal buf_over_tuser  : std_logic_vector(1 downto 0);

    signal buf_out_tvalid : std_logic;
    signal buf_out_tready : std_logic;
    signal buf_out_tdata  : std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
    signal buf_out_tuser  : std_logic_vector(0 downto 0);

    signal active    : std_logic;
    signal skip_in   : std_logic;
    signal skip_over : std_logic;

begin

    active    <= buf_in_tvalid and buf_over_tvalid;
    skip_in   <= (not buf_in_tuser(0))   and buf_over_tuser(0);
    skip_over <= buf_in_tuser(0) and (not buf_over_tuser(0));

    buf_in_tready   <= active and (skip_in   or (not skip_over and buf_out_tready));
    buf_over_tready <= active and (skip_over or (not skip_in   and buf_out_tready));

    buf_out_tvalid <= active and not skip_in and not skip_over;
    buf_out_tdata  <= buf_over_tdata when (enable = '1' and buf_over_tuser(1) = '1')
                      else buf_in_tdata;
    buf_out_tuser  <= buf_over_tuser(0 downto 0) when (enable = '1' and buf_over_tuser(1) = '1')
                      else buf_in_tuser;

    u_buf_in: svo_buf
        generic map (TUSER_WIDTH => 1, SVO_MODE => SVO_MODE,
            SVO_FRAMERATE => SVO_FRAMERATE, SVO_BITS_PER_PIXEL => SVO_BITS_PER_PIXEL,
            SVO_BITS_PER_RED => SVO_BITS_PER_RED, SVO_BITS_PER_GREEN => SVO_BITS_PER_GREEN,
            SVO_BITS_PER_BLUE => SVO_BITS_PER_BLUE, SVO_BITS_PER_ALPHA => SVO_BITS_PER_ALPHA)
        port map (clk => clk, resetn => resetn,
            in_axis_tvalid => in_axis_tvalid, in_axis_tready => in_axis_tready,
            in_axis_tdata => in_axis_tdata, in_axis_tuser => in_axis_tuser,
            out_axis_tvalid => buf_in_tvalid, out_axis_tready => buf_in_tready,
            out_axis_tdata => buf_in_tdata, out_axis_tuser => buf_in_tuser);

    u_buf_over: svo_buf
        generic map (TUSER_WIDTH => 2, SVO_MODE => SVO_MODE,
            SVO_FRAMERATE => SVO_FRAMERATE, SVO_BITS_PER_PIXEL => SVO_BITS_PER_PIXEL,
            SVO_BITS_PER_RED => SVO_BITS_PER_RED, SVO_BITS_PER_GREEN => SVO_BITS_PER_GREEN,
            SVO_BITS_PER_BLUE => SVO_BITS_PER_BLUE, SVO_BITS_PER_ALPHA => SVO_BITS_PER_ALPHA)
        port map (clk => clk, resetn => resetn,
            in_axis_tvalid => over_axis_tvalid, in_axis_tready => over_axis_tready,
            in_axis_tdata => over_axis_tdata, in_axis_tuser => over_axis_tuser,
            out_axis_tvalid => buf_over_tvalid, out_axis_tready => buf_over_tready,
            out_axis_tdata => buf_over_tdata, out_axis_tuser => buf_over_tuser);

    u_buf_out: svo_buf
        generic map (TUSER_WIDTH => 1, SVO_MODE => SVO_MODE,
            SVO_FRAMERATE => SVO_FRAMERATE, SVO_BITS_PER_PIXEL => SVO_BITS_PER_PIXEL,
            SVO_BITS_PER_RED => SVO_BITS_PER_RED, SVO_BITS_PER_GREEN => SVO_BITS_PER_GREEN,
            SVO_BITS_PER_BLUE => SVO_BITS_PER_BLUE, SVO_BITS_PER_ALPHA => SVO_BITS_PER_ALPHA)
        port map (clk => clk, resetn => resetn,
            in_axis_tvalid => buf_out_tvalid, in_axis_tready => buf_out_tready,
            in_axis_tdata => buf_out_tdata, in_axis_tuser => buf_out_tuser,
            out_axis_tvalid => out_axis_tvalid, out_axis_tready => out_axis_tready,
            out_axis_tdata => out_axis_tdata, out_axis_tuser => out_axis_tuser);

end architecture rtl;


-- svo_rect
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

entity svo_rect is
    generic (
        SVO_MODE           : svo_mode_t := M_640x480V;
        SVO_FRAMERATE      : integer    := 60;
        SVO_BITS_PER_PIXEL : integer    := 24;
        SVO_BITS_PER_RED   : integer    := 8;
        SVO_BITS_PER_GREEN : integer    := 8;
        SVO_BITS_PER_BLUE  : integer    := 8;
        SVO_BITS_PER_ALPHA : integer    := 0
    );
    port (
        clk    : in  std_logic;
        resetn : in  std_logic;
        x1     : in  std_logic_vector(11 downto 0);
        y1     : in  std_logic_vector(11 downto 0);
        x2     : in  std_logic_vector(11 downto 0);
        y2     : in  std_logic_vector(11 downto 0);

        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        out_axis_tuser  : out std_logic_vector(2 downto 0)
    );
end entity svo_rect;

architecture rtl of svo_rect is
    constant SVO_HOR_PIXELS : integer := get_hor_pixels(SVO_MODE);
    constant SVO_VER_PIXELS : integer := get_ver_pixels(SVO_MODE);

    signal x    : unsigned(SVO_XYBITS-1 downto 0);
    signal y    : unsigned(SVO_XYBITS-1 downto 0);
    signal on_x : std_logic;
    signal on_y : std_logic;
    signal in_x : std_logic;
    signal in_y : std_logic;
    signal border : std_logic;
begin
    on_x   <= '1' when (x = unsigned(x1)) or (x = unsigned(x2)) else '0';
    on_y   <= '1' when (y = unsigned(y1)) or (y = unsigned(y2)) else '0';
    border <= in_x and in_y and (on_x or on_y);

    process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                x    <= (others => '0');
                y    <= (others => '0');
                in_x <= '0';
                in_y <= '0';
                out_axis_tvalid <= '0';
            else
                if out_axis_tvalid = '1' and out_axis_tready = '1' then
                    if x = to_unsigned(SVO_HOR_PIXELS-1, SVO_XYBITS) then
                        x <= (others => '0');
                        if y = to_unsigned(SVO_VER_PIXELS-1, SVO_XYBITS) then
                            y <= (others => '0');
                        else
                            y <= y + 1;
                        end if;
                    else
                        x <= x + 1;
                    end if;
                end if;

                if x = unsigned(x1) then in_x <= '1'; end if;
                if y = unsigned(y1) then in_y <= '1'; end if;
                if x = unsigned(x2) then in_x <= '0'; end if;
                if y = unsigned(y2) and x = unsigned(x2) then in_y <= '0'; end if;

                out_axis_tvalid    <= '1';
                out_axis_tdata     <= (others => not border);
                out_axis_tuser(0)  <= '1' when (x = 0 and y = 0) else '0';
                out_axis_tuser(1)  <= in_x and in_y;
                out_axis_tuser(2)  <= border;
            end if;
        end if;
    end process;
end architecture rtl;
