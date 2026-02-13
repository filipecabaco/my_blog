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

## ✅ Phase 4 - Testing & Infrastructure (Complete)

- [x] Configured test.exs (logger level, test github token, plug_init_mode)
- [x] Created test_helper.exs and ConnCase support module
- [x] Added Blog.Posts unit tests (title/1, description/1, parse/1) - 9 tests
- [x] Added Blog.Feed tests (build/0 XML output, metadata) - 2 tests
- [x] Added LiveView tests for Index and Show - 3 tests
- [x] Switched from Cowboy to Bandit (~> 1.6) with adapter config

## ✅ Phase 5 - Improvements (Complete)

- [x] Posts module: converted to proper GenServer with 5-minute cache TTL
- [x] Posts module: pluggable HTTP via `:req_options` config for testability
- [x] Added integration tests with Req.Test for GitHub API (8 tests)
- [x] Statistics: removed eager `list_post` call from init (lazy counter creation)
- [x] ReadTag Monitor: reduced polling from 100ms to 5 seconds
- [x] Fixed HEEx formatting (`<%= if %>` → `{if}`)
- [x] Added GitHub Actions CI pipeline (compile, format, test)

## Current Status

**Compilation: 0 warnings, 0 errors**
**Formatting: clean**
**Tests: 26 passing, 0 failures**

---

## 📋 Remaining (Future Work)

### Features
- [ ] Add search functionality
- [ ] Add tags/categories
- [ ] Dark mode
