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

Every blog post requires a card image. Images are **pure illustration** — absolutely NO text of any kind. No titles, no tags, no labels, no annotations, no numbers, no axis labels. The illustration must communicate the concept purely through shapes and visual metaphor. Title, tags, and metadata are shown in the HTML card below the image.

**Model guidance**: When invoked as part of a larger workflow, use `opus` for SVG generation — this is creative/implementation work.

## Required: Generate Image for Every New Post

When a new blog post is created, you MUST:
1. Read the post title, tags, and content to understand the topic
2. Choose an illustration style based on tags (see mapping below)
3. Generate an SVG with **only geometric shapes and the accent line** — absolutely NO `<text>` elements
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

| Element | Color | Usage |
|---------|-------|-------|
| Background | `#0d1117` | Canvas background |
| Container frame | `#5a6670` | Border rect around illustration area |
| Illustration elements | `#5a6670`, `#4a5460`, `#6e7681` | Lines, boxes, shapes, borders |
| Panel/card fills | `#161b22` | Box backgrounds inside illustration |
| Tertiary fills | `#1c2128` | Subtle background layers |
| Accent line ONLY | `#58a6ff` at 30% opacity | Bottom accent line only — do NOT use elsewhere |
| Border details | `#30363d` | Subtle inner borders/dividers |

**Critical Rules:**
- **NO TEXT**: Do NOT use any `<text>` elements in the SVG. No titles, labels, annotations, numbers, axis labels, or any other text. The illustration must communicate purely through shapes.
- **Illustration colors**: Use ONLY muted grays (#5a6670, #4a5460, #6e7681) — never use bright #58a6ff for illustration elements
- **Accent blue**: #58a6ff is ONLY for the bottom accent line (4px rect at y=626), nowhere else
- **Canvas margins**: 100px left/right, 60-80px top/bottom — don't extend illustration to edges
- **Container frame**: Add a subtle `<rect>` border (x=100, y=60, width=1000, height=510, stroke=#5a6670, stroke-width=2) to define illustration bounds
- **No neon, gradients, or bright colors** — stick to the muted palette
- **Abstract/geometric** — not code screenshots or realistic images
- 8px radius on panels, 6-10px on windows

## Tag-to-Illustration Mapping

Choose illustration based on the post's primary tags:

| Tags | Illustration | Visual Elements |
|------|-------------|-----------------|
| `backend`, `web` | **Browser window** | Window chrome with dots, URL bar shape, content line shapes, code block area, card grid |
| `real-time` | **Connected clients** | Central node with pulse rings, 4 browser windows connected via dashed lines, live dots on connections |
| `data-visualization` | **Network graph** | Nodes and edges, central hub, leaf nodes at different levels, connecting lines |
| `machine-learning` | **Neural network** | Input/hidden/output layers as circles, connection lines between layers |
| `applications` | **Desktop window** | Native window frame with title bar dots, editor area with line shapes, sidebar panel with item shapes |
| `data` | **Feed/stream** | RSS-style icon (arcs + dot), feed entry card shapes flowing from source, dashed connecting lines |
| `backend` (rate limiting) | **Funnel/gate** | Many dots on left (requests), funnel/gate shape in center, few dots passing through on right, clock shape |
| `backend` (statistics) | **Bar chart** | Axes as lines, bars of varying height, dashed grid lines, badge shape |
| _fallback_ | **Abstract geometric** | Abstract geometric shapes suggesting the topic — circles, rects, lines, polygons arranged to evoke the concept |

## SVG Layout Template

Canvas: **1200x630px**

```
┌─────────────────────────────────────────────────────┐  y=0
│                                                     │
│  ┌───────────────────────────────────────────────┐  y=60  ← container frame starts
│  │                                               │
│  │   [Illustration fills here, roughly          │
│  │    800-950px wide × 450px tall]              │
│  │                                               │
│  │   Use muted grays (#5a6670, #4a5460)        │
│  │   NO bright colors, NO title text            │
│  │                                               │
│  └───────────────────────────────────────────────┘  y=570 ← container frame ends
│                                                     │
│  ════════════════════════════════════════════════  y=626 ← accent line (4px, #58a6ff 30%)
└─────────────────────────────────────────────────────┘  y=630
0   100px margin            1100    1200px
```

**Canvas breakdown:**
- Margins: 100px left/right, 60px top, 4px bottom for accent line
- Usable illustration area: x ∈ [100, 1100], y ∈ [60, 570]
- Container frame: `<rect x="100" y="60" width="1000" height="510" stroke="#5a6670" stroke-width="2" fill="none" rx="16"/>`
- Accent line: `<rect x="0" y="626" width="1200" height="4" fill="#58a6ff" opacity="0.3"/>`

**Important**: Illustration should fill most of the container (not cramped in a corner). Distribute content vertically and horizontally to use the space effectively.

## Generation Process

```bash
# 1. Write SVG to priv/static/images/posts/{slug}.svg
# 2. Convert: rsvg-convert {slug}.svg -o {slug}.png -w 1200 -h 630
# 3. Delete the SVG (keep only PNG)
```

### Accent Line

- Full-width rect at y=626, height=4, fill=#58a6ff, opacity=0.3

## Illustration Guidelines

**Shape and composition:**
- Use **geometric shapes only** (circles, rects, lines, polygons) — no complex bezier curves
- **NO `<text>` elements at all** — convey meaning purely through visual shapes and layout
- Layer opacity for depth (0.3-0.8 range for secondary elements)
- Dashed lines (`stroke-dasharray="6,4"`) for connections, flows, or optional elements
- Small circles (r=3-6) as live indicator dots or connection points
- Window chrome: rounded rect + 3 dots at top-left + title bar separator
- Use small rounded rects as "text line" placeholders instead of actual text
- Minimal detail — suggest the concept, don't overload with decoration

**Canvas usage:**
- Center illustration horizontally in usable area (x: 100-1100)
- Distribute vertically to fill y: 60-570 space (use most of it, don't leave large gaps)
- For multi-element layouts (diagrams, grids), space elements evenly
- Minimum 40px between major elements for visual breathing room

**Color discipline:**
- Borders/outlines: #5a6670 or #30363d
- Boxes/containers: #161b22 for fills, #5a6670 for stroke
- Details/depth: #4a5460 or #1c2128 with reduced opacity
- **Never use #58a6ff in the illustration** — only in the accent line

## Common Mistakes to Avoid

1. **Including text**: NEVER use `<text>` elements. No titles, labels, numbers, annotations, or any written content. Use shapes to suggest meaning instead.
2. **Using bright colors for illustration**: #58a6ff should ONLY be the accent line at the bottom, never for diagram elements. Use muted grays instead.
3. **Cramped illustrations**: Leaving large blank areas at bottom. Distribute content vertically to fill y: 60-570.
4. **No container frame**: The subtle rect border (x=100, y=60, width=1000, height=510) is essential for defining visual boundaries.
5. **Extending to edges**: Illustration should have ~100px margins on sides. Don't extend elements to x=0 or x=1200.
6. **Missing accent line**: Every image must end with the blue accent line at y=626. Easy to forget.
7. **Complex paths instead of shapes**: Stick to circles, rects, lines, polygons. Avoid bezier curves and complex SVG paths.

## When to Regenerate

- New post created
- Post title changed
- Post tags changed
- Topic significantly shifted

## Dependencies

- `rsvg-convert` (from librsvg via homebrew)
- ImageMagick 7 (`magick`) available as backup
