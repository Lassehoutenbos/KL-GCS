#ifndef LOGO_KL_H
#define LOGO_KL_H

#include <stdint.h>

/* 128x128 RGB565 logo (KL-Systems "Both"). Big-endian byte order is applied
 * at draw time by st7735_draw_rgb565(). */
extern const uint16_t logo_kl_both[128 * 128];

#endif
