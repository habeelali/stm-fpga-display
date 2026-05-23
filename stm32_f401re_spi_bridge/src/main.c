#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#define PERIPH_BASE        0x40000000UL
#define AHB1PERIPH_BASE    (PERIPH_BASE + 0x00020000UL)
#define APB1PERIPH_BASE    PERIPH_BASE
#define APB2PERIPH_BASE    (PERIPH_BASE + 0x00010000UL)

#define RCC_BASE           (AHB1PERIPH_BASE + 0x3800UL)
#define GPIOA_BASE         (AHB1PERIPH_BASE + 0x0000UL)
#define GPIOB_BASE         (AHB1PERIPH_BASE + 0x0400UL)
#define USART2_BASE        (APB1PERIPH_BASE + 0x4400UL)
#define SPI1_BASE          (APB2PERIPH_BASE + 0x3000UL)

#define REG32(addr)        (*(volatile uint32_t *)(addr))

#define RCC_AHB1ENR        REG32(RCC_BASE + 0x30UL)
#define RCC_APB1ENR        REG32(RCC_BASE + 0x40UL)
#define RCC_APB2ENR        REG32(RCC_BASE + 0x44UL)

#define GPIO_MODER(base)   REG32((base) + 0x00UL)
#define GPIO_OTYPER(base)  REG32((base) + 0x04UL)
#define GPIO_OSPEEDR(base) REG32((base) + 0x08UL)
#define GPIO_PUPDR(base)   REG32((base) + 0x0CUL)
#define GPIO_IDR(base)     REG32((base) + 0x10UL)
#define GPIO_ODR(base)     REG32((base) + 0x14UL)
#define GPIO_BSRR(base)    REG32((base) + 0x18UL)
#define GPIO_AFRL(base)    REG32((base) + 0x20UL)

#define USART_SR(base)     REG32((base) + 0x00UL)
#define USART_DR(base)     REG32((base) + 0x04UL)
#define USART_BRR(base)    REG32((base) + 0x08UL)
#define USART_CR1(base)    REG32((base) + 0x0CUL)
#define USART_CR2(base)    REG32((base) + 0x10UL)
#define USART_CR3(base)    REG32((base) + 0x14UL)

#define SPI_CR1(base)      REG32((base) + 0x00UL)
#define SPI_CR2(base)      REG32((base) + 0x04UL)
#define SPI_SR(base)       REG32((base) + 0x08UL)
#define SPI_DR(base)       REG32((base) + 0x0CUL)

#define BIT(n)             (1UL << (n))

#define FPGA_CS_PORT       GPIOB_BASE
#define FPGA_CS_PIN        6U

#define CMD_SET_PALETTE     0x01U
#define CMD_WRITE_TILE      0x10U
#define CMD_WRITE_TILE_RECT 0x20U
#define CMD_FILL_TILEMAP    0x21U

#define TILE_BYTES          128U
#define LINE_MAX            96U

static char line_buf[LINE_MAX];
static uint32_t line_len;

static void delay_cycles(volatile uint32_t n)
{
    while (n-- != 0U) {
        __asm__ volatile ("nop");
    }
}

static void uart_putc(char c)
{
    while ((USART_SR(USART2_BASE) & BIT(7)) == 0U) {
    }
    USART_DR(USART2_BASE) = (uint32_t)c;
}

static void uart_puts(const char *s)
{
    while (*s != '\0') {
        if (*s == '\n') {
            uart_putc('\r');
        }
        uart_putc(*s++);
    }
}

static bool uart_getc_nonblock(char *out)
{
    if ((USART_SR(USART2_BASE) & BIT(5)) == 0U) {
        return false;
    }
    *out = (char)(USART_DR(USART2_BASE) & 0xFFU);
    return true;
}

static int hex_digit(char c)
{
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    }
    if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    }
    return -1;
}

