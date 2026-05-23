library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

entity svo_enc is
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

        in_axis_tvalid : in  std_logic;
        in_axis_tready : out std_logic;
        in_axis_tdata  : in  std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        in_axis_tuser  : in  std_logic_vector(0 downto 0);

        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        out_axis_tuser  : out std_logic_vector(3 downto 0)
    );
end entity svo_enc;

architecture rtl of svo_enc is

    constant SVO_HOR_PIXELS     : integer := get_hor_pixels(SVO_MODE);
    constant SVO_VER_PIXELS     : integer := get_ver_pixels(SVO_MODE);
    constant SVO_HOR_FRONT_PORCH: integer := get_hor_fp(SVO_MODE);
    constant SVO_HOR_SYNC       : integer := get_hor_sync(SVO_MODE);
    constant SVO_HOR_BACK_PORCH : integer := get_hor_bp(SVO_MODE);
    constant SVO_VER_FRONT_PORCH: integer := get_ver_fp(SVO_MODE);
    constant SVO_VER_SYNC       : integer := get_ver_sync(SVO_MODE);
    constant SVO_VER_BACK_PORCH : integer := get_ver_bp(SVO_MODE);
    constant SVO_HOR_TOTAL      : integer := SVO_HOR_FRONT_PORCH + SVO_HOR_SYNC + SVO_HOR_BACK_PORCH + SVO_HOR_PIXELS;
    constant SVO_VER_TOTAL      : integer := SVO_VER_FRONT_PORCH + SVO_VER_SYNC + SVO_VER_BACK_PORCH + SVO_VER_PIXELS;

    type ctrl_fifo_t  is array (0 to 3) of std_logic_vector(3 downto 0);
    type pixel_fifo_t is array (0 to 7) of std_logic_vector(SVO_BITS_PER_PIXEL downto 0);
    type out_fifo_t   is array (0 to 3) of std_logic_vector(SVO_BITS_PER_PIXEL+3 downto 0);

    signal ctrl_fifo  : ctrl_fifo_t;
    signal pixel_fifo : pixel_fifo_t;
    signal out_fifo   : out_fifo_t;

    signal ctrl_fifo_wraddr  : unsigned(1 downto 0);
    signal ctrl_fifo_rdaddr  : unsigned(1 downto 0);
    signal pixel_fifo_wraddr : unsigned(2 downto 0);
    signal pixel_fifo_rdaddr : unsigned(2 downto 0);
    signal out_fifo_wraddr   : unsigned(1 downto 0);
    signal out_fifo_rdaddr   : unsigned(1 downto 0);

    signal ctrl_fifo_fill  : unsigned(1 downto 0);
    signal pixel_fifo_fill : unsigned(2 downto 0);
    signal out_fifo_fill   : unsigned(1 downto 0);

    signal wait_for_fifos : unsigned(1 downto 0);

    signal s_in_axis_tready  : std_logic;
    signal s_out_axis_tvalid : std_logic;

