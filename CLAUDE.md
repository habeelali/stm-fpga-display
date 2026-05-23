# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

Three independent subprojects that talk to each other over SPI:

- `fpga_project_vhdl/` — VHDL-93/2008 design for the Sipeed Tang Nano 4K (Gowin GW1NSR-LV4CQN48PC6/I5). Drives an HDMI display via a tile/palette renderer, fed by an SPI slave. This is the VHDL port of an upstream Verilog SVO HDMI project; the original Verilog tree (`fpga_project/`) has been deleted from the working tree but still exists in git history (commit `c69533e`) for reference.
- `stm32_f401re_spi_bridge/` — bare-metal STM32F401RE Nucleo firmware. Accepts text commands on the ST-LINK virtual serial port (115200 8N1) and pushes binary tile/palette/map packets to the FPGA over SPI1.
- `docs/` — Tang Nano 4K datasheet, schematic, and `pinmap.png`.

The STM32↔FPGA wiring, packet behavior, and serial command surface are documented in `stm32_f401re_spi_bridge/README.md` — that file is the source of truth for the physical interface.

## FPGA build (Gowin)

The project is built with the Gowin EDA IDE using `fpga_project_vhdl/fpga_project_vhdl.gprj`. There is no command-line build flow checked in; synthesis/P&R is driven from the IDE. Top-level entity is `top` in `src/top.vhd`. Constraints live in `src/hdmi.cst` (pins) and `src/hdmi.sdc` (timing).

Important pin constraint: the STM32 SPI lines map to ordinary DVP/header pins (41/42/43), **not** the MSPI-labeled pins. The MSPI pins are dedicated in this package and Gowin P&R rejects them as user I/O. Don't try to "fix" this by moving SPI back to MSPI pins.

## FPGA simulation (GHDL)

Testbenches live in `fpga_project_vhdl/tb/` and waveforms in `fpga_project_vhdl/waves/` (`.ghw` format → GHDL + GtkWave). The `work-obj08.cf` artifact in the project root indicates the working flow is GHDL with `--std=08`. Typical invocation from `fpga_project_vhdl/`:

```sh
ghdl -a --std=08 src/svo_pkg.vhd src/spi_byte_rx.vhd src/spi_dp_ram.vhd src/spi_tile_display.vhd tb/tb_spi_byte_rx.vhd
ghdl -r --std=08 tb_spi_byte_rx --wave=waves/tb_spi_byte_rx.ghw
```

Three TBs: `tb_spi_byte_rx` (byte-level SPI deserializer), `tb_spi_tile_protocol` (command-parser FSM), `tb_spi_tile_render` (full pipeline including AXIS pixel output). Each TB uses `std.env.stop` to terminate.

## STM32 firmware

```sh
cd stm32_f401re_spi_bridge
make            # build .elf and .bin in build/
make flash      # st-flash write to 0x08000000
make reset
make monitor    # picocom on $SERIAL_PORT (default /dev/ttyACM0) with local echo
```

Toolchain: `arm-none-eabi-gcc`, `st-flash`, `picocom`. No HAL — direct register access in `src/main.c` plus a minimal `startup_stm32f401xe.c`.

## RTL architecture

The display pipeline is a chain of three units in `fpga_project_vhdl/src/`:

1. `spi_byte_rx.vhd` — synchronizes raw SPI pins into the system clock domain (3-stage sync on sclk/cs/mosi), shifts MSB-first on rising sclk, emits `byte_valid` pulses per received byte while CS is low.
2. `spi_tile_display.vhd` — command parser FSM that consumes the byte stream and updates three on-chip memories:
   - **Palette** (16 entries × 24-bit RGB), updated by cmd `0x01`.
   - **Tile ROM** (64 tiles × 128 bytes = 16×16 px @ 4bpp palette indices), written by cmds `0x10` (single tile) and `0x20` (rectangle of tiles).
   - **Tilemap** (40×30 tile IDs for 640×480), written by cmd `0x21` (fill run).
   It also produces a raster AXIS pixel stream (`out_axis_t{valid,data,user}`) by reading the tilemap → tile ROM → palette at the current pixel position. `tuser` carries start-of-frame.
3. `svo_hdmi.vhd` (and `hdmi/svo_*.vhd`) — upstream SVO encoder: takes the AXIS pixel stream and emits TMDS via `svo_enc`/`svo_tmds`/`svo_openldi`. `svo_pkg.vhd` holds the video-mode generics (default `M_640x480V`). `svo_tcard`/`svo_term`/`svo_vdma` are legacy SVO blocks not all wired into the top-level.

`top.vhd` ties it all together: `Gowin_PLLVR` generates a 5×-pixel clock, `Gowin_CLKDIV` divides it back down, `Reset_Sync` aligns the external reset, and `svo_hdmi` (which internally instantiates `spi_tile_display` — see that wrapper) drives the TMDS pads.

`spi_dp_ram.vhd` is a generic dual-port RAM used for tile and map storage; the palette is a simple register array.

## Packet protocol (STM32 → FPGA)

Command byte then payload, all binary, MSB-first, sent inside one CS-low frame. The same encoding is implemented on both sides — when adding a command, update `spi_tile_display.vhd`'s FSM and the STM32 sender in `stm32_f401re_spi_bridge/src/main.c` together, plus a TB case in `tb_spi_tile_protocol.vhd`.

| Cmd  | Payload                                        | Meaning                       |
| ---- | ---------------------------------------------- | ----------------------------- |
| 0x01 | `idx(4b) R G B`                                | set palette entry             |
| 0x10 | `tile_id` + 128 bytes                          | write one tile (4bpp packed)  |
| 0x20 | `x y w h` + `w*h*128` bytes                    | write rectangle of tiles      |
| 0x21 | `tile_id` + 16-bit run length                  | fill tilemap                  |

Screen is fixed at 40×30 tiles of 16×16 px; tile IDs 0–63; palette indices 0–15.