static void put_u32(uint32_t value)
{
    char tmp[11];
    uint32_t n = 0;

    if (value == 0U) {
        uart_putc('0');
        return;
    }

    while (value != 0U && n < sizeof(tmp)) {
        tmp[n++] = (char)('0' + (value % 10U));
        value /= 10U;
    }
    while (n != 0U) {
        uart_putc(tmp[--n]);
    }
}

static bool streq(const char *a, const char *b)
{
    while (*a != '\0' && *b != '\0') {
        if (*a++ != *b++) {
            return false;
        }
    }
    return *a == '\0' && *b == '\0';
}

static char *skip_spaces(char *s)
{
    while (*s == ' ' || *s == '\t') {
        s++;
    }
    return s;
}

static char *next_token(char **cursor)
{
    char *s = skip_spaces(*cursor);
    char *start;

    if (*s == '\0') {
        *cursor = s;
        return NULL;
    }

    start = s;
    while (*s != '\0' && *s != ' ' && *s != '\t') {
        s++;
    }
    if (*s != '\0') {
        *s++ = '\0';
    }
    *cursor = s;
    return start;
}

static bool parse_u32(char *s, uint32_t *out)
{
    uint32_t value = 0;
    uint32_t base = 10;

    if (s == NULL || *s == '\0') {
        return false;
    }

    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        base = 16;
        s += 2;
    }

    if (*s == '\0') {
        return false;
    }

    while (*s != '\0') {
        int d = hex_digit(*s++);
        if (d < 0 || (uint32_t)d >= base) {
            return false;
        }
        value = value * base + (uint32_t)d;
    }

    *out = value;
    return true;
}

static bool parse_rgb(char *s, uint8_t *r, uint8_t *g, uint8_t *b)
{
    uint32_t value;

    if (s == NULL) {
        return false;
    }
    if (s[0] == '#') {
        s++;
    }
    if (!parse_u32(s, &value) || value > 0xFFFFFFU) {
        return false;
    }

    *r = (uint8_t)((value >> 16) & 0xFFU);
    *g = (uint8_t)((value >> 8) & 0xFFU);
    *b = (uint8_t)(value & 0xFFU);
    return true;
}

static void cs_low(void)
{
    GPIO_BSRR(FPGA_CS_PORT) = BIT(FPGA_CS_PIN + 16U);
}

static void cs_high(void)
{
    GPIO_BSRR(FPGA_CS_PORT) = BIT(FPGA_CS_PIN);
}

static void spi_write8(uint8_t value)
{
    while ((SPI_SR(SPI1_BASE) & BIT(1)) == 0U) {
    }
    *((volatile uint8_t *)(SPI1_BASE + 0x0CUL)) = value;
    while ((SPI_SR(SPI1_BASE) & BIT(1)) == 0U) {
    }
    while ((SPI_SR(SPI1_BASE) & BIT(7)) != 0U) {
    }
    (void)SPI_DR(SPI1_BASE);
    (void)SPI_SR(SPI1_BASE);
}

static void spi_packet_begin(void)
{
    cs_low();
    delay_cycles(80);
}

static void spi_packet_end(void)
{
    while ((SPI_SR(SPI1_BASE) & BIT(7)) != 0U) {
    }
    delay_cycles(80);
    cs_high();
    delay_cycles(400);
}

static void fpga_set_palette(uint8_t idx, uint8_t r, uint8_t g, uint8_t b)
{
    spi_packet_begin();
    spi_write8(CMD_SET_PALETTE);
    spi_write8(idx & 0x0FU);
    spi_write8(r);
    spi_write8(g);
    spi_write8(b);
    spi_packet_end();
}

static void fpga_fill_tilemap(uint8_t tile_id)
{
    spi_packet_begin();
    spi_write8(CMD_FILL_TILEMAP);
    spi_write8(tile_id & 0x3FU);
    spi_packet_end();
}

static void fpga_rect(uint8_t x, uint8_t y, uint8_t w, uint8_t h, uint8_t tile_id)
{
    uint32_t count = (uint32_t)w * (uint32_t)h;

    spi_packet_begin();
    spi_write8(CMD_WRITE_TILE_RECT);
    spi_write8(x);
    spi_write8(y);
    spi_write8(w);
    spi_write8(h);
    for (uint32_t i = 0; i < count; i++) {
        spi_write8(tile_id & 0x3FU);
    }
    spi_packet_end();
}

