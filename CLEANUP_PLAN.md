# Blog Cleanup Plan

## ✅ Phase 1 - Critical Fixes (Complete)

- [x] Fixed runtime.exs duplicate configuration blocks
- [x] Added .env file loading (manual parsing in runtime.exs)
- [x] Removed gettext (not needed for a blog)
- [x] Updated dev.exs live reload patterns for Phoenix 1.8
- [x] Fixed mix.exs (removed unnecessary compiler, added listeners)
- [x] Fixed esbuild CSS loader configuration
- [x] Styles loading correctly

## ✅ Phase 2 - Phoenix 1.8 Migration (Complete)

- [x] Converted to component-based layouts (`BlogWeb.Layouts`)
- [x] Moved templates to `lib/blog_web/components/layouts/`
- [x] Removed old `templates/` directory
- [x] Fixed deprecated `live_flash/2` → `Phoenix.Flash.get/2`
- [x] Fixed deprecated `live_redirect/2` → `<.link navigate={...}>`
- [x] Fixed deprecated `live_title_tag/2` → `<.live_title>`
- [x] Fixed deprecated `csrf_token_value/0` → `Plug.CSRFProtection.get_csrf_token/0`
- [x] Replaced `Routes` helpers with verified routes (`~p` sigil) everywhere
- [x] Removed `import Phoenix.LiveView.Helpers` (deprecated)
- [x] Removed `use PhoenixHTMLHelpers` and `phoenix_html_helpers` dep
- [x] Removed unused `channel` definition from BlogWeb
- [x] Updated dependencies (earmark 1.4.48, vega_lite 0.1.11)

## ✅ Phase 3 - Code Quality (Complete)

### Posts Module
- [x] Replaced Agent with ETS-based caching
- [x] Fixed unsafe `Regex.run/2` calls (can return nil) in `title/1` and `description/1`
- [x] Replaced `Earmark.as_html!/1` with safe `Earmark.as_html/1`
- [x] Error tuples no longer cached in ETS (only success values)
- [x] Added `with` statements for chained operations in `fetch_titles/1` and `fetch_post/2`
- [x] Added `@spec` typespecs to all public and private functions
- [x] Replaced `IO.warn/1` and `IO.inspect/2` with `Logger`
- [x] Added `child_spec/1` for supervisor compatibility

### Feed Module
- [x] Added error handling for failed post fetches (`with` + nil rejection)
- [x] Extracted `parse_date/1` with nil safety for regex
- [x] Skips broken entries instead of crashing

### LiveViews
- [x] `PostLive.Show` handles `{:error, _}` from `get_post` and `parse`
- [x] Centralized flash component in `BlogWeb.Layouts.flash/1`
- [x] Removed duplicate flash implementations from Index and Show
- [x] Fixed ReadTag component: single root element, nil-safe update

### Cleanup
- [x] Deleted dead modules: `PageView`, `LayoutView`, `Components.Layout`
- [x] Deleted unused HTML templates
- [x] Fixed `.gitignore` to exclude `.env` (contains secrets)
- [x] Fixed ReadTag Monitor nil handling for `get_state/1`
- [x] Fixed Statistics telemetry handler leak (`detach` in `terminate`)
- [x] Cleaned up `BlogWeb` moduledoc

---

## Current Status

**Compilation: 0 warnings, 0 errors**

---

## 📋 Remaining (Future Work)

### Testing
- [ ] Configure test.exs
- [ ] Add Blog.Posts unit tests (title/1, description/1, parse/1)
- [ ] Add integration tests with Bypass for GitHub API mocking
- [ ] Add LiveView tests for Index and Show

### Performance
- [ ] Add telemetry metrics for GitHub API calls
- [ ] Cache TTL support (entries never expire currently)
- [ ] Monitor cache hit rates

### Features
- [ ] Add search functionality
- [ ] Add tags/categories
- [ ] RSS feed improvements
- [ ] Dark mode

### Developer Experience
- [ ] Add CI/CD pipeline
- [ ] Add code coverage reporting
