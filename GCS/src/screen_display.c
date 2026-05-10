#include "screen_display.h"
#include "screen_st7735.h"
#include "logo_kl.h"
#include "system_state.h"
#include "analog.h"     /* g_latest_adc  */
#include "digital_io.h" /* g_latest_digital */
#include "rs485.h"
#include "pins.h"

#include "pico/stdlib.h"
#include "hardware/gpio.h"

#include "FreeRTOS.h"
#include "task.h"

#include <stdbool.h>
#include <stdio.h>
#include <string.h>

/* ------------------------------------------------------------------ */
/* Voltage conversion                                                     */
/* MCP3208 12-bit, Vref = 3.3 V                                          */
/* Adjust DIVIDER ratios to match actual hardware resistor dividers.     */
/* ------------------------------------------------------------------ */
#define ADC_VREF        3.3f
#define ADC_MAX_COUNT   4095.0f
#define BAT_DIVIDER     9.1818f  /* (180k + 22k) / 22k — max ~30.3 V */
#define EXT_DIVIDER     9.1818f

static float adc_to_volts(uint16_t raw, float divider)
{
    return ((float)raw / ADC_MAX_COUNT) * ADC_VREF * divider;
}

/* ------------------------------------------------------------------ */
/* Additional colour constants                                            */
/* ------------------------------------------------------------------ */
#define COL_NAVY      ST7735_COLOR(  0,  32, 128)   /* dark navy blue  */
#define COL_DKBLUE    ST7735_COLOR(  0,  16,  72)   /* very dark blue  */
#define COL_TEAL      ST7735_COLOR(  0, 160, 144)   /* teal accent     */
#define COL_AMBER     ST7735_COLOR(255, 152,   0)   /* warm amber/gold */
#define COL_LTGRAY    ST7735_COLOR(176, 176, 176)   /* light grey      */
#define COL_CHARCOAL  ST7735_COLOR( 28,  32,  40)   /* dark charcoal   */
#define COL_DKRED     ST7735_COLOR(144,   0,   0)   /* dark red        */
#define COL_DKGREEN   ST7735_COLOR(  0, 100,   0)   /* dark green      */

/* ------------------------------------------------------------------ */
/* Rounded-rectangle primitives (chamfered / octagonal corners)          */
/*  r = corner radius; r=0 falls back to a plain rectangle.              */
/*  Chamfer formula: row i gets indent = (r-1-i), giving a 45° bevel.   */
/* ------------------------------------------------------------------ */
static void fill_rrect(int16_t x, int16_t y, int16_t w, int16_t h,
                        int16_t r, uint16_t color)
{
    if (w <= 0 || h <= 0) return;
    if (r <= 0) { st7735_fill_rect(x, y, w, h, color); return; }
    if (r > w / 2) r = w / 2;
    if (r > h / 2) r = h / 2;
    st7735_fill_rect(x, y + r, w, h - 2 * r, color);   /* middle band */
    for (int16_t i = 0; i < r; i++) {
        int16_t ind = r - 1 - i;
        st7735_draw_hline(x + ind, y + i,         w - 2 * ind, color);
        st7735_draw_hline(x + ind, y + h - 1 - i, w - 2 * ind, color);
    }
}

static void draw_rrect(int16_t x, int16_t y, int16_t w, int16_t h,
                        int16_t r, uint16_t color)
{
    if (w <= 0 || h <= 0) return;
    if (r <= 0) {
        st7735_draw_hline(x, y,         w, color);
        st7735_draw_hline(x, y + h - 1, w, color);
        st7735_draw_vline(x,         y, h, color);
        st7735_draw_vline(x + w - 1, y, h, color);
        return;
    }
    if (r > w / 2) r = w / 2;
    if (r > h / 2) r = h / 2;
    st7735_draw_hline(x + r, y,         w - 2 * r, color);
    st7735_draw_hline(x + r, y + h - 1, w - 2 * r, color);
    st7735_draw_vline(x,         y + r, h - 2 * r, color);
    st7735_draw_vline(x + w - 1, y + r, h - 2 * r, color);
    for (int16_t i = 0; i < r; i++) {
        int16_t ind = r - 1 - i;
        st7735_draw_pixel(x + ind,         y + i,         color);
        st7735_draw_pixel(x + w - 1 - ind, y + i,         color);
        st7735_draw_pixel(x + ind,         y + h - 1 - i, color);
        st7735_draw_pixel(x + w - 1 - ind, y + h - 1 - i, color);
    }
}

typedef enum {
    UI_ICON_GCS,
    UI_ICON_BATTERY,
    UI_ICON_POWER,
    UI_ICON_KEY,
    UI_ICON_PI,
    UI_ICON_IO,
    UI_ICON_WAIT,
    UI_ICON_ALERT,
    UI_ICON_LOCK,
    UI_ICON_SEARCHLIGHT,
    UI_ICON_RADAR,
    UI_ICON_PANTILT,
    UI_ICON_LIGHTBAR,
    UI_ICON_DEVICE,
    UI_ICON_SIGNAL,
    UI_ICON_TEMP,
} ui_icon_t;

static void draw_centered_string(int16_t y, const char *s,
                                 uint16_t fg, uint16_t bg, const font_t *font)
{
    st7735_draw_text((128 - st7735_text_width(s, font)) / 2, y, s, fg, bg, font);
}

