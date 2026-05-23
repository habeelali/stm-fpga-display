library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.svo_pkg.all;

entity svo_term is
    generic (
        SVO_MODE           : svo_mode_t := M_640x480V;
        SVO_FRAMERATE      : integer    := 60;
        SVO_BITS_PER_PIXEL : integer    := 24;
        SVO_BITS_PER_RED   : integer    := 8;
        SVO_BITS_PER_GREEN : integer    := 8;
        SVO_BITS_PER_BLUE  : integer    := 8;
        SVO_BITS_PER_ALPHA : integer    := 0;
        MEM_DEPTH          : integer    := 2048
    );
    port (
        clk    : in  std_logic;
        oclk   : in  std_logic;
        resetn : in  std_logic;

        in_axis_tvalid : in  std_logic;
        in_axis_tready : out std_logic;
        in_axis_tdata  : in  std_logic_vector(7 downto 0);

        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(1 downto 0);
        out_axis_tuser  : out std_logic_vector(0 downto 0)
    );
end entity svo_term;

architecture rtl of svo_term is

    constant SVO_HOR_PIXELS : integer := get_hor_pixels(SVO_MODE);
    constant SVO_VER_PIXELS : integer := get_ver_pixels(SVO_MODE);
    constant MEM_ABITS      : integer := svo_clog2(MEM_DEPTH);

    type mem_t is array (0 to MEM_DEPTH-1) of std_logic_vector(7 downto 0);
    signal mem : mem_t;

    signal mem_start : unsigned(MEM_ABITS-1 downto 0);
    signal mem_stop  : unsigned(MEM_ABITS-1 downto 0);

    signal mem_portA_addr  : unsigned(MEM_ABITS-1 downto 0);
    signal mem_portA_rdata : std_logic_vector(7 downto 0);
    signal mem_portA_wdata : std_logic_vector(7 downto 0);
    signal mem_portA_wen   : std_logic;

    signal mem_portB_addr  : unsigned(MEM_ABITS-1 downto 0);
    signal mem_portB_rdata : std_logic_vector(7 downto 0);

    signal mem_start_GR, mem_stop_GR : unsigned(MEM_ABITS-1 downto 0);
    signal mem_start_B1, mem_stop_B1 : unsigned(MEM_ABITS-1 downto 0);
    signal mem_start_B2, mem_stop_B2 : unsigned(MEM_ABITS-1 downto 0);
    signal mem_start_B3, mem_stop_B3 : unsigned(MEM_ABITS-1 downto 0);
    signal mem_start_B,  mem_stop_B  : unsigned(MEM_ABITS-1 downto 0);

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

    -- Font memory: 128 chars x 8 rows x 8 cols = 8192 bits
    constant fontmem : std_logic_vector(8191 downto 0) :=
        x"00000000000000000000000000000000" &
        x"00000000006092000c000000000000000c1010102010100c1010101010101001" &
        x"101030080808300000003c08102040007c00384048484800000000000000000000" &
        x"004428104428000000004428aa928282000000001028444444000000005824242424" &
        x"24000000001010101010380010000000001c2018040038000000000404040c3400" &
        x"00002020382424580000000800000000000000002038242458000000001038040438" &
        x"00000000304848703838000000007808100820400000000000383c24543c444438" &
        x"000000001c20187c04040000000000003804040404380000000034484848380808" &
        x"00000000b844447840380000000000000000001000080000fe0000000000000044" &
        x"281000000000003820202020202038000000008040201008040200000000003808" &
        x"080808380000007c040810204040007c00001010102828444444000000004444285c" &
        x"2828101000000000282854548282820000001010102828444444000000003844444444" &
        x"44443800000000101010101010107c00000000384400380004443800000000444424" &
        x"1c244444003c00000038444040380440380000000034484848380808000000003844" &
        x"0074545444383800000000000000000010080000000004081020100810040000000000" &
        x"fe00fe0000000000002010080404080800102030300000003030000000000000" &
        x"5c22627814081418000000000064682c4c00000000103c50381478100000002858fe" &
        x"28fe28280000000000000000002828000000001000001010101010100000000000000000" &
        x"00000000000000000000000000000000000000000000000000000000000000000000000000" &
        x"0000000000000000000000000000000000000000000000000000000000000000000000000000" &
        x"00000000000000000000000000000000000000000000000000000000000000000000000000" &
        x"0000000000000000000000000000000000000000000000000000000000000000000000000000" &
        x"00000000000000000000000000000000000000000000000000000000000000000000000000" &
        x"0000000000000000000000000000000000000000000000000000000000000000000000000000" &
        x"00000000000000000000000000000000000000000000000000000000000000000000000000" &
        x"0000000000000000000000000000000000000000000000000000000000000000000000000000" &
        x"00000000000000000000000000000000000000000000000000000000000000000000000000" &
        x"0000000000000000000000000000000000000000000000000000000000000000000000000000" &
        x"00000000000000000000000000000000000000000000000000000000000000000000000000" &
        x"00000000000000000000000000000000";

    function font_lookup(c : std_logic_vector(7 downto 0);
                         fx : unsigned(2 downto 0);
                         fy : unsigned(2 downto 0)) return std_logic is
        variable idx : integer;
    begin
        idx := to_integer(unsigned(c)) * 64 + to_integer(fy) * 8 + to_integer(fx);
        return fontmem(idx);
    end function;

    signal pipeline_en : std_logic;

    -- CDC for oresetn
    signal oresetn_q : std_logic_vector(3 downto 0);
    signal oresetn   : std_logic;

    -- pipeline stage 1
    signal p1_xpos          : unsigned(SVO_XYBITS-1 downto 0);
    signal p1_ypos          : unsigned(SVO_XYBITS-1 downto 0);
    signal p1_start_of_frame: std_logic;
    signal p1_start_of_line : std_logic;
    signal p1_valid         : std_logic;

    -- pipeline stage 2
    signal p2_x, p2_y              : unsigned(2 downto 0);
    signal p2_start_of_frame       : std_logic;
    signal p2_start_of_line        : std_logic;
    signal p2_valid                : std_logic;
    signal p2_found_end            : std_logic;
    signal p2_last_req_remline     : std_logic;
    signal p2_line_start_addr      : unsigned(MEM_ABITS-1 downto 0);
    signal request_remove_line_oclk: std_logic;

    -- pipeline stage 3
    signal p3_x, p3_y        : unsigned(2 downto 0);
    signal p3_start_of_frame : std_logic;
    signal p3_start_of_line  : std_logic;
    signal p3_valid           : std_logic;

    -- pipeline stage 4
    signal p4_c             : std_logic_vector(7 downto 0);
    signal p4_x, p4_y       : unsigned(2 downto 0);
    signal p4_start_of_frame: std_logic;
    signal p4_valid         : std_logic;

    -- pipeline stage 5
    signal p5_outval        : std_logic_vector(1 downto 0);
    signal p5_start_of_frame: std_logic;
    signal p5_valid         : std_logic;

    -- CDC for remove_line
    signal request_remove_line_syn1 : std_logic;
    signal request_remove_line_syn2 : std_logic;
    signal request_remove_line_syn3 : std_logic;
    signal request_remove_line      : std_logic;

    signal remove_line : std_logic;

    signal s_in_axis_tready : std_logic;

    function next_addr(addr : unsigned; depth : integer) return unsigned is
    begin
        if to_integer(addr) = depth-1 then return (others => '0');
        else return addr + 1; end if;
    end function;

