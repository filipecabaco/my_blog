---
name: my-blog-conventions
description: >
  Conventions for filipecabaco/my_blog, an Elixir/Phoenix blog that fetches
  markdown posts from GitHub API. Use when creating or editing blog posts,
  modifying post parsing/rendering logic, working with tags, updating the
  Atom feed, or changing post-related CSS. Also use when debugging post
  caching, GitHub API integration, or tag extraction.
---

## Architecture

Elixir/Phoenix app. Posts are markdown files in `posts/`, fetched at runtime
via GitHub API (`api.github.com/repos/filipecabaco/my_blog/contents/posts`).
Cached in ETS (`Blog.Posts` GenServer) with 30-minute TTL. Parsed with Earmark.

## Post File Format

Filename: `YYYY-MM-DD_slug_with_underscores.md`

```markdown
# Post Title
tags: tag1, tag2, tag3

First paragraph is the description (used in feeds and metadata).

Rest of content...
```

- Line 1: `# Title` -- extracted via `~r/#(.*)/`
- Line 2: `tags: comma, separated` -- extracted via `~r/^tags:\s*(.+)$/m`
- First paragraph after title+tags block: description -- extracted via `~r/# .*\n(?:tags:.*\n)?\n(.*)/`

## Tag Conventions

Tags must be **broad categories**, not specific technologies:

| Instead of | Use |
|---|---|
| `elixir` | `backend` |
| `phoenix` | `web` |
| `liveview` | `real-time` |
| `javascript` | `frontend` |
| `vega-lite` | `data-visualization` |
| `xml` | `data` |
| `tauri` | `applications` |

`machine-learning` is already general enough.

Tags render as `.tag-pill` styled spans on both index and show pages, and
become `<category>` elements in the Atom feed.

## Key Files

| File | Purpose |
|---|---|
| `lib/blog/posts.ex` | GenServer: fetch, cache (ETS + TTL), parse (title/tags/description) |
| `lib/blog_web/live/post_live/index.ex` | Post listing with tag pills |
| `lib/blog_web/live/post_live/show.ex` | Individual post view with tag pills, read tags, statistics |
| `lib/blog/feed.ex` | Atom feed via xmerl (tags become `<category>` elements) |
| `assets/css/app.css` | Tag pill styling (`.tag-pill` class) |
| `config/runtime.exs` | GitHub token config from env |
| `posts/*.md` | Markdown source files |

## Secrets

GitHub API token loaded from `GITHUB_API_TOKEN` or `GITHUB_TOKEN` env vars
(see `config/runtime.exs`). `.env` is gitignored. Never commit tokens.

## Design System

### Visual Style: GitHub Dark

Clean, minimal, monochromatic. Inspired by GitHub's dark mode.

**Theme Tokens (CSS variables in `assets/css/app.css`):**

| Token | Value | Usage |
|---|---|---|
| `--bg-primary` | `#0d1117` | Page background |
| `--bg-secondary` | `#161b22` | Cards, panels |
| `--bg-tertiary` | `#1c2128` | Code blocks, tag pills, inputs |
| `--bg-overlay` | `rgba(13,17,23,0.8)` | Sticky header backdrop |
| `--text-primary` | `#e6edf3` | Headings, body text |
| `--text-secondary` | `#8b949e` | Descriptions, labels, nav |
| `--text-muted` | `#6e7681` | Subtle UI elements |
| `--border-color` | `#30363d` | Card borders, dividers |
| `--border-subtle` | `#21262d` | Subtle separators |
| `--link-color` | `#58a6ff` | Links, accents |

**Typography:**
- Monospace everywhere: `--font-mono` (SF Mono, Monaco, Inconsolata, Fira Code)
- Sans-serif available: `--font-sans` (system stack) - not currently used
- Tag pills are lowercase with subtle letter-spacing

**Spacing Scale:**
- `--space-xs` (0.25rem) through `--space-3xl` (4rem)

**Radius:**
- `--radius-sm` (4px), `--radius-md` (6px), `--radius-lg` (8px)

