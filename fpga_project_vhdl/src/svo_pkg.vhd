library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package svo_pkg is

    constant SVO_XYBITS : integer := 14;

    type svo_mode_t is (
        M_640x480V,   M_640x480,    M_960x540,    M_768x576,
        M_1280x854R,  M_2560x2048R, M_1920x1200,  M_480x320R,
        M_1280x768R,  M_2560x1440R, M_2048x1536,  M_1024x576,
        M_320x200,    M_384x288R,   M_1280x1024R, M_768x576R,
        M_2048x1536R, M_1024x576R,  M_1680x1050R, M_1280x854,
        M_2560x2048,  M_1440x900R,  M_2048x1080,  M_1152x768R,
        M_4096x2160,  M_4096x2160R, M_800x480,    M_2560x1080R,
        M_1440x1080R, M_854x480,    M_480x320,    M_1920x1200R,
        M_3840x2160,  M_1400x1050,  M_854x480R,   M_1680x1050,
        M_320x200R,   M_1920x1080R, M_1920x1080,  M_2560x1440,
        M_1440x900,   M_1024x600,   M_1400x1050R, M_1366x768,
        M_1440x1080,  M_1600x900,   M_64x48T,     M_640x480R,
        M_352x288R,   M_1024x768,   M_800x600,    M_1280x960,
        M_1024x768R,  M_1280x960R,  M_1600x900R,  M_800x600R,
        M_1280x800,   M_384x288,    M_352x288,    M_800x480R,
        M_1440x960,   M_3840x2160R, M_2048x1080R, M_1280x800R,
        M_1366x768R,  M_1600x1200R, M_2560x1600,  M_1600x1200,
        M_320x240,    M_1152x864,   M_1440x960R,  M_2560x1080,
        M_1152x768,   M_1280x720,   M_1152x864R,  M_1024x600R,
        M_1280x1024,  M_1280x768,   M_1280x720R,  M_2560x1600R,
        M_320x240R
    );

    function get_hor_pixels(mode : svo_mode_t) return integer;
    function get_ver_pixels(mode : svo_mode_t) return integer;
    function get_hor_fp    (mode : svo_mode_t) return integer;
    function get_hor_sync  (mode : svo_mode_t) return integer;
    function get_hor_bp    (mode : svo_mode_t) return integer;
    function get_ver_fp    (mode : svo_mode_t) return integer;
    function get_ver_sync  (mode : svo_mode_t) return integer;
    function get_ver_bp    (mode : svo_mode_t) return integer;

    function svo_clog2(v : integer) return integer;
    function svo_max(a : integer; b : integer) return integer;

end package svo_pkg;