static void fpga_write_tile_solid(uint8_t tile_id, uint8_t pal_idx)
{
    uint8_t packed = (uint8_t)(((pal_idx & 0x0FU) << 4) | (pal_idx & 0x0FU));

    spi_packet_begin();
    spi_write8(CMD_WRITE_TILE);
    spi_write8(tile_id & 0x3FU);
    for (uint32_t i = 0; i < TILE_BYTES; i++) {
        spi_write8(packed);
    }
    spi_packet_end();
}

static void fpga_write_tile_checker(uint8_t tile_id, uint8_t a, uint8_t b)
{
    spi_packet_begin();
    spi_write8(CMD_WRITE_TILE);
    spi_write8(tile_id & 0x3FU);
    for (uint32_t row = 0; row < 16U; row++) {
        for (uint32_t col_pair = 0; col_pair < 8U; col_pair++) {
            uint32_t col = col_pair * 2U;
            uint8_t p0 = (((row / 4U) + (col / 4U)) & 1U) ? b : a;
            uint8_t p1 = (((row / 4U) + ((col + 1U) / 4U)) & 1U) ? b : a;
            spi_write8((uint8_t)((p0 << 4) | (p1 & 0x0FU)));
        }
    }
    spi_packet_end();
}

static void fpga_write_tile_stripes(uint8_t tile_id, uint8_t a, uint8_t b)
{
    spi_packet_begin();
    spi_write8(CMD_WRITE_TILE);
    spi_write8(tile_id & 0x3FU);
    for (uint32_t row = 0; row < 16U; row++) {
        uint8_t p = ((row / 2U) & 1U) ? b : a;
        uint8_t packed = (uint8_t)((p << 4) | (p & 0x0FU));
        for (uint32_t col_pair = 0; col_pair < 8U; col_pair++) {
            spi_write8(packed);
        }
    }
    spi_packet_end();
}

static void load_default_palette(void)
{
    fpga_set_palette(0, 0x00, 0x00, 0x00);
    fpga_set_palette(1, 0xFF, 0xFF, 0xFF);
    fpga_set_palette(2, 0xE6, 0x24, 0x24);
    fpga_set_palette(3, 0x20, 0xC8, 0x60);
    fpga_set_palette(4, 0x20, 0x60, 0xE8);
    fpga_set_palette(5, 0x00, 0xCC, 0xCC);
    fpga_set_palette(6, 0xD0, 0x40, 0xD0);
    fpga_set_palette(7, 0xF0, 0xD0, 0x30);
    fpga_set_palette(8, 0x18, 0x18, 0x18);
    fpga_set_palette(9, 0x48, 0x48, 0x48);
}

static void load_demo(void)
{
    load_default_palette();
    fpga_write_tile_solid(0, 0);
    fpga_write_tile_solid(1, 2);
    fpga_write_tile_solid(2, 3);
    fpga_write_tile_solid(3, 4);
    fpga_write_tile_checker(4, 1, 8);
    fpga_write_tile_stripes(5, 5, 8);
    fpga_fill_tilemap(0);
    fpga_rect(2, 2, 12, 8, 1);
    fpga_rect(14, 2, 12, 8, 2);
    fpga_rect(26, 2, 12, 8, 3);
    fpga_rect(5, 13, 12, 10, 4);
    fpga_rect(23, 13, 12, 10, 5);
}

static void load_bars(void)
{
    load_default_palette();
    for (uint8_t i = 0; i < 8U; i++) {
        fpga_write_tile_solid(i, i);
        fpga_rect((uint8_t)(i * 5U), 0, 5, 30, i);
    }
}