static void draw_status_dot(int16_t x, int16_t y, uint16_t color, uint16_t bg)
{
    fill_rrect(x, y, 8, 8, 4, color);
    st7735_draw_pixel(x + 1, y + 1, ST7735_WHITE);
    st7735_draw_pixel(x + 6, y + 6, bg);
}

static void draw_icon(ui_icon_t icon, int16_t x, int16_t y,
                      uint16_t fg, uint16_t bg)
{
    st7735_fill_rect(x, y, 12, 12, bg);

    switch (icon) {
        case UI_ICON_GCS:
            st7735_draw_hline(x + 2, y + 5, 8, fg);
            st7735_draw_vline(x + 6, y + 2, 7, fg);
            fill_rrect(x + 1, y + 1, 3, 3, 1, fg);
            fill_rrect(x + 8, y + 1, 3, 3, 1, fg);
            fill_rrect(x + 1, y + 8, 3, 3, 1, fg);
            fill_rrect(x + 8, y + 8, 3, 3, 1, fg);
            break;

        case UI_ICON_BATTERY:
            draw_rrect(x + 1, y + 3, 9, 6, 1, fg);
            st7735_fill_rect(x + 10, y + 5, 2, 2, fg);
            st7735_fill_rect(x + 3, y + 5, 2, 2, fg);
            st7735_fill_rect(x + 6, y + 5, 2, 2, fg);
            break;

        case UI_ICON_POWER:
            st7735_draw_vline(x + 4, y + 2, 5, fg);
            st7735_draw_vline(x + 7, y + 2, 5, fg);
            st7735_draw_hline(x + 3, y + 7, 6, fg);
            st7735_draw_vline(x + 6, y + 7, 4, fg);
            st7735_draw_hline(x + 6, y + 10, 4, fg);
            break;

        case UI_ICON_KEY:
            draw_rrect(x + 1, y + 3, 5, 5, 2, fg);
            st7735_draw_pixel(x + 3, y + 5, bg);
            st7735_draw_hline(x + 6, y + 5, 5, fg);
            st7735_draw_vline(x + 9, y + 5, 3, fg);
            st7735_draw_vline(x + 11, y + 5, 2, fg);
            break;

        case UI_ICON_PI:
            fill_rrect(x + 2, y + 2, 8, 8, 2, fg);
            fill_rrect(x + 4, y + 4, 4, 4, 1, bg);
            for (int i = 0; i < 3; i++) {
                st7735_draw_pixel(x + 1, y + 3 + i * 2, fg);
                st7735_draw_pixel(x + 10, y + 3 + i * 2, fg);
            }
            break;

        case UI_ICON_IO:
            draw_rrect(x + 2, y + 3, 8, 6, 1, fg);
            st7735_draw_pixel(x + 3, y + 2, fg);
            st7735_draw_pixel(x + 5, y + 2, fg);
            st7735_draw_pixel(x + 7, y + 2, fg);
            st7735_draw_pixel(x + 3, y + 9, fg);
            st7735_draw_pixel(x + 5, y + 9, fg);
            st7735_draw_pixel(x + 7, y + 9, fg);
            break;

        case UI_ICON_WAIT:
            st7735_draw_hline(x + 3, y + 2, 6, fg);
            st7735_draw_hline(x + 3, y + 9, 6, fg);
            for (int i = 0; i < 4; i++) {
                st7735_draw_pixel(x + 4 + i, y + 3 + i, fg);
                st7735_draw_pixel(x + 7 - i, y + 3 + i, fg);
            }
            break;

        case UI_ICON_ALERT:
            for (int row = 0; row < 9; row++) {
                int16_t half = (int16_t)(row / 2);
                st7735_draw_hline(x + 6 - half, y + 1 + row, half * 2 + 1, fg);
            }
            st7735_draw_vline(x + 6, y + 4, 3, bg);
            st7735_draw_pixel(x + 6, y + 8, bg);
            break;

        case UI_ICON_LOCK:
            draw_rrect(x + 3, y + 1, 6, 6, 3, fg);
            st7735_fill_rect(x + 4, y + 5, 4, 3, bg);
            fill_rrect(x + 2, y + 6, 8, 5, 1, fg);
            st7735_draw_pixel(x + 6, y + 8, bg);
            break;

        case UI_ICON_SEARCHLIGHT:
            fill_rrect(x + 1, y + 6, 4, 4, 1, fg);
            for (int row = 0; row < 7; row++) {
                st7735_draw_hline(x + 5, y + 3 + row, row + 2, fg);
            }
            break;

        case UI_ICON_RADAR:
            st7735_draw_hline(x + 2, y + 9, 8, fg);
            st7735_draw_vline(x + 6, y + 5, 4, fg);
            st7735_draw_hline(x + 5, y + 5, 3, fg);
            st7735_draw_pixel(x + 4, y + 4, fg);
            st7735_draw_pixel(x + 8, y + 4, fg);
            st7735_draw_pixel(x + 3, y + 2, fg);
            st7735_draw_pixel(x + 9, y + 2, fg);
            break;

        case UI_ICON_PANTILT:
            fill_rrect(x + 2, y + 4, 8, 5, 1, fg);
            st7735_draw_pixel(x + 5, y + 6, bg);
            st7735_draw_pixel(x + 6, y + 6, bg);
            st7735_draw_vline(x + 6, y + 9, 2, fg);
            st7735_draw_hline(x + 3, y + 11, 6, fg);
            break;

        case UI_ICON_LIGHTBAR:
            fill_rrect(x + 1, y + 4, 10, 4, 1, fg);
            st7735_draw_vline(x + 4, y + 4, 4, bg);
            st7735_draw_vline(x + 8, y + 4, 4, bg);
            st7735_draw_hline(x + 2, y + 9, 8, fg);
            break;

        case UI_ICON_DEVICE:
            draw_rrect(x + 2, y + 2, 8, 8, 1, fg);
            st7735_draw_hline(x + 4, y + 5, 4, fg);
            st7735_draw_hline(x + 4, y + 7, 4, fg);
            break;

        case UI_ICON_SIGNAL:
            st7735_fill_rect(x + 2, y + 8, 2, 2, fg);
            st7735_fill_rect(x + 5, y + 6, 2, 4, fg);
            st7735_fill_rect(x + 8, y + 3, 2, 7, fg);
            break;

        case UI_ICON_TEMP:
            draw_rrect(x + 5, y + 2, 3, 7, 1, fg);
            fill_rrect(x + 3, y + 8, 7, 3, 2, fg);
            st7735_draw_vline(x + 6, y + 4, 5, bg);
            break;
    }
}

