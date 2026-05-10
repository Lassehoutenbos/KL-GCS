/* GPIO pad continuity test for the TFT-SPI pins.
 *
 * Disconnect the TFT module before flashing this. The display will not be
 * driven — this test only exercises the Pico's GPIO pads as plain digital
 * outputs, to find a pad damaged by back-powering through the module.
 *
 * Behaviour:
 *   For each pin in {SCK, MOSI, CS, DC, RST}:
 *     1. Drive the pin HIGH for 3 s — measure pad-to-GND, expect ~3.3 V
 *     2. Drive the pin LOW  for 3 s — measure pad-to-GND, expect ~0 V
 *   Then move to the next pin. Cycle repeats forever.
 *
 * The on-board LED gives a coarse beat so you know the firmware is running.
 *
 * Pass criteria: every pin reaches a clean 0 V and 3.3 V. Anything stuck
 * mid-rail (~1.6 V), refusing to swing, or pulling other pins with it
 * indicates a damaged pad on that GPIO.
 */

#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "pins.h"

#include <stdio.h>

static const struct {
    uint        pin;
    const char *name;
} s_pads[] = {
    { PIN_TFT_SCK,  "SCK  (GP10)" },
    { PIN_TFT_MOSI, "MOSI (GP11)" },
    { PIN_TFT_CS,   "CS   (GP12)" },
    { PIN_TFT_DC,   "DC   (GP13)" },
    { PIN_TFT_RST,  "RST  (GP14)" },
};
#define N_PADS (sizeof(s_pads) / sizeof(s_pads[0]))

#define HOLD_MS 3000   /* time to hold each level — long enough to read on a DMM */

int main(void)
{
    stdio_init_all();

    /* All TFT pads to plain GPIO outputs, idle low. */
    for (size_t i = 0; i < N_PADS; i++) {
        gpio_init(s_pads[i].pin);
        gpio_set_dir(s_pads[i].pin, GPIO_OUT);
        gpio_put(s_pads[i].pin, 0);
    }

    /* Backlight pin: park low (display is unplugged anyway). */
    gpio_init(PIN_TFT_BLK);
    gpio_set_dir(PIN_TFT_BLK, GPIO_OUT);
    gpio_put(PIN_TFT_BLK, 0);

    printf("\n=== TFT GPIO pad continuity test ===\n");
    printf("Probe each pad with a DMM. Expect 3.3 V high, 0 V low.\n\n");

    while (1) {
        for (size_t i = 0; i < N_PADS; i++) {
            uint pin = s_pads[i].pin;

            printf("[%s] HIGH for %u ms ...\n", s_pads[i].name, HOLD_MS);
            gpio_put(pin, 1);
            sleep_ms(HOLD_MS);

            printf("[%s] LOW  for %u ms ...\n", s_pads[i].name, HOLD_MS);
            gpio_put(pin, 0);
            sleep_ms(HOLD_MS);
        }
        printf("--- cycle complete, repeating ---\n\n");
    }
}
