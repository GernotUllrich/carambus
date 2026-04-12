# Pitfalls Research

**Domain:** Documentation quality audit — mkdocs-based docs for Rails app after 5 milestones of significant refactoring
**Researched:** 2026-04-12
**Confidence:** HIGH (primary sources: direct inspection of docs/, mkdocs.yml, BROKEN_LINKS_REPORT.txt, PROJECT.md, and confirmed stale references in tournament-architecture-overview.en.md, umb-scraping-methods.md, streaming-architecture.de.md)

---

## Critical Pitfalls

### Pitfall 1: Auditing Only Visible Text, Missing Embedded Stale Class and File References

**What goes wrong:**
A doc audit that reads for prose accuracy misses class names, file paths, and method references embedded in code blocks, diagrams, and bullet lists. In this codebase, `docs/developers/tournament-architecture-overview.en.md` references `lib/tournament_monitor_support.rb` and `TournamentMonitorSupport` directly — a file deleted in v2.1. `docs/developers/umb-scraping-methods.md` explicitly praises `UmbScraperV2` as "Moderne Code-Struktur" — a class deleted in v5.0. Both were found via grep, not by reading. A manual read-through would likely miss both.

**Why it happens:**
Code references in docs are treated as decorative context, not as facts that break. The audit instinct is to check whether concepts are accurate; it does not automatically check whether every referenced identifier still exists in the codebase.

**How to avoid:**
Build a grep inventory before reading any doc. Extract all class names, file paths, and method calls from docs (pattern: `ClassName`, `path/to/file.rb`, `#method_name`) and verify each against the actual file tree. Run this as a first phase: audit = grep list first, prose review second. The `BROKEN_LINKS_REPORT.txt` already exists and covers hyperlinks — replicate that discipline for code identifiers.

**Warning signs:**
- Docs reference classes that return zero results in `grep -rn "ClassName" app/`.
- Docs mention files with paths that don't exist: `ls app/services/umb_scraper_v2.rb` returns no such file.
- Docs describe a class as having N lines when the current file has M lines (e.g., "TournamentMonitorSupport — the operational workhorse" when the file is gone).

**Phase to address:**
Audit phase (first phase of v6.0) — build the identifier grep list before writing a single update.

---

### Pitfall 2: Updating One Language File Without Its Pair

**What goes wrong:**
The mkdocs-i18n plugin pairs `foo.de.md` and `foo.en.md`. If a stale reference is fixed in the `.de.md` file but not the `.en.md` file, the published English site still contains the wrong information. Worse: the plugin's `fallback_to_default: true` setting means that if only one language is built, the fallback silently serves the other language's content — so a broken English file is invisible during German-only testing.

In this repo, asymmetry already exists: `developers/streaming-dev-setup.de.md` has no `.en.md` counterpart; `developers/tournament-architecture-overview.en.md` has no `.de.md` counterpart; `developers/test-implementation-summary.de.md` has no `.en.md` counterpart. Every update must explicitly decide: fix both, or document why one language intentionally lacks the page.

**Why it happens:**
Writers fix what they find broken and move on. The connection between `foo.de.md` and `foo.en.md` is a filename convention, not enforced by the editor or CI. There is no tooling that warns "you edited the German file — did you update the English one too?"