static ui_icon_t periph_icon(uint8_t addr)
{
    switch (addr) {
        case 0x01: return UI_ICON_SEARCHLIGHT;
        case 0x02: return UI_ICON_RADAR;
        case 0x03: return UI_ICON_PANTILT;
        case 0x04: return UI_ICON_LIGHTBAR;
        default:   return UI_ICON_DEVICE;
    }
}

static void draw_header(const char *title, ui_icon_t icon,
                        uint16_t bg, uint16_t fg, uint16_t accent)
{
    st7735_fill_rect(0, 0, 128, 16, bg);
    draw_icon(icon, 4, 2, fg, bg);
    draw_centered_string(4, title, fg, bg, &font_6x10);
    st7735_fill_rect(0, 16, 128, 1, accent);
}

/* ------------------------------------------------------------------ */
/* Internal state                                                         */
/* ------------------------------------------------------------------ */
static volatile uint8_t s_mode      = SCREEN_MODE_AUTO;
static          uint8_t s_last_mode = 0xFF; /* forces first render */
static          uint8_t s_wait_frame = 0;
static          uint8_t s_batwarning_frame = 0;

/* Snapshot of last rendered main-screen data — redraw only on change */
static uint16_t    s_last_bat_raw  = 0xFFFF;
static uint16_t    s_last_ext_raw  = 0xFFFF;
static uint8_t     s_last_porta    = 0xFF;
static uint8_t     s_last_portb    = 0xFF;
static sys_state_t s_last_sysstate = 0xFF;

/* ------------------------------------------------------------------ */
/* Peripheral screen state                                               */
/* ------------------------------------------------------------------ */
#define PERIPH_MAX_DISPLAY  8
#define PERIPH_DETAIL_BUF   32

static uint8_t  s_detail_addr  = 0x01;
static uint8_t  s_detail_cmd   = 0;
static uint8_t  s_detail_buf[PERIPH_DETAIL_BUF];
static uint8_t  s_detail_len   = 0;
static bool     s_detail_dirty = false;

/* ADC noise floor: ignore changes smaller than this many counts.
 * 16 counts ≈ 13 mV at the ADC, ≈ 118 mV after the 9.18 divider — about
 * the displayed 0.1 V precision, so this never hides a real change but
 * stops jitter from triggering redraws. */
#define ADC_REDRAW_HYST 16

static bool main_needs_redraw(void)
{
    uint16_t    bat = g_latest_adc.ch[ADC_CH_BAT_VIN];
    uint16_t    ext = g_latest_adc.ch[ADC_CH_EXT_VIN];
    uint8_t     pa  = g_latest_digital.port_a;
    uint8_t     pb  = g_latest_digital.port_b;
    sys_state_t st  = g_sys_state;

    int bat_d = (int)bat - (int)s_last_bat_raw; if (bat_d < 0) bat_d = -bat_d;
    int ext_d = (int)ext - (int)s_last_ext_raw; if (ext_d < 0) ext_d = -ext_d;

    if (bat_d < ADC_REDRAW_HYST && ext_d < ADC_REDRAW_HYST &&
        pa == s_last_porta && pb == s_last_portb && st == s_last_sysstate)
        return false;

    s_last_bat_raw  = bat;
    s_last_ext_raw  = ext;
    s_last_porta    = pa;
    s_last_portb    = pb;
    s_last_sysstate = st;
    return true;
}

/* ------------------------------------------------------------------ */
/* Render helpers                                                         */
/* ------------------------------------------------------------------ */

static void render_boot(void)
{
    st7735_draw_rgb565(0, 0, 128, 128, logo_kl_both);
}

static void render_waiting(void)
{
    st7735_fill_screen(COL_CHARCOAL);

    draw_header("PLEASE WAIT", UI_ICON_WAIT, COL_AMBER, ST7735_BLACK,
                ST7735_YELLOW);
    st7735_fill_rect(0, 17, 128,  2, ST7735_YELLOW);

    /* Rounded content panel */
    fill_rrect(8, 28, 112, 56, 6, COL_NAVY);

    draw_icon(UI_ICON_PI, 58, 33, ST7735_CYAN, COL_NAVY);
    draw_centered_string(50, "PI LINK", ST7735_YELLOW, COL_NAVY, &font_8x16);
    draw_centered_string(70, "Waiting", COL_LTGRAY, COL_NAVY, &font_6x10);

    /* Rounded progress dots (3 lit, 2 dim) */
    for (int i = 0; i < 5; i++) {
        uint16_t dot_col = (i < 3) ? COL_AMBER : ST7735_DARKGREY;
        fill_rrect(39 + i * 11, 90, 8, 8, 2, dot_col);
    }

    /* Yellow accent + amber footer */
    st7735_fill_rect(0, 106, 128,  2, ST7735_YELLOW);
    st7735_fill_rect(0, 108, 128, 20, COL_AMBER);
    /* "Stand by...": 11*6=66px, x=31 */
    st7735_draw_text(31, 115, "Stand by...", ST7735_BLACK, COL_AMBER, &font_6x10);
}