static void print_help(void)
{
    uart_puts("\nCommands:\n");
    uart_puts("  help\n");
    uart_puts("  demo\n");
    uart_puts("  bars\n");
    uart_puts("  clear\n");
    uart_puts("  fill <tile>\n");
    uart_puts("  rect <x> <y> <w> <h> <tile>\n");
    uart_puts("  pal <idx> <rrggbb>\n");
    uart_puts("  solid <tile> <palette_idx>\n");
    uart_puts("  checker <tile> <palette_a> <palette_b>\n");
    uart_puts("  stripes <tile> <palette_a> <palette_b>\n");
    uart_puts("Tile grid is 40x30, each tile is 16x16 pixels.\n");
}

static bool get_arg_u8(char **cursor, uint32_t max_value, uint8_t *out)
{
    uint32_t value;
    char *tok = next_token(cursor);

    if (!parse_u32(tok, &value) || value > max_value) {
        return false;
    }

    *out = (uint8_t)value;
    return true;
}

static void handle_line(char *line)
{
    char *cursor = line;
    char *cmd = next_token(&cursor);
    uint8_t a;
    uint8_t b;
    uint8_t c;
    uint8_t d;
    uint8_t e;

    if (cmd == NULL) {
        return;
    }

    if (streq(cmd, "help") || streq(cmd, "?")) {
        print_help();
    } else if (streq(cmd, "demo")) {
        load_demo();
        uart_puts("loaded demo\n");
    } else if (streq(cmd, "bars")) {
        load_bars();
        uart_puts("loaded bars\n");
    } else if (streq(cmd, "clear")) {
        fpga_write_tile_solid(0, 0);
        fpga_fill_tilemap(0);
        uart_puts("cleared\n");
    } else if (streq(cmd, "fill")) {
        if (get_arg_u8(&cursor, 63, &a)) {
            fpga_fill_tilemap(a);
            uart_puts("filled tile ");
            put_u32(a);
            uart_puts("\n");
        } else {
            uart_puts("usage: fill <tile 0..63>\n");
        }
    } else if (streq(cmd, "rect")) {
        if (get_arg_u8(&cursor, 39, &a) &&
            get_arg_u8(&cursor, 29, &b) &&
            get_arg_u8(&cursor, 40, &c) &&
            get_arg_u8(&cursor, 30, &d) &&
            get_arg_u8(&cursor, 63, &e)) {
            fpga_rect(a, b, c, d, e);
            uart_puts("rect sent\n");
        } else {
            uart_puts("usage: rect <x 0..39> <y 0..29> <w> <h> <tile 0..63>\n");
        }
    } else if (streq(cmd, "pal")) {
        char *rgb = NULL;
        uint8_t r;
        uint8_t g;
        uint8_t bl;
        if (get_arg_u8(&cursor, 15, &a)) {
            rgb = next_token(&cursor);
        }
        if (rgb != NULL && parse_rgb(rgb, &r, &g, &bl)) {
            fpga_set_palette(a, r, g, bl);
            uart_puts("palette updated\n");
        } else {
            uart_puts("usage: pal <idx 0..15> <rrggbb>\n");
        }
    } else if (streq(cmd, "solid")) {
        if (get_arg_u8(&cursor, 63, &a) && get_arg_u8(&cursor, 15, &b)) {
            fpga_write_tile_solid(a, b);
            uart_puts("solid tile written\n");
        } else {
            uart_puts("usage: solid <tile 0..63> <palette 0..15>\n");
        }
    } else if (streq(cmd, "checker")) {
        if (get_arg_u8(&cursor, 63, &a) &&
            get_arg_u8(&cursor, 15, &b) &&
            get_arg_u8(&cursor, 15, &c)) {
            fpga_write_tile_checker(a, b, c);
            uart_puts("checker tile written\n");
        } else {
            uart_puts("usage: checker <tile 0..63> <palette_a> <palette_b>\n");
        }
    } else if (streq(cmd, "stripes")) {
        if (get_arg_u8(&cursor, 63, &a) &&
            get_arg_u8(&cursor, 15, &b) &&
            get_arg_u8(&cursor, 15, &c)) {
            fpga_write_tile_stripes(a, b, c);
            uart_puts("stripe tile written\n");
        } else {
            uart_puts("usage: stripes <tile 0..63> <palette_a> <palette_b>\n");
        }
    } else {
        uart_puts("unknown command: ");
        uart_puts(cmd);
        uart_puts("\n");
    }
}