begin
    in_axis_tready  <= s_in_axis_tready;
    out_axis_tvalid <= s_out_axis_tvalid;

    ctrl_fifo_fill  <= ctrl_fifo_wraddr  - ctrl_fifo_rdaddr;
    pixel_fifo_fill <= pixel_fifo_wraddr - pixel_fifo_rdaddr;
    out_fifo_fill   <= out_fifo_wraddr   - out_fifo_rdaddr;

    -- Process 1: generate ctrl entries (hsync/vsync/blank timing)
    process(clk)
        variable hcursor   : unsigned(SVO_XYBITS-1 downto 0);
        variable vcursor   : unsigned(SVO_XYBITS-1 downto 0);
        variable is_hsync  : std_logic;
        variable is_vsync  : std_logic;
        variable is_blank  : std_logic;
        variable is_sof    : std_logic;
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                ctrl_fifo_wraddr <= (others => '0');
                hcursor := (others => '0');
                vcursor := (others => '0');
            elsif ctrl_fifo_wraddr + 1 /= ctrl_fifo_rdaddr then
                is_blank := '0';
                is_hsync := '0';
                is_vsync := '0';

                if hcursor < to_unsigned(SVO_HOR_FRONT_PORCH, SVO_XYBITS) then
                    is_blank := '1';
                elsif hcursor < to_unsigned(SVO_HOR_FRONT_PORCH + SVO_HOR_SYNC, SVO_XYBITS) then
                    is_blank := '1'; is_hsync := '1';
                elsif hcursor < to_unsigned(SVO_HOR_FRONT_PORCH + SVO_HOR_SYNC + SVO_HOR_BACK_PORCH, SVO_XYBITS) then
                    is_blank := '1';
                end if;

                if vcursor < to_unsigned(SVO_VER_FRONT_PORCH, SVO_XYBITS) then
                    is_blank := '1';
                elsif vcursor < to_unsigned(SVO_VER_FRONT_PORCH + SVO_VER_SYNC, SVO_XYBITS) then
                    is_blank := '1'; is_vsync := '1';
                elsif vcursor < to_unsigned(SVO_VER_FRONT_PORCH + SVO_VER_SYNC + SVO_VER_BACK_PORCH, SVO_XYBITS) then
                    is_blank := '1';
                end if;

                if (hcursor = 0 and vcursor = 0) then
                    is_sof := '1';
                else
                    is_sof := '0';
                end if;
                ctrl_fifo(to_integer(ctrl_fifo_wraddr)) <= is_blank & is_vsync & is_hsync & is_sof;
                ctrl_fifo_wraddr <= ctrl_fifo_wraddr + 1;

                if hcursor = to_unsigned(SVO_HOR_TOTAL-1, SVO_XYBITS) then
                    hcursor := (others => '0');
                    if vcursor = to_unsigned(SVO_VER_TOTAL-1, SVO_XYBITS) then
                        vcursor := (others => '0');
                    else
                        vcursor := vcursor + 1;
                    end if;
                else
                    hcursor := hcursor + 1;
                end if;
            end if;
        end if;
    end process;

    -- Process 2: accept pixel data into pixel fifo
    process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                pixel_fifo_wraddr <= (others => '0');
                s_in_axis_tready <= '0';
            else
                if in_axis_tvalid = '1' and s_in_axis_tready = '1' then
                    pixel_fifo(to_integer(pixel_fifo_wraddr)) <= in_axis_tuser & in_axis_tdata;
                    pixel_fifo_wraddr <= pixel_fifo_wraddr + 1;
                end if;
                if (pixel_fifo_wraddr + 2 = pixel_fifo_rdaddr) or
                   (pixel_fifo_wraddr + 1 = pixel_fifo_rdaddr) then
                    s_in_axis_tready <= '0';
                else
                    s_in_axis_tready <= '1';
                end if;
            end if;
        end if;
    end process;

    -- Process 3: merge ctrl and pixel fifos into out fifo
    process(clk)
        variable cf_entry  : std_logic_vector(3 downto 0);
        variable pf_entry  : std_logic_vector(SVO_BITS_PER_PIXEL downto 0);
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                ctrl_fifo_rdaddr  <= (others => '0');
                pixel_fifo_rdaddr <= (others => '0');
                out_fifo_wraddr   <= (others => '0');
            else
                if ctrl_fifo_rdaddr /= ctrl_fifo_wraddr and
                   pixel_fifo_rdaddr /= pixel_fifo_wraddr and
                   out_fifo_wraddr + 1 /= out_fifo_rdaddr then

                    cf_entry := ctrl_fifo(to_integer(ctrl_fifo_rdaddr));
                    pf_entry := pixel_fifo(to_integer(pixel_fifo_rdaddr));

                    -- cf_entry: bit3=blank, bit2=vsync, bit1=hsync, bit0=sof
                    -- pf_entry: bit(BPP)=tuser[0]=sof_pixel
                    if cf_entry(0) = '1' and pf_entry(SVO_BITS_PER_PIXEL) = '0' then
                        -- drop non-start pixels until frame sync
                        pixel_fifo_rdaddr <= pixel_fifo_rdaddr + 1;
                    elsif cf_entry(3) = '1' then
                        -- blank period: output ctrl with zero pixel
                        out_fifo(to_integer(out_fifo_wraddr)) <=
                            cf_entry & (SVO_BITS_PER_PIXEL-1 downto 0 => '0');
                        out_fifo_wraddr  <= out_fifo_wraddr + 1;
                        ctrl_fifo_rdaddr <= ctrl_fifo_rdaddr + 1;
                    else
                        out_fifo(to_integer(out_fifo_wraddr)) <=
                            cf_entry & pf_entry(SVO_BITS_PER_PIXEL-1 downto 0);
                        out_fifo_wraddr   <= out_fifo_wraddr + 1;
                        ctrl_fifo_rdaddr  <= ctrl_fifo_rdaddr + 1;
                        pixel_fifo_rdaddr <= pixel_fifo_rdaddr + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Process 4: output from out fifo
    process(clk)
        variable next_rd : unsigned(1 downto 0);
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                wait_for_fifos   <= (others => '0');
                out_fifo_rdaddr  <= (others => '0');
                s_out_axis_tvalid  <= '0';
                out_axis_tdata   <= (others => '0');
                out_axis_tuser   <= (others => '0');
            elsif wait_for_fifos < 3 or out_fifo_fill = 0 then
                if ctrl_fifo_fill < 3 or pixel_fifo_fill < 6 or out_fifo_fill < 3 then
                    wait_for_fifos <= (others => '0');
                else
                    wait_for_fifos <= wait_for_fifos + 1;
                end if;
            else
                next_rd := out_fifo_rdaddr;
                if s_out_axis_tvalid = '1' and out_axis_tready = '1' then
                    next_rd := next_rd + 1;
                end if;

                if next_rd /= out_fifo_wraddr then
                    s_out_axis_tvalid <= '1';
                else
                    s_out_axis_tvalid <= '0';
                end if;
                out_axis_tuser <= out_fifo(to_integer(next_rd))(SVO_BITS_PER_PIXEL+3 downto SVO_BITS_PER_PIXEL);
                out_axis_tdata <= out_fifo(to_integer(next_rd))(SVO_BITS_PER_PIXEL-1 downto 0);
                out_fifo_rdaddr <= next_rd;
            end if;
        end if;
    end process;

end architecture rtl;
