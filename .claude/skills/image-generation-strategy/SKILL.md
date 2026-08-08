---
name: image-generation-strategy
description: >
  Share cards are rendered on demand by the app, not checked into the repo.
  There is nothing to generate when writing a post. Read this before adding image
  assets for posts, or changing the card layout, the brand tokens or the fonts.
license: MIT
metadata:
  author: filipecabaco
  version: "5.0.0"
---

# Share cards

**Do not generate or commit card images.** `Blog.Card` draws them on request, so a
card can never fall out of step with a post's title or the brand.

| Route | Card |
|---|---|
| `/images/posts/{slug}.png` | the post's card |
| `/images/og-root.png` | the site card |

Writing a post requires no image work at all. Adding the post is enough.

## How it works

`Blog.Card.svg/2` lays the card out as SVG from post metadata and the brand
tokens, then `rsvg-convert` rasterises it to a 1200x630 PNG. Results are cached
in ETS against a hash of the title, date and reading time, so each card is drawn once
and redrawn automatically when any of those change.

Fonts come from `priv/fonts` via a generated `fontconfig` file, so rendering does
not depend on what is installed on the host. `rsvg-convert` is installed in the
runtime image by the Dockerfile.

## Card anatomy

```
┌──────────────────────────────────────────────────────────┐
│ ● FILIPECABACO.COM                                       │
│                                                          │
│   Realtime Updates                            ▪▫▪▪▫      │
│   with LiveView                               ▫▪▫▪▪      │
│                                               ▪▪▫▫▪      │
│ ─────────────────────────────────────────────────────    │
│ 2022-09-13                                 16 MIN READ   │
└──────────────────────────────────────────────────────────┘
```

The title steps down through 84 / 70 / 62 / 56px so it always clears the mark on
the right. SVG has no line breaking, so `Blog.Card` wraps the title itself.

## The mark

`Blog.Mark` builds a 5x5 patch panel whose lit cells come from `sha256(slug)`:
every post gets a distinct figure from one system, and the same post always draws
the same one. The site renders the identical mark inline as SVG on the index, via
the `mark/1` component in `BlogWeb.Layouts`.

## Brand

Cards always use the light theme, since they appear on someone else's background
in a feed. Tokens are resolved to sRGB in `Blog.Card` because librsvg cannot parse
`oklch()`; if the tokens in `app.css` change, update the hex values there too.

| Role | Token | sRGB |
|---|---|---|
| Ground | `--paper` | `#faf7f3` |
| Text | `--ink` | `#271f18` |
| Labels | `--ink-3` | `#87807a` |
| Rules | `--rule` | `#d9d4ce` |
| Unlit cells | `--rule-2` | `#c1bbb3` |
| Mark, dot | `--signal` | `#d33a0c` |

Type: **Familjen Grotesk** for the title, **JetBrains Mono** for labels.

## Icons

`priv/static/images/logo.svg` is the source for the favicon and touch icon. To
regenerate the raster versions after editing it:

```bash
rsvg-convert priv/static/images/logo.svg -w 512 -h 512 -o priv/static/images/logo.png
rsvg-convert priv/static/images/logo.svg -w 180 -h 180 -o priv/static/images/apple-touch-icon.png
```