static void update_waiting_dots(void)
{
    uint8_t lit = s_wait_frame % 5;
    for (int i = 0; i < 5; i++) {
        uint16_t dot_col = (i == lit) ? COL_AMBER : ST7735_DARKGREY;
        fill_rrect(39 + i * 11, 90, 8, 8, 2, dot_col);
    }
    s_wait_frame++;
}

/* Track previous pill states so we only repaint them on transition —
 * repainting a pill bg flashes for one frame underneath the new text. */
static bool s_main_static_drawn = false;
static int8_t s_last_locked    = -1;
static int8_t s_last_connected = -1;
static uint16_t s_last_bat_col = 0xFFFE;

/* Static chrome — drawn once on mode entry. */
static void render_main_static(void)
{
    st7735_fill_screen(ST7735_BLACK);

    draw_header("GCS PANEL", UI_ICON_GCS, COL_NAVY, ST7735_WHITE, COL_TEAL);

    /* Battery card chrome */
    fill_rrect(4, 20, 120, 33, 4, COL_CHARCOAL);
    st7735_draw_text(24, 23, "BATTERY", ST7735_GREY, COL_CHARCOAL, &font_6x10);
    /* Charge bar track (border + black inner) */
    fill_rrect(8, 47, 112, 5, 2, ST7735_DARKGREY);
    fill_rrect(9, 48, 110, 3, 1, ST7735_BLACK);

    /* External card chrome */
    fill_rrect(4, 56, 120, 28, 4, COL_CHARCOAL);
    draw_icon(UI_ICON_POWER, 8, 60, ST7735_CYAN, COL_CHARCOAL);
    st7735_draw_text(24, 59, "EXTERNAL", ST7735_GREY, COL_CHARCOAL, &font_6x10);

    /* Status row separator */
    st7735_fill_rect(0, 85, 128, 1, COL_TEAL);

    /* I/O strip background */
    fill_rrect(4, 106, 120, 18, 4, COL_DKBLUE);
    draw_icon(UI_ICON_IO, 8, 109, COL_TEAL, COL_DKBLUE);

    s_last_locked    = -1;
    s_last_connected = -1;
    s_last_bat_col   = 0xFFFE;
    s_main_static_drawn = true;
}

/* Dynamic values — drawn whenever ADC/IO/state changes. Only repaints
 * the cells whose values actually changed, to avoid flicker. */
static void update_main_dynamic(void)
{
    char buf[24];

    /* ---- Battery value + bar ---- */
    float bat_v = adc_to_volts(g_latest_adc.ch[0], BAT_DIVIDER);
    snprintf(buf, sizeof(buf), "%4.1fV", (double)bat_v);
    uint16_t bat_col = (bat_v > 23.0f) ? ST7735_GREEN :
                       (bat_v > 21.0f) ? ST7735_YELLOW : ST7735_RED;
    draw_icon(UI_ICON_BATTERY, 8, 22, bat_col, COL_CHARCOAL);
    st7735_draw_text(40, 32, buf, bat_col, COL_CHARCOAL, &font_8x16);

    /* Bar: only clear the unfilled tail when colour changed; else just
     * extend/shrink the coloured portion + clear what's beyond. */
    int fill = (int)((bat_v - 18.0f) / (25.2f - 18.0f) * 108.0f);
    if (fill < 0)   fill = 0;
    if (fill > 108) fill = 108;
    if (bat_col != s_last_bat_col) {
        fill_rrect(9, 48, 110, 3, 1, ST7735_BLACK);
        s_last_bat_col = bat_col;
    }
    if (fill > 0)       fill_rrect(10, 48, fill, 3, 1, bat_col);
    if (fill < 108)     st7735_fill_rect(10 + fill, 48, 108 - fill, 3,
                                         ST7735_BLACK);

    /* ---- External voltage ---- */
    float ext_v = adc_to_volts(g_latest_adc.ch[1], EXT_DIVIDER);
    snprintf(buf, sizeof(buf), "%4.1fV", (double)ext_v);
    st7735_draw_text(40, 68, buf, ST7735_CYAN, COL_CHARCOAL, &font_8x16);

    /* ---- Key pill (only on transition) ---- */
    bool locked = (g_latest_digital.port_a & (1u << IOEXP_A_KEY));
    if ((int8_t)locked != s_last_locked) {
        uint16_t key_col = locked ? ST7735_RED : ST7735_GREEN;
        fill_rrect(4, 88, 58, 14, 4, key_col);
        draw_icon(UI_ICON_KEY, 8, 89, ST7735_WHITE, key_col);
        st7735_draw_text(24, 92, locked ? "LOCK" : "OPEN", ST7735_WHITE,
                         key_col, &font_6x10);
        s_last_locked = (int8_t)locked;
    }

    /* ---- I/O hex ---- */
    snprintf(buf, sizeof(buf), "I/O A:%02X B:%02X",
             g_latest_digital.port_a & 0xFF,
             g_latest_digital.port_b & 0xFF);
    st7735_draw_text(28, 112, buf, COL_LTGRAY, COL_DKBLUE, &font_6x10);

    /* ---- Pi pill (only on transition) ---- */
    sys_state_t state = g_sys_state;
    bool connected = (state == SYS_CONNECTED || state == SYS_ACTIVE);
    if ((int8_t)connected != s_last_connected) {
        uint16_t pi_col = connected ? ST7735_GREEN : COL_AMBER;
        fill_rrect(66, 88, 58, 14, 4, pi_col);
        draw_icon(UI_ICON_PI, 70, 89, ST7735_WHITE, pi_col);
        st7735_draw_text(86, 92, connected ? "CONN" : "WAIT", ST7735_WHITE,
                         pi_col, &font_6x10);
        s_last_connected = (int8_t)connected;
    }
}

