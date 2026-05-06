// Minimal test for 1.44" 128x128 ST7735 TFT on Raspberry Pi Pico (SPI1).
// Pins: SCK=GP10, MOSI=GP11, CS=GP12, DC=GP13, RST=GP14, BL=GP15

#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/spi.h"
#include "hardware/pwm.h"
#include "hardware/gpio.h"

#define TFT_SPI    spi1
#define PIN_SCK    10
#define PIN_MOSI   11
#define PIN_CS     12
#define PIN_DC     13
#define PIN_RST    14
#define PIN_BL     15

#define TFT_W      128
#define TFT_H      128
#define COL_OFFSET 2   // 1.44" 128x128 ST7735 offsets
#define ROW_OFFSET 3

static inline void cs_low(void)  { gpio_put(PIN_CS, 0); }
static inline void cs_high(void) { gpio_put(PIN_CS, 1); }

static void tft_write_cmd(uint8_t cmd) {
    gpio_put(PIN_DC, 0);
    cs_low();
    spi_write_blocking(TFT_SPI, &cmd, 1);
    cs_high();
}

static void tft_write_data(const uint8_t *buf, size_t len) {
    gpio_put(PIN_DC, 1);
    cs_low();
    spi_write_blocking(TFT_SPI, buf, len);
    cs_high();
}

static void tft_write_data_byte(uint8_t b) { tft_write_data(&b, 1); }

static void tft_set_window(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1) {
    x0 += COL_OFFSET; x1 += COL_OFFSET;
    y0 += ROW_OFFSET; y1 += ROW_OFFSET;
    uint8_t d[4];
    tft_write_cmd(0x2A);
    d[0] = x0 >> 8; d[1] = x0 & 0xFF; d[2] = x1 >> 8; d[3] = x1 & 0xFF;
    tft_write_data(d, 4);
    tft_write_cmd(0x2B);
    d[0] = y0 >> 8; d[1] = y0 & 0xFF; d[2] = y1 >> 8; d[3] = y1 & 0xFF;
    tft_write_data(d, 4);
    tft_write_cmd(0x2C);
}

static void tft_fill(uint16_t color) {
    tft_set_window(0, 0, TFT_W - 1, TFT_H - 1);
    uint8_t hi = color >> 8, lo = color & 0xFF;
    gpio_put(PIN_DC, 1);
    cs_low();
    for (int i = 0; i < TFT_W * TFT_H; i++) {
        spi_write_blocking(TFT_SPI, &hi, 1);
        spi_write_blocking(TFT_SPI, &lo, 1);
    }
    cs_high();
}

static void tft_init(void) {
    gpio_put(PIN_RST, 0); sleep_ms(50);
    gpio_put(PIN_RST, 1); sleep_ms(120);

    tft_write_cmd(0x01);            // SWRESET
    sleep_ms(150);
    tft_write_cmd(0x11);            // SLPOUT
    sleep_ms(120);
    tft_write_cmd(0x3A);            // COLMOD
    tft_write_data_byte(0x05);      // 16-bit/pixel (RGB565)
    tft_write_cmd(0x36);            // MADCTL
    tft_write_data_byte(0xC0);      // MX|MY, RGB
    tft_write_cmd(0x21);            // INVON (most 1.44" panels need this)
    tft_write_cmd(0x13);            // NORON
    sleep_ms(10);
    tft_write_cmd(0x29);            // DISPON
    sleep_ms(100);
}

static void backlight_init(uint8_t duty_percent) {
    gpio_set_function(PIN_BL, GPIO_FUNC_PWM);
    uint slice = pwm_gpio_to_slice_num(PIN_BL);
    pwm_set_wrap(slice, 999);
    pwm_set_chan_level(slice, pwm_gpio_to_channel(PIN_BL), duty_percent * 10);
    pwm_set_enabled(slice, true);
}

int main(void) {
    stdio_init_all();

    spi_init(TFT_SPI, 20 * 1000 * 1000); // 20 MHz
    gpio_set_function(PIN_SCK,  GPIO_FUNC_SPI);
    gpio_set_function(PIN_MOSI, GPIO_FUNC_SPI);

    gpio_init(PIN_CS);  gpio_set_dir(PIN_CS,  GPIO_OUT); gpio_put(PIN_CS,  1);
    gpio_init(PIN_DC);  gpio_set_dir(PIN_DC,  GPIO_OUT); gpio_put(PIN_DC,  0);
    gpio_init(PIN_RST); gpio_set_dir(PIN_RST, GPIO_OUT); gpio_put(PIN_RST, 1);

    backlight_init(80);
    tft_init();

    const uint16_t colors[] = {
        0xF800, // red
        0x07E0, // green
        0x001F, // blue
        0xFFFF, // white
        0x0000, // black
        0xFFE0, // yellow
        0x07FF, // cyan
        0xF81F, // magenta
    };
    int n = sizeof(colors) / sizeof(colors[0]);

    int i = 0;
    while (true) {
        tft_fill(colors[i]);
        i = (i + 1) % n;
        sleep_ms(500);
    }
}
