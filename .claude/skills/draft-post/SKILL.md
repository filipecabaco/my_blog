---
name: draft-post
description: >
  Draft a new blog post based on broad engineering themes extracted from the author's
  recent work. Researches filipecabaco's activity to find hands-on experience, identifies
  universal engineering patterns, gets user approval, writes the post, generates a card
  image, and opens a draft PR. Focus on general principles, not specific projects.
user_invocable: true
---

# Draft Post

End-to-end workflow: research contributions, extract broad engineering themes, pick a topic, write a draft post, generate a card image, and open a draft PR.

## Step 1: Research Author Contributions

**Model**: Use `haiku` — this is a research/context-gathering step.

Fetch recent public activity for `filipecabaco` using `gh` CLI:

```bash
# Recent push/PR/issue events
gh api "/users/filipecabaco/events/public" --paginate -q '.[] | select(.type == "PushEvent" or .type == "PullRequestEvent" or .type == "IssuesEvent") | {type, repo: .repo.name, created_at: .created_at}'

# Recently starred repos
gh api "/users/filipecabaco/starred?per_page=10" -q '.[].full_name'

# Recent PRs authored
gh search prs --author=filipecabaco --sort=created --limit=20
```

**Extract broad engineering themes and patterns**, not specific technologies:
- What engineering problems were being solved? (testing, performance, reliability, scalability, debugging, architecture, tooling)
- What general techniques or approaches were used?
- What universal lessons or patterns emerge?

**Example**: If work involved improving test coverage in a real-time system, the theme is "testing strategies for async systems" not "testing Supabase Realtime."

## Step 2: Research Trending Engineering Topics

**Model**: Use `haiku` — this is a research/context-gathering step.

Use WebSearch to check what broader engineering topics are trending:

- Search Hacker News for discussions on testing, debugging, performance, architecture, developer experience
- Search engineering blogs and communities for current pain points and solutions
- Look for timeless engineering topics that remain relevant

**Focus on universal themes**: testing strategies, debugging techniques, performance optimization, CI/CD practices, developer tooling, architecture patterns, code quality, etc.

## Step 3: Select Topic (Requires User Approval)

**Model**: Use `sonnet` — this is a summarizing/decision-making step.

Pick the topic that best satisfies all four criteria:
1. **Broad applicability**: Universal engineering theme, not tied to specific projects/technologies
2. **Authentic experience**: Author has direct hands-on experience with the underlying problem
3. **Relevant**: Currently discussed or timeless engineering concern
4. **Not already covered**: Check existing posts to avoid duplicates

Check existing posts to avoid duplicates:

```bash
gh api "repos/filipecabaco/my_blog/contents/posts" -q '.[].name'
```

**IMPORTANT**: Present the chosen topic and a brief outline to the user and wait for approval before proceeding. Do NOT write the full draft until the user confirms.

## Step 4: Write the Draft Post

**Model**: Use `opus` — this is a writing/implementation step.

### Required Assets Per Post

Every blog post requires **two files** for the homepage card to render correctly:

| File | Path | Purpose |
|------|------|---------|
| Post markdown | `posts/YYYY-MM-DD_slug_title.md` | The post content |
| Card image | `priv/static/images/posts/YYYY-MM-DD_slug_title.png` | Homepage card + OG meta image |

The card image is used in three places:
1. **Homepage card**: `<img src="/images/posts/{slug}.png">` in `index.ex`
2. **OG meta tag**: `<meta property="og:image">` in `root.html.heex`
3. **Atom feed**: `<enclosure>` in `feed.ex`

If the PNG is missing, the homepage card will show a broken image.

### Create Branch

```bash
git checkout -b draft/YYYY-MM-DD_slug_title
```

### Write the Markdown File

Save to `posts/YYYY-MM-DD_slug_title.md` following blog conventions:

```markdown
# Post Title
tags: tag1, tag2, tag3

First paragraph is the description (used in feeds and metadata).

Rest of content...
```

**Format rules:**
- Line 1: `# Title`
- Line 2: `tags: comma, separated` (metadata only — stripped before rendering by `parse/1`, never shown in the post body)
- Line 3: empty
- Line 4+: description paragraph, then full content