static void render_warning(void)
{
    st7735_fill_screen(COL_DKRED);

    /* Outer orange "glow" triangle: apex (64,5), base y=100, half-width=57 */
    for (int y = 5; y <= 100; y++) {
        int half = (int)((float)(y - 5) / 95.0f * 57.0f);
        st7735_draw_hline(64 - half, y, 2 * half + 1, ST7735_ORANGE);
    }

    /* Inner yellow triangle: apex (64,8), base y=98, half-width=54 */
    for (int y = 8; y <= 98; y++) {
        int half = (int)((float)(y - 8) / 90.0f * 54.0f);
        st7735_draw_hline(64 - half, y, 2 * half + 1, ST7735_YELLOW);
    }

    /* Black exclamation mark centred inside triangle */
    st7735_fill_rect(60, 44, 8, 28, ST7735_BLACK);  /* shaft */
    st7735_fill_rect(60, 79, 8,  8, ST7735_BLACK);  /* dot   */

    /* Short rounded orange accent pill */
    fill_rrect(14, 101, 100, 4, 2, ST7735_ORANGE);
    /* Rounded footer panel */
    fill_rrect(4, 105, 120, 23, 4, ST7735_DARKGREY);
    draw_centered_string(109, "WARNING", ST7735_RED, ST7735_DARKGREY, &font_8x16);
}

static void render_lock(void)
{
    st7735_fill_screen(COL_CHARCOAL);

    /* Shackle: pill-shaped arch top + two straight legs */
    /* Arch (r = h/2 → full stadium shape): x=46, y=18, w=36, h=14, r=7 */
    fill_rrect(46, 18, 36, 14, 7, COL_LTGRAY);
    /* Legs connect at y=24 (where arch reaches full width) */
    st7735_fill_rect(46, 24, 8, 34, COL_LTGRAY);   /* left leg  y=24–57 */
    st7735_fill_rect(74, 24, 8, 34, COL_LTGRAY);   /* right leg y=24–57 */

    /* Body: rounded amber rectangle; body overdraws bottom of legs */
    fill_rrect(32, 56, 64, 44, 6, COL_AMBER);
    draw_rrect(32, 56, 64, 44, 6, ST7735_YELLOW);  /* yellow border */

    /* Keyhole centred in body: x=(128-12)/2=58 */
    fill_rrect(58, 64, 12, 22, 3, COL_CHARCOAL);

    draw_centered_string(106, "LOCKED", ST7735_RED, COL_CHARCOAL, &font_8x16);
}

static void update_batwarning(void)
{
    bool flash = (s_batwarning_frame & 1);

    /* Repaint battery interior: toggle red fill on/off */
    fill_rrect(10, 28, 92, 44, 4, COL_CHARCOAL);
    if (!flash) {
        fill_rrect(10, 28, 14, 44, 4, ST7735_RED);
        st7735_draw_vline(24, 28, 44, COL_AMBER);
    }

    /* Flash "CHARGE NOW!" between white and yellow */
    uint16_t txt_col = flash ? ST7735_YELLOW : ST7735_WHITE;
    draw_centered_string(113, "CHARGE NOW!", txt_col, ST7735_RED, &font_6x10);

    s_batwarning_frame++;
}

static void render_batwarning(void)
{
    s_batwarning_frame = 0;
    st7735_fill_screen(COL_CHARCOAL);

    draw_header("LOW BATTERY", UI_ICON_BATTERY, ST7735_RED, ST7735_WHITE,
                COL_AMBER);
    st7735_fill_rect(0, 17, 128,  2, COL_AMBER);

    /* Battery icon with rounded body */
    fill_rrect( 8, 26,  96, 48, 5, ST7735_DARKGREY);  /* outer border   */
    fill_rrect(10, 28,  92, 44, 4, COL_CHARCOAL);     /* interior       */
    st7735_fill_rect(104, 40, 10, 18, ST7735_DARKGREY); /* terminal nub   */
    st7735_fill_rect(106, 42,  6, 14, COL_CHARCOAL);  /* terminal inner */
    fill_rrect(10, 28,  14, 44, 4, ST7735_RED);        /* ~15% red fill  */
    st7735_draw_vline(24, 28, 44, COL_AMBER);          /* charge marker  */

    float bat_v = adc_to_volts(g_latest_adc.ch[0], BAT_DIVIDER);
    char buf[16];
    snprintf(buf, sizeof(buf), "%4.1fV", (double)bat_v);
    draw_centered_string(82, buf, ST7735_YELLOW, COL_CHARCOAL, &font_8x16);

    /* Amber accent + red footer */
    st7735_fill_rect(0, 104, 128,  2, COL_AMBER);
    st7735_fill_rect(0, 106, 128, 22, ST7735_RED);
    draw_centered_string(113, "CHARGE NOW!", ST7735_WHITE, ST7735_RED, &font_6x10);
}