begin

    pipeline_en <= not p5_valid or out_axis_tready;

    -- oresetn sync
    process(oclk) begin
        if rising_edge(oclk) then
            oresetn_q <= oresetn_q(2 downto 0) & resetn;
            oresetn   <= oresetn_q(3);
        end if;
    end process;

    -- Dual-port memory
    process(clk) begin
        if rising_edge(clk) then
            if mem_portA_wen = '1' then
                mem(to_integer(mem_portA_addr)) <= mem_portA_wdata;
                mem_portA_rdata <= (others => '0');
            else
                mem_portA_rdata <= mem(to_integer(mem_portA_addr));
            end if;
            mem_start_GR <= bin2gray(mem_start);
            mem_stop_GR  <= bin2gray(mem_stop);
        end if;
    end process;

    process(oclk) begin
        if rising_edge(oclk) then
            if pipeline_en = '1' then
                if mem_portB_addr /= mem_stop_B then
                    mem_portB_rdata <= mem(to_integer(mem_portB_addr));
                else
                    mem_portB_rdata <= (others => '0');
                end if;
            end if;
            mem_start_B1 <= mem_start_GR;
            mem_start_B2 <= mem_start_B1;
            mem_start_B3 <= gray2bin(mem_start_B2);
            mem_stop_B1  <= mem_stop_GR;
            mem_stop_B2  <= mem_stop_B1;
            mem_stop_B3  <= gray2bin(mem_stop_B2);
        end if;
    end process;

    -- remove_line CDC
    process(clk) begin
        if rising_edge(clk) then
            request_remove_line_syn1 <= request_remove_line_oclk;
            request_remove_line_syn2 <= request_remove_line_syn1;
            request_remove_line_syn3 <= request_remove_line_syn2;
            request_remove_line <= request_remove_line_syn2 xor request_remove_line_syn3;
        end if;
    end process;

    in_axis_tready <= s_in_axis_tready;

    s_in_axis_tready <= '1' when next_addr(mem_stop, MEM_DEPTH) /= mem_start and remove_line = '0' else '0';

    -- Input interface
    process(clk) begin
        if rising_edge(clk) then
            mem_portA_wen   <= '0';
            mem_portA_wdata <= in_axis_tdata;
            mem_portA_addr  <= mem_start;

            if request_remove_line = '1' and mem_start /= mem_stop then
                mem_portA_addr <= next_addr(mem_start, MEM_DEPTH);
                mem_start      <= next_addr(mem_start, MEM_DEPTH);
                remove_line    <= '1';
            end if;

            if resetn = '0' then
                remove_line <= '0';
                mem_start   <= (others => '0');
                mem_stop    <= (others => '0');
            else
                if remove_line = '1' then
                    if mem_portA_rdata = x"0A" or mem_start = mem_stop then
                        remove_line <= '0';
                    else
                        mem_portA_addr <= next_addr(mem_start, MEM_DEPTH);
                        mem_start      <= next_addr(mem_start, MEM_DEPTH);
                    end if;
                elsif next_addr(mem_stop, MEM_DEPTH) = mem_start then
                    if mem_portA_addr = mem_start then
                        mem_portA_addr <= next_addr(mem_start, MEM_DEPTH);
                        mem_start      <= next_addr(mem_start, MEM_DEPTH);
                        remove_line    <= '1';
                    end if;
                elsif in_axis_tvalid = '1' and s_in_axis_tready = '1' then
                    if unsigned(in_axis_tdata) >= 32 or in_axis_tdata = x"0A" then
                        mem_stop       <= next_addr(mem_stop, MEM_DEPTH);
                        mem_portA_addr <= mem_stop;
                        mem_portA_wen  <= '1';
                    elsif in_axis_tdata = x"04" then
                        mem_stop <= mem_start;
                    elsif in_axis_tdata = x"08" then
                        if mem_stop /= mem_start then
                            if mem_stop = 0 then
                                mem_stop <= to_unsigned(MEM_DEPTH-1, MEM_ABITS);
                            else
                                mem_stop <= mem_stop - 1;
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Pipeline stage 1
    process(oclk) begin
        if rising_edge(oclk) then
            if oresetn = '0' then
                p1_xpos  <= (others => '0');
                p1_ypos  <= (others => '0');
                p1_valid <= '0';
            elsif pipeline_en = '1' then
                p1_valid         <= '1';
                if (p1_xpos = 0 and p1_ypos = 0) then
                    p1_start_of_frame <= '1';
                else
                    p1_start_of_frame <= '0';
                end if;
                if p1_xpos = 0 then
                    p1_start_of_line <= '1';
                else
                    p1_start_of_line <= '0';
                end if;
                if p1_xpos = to_unsigned(SVO_HOR_PIXELS-1, SVO_XYBITS) then
                    p1_xpos <= (others => '0');
                    if p1_ypos = to_unsigned(SVO_VER_PIXELS-1, SVO_XYBITS) then
                        p1_ypos <= (others => '0');
                    else
                        p1_ypos <= p1_ypos + 1;
                    end if;
                else
                    p1_xpos <= p1_xpos + 1;
                end if;
            end if;
        end if;
    end process;

    -- Pipeline stage 2
    process(oclk) begin
        if rising_edge(oclk) then
            if oresetn = '0' then
                p2_valid            <= '0';
                p2_found_end        <= '1';
                p2_last_req_remline <= '1';
                request_remove_line_oclk <= '0';
            elsif pipeline_en = '1' then
                p2_start_of_frame <= p1_start_of_frame;
                p2_start_of_line  <= p1_start_of_line;
                p2_valid          <= p1_valid;

                if mem_portB_addr = mem_stop_B then
                    p2_found_end <= '1';
                end if;

                if p1_start_of_frame = '1' then
                    if p2_found_end = '0' and p2_last_req_remline = '0' then
                        request_remove_line_oclk <= not request_remove_line_oclk;
                        p2_last_req_remline      <= '1';
                    else
                        p2_last_req_remline <= '0';
                    end if;
                    mem_stop_B        <= mem_stop_B3;
                    mem_start_B       <= mem_start_B3;
                    mem_portB_addr    <= mem_start_B3;
                    p2_line_start_addr <= mem_start_B3;
                    p2_found_end      <= '0';
                    p2_x <= (others => '0');
                    p2_y <= (others => '0');
                elsif p1_start_of_line = '1' then
                    if p2_y = "111" then
                        if mem_portB_addr /= mem_stop_B then
                            mem_portB_addr    <= next_addr(mem_portB_addr, MEM_DEPTH);
                            p2_line_start_addr <= next_addr(mem_portB_addr, MEM_DEPTH);
                        else
                            p2_line_start_addr <= mem_stop_B;
                        end if;
                    else
                        mem_portB_addr <= p2_line_start_addr;
                    end if;
                    p2_x <= (others => '0');
                    p2_y <= p2_y + 1;
                else
                    if p2_x = "111" then
                        if mem_portB_addr /= mem_stop_B and mem_portB_rdata /= x"0A" then
                            mem_portB_addr <= next_addr(mem_portB_addr, MEM_DEPTH);
                        end if;
                    end if;
                    p2_x <= p2_x + 1;
                end if;
            end if;
        end if;
    end process;

    -- Pipeline stage 3
    process(oclk) begin
        if rising_edge(oclk) then
            if oresetn = '0' then
                p3_valid <= '0';
            elsif pipeline_en = '1' then
                p3_x              <= p2_x;
                p3_y              <= p2_y;
                p3_start_of_frame <= p2_start_of_frame;
                p3_start_of_line  <= p2_start_of_line;
                p3_valid          <= p2_valid;
            end if;
        end if;
    end process;

    -- Pipeline stage 4
    process(oclk) begin
        if rising_edge(oclk) then
            if oresetn = '0' then
                p4_valid <= '0';
            elsif pipeline_en = '1' then
                p4_c              <= mem_portB_rdata;
                p4_x              <= p3_x;
                p4_y              <= p3_y;
                p4_start_of_frame <= p3_start_of_frame;
                p4_valid          <= p3_valid;
            end if;
        end if;
    end process;

    -- Pipeline stage 5
    process(oclk) begin
        if rising_edge(oclk) then
            if oresetn = '0' then
                p5_valid <= '0';
            elsif pipeline_en = '1' then
                if unsigned(p4_c) >= 32 and unsigned(p4_c) < 128 then
                    if font_lookup(p4_c, p4_x, p4_y) = '1' then
                        p5_outval <= "10";
                    else
                        p5_outval <= "01";
                    end if;
                else
                    p5_outval <= "00";
                end if;
                p5_start_of_frame <= p4_start_of_frame;
                p5_valid          <= p4_valid;
            end if;
        end if;
    end process;

    out_axis_tvalid <= p5_valid;
    out_axis_tdata  <= p5_outval;
    out_axis_tuser  <= p5_start_of_frame & "";

end architecture rtl;
