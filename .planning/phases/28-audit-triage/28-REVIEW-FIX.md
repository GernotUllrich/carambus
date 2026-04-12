---
phase: 28-audit-triage
fixed_at: 2026-04-12T00:00:00Z
review_path: .planning/phases/28-audit-triage/28-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 28: Code Review Fix Report

**Fixed at:** 2026-04-12
**Source review:** .planning/phases/28-audit-triage/28-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: `--nav-only` summary reports full-scan counts, not nav-scoped counts

**Files modified:** `bin/check-docs-translations.rb`
**Commit:** 2f58664c
**Applied fix:** Moved `print_findings` and `print_summary` calls inside the `if @nav_only` / `else` branches. In the nav-only branch, `print_summary` is now called with `nav_bases.size` for both the de and en counts, reflecting the actual nav-scoped set rather than the full filesystem scan.

---

### WR-02: Unquoted `tmp_dir` interpolated directly into shell string (command injection vector)

**Files modified:** `lib/tasks/mkdocs.rake`
**Commit:** c9a36ffa
**Applied fix:** Replaced `system("mkdocs build --strict --site-dir #{tmp_dir} 2>&1")` with the multi-argument form `system("mkdocs", "build", "--strict", "--site-dir", tmp_dir)`, which bypasses shell interpretation entirely and removes the `2>&1` redirect (stdout/stderr both go to terminal as intended).

---

### WR-03: `print_summary` in `check-docs-coderef.rb` re-globs the filesystem

**Files modified:** `bin/check-docs-coderef.rb`
**Commit:** f9297b14
**Applied fix:** Refactored `scan_docs` to perform the glob and archive filter once at the top of the method, returning `doc_files.size` at the end (and on early return when stale set is empty). In `run`, the return value is captured as `scanned_count` and passed to `print_summary`. The `print_summary` signature was updated to `print_summary(stale_count, scanned_count)` and the duplicate glob + archive-filter block inside it was removed.

---

### WR-04: Duplicate `reference/api.md` entry in `mkdocs.yml` nav

**Files modified:** `mkdocs.yml`
**Commit:** 0af0250b
**Applied fix:** Removed the `- API Reference: reference/api.md` line from the `Developers` nav section (former line 167). The canonical entry `- API: reference/api.md` under the `Reference` section is retained. This eliminates the duplicate that caused MkDocs strict-mode warnings.

---

_Fixed: 2026-04-12_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