**Title format:**
- Short and punchy (3-7 words)
- NO colons or subtitles
- Conversational, sometimes playful
- Examples: "Making my blog", "When Rate limit strikes!", "Statistics on the cheap", "Drawing Graphs With a Twist"
- Bad: "Testing Strategies: A Deep Dive" (has colon, too formal)
- Good: "Testing Without the Pain" or "Making Tests Reliable"

**Allowed tags:** `backend`, `web`, `real-time`, `data-visualization`, `machine-learning`, `applications`, `data`, `frontend`

**Writing style:** Follow the voice and structure conventions from `my-blog-conventions` skill:
- Conversational first-person tone with genuine excitement
- Technical depth with code examples
- Progressive disclosure: simple to complex
- Personal opening hook, honest caveats section, bullet-point conclusion
- 3-7 emoji per post, strategically placed, never in code blocks

**Content must be authentic** -- grounded in real contributions and experience, not generic.

**Code examples must be real** -- all code examples in posts must come from real source code found during Step 1 research (PRs, commits, repos). Adapt examples slightly to better illustrate the point, but they should remain authentic and traceable to the source. Never use randomly generated or fabricated code samples.

**Post length**: Posts can be either **standard** or **short form**:
- **Standard** (~1000-2000 words, ~7-14 min read): Deep dives with multiple code examples, caveats section, and progression from simple to complex.
- **Short form** (~300-600 words, ~2-4 min read): Focused on a single insight, trick, or lesson learned. One or two code examples max. Get to the point fast. Good for quick wins, TILs, or opinionated takes.

When proposing a topic, suggest the appropriate length. Not every topic needs a deep dive — shorter posts are great for sharing a single useful pattern or gotcha.

The blog calculates reading time at ~150 WPM (accounting for code blocks in technical posts) and displays it on both the homepage cards and individual post pages.

**Framing guideline**: Frame the post around the general engineering principle, not the specific project:
- Good: "Strategies for Testing Async Systems" (universal)
- Bad: "How We Test Supabase Realtime" (project-specific)
- Good: "Debugging Production Database Migrations" (universal)
- Bad: "How I Fixed Migration Issues at Work" (job-specific)

Use specific work as examples/evidence, but the topic should apply broadly to any engineer facing similar problems.

### Generate Card Image

Follow the `image-generation-strategy` skill:
1. Create an SVG illustration based on the post's tags (illustration only, no title/tags text)
2. Use GitHub dark theme colors (background `#0d1117`, panels `#161b22`, accent `#58a6ff`)
3. Canvas size 1200x630, monochromatic, geometric/abstract style
4. Convert to PNG:

```bash
rsvg-convert priv/static/images/posts/SLUG.svg -o priv/static/images/posts/SLUG.png -w 1200 -h 630
rm priv/static/images/posts/SLUG.svg
```

## Step 5: Push and Open Draft PR

**Model**: Use `haiku` — this is a mechanical git operations step.

Commit, push the branch, and open a draft PR with a preview link:

```bash
git add posts/YYYY-MM-DD_slug_title.md priv/static/images/posts/SLUG.png
git commit -m "Draft post: Post Title"
git push -u origin draft/YYYY-MM-DD_slug_title
gh pr create --draft --title "Post Title" --body "$(cat <<'EOF'
## Summary

- Topic: [broad engineering theme, not project-specific]
- Why relevant: [timeless concern or current discussion in engineering community]
- Informed by: [general experience that backs this up, without naming specific projects]

## Preview

[View on filipecabaco.com](https://filipecabaco.com/?pr=PR_NUMBER)

## Status

Draft -- needs human review before publishing.

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

After opening the PR, note the PR number from the output and update the preview link if needed.

**Preview URL**: The blog supports a `?pr=` query parameter that resolves the PR number to its head branch via the GitHub API, then fetches posts from that branch. Card images are proxied through `/pr/:pr/images/*path` so they render correctly even though they're not on the local filesystem.

- Homepage with PR posts: `https://filipecabaco.com/?pr=PR_NUMBER`
- Individual post: `https://filipecabaco.com/post/SLUG?pr=PR_NUMBER`

Return the PR URL to the user.