/* ------------------------------------------------------------------ */
/* Peripheral helper                                                      */
/* ------------------------------------------------------------------ */

static const char *periph_name(uint8_t addr)
{
    switch (addr) {
        case 0x01: return "Searchlight";
        case 0x02: return "Radar";
        case 0x03: return "Pan-Tilt";
        case 0x04: return "Light Bar";
        default:   return "Device";
    }
}

/* ------------------------------------------------------------------ */
/* Peripheral overview screen (mode 5)                                   */
/* ------------------------------------------------------------------ */

static void render_periph_overview(void)
{
    st7735_fill_screen(ST7735_BLACK);
    char buf[24];

    draw_header("PERIPHERALS", UI_ICON_DEVICE, COL_NAVY, ST7735_WHITE,
                COL_TEAL);

    /* Pull fresh data from RS-485 layer */
    uint8_t addrs[PERIPH_MAX_DISPLAY];
    bool    online[PERIPH_MAX_DISPLAY];
    uint8_t count = rs485_get_peripherals(addrs, online, PERIPH_MAX_DISPLAY);

    uint8_t online_count = 0;
    if (count == 0) {
        draw_icon(UI_ICON_DEVICE, 58, 43, ST7735_DARKGREY, ST7735_BLACK);
        draw_centered_string(61, "NO DEVICES", COL_LTGRAY, ST7735_BLACK, &font_6x10);
    }

    for (int i = 0; i < count; i++) {
        int16_t row_y = 21 + i * 11;
        bool    is_on = online[i];
        if (is_on) online_count++;

        draw_icon(periph_icon(addrs[i]), 4, row_y - 2,
                  is_on ? COL_TEAL : ST7735_DARKGREY, ST7735_BLACK);

        /* Address */
        snprintf(buf, sizeof(buf), "%02X", addrs[i]);
        st7735_draw_text(20, row_y, buf, COL_LTGRAY, ST7735_BLACK, &font_6x10);

        /* Name */
        st7735_draw_text(36, row_y, periph_name(addrs[i]),
                         ST7735_WHITE, ST7735_BLACK, &font_6x10);

        draw_status_dot(116, row_y, is_on ? ST7735_GREEN : ST7735_RED,
                        ST7735_BLACK);
    }

    /* Footer summary */
    st7735_fill_rect(0, 114, 128, 1, COL_TEAL);
    st7735_fill_rect(0, 115, 128, 13, COL_NAVY);
    snprintf(buf, sizeof(buf), "%d devs  %d online", count, online_count);
    int16_t tw = st7735_text_width(buf, &font_6x10);
    st7735_draw_text((128 - tw) / 2, 118, buf, COL_TEAL, COL_NAVY, &font_6x10);
}

/* ------------------------------------------------------------------ */
/* Peripheral detail screen (mode 6)                                     */
/* ------------------------------------------------------------------ */

