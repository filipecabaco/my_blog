---
name: image-generation-strategy
description: Automated image generation for blog posts using strategy pattern based on tags (backend, web, real-time, frontend, data-visualization, machine-learning, applications, data) and content analysis. Selects appropriate approach (code screenshots, charts, diagrams, terminal output, UI screenshots, typographic cards) and handles caching, metadata overrides, and homepage integration.
license: MIT
metadata:
  author: filipecabaco
  version: "1.0.0"
---

# Image Generation Strategy

Flexible image generation for blog posts that selects the appropriate visual approach based on post content and tags.

## Strategy Selection

**Tag-based mapping:**

| Tags | Strategy | Output |
|------|----------|--------|
| `backend`, `web`, `real-time` | code_screenshot | Syntax-highlighted Elixir/Phoenix code |
| `data-visualization` | chart_preview | Vega-lite/graph rendering |
| `machine-learning` | architecture_diagram | Model flow visualization |
| `applications` | ui_screenshot | Application UI mockup |
| `frontend` | component_visual | Browser/component preview |
| `data` | data_flow_diagram | Pipeline visualization |
| _fallback_ | typographic_card | Title + Tags + Description |

## Post Metadata Overrides

Add to post frontmatter:

```markdown
tags: backend, web
image_strategy: code_screenshot
image_hint: lines 45-60
image_source: /images/custom-preview.png
image_caption: Alt text for accessibility
```

**Fields:**
- `image_strategy`: Override automatic selection
- `image_hint`: Line range, block index, or selection detail
- `image_source`: Manual image path (bypass generation)
- `image_caption`: Accessibility alt text

## Implementation Structure

```elixir
defmodule Blog.Images do
  def generate_for_post(post_content, post_title) do
    strategy = select_strategy(post_content)
    generate(strategy, post_content, post_title)
  end

  defp select_strategy(%{tags: tags, metadata: metadata}) do
    # 1. Check explicit override in metadata
    # 2. Apply tag-based rules
    # 3. Fallback to typographic
  end

  # Strategy implementations
  defp generate(:code_screenshot, post, title)
  defp generate(:chart_preview, post, title)
  defp generate(:architecture_diagram, post, title)
  defp generate(:terminal_output, post, title)
  defp generate(:ui_screenshot, post, title)
  defp generate(:typographic_card, post, title)
end
```

## Strategy Details

### Code Screenshots
**For:** backend, web, real-time tags
**Extract:** First meaningful code block from markdown
**Tools:** Carbon API, Puppeteer/Playwright
**Style:** Dark theme, monospace (JetBrains Mono/Fira Code), tag pills, title overlay

### Chart Preview
**For:** data-visualization tag
**Extract:** Vega-lite spec from post
**Tools:** Vix (ImageMagick bindings)
**Style:** Clean background, chart focal point, title + description

### Architecture/Flow Diagrams
**For:** machine-learning, data, backend (no code)
**Extract:** Mermaid blocks from markdown
**Tools:** Mermaid CLI
**Style:** Clean rendering, monospace labels, tag indicators

### Terminal Output
**For:** backend, applications (CLI)
**Extract:** Terminal examples from post
**Tools:** Asciinema, SVG terminal generators
**Style:** Dark bg, green/white text, monospace, prompt indicators

### UI Screenshots
**For:** applications, frontend
**Source:** Manual screenshots, Puppeteer captures, design tool exports
**Style:** Browser chrome/app window, shadow effects, tag overlay

### Typographic Cards (Fallback)
**For:** Any post without specific visual
**Tools:** Vix or Mogrify
**Content:** Title (monospace), tag pills, first paragraph
**Style:** Minimalist, high contrast, 1200x630 aspect ratio

## Caching Strategy

**Storage:**
- Path: `priv/static/images/generated/`
- Naming: `{post_slug}.png` (e.g., `2022-07-16_making_my_blog.png`)
- Cache: ETS alongside post content

**Regeneration triggers:**
- Post content hash changes
- Manual cache invalidation
- Missing image file

**Performance:**
- Generate on first request (dev)
- Pre-generate all (production deploys)

## Homepage Integration

```heex
<div class="post-card">
  <img src={@post.image_url} alt={@post.image_caption} class="post-image" />
  <div class="post-content">
    <h2>{@post.title}</h2>
    <p class="post-description">{@post.description}</p>
    <div class="post-tags">
      <%= for tag <- @post.tags do %>
        <span class="tag-pill">{tag}</span>
      <% end %>
    </div>
  </div>
</div>
```

**Design:** Modern minimal, monospace typography, card grid, hover effects, lazy loading

## Dependencies

**Elixir:**
- `vix` or `mogrify` - Image manipulation
- `req` - HTTP client for external APIs
- `jason` - JSON parsing

**External (optional):**
- `@mermaid-js/mermaid-cli` - Diagram rendering (npm)
- `puppeteer` - Browser automation (npm)

**System:**
- ImageMagick (for Vix/Mogrify)
- Node.js (if using mermaid-cli/puppeteer)

## Future Enhancements

- A/B test different styles
- Social media specific sizes (Twitter, LinkedIn)
- Dark/light mode variants
- Animated previews (GIF/video)
- AI-generated images (Stable Diffusion, DALL-E)

## References

- [Open Graph Best Practices](https://og-playground.vercel.app/)
- [Carbon API](https://github.com/carbon-app/carbon)
- [Vix Documentation](https://hexdocs.pm/vix/)
- [Mermaid CLI](https://github.com/mermaid-js/mermaid-cli)
