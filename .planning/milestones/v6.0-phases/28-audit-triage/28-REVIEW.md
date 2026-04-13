---
phase: 28-audit-triage
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - bin/check-docs-translations.rb
  - bin/check-docs-coderef.rb
  - lib/tasks/mkdocs.rake
  - mkdocs.yml
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 28: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Four source files were reviewed: two Ruby CLI scripts (`bin/check-docs-translations.rb`, `bin/check-docs-coderef.rb`), one Rake task file (`lib/tasks/mkdocs.rake`), and one YAML configuration file (`mkdocs.yml`).

The scripts are well-structured with clear purpose and consistent style. The primary concerns are:

- A logic bug in `check-docs-translations.rb` where the `--nav-only` mode produces a misleading summary (counts from the full filesystem scan, not from nav-scoped results).
- A shell command injection vector in `mkdocs.rake` where `tmp_dir` is interpolated directly into a shell string passed to `system()`.
- A summary double-glob in `check-docs-coderef.rb` that re-walks the filesystem after `scan_docs` already has the result.
- A duplicate `reference/api.md` entry in `mkdocs.yml` nav causing MkDocs to warn or silently drop one entry.

---

## Warnings

### WR-01: `--nav-only` summary reports full-scan counts, not nav-scoped counts

**File:** `bin/check-docs-translations.rb:50`
**Issue:** `print_summary(de_bases.size, en_bases.size)` is always called with the counts from `collect_base_sets`, which performs a full filesystem glob regardless of whether `--nav-only` is active. When `--nav-only` is used, `de_bases` and `en_bases` are never narrowed to the nav subset, so the "Total .de.md files" and "Total .en.md files" lines in the summary reflect the entire docs tree rather than just the nav-referenced files. The gap counts in `@missing_en` / `@missing_de` are correctly scoped (via `check_nav_pairs`), but the totals are misleading and the summary narrative is inconsistent.

**Fix:** Pass the nav-scoped count when in nav-only mode, or track counts inside `check_nav_pairs`:

```ruby
def run
  # ...
  de_bases, en_bases = collect_base_sets

  if @nav_only
    nav_bases = collect_nav_bases
    check_nav_pairs(nav_bases)
    print_findings
    print_summary(nav_bases.size, nav_bases.size)   # nav size for both; gaps already computed
  else
    @missing_en = (de_bases - en_bases).sort
    @missing_de = (en_bases - de_bases).sort
    print_findings
    print_summary(de_bases.size, en_bases.size)
  end
end
```

Alternatively, rename the summary columns to "Files checked" and derive the count from `@missing_en` / `@missing_de`.

---

### WR-02: Unquoted `tmp_dir` interpolated directly into shell string (command injection vector)

**File:** `lib/tasks/mkdocs.rake:86`
**Issue:** `system("mkdocs build --strict --site-dir #{tmp_dir} 2>&1")` interpolates `tmp_dir` directly into a shell command string. Although `tmp_dir` is constructed from `"/tmp/mkdocs-check-#{Process.pid}"` — which is safe in practice — this pattern is fragile: if `tmp_dir` ever changes to incorporate user-controlled input (e.g., a branch name or environment variable), it becomes a command injection point. Using `system()` with a single string invokes the shell, so spaces or shell metacharacters in the interpolated value would be interpreted.

**Fix:** Use the multi-argument form of `system` to bypass shell interpretation entirely:

```ruby
success = system("mkdocs", "build", "--strict", "--site-dir", tmp_dir)
```

Note: the `2>&1` redirect is not needed with the array form if stdout/stderr both go to the terminal, which is the desired behavior here.

---

### WR-03: `print_summary` in `check-docs-coderef.rb` re-globs the filesystem

**File:** `bin/check-docs-coderef.rb:163-165`
**Issue:** `print_summary` calls `Dir.glob(DOCS_ROOT.join("**", "*.md").to_s)` and re-applies the archive filter to compute the "Files scanned" count. The exact same glob was already performed inside `scan_docs`. This duplicates filesystem work and — more importantly — creates a consistency hazard: if a file is created or deleted between the two calls (unlikely in practice, but structurally unsound), the count will not match the actual scan. The `exclude_archives` filter is also duplicated verbatim, violating DRY.

**Fix:** Track the scanned file count once in `scan_docs` and pass it to `print_summary`:

