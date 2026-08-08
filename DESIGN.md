# Design

The visual system for filipecabaco.com. Source of truth is `assets/css/app.css`;
this explains the intent behind it.

## Register and lane

Brand register: the design is the product. The lane is **Nordic telecom technical
documentation**, roughly 1985 — Ericsson switching manuals, Bang & Olufsen product
literature. Precise, warm, mechanical.

The reasoning is not decorative. The BEAM was built at Ericsson to run telephone
exchanges, and this blog runs a process per connected reader and shows where each
one has read to. Line status, plate numbers and patch panels are the subject
matter here.

Deliberately **not**: GitHub dark (the reflex answer for a developer blog), and
not the display-serif editorial look that is the reflex one tier down.

## Theme

Light by default. These are 3000-word technical articles read at a desk in the
afternoon, not dashboards watched at 2am. Dark is a real second theme, not an
afterthought.

Three states are supported: no `data-theme` (follow the system), `data-theme="light"`,
`data-theme="dark"`. Every colour is defined on bare `:root` first, so nothing
depends on a media query resolving.

## Colour

Strategy: **Committed**. One saturated signal colour, used the way a busy-line lamp
is used, never as ornament. Every neutral is tinted toward the signal hue.

| Token | Light | Role |
|---|---|---|
| `--paper` | `oklch(0.977 0.006 72)` | page ground |
| `--paper-2` / `--paper-3` | | sunk panels, code, meters |
| `--ink` | `oklch(0.245 0.017 58)` | body text |
| `--ink-2` / `--ink-3` | | secondary, labels |
| `--rule` / `--rule-2` | | hairlines, borders |
| `--signal` | `oklch(0.575 0.196 35)` | the one accent |

`Blog.Card` holds sRGB equivalents because librsvg cannot parse `oklch()`. If these
change, update those too.

### Code

Neutrals carry structure, the signal carries atoms. Keywords get **weight**, not
hue. Three low-chroma hues total: signal for atoms, a muted green for strings, a
muted indigo for numbers. Highlighting is done on the server by Makeup.

## Typography

| Family | Use |
|---|---|
| **Familjen Grotesk** | headings, nav, labels, the wordmark |
| **Literata** | body prose |
| **JetBrains Mono** | code, metadata, numeric readouts |

Self-hosted from `priv/static/fonts` as latin-subset woff2. Familjen Grotesk is a
Swedish grotesk: warm and mechanical, which is the voice. Literata is there because
a 16-minute article has to be readable; the old site set body copy in monospace,
which is the single biggest reason it read as dated.

Scale steps by roughly 1.28 (`--size-000` to `--size-5`), fluid via `clamp()` at the
display sizes. Body measure is capped at `68ch`.

## Layout

One grid, `.frame`, used by every page: a `12.5rem` rail plus a content column.
This is what keeps left edges aligned across the index, a post and the stats page —
they previously sat on three different container widths (1200 / 800 / 900).

The rail carries metadata, contents and presence. Below `60rem` it collapses into a
horizontal strip above the content.

## The mark

`Blog.Mark` draws a 5×5 patch panel whose lit cells come from `sha256(slug)`. Every
post gets a distinct figure from one system, and the same post always draws the
same one. Rendered inline as SVG on the index and into the share card by `Blog.Card`.

## Labels

A named annotation system, not decoration sprinkled above every heading: `.label`
for uppercase mono field captions, `.plate` for plate numbers and tabular figures.

## Motion

Restrained. `--ease` is ease-out-quart; no bounce. The one place motion carries
meaning is the presence lamps sliding on the rail as other readers scroll.
`prefers-reduced-motion` is honoured.

## Presence

The signature feature. Lamps on a vertical track, one per connected reader,
positioned by a 0–1 fraction of the article. Your own lamp is the signal colour and
slightly larger; everyone else's is neutral.

The track lives in the rail on desktop. On a phone the rail scrolls away within a
screen, so the track pins to the right edge of the viewport and stays visible for
the whole article — otherwise the one thing that makes this blog different is only
on screen for the first two seconds. Track height comes from `--track`, so the same
lamp positioning works at both sizes.