**How to avoid:**
Treat every doc as a pair. Before marking any file updated, open both language versions simultaneously. For each change: apply to both files. For asymmetric files (one language exists, the other doesn't): make an explicit decision — create the missing file, or move the page to a language-neutral `.md` file that the i18n plugin serves to both. Never leave the pair in different states silently.

**Warning signs:**
- Running `diff docs/foo.de.md docs/foo.en.md` shows structural divergence beyond translation differences.
- A feature is documented in German sections but returns no results searching the English site.
- `ls docs/developers/ | grep "\.de\.md$" | sed 's/\.de\.md$//' | sort` vs the same for `.en.md` shows different counts.

**Phase to address:**
Every update phase — pair-checking is a per-file discipline, not a separate phase. Enforce it at the task level: "for every file changed, its pair is changed or the asymmetry is documented."

---

### Pitfall 3: Removing Stale Content Without Auditing Inbound Links

**What goes wrong:**
Deleting or heavily rewriting a doc page that other docs link to creates broken links. The `BROKEN_LINKS_REPORT.txt` already documents 74 broken links before the audit work begins. Removing a page like `developers/umb-scraping-methods.md` (which covers the deleted UmbScraperV2) without checking what links to it would increase the broken link count. The mkdocs nav also explicitly lists this page — removing the file without updating `mkdocs.yml` causes a build error.

**Why it happens:**
The natural instinct is to delete the wrong page and move on. Checking all inbound references requires a reverse-link lookup that grep can provide but that is easy to skip under time pressure.

**How to avoid:**
Before deleting or renaming any doc page: (1) grep the entire `docs/` tree for the target filename, (2) grep for the anchor heading text (used in cross-doc links), (3) check `mkdocs.yml` nav for the page entry. For each inbound reference: update or remove it before deleting the target. After any deletion: run the link checker script that produced `BROKEN_LINKS_REPORT.txt` and verify the broken link count did not increase.

**Warning signs:**
- Broken link count in the report increases after a deletion.
- `mkdocs build` fails with "page not found" during build.
- A page deletion causes 5+ broken links in other files that seemed unrelated.

**Phase to address:**
The removal/update phase of the audit. Every deletion must be preceded by the inbound-link grep.

---

### Pitfall 4: Over-Documenting Extracted Service Internals

**What goes wrong:**
After extracting 37 services across 7 namespaces, the temptation is to document every service class — its constructor, private methods, and implementation details. This produces documentation that is immediately stale (implementation changes every refactoring cycle) and that conflates API documentation with architecture documentation. For internal services like `Umb::DateHelpers` or `PartyMonitor::TablePopulator`, implementation docs add maintenance overhead with zero user value.

**Why it happens:**
"We added this service, we should document it" is a reasonable instinct that doesn't distinguish between what callers need to know and what the service itself does internally. The result is docs that describe `private` methods that no external caller ever touches.

**How to avoid:**
Apply a strict two-tier rule: (1) **Architecture docs** describe the service's role in the system, its public interface, and the data contract it satisfies. (2) **Implementation notes** (if they belong in docs at all) go in code comments, not published docs. For the 37 extracted services: document the namespace boundary and the responsibility allocation (e.g., "TableMonitor delegates score calculation to ScoreEngine, game setup to GameSetup") — not each service's method list. The reader needs to understand the architecture, not re-read the source.

**Warning signs:**
- A doc page for a service begins with "This class has the following private methods..."
- Documentation of a service method that is already fully described by its name (`calculate_standings`).
- A doc page changes every time the service is refactored internally, even when the external behavior is unchanged.

**Phase to address:**
New documentation phase (documenting v1.0–v5.0 additions). Write the architecture overview first; only add method-level detail where the method's behavior is non-obvious and not captured in tests.

---

### Pitfall 5: Treating Archived Docs as Harmless

**What goes wrong:**
The `docs/archive/` and `docs/internal/archive/` directories contain documents that explicitly reference deleted code (`UmbScraperV2`, `lib/tournament_monitor_support.rb`) and outdated architectures. These directories are excluded from the broken-link checker report (`Mode: Excluding archives, internal, and obsolete documents`) — but they are still rendered and served in the mkdocs site unless explicitly excluded in `mkdocs.yml`. A developer searching the docs site will find archived pages in search results, read a code example with `UmbScraperV2.new`, and be misled.

**Why it happens:**
Archive directories are created to preserve history, but mkdocs serves everything under `docs/` unless explicitly excluded. The assumption that "archive = not read" does not hold when site search indexes all pages.

**How to avoid:**
Verify that `mkdocs.yml` excludes archive directories from the nav AND from search indexing. The `exclude_docs` option (mkdocs-material) or `search.exclude: true` front matter on archive index pages prevents stale content from surfacing in search. Audit which archive pages are indexed by checking `site/search/search_index.json` after a build. For archive pages that describe deleted code, add a prominent "Archived — this feature no longer exists" notice at the top rather than updating the content.

**Warning signs:**
- Site search for "UmbScraperV2" returns results from archive pages.
- A developer follows a search result and finds instructions for code that doesn't compile.
- `mkdocs.yml` has no `exclude_docs` or `not_in_nav` directive for archive directories.

**Phase to address:**
Audit phase — verify archive exclusion before starting the update work. Adding notices to archive pages is a task, not a separate phase.

---

### Pitfall 6: Updating Prose Without Verifying the Corresponding Code Path Still Works

**What goes wrong:**
A documentation update replaces "see `UmbScraperV2`" with "see `Umb::ArchiveScraper`" — and the new content accurately describes what the service does — but the rake task or job that invokes it was also changed, and the doc doesn't reflect the new invocation path. The reader follows the updated doc, runs the wrong command, and gets an error. This happened with `ScrapeUmbArchiveJob`: the public method signature changed, but docs that showed how to invoke the job were not updated.

**Why it happens:**
Docs are updated at the class level ("here is what this service does") without verifying the full call chain: job → service → method arguments. Class-level updates are faster and feel complete.

**How to avoid:**
For every service mentioned in updated docs, trace the full call chain from the entry point (rake task, job, controller action, reflex) to the service and verify the method signatures match. When a doc includes a code example with a method call, run that exact call in a Rails console or test to confirm it works. Docs that include code examples are integration tests for documentation accuracy.

**Warning signs:**
- A doc shows `SomeJob.perform_now(discipline: '3-Cushion')` but the job's `perform` signature takes different arguments.
- A rake task invocation in docs produces `NoMethodError` when run verbatim.
- Code examples in docs reference private methods or constants that are no longer exported.

**Phase to address:**
Update phase — every code example in updated docs must be verified as runnable.

---

### Pitfall 7: New Services Have No Documentation Coverage at All

**What goes wrong:**
The opposite of over-documenting is under-documenting: 37 services were extracted across 7 namespaces (v1.0–v5.0), but the existing docs still describe the god-object models as the units of responsibility. A developer reading `developers/tournament-architecture-overview.en.md` sees `TournamentMonitorSupport` (deleted) described as "the operational workhorse" with no mention of `PlayerGroupDistributor`, `RankingResolver`, `ResultProcessor`, or `TablePopulator` that replaced it. The video cross-referencing system (`Video::TournamentMatcher`, `Video::MetadataExtractor`, `SoopliveBilliardsClient`) and the `Umb::*` namespace have zero documentation coverage outside internal notes.

**Why it happens:**
Documentation was written when the god-object models existed. After extraction, the code changed but the doc update was deferred — a standard pattern in delivery-focused milestones. The result is a growing divergence where new developers get an increasingly wrong map of the codebase.

**How to avoid:**
The audit phase must produce a gap inventory: for each namespace introduced in v1.0–v5.0, determine whether any public-facing or developer-facing doc covers it. Services that are internal implementation details of a model do not need separate pages — but they should appear in an updated architecture overview that shows the current responsibility allocation. Create one "current architecture" page per major domain (tournament monitoring, scraping, video cross-referencing) that reflects post-refactoring structure, and link from old pages to the new ones rather than attempting an in-place update of outdated architecture docs.

**Warning signs:**
- Grepping docs for "ScoreEngine", "Umb::", "Video::TournamentMatcher" returns no results in non-archive, non-internal docs.
- The developers section describes class responsibilities in terms of the pre-refactoring god objects.
- A new developer's onboarding question ("where does scoring logic live?") cannot be answered from the docs.

**Phase to address:**
New documentation phase — write the current-state architecture overview pages before updating old pages. Update old pages to reference the new overview.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Update only the `.de.md` file and defer `.en.md` | Faster per-file, easier to review | English docs diverge; fallback behavior silently serves stale content | Never — do both at the same time or document the asymmetry explicitly |
| Leave archive docs without "archived" notices | No extra work | Site search surfaces stale code examples to new developers | Never for pages that contain runnable code examples pointing to deleted code |
| Document only the class, not the call chain | Accurate at the class level | Reader cannot use the information without additional investigation | Acceptable only for internal implementation classes with no external callers |
| Describe new services in a changelog rather than updating architecture docs | Quick, preserves history | Architecture overview grows stale; changelogs are not reference material | Acceptable as a supplement, never as a replacement for architecture doc updates |
| Rely on `BROKEN_LINKS_REPORT.txt` as the complete audit | Link audit already exists | File-path links are checked but code-identifier references are not | Use as a starting point, not a completion criterion |
| Skip verifying code examples | Saves time per doc | Code examples that don't work destroy reader trust faster than outdated prose | Never for docs that target developers |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| mkdocs-i18n plugin (`suffix` structure) | Assuming `foo.md` is served to all locales | Files without `.de.md`/`.en.md` suffix are served as-is; the plugin does not auto-translate or duplicate them — they appear only in the locale that matches or as a fallback |
| mkdocs nav with i18n | Listing a `.md` key in nav without suffix — mkdocs resolves this to the default locale file | Nav entries should use the base name without suffix; the plugin resolves to the correct language file automatically |
| `fallback_to_default: true` | Assuming missing-language pages are invisible | The fallback serves the default locale (German) content to English-locale visitors — stale German content becomes the English page silently |
| mkdocs `exclude_docs` | Assuming `docs/archive/` is not indexed because it's not in nav | mkdocs serves and indexes all files under `docs_dir` unless explicitly excluded via `exclude_docs` or `not_in_nav` |
| Link checker script | Assuming it checks code identifier references | The existing checker only checks markdown hyperlinks and image paths — it does not verify that class names, method names, or file paths in code blocks exist in the codebase |
| mkdocs build errors | Fixing broken nav entries by removing the nav entry rather than the broken file | Removing a nav entry leaves an orphaned file that is still indexed by search — remove both the nav entry and the file (or redirect) |

---

## "Looks Done But Isn't" Checklist

- [ ] **Stale identifier audit complete:** `grep -rn "UmbScraperV2\|tournament_monitor_support\|lib/tournament_monitor_support" docs/` returns only archive-flagged files — not active docs.
- [ ] **Pair coverage verified:** `diff <(ls docs/developers/*.de.md | sed 's/\.de\.md//') <(ls docs/developers/*.en.md | sed 's/\.en\.md//')` shows no unexpected asymmetry.
- [ ] **mkdocs.yml nav is consistent with file tree:** Every file listed in nav exists; every file edited has a corresponding nav entry (or is intentionally not-in-nav).
- [ ] **Broken link count did not increase:** Running the link checker after all updates produces <= 74 broken links (the pre-audit baseline), ideally fewer.
- [ ] **Archive pages have stale-content notices:** Every archived page that references deleted classes has a visible "Archived" header.
- [ ] **New architecture overview exists:** At least one updated page per refactored domain (tournament monitoring, scraping, video) reflects post-v5.0 structure.
- [ ] **Code examples are runnable:** Every developer-facing code example in updated docs was verified against the current codebase (class exists, method signature matches, invocation path works).
- [ ] **mkdocs build passes:** `mkdocs build --strict` (or without strict mode if warnings are acceptable) completes without errors after all updates.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Stale class reference found post-publication | LOW | Grep for all occurrences, update both language files, rebuild site |
| Broken link count increased after update | LOW | Run link checker, find new broken links, fix or remove the source reference |
| Language files diverged (one updated, one not) | MEDIUM | Diff both files, identify structural gaps, apply missing changes to the lagging file |
| Archive content surfacing in search | LOW | Add `search: exclude: true` front matter to archive index or add `exclude_docs` to mkdocs.yml |
| Nav entry removed but file still served | LOW | Add file to `not_in_nav` or delete the file; rebuild and verify search_index.json |
| New architecture doc contradicts old page | MEDIUM | Add a deprecation notice to old page linking to new one; do not delete old page until all inbound links are updated |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Stale class/file identifiers in docs | Audit phase — grep inventory first | `grep -rn "UmbScraperV2\|tournament_monitor_support" docs/` returns zero active-doc results |
| Language pair divergence | Every update task — pair discipline | Diff of de/en file shows only translation differences, not structural differences |
| Broken links from deletions | Removal/update phase — inbound-link grep before every deletion | Broken link count <= baseline after all changes |
| Over-documenting service internals | New documentation phase — architecture overview first | No published page describes private methods or implementation internals of extracted services |
| Archive content indexed in search | Audit phase — verify mkdocs exclude configuration | `site/search/search_index.json` contains no entries from `docs/archive/` or `docs/internal/` |
| Code examples not runnable | Update phase — verify each example against codebase | Zero "NoMethodError" or "uninitialized constant" when running examples from updated docs |
| New services undocumented | New documentation phase — gap inventory | Grepping published docs for `Umb::`, `Video::TournamentMatcher`, `ScoreEngine` returns at least one architecture-level reference per namespace |

---

## Sources

- `docs/BROKEN_LINKS_REPORT.txt` — 74 confirmed broken links as pre-audit baseline; link checker scope and exclusions documented
- `docs/developers/tournament-architecture-overview.en.md` — confirmed reference to deleted `lib/tournament_monitor_support.rb` and `TournamentMonitorSupport`
- `docs/developers/umb-scraping-methods.md` — confirmed reference to deleted `UmbScraperV2` class as active documentation (not archived)
- `mkdocs.yml` — i18n plugin configuration (`fallback_to_default: true`, `docs_structure: suffix`), full nav inventory, no `exclude_docs` directive for archive directories
- `.planning/PROJECT.md` — complete list of 37 extracted services, deleted files (`UmbScraperV2`, `lib/tournament_monitor_support.rb`), and milestone history
- `grep -rn "UmbScraperV2" docs/` — live execution confirmed stale references in `developers/umb-scraping-methods.md` (active nav page) and multiple archive pages
- `grep -rn "tournament_monitor_support" docs/` — live execution confirmed stale references in `developers/tournament-architecture-overview.en.md` and `developers/clubcloud-upload.de.md` / `.en.md`
- File tree comparison of `.de.md` vs `.en.md` in `docs/developers/` — confirmed asymmetric pairs: `streaming-dev-setup.de.md` (no en), `tournament-architecture-overview.en.md` (no de), `test-implementation-summary.de.md` (no en), `testing-strategy.de.md` (no en)

---
*Pitfalls research for: documentation quality audit after 5 milestones of codebase refactoring*
*Researched: 2026-04-12*