static void render_periph_detail(void)
{
    st7735_fill_screen(ST7735_BLACK);
    char buf[24];

    const char *name = periph_name(s_detail_addr);
    draw_header(name, periph_icon(s_detail_addr), COL_NAVY, ST7735_WHITE,
                COL_TEAL);
    int16_t tw;

    /* Body — layout depends on peripheral type */
    if (s_detail_len == 0) {
        /* "No data yet": 11*6=66px, x=31 */
        draw_icon(periph_icon(s_detail_addr), 58, 42, ST7735_DARKGREY,
                  ST7735_BLACK);
        draw_centered_string(60, "No data yet", COL_LTGRAY, ST7735_BLACK, &font_6x10);
    } else {
        switch (s_detail_addr) {

            case 0x01: /* Searchlight: brightness(u8), temp_C(i8), faults(u8) */
                if (s_detail_len >= 3) {
                    uint8_t brightness = s_detail_buf[0];
                    int8_t  temp_c     = (int8_t)s_detail_buf[1];
                    uint8_t faults     = s_detail_buf[2];

                    draw_icon(UI_ICON_LIGHTBAR, 4, 20, ST7735_CYAN, ST7735_BLACK);
                    st7735_draw_text(20, 22, "Brightness", COL_LTGRAY, ST7735_BLACK, &font_6x10);
                    int pct = (int)((brightness * 100u) / 255u);
                    snprintf(buf, sizeof(buf), "%3d%%", pct);
                    st7735_draw_text(88, 22, buf, ST7735_WHITE, ST7735_BLACK, &font_6x10);
                    fill_rrect(4, 32, 120, 6, 3, COL_CHARCOAL);
                    int bw = (int)((brightness * 120u) / 255u);
                    if (bw > 0) fill_rrect(4, 32, bw, 6, 3, ST7735_CYAN);

                    draw_icon(UI_ICON_TEMP, 4, 42, COL_LTGRAY, ST7735_BLACK);
                    st7735_draw_text(20, 44, "Temp", COL_LTGRAY, ST7735_BLACK, &font_6x10);
                    snprintf(buf, sizeof(buf), "%d C", (int)temp_c);
                    uint16_t t_col = (temp_c < 60) ? ST7735_GREEN :
                                     (temp_c < 75) ? COL_AMBER : ST7735_RED;
                    st7735_draw_text(60, 44, buf, t_col, ST7735_BLACK, &font_8x16);

                    draw_icon(UI_ICON_ALERT, 4, 66, COL_AMBER, ST7735_BLACK);
                    st7735_draw_text(20, 68, "Faults", COL_LTGRAY, ST7735_BLACK, &font_6x10);
                    if (faults == 0) {
                        st7735_draw_text(60, 68, "NONE", ST7735_GREEN, ST7735_BLACK, &font_6x10);
                    } else {
                        if (faults & 0x01) st7735_draw_text(4, 80, "Overcurrent",
                                               ST7735_RED, ST7735_BLACK, &font_6x10);
                        if (faults & 0x02) st7735_draw_text(4, 90, "Overtemp",
                                               ST7735_RED, ST7735_BLACK, &font_6x10);
                        if (faults & 0x04) st7735_draw_text(4, 100, "Undervolt",
                                               ST7735_RED, ST7735_BLACK, &font_6x10);
                    }
                }
                break;

            case 0x02: /* Radar: distance_mm(u16 LE), signal(u8), status(u8) */
                if (s_detail_len >= 4) {
                    uint16_t dist_mm = (uint16_t)s_detail_buf[0]
                                     | ((uint16_t)s_detail_buf[1] << 8);
                    uint8_t  signal  = s_detail_buf[2];
                    uint8_t  status  = s_detail_buf[3];

                    draw_icon(UI_ICON_RADAR, 4, 20, ST7735_CYAN, ST7735_BLACK);
                    st7735_draw_text(20, 22, "Distance", COL_LTGRAY, ST7735_BLACK, &font_6x10);
                    snprintf(buf, sizeof(buf), "%u mm", (unsigned)dist_mm);
                    int16_t dw = st7735_text_width(buf, &font_8x16);
                    st7735_draw_text((128 - dw) / 2, 34, buf,
                                     ST7735_CYAN, ST7735_BLACK, &font_8x16);

                    draw_icon(UI_ICON_SIGNAL, 4, 56, ST7735_GREEN, ST7735_BLACK);
                    st7735_draw_text(20, 58, "Signal", COL_LTGRAY, ST7735_BLACK, &font_6x10);
                    fill_rrect(4, 68, 120, 6, 3, COL_CHARCOAL);
                    int sw = (int)((signal * 120u) / 255u);
                    if (sw > 0) fill_rrect(4, 68, sw, 6, 3, ST7735_GREEN);

                    draw_icon(UI_ICON_DEVICE, 4, 78, COL_LTGRAY, ST7735_BLACK);
                    st7735_draw_text(20, 80, "Status", COL_LTGRAY, ST7735_BLACK, &font_6x10);
                    st7735_draw_text(60, 80, status == 0 ? "OK " : "ERR",
                                     status == 0 ? ST7735_GREEN : ST7735_RED,
                                     ST7735_BLACK, &font_6x10);
                }
                break;

            case 0x03: /* Pan-Tilt: pan_deg(u8), tilt_deg(u8), moving(u8) */
                if (s_detail_len >= 3) {
                    uint8_t pan    = s_detail_buf[0];
                    uint8_t tilt   = s_detail_buf[1];
                    uint8_t moving = s_detail_buf[2];

                    draw_icon(UI_ICON_PANTILT, 4, 20, ST7735_CYAN, ST7735_BLACK);
                    st7735_draw_text(20, 22, "Pan", COL_LTGRAY, ST7735_BLACK, &font_6x10);
                    snprintf(buf, sizeof(buf), "%3d", (int)pan);
                    st7735_draw_text(62, 22, buf, ST7735_CYAN, ST7735_BLACK, &font_8x16);
                    st7735_draw_text(100, 28, "deg", COL_LTGRAY, ST7735_BLACK, &font_6x10);

                    draw_icon(UI_ICON_PANTILT, 4, 46, ST7735_CYAN, ST7735_BLACK);
                    st7735_draw_text(20, 48, "Tilt", COL_LTGRAY, ST7735_BLACK, &font_6x10);
                    snprintf(buf, sizeof(buf), "%3d", (int)tilt);
                    st7735_draw_text(62, 48, buf, ST7735_CYAN, ST7735_BLACK, &font_8x16);
                    st7735_draw_text(100, 54, "deg", COL_LTGRAY, ST7735_BLACK, &font_6x10);

                    draw_icon(UI_ICON_WAIT, 4, 74, COL_AMBER, ST7735_BLACK);
                    st7735_draw_text(20, 76, "Motion", COL_LTGRAY, ST7735_BLACK, &font_6x10);
                    uint16_t m_col = moving ? COL_AMBER : ST7735_GREEN;
                    fill_rrect(60, 74, 40, 12, 4, m_col);
                    st7735_draw_text(64, 77, moving ? "MOVE" : "IDLE",
                                     ST7735_WHITE, m_col, &font_6x10);
                }
                break;

            default: /* Generic: hex dump of first 8 bytes */
                st7735_draw_text(4, 22, "Raw data:", COL_LTGRAY, ST7735_BLACK, &font_6x10);
                for (int i = 0; i < s_detail_len && i < 8; i++) {
                    snprintf(buf, sizeof(buf), "%02X", s_detail_buf[i]);
                    st7735_draw_text(4 + i * 18, 36, buf,
                                     ST7735_WHITE, ST7735_BLACK, &font_6x10);
                }
                break;
        }
    }

    /* Footer: address + online status */
    st7735_fill_rect(0, 114, 128, 1, COL_TEAL);
    st7735_fill_rect(0, 115, 128, 13, COL_NAVY);

    uint8_t addrs[PERIPH_MAX_DISPLAY];
    bool    online_flags[PERIPH_MAX_DISPLAY];
    uint8_t cnt = rs485_get_peripherals(addrs, online_flags, PERIPH_MAX_DISPLAY);
    bool is_on = false;
    for (int i = 0; i < cnt; i++) {
        if (addrs[i] == s_detail_addr) { is_on = online_flags[i]; break; }
    }

    snprintf(buf, sizeof(buf), "0x%02X  %s",
             s_detail_addr, is_on ? "ONLINE" : "OFFLINE");
    tw = st7735_text_width(buf, &font_6x10);
    st7735_draw_text((128 - tw) / 2, 118, buf,
                     is_on ? ST7735_GREEN : ST7735_RED, COL_NAVY, &font_6x10);
}

