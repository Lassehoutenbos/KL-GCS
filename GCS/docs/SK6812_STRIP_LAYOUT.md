# SK6812 Status Strip — Pixel Layout

The SK6812 RGBW strip on the front panel runs **vertically between Payload-1
and Payload-2 connector groups**. Functionally it is a **status indicator** —
each contiguous pixel range corresponds to one switch group on the panel.

Total pixels: **38** (indices `0..37`). Gap pixels stay off and act as
separators between groups.

## Pixel-to-switch mapping

| Pixel range | Length | Switch group | Notes                |
|------------:|-------:|--------------|----------------------|
| `0 – 3`     | 4      | **SW2-1**    | top of payload column |
| `4`         | 1      | gap          | separator (off)      |
| `5 – 8`     | 4      | **SW2-2**    |                      |
| `9 – 10`    | 2      | gap          | separator (off)      |
| `11 – 13`   | 3      | **SW2-3**    |                      |
| `14 – 17`   | 4      | **SW1-1**    |                      |
| `18`        | 1      | gap          | separator (off)      |
| `19 – 22`   | 4      | **SW1-2**    |                      |
| `23`        | 1      | gap          | separator (off)      |
| `24 – 27`   | 4      | **SW1-3**    |                      |
| `28 – 37`   | 10     | **SW3**      | bottom — largest segment |

## Group summary

| Group  | Start | End | Length |
|--------|------:|----:|-------:|
| SW2-1  | 0     | 3   | 4      |
| SW2-2  | 5     | 8   | 4      |
| SW2-3  | 11    | 13  | 3      |
| SW1-1  | 14    | 17  | 4      |
| SW1-2  | 19    | 22  | 4      |
| SW1-3  | 24    | 27  | 4      |
| SW3    | 28    | 37  | 10     |

## Usage

The strip is intended as a **status indicator**, not decorative. Each group's
colour reflects the live state of the matching switch / function (e.g. armed,
selected, fault). Gap pixels remain off so groups read as discrete bars.

For bench testing, `Testcode/gcs_tester.py` exposes two animation modes that
use this mapping:

- **Groups** — each group lit a distinct hue, gaps off. Verifies physical
  alignment of pixel ranges to switch labels at a glance.
- **Group-Sweep** — one group lit at a time, advancing top-to-bottom, gaps
  off. Useful for confirming order and counting.

Both honour the SK6812 colour sliders only as an *intensity* baseline; the
hue of each group is fixed for identification.
