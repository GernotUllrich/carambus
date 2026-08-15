---
phase: 260507-jfe
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/models/tournament.rb
  - app/models/region.rb
  - test/models/tournament_test.rb
autonomous: true
requirements:
  - JFE-01
must_haves:
  truths:
    - "When a tournament is scraped (via Region#scrape_tournaments_data or Region#scrape_upcoming_tournaments) with a title that encodes a player class, the resulting Tournament record has Tournament#player_class set to the canonical token from Discipline::PLAYER_CLASS_ORDER."
    - "When a title encodes no recognizable player class, Tournament#player_class is nil (NOT empty string, NOT a guess) and the scraper does not crash."
    - "Tournament.parse_player_class_from_title is idempotent and pure (same input → same output, no DB touches)."
    - "No existing Tournament record (id < 50_000_000 i.e. global, or any locally-created record) is mutated by this change. Behavior preservation: only newly-scraped tournaments going forward populate the field."
  artifacts:
    - path: "app/models/tournament.rb"
      provides: "Tournament.parse_player_class_from_title(title) class method"
      contains: "def self.parse_player_class_from_title"
    - path: "app/models/region.rb"
      provides: "Two scrape sites pass parsed player_class to Tournament.create"
      contains: "Tournament.parse_player_class_from_title"
    - path: "test/models/tournament_test.rb"
      provides: "Characterization tests for parse_player_class_from_title covering each token in PLAYER_CLASS_ORDER + nil-on-no-match + nil-on-blank-title."
      contains: "parse_player_class_from_title"
  key_links:
    - from: "app/models/region.rb"
      to: "Tournament.parse_player_class_from_title"
      via: "Direct class method call inside Tournament.create(...) arg hash, alongside the existing is_handicap derivation"
      pattern: "Tournament\\.parse_player_class_from_title"
    - from: "Tournament.parse_player_class_from_title"
      to: "Discipline::PLAYER_CLASS_ORDER"
      via: "Constant reference for canonical token whitelist"
      pattern: "Discipline::PLAYER_CLASS_ORDER"
---

<objective>
Extract `player_class` (e.g. "5", "III") from a tournament title at scrape time and persist it on Tournament#player_class. This unblocks Discipline#parameter_ranges (Phase 39) and Tournament::TableReservationService for German-federation tournaments scraped via Region#scrape_tournaments_data and Region#scrape_upcoming_tournaments — currently both call sites pass nothing for player_class, leaving the field nil even when the title plainly says "Klasse 5".

