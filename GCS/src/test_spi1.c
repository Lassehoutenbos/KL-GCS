/* spi1 peripheral test — no display required.
 *
 * Initializes spi1 with the same baud / format that screen_st7735.c uses,
 * then continuously sends a known byte pattern. Toggles CS each transfer
 * so you can trigger a scope on its falling edge.
 *
 * Probe at the Pico pins (display can be plugged in or unplugged):
 *   GP10 (SCK)  — square clock burst, 8 cycles per byte
 *   GP11 (MOSI) — data, alternating 0xA5 / 0x5A so every bit toggles
 *   GP12 (CS)   — falls at start of each transfer, rises after
 *   GP13 (DC)   — held HIGH (data mode) for visibility
 *   GP14 (RST)  — held HIGH (out of reset)
 *
 * Pass: clean 3.3 V CMOS swings on SCK + MOSI at ~15 MHz, CS toggling.
 * Fail: SCK/MOSI flat, garbage, or stuck at one rail → spi1 block dead.
 *
 * If spi1 is dead but plain GPIO writes worked (test_gpio_pads), the
 * peripheral itself is damaged — pads are fine.
 */

#include "pico/stdlib.h"
#include "hardware/spi.h"
#include "hardware/gpio.h"
#include "pins.h"

#include <stdio.h>

#define BURST_BYTES 16

int main(void)
{
    stdio_init_all();

    /* CS / DC / RST as plain GPIO outputs, idle in their normal levels. */
    gpio_init(PIN_TFT_CS);  gpio_set_dir(PIN_TFT_CS,  GPIO_OUT); gpio_put(PIN_TFT_CS,  1);
    gpio_init(PIN_TFT_DC);  gpio_set_dir(PIN_TFT_DC,  GPIO_OUT); gpio_put(PIN_TFT_DC,  1);
    gpio_init(PIN_TFT_RST); gpio_set_dir(PIN_TFT_RST, GPIO_OUT); gpio_put(PIN_TFT_RST, 1);

    /* Park backlight low. */
    gpio_init(PIN_TFT_BLK); gpio_set_dir(PIN_TFT_BLK, GPIO_OUT); gpio_put(PIN_TFT_BLK, 0);

    /* Bring up spi1 exactly like screen_st7735.c does. */
    uint actual = spi_init(ST7735_SPI_INST, ST7735_SPI_BAUD);
    spi_set_format(ST7735_SPI_INST, 8, SPI_CPOL_0, SPI_CPHA_0, SPI_MSB_FIRST);
    gpio_set_function(PIN_TFT_SCK,  GPIO_FUNC_SPI);
    gpio_set_function(PIN_TFT_MOSI, GPIO_FUNC_SPI);

    printf("\n=== spi1 peripheral test ===\n");
    printf("Requested baud %u, actual %u Hz\n",
           (unsigned)ST7735_SPI_BAUD, (unsigned)actual);
    printf("Probe SCK=GP%u, MOSI=GP%u, CS=GP%u\n",
           PIN_TFT_SCK, PIN_TFT_MOSI, PIN_TFT_CS);

    uint8_t pattern_a[BURST_BYTES];
    uint8_t pattern_b[BURST_BYTES];
    for (int i = 0; i < BURST_BYTES; i++) {
        pattern_a[i] = 0xA5;
        pattern_b[i] = 0x5A;
    }

    uint32_t bursts = 0;
    while (1) {
        const uint8_t *buf = (bursts & 1) ? pattern_b : pattern_a;

        gpio_put(PIN_TFT_CS, 0);
        spi_write_blocking(ST7735_SPI_INST, buf, BURST_BYTES);
        gpio_put(PIN_TFT_CS, 1);

        bursts++;
        if ((bursts & 0xFFFF) == 0) {
            printf("bursts=%u\n", (unsigned)bursts);
        }
        sleep_us(200);  /* gap so CS edges are easy to trigger on */
    }
}