/* ------------------------------------------------------------------ */
/* Peripheral screen public API                                           */
/* ------------------------------------------------------------------ */

void screen_periph_set_detail_addr(uint8_t addr)
{
    s_detail_addr  = addr;
    s_detail_len   = 0;
    s_detail_dirty = true;
}

void screen_periph_update_data(uint8_t addr, uint8_t cmd,
                               const uint8_t *payload, uint8_t len)
{
    if (addr != s_detail_addr) return;
    s_detail_cmd = cmd;
    if (len > PERIPH_DETAIL_BUF) len = PERIPH_DETAIL_BUF;
    memcpy(s_detail_buf, payload, len);
    s_detail_len   = len;
    s_detail_dirty = true;
}

/* ------------------------------------------------------------------ */
/* Public API                                                             */
/* ------------------------------------------------------------------ */

void screen_display_init(void)
{
    /* GPIO direction for TFT pins — safe to call before scheduler starts.
     * The full st7735_init() (which uses vTaskDelay) is called from
     * screen_task after the scheduler has started. */
    gpio_init(PIN_TFT_CS);  gpio_set_dir(PIN_TFT_CS,  GPIO_OUT); gpio_put(PIN_TFT_CS,  1);
    gpio_init(PIN_TFT_DC);  gpio_set_dir(PIN_TFT_DC,  GPIO_OUT); gpio_put(PIN_TFT_DC,  1);
    gpio_init(PIN_TFT_RST); gpio_set_dir(PIN_TFT_RST, GPIO_OUT); gpio_put(PIN_TFT_RST, 1);
}

void screen_task(void *param)
{
    (void)param;

    /* Full hardware init here — uses vTaskDelay, needs scheduler running */
    st7735_init();
    render_boot();
    vTaskDelay(pdMS_TO_TICKS(7000));   /* hold boot screen for 7 s */

    TickType_t last_wake = xTaskGetTickCount();
    const TickType_t period = pdMS_TO_TICKS(200);

    while (1) {
        /* Check for host-override notification (non-blocking) */
        uint32_t notified_mode = 0;
        if (xTaskNotifyWait(0, 0xFFFFFFFF, &notified_mode, 0) == pdTRUE) {
            s_mode = (uint8_t)notified_mode;
        }

        /* Determine effective render mode */
        uint8_t effective;
        if (s_mode == SCREEN_MODE_AUTO) {
            /* Map system state to a render mode */
            switch (g_sys_state) {
                case SYS_BOOT:
                case SYS_INIT:
                    effective = 0xFF; /* boot splash — rendered by init */
                    break;
                case SYS_WAITING_FOR_PI:
                    effective = SCREEN_MODE_AUTO + 10; /* special "waiting" */
                    break;
                case SYS_LOCKED:
                    effective = SCREEN_MODE_LOCK;
                    break;
                case SYS_ERROR:
                    effective = SCREEN_MODE_WARNING;
                    break;
                default:
                    effective = SCREEN_MODE_MAIN;
                    break;
            }
        } else {
            effective = s_mode;
        }

        if (effective != s_last_mode) {
            s_last_mode = effective;
            if (effective != SCREEN_MODE_MAIN) s_main_static_drawn = false;
            switch (effective) {
                case SCREEN_MODE_MAIN:
                    render_main_static();
                    update_main_dynamic();
                    break;
                case SCREEN_MODE_WARNING:       render_warning();        break;
                case SCREEN_MODE_LOCK:          render_lock();           break;
                case SCREEN_MODE_BATWARNING:    render_batwarning();     break;
                case SCREEN_MODE_PERIPH:        render_periph_overview(); break;
                case SCREEN_MODE_PERIPH_DETAIL: render_periph_detail();  break;
                case SCREEN_MODE_AUTO + 10: s_wait_frame = 0; render_waiting(); break;
                case 0xFF:                                   break; /* boot — skip */
                default:
                    render_main_static();
                    update_main_dynamic();
                    break;
            }
        } else if (effective == SCREEN_MODE_MAIN && main_needs_redraw()) {
            update_main_dynamic();
        } else if (effective == SCREEN_MODE_AUTO + 10) {
            update_waiting_dots();
        } else if (effective == SCREEN_MODE_BATWARNING) {
            update_batwarning();
        } else if (effective == SCREEN_MODE_PERIPH_DETAIL && s_detail_dirty) {
            s_detail_dirty = false;
            render_periph_detail();
        }

        vTaskDelayUntil(&last_wake, period);
    }
}
