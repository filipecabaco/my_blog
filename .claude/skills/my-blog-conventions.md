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
