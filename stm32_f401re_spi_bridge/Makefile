PROJECT := stm32_f401re_spi_bridge
BUILD := build

CC := arm-none-eabi-gcc
OBJCOPY := arm-none-eabi-objcopy
SIZE := arm-none-eabi-size
STFLASH := st-flash
SERIAL_PORT ?= /dev/ttyACM0
BAUD ?= 115200

CPU := -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard
CFLAGS := $(CPU) -std=c11 -Os -g3 -Wall -Wextra -ffunction-sections -fdata-sections
LDFLAGS := $(CPU) -TSTM32F401RETx_FLASH.ld -Wl,--gc-sections -Wl,-Map=$(BUILD)/$(PROJECT).map -specs=nosys.specs

SRCS := src/startup_stm32f401xe.c src/main.c
OBJS := $(SRCS:%.c=$(BUILD)/%.o)

.PHONY: all clean flash reset monitor size

all: $(BUILD)/$(PROJECT).bin

$(BUILD)/$(PROJECT).elf: $(OBJS) STM32F401RETx_FLASH.ld
	$(CC) $(OBJS) $(LDFLAGS) -o $@
	$(SIZE) $@

$(BUILD)/$(PROJECT).bin: $(BUILD)/$(PROJECT).elf
	$(OBJCOPY) -O binary $< $@

$(BUILD)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

flash: $(BUILD)/$(PROJECT).bin
	$(STFLASH) write $< 0x08000000

reset:
	$(STFLASH) reset

monitor:
	picocom -b $(BAUD) --echo --imap lfcrlf $(SERIAL_PORT)

size: $(BUILD)/$(PROJECT).elf
	$(SIZE) $<

clean:
	rm -rf $(BUILD)