**Interactive Elements:**
- Cards lift on hover (`translateY(-2px)`) with border brightening
- All transitions use `--transition` (0.15s ease)
- No neon, no glow, no gradients - just subtle border/color shifts

**Layout:**
- Default container: 800px max-width
- Homepage/header: 1200px max-width
- Dashboard: 900px max-width
- Grid cards: 340px min-width auto-fill
- Boids particle animation in background (JS, `pointer-events: none`)

**Syntax Highlighting:**
- highlight.js with `github-dark` theme
- Languages: Elixir, JavaScript, Bash, SQL, JSON, HTML
- Code blocks: `--bg-tertiary` background, `--border-color` border, 8px radius

**CSS Architecture:**
- `phoenix.css`: Base element reset using theme variables (no classes)
- `app.css`: All theme tokens + component styles
- All colors/spacing reference CSS variables - never hardcoded in components

### Image Generation Guidelines

Images must match the GitHub dark monochromatic aesthetic:
- **Backgrounds**: Always `#0d1117` or `#161b22` - never white or light
- **Text**: Monospace in `#e6edf3` (primary) or `#8b949e` (secondary)
- **Accents**: Only `#58a6ff` (blue links) - no neon, no gradients, no bright colors
- **Borders**: `#30363d` - thin, subtle, 8px radius for containers
- **Code blocks**: Use `github-dark` syntax theme, `#1c2128` background
- **Terminal theme**: `#e6edf3` text on `#0d1117` background, monospace
- **Style**: Clean, minimal, monochromatic - no glowing effects, no animations in images
- **Cards/Panels**: `#161b22` background with `#30363d` border
- **Aspect ratio**: 1200x630 for OG images

## Writing Style & Structure

Posts follow a playful technical style that balances honest expertise with approachability.

### Post Structure Template

```markdown
# [Title - descriptive or playful]
tags: broad, categories, here

[Opening Hook - 1-2 sentences]
Personal admission, surprising problem, or meta-commentary

[Context paragraph]
Why this matters, what triggered it

## [Section Headers]
Progressive technical content with:
- Conversational explanations
- Code blocks with context before and results after
- Screenshots/GIFs showing progression
- Celebration of wins

## Caveats
Honest limitations, "good enough" solutions

## Conclusion
- Bullet points of key learnings
- Optional: One-line closing reflection
```

### Voice Guidelines

**Consistent casual tone:**
- Use "Let's" instead of "We will"
- Show genuine excitement: "And here's the cool part!"
- Acknowledge complexity: "This gets weird, but stick with me"
- Celebrate wins: "And it works!" over "This concludes the implementation"
- Meta-commentary: Acknowledge reinventing wheels, taking shortcuts, overengineering

**Existing strong patterns to maintain:**
- Personal opening hooks ("For years I've wanted...", "Well that was quick...")
- Progressive disclosure: simple → complex
- Honest limitations sections
- Bullet-point conclusions
- Conversational asides in parentheses

### Personality Elements

**Emoji usage:**
- 3-7 per post, strategically placed
- Never in code blocks or technical explanations
- Already established: 😅, 🧐, ❤️

**Section headers:**
- Can be playful ("The Terminator", "Let the laziness begin!") or straightforward
- Maintain variety based on content tone

**Industry humor:**
- NIH syndrome, YOLO deployments, wheel reinvention
- "As every person thinking about building their blog, we need to always rewrite and reinvent the wheel 😅"
- "And why no database? Because..."

**Honest limitations:**
- Celebrate "good enough": "This is a really simplistic approach"
- Admit shortcuts and trade-offs
- No pretense of perfection

### Technical Balance

**Never sacrifice accuracy for personality:**
- Code quality comes first
- Explain jargon even when joking about it
- Progressive disclosure: Simple explanation → Code → Deep dive → Summary
- Visual breaks: Screenshot or code block every 3-4 paragraphs

**Proven content patterns:**
- Context before code: "And why X? Because..."
- Results after code: Show output, explain impact
- Screenshots showing progression (build steps, UI changes)
- Clear caveats section before conclusion
