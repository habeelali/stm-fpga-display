library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

entity svo_tcard is
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

        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        out_axis_tuser  : out std_logic_vector(0 downto 0)
    );
end entity svo_tcard;

architecture rtl of svo_tcard is

    constant SVO_HOR_PIXELS : integer := get_hor_pixels(SVO_MODE);
    constant SVO_VER_PIXELS : integer := get_ver_pixels(SVO_MODE);

    constant HOFFSET  : integer := ((32 - (SVO_HOR_PIXELS mod 32)) mod 32) / 2;
    constant VOFFSET  : integer := ((32 - (SVO_VER_PIXELS mod 32)) mod 32) / 2;
    constant HOR_CELLS : integer := (SVO_HOR_PIXELS + 31) / 32;
    constant VER_CELLS : integer := (SVO_VER_PIXELS + 31) / 32;
    constant BAR_W    : integer := (HOR_CELLS - 8 - (HOR_CELLS mod 2)) / 2;

    constant X1 : integer := 2;
    constant X2 : integer := 2 + BAR_W;
    constant X3 : integer := HOR_CELLS - 4 - BAR_W;
    constant X4 : integer := HOR_CELLS - 4;

    -- best_y_params: returns blk/gap/off for known vertical resolutions
    function best_y_blk(ver : integer) return integer is
    begin
        if ver = 480  then return 3;
        elsif ver = 600  then return 3;
        elsif ver = 768  then return 4;
        elsif ver = 1080 then return 6;
        else return 0; end if;
    end function;
    function best_y_gap(ver : integer) return integer is
    begin
        if ver = 480  then return 1;
        elsif ver = 600  then return 2;
        elsif ver = 768  then return 3;
        elsif ver = 1080 then return 2;
        else return 0; end if;
    end function;
    function best_y_off(ver : integer) return integer is
    begin
        if ver = 480  then return 1;
        elsif ver = 600  then return 2;
        elsif ver = 768  then return 2;
        elsif ver = 1080 then return 5;
        else return 0; end if;
    end function;

    constant Y_BLK : integer := best_y_blk(SVO_VER_PIXELS);
    constant Y_GAP : integer := best_y_gap(SVO_VER_PIXELS);
    constant Y_OFF : integer := best_y_off(SVO_VER_PIXELS);

    constant Y1 : integer := 0*Y_BLK + 0*Y_GAP + Y_OFF;
    constant Y2 : integer := 1*Y_BLK + 0*Y_GAP + Y_OFF;
    constant Y3 : integer := 1*Y_BLK + 1*Y_GAP + Y_OFF;
    constant Y4 : integer := 2*Y_BLK + 1*Y_GAP + Y_OFF;
    constant Y5 : integer := 2*Y_BLK + 2*Y_GAP + Y_OFF;
    constant Y6 : integer := 3*Y_BLK + 2*Y_GAP + Y_OFF;

    -- bolt bitmap: 32 rows x 32 cols, row 0 at MSB (bit 1023)
    constant bolt_bitmap : std_logic_vector(1023 downto 0) :=
        "00000000000000000000000000000000" &
        "01111111000000000000000001111111" &
        "01111100000000000000000000011111" &
        "01110000000000000000000000000111" &
        "01100000000000000000000000000011" &
        "01100000000000000000000000000011" &
        "01000000000000000000000000000001" &
        "01000000000000000000000000000001" &
        "00000000000000000000000000000000" &
        "00000000000000000000000000000000" &
        "00000000000000000000000000000000" &
        "00000000000000000000000000000000" &
        "00000000000000111100000000000000" &
        "00000000000001111110000000000000" &
        "00000000000011111111000000000000" &
        "00000000000011111111000000000000" &
        "00000000000011111111000000000000" &
        "00000000000011111111000000000000" &
        "00000000000001111110000000000000" &
        "00000000000000111100000000000000" &
        "00000000000000000000000000000000" &
        "00000000000000000000000000000000" &
        "00000000000000000000000000000000" &
        "00000000000000000000000000000000" &
        "00000000000000000000000000000000" &
        "01000000000000000000000000000001" &
        "01000000000000000000000000000001" &
        "01100000000000000000000000000011" &
        "01100000000000000000000000000011" &
        "01110000000000000000000000000111" &
        "01111100000000000000000000011111" &
        "01111111000000000000000001111111";

    signal hcursor : unsigned(SVO_XYBITS-1 downto 0);
    signal vcursor : unsigned(SVO_XYBITS-1 downto 0);
    signal x_cell  : unsigned(SVO_XYBITS-7 downto 0);
    signal y_cell  : unsigned(SVO_XYBITS-7 downto 0);
    signal xoff    : unsigned(4 downto 0);
    signal yoff    : unsigned(4 downto 0);
    signal rng     : unsigned(31 downto 0);
    signal s_out_axis_tvalid : std_logic;
    signal s_out_axis_tdata  : std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
    signal s_out_axis_tuser  : std_logic_vector(0 downto 0);

    -- Animation state (adapted from Project F "Racing the Beam")
    constant BOUNCE_SIZE  : integer := 80;
    constant BOUNCE_SPEED : integer := 2;
    signal frame_ctr   : unsigned(7 downto 0);
    signal frame_tick  : std_logic;
    signal bounce_x    : unsigned(SVO_XYBITS-1 downto 0);
    signal bounce_y    : unsigned(SVO_XYBITS-1 downto 0);
    signal bounce_dx   : std_logic;
    signal bounce_dy   : std_logic;