package body svo_pkg is

    function get_hor_pixels(mode : svo_mode_t) return integer is
        variable r : integer;
    begin
        r := 0;
        case mode is
            when M_640x480V   => r := 640;
            when M_960x540    => r := 960;
            when M_768x576    => r := 768;
            when M_1280x854R  => r := 1280;
            when M_2560x2048R => r := 2560;
            when M_1920x1200  => r := 1920;
            when M_480x320R   => r := 480;
            when M_1280x768R  => r := 1280;
            when M_2560x1440R => r := 2560;
            when M_2048x1536  => r := 2048;
            when M_1024x576   => r := 1024;
            when M_320x200    => r := 320;
            when M_384x288R   => r := 384;
            when M_1280x1024R => r := 1280;
            when M_768x576R   => r := 768;
            when M_2048x1536R => r := 2048;
            when M_1024x576R  => r := 1024;
            when M_1680x1050R => r := 1680;
            when M_1280x854   => r := 1280;
            when M_2560x2048  => r := 2560;
            when M_1440x900R  => r := 1440;
            when M_2048x1080  => r := 2048;
            when M_1152x768R  => r := 1152;
            when M_4096x2160  => r := 4096;
            when M_4096x2160R => r := 4096;
            when M_800x480    => r := 800;
            when M_2560x1080R => r := 2560;
            when M_1440x1080R => r := 1440;
            when M_854x480    => r := 854;
            when M_640x480    => r := 640;
            when M_480x320    => r := 480;
            when M_1920x1200R => r := 1920;
            when M_3840x2160  => r := 3840;
            when M_1400x1050  => r := 1400;
            when M_854x480R   => r := 854;
            when M_1680x1050  => r := 1680;
            when M_320x200R   => r := 320;
            when M_1920x1080R => r := 1920;
            when M_1920x1080  => r := 1920;
            when M_2560x1440  => r := 2560;
            when M_1440x900   => r := 1440;
            when M_1024x600   => r := 1024;
            when M_1400x1050R => r := 1400;
            when M_1366x768   => r := 1366;
            when M_1440x1080  => r := 1440;
            when M_1600x900   => r := 1600;
            when M_64x48T     => r := 64;
            when M_640x480R   => r := 640;
            when M_352x288R   => r := 352;
            when M_1024x768   => r := 1024;
            when M_800x600    => r := 800;
            when M_1280x960   => r := 1280;
            when M_1024x768R  => r := 1024;
            when M_1280x960R  => r := 1280;
            when M_1600x900R  => r := 1600;
            when M_800x600R   => r := 800;
            when M_1280x800   => r := 1280;
            when M_384x288    => r := 384;
            when M_352x288    => r := 352;
            when M_800x480R   => r := 800;
            when M_1440x960   => r := 1440;
            when M_3840x2160R => r := 3840;
            when M_2048x1080R => r := 2048;
            when M_1280x800R  => r := 1280;
            when M_1366x768R  => r := 1366;
            when M_1600x1200R => r := 1600;
            when M_2560x1600  => r := 2560;
            when M_1600x1200  => r := 1600;
            when M_320x240    => r := 320;
            when M_1152x864   => r := 1152;
            when M_1440x960R  => r := 1440;
            when M_2560x1080  => r := 2560;
            when M_1152x768   => r := 1152;
            when M_1280x720   => r := 1280;
            when M_1152x864R  => r := 1152;
            when M_1024x600R  => r := 1024;
            when M_1280x1024  => r := 1280;
            when M_1280x768   => r := 1280;
            when M_1280x720R  => r := 1280;
            when M_2560x1600R => r := 2560;
            when M_320x240R   => r := 320;
        end case;
        return r;
    end function;

    function get_ver_pixels(mode : svo_mode_t) return integer is
        variable r : integer;
    begin
        r := 0;
        case mode is
            when M_640x480V   => r := 480;
            when M_960x540    => r := 540;
            when M_768x576    => r := 576;
            when M_1280x854R  => r := 854;
            when M_2560x2048R => r := 2048;
            when M_1920x1200  => r := 1200;
            when M_480x320R   => r := 320;
            when M_1280x768R  => r := 768;
            when M_2560x1440R => r := 1440;
            when M_2048x1536  => r := 1536;
            when M_1024x576   => r := 576;
            when M_320x200    => r := 200;
            when M_384x288R   => r := 288;
            when M_1280x1024R => r := 1024;
            when M_768x576R   => r := 576;
            when M_2048x1536R => r := 1536;
            when M_1024x576R  => r := 576;
            when M_1680x1050R => r := 1050;
            when M_1280x854   => r := 854;
            when M_2560x2048  => r := 2048;
            when M_1440x900R  => r := 900;
            when M_2048x1080  => r := 1080;
            when M_1152x768R  => r := 768;
            when M_4096x2160  => r := 2160;
            when M_4096x2160R => r := 2160;
            when M_800x480    => r := 480;
            when M_2560x1080R => r := 1080;
            when M_1440x1080R => r := 1080;
            when M_854x480    => r := 480;
            when M_640x480    => r := 480;
            when M_480x320    => r := 320;
            when M_1920x1200R => r := 1200;
            when M_3840x2160  => r := 2160;
            when M_1400x1050  => r := 1050;
            when M_854x480R   => r := 480;
            when M_1680x1050  => r := 1050;
            when M_320x200R   => r := 200;
            when M_1920x1080R => r := 1080;
            when M_1920x1080  => r := 1080;
            when M_2560x1440  => r := 1440;
            when M_1440x900   => r := 900;
            when M_1024x600   => r := 600;
            when M_1400x1050R => r := 1050;
            when M_1366x768   => r := 768;
            when M_1440x1080  => r := 1080;
            when M_1600x900   => r := 900;
            when M_64x48T     => r := 48;
            when M_640x480R   => r := 480;
            when M_352x288R   => r := 288;
            when M_1024x768   => r := 768;
            when M_800x600    => r := 600;
            when M_1280x960   => r := 960;
            when M_1024x768R  => r := 768;
            when M_1280x960R  => r := 960;
            when M_1600x900R  => r := 900;
            when M_800x600R   => r := 600;
            when M_1280x800   => r := 800;
            when M_384x288    => r := 288;
            when M_352x288    => r := 288;
            when M_800x480R   => r := 480;
            when M_1440x960   => r := 960;
            when M_3840x2160R => r := 2160;
            when M_2048x1080R => r := 1080;
            when M_1280x800R  => r := 800;
            when M_1366x768R  => r := 768;
            when M_1600x1200R => r := 1200;
            when M_2560x1600  => r := 1600;
            when M_1600x1200  => r := 1200;
            when M_320x240    => r := 240;
            when M_1152x864   => r := 864;
            when M_1440x960R  => r := 960;
            when M_2560x1080  => r := 1080;
            when M_1152x768   => r := 768;
            when M_1280x720   => r := 720;
            when M_1152x864R  => r := 864;
            when M_1024x600R  => r := 600;
            when M_1280x1024  => r := 1024;
            when M_1280x768   => r := 768;
            when M_1280x720R  => r := 720;
            when M_2560x1600R => r := 1600;
            when M_320x240R   => r := 240;
        end case;
        return r;
    end function;

    function get_hor_fp(mode : svo_mode_t) return integer is
        variable r : integer;
    begin
        r := 0;
        case mode is
            when M_640x480V   => r := 16;
            when M_960x540    => r := 128;
            when M_768x576    => r := 32;
            when M_1280x854R  => r := 48;
            when M_2560x2048R => r := 48;
            when M_1920x1200  => r := 136;
            when M_480x320R   => r := 48;
            when M_1280x768R  => r := 48;
            when M_2560x1440R => r := 48;
            when M_2048x1536  => r := 160;
            when M_1024x576   => r := 40;
            when M_320x200    => r := 16;
            when M_384x288R   => r := 48;
            when M_1280x1024R => r := 48;
            when M_768x576R   => r := 48;
            when M_2048x1536R => r := 48;
            when M_1024x576R  => r := 48;
            when M_1680x1050R => r := 48;
            when M_1280x854   => r := 72;
            when M_2560x2048  => r := 208;
            when M_1440x900R  => r := 48;
            when M_2048x1080  => r := 128;
            when M_1152x768R  => r := 48;
            when M_4096x2160  => r := 336;
            when M_4096x2160R => r := 48;
            when M_800x480    => r := 24;
            when M_2560x1080R => r := 48;
            when M_1440x1080R => r := 48;
            when M_854x480    => r := 24;
            when M_640x480    => r := 24;
            when M_480x320    => r := 16;
            when M_1920x1200R => r := 48;
            when M_3840x2160  => r := 320;
            when M_1400x1050  => r := 88;
            when M_854x480R   => r := 48;
            when M_1680x1050  => r := 104;
            when M_320x200R   => r := 48;
            when M_1920x1080R => r := 48;
            when M_1920x1080  => r := 128;
            when M_2560x1440  => r := 192;
            when M_1440x900   => r := 88;
            when M_1024x600   => r := 48;
            when M_1400x1050R => r := 48;
            when M_1366x768   => r := 72;
            when M_1440x1080  => r := 88;
            when M_1600x900   => r := 96;
            when M_64x48T     => r := 2;
            when M_640x480R   => r := 48;
            when M_352x288R   => r := 48;
            when M_1024x768   => r := 48;
            when M_800x600    => r := 32;
            when M_1280x960   => r := 80;
            when M_1024x768R  => r := 48;
            when M_1280x960R  => r := 48;
            when M_1600x900R  => r := 48;
            when M_800x600R   => r := 48;
            when M_1280x800   => r := 72;
            when M_384x288    => r := 16;
            when M_352x288    => r := 8;
            when M_800x480R   => r := 48;
            when M_1440x960   => r := 88;
            when M_3840x2160R => r := 48;
            when M_2048x1080R => r := 48;
            when M_1280x800R  => r := 48;
            when M_1366x768R  => r := 48;
            when M_1600x1200R => r := 48;
            when M_2560x1600  => r := 200;
            when M_1600x1200  => r := 112;
            when M_320x240    => r := 16;
            when M_1152x864   => r := 64;
            when M_1440x960R  => r := 48;
            when M_2560x1080  => r := 160;
            when M_1152x768   => r := 64;
            when M_1280x720   => r := 64;
            when M_1152x864R  => r := 48;
            when M_1024x600R  => r := 48;
            when M_1280x1024  => r := 88;
            when M_1280x768   => r := 64;
            when M_1280x720R  => r := 48;
            when M_2560x1600R => r := 48;
            when M_320x240R   => r := 48;
        end case;
        return r;
    end function;

    function get_hor_sync(mode : svo_mode_t) return integer is
        variable r : integer;
    begin
        r := 0;
        case mode is
            when M_640x480V   => r := 96;
            when M_960x540    => r := 112;
            when M_768x576    => r := 72;
            when M_1280x854R  => r := 32;
            when M_2560x2048R => r := 32;
            when M_1920x1200  => r := 200;
            when M_480x320R   => r := 32;
            when M_1280x768R  => r := 32;
            when M_2560x1440R => r := 32;
            when M_2048x1536  => r := 216;
            when M_1024x576   => r := 96;
            when M_320x200    => r := 24;
            when M_384x288R   => r := 32;
            when M_1280x1024R => r := 32;
            when M_768x576R   => r := 32;
            when M_2048x1536R => r := 32;
            when M_1024x576R  => r := 32;
            when M_1680x1050R => r := 32;
            when M_1280x854   => r := 128;
            when M_2560x2048  => r := 280;
            when M_1440x900R  => r := 32;
            when M_2048x1080  => r := 216;
            when M_1152x768R  => r := 32;
            when M_4096x2160  => r := 448;
            when M_4096x2160R => r := 32;
            when M_800x480    => r := 72;
            when M_2560x1080R => r := 32;
            when M_1440x1080R => r := 32;
            when M_854x480    => r := 80;
            when M_640x480    => r := 56;
            when M_480x320    => r := 40;
            when M_1920x1200R => r := 32;
            when M_3840x2160  => r := 416;
            when M_1400x1050  => r := 144;
            when M_854x480R   => r := 32;
            when M_1680x1050  => r := 176;
            when M_320x200R   => r := 32;
            when M_1920x1080R => r := 32;
            when M_1920x1080  => r := 200;
            when M_2560x1440  => r := 272;
            when M_1440x900   => r := 144;
            when M_1024x600   => r := 96;
            when M_1400x1050R => r := 32;
            when M_1366x768   => r := 136;
            when M_1440x1080  => r := 152;
            when M_1600x900   => r := 160;
            when M_64x48T     => r := 4;
            when M_640x480R   => r := 32;
            when M_352x288R   => r := 32;
            when M_1024x768   => r := 104;
            when M_800x600    => r := 80;
            when M_1280x960   => r := 128;
            when M_1024x768R  => r := 32;
            when M_1280x960R  => r := 32;
            when M_1600x900R  => r := 32;
            when M_800x600R   => r := 32;
            when M_1280x800   => r := 128;
            when M_384x288    => r := 32;
            when M_352x288    => r := 32;
            when M_800x480R   => r := 32;
            when M_1440x960   => r := 144;
            when M_3840x2160R => r := 32;
            when M_2048x1080R => r := 32;
            when M_1280x800R  => r := 32;
            when M_1366x768R  => r := 32;
            when M_1600x1200R => r := 32;
            when M_2560x1600  => r := 272;
            when M_1600x1200  => r := 168;
            when M_320x240    => r := 24;
            when M_1152x864   => r := 120;
            when M_1440x960R  => r := 32;
            when M_2560x1080  => r := 272;
            when M_1152x768   => r := 112;
            when M_1280x720   => r := 128;
            when M_1152x864R  => r := 32;
            when M_1024x600R  => r := 32;
            when M_1280x1024  => r := 128;
            when M_1280x768   => r := 128;
            when M_1280x720R  => r := 32;
            when M_2560x1600R => r := 32;
            when M_320x240R   => r := 32;
        end case;
        return r;
    end function;

    function get_hor_bp(mode : svo_mode_t) return integer is
        variable r : integer;
    begin
        r := 0;
        case mode is
            when M_640x480V   => r := 48;
            when M_960x540    => r := 240;
            when M_768x576    => r := 104;
            when M_1280x854R  => r := 80;
            when M_2560x2048R => r := 80;
            when M_1920x1200  => r := 336;
            when M_480x320R   => r := 80;
            when M_1280x768R  => r := 80;
            when M_2560x1440R => r := 80;
            when M_2048x1536  => r := 376;
            when M_1024x576   => r := 136;
            when M_320x200    => r := 40;
            when M_384x288R   => r := 80;
            when M_1280x1024R => r := 80;
            when M_768x576R   => r := 80;
            when M_2048x1536R => r := 80;
            when M_1024x576R  => r := 80;
            when M_1680x1050R => r := 80;
            when M_1280x854   => r := 200;
            when M_2560x2048  => r := 488;
            when M_1440x900R  => r := 80;
            when M_2048x1080  => r := 344;
            when M_1152x768R  => r := 80;
            when M_4096x2160  => r := 784;
            when M_4096x2160R => r := 80;
            when M_800x480    => r := 96;
            when M_2560x1080R => r := 80;
            when M_1440x1080R => r := 80;
            when M_854x480    => r := 104;
            when M_640x480    => r := 80;
            when M_480x320    => r := 56;
            when M_1920x1200R => r := 80;
            when M_3840x2160  => r := 736;
            when M_1400x1050  => r := 232;
            when M_854x480R   => r := 80;
            when M_1680x1050  => r := 280;
            when M_320x200R   => r := 80;
            when M_1920x1080R => r := 80;
            when M_1920x1080  => r := 328;
            when M_2560x1440  => r := 464;
            when M_1440x900   => r := 232;
            when M_1024x600   => r := 144;
            when M_1400x1050R => r := 80;
            when M_1366x768   => r := 208;
            when M_1440x1080  => r := 240;
            when M_1600x900   => r := 256;
            when M_64x48T     => r := 2;
            when M_640x480R   => r := 80;
            when M_352x288R   => r := 80;
            when M_1024x768   => r := 152;
            when M_800x600    => r := 112;
            when M_1280x960   => r := 208;
            when M_1024x768R  => r := 80;
            when M_1280x960R  => r := 80;
            when M_1600x900R  => r := 80;
            when M_800x600R   => r := 80;
            when M_1280x800   => r := 200;
            when M_384x288    => r := 48;
            when M_352x288    => r := 40;
            when M_800x480R   => r := 80;
            when M_1440x960   => r := 232;
            when M_3840x2160R => r := 80;
            when M_2048x1080R => r := 80;
            when M_1280x800R  => r := 80;
            when M_1366x768R  => r := 80;
            when M_1600x1200R => r := 80;
            when M_2560x1600  => r := 472;
            when M_1600x1200  => r := 280;
            when M_320x240    => r := 40;
            when M_1152x864   => r := 184;
            when M_1440x960R  => r := 80;
            when M_2560x1080  => r := 432;
            when M_1152x768   => r := 176;
            when M_1280x720   => r := 192;
            when M_1152x864R  => r := 80;
            when M_1024x600R  => r := 80;
            when M_1280x1024  => r := 216;
            when M_1280x768   => r := 192;
            when M_1280x720R  => r := 80;
            when M_2560x1600R => r := 80;
            when M_320x240R   => r := 80;
        end case;
        return r;
    end function;

    function get_ver_fp(mode : svo_mode_t) return integer is
        variable r : integer;
    begin
        r := 0;
        case mode is
            when M_640x480V   => r := 10;
            when M_64x48T     => r := 1;
            when others       => r := 3;
        end case;
        return r;
    end function;

    function get_ver_sync(mode : svo_mode_t) return integer is
        variable r : integer;
    begin
        r := 0;
        case mode is
            when M_640x480V   => r := 2;
            when M_960x540    => r := 5;
            when M_768x576    => r := 4;
            when M_1280x854R  => r := 10;
            when M_2560x2048R => r := 7;
            when M_1920x1200  => r := 6;
            when M_480x320R   => r := 10;
            when M_1280x768R  => r := 10;
            when M_2560x1440R => r := 5;
            when M_2048x1536  => r := 4;
            when M_1024x576   => r := 5;
            when M_320x200    => r := 6;
            when M_384x288R   => r := 4;
            when M_1280x1024R => r := 7;
            when M_768x576R   => r := 4;
            when M_2048x1536R => r := 4;
            when M_1024x576R  => r := 5;
            when M_1680x1050R => r := 6;
            when M_1280x854   => r := 10;
            when M_2560x2048  => r := 7;
            when M_1440x900R  => r := 6;
            when M_2048x1080  => r := 10;
            when M_1152x768R  => r := 10;
            when M_4096x2160  => r := 10;
            when M_4096x2160R => r := 10;
            when M_800x480    => r := 10;
            when M_2560x1080R => r := 10;
            when M_1440x1080R => r := 4;
            when M_854x480    => r := 10;
            when M_640x480    => r := 4;
            when M_480x320    => r := 10;
            when M_1920x1200R => r := 6;
            when M_3840x2160  => r := 5;
            when M_1400x1050  => r := 4;
            when M_854x480R   => r := 10;
            when M_1680x1050  => r := 6;
            when M_320x200R   => r := 6;
            when M_1920x1080R => r := 5;
            when M_1920x1080  => r := 5;
            when M_2560x1440  => r := 5;
            when M_1440x900   => r := 6;
            when M_1024x600   => r := 10;
            when M_1400x1050R => r := 4;
            when M_1366x768   => r := 10;
            when M_1440x1080  => r := 4;
            when M_1600x900   => r := 5;
            when M_64x48T     => r := 2;
            when M_640x480R   => r := 4;
            when M_352x288R   => r := 10;
            when M_1024x768   => r := 4;
            when M_800x600    => r := 4;
            when M_1280x960   => r := 4;
            when M_1024x768R  => r := 4;
            when M_1280x960R  => r := 4;
            when M_1600x900R  => r := 5;
            when M_800x600R   => r := 4;
            when M_1280x800   => r := 6;
            when M_384x288    => r := 4;
            when M_352x288    => r := 10;
            when M_800x480R   => r := 10;
            when M_1440x960   => r := 10;
            when M_3840x2160R => r := 5;
            when M_2048x1080R => r := 10;
            when M_1280x800R  => r := 6;
            when M_1366x768R  => r := 10;
            when M_1600x1200R => r := 4;
            when M_2560x1600  => r := 6;
            when M_1600x1200  => r := 4;
            when M_320x240    => r := 4;
            when M_1152x864   => r := 4;
            when M_1440x960R  => r := 10;
            when M_2560x1080  => r := 10;
            when M_1152x768   => r := 10;
            when M_1280x720   => r := 5;
            when M_1152x864R  => r := 4;
            when M_1024x600R  => r := 10;
            when M_1280x1024  => r := 7;
            when M_1280x768   => r := 10;
            when M_1280x720R  => r := 5;
            when M_2560x1600R => r := 6;
            when M_320x240R   => r := 4;
        end case;
        return r;
    end function;

    function get_ver_bp(mode : svo_mode_t) return integer is
        variable r : integer;
    begin
        r := 0;
        case mode is
            when M_640x480V   => r := 33;
            when M_960x540    => r := 77;
            when M_768x576    => r := 16;
            when M_1280x854R  => r := 12;
            when M_2560x2048R => r := 49;
            when M_1920x1200  => r := 36;
            when M_480x320R   => r := 6;
            when M_1280x768R  => r := 9;
            when M_2560x1440R => r := 33;
            when M_2048x1536  => r := 49;
            when M_1024x576   => r := 15;
            when M_320x200    => r := 3;
            when M_384x288R   => r := 6;
            when M_1280x1024R => r := 20;
            when M_768x576R   => r := 10;
            when M_2048x1536R => r := 37;
            when M_1024x576R  => r := 9;
            when M_1680x1050R => r := 21;
            when M_1280x854   => r := 20;
            when M_2560x2048  => r := 63;
            when M_1440x900R  => r := 17;
            when M_2048x1080  => r := 27;
            when M_1152x768R  => r := 9;
            when M_4096x2160  => r := 64;
            when M_4096x2160R => r := 49;
            when M_800x480    => r := 7;
            when M_2560x1080R => r := 18;
            when M_1440x1080R => r := 24;
            when M_854x480    => r := 7;
            when M_640x480    => r := 13;
            when M_480x320    => r := 3;
            when M_1920x1200R => r := 26;
            when M_3840x2160  => r := 69;
            when M_1400x1050  => r := 32;
            when M_854x480R   => r := 6;
            when M_1680x1050  => r := 30;
            when M_320x200R   => r := 6;
            when M_1920x1080R => r := 23;
            when M_1920x1080  => r := 32;
            when M_2560x1440  => r := 45;
            when M_1440x900   => r := 25;
            when M_1024x600   => r := 11;
            when M_1400x1050R => r := 23;
            when M_1366x768   => r := 17;
            when M_1440x1080  => r := 33;
            when M_1600x900   => r := 26;
            when M_64x48T     => r := 1;
            when M_640x480R   => r := 7;
            when M_352x288R   => r := 6;
            when M_1024x768   => r := 23;
            when M_800x600    => r := 17;
            when M_1280x960   => r := 29;
            when M_1024x768R  => r := 15;
            when M_1280x960R  => r := 21;
            when M_1600x900R  => r := 18;
            when M_800x600R   => r := 11;
            when M_1280x800   => r := 22;
            when M_384x288    => r := 6;
            when M_352x288    => r := 3;
            when M_800x480R   => r := 6;
            when M_1440x960   => r := 23;
            when M_3840x2160R => r := 54;
            when M_2048x1080R => r := 18;
            when M_1280x800R  => r := 14;
            when M_1366x768R  => r := 9;
            when M_1600x1200R => r := 28;
            when M_2560x1600  => r := 49;
            when M_1600x1200  => r := 38;
            when M_320x240    => r := 5;
            when M_1152x864   => r := 26;
            when M_1440x960R  => r := 15;
            when M_2560x1080  => r := 27;
            when M_1152x768   => r := 17;
            when M_1280x720   => r := 20;
            when M_1152x864R  => r := 18;
            when M_1024x600R  => r := 6;
            when M_1280x1024  => r := 29;
            when M_1280x768   => r := 17;
            when M_1280x720R  => r := 13;
            when M_2560x1600R => r := 37;
            when M_320x240R   => r := 6;
        end case;
        return r;
    end function;

    function svo_clog2(v : integer) return integer is
        variable n : integer;
        variable r : integer;
    begin
        n := v;
        if n > 0 then n := n - 1; end if;
        r := 0;
        while n /= 0 loop
            n := n / 2;
            r := r + 1;
        end loop;
        return r;
    end function;

    function svo_max(a : integer; b : integer) return integer is
    begin
        if a > b then return a; else return b; end if;
    end function;

end package body svo_pkg;
