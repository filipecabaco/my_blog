---
name: image-generation-strategy
description: >
  Every blog post MUST have a generated card image at priv/static/images/posts/{slug}.png.
  Images are topic-based SVG illustrations converted to PNG via rsvg-convert, following the GitHub dark theme.
  When creating a new post, always generate its image. When updating tags or title, regenerate.
license: MIT
metadata:
  author: filipecabaco
  version: "3.1.0"
---

# Image Generation Strategy

Every blog post requires a card image. Images are **illustration-only** (no title, no tags — those are shown in the HTML card below the image). Generated as SVG then converted to PNG.

**Model guidance**: When invoked as part of a larger workflow, use `opus` for SVG generation — this is creative/implementation work.

## Required: Generate Image for Every New Post

When a new blog post is created, you MUST:
1. Read the post title, tags, and content to understand the topic
2. Choose an illustration style based on tags (see mapping below)
3. Generate an SVG with **only the illustration and accent line** (no title text, no tag pills)
4. Convert to PNG at `priv/static/images/posts/{slug}.png`
5. The slug is the filename without `.md` (e.g., `2022-07-16_making_my_blog`)

## File Locations

| What | Path |
|------|------|
| Generated PNGs | `priv/static/images/posts/{slug}.png` |
| Image in template | `"/images/posts/#{post.title}.png"` (in index.ex) |
| CSS class | `.post-card-image` |

## Visual Style (GitHub Dark Theme)

All images are **1200x630** and strictly monochromatic:

| Element | Color |
|---------|-------|
| Background | `#0d1117` |
| Panel/card fills | `#161b22` |
| Tertiary fills | `#1c2128` |
| Primary text (title) | `#e6edf3` |
| Secondary text (labels) | `#8b949e` |
| Muted elements | `#6e7681` |
| Borders/strokes | `#30363d` |
| Accent (bottom line) | `#58a6ff` at 30% opacity |
| Tag pill bg | `#1c2128` with `#30363d` border |

**Rules:**
- Monospace font everywhere (monospace in SVG)
- Monochromatic only - greys and one blue accent
- No neon, no gradients, no bright colors, no emoji
- Abstract/geometric illustrations, not code screenshots
- 8px radius on panels, 4px on pills, 6-10px on windows

## Tag-to-Illustration Mapping

Choose illustration based on the post's primary tags:

| Tags | Illustration | Visual Elements |
|------|-------------|-----------------|
| `backend`, `web` | **Browser window** | Window chrome with dots, URL bar, content lines, code block area, card grid |
| `real-time` | **Connected clients** | Central PubSub node with pulse rings, 4 browser windows connected via dashed lines, live dots on connections |
| `data-visualization` | **Network graph** | Nodes and edges, central hub, leaf nodes at different levels, labeled connections |
| `machine-learning` | **Neural network** | Input/hidden/output layers as circles, connection lines between layers, "input"/"output" labels |
| `applications` | **Desktop window** | Native window frame with title bar, editor area with text lines, sidebar panel with suggestion items |
| `data` | **Feed/stream** | RSS-style icon (arcs + dot), feed entry cards flowing from source, dashed connecting lines |
| `backend` (rate limiting) | **Funnel/gate** | Many dots on left (requests), funnel/gate in center with "429", few dots passing through on right, clock |
| `backend` (statistics) | **Bar chart** | Y/X axes, bars of varying height, dashed grid lines, counter badge |
| _fallback_ | **Typographic card** | Large title, tag pills, abstract geometric shapes |

## SVG Layout Template

```
┌──────────────────────────────────────────┐
│                                          │
│     [Topic illustration]                 │
│     (fills entire 1200x630 canvas)       │
│                                          │
│                                          │
│                                          │
│  ════════════════════ accent (y=626)     │
└──────────────────────────────────────────┘
```

The illustration fills the full image. Only the accent line at the bottom is added. **Do NOT include title text or tag pills** — those are rendered in the HTML card below the image.

## Generation Process

```bash
# 1. Write SVG to priv/static/images/posts/{slug}.svg
# 2. Convert: rsvg-convert {slug}.svg -o {slug}.png -w 1200 -h 630
# 3. Delete the SVG (keep only PNG)
```

### Accent Line

- Full-width rect at y=626, height=4, fill=#58a6ff, opacity=0.3

## Illustration Guidelines

When drawing SVG illustrations:
- Use **geometric shapes** (circles, rects, lines) - no complex paths
- Layer opacity for depth (0.3-0.8 range)
- Dashed lines (`stroke-dasharray="6,4"`) for connections/data flow
- Small circles (r=3-6) as live indicator dots
- Window chrome: rounded rect + 3 dots at top-left + title bar
- Minimal detail - suggest the concept, don't overload
- Center the illustration horizontally

## When to Regenerate

- New post created
- Post title changed
- Post tags changed
- Topic significantly shifted

## Dependencies

- `rsvg-convert` (from librsvg via homebrew)
- ImageMagick 7 (`magick`) available as backup