```ruby
def scan_docs(stale_identifiers)
  return 0 if stale_identifiers.empty?

  doc_files = Dir.glob(DOCS_ROOT.join("**", "*.md").to_s)
  doc_files = doc_files.reject { |f| archive_path?(f) } if @exclude_archives
  # ... existing scan logic ...
  doc_files.size
end

# In run:
scanned_count = scan_docs(stale_only)
# ...
print_summary(stale_only.size, scanned_count)

def print_summary(stale_count, scanned_count)
  puts "Files scanned:              #{scanned_count}"
  # ...
end
```

---

### WR-04: Duplicate `reference/api.md` entry in `mkdocs.yml` nav

**File:** `mkdocs.yml:167` and `mkdocs.yml:191`
**Issue:** `reference/api.md` appears twice in the nav: once under `Developers` as `API Reference` (line 167) and again under `Reference` as `API` (line 191). MkDocs will warn about duplicate pages in strict mode (which `mkdocs:check` runs with `--strict`), causing the CI check task to fail. Even without strict mode, one entry will be silently ignored depending on the MkDocs version.

**Fix:** Decide which section should own this page. If it belongs in `Reference`, remove the entry from `Developers` and add a cross-reference in prose. If it must appear in both, use MkDocs `navigation.indexes` or a redirect, but duplicate nav entries are not supported natively:

```yaml
# In Developers section, replace the duplicate with a prose link or remove it:
# Remove line 167:  - API Reference: reference/api.md
```

---

## Info

### IN-01: `BLUE` constant defined but never used in both scripts

**File:** `bin/check-docs-translations.rb:19`, `bin/check-docs-coderef.rb:31`
**Issue:** The `BLUE = "\e[34m"` constant is defined in both checker classes but never referenced in any output statement. This is dead code.

**Fix:** Remove the unused constant from both files, or use it for informational output lines (e.g., the "Mode:" or "App root:" header lines) if color differentiation is desired.

---

### IN-02: `exit 1` inside Rake tasks bypasses normal Rake error flow

**File:** `lib/tasks/mkdocs.rake:13`, `lib/tasks/mkdocs.rake:19`, `lib/tasks/mkdocs.rake:33`, `lib/tasks/mkdocs.rake:81`, `lib/tasks/mkdocs.rake:93`
**Issue:** `exit 1` called inside a Rake task terminates the entire Ruby process immediately. This prevents Rake from running any subsequent tasks in a chain (`rake db:migrate docs:build` would abort mid-run), suppresses Rake's standard error reporting, and bypasses `ensure` blocks or `at_exit` hooks in the broader process. The conventional Rake approach is to raise an exception.

**Fix:** Replace `exit 1` with `raise "Error message"` or `abort "Error message"` (which prints to stderr and sets exit code 1, but still allows Ruby cleanup):

```ruby
abort "Error: mkdocs is not installed. Please install it first:\n  pip install mkdocs-material mkdocs-static-i18n pymdown-extensions"
```

Or for Rake-native style:
```ruby
fail "mkdocs build failed with warnings or errors."
```

---

### IN-03: `collect_nav_bases` uses `YAML.load_file` without safe-load on an untrusted path

**File:** `bin/check-docs-translations.rb:88`
**Issue:** `YAML.load_file(MKDOCS_YML.to_s)` uses the default YAML loader. In Ruby < 3.1 this allows arbitrary object deserialization (Psych unsafe load). In Ruby 3.1+ the default was changed to safe load. Since the project targets Ruby 3.2.1 (per CLAUDE.md), this is not a current vulnerability, but the call pattern should be explicit for clarity and forward compatibility.

**Fix:** Use the explicit safe form:

```ruby
config = YAML.safe_load_file(MKDOCS_YML.to_s)
```

Or equivalently:
```ruby
config = YAML.load_file(MKDOCS_YML.to_s, permitted_classes: [])
```

---

### IN-04: `polyfill.io` CDN reference in `mkdocs.yml`

**File:** `mkdocs.yml:236`
**Issue:** `https://polyfill.io/v3/polyfill.min.js?features=es6` references the polyfill.io CDN, which was acquired by a Chinese conglomerate in 2024 and began injecting malicious scripts before being taken down. The domain is now operated by Cloudflare under `cdnjs.cloudflare.com` or can be self-hosted. This is a documentation site (not the main app), but it still loads the script in every visitor's browser.

**Fix:** Replace with the Cloudflare-hosted safe alternative or remove if ES6 polyfilling is not needed for the docs audience (modern browsers on a developer docs site):

```yaml
extra_javascript:
  - javascripts/mathjax.js
  - https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js
  # polyfill.io removed — unsafe CDN; not needed for modern browsers
```

---

_Reviewed: 2026-04-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