static void gpio_init(void)
{
    RCC_AHB1ENR |= BIT(0) | BIT(1);
    (void)RCC_AHB1ENR;

    /* PA2/PA3 USART2 AF7, PA5/PA7 SPI1 AF5. */
    GPIO_MODER(GPIOA_BASE) &= ~((3U << (2U * 2U)) | (3U << (3U * 2U)) |
                                (3U << (5U * 2U)) | (3U << (7U * 2U)));
    GPIO_MODER(GPIOA_BASE) |=  ((2U << (2U * 2U)) | (2U << (3U * 2U)) |
                                (2U << (5U * 2U)) | (2U << (7U * 2U)));
    GPIO_AFRL(GPIOA_BASE) &= ~((0xFU << (2U * 4U)) | (0xFU << (3U * 4U)) |
                               (0xFU << (5U * 4U)) | (0xFU << (7U * 4U)));
    GPIO_AFRL(GPIOA_BASE) |=  ((7U << (2U * 4U)) | (7U << (3U * 4U)) |
                               (5U << (5U * 4U)) | (5U << (7U * 4U)));
    GPIO_OSPEEDR(GPIOA_BASE) |= (3U << (5U * 2U)) | (3U << (7U * 2U));
    GPIO_PUPDR(GPIOA_BASE) &= ~((3U << (5U * 2U)) | (3U << (7U * 2U)));

    /* PB6 software chip select. */
    GPIO_MODER(GPIOB_BASE) &= ~(3U << (FPGA_CS_PIN * 2U));
    GPIO_MODER(GPIOB_BASE) |=  (1U << (FPGA_CS_PIN * 2U));
    GPIO_OTYPER(GPIOB_BASE) &= ~BIT(FPGA_CS_PIN);
    GPIO_OSPEEDR(GPIOB_BASE) |= (3U << (FPGA_CS_PIN * 2U));
    cs_high();
}

static void uart_init(void)
{
    RCC_APB1ENR |= BIT(17);
    (void)RCC_APB1ENR;

    USART_CR1(USART2_BASE) = 0;
    USART_CR2(USART2_BASE) = 0;
    USART_CR3(USART2_BASE) = 0;
    USART_BRR(USART2_BASE) = 0x008BU; /* 16 MHz / 115200 baud. */
    USART_CR1(USART2_BASE) = BIT(13) | BIT(3) | BIT(2);
}

static void spi_init(void)
{
    RCC_APB2ENR |= BIT(12);
    (void)RCC_APB2ENR;

    SPI_CR1(SPI1_BASE) = 0;
    SPI_CR2(SPI1_BASE) = 0;
    SPI_CR1(SPI1_BASE) = BIT(2) | BIT(9) | BIT(8) | (2U << 3U);
    SPI_CR1(SPI1_BASE) |= BIT(6);
}

int main(void)
{
    gpio_init();
    uart_init();
    spi_init();

    uart_puts("\nSTM32F401RE FPGA SPI tile bridge ready.\n");
    uart_puts("UART 115200 8N1, SPI1 mode 0, MSB first. Type 'help'.\n> ");

    while (1) {
        char ch;

        if (!uart_getc_nonblock(&ch)) {
            continue;
        }

        if (ch == '\r' || ch == '\n') {
            uart_puts("\n");
            line_buf[line_len] = '\0';
            handle_line(line_buf);
            line_len = 0;
            uart_puts("> ");
        } else if (ch == 0x08 || ch == 0x7F) {
            if (line_len != 0U) {
                line_len--;
                uart_puts("\b \b");
            }
        } else if (ch >= 0x20 && ch <= 0x7E) {
            if (line_len < (LINE_MAX - 1U)) {
                line_buf[line_len++] = ch;
                uart_putc(ch);
            }
        }
    }
}