begin
    out_axis_tvalid <= s_out_axis_tvalid;
    out_axis_tdata  <= s_out_axis_tdata;
    out_axis_tuser  <= s_out_axis_tuser;

    process(clk)
        variable r   : unsigned(SVO_BITS_PER_RED-1   downto 0);
        variable g   : unsigned(SVO_BITS_PER_GREEN-1 downto 0);
        variable b   : unsigned(SVO_BITS_PER_BLUE-1  downto 0);
        variable rng_v : unsigned(31 downto 0);
        variable bmp_idx : integer;
        variable xc  : integer;
        variable yc  : integer;
        variable xo  : integer;
        variable yo  : integer;
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                hcursor <= (others => '0');
                vcursor <= (others => '0');
                x_cell  <= (others => '0');
                y_cell  <= (others => '0');
                xoff    <= to_unsigned(HOFFSET, 5);
                yoff    <= to_unsigned(VOFFSET, 5);
                rng     <= (others => '0');
                s_out_axis_tvalid <= '0';
                s_out_axis_tdata  <= (others => '0');
                s_out_axis_tuser  <= (others => '0');
                frame_ctr   <= (others => '0');
                frame_tick  <= '0';
                bounce_x    <= to_unsigned(100, SVO_XYBITS);
                bounce_y    <= to_unsigned(100, SVO_XYBITS);
                bounce_dx   <= '0';
                bounce_dy   <= '0';
            elsif s_out_axis_tvalid = '0' or out_axis_tready = '1' then
                -- Frame tick: one cycle at start of each frame
                if hcursor = 0 and vcursor = 0 then
                    frame_tick <= '1';
                else
                    frame_tick <= '0';
                end if;

                -- Bouncing box position update (Project F "Bounce")
                if frame_tick = '1' then
                    frame_ctr <= frame_ctr + 1;
                    -- horizontal
                    if bounce_dx = '0' then
                        if bounce_x + BOUNCE_SIZE + BOUNCE_SPEED >= SVO_HOR_PIXELS then
                            bounce_x  <= to_unsigned(SVO_HOR_PIXELS - BOUNCE_SIZE, SVO_XYBITS);
                            bounce_dx <= '1';
                        else
                            bounce_x <= bounce_x + BOUNCE_SPEED;
                        end if;
                    else
                        if bounce_x < BOUNCE_SPEED then
                            bounce_x  <= (others => '0');
                            bounce_dx <= '0';
                        else
                            bounce_x <= bounce_x - BOUNCE_SPEED;
                        end if;
                    end if;
                    -- vertical
                    if bounce_dy = '0' then
                        if bounce_y + BOUNCE_SIZE + BOUNCE_SPEED >= SVO_VER_PIXELS then
                            bounce_y  <= to_unsigned(SVO_VER_PIXELS - BOUNCE_SIZE, SVO_XYBITS);
                            bounce_dy <= '1';
                        else
                            bounce_y <= bounce_y + BOUNCE_SPEED;
                        end if;
                    else
                        if bounce_y < BOUNCE_SPEED then
                            bounce_y  <= (others => '0');
                            bounce_dy <= '0';
                        else
                            bounce_y <= bounce_y - BOUNCE_SPEED;
                        end if;
                    end if;
                end if;
                rng_v := rng;
                xc := to_integer(x_cell);
                yc := to_integer(y_cell);
                xo := to_integer(xoff);
                yo := to_integer(yoff);

                if hcursor = 0 then
                    rng_v := to_unsigned(to_integer(y_cell), 32) xor to_unsigned(123456789, 32);
                end if;

                -- xorshift32
                rng_v := rng_v xor (rng_v(18 downto 0) & "0000000000000");  -- << 13
                rng_v := rng_v xor ("00000000000000000" & rng_v(31 downto 17)); -- >> 17
                rng_v := rng_v xor (rng_v(26 downto 0) & "00000");           -- << 5

                if xoff = 0 or hcursor = 0 then
                    r := to_unsigned(0, SVO_BITS_PER_RED);
                    g := to_unsigned(0, SVO_BITS_PER_GREEN);
                    b := to_unsigned(0, SVO_BITS_PER_BLUE);
                    if rng_v(0) = '1' then r := r + 16; end if;
                    if rng_v(1) = '1' then r := r + 16; end if;
                    if rng_v(2) = '1' then r := r + 31; end if;
                    if rng_v(3) = '1' then g := g + 16; end if;
                    if rng_v(4) = '1' then g := g + 16; end if;
                    if rng_v(5) = '1' then g := g + 31; end if;
                    if rng_v(6) = '1' then b := b + 16; end if;
                    if rng_v(7) = '1' then b := b + 16; end if;
                    if rng_v(8) = '1' then b := b + 31; end if;
                    if r = 0 and g = 0 and b = 0 then
                        r := to_unsigned(32, SVO_BITS_PER_RED);
                        g := to_unsigned(32, SVO_BITS_PER_GREEN);
                        b := to_unsigned(32, SVO_BITS_PER_BLUE);
                    end if;
                else
                    r := (others => '0');
                    g := (others => '0');
                    b := (others => '0');
                    -- carry over from registered signals not recalculated here;
                    -- will be overwritten by color bars below if applicable
                    -- (tdata from previous cycle retained in out_axis_tdata)
                    r := unsigned(s_out_axis_tdata(SVO_BITS_PER_RED-1 downto 0));
                    g := unsigned(s_out_axis_tdata(SVO_BITS_PER_RED+SVO_BITS_PER_GREEN-1 downto SVO_BITS_PER_RED));
                    b := unsigned(s_out_axis_tdata(SVO_BITS_PER_RED+SVO_BITS_PER_GREEN+SVO_BITS_PER_BLUE-1 downto SVO_BITS_PER_RED+SVO_BITS_PER_GREEN));
                end if;

                if xoff = "11111" or yoff = "11111" then
                    r := (others => '0');
                    g := (others => '0');
                    b := (others => '0');
                end if;

                if SVO_VER_PIXELS >= 480 then
                    -- Raster bar overlay (Project F "Raster Bars"): animated horizontal bands in background
                    if hcursor < SVO_HOR_PIXELS and vcursor < SVO_VER_PIXELS then
                        if to_integer(vcursor + frame_ctr) mod 16 < 3 then
                            r := resize(frame_ctr(7 downto 5) & "00000", SVO_BITS_PER_RED);
                            g := resize(frame_ctr(7 downto 5) & "00000", SVO_BITS_PER_GREEN);
                            b := resize(not frame_ctr(7 downto 5) & "00000", SVO_BITS_PER_BLUE);
                        end if;
                    end if;
                    if xc > X1 and xc <= X2 and yc > Y1 and yc <= Y2 then r := to_unsigned(63, SVO_BITS_PER_RED); g := (others => '0'); b := (others => '0'); end if;
                    if xc > X1 and xc <= X2 and yc > Y3 and yc <= Y4 then r := (others => '0'); g := to_unsigned(63, SVO_BITS_PER_GREEN); b := (others => '0'); end if;
                    if xc > X1 and xc <= X2 and yc > Y5 and yc <= Y6 then r := (others => '0'); g := (others => '0'); b := to_unsigned(63, SVO_BITS_PER_BLUE); end if;
                    if xc > X3 and xc <= X4 and yc > Y1 and yc <= Y2 then r := (others => '0'); g := to_unsigned(63, SVO_BITS_PER_GREEN); b := to_unsigned(63, SVO_BITS_PER_BLUE); end if;
                    if xc > X3 and xc <= X4 and yc > Y3 and yc <= Y4 then r := to_unsigned(63, SVO_BITS_PER_RED); g := (others => '0'); b := to_unsigned(63, SVO_BITS_PER_BLUE); end if;
                    if xc > X3 and xc <= X4 and yc > Y5 and yc <= Y6 then r := to_unsigned(63, SVO_BITS_PER_RED); g := to_unsigned(63, SVO_BITS_PER_GREEN); b := (others => '0'); end if;
                    if xoff = "11111" and (xc = X2 or xc = X4) then r := (others => '0'); g := (others => '0'); b := (others => '0'); end if;
                    if yoff = "11111" and (yc = Y2 or yc = Y4 or yc = Y6) then r := (others => '0'); g := (others => '0'); b := (others => '0'); end if;
                end if;

                s_out_axis_tvalid <= '1';

                -- Bouncing box rendering (Project F "Bounce")
                if hcursor >= bounce_x and hcursor < bounce_x + BOUNCE_SIZE and
                   vcursor >= bounce_y and vcursor < bounce_y + BOUNCE_SIZE then
                    -- Box fill: cycling colour based on frame counter
                    r := resize(frame_ctr(7 downto 2) & "00", SVO_BITS_PER_RED);
                    g := resize(frame_ctr(6 downto 1) & "00", SVO_BITS_PER_GREEN);
                    b := resize(frame_ctr(5 downto 0) & "00", SVO_BITS_PER_BLUE);
                    -- Box border
                    if hcursor = bounce_x or hcursor = bounce_x + BOUNCE_SIZE - 1 or
                       vcursor = bounce_y or vcursor = bounce_y + BOUNCE_SIZE - 1 then
                        r := (others => '1');
                        g := (others => '1');
                        b := (others => '1');
                    end if;
                end if;
                if (xc = 1 or xc = HOR_CELLS-2) and (yc = 1 or yc = VER_CELLS-2) then
                    bmp_idx := yo * 32 + xo;
                    if bolt_bitmap(bmp_idx) = '1' then
                        s_out_axis_tdata <= (others => '1');
                    else
                        s_out_axis_tdata <= (others => '0');
                    end if;
                else
                    s_out_axis_tdata <= std_logic_vector(b) & std_logic_vector(g) & std_logic_vector(r);
                end if;
                if (hcursor = 0 and vcursor = 0) then
                    s_out_axis_tuser(0) <= '1';
                else
                    s_out_axis_tuser(0) <= '0';
                end if;

                rng <= rng_v;

                if hcursor = to_unsigned(SVO_HOR_PIXELS-1, SVO_XYBITS) then
                    hcursor <= (others => '0');
                    x_cell  <= (others => '0');
                    xoff    <= to_unsigned(HOFFSET, 5);
                    if vcursor = to_unsigned(SVO_VER_PIXELS-1, SVO_XYBITS) then
                        vcursor <= (others => '0');
                        y_cell  <= (others => '0');
                        yoff    <= to_unsigned(VOFFSET, 5);
                    else
                        vcursor <= vcursor + 1;
                        if yoff = "11111" then
                            y_cell <= y_cell + 1;
                        end if;
                        yoff <= yoff + 1;
                    end if;
                else
                    hcursor <= hcursor + 1;
                    if xoff = "11111" then
                        x_cell <= x_cell + 1;
                    end if;
                    xoff <= xoff + 1;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
