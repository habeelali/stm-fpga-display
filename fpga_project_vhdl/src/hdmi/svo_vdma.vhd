library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

-- svo_vdma_crossclock_fifo
entity svo_vdma_crossclock_fifo is
    generic (
        WIDTH : integer := 8;
        DEPTH : integer := 12;
        ABITS : integer := 4
    );
    port (
        in_clk    : in  std_logic;
        in_resetn : in  std_logic;
        in_enable : in  std_logic;
        in_data   : in  std_logic_vector(WIDTH-1 downto 0);
        in_free   : out unsigned(ABITS-1 downto 0);

        out_clk    : in  std_logic;
        out_resetn : in  std_logic;
        out_enable : in  std_logic;
        out_data   : out std_logic_vector(WIDTH-1 downto 0);
        out_avail  : out unsigned(ABITS-1 downto 0)
    );
end entity svo_vdma_crossclock_fifo;

architecture rtl of svo_vdma_crossclock_fifo is

    type fifo_mem_t is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
    signal fifo : fifo_mem_t;

    signal in_ptr       : unsigned(ABITS-1 downto 0);
    signal in_ptr_gray  : unsigned(ABITS-1 downto 0);
    signal out_ptr      : unsigned(ABITS-1 downto 0);
    signal out_ptr_gray : unsigned(ABITS-1 downto 0);

    signal out_ptr_for_in_clk : unsigned(ABITS-1 downto 0);
    signal in_ptr_for_out_clk : unsigned(ABITS-1 downto 0);

    signal sync_in_ptr_0, sync_in_ptr_1, sync_in_ptr_2   : unsigned(ABITS-1 downto 0);
    signal sync_out_ptr_0, sync_out_ptr_1, sync_out_ptr_2 : unsigned(ABITS-1 downto 0);

    function bin2gray(b : unsigned) return unsigned is
        variable g : unsigned(b'range);
    begin
        g(b'length-1) := b(b'length-1);
        for i in 0 to b'length-2 loop
            g(i) := b(i) xor b(i+1);
        end loop;
        return g;
    end function;

    function gray2bin(g : unsigned) return unsigned is
        variable b   : unsigned(g'range);
        variable acc : std_logic;
    begin
        acc := '0';
        for i in g'length-1 downto 0 loop
            acc := acc xor g(i);
            b(i) := acc;
        end loop;
        return b;
    end function;

begin

    process(in_clk)
    begin
        if rising_edge(in_clk) then
            if in_resetn = '0' then
                in_ptr      <= (others => '0');
                in_ptr_gray <= (others => '0');
            else
                if in_enable = '1' then
                    fifo(to_integer(in_ptr)) <= in_data;
                    in_ptr      <= in_ptr + 1;
                    in_ptr_gray <= bin2gray(in_ptr + 1);
                end if;
            end if;

            sync_out_ptr_0    <= out_ptr_gray;
            sync_out_ptr_1    <= sync_out_ptr_0;
            sync_out_ptr_2    <= sync_out_ptr_1;
            out_ptr_for_in_clk <= gray2bin(sync_out_ptr_2);

            in_free <= to_unsigned(DEPTH, ABITS) - in_ptr + out_ptr_for_in_clk - 1;
        end if;
    end process;

    process(out_clk)
    begin
        if rising_edge(out_clk) then
            if out_resetn = '0' then
                out_ptr      <= (others => '0');
                out_ptr_gray <= (others => '0');
            else
                if out_enable = '1' then
                    out_ptr      <= out_ptr + 1;
                    out_ptr_gray <= bin2gray(out_ptr + 1);
                    out_data     <= fifo(to_integer(out_ptr + 1));
                else
                    out_data <= fifo(to_integer(out_ptr));
                end if;
            end if;

            sync_in_ptr_0    <= in_ptr_gray;
            sync_in_ptr_1    <= sync_in_ptr_0;
            sync_in_ptr_2    <= sync_in_ptr_1;
            in_ptr_for_out_clk <= gray2bin(sync_in_ptr_2);

            out_avail <= in_ptr_for_out_clk - out_ptr;
        end if;
    end process;

end architecture rtl;


-- svo_vdma
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

entity svo_vdma is
    generic (
        SVO_MODE           : svo_mode_t := M_640x480V;
        SVO_FRAMERATE      : integer    := 60;
        SVO_BITS_PER_PIXEL : integer    := 24;
        SVO_BITS_PER_RED   : integer    := 8;
        SVO_BITS_PER_GREEN : integer    := 8;
        SVO_BITS_PER_BLUE  : integer    := 8;
        SVO_BITS_PER_ALPHA : integer    := 0;
        MEM_ADDR_WIDTH     : integer    := 32;
        MEM_DATA_WIDTH     : integer    := 64;
        MEM_BURST_LEN      : integer    := 8;
        FIFO_DEPTH         : integer    := 64
    );
    port (
        clk    : in  std_logic;
        oclk   : in  std_logic;
        resetn : in  std_logic;
        frame_irq : out std_logic;

        cfg_axi_awvalid : in  std_logic;
        cfg_axi_awready : out std_logic;
        cfg_axi_awaddr  : in  std_logic_vector(7 downto 0);
        cfg_axi_wvalid  : in  std_logic;
        cfg_axi_wready  : out std_logic;
        cfg_axi_wdata   : in  std_logic_vector(31 downto 0);
        cfg_axi_bvalid  : out std_logic;
        cfg_axi_bready  : in  std_logic;
        cfg_axi_arvalid : in  std_logic;
        cfg_axi_arready : out std_logic;
        cfg_axi_araddr  : in  std_logic_vector(7 downto 0);
        cfg_axi_rvalid  : out std_logic;
        cfg_axi_rready  : in  std_logic;
        cfg_axi_rdata   : out std_logic_vector(31 downto 0);

        mem_axi_araddr  : out std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
        mem_axi_arlen   : out std_logic_vector(7 downto 0);
        mem_axi_arsize  : out std_logic_vector(2 downto 0);
        mem_axi_arprot  : out std_logic_vector(2 downto 0);
        mem_axi_arburst : out std_logic_vector(1 downto 0);
        mem_axi_arvalid : out std_logic;
        mem_axi_arready : in  std_logic;

        mem_axi_rdata   : in  std_logic_vector(MEM_DATA_WIDTH-1 downto 0);
        mem_axi_rvalid  : in  std_logic;
        mem_axi_rready  : out std_logic;

        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        out_axis_tuser  : out std_logic_vector(0 downto 0);

        term_axis_tvalid : out std_logic;
        term_axis_tready : in  std_logic;
        term_axis_tdata  : out std_logic_vector(7 downto 0)
    );
end entity svo_vdma;

architecture rtl of svo_vdma is

    constant SVO_HOR_PIXELS  : integer := get_hor_pixels(SVO_MODE);
    constant SVO_VER_PIXELS  : integer := get_ver_pixels(SVO_MODE);
    constant BYTES_PER_PIXEL : integer := (SVO_BITS_PER_PIXEL + 7) / 8;
    constant BYTES_PER_BURST : integer := MEM_BURST_LEN * MEM_DATA_WIDTH / 8;
    constant NUM_PIXELS      : integer := SVO_HOR_PIXELS * SVO_VER_PIXELS;
    constant NUM_PIXELS_WIDTH: integer := svo_clog2(NUM_PIXELS);
    constant NUM_BURSTS      : integer := (NUM_PIXELS * BYTES_PER_PIXEL + BYTES_PER_BURST - 1) / BYTES_PER_BURST;
    constant NUM_BURSTS_WIDTH: integer := svo_clog2(NUM_BURSTS);
    constant NUM_WORDS       : integer := MEM_BURST_LEN * NUM_BURSTS;
    constant NUM_WORDS_WIDTH : integer := svo_clog2(NUM_WORDS);
    constant FIFO_ABITS      : integer := svo_clog2(FIFO_DEPTH);

    signal oresetn_q : std_logic_vector(3 downto 0);
    signal iresetn_q : std_logic_vector(3 downto 0);
    signal oresetn   : std_logic;
    signal iresetn   : std_logic;

    signal reg_startaddr   : std_logic_vector(31 downto 0);
    signal reg_activeframe : std_logic_vector(31 downto 0);
    signal s_cfg_bvalid    : std_logic;
    signal s_cfg_rvalid    : std_logic;
    signal s_cfg_rdata     : std_logic_vector(31 downto 0);
    signal s_term_tvalid   : std_logic;
    signal s_term_tdata    : std_logic_vector(7 downto 0);

    signal s_arvalid : std_logic;
    signal s_araddr  : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
    signal ar_burst_count : unsigned(NUM_BURSTS_WIDTH-1 downto 0);
    signal ar_burst_delay : unsigned(3 downto 0);
    signal ar_flow_ctrl   : std_logic;

    signal r_word_count    : unsigned(NUM_WORDS_WIDTH-1 downto 0);
    signal r_word_count_zero : std_logic;
    signal requested_words : unsigned(FIFO_ABITS downto 0);
    signal s_rready        : std_logic;

    signal fifo_out_en         : std_logic;
    signal fifo_out_first_word : std_logic;
    signal fifo_out_data       : std_logic_vector(MEM_DATA_WIDTH-1 downto 0);
    signal fifo_in_free        : unsigned(FIFO_ABITS-1 downto 0);
    signal fifo_out_avail      : unsigned(FIFO_ABITS-1 downto 0);

    signal outbuf_bytes      : unsigned(7 downto 0);
    signal outbuf_framestart : std_logic;
    signal pixel_count       : unsigned(NUM_PIXELS_WIDTH downto 0);
    signal pixel_data        : std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);

    constant OUTBUF_WIDTH : integer := MEM_DATA_WIDTH + 8*BYTES_PER_PIXEL - 8;
    signal outbuf : std_logic_vector(OUTBUF_WIDTH-1 downto 0);

    component svo_vdma_crossclock_fifo
        generic (WIDTH : integer := 8; DEPTH : integer := 12; ABITS : integer := 4);
        port (
            in_clk : in std_logic; in_resetn : in std_logic;
            in_enable : in std_logic; in_data : in std_logic_vector(WIDTH-1 downto 0);
            in_free : out unsigned(ABITS-1 downto 0);
            out_clk : in std_logic; out_resetn : in std_logic;
            out_enable : in std_logic; out_data : out std_logic_vector(WIDTH-1 downto 0);
            out_avail : out unsigned(ABITS-1 downto 0)
        );
    end component;

    signal fifo_in_data  : std_logic_vector(MEM_DATA_WIDTH downto 0);
    signal fifo_out_data_full : std_logic_vector(MEM_DATA_WIDTH downto 0);

    signal s_cfg_awready : std_logic;
    signal s_cfg_arready : std_logic;

begin

    -- CDC resets
    process(oclk) begin
        if rising_edge(oclk) then
            oresetn_q <= oresetn_q(2 downto 0) & resetn;
            oresetn   <= oresetn_q(3);
        end if;
    end process;
    process(clk) begin
        if rising_edge(clk) then
            iresetn_q <= iresetn_q(2 downto 0) & oresetn;
            iresetn   <= iresetn_q(3);
        end if;
    end process;

    -- AXI-lite config
    s_cfg_awready <= resetn and cfg_axi_awvalid and cfg_axi_wvalid and
                     (not s_cfg_bvalid or cfg_axi_bready) and not s_term_tvalid;
    s_cfg_arready <= resetn and cfg_axi_arvalid and (not s_cfg_rvalid or cfg_axi_rready);
    cfg_axi_awready <= s_cfg_awready;
    cfg_axi_wready  <= s_cfg_awready;
    cfg_axi_arready <= s_cfg_arready;
    cfg_axi_bvalid  <= s_cfg_bvalid;
    cfg_axi_rvalid  <= s_cfg_rvalid;
    cfg_axi_rdata   <= s_cfg_rdata;
    term_axis_tvalid <= s_term_tvalid;
    term_axis_tdata  <= s_term_tdata;

    process(clk) begin
        if rising_edge(clk) then
            if resetn = '0' then
                reg_startaddr  <= (others => '0');
                s_cfg_bvalid   <= '0';
                s_cfg_rvalid   <= '0';
                s_term_tvalid  <= '0';
            else
                if cfg_axi_bready = '1' then s_cfg_bvalid <= '0'; end if;
                if cfg_axi_rready = '1' then s_cfg_rvalid <= '0'; end if;
                if term_axis_tready = '1' then s_term_tvalid <= '0'; end if;
                if s_cfg_awready = '1' then
                    s_cfg_bvalid <= '1';
                    if cfg_axi_awaddr = x"00" then
                        reg_startaddr <= cfg_axi_wdata;
                    elsif cfg_axi_awaddr = x"0C" then
                        s_term_tvalid <= '1';
                        s_term_tdata  <= cfg_axi_wdata(7 downto 0);
                    end if;
                end if;
                if s_cfg_arready = '1' then
                    s_cfg_rvalid <= '1';
                    case cfg_axi_araddr is
                        when x"00"  => s_cfg_rdata <= reg_startaddr;
                        when x"04"  => s_cfg_rdata <= reg_activeframe;
                        when x"08"  => s_cfg_rdata <= std_logic_vector(to_unsigned(SVO_VER_PIXELS, 16)) &
                                                       std_logic_vector(to_unsigned(SVO_HOR_PIXELS, 16));
                        when others => s_cfg_rdata <= (others => '0');
                    end case;
                end if;
            end if;
        end if;
    end process;

    -- Memory AR channel
    mem_axi_arlen   <= std_logic_vector(to_unsigned(MEM_BURST_LEN-1, 8));
    mem_axi_arsize  <= std_logic_vector(to_unsigned(svo_clog2(MEM_DATA_WIDTH/8), 3));
    mem_axi_arprot  <= "000";
    mem_axi_arburst <= "01";
    mem_axi_arvalid <= s_arvalid;
    mem_axi_araddr  <= s_araddr;

    process(clk) begin
        if rising_edge(clk) then
            frame_irq <= '0';
            if ar_burst_delay /= 0 then ar_burst_delay <= ar_burst_delay - 1; end if;
            if iresetn = '0' or resetn = '0' then
                ar_burst_delay <= (others => '0');
                ar_burst_count <= (others => '0');
                s_araddr       <= (others => '0');
                s_arvalid      <= '0';
                reg_activeframe <= (others => '0');
            else
                if unsigned(s_araddr) = 0 then
                    s_araddr        <= reg_startaddr;
                    reg_activeframe <= reg_startaddr;
                elsif mem_axi_arready = '1' and s_arvalid = '1' then
                    s_arvalid      <= '0';
                    ar_burst_delay <= to_unsigned(6, 4);
                elsif ar_flow_ctrl = '1' and s_arvalid = '0' and ar_burst_delay = 0 then
                    s_arvalid <= '1';
                    if ar_burst_count = to_unsigned(NUM_BURSTS-1, NUM_BURSTS_WIDTH) then
                        ar_burst_count <= (others => '0');
                    else
                        ar_burst_count <= ar_burst_count + 1;
                    end if;
                    if ar_burst_count = 0 then
                        s_araddr        <= reg_startaddr;
                        reg_activeframe <= reg_startaddr;
                        if unsigned(reg_startaddr) = 0 then
                            ar_burst_count <= (others => '0');
                            s_arvalid      <= '0';
                        else
                            frame_irq <= '1';
                        end if;
                    else
                        s_araddr <= std_logic_vector(unsigned(s_araddr) +
                                    to_unsigned(MEM_BURST_LEN * MEM_DATA_WIDTH / 8, MEM_ADDR_WIDTH));
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Memory R channel
    r_word_count_zero <= '1' when r_word_count = 0 else '0';
    fifo_in_data <= r_word_count_zero & mem_axi_rdata;

    u_fifo: svo_vdma_crossclock_fifo
        generic map (WIDTH => MEM_DATA_WIDTH+1, DEPTH => FIFO_DEPTH, ABITS => FIFO_ABITS)
        port map (
            in_clk     => clk,
            in_resetn  => resetn,
            in_enable  => mem_axi_rvalid and s_rready,
            in_data    => fifo_in_data,
            in_free    => fifo_in_free,
            out_clk    => oclk,
            out_resetn => oresetn,
            out_enable => fifo_out_en,
            out_data   => fifo_out_data_full,
            out_avail  => fifo_out_avail
        );

    fifo_out_first_word <= fifo_out_data_full(MEM_DATA_WIDTH);
    fifo_out_data       <= fifo_out_data_full(MEM_DATA_WIDTH-1 downto 0);
    mem_axi_rready      <= s_rready;

    process(clk)
        variable rw : unsigned(FIFO_ABITS downto 0);
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                requested_words <= (others => '0');
                s_rready        <= '0';
                r_word_count    <= (others => '0');
                ar_flow_ctrl    <= '0';
            else
                rw := requested_words;
                if s_arvalid = '1' and mem_axi_arready = '1' then
                    rw := rw + MEM_BURST_LEN;
                end if;
                if mem_axi_rvalid = '1' and s_rready = '1' then
                    rw := rw - 1;
                    if r_word_count = to_unsigned(NUM_WORDS-1, NUM_WORDS_WIDTH) then
                        r_word_count <= (others => '0');
                    else
                        r_word_count <= r_word_count + 1;
                    end if;
                end if;
                requested_words <= rw;
                if rw + MEM_BURST_LEN + 4 < fifo_in_free then
                    ar_flow_ctrl <= '1';
                else
                    ar_flow_ctrl <= '0';
                end if;
                if fifo_in_free > 4 then s_rready <= '1'; else s_rready <= '0'; end if;
            end if;
        end if;
    end process;

    -- Output stream
    out_axis_tvalid <= '1' when pixel_count < to_unsigned(NUM_PIXELS, NUM_PIXELS_WIDTH+1) else '0';
    out_axis_tdata  <= pixel_data;
    out_axis_tuser  <= "1" when pixel_count = 0 else "0";

    process(oclk)
        variable ob      : std_logic_vector(OUTBUF_WIDTH-1 downto 0);
        variable ob_bytes: unsigned(7 downto 0);
        variable ob_fs   : std_logic;
    begin
        if rising_edge(oclk) then
            fifo_out_en <= '0';
            if oresetn = '0' then
                outbuf_bytes <= (others => '0');
                pixel_count  <= to_unsigned(NUM_PIXELS, NUM_PIXELS_WIDTH+1);
                outbuf       <= (others => '0');
                outbuf_framestart <= '0';
            else
                ob       := outbuf;
                ob_bytes := outbuf_bytes;
                ob_fs    := outbuf_framestart;

                if fifo_out_avail /= 0 and ob_bytes < BYTES_PER_PIXEL and
                   (fifo_out_first_word = '0' or pixel_count >= to_unsigned(NUM_PIXELS-1, NUM_PIXELS_WIDTH+1)) then
                    ob(MEM_DATA_WIDTH + 8*BYTES_PER_PIXEL - 9 downto 0) :=
                        fifo_out_data & ob(8*BYTES_PER_PIXEL-2 downto 0);
                    ob_bytes := to_unsigned(MEM_DATA_WIDTH/8, 8);
                    ob_fs    := fifo_out_first_word;
                    fifo_out_en <= '1';
                end if;

                if out_axis_tready = '1' then
                    pixel_data <= ob(SVO_BITS_PER_PIXEL-1 downto 0);
                    if ob_fs = '1' or pixel_count > to_unsigned((NUM_WORDS*(MEM_DATA_WIDTH/8) + BYTES_PER_PIXEL - 1) / BYTES_PER_PIXEL, NUM_PIXELS_WIDTH+1) then
                        pixel_count <= (others => '0');
                    else
                        pixel_count <= pixel_count + 1;
                    end if;
                    if ob_bytes < BYTES_PER_PIXEL then
                        ob_bytes := (others => '0');
                    else
                        ob_bytes := ob_bytes - BYTES_PER_PIXEL;
                    end if;
                    ob    := (BYTES_PER_PIXEL*8-1 downto 0 => '0') & ob(OUTBUF_WIDTH-1 downto BYTES_PER_PIXEL*8);
                    ob_fs := '0';
                end if;

                outbuf            <= ob;
                outbuf_bytes      <= ob_bytes;
                outbuf_framestart <= ob_fs;
            end if;
        end if;
    end process;

end architecture rtl;
