#ifndef FONT_DATA_H
#define FONT_DATA_H

#include <stdint.h>

/* Generic bitmap font descriptor.
 *
 * Glyph bitmap is stored as `height` rows of `bytes_per_row` bytes each,
 * MSB = leftmost pixel. For widths <= 8, bytes_per_row = 1 and unused
 * low-order bits in each row should be zero.
 *
 * `data` points to glyphs (last - first + 1) packed contiguously: glyph 0
 * is `first`, glyph 1 is `first+1`, etc. `width` is the cell advance (so
 * a 6-wide glyph in a 6x10 cell uses bits 7..2 of each row byte; bits
 * 1..0 are zero/spacer).
 */
typedef struct {
    uint8_t  width;          /* glyph cell advance in pixels         */
    uint8_t  height;         /* glyph cell height in pixels          */
    uint8_t  bytes_per_row;  /* row stride per glyph                 */
    uint8_t  first;          /* first ASCII char in table (0x20)     */
    uint8_t  last;           /* last  ASCII char in table (0x7E)     */
    const uint8_t *data;     /* glyph bitmap data                    */
} font_t;

/* The three available fonts. */
extern const font_t font_5x7;    /* legacy small font, scalable      */
extern const font_t font_6x10;   /* clean body text, descenders      */
extern const font_t font_8x16;   /* large titles / readouts          */

#endif /* FONT_DATA_H */
