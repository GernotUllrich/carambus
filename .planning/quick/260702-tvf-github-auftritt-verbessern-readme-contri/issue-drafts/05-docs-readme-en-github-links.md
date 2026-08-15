# docs: fix raw-GitHub-broken links in docs/README.en.md

**Labels:** good first issue, help wanted

## Summary

`docs/README.en.md` links to plain `.md` filenames (e.g. `decision-makers/index.md`, `administrators/installation-overview.md`). Those files do not exist under that name in the repo — the actual files carry language suffixes (`index.en.md` / `index.de.md`). The links only resolve in the mkdocs-built site (https://GernotUllrich.github.io/carambus), where the mkdocs i18n plugin maps them at build time. Anyone browsing the docs directory on GitHub itself hits 404s.

## Why it matters

GitHub is the first place new users and contributors browse the docs. Broken links on the English docs index make the documentation look unmaintained, even though the content exists one suffix away.

## Where

- `docs/README.en.md` — all relative `[...](*.md)` links (≈20, e.g. lines 9, 13, 17, 21, 25, 91–106)
- Target files: e.g. `docs/decision-makers/index.en.md`, `docs/administrators/installation-overview.en.md` (verify each target's actual filename)
- Same pattern likely exists in `docs/README.de.md` (check and fix in the same PR if so)
- `mkdocs.yml` — the i18n plugin config explains why the suffix-less names work on the built site

## Suggested approach

1. Decide the strategy with a quick maintainer check-in on this issue. Two options:
   - (a) Point relative links at the real files (`index.md` → `index.en.md`) — works on GitHub; verify the mkdocs i18n plugin still resolves them in the built site.
   - (b) Point links at the built docs site (absolute `https://GernotUllrich.github.io/carambus/...` URLs) — always works, at the cost of leaving the GitHub file view.
2. Apply the chosen strategy consistently across `docs/README.en.md` (and `.de.md` if affected).
3. Verify: click every link in the GitHub file preview; if strategy (a), also run `bin/rails mkdocs:build` (or `mkdocs build`) and spot-check the built site links.

## Definition of done

- Every link in `docs/README.en.md` resolves when viewed on github.com (no 404s).
- If relative links were kept: `mkdocs build` succeeds and the built docs-site links still work.
- The same check applied to `docs/README.de.md`.