**Purpose:** Closes a data-gap that forces operators to set player_class manually after each scrape. Title text is the only authoritative source we have at scrape time (CC HTML doesn't expose a class field separately). Cheap, atomic, behavior-preserving.

**Output:**
- `Tournament.parse_player_class_from_title(title)` class method (~15 LOC + comments)
- Two 1-line additions in `Region#scrape_tournaments_data` and `Region#scrape_upcoming_tournaments` mirroring the existing `is_handicap` derivation
- Minitest unit tests covering the canonical PLAYER_CLASS_ORDER tokens, ambiguous titles, and edge cases (nil/blank title, no class in title, multiple matches → first wins).
</objective>

<execution_context>
@/Users/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/workflows/execute-plan.md
@/Users/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@.agents/skills/extend-before-build/SKILL.md
@.agents/skills/scenario-management/SKILL.md
@app/models/tournament.rb
@app/models/region.rb
@app/models/discipline.rb

<interfaces>
<!-- Key contracts the executor needs. Extracted from the codebase. -->
<!-- Use these directly — no further codebase exploration needed for the parser surface. -->

From app/models/discipline.rb:55 — the canonical taxonomy:

```ruby
# Karambol klein: 7..1 (lower number = better class).
# Karambol groß: I..III (lower roman = better class).
# In live DB no single discipline mixes both sets; parser need not disambiguate.
PLAYER_CLASS_ORDER = %w[7 6 5 4 3 2 1 I II III].freeze
```

From app/models/tournament.rb (schema annotation, line 32):

```ruby
#  player_class                   :string
```

Already exists as a plain Tournament column. NO migration needed.

From app/models/region.rb:559-569 — the existing extend-before-build seam (scrape_tournaments_data path):

```ruby
tournament = Tournament.where(season:, organizer: self, title: name).first
unless tournament.present?
  # Erkenne Vorgabeturniere am Titel
  is_handicap = name =~ /Vorgabe/i
  tournament = Tournament.create(
    season:,
    organizer: self,
    title: name,
    region_id: self.id,
    handicap_tournier: is_handicap
  )
end
```

From app/models/region.rb:941-953 — the second seam (scrape_upcoming_tournaments path):

```ruby
tournament = Tournament.where(season: current_season, organizer: self, title: name).first
unless tournament.present?
  is_handicap = name =~ /Vorgabe/i
  tournament = Tournament.create!(
    season: current_season,
    organizer: self,
    title: name,
    date: date,
    handicap_tournier: is_handicap
  )
end
```

**Both sites already derive `is_handicap` from `name`. We add `player_class` derivation in the same shape.**
</interfaces>
</context>

<open_questions>
The executor should resolve these by reading code; do NOT block on user input.

1. **Exact regex coverage of titles in production.** The plan covers the two well-known forms: numeric (1..7) and roman (I..III), each preceded by a "Klasse"/"Kl."/"KK"/"BK"/"KKK" marker word OR appearing as a standalone token at the end of the title. If the executor finds production titles encoding the class differently (e.g. "Damen", "Schüler", "U17" — these are NOT in `PLAYER_CLASS_ORDER`), they MUST be left as `nil` (return nil, do not coerce). This is correct behavior for now: those tournaments use a different classification system and should stay manual until JFE-02. Document any such patterns observed in the SUMMARY.md as "deferred" so we know whether a follow-up phase is needed.

2. **`PLAYER_CLASS_ORDER` is a global record (Discipline class constant).** It lives in `app/models/discipline.rb:55` — the constant itself isn't a record, so LocalProtector doesn't apply. The parser may reference `Discipline::PLAYER_CLASS_ORDER` directly without LocalProtector concerns.

3. **Backfill scope: explicitly out of scope.** This plan ONLY populates `player_class` for newly-scraped tournaments. It does NOT touch existing rows. If the user later wants a backfill rake task for existing local tournaments (id >= MIN_ID), that's a separate quick task (would also need an explicit `unprotected = true` dance — out of scope here).

4. **InternationalTournament path (UMB scraper).** The UMB scraper creates `InternationalTournament` records with English titles like "UMB World Cup Antwerp". The German `PLAYER_CLASS_ORDER` taxonomy doesn't apply. The parser will return `nil` on those titles and that is correct — InternationalTournament inherits Tournament so the column exists, but it stays unused on that subclass. No special-casing needed.

5. **CuescoScraper / SoopliveScraper / KozoomScraper** are out of scope: Cuesco creates Games on existing tournaments (title was set upstream); Sooplive and Kozoom create `Video` records, not `Tournament`s. Verified by grep — none of them call `Tournament.create`.

6. **`RegionCc::TournamentSyncer` is also out of scope:** it only LOOKS UP existing Tournament records by title (`Tournament.where(title: tournament_cc.name, ...)`), doesn't create them.
</open_questions>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add Tournament.parse_player_class_from_title class method + Minitest unit tests</name>
  <files>
    app/models/tournament.rb
    test/models/tournament_test.rb
  </files>
  <behavior>
    Tests to write FIRST (RED), all in test/models/tournament_test.rb under a "::parse_player_class_from_title" group:

    - test "returns nil for nil title" — Tournament.parse_player_class_from_title(nil) == nil
    - test "returns nil for blank title" — Tournament.parse_player_class_from_title("") == nil and ("   ") == nil
    - test "extracts numeric class — 'Klasse 5'" — input "Bezirksmeisterschaft Freie Partie Klasse 5" → "5"
    - test "extracts numeric class — 'Kl. 4'" — input "Vorgabeturnier Einband Kl. 4 2024" → "4"
    - test "extracts numeric class — 'KK 7'" (Kreisklasse) — input "KK Dreiband KK 7 Saison 2024/25" → "7"
    - test "extracts roman class — 'Klasse III'" — input "Verbandspokal Klasse III" → "III"
    - test "extracts roman class — 'Kl. II'" — input "Karambol groß Kl. II Final" → "II"
    - test "extracts roman class — standalone trailing 'I'" — input "Stadtmeisterschaft Cadre 47/2 I" → "I" (must NOT match the 'i' in "Stadtmeisterschaft" — boundary regex)
    - test "no match returns nil" — input "Pokalturnier Damen 9-Ball" → nil (Damen, U17, etc. are deferred per Open Question 1)
    - test "no match returns nil — empty Latin numerals not in order" — input "Klasse IV" → nil (IV is NOT in PLAYER_CLASS_ORDER per discipline.rb:55; the constant only goes up to III)
    - test "first match wins on ambiguous title" — input "Klasse 3 / Klasse 4 Mixed" → "3" (deterministic; the parser walks PLAYER_CLASS_ORDER in declared order or matches the first occurrence — pick one and lock it in the test)
    - test "case insensitive marker" — input "klasse 5" (lowercase) → "5"
    - test "all PLAYER_CLASS_ORDER tokens reachable" — for each token in Discipline::PLAYER_CLASS_ORDER, build a synthetic title "Test Klasse #{token}" and assert the parser returns that token. This is the regression guard for any future addition to the constant.

    Run RED phase: `bin/rails test test/models/tournament_test.rb -n /parse_player_class_from_title/` — all 13 tests must FAIL with NoMethodError on Tournament (the method does not yet exist).
  </behavior>
  <action>
    GREEN phase — add to app/models/tournament.rb (suggested position: right after the existing class methods around line 173, before `def self.text_search_sql` to group with other class methods):

    ```ruby
    # Phase 39 / Quick 260507-jfe — Extracts the player_class token (e.g. "5", "III")
    # from a German-federation tournament title. Returns nil if the title is blank
    # or encodes no class from Discipline::PLAYER_CLASS_ORDER.
    #
    # Called from Region#scrape_tournaments_data and Region#scrape_upcoming_tournaments
    # at Tournament.create(...) time, alongside the existing is_handicap derivation.
    # Pure / idempotent — no DB touches. Safe to call from anywhere.
    #
    # Design: scan PLAYER_CLASS_ORDER in declared order (best-class-first walk
    # would risk picking "1" out of "Klasse 11" — declared order is "7 6 5 4 3 2 1 I II III",
    # which means we try "7" first, then "6", etc. To make matching deterministic,
    # we anchor each candidate with word boundaries AND require a recognized class
    # marker ("Klasse", "Kl.", "KK") immediately before — OR allow it as a trailing
    # standalone token. This avoids matching "1" inside "2024" or "I" inside "Bezirk".
    def self.parse_player_class_from_title(title)
      return nil if title.blank?

      Discipline::PLAYER_CLASS_ORDER.each do |token|
        # Marker forms: "Klasse 5", "Kl. III", "KK 7" — case-insensitive, dot/space tolerant
        return token if title =~ /\b(?:Klasse|Kl\.?|KK)\s+#{Regexp.escape(token)}\b/i
        # Standalone trailing form: title ends in "... 5" or "... III" (with word boundary).
        # Require leading whitespace so we don't grab "47/2" -> "2" or trailing year digits.
        return token if title =~ /(?:\s)#{Regexp.escape(token)}\s*\z/
      end
      nil
    end
    ```

    Per the extend-before-build SKILL: this is a single new class method on an existing model — NOT a new service, NOT a new module, NOT a parallel parser pipeline. The two consumer sites (Region) get the parsed value via direct `Tournament.parse_player_class_from_title(name)` at the call site (Task 2), exactly mirroring the existing `is_handicap = name =~ /Vorgabe/i` line.

    Run GREEN: `bin/rails test test/models/tournament_test.rb -n /parse_player_class_from_title/` — all 13 must pass.

    Run STANDARDRB: `bundle exec standardrb app/models/tournament.rb test/models/tournament_test.rb` — must be clean (no new offenses; existing offenses in tournament.rb are pre-existing and out of scope).

    Run BRAKEMAN no-pager scoped to the file: `bundle exec brakeman --no-pager --only-files app/models/tournament.rb 2>&1 | tail -20` — no new findings.

    **NOTE for executor:** if any of the 13 RED tests is genuinely under-specified (e.g. test 11 "first match wins on ambiguous title" depends on the iteration order of PLAYER_CLASS_ORDER — "3" comes before "4" in that array, so "Klasse 3" is found first by the loop and returned — verify and lock the assertion to "3"), that's a **plan-prescribed-test deviation** under CLAUDE.md Rule 1: fix the test to match the prescribed code (which IS the contract), document the deviation in SUMMARY.md.
  </action>
  <verify>
    <automated>bin/rails test test/models/tournament_test.rb -n /parse_player_class_from_title/ && bundle exec standardrb app/models/tournament.rb test/models/tournament_test.rb</automated>
  </verify>
  <done>
    - Tournament.parse_player_class_from_title exists, is `def self.`, takes one positional arg, returns String or nil.
    - All 13 unit tests GREEN.
    - standardrb clean on the two touched files (or only pre-existing offenses on lines NOT touched by this plan).
    - No DB queries issued by the parser (assert with `assert_no_queries do ... end` in at least one of the tests as a defensive guard).
  </done>
</task>

<task type="auto">
  <name>Task 2: Wire parser into Region's two scrape sites + add 2 integration-style tests</name>
  <files>
    app/models/region.rb
    test/models/tournament_test.rb
  </files>
  <action>
    Edit `app/models/region.rb` at the two known-and-grep-confirmed sites (use the Read tool first to verify line numbers haven't drifted):

    **Site 1 — `Region#scrape_tournaments_data`, around line 562-569 (find the exact location by grepping for `is_handicap = name =~ /Vorgabe/i` and the immediately following `Tournament.create(`):**

    Before:
    ```ruby
    is_handicap = name =~ /Vorgabe/i
    tournament = Tournament.create(
      season:,
      organizer: self,
      title: name,
      region_id: self.id,
      handicap_tournier: is_handicap
    )
    ```

    After (one new line + one new arg):
    ```ruby
    is_handicap = name =~ /Vorgabe/i
    parsed_player_class = Tournament.parse_player_class_from_title(name)
    tournament = Tournament.create(
      season:,
      organizer: self,
      title: name,
      region_id: self.id,
      handicap_tournier: is_handicap,
      player_class: parsed_player_class
    )
    ```

    **Site 2 — `Region#scrape_upcoming_tournaments`, around line 944-952 (find by grepping for the second `is_handicap = name =~ /Vorgabe/i`):**

    Before:
    ```ruby
    is_handicap = name =~ /Vorgabe/i
    tournament = Tournament.create!(
      season: current_season,
      organizer: self,
      title: name,
      date: date,
      handicap_tournier: is_handicap
    )
    ```

    After:
    ```ruby
    is_handicap = name =~ /Vorgabe/i
    parsed_player_class = Tournament.parse_player_class_from_title(name)
    tournament = Tournament.create!(
      season: current_season,
      organizer: self,
      title: name,
      date: date,
      handicap_tournier: is_handicap,
      player_class: parsed_player_class
    )
    ```

    **Why the same shape twice (DRY violation accepted):** these are two independent scrape paths in a 1000-line god-object model; refactoring both into a shared helper is out of scope per the project's "no architecture changes" constraint and the extend-before-build SKILL ("Refactoring for quality can come later"). A future RegionCc-or-similar refactor phase can collapse them.

    **Add 2 integration-style tests to test/models/tournament_test.rb** (under a "player_class scraped at create time" group). These test the END-TO-END contract — that `Tournament.create` with a `:player_class` keyword arg actually persists the value (proves the column wiring + frontmatter `files_modified` are correct):

    ```ruby
    test "Tournament.create accepts and persists player_class from parser" do
      title = "Bezirksmeisterschaft Einband Klasse 5 2024"
      season = seasons(:current)
      region = regions(:nbv) # adjust to whichever fixture exists; if none, build inline
      parsed = Tournament.parse_player_class_from_title(title)
      assert_equal "5", parsed

      t = Tournament.create!(
        season: season,
        organizer: region,
        title: title,
        player_class: parsed
      )
      assert_equal "5", t.reload.player_class
    end

    test "Tournament.create with nil parsed player_class persists nil (no coercion to empty string)" do
      title = "Pokalturnier Damen 9-Ball" # no class in title
      season = seasons(:current)
      region = regions(:nbv)
      parsed = Tournament.parse_player_class_from_title(title)
      assert_nil parsed

      t = Tournament.create!(
        season: season,
        organizer: region,
        title: title,
        player_class: parsed
      )
      assert_nil t.reload.player_class
    end
    ```

    **If `regions(:nbv)` or `seasons(:current)` fixtures don't exist** (verify via `grep -l "^nbv:" test/fixtures/regions.yml test/fixtures/*.yml` first), substitute with whatever Region/Season fixtures the executor finds; the test contract is independent of fixture choice. Document the substitution in SUMMARY.md.

    **Do NOT add a system test or end-to-end scraper test** that exercises the actual HTTP scrape paths — those require WebMock/VCR cassettes and are out of scope. The Region.rb edits are pure call-site additions verified by code inspection + the Tournament-level integration tests above.

    Run: `bin/rails test test/models/tournament_test.rb -n /parse_player_class_from_title|player_class_scraped_at_create_time/`

    Run: `bundle exec standardrb app/models/region.rb test/models/tournament_test.rb`

    **Sanity grep:** `grep -n "Tournament.parse_player_class_from_title" app/models/region.rb` — must return exactly 2 lines (one per scrape site). If 0 or 1, the edit didn't land at both sites.

    **LocalProtector self-check:** This change creates new local tournaments only (the existing scrape paths). It does NOT mutate any pre-existing record (global id < 50_000_000 OR local id >= 50_000_000). Confirmed: both sites are inside `unless tournament.present?` blocks — they only run when no matching Tournament exists, and the new `Tournament.create(...)` with `player_class:` is a fresh insert, not an update of an existing row. No `unprotected = true` dance needed.
  </action>
  <verify>
    <automated>bin/rails test test/models/tournament_test.rb -n /parse_player_class_from_title|player_class_scraped/ && grep -c "Tournament.parse_player_class_from_title" app/models/region.rb | grep -q '^2$' && bundle exec standardrb app/models/region.rb test/models/tournament_test.rb</automated>
  </verify>
  <done>
    - Both Region scrape sites pass `player_class: Tournament.parse_player_class_from_title(name)` to `Tournament.create(...)`.
    - The two integration tests pass — Tournament.create persists the parsed value (and nil stays nil).
    - `grep -c "Tournament.parse_player_class_from_title" app/models/region.rb` returns exactly 2.
    - standardrb clean on the two touched files.
    - SUMMARY.md notes any fixture-name substitutions and the title patterns observed-but-deferred (Damen, U17, Schüler) per Open Question 1.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| External CC HTML → Region.scrape_* | Tournament title text is sourced from third-party ClubCloud HTML scraping. Untrusted input crosses into the parser via the `name` variable. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-jfe-01 | Tampering | Tournament.parse_player_class_from_title | mitigate | Pure regex match against a hardcoded whitelist (`Discipline::PLAYER_CLASS_ORDER`); no DB query, no eval, no shell-out, no string interpolation into SQL. Returns from a closed set of strings or nil. Even maliciously-crafted titles cannot return a value outside the constant. |
| T-jfe-02 | Denial of Service | Tournament.parse_player_class_from_title | mitigate | Regex is O(n) over title length (no nested quantifiers, no catastrophic backtracking patterns). PLAYER_CLASS_ORDER has 10 items so total work is bounded at ~20 anchored regex matches per call. Title length is already bounded by the `tournaments.title :string` column (PostgreSQL default 255 chars). No ReDoS risk. |
| T-jfe-03 | Information Disclosure | n/a | accept | Parser handles only public tournament titles. No PII, no secrets. |
| T-jfe-04 | Elevation of Privilege | Region.scrape_* call sites | accept | Existing scrape paths already bypass UI authorization (server-side scraper run as system); this change only adds a derived attribute, doesn't introduce a new privilege boundary. |
</threat_model>

<verification>
After both tasks land, run the full focused test sweep + critical-path regression:

```bash
# Plan-internal contract
bin/rails test test/models/tournament_test.rb

# Critical scraping concerns (per CLAUDE.md `bin/rails test:critical`)
bin/rails test:critical

# Lint
bundle exec standardrb app/models/tournament.rb app/models/region.rb test/models/tournament_test.rb
```

All must be GREEN with zero new offenses on the touched files. Pre-existing failures in unrelated specs (e.g. `bk2_scoreboard_test.rb` per STATE.md line 119) are NOT in scope.
</verification>

<success_criteria>
- New scrape of a title containing "Klasse 5" creates a Tournament with `player_class == "5"`.
- New scrape of a title with no recognizable class creates a Tournament with `player_class == nil` (no crash, no empty string).
- All existing tournament tests still pass.
- Two integration tests + 13 unit tests = 15 new tests, all GREEN.
- `Tournament.parse_player_class_from_title` is referenced exactly twice in `app/models/region.rb`.
- No global record (id < `Tournament::MIN_ID`) is mutated. Verified by code inspection: both edits are inside `unless tournament.present?` blocks (fresh creates only).
- `standardrb` clean on touched files.
</success_criteria>

<output>
After completion, create `.planning/quick/260507-jfe-scrape-player-class-from-tournament-titl/260507-jfe-SUMMARY.md` covering:
- The two scrape sites edited (with line numbers post-edit) and the parser method signature.
- Any title patterns observed in the codebase or test fixtures that the parser intentionally returns nil for (Damen, U17, Schüler, IV+) — these become candidates for a JFE-02 follow-up if the user wants to extend coverage.
- Fixture substitutions made if `regions(:nbv)`/`seasons(:current)` weren't available.
- Confirmation: `grep -c "Tournament.parse_player_class_from_title" app/models/region.rb` returns 2.
- Test counts (RED → GREEN transition, final assertion count).
- Any plan-prescribed-test deviations per CLAUDE.md Rule 1.
</output>
