# STM32F401RE SPI Tile Bridge

Firmware for a Nucleo-F401RE that accepts simple text commands over the ST-LINK
virtual serial port and sends write-only SPI packets to the FPGA tile display.

## Wiring

All signals are 3.3 V. Connect grounds between the Nucleo and Tang Nano 4K.

| STM32F401RE Nucleo | STM32 pin | FPGA signal | Tang Nano 4K pin |
| --- | --- | --- | --- |
| D13 | PA5 / SPI1_SCK | `spi_sclk` | physical 41, IOT20A / DVP_PCLK |
| D11 | PA7 / SPI1_MOSI | `spi_mosi` | physical 43, IOT17A / DVP_VSYNC |
| D10 | PB6 / GPIO CS | `spi_cs_n` | physical 42, IOT20B / DVP_HSYNC |
| GND | GND | GND | GND |

MISO is not used in v1.

The MSPI-labeled Tang Nano 4K pins are dedicated in this package and Gowin P&R
rejects them as regular user I/O, so this firmware uses the same STM32 pins but
the FPGA constraints map them to ordinary DVP/header pins.

## Build And Flash

```sh
make
make flash
make reset
make monitor
```

The serial console is USART2 through the ST-LINK virtual COM port at
`115200 8N1`. `make monitor` enables local echo so typed commands are visible.
On this machine it appeared as `/dev/ttyACM0` and
`/dev/serial/by-id/usb-STMicroelectronics_STM32_STLink_066BFF545589564867035349-if02`.

## Serial Commands

```text
help
demo
bars
clear
fill <tile>
rect <x> <y> <w> <h> <tile>
pal <idx> <rrggbb>
solid <tile> <palette_idx>
checker <tile> <palette_a> <palette_b>
stripes <tile> <palette_a> <palette_b>
```

The FPGA display grid is 40x30 tiles. Each tile is 16x16 pixels. Tile IDs are
0..63 and palette indices are 0..15.
