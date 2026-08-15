# Phase 39: DTP-Backed Parameter Ranges - Research

**Researched:** 2026-05-06
**Domain:** Rails ActiveRecord lookup query + range derivation; refactor-with-test-net
**Confidence:** HIGH (all claims verified against live DB + source code)

## Summary

Phase 39 replaces the hard-coded `Discipline::DISCIPLINE_PARAMETER_RANGES` constant with a context-aware lookup against the existing `discipline_tournament_plans` table (DTP, 464 rows, 12 disciplines populated). The new method signature `Discipline#parameter_ranges(tournament:)` queries DTP by `(discipline_id, tournament_plan_id, players, player_class)`, walks `PLAYER_CLASS_ORDER` on class-miss, and returns a Hash of Ranges derived from the canonical `points`/`innings` values via the lenient-OR `(p*0.75).floor..p` reduction. Disciplines without DTP entries (61 of 73 in the live DB) and `handicap_tournier=true` tournaments return `{}`.

The refactor has a clear test-net: 4 existing test files reference `parameter_ranges` (model unit, system, integration sentinel) and must be updated. The single production caller is `TournamentsController#verify_tournament_start_parameters`. The signature change is hard, NOT backward-compatible — Phase 39 D-01 commits to keyword-arg `tournament:`.

**Primary recommendation:** Implement `Discipline#parameter_ranges(tournament:)` as a 4-branch decision tree (handicap → no plan → DTP miss → DTP hit) with `PLAYER_CLASS_ORDER` walk on hit-miss. Reuse the existing `seedings.where.not(state: "no_show").count` pattern from `tournaments_controller.rb#finalize_modus` (line 196-199) — the bare `seedings.count` from CONTEXT.md D-03 is slightly less defensive. Drop 5 fields from `UI_07_FIELDS` AND drop the `UI_07_SENTINEL_VALUES` constant entirely; both per D-12/D-13. Update 4 test files in lock-step.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Methoden-Signatur und Lookup**

- **D-01:** `Discipline#parameter_ranges(tournament:)` ist die kanonische Signatur (Keyword-Argument). Hartes Brechen mit der bisherigen No-Arg-Variante; Aufrufer in `app/controllers/tournaments_controller.rb#verify_tournament_start_parameters` wird auf den neuen Aufruf umgestellt (`tournament.discipline&.parameter_ranges(tournament: tournament)`).

- **D-02:** Lookup-Query: `DisciplineTournamentPlan.where(discipline: self, tournament_plan: tournament.tournament_plan, players: tournament.seedings.count, player_class: <derived>)`. Bei Class-Mismatch greift D-04 (Fallback-Walk).

- **D-03:** `players`-Argument für DTP-Query = `tournament.seedings.count` (live count aus der Seedings-Assoziation, nicht aus `TournamentPlan.players`). Begründung: Verifikation läuft pre-start, aber nach Seeding-Eintrag — `seedings.count` reflektiert die tatsächlich gemeldeten Spieler. **Researcher-Auftrag:** prüfen, ob das in allen Fällen den DTP-Werten entspricht.

**Player-Class-Hierarchie und Fallback**

- **D-04:** Player-Class-Ordnung (worst → best): `PLAYER_CLASS_ORDER = %w[7 6 5 4 3 2 1 I II III].freeze`. Lebt als Konstante auf `Discipline` (oder optional auf `PlayerClass`). Eine spätere Daten-Source-of-Truth-Migration ist für Phase 39 NICHT in scope.

- **D-05:** Class-Match-Strategie: Erst exakter Match auf `tournament.player_class`, bei 0 Treffern Walk in Richtung "höher" (besser) durch `PLAYER_CLASS_ORDER` bis zum ersten Treffer. Kein Walk in Richtung "niedriger". Bei vollständigem Walk-Miss: leerer Hash (`{}`).

- **D-06:** Lückenmuster in DTPs (z. B. `4` und `6` vorhanden, `5` fehlt) sind Investigation-Item, kein Phase-39-Blocker. Phase 39 implementiert die Fallback-Logik korrekt; Daten-Audit + Auffüllung läuft separat.

**Reduced-Mode (operator-getroffene Reduktion)**

- **D-07:** Reduktionsfaktor ist **0.75**, nicht 0.80. Phase 38 D-20 war hier veraltet — die Praxis ist 80/20 → 60/15 (= 0.75x). Phase 39 nutzt 0.75 durchgängig.

- **D-08:** Lenient-OR-Modus: `parameter_ranges` liefert für points → Range `(canonical*0.75).floor..canonical` und für innings analog. Keine Modus-Unterscheidung, kein Trigger.

- **D-09:** Kein Tournament-Flag, keine Migration. Reduced-Entscheidung steht in der Turnier-Einladung, ist nicht maschinenlesbar.

**Non-DTP-Disziplinen + handicap_tournier**

- **D-10:** Disziplinen OHNE DTP-Eintrag (BK-Familie aus Phase 38.6: BK-2kombi, BK50, BK100, BK-2, BK-2plus; Pool, Snooker, Kegel, Biathlon, 5-Kegel; sowie Karambol-Spezialvarianten ohne DTP-Daten wie "Freie Partie" ohne Suffix, "Cadre 47/1", "Einband", "Dreiband") → `parameter_ranges` liefert `{}`.

- **D-11:** Wenn `tournament.handicap_tournier == true` → `parameter_ranges` liefert `{}` unabhängig von der Disziplin.

**Verifikations-Felder (Controller-Seite)**

- **D-12:** `UI_07_FIELDS` wird auf `[:balls_goal, :innings_goal]` reduziert. Die 5 bisher mitgeprüften Felder (`timeout`, `sets_to_play`, `sets_to_win`, `time_out_warm_up_first_min`, `time_out_warm_up_follow_up_min`) sind operator-eingegebene Parameter — kein Master-Daten-Bezug.

- **D-13:** `UI_07_SENTINEL_VALUES` wird gelöscht (toter Code nach D-12).

**Konstanten-Cleanup**

- **D-14:** Folgende Konstanten in `app/models/discipline.rb:60-94` werden vollständig entfernt: `UI_07_SHARED_RANGES`, `UI_07_DISCIPLINE_SPECIFIC_RANGES`, `DISCIPLINE_PARAMETER_RANGES`. Inkl. Kommentare zu D-17 (Phase 36B) und 2026-04-27-Widening-Hinweis.

- **D-15:** `UI_07_FIELDS` wird reduziert (D-12), `UI_07_SENTINEL_VALUES` gelöscht (D-13).

**Test-Strategie**

- **D-16:** `test/models/discipline_test.rb` deckt ab: (a) DTP-Hit Normal, (b) Class-Fallback-Walk, (c) Walk-Miss, (d) Non-DTP-Disziplin, (e) handicap_tournier=true, (f) tournament.tournament_plan=nil.

- **D-17:** `test/system/tournament_parameter_verification_test.rb` wird angepasst.

- **D-18:** Bestehende Fixtures/Factories für DisciplineTournamentPlan werden gelesen, nicht neu erstellt.

### Claude's Discretion

- Genaue Methoden-Komposition innerhalb `Discipline#parameter_ranges(tournament:)` (Hilfsmethoden-Extraktion, Modul-Split — solange die externe API D-01 stimmt).
- Reihenfolge der Branches innerhalb der Methode (handicap-Check zuerst vs. Disziplin-DTP-Check zuerst).
- Konkrete Test-Datenkonstellationen, solange D-16 a–f abgedeckt sind.

### Deferred Ideas (OUT OF SCOPE)

- TournamentMonitor-Form-Checkbox "Reduced-Modus" (Pre-fill mit 0.75x). Reine UI-Komfortfunktion. Backlog/v7.x.
- DTP-Daten-Audit (Lückenmuster). Backlog.
- Player-Class-Ordnung als DB-Daten-Source (Migration `player_classes.order_index`).
- Long-term DB-backed historical-data Range (Nightly-Rake aus realen Tournament-Daten).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DATA-01 | `Discipline#parameter_ranges` is wide enough for real-world usage without false-positive warnings from the Phase 36B parameter verification modal. Youth, handicap, pool, snooker, biathlon, and kegel disciplines either have explicit range entries or are covered by the DTP-backed lookup. Verification modal no longer fires on legitimate tournament configurations. | DTP table query (D-02) provides per-(discipline,plan,players,class) canonical values; `{}` return for non-DTP disciplines (D-10) and handicap (D-11) makes the modal unable to fire on those configs; UI_07_FIELDS reduction (D-12) eliminates operator-input fields from verification entirely. |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

| Constraint | Source | Phase 39 Implication |
|------------|--------|---------------------|
| Rails 7.2 / Ruby 3.2.1 | Tech Stack | No language/framework upgrade needed |
| Minitest (NOT RSpec) | Testing | All new tests in `test/models/discipline_test.rb` use `ActiveSupport::TestCase`, `test "..." do` syntax |
| Fixtures + FactoryBot | Testing | FactoryBot is loaded (`test_helper.rb:32`, `Gemfile:75`) but project predominantly uses fixtures. No `discipline_tournament_plans.yml` fixture exists today — Phase 39 must add it (research finding 2 below). |
| Frozen string literals | Code Conventions | Top of every Ruby file: `# frozen_string_literal: true` |
| German comments for business logic, English for technical | Code Conventions | Method docstrings business-rationale in German; method-internal logic notes in English |
| LocalProtector for global records | Architecture | `Discipline` and `DisciplineTournamentPlan` already include `LocalProtector`; Phase 39 only READS, never writes — no concern |
| `LocalProtectorTestOverride` | test_helper.rb | Tests can ignore the < MIN_ID guard |
| Conventional commit messages | Code Conventions | Phase 39 commit prefix: `feat(discipline)` or `refactor(discipline)` |
| `bundle exec standardrb` | Linting | Final code must pass standardrb |
| `strong_migrations` enforced | DB | Phase 39 has NO migrations (D-09 explicit) — N/A |
| `frozen_string_literal: true` | Code Conventions | Already present in `discipline.rb:1` and `discipline_tournament_plans.rb` does NOT have it (line 1 is schema comment) — leave as-is unless modifying that file |
| Project Skill `extend-before-build` | Skills | The new method REPLACES the old constant-based one — this is "user explicitly requests a rewrite" exception (D-01 hard break). Apply skill selectively: extend the existing method body if it makes structural sense; don't introduce a parallel resolver service. |
| Project Skill `scenario-management` | Skills | Code edits MUST happen in `carambus_master/`, NOT `carambus_bcw/`. Pre-edit cleanliness check at research time: master is 2 behind, bcw is 1 ahead and clean, api has 2 untracked script files. **Action item for executor: pull master before editing.** |

## Standard Stack

### Core (already in Gemfile)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rails (ActiveRecord) | 7.2.0.beta2 | DB query DSL for DTP lookup | `Discipline.has_many :discipline_tournament_plans` already exists (line 26); no new query infrastructure needed |
| Minitest | bundled with Rails | Test framework | Project convention; 271-line `discipline_test.rb` already uses it |
| FactoryBot | as in Gemfile | Test factory | Available but project predominantly uses fixtures |

### Supporting

| Helper | Purpose | When to Use |
|--------|---------|-------------|
| `Range#cover?` | Range membership check (existing in controller line 1040) | Already used in `verify_tournament_start_parameters` |
| `Integer#floor` (or `(x*0.75).floor`) | Reduce point/inning value to lower bound | Implements D-08 lenient-OR floor |

**No new gems needed.** [VERIFIED: Gemfile read]

## Architecture Patterns

### Recommended Method Composition

```ruby
# app/models/discipline.rb (replaces lines 51-101)

# Player-class hierarchy worst → best.
# Walk direction for fallback (D-05): ascending = stricter (better) class.
# Numbers (Karambol klein: 7..1) and Roman numerals (Karambol groß: I..III)
# coexist; no discipline mixes them in the live DB (verified 2026-05-06).
PLAYER_CLASS_ORDER = %w[7 6 5 4 3 2 1 I II III].freeze

REDUCED_FACTOR = 0.75 # D-07: Operator-getroffene Reduktion (Einladung).

# Phase 39: liefert Hash{ balls_goal: Range, innings_goal: Range } basierend auf
# DTP-Daten (Disziplin + tournament_plan + players + player_class).
# Liefert {} bei: handicap_tournier=true (D-11), fehlendem Plan (D-16f),
# Disziplin ohne DTP (D-10), oder Class-Walk-Miss (D-05 Endpunkt).
def parameter_ranges(tournament:)
  return {} if tournament.handicap_tournier
  return {} if tournament.tournament_plan.nil?

  dtp = lookup_dtp_with_class_walk(tournament)
  return {} if dtp.nil?

  {
    balls_goal:    range_from_canonical(dtp.points),
    innings_goal:  range_from_canonical(dtp.innings)
  }
end

private

def lookup_dtp_with_class_walk(tournament)
  base_scope = discipline_tournament_plans
                 .where(tournament_plan_id: tournament.tournament_plan_id)
                 .where(players: tournament.seedings.count)

  # Exakter Class-Match (D-05 Schritt 1)
  exact = base_scope.find_by(player_class: tournament.player_class)
  return exact if exact

  # Walk in Richtung "besser" (D-05 Schritt 2)
  starting_index = PLAYER_CLASS_ORDER.index(tournament.player_class.to_s)
  return nil unless starting_index # Class nicht in Order-Liste → kein Walk möglich

  PLAYER_CLASS_ORDER[(starting_index + 1)..].each do |candidate|
    hit = base_scope.find_by(player_class: candidate)
    return hit if hit
  end
  nil
end

def range_from_canonical(canonical)
  return (0..0) if canonical.to_i.zero?  # Edge: Petit/Grand Prix + Nordcup haben points=0/innings=0
  ((canonical * REDUCED_FACTOR).floor..canonical)
end
```

**Why this composition:**
- 3 methods + 2 constants. Single public entry, two private helpers.
- Branches in declared order: handicap → no plan → DTP lookup. All early-return `{}`.
- Class walk extracted because it's the only complex logic (D-05).
- `range_from_canonical` extracted to handle the `0` edge case once (Petit/Grand Prix).

### Pattern 1: Reuse existing controller participant-count idiom
**What:** `tournaments_controller.rb#finalize_modus` (line 196-199) already computes the same lookup-relevant count: `seedings.where.not(state: "no_show").where(@seeding_scope).count`.
**When to use:** Phase 39's `parameter_ranges` is LESS strict than that — D-03 says bare `seedings.count`. The existing controller pattern is more defensive (excludes no-shows).
**Recommendation:** Follow CONTEXT.md D-03 verbatim (`tournament.seedings.count`) for now. Document the discrepancy as a follow-up — if the planner discovers it matters in practice (e.g., a participant marked `no_show` shifts the DTP key from 8 to 7), it can revisit.

```ruby
# Source: app/controllers/tournaments_controller.rb:196-199 [VERIFIED: source read]
@participant_count = @tournament.seedings
                                .where.not(state: "no_show")
                                .where(@seeding_scope)
                                .count
```

### Pattern 2: Existing DTP query shape — already established
**What:** `tournaments_controller.rb#finalize_modus` (line 217-225) queries DTP with the same key shape Phase 39 needs:
```ruby
# Source: app/controllers/tournaments_controller.rb:217-225 [VERIFIED: source read]
TournamentPlan.joins(discipline_tournament_plans: :discipline)
              .where(discipline_tournament_plans: {
                       players: @participant_count,
                       player_class: @tournament.player_class,
                       discipline_id: @tournament.discipline_id
                     })
              .where.not(name: ['T0', 'T00', 'T000'])
              .first
```
**When to use:** Phase 39 should mirror this query but with `tournament_plan_id` as a filter (since it's already chosen) instead of joining via TournamentPlan. The existing pattern proves the (discipline, plan, players, class) composite is the correct lookup key.

### Anti-Patterns to Avoid
- **Caching the DTP lookup on Discipline.** The result depends on a specific Tournament — no value to cache on the Discipline class.
- **Building a parallel `BkParamResolver`-style service.** Per CLAUDE.md `extend-before-build` skill: the existing `Discipline` model is the natural home for a method named `parameter_ranges`. A separate `Discipline::ParameterRangeResolver` service is over-engineering for ~30 LOC of logic.
- **Memoizing per-instance.** `Discipline.find(x).parameter_ranges(tournament: t1)` and `parameter_ranges(tournament: t2)` are different inputs — no `@parameter_ranges ||=` on Discipline.
- **Treating `points = 0` as a real range.** Petit/Grand Prix and Nordcup have `points=0, innings=0` for ALL DTP rows (verified DB query below). Without the `0..0` edge case, the verifier would consider every realistic balls_goal an out-of-range error. Returning `(0..0)` short-circuits naturally because `Range#cover?(50)` for `0..0` is false; the controller's existing `next if range.cover?(value)` then flags it. **The cleaner approach is to return `{}` (i.e., skip verification) for `points=0/innings=0` DTP rows.** See "Open Questions" below.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Range derivation | Custom Range struct or pair of integers | Native `Range` literal `((a*0.75).floor..a)` | The controller line 1040 calls `range.cover?(value)` — only need a Range |
| Class ordering source | A `PlayerClass.order_index` migration | `PLAYER_CLASS_ORDER` constant on Discipline (D-04) | Migration is explicitly out-of-scope per D-04; deferred per "Deferred Ideas" |
| DTP lookup wrapper service | A `DtpLookup` service object | Direct AR query via `discipline_tournament_plans.where(...)` | The has_many association already exists (line 26); 3 lines of where-chain is clearer than a service |
| Class walk | A while-loop with manual index increment | `PLAYER_CLASS_ORDER[(idx+1)..].each { |c| return hit if hit }` | Idiomatic Ruby, single-purpose, easy to read |

**Key insight:** The DTP query is a 4-column composite SELECT. Both AR has_many association (line 26 `Discipline has_many :discipline_tournament_plans`) and the existing finalize_modus pattern (line 217) provide all infrastructure needed. Don't introduce abstraction.

## Runtime State Inventory

> Phase 39 is a **refactor/rewrite** phase (replaces method body + 5 constants), so the inventory below is required. Verified against bcw checkout 2026-05-06 unless noted.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — `parameter_ranges` is a pure read-side method. No DB writes. The 464 DTP rows already exist as global records (id < MIN_ID); Phase 39 only QUERIES them. | None |
| Live service config | None — no external service caches/calls `parameter_ranges`. The single in-process caller is `tournaments_controller.rb`. | None |
| OS-registered state | None — no cron jobs, no Sidekiq jobs, no scheduled tasks reference this method. | None |
| Secrets/env vars | None — no env-var-driven feature flag, no secret-keyed override. | None |
| Build artifacts / installed packages | None — no precompiled assets reference the constant names. Test fixtures (`disciplines.yml`) reference Discipline records but NOT the deleted constants. | None |
| **In-memory cached values** | The constants `UI_07_SHARED_RANGES`, `UI_07_DISCIPLINE_SPECIFIC_RANGES`, `DISCIPLINE_PARAMETER_RANGES` are class-level frozen Hashes. Loaded once at boot. | Removed by D-14 — class reload + restart in development invalidates them automatically. No data migration needed. |

**Nothing found in any category** → Phase 39 is purely a code refactor. The single risk is **stale Spring/Bootsnap caches** in dev (mitigation: `bin/spring stop` if used). Production deploy is via Capistrano with restart — no caching concern. [VERIFIED: source read across app/, test/, lib/, config/]

## Common Pitfalls

### Pitfall 1: Tournament without tournament_plan_id (production reality)
**What goes wrong:** D-02 query against `tournament_plan_id: nil` returns zero rows for ALL discipline+players+class combos → silent `{}` return → no verification on legitimately incomplete data.
**Why it happens:** Production DB has 0 tournaments with `tournament_plan_id IS NOT NULL` (verified on `carambus_api_development`: total=18287, with_plan=0). Phase 39 only fires when the wizard `select_modus` step has completed (which assigns plan_id at line 280). Pre-wizard tournaments stay nil.
**How to avoid:** D-16(f) test case ("tournament.tournament_plan=nil → {}") locks the defensive return.
**Warning signs:** A user reports "verification modal never fires" for a tournament where the wizard wasn't completed end-to-end. Expected behavior, not a bug.

### Pitfall 2: Petit/Grand Prix and Nordcup have points=0, innings=0
**What goes wrong:** DTP rows for disciplines 19 (Petit/Grand Prix) and 20 (Nordcup) have `points=0, innings=0` for ALL 32 rows (verified). The naive `((0*0.75).floor..0)` = `0..0`. Operator submitting balls_goal=50 → falls outside `0..0` → false-positive modal trigger on legitimate values.
**Why it happens:** These two disciplines use DTP for participant-count→plan-shape mapping but NOT for points/innings master data.
**How to avoid:** Return `{}` (skip verification) when the matched DTP row has `points=0` AND `innings=0`. This is a 4th implicit "no-data" branch.

```ruby
def range_from_canonical(canonical)
  return nil if canonical.to_i.zero?  # Don't seed a 0..0 Range
  ((canonical * REDUCED_FACTOR).floor..canonical)
end

# Then in parameter_ranges:
balls_range   = range_from_canonical(dtp.points)
innings_range = range_from_canonical(dtp.innings)
return {} if balls_range.nil? && innings_range.nil?  # Both zero → no master data
hash = {}
hash[:balls_goal]   = balls_range   if balls_range
hash[:innings_goal] = innings_range if innings_range
hash
```

**Warning signs:** A Nordcup or Petit/Grand Prix tournament with realistic balls_goal opens the verification modal.

### Pitfall 3: Empty-string player_class on tournament
**What goes wrong:** `tournament.player_class` is sometimes `""` (empty string), not nil. `PLAYER_CLASS_ORDER.index("")` returns `nil`, which D-05 walk handles correctly (returns nil). But `find_by(player_class: "")` may match DTP rows where the column is NULL (if the cast happens) or fail to match (PostgreSQL: `""` ≠ NULL). Verified: live DB has 32 DTP rows with `player_class = NULL` (Nordcup + Petit/Grand Prix).
**Why it happens:** The Tournament form (`tournaments/_form.html.erb:56`) offers a `prompt: true` blank option. Operator can submit empty.
**How to avoid:** Treat `tournament.player_class.presence` (or `.to_s`) consistently. If using `.to_s`, an empty string in `find_by(player_class: "")` will NOT match NULL DTPs. For Nordcup/Petit cases, this is fine — they want to fall through to `{}` anyway because `points=0/innings=0`.
**Warning signs:** An operator with player_class blank gets a different answer than expected.

### Pitfall 4: Class walk passes through wrong list (mixed numeric vs roman)
**What goes wrong:** `PLAYER_CLASS_ORDER = %w[7 6 5 4 3 2 1 I II III]` puts numbers BEFORE Roman numerals. A tournament with `player_class="3"` (Karambol klein) walks through `1 → I → II → III`. But Karambol klein DTPs only use `{1,2,3,4,5,6,7}`; Karambol groß only uses `{I,II,III}`. The walk would never find an "I" entry for a "kleines Billard" discipline because no such DTP row exists.
**Why it happens:** The constant list is a single global ordering. The discipline-specific class set isn't enforced in the constant.
**How to avoid:** **No special handling required.** The walk safely runs off the end with `nil` — falls through to D-05's "complete walk-miss → `{}`" path. **However**, it does pointless DB queries (4 misses for "3" walking up) before giving up. Not a correctness issue.
**Warning signs:** EXPLAIN ANALYZE shows extra DTP queries during verification. Acceptable for now (each query is indexed lookup, sub-ms). Optimization opportunity for later: split the order list per-discipline (Karambol klein uses 1-7, Karambol groß uses I-III).

### Pitfall 5: Test fixtures don't include DTP rows
**What goes wrong:** `test/fixtures/discipline_tournament_plans.yml` does NOT exist (verified). Tests written for D-16(a)/(b)/(c) need DTP rows. Without them, tests will fail with "no DTP found" → all return `{}`.
**Why it happens:** Phase 38 work didn't touch DTPs. Plan 39 must add fixtures.
**How to avoid:** Add a minimal `test/fixtures/discipline_tournament_plans.yml` with ~6 rows covering: (i) Freie Partie klein with classes 1+3+5+7 (gap-test for D-05 walk), (ii) Karambol groß with II only (single-class), (iii) Nordcup with points=0/innings=0 (Pitfall 2 regression).
**Warning signs:** Plan tests are GREEN but always return `{}` — the DTP join just doesn't match. Locking-in behavior tests should explicitly assert non-empty Hash for happy path.

### Pitfall 6: Stale `UI_07_SENTINEL_VALUES` test references after deletion
**What goes wrong:** `test/integration/tournament_verification_sentinels_test.rb` (entire file, 7 tests) tests `sets_to_play=0/999` and `sets_to_win=0` exemptions. After D-12 removes those fields from `UI_07_FIELDS`, the verifier IGNORES them — sentinel-exemption logic is dead, tests for it pass trivially or become misleading.
**Why it happens:** Sentinel guards were a Layer-4 fix layered on top of `UI_07_FIELDS = [..., sets_to_play, sets_to_win]`. D-12 removes the underlying need for the guard.
**How to avoid:** **Delete the entire file** `test/integration/tournament_verification_sentinels_test.rb` as part of the same plan. It's a regression guard for dead code; keeping it is misleading. (CONTEXT.md D-13 says `UI_07_SENTINEL_VALUES wird mit-gestrichen, da sie Toten Code wird` — the test file is the toter Code's test.)
**Warning signs:** Tests pass but assert nothing meaningful (e.g., "sets_to_win=999 is flagged" — but sets_to_win isn't even in UI_07_FIELDS anymore). [VERIFIED: file read]

## Code Examples

### DTP query (verified pattern from existing controller)
```ruby
# Source: app/controllers/tournaments_controller.rb:217-225 [VERIFIED]
TournamentPlan.joins(discipline_tournament_plans: :discipline)
              .where(discipline_tournament_plans: {
                       players: @participant_count,
                       player_class: @tournament.player_class,
                       discipline_id: @tournament.discipline_id
                     })
              .where.not(name: ['T0', 'T00', 'T000'])
              .first
```

### Phase 39 idiomatic equivalent (recommended)
```ruby
# Phase 39 NEW: query the FK side directly via the existing has_many
# Source: derived from app/models/discipline.rb:26 association + AR docs
discipline_tournament_plans
  .where(tournament_plan_id: tournament.tournament_plan_id)
  .where(players: tournament.seedings.count)
  .find_by(player_class: tournament.player_class)
# returns DisciplineTournamentPlan or nil
```

### Existing parameter_ranges signature change site
```ruby
# Source: app/controllers/tournaments_controller.rb:1026 [VERIFIED]
# OLD:
ranges = tournament.discipline&.parameter_ranges || {}
# NEW (D-01):
ranges = tournament.discipline&.parameter_ranges(tournament: tournament) || {}
```

### Existing system test selector (must update)
```ruby
# Source: test/system/tournament_parameter_verification_test.rb:30-32 [VERIFIED]
@tournament = Tournament.joins(:discipline)
  .where.not(state: %w[tournament_started playing_groups ...])
  .to_a
  .find { |t| t.discipline&.parameter_ranges&.any? }   # OLD signature

# NEW (D-01):
.find { |t| t.discipline&.parameter_ranges(tournament: t)&.any? }
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded `DISCIPLINE_PARAMETER_RANGES` constant (15 disciplines, single Range per pair) | DTP-backed (12 disciplines populated, ranges per (plan, players, class) tuple) | Phase 39 (this) | Verification modal stops false-firing on Pool/Snooker/Kegel/BK-/Biathlon (61 of 73 disciplines now correctly skipped). Karambol verification becomes more accurate (per-class ranges). |
| 7-field verification | 2-field verification (balls_goal, innings_goal only) | Phase 39 D-12 | Operator-input fields no longer trigger false-positives. Time/set fields cleared from check. |

**Deprecated/outdated:**
- `UI_07_SHARED_RANGES`, `UI_07_DISCIPLINE_SPECIFIC_RANGES`, `DISCIPLINE_PARAMETER_RANGES` — D-14, deleted.
- `UI_07_SENTINEL_VALUES` — D-13, deleted (dead after D-12 narrows fields).
- `test/integration/tournament_verification_sentinels_test.rb` (7 tests) — recommended deletion (Pitfall 6).

## Researcher Findings (per CONTEXT.md questions)

### Finding 1 — D-03 validation: `seedings.count` vs `tournament_plan.players`

**Question:** Does `seedings.count` always reflect the value used to populate `discipline_tournament_plans.players`?

**Answer:** [VERIFIED: live DB query, source code read]

- The existing controller pattern (`tournaments_controller.rb#finalize_modus:196-199`) uses `seedings.where.not(state: "no_show").where(@seeding_scope).count` — i.e., participant-only, scope-filtered count.
- D-03's bare `tournament.seedings.count` is more permissive (includes no-shows).
- `tournament_plan.players` ALSO exists as a column. For tournaments where `tournament_plan_id` is set, `tournament.tournament_plan.players` is the EXACT count baked into that plan (e.g., plan T04_5 has `players: 5`).
- **Discrepancy in practice:** The bcw DB has 0 tournaments with `tournament_plan_id` set; the carambus_api DB has 0 tournaments with `tournament_plan_id` set. So real-world test of seedings.count vs. plan.players cannot be performed today.
- **Risk:** If a tournament starts with 8 seedings but 1 marks `no_show`, `seedings.count` = 8 (matches DTP for 8-player config) vs. `tournament_plan.players` = also 8 (the plan was chosen for 8). Both consistent. If a seeding is dropped (destroyed), `seedings.count` drops but `tournament_plan.players` stays — the DTP query would suddenly miss.
- **Recommendation:** Follow CONTEXT.md D-03 verbatim (`tournament.seedings.count`). Document the discrepancy with the controller pattern as Open Question 2 below. If the verification fires/misses unexpectedly post-deploy, switch to `seedings.where.not(state: "no_show").count`.

### Finding 2 — Test fixtures vs FactoryBot for DTP-specific tests

**Inspection results:** [VERIFIED: filesystem]

- `test/fixtures/discipline_tournament_plans.yml` — **DOES NOT EXIST**.
- `test/factories/` — **DOES NOT EXIST** (no factories directory).
- FactoryBot IS loaded (`test_helper.rb:32: require 'factory_bot_rails'` and `:117: include FactoryBot::Syntax::Methods`) but no factories are defined for ANY model.
- `test/fixtures/disciplines.yml` exists with 11 entries (5 BK-* + 5 Karambol-related + Pool).
- `test/fixtures/tournaments.yml` exists with 4 entries (`local`, `imported`, `scraped`, `wc_*`). The `:local` fixture has `tournament_plan_id: 50_000_100` (line 62) and points to `tournament_plans(:t04_5)`.
- `test/fixtures/tournament_plans.yml` exists with 2 entries (`t04_5`, `t06_6`).
- `test/fixtures/seedings.yml` exists with 3 entries — but only for InternationalTournament fixtures, NOT for `:local`.

**Recommendation:**

Use **fixtures, not factories**, consistent with project convention:

1. **Add** `test/fixtures/discipline_tournament_plans.yml` with ~10 rows covering D-16 cases:
   - 2 rows for Karambol klein (Freie Partie klein) class 1 + class 3 (gap test for class 5/walk)
   - 2 rows for Karambol groß (Dreiband groß) class I + class II (Roman walk)
   - 1 row with points=0/innings=0 (Nordcup edge case, Pitfall 2)
   - 1 row for Cadre 47/2 (verifies non-fixture discipline)
2. **Extend** `test/fixtures/seedings.yml` to populate the `:local` tournament with N seedings matching DTP `players` values.
3. **Extend** `test/fixtures/tournaments.yml` to add fixtures for D-16 cases (e.g., `local_handicap` with `handicap_tournier: true`, `local_no_plan` with `tournament_plan_id: nil`).

FactoryBot would also work but adds a new pattern. The existing test conventions in `discipline_test.rb` and `tournament_parameter_verification_test.rb` use fixtures exclusively — match the convention.

### Finding 3 — PLAYER_CLASS_ORDER validation against real DTP data

**Question:** Which player_class values exist in DTP? Are there values not in `%w[7 6 5 4 3 2 1 I II III]`?

**Answer:** [VERIFIED: live DB query]

```sql
SELECT DISTINCT player_class FROM discipline_tournament_plans ORDER BY player_class;
-- 1, 2, 3, 4, 5, 6, 7, I, II, III, NULL  (11 distinct values; NULL for Nordcup + Petit/Grand Prix)
```

`PLAYER_CLASS_ORDER` is **complete** for all non-NULL values. NULL never appears as `tournament.player_class` — the form (`_form.html.erb:56`) only offers the 10 defined values + blank prompt. Empty-string handling (Pitfall 3) is the only edge case.

**Class gaps within (discipline, plan, players) tuples — verified pattern:**

```sql
SELECT discipline_id, players, ARRAY_AGG(DISTINCT player_class ORDER BY player_class) AS classes
FROM discipline_tournament_plans
WHERE discipline_id IN (31, 33, 34) GROUP BY discipline_id, players ORDER BY discipline_id, players;
```

| Discipline | Players | Classes available |
|------------|---------|-------------------|
| Dreiband groß (31) | 1-4 | I, II, III (full set) |
| Dreiband groß (31) | 5-8 | II, III (**Class I split into different `tournament_plan_id`**) |
| Dreiband groß (31) | 9-10 | III (only); class I, II live in different plan |
| Freie Partie klein (34) | 1-5, 9-11, 13-16 | 1-7 (full set) |
| Freie Partie klein (34) | 6-8, 12 | Split: 1-5 in one plan, 6-7 in another |

**This is NOT a "gap" pattern (`{4, 6}` skipping `5`).** It's a **plan-stratification** pattern: the same (discipline, players) tuple appears in multiple `tournament_plan_id` groupings, each carrying a different class subset. D-06's "gap" mental model is slightly off — there are no gaps WITHIN a (discipline, plan, players) tuple. Walk is necessary because a tournament with `player_class=I` may not match the `tournament_plan_id` chosen, but `player_class=II` for that plan exists.

D-06 is correct as scoped (no Phase 39 blocker). Walk strategy (D-05) handles this stratification correctly: walk for class I → first hit at class II in the same `(plan, players)` row.

### Finding 4 — Carambol disciplines without DTP entries (D-10 list completeness)

**Answer:** [VERIFIED: live DB query]

```sql
SELECT d.id, d.name FROM disciplines d
LEFT JOIN discipline_tournament_plans dtp ON dtp.discipline_id = d.id
WHERE dtp.id IS NULL ORDER BY d.name;
-- 61 rows
```

Karambol-related disciplines without DTP entries (full list):

| ID | Name | In CONTEXT.md D-10? |
|----|------|---------------------|
| 104 | Cadre | NO — D-10 incomplete |
| 42 | Cadre 38/2 | NO |
| 41 | Cadre 47/1 | YES |
| 10 | Cadre 57/2 | NO |
| 103 | Dreiband (no suffix) | YES |
| 87 | Dreiband Doppel (kl) | NO |
| 12 | Dreiband halb | NO |
| 105 | Einband (no suffix) | YES |
| 11 | Einband halb | NO |
| 106 | Freie Partie (no suffix) | YES |

D-10 lists 4 of these 10. The other 6 are also DTP-less — but D-10's logic is "any non-DTP discipline → `{}`". The implementation is unaffected by which specific names are listed. The list in D-10 is **descriptive** ("z. B. ..."), not **prescriptive**. **No action needed**, but the planner should be aware that ALL 61 DTP-less disciplines (not just the 14-15 named in D-10) automatically get `{}` returns.

### Finding 5 — Existing call sites of `parameter_ranges`

**Answer:** [VERIFIED: grep across app/, test/, lib/]

```
app/models/discipline.rb:99               (definition)
app/controllers/tournaments_controller.rb:1026  (production caller — single)
test/integration/tournament_verification_sentinels_test.rb:17, 20, 23  (test double)
test/models/discipline_test.rb:33, 45, 53, 63  (test calls)
test/system/tournament_parameter_verification_test.rb:31, 133  (test calls)
```

**Production: 1 caller.** D-01 is correct.

**Tests: 4 files referencing `parameter_ranges` directly.** All must be updated:

1. `test/models/discipline_test.rb` — 4 existing tests + 2 anchor tests use no-arg signature. **Replace + extend per D-16 (a–f).**
2. `test/system/tournament_parameter_verification_test.rb` — 2 calls (line 31, 133) use no-arg signature. **Update signature to `parameter_ranges(tournament: t)`. Adjust test data per D-17 (Pool/BK/handicap cases).**
3. `test/integration/tournament_verification_sentinels_test.rb` — uses `FakeDiscipline` Struct that mimics `parameter_ranges` (no-arg). **DELETE entire file (Pitfall 6).** Or refactor to test the new 2-field UI_07_FIELDS.
4. `test/fixtures/discipline_tournament_plans.yml` — **CREATE** (Finding 2 recommendation).

### Finding 6 — Sentinel-Value reduction implication (D-13)

**Answer:** [VERIFIED: grep]

```
app/controllers/tournaments_controller.rb:45  (definition)
app/controllers/tournaments_controller.rb:1039  (sole reference in verifier)
test/integration/tournament_verification_sentinels_test.rb:24, 98  (test references)
```

**Confirmed:** No views, no helpers, no other controllers, no jobs reference `UI_07_SENTINEL_VALUES`. D-13's deletion is safe — the constant is referenced only by its definition site, the verifier (line 1039), and one test file (Pitfall 6 → delete).

### Finding 7 — handicap_tournier behavior (D-11)

**Answer:** [VERIFIED: live DB query, source code read]

```sql
SELECT count(*) FROM tournaments WHERE handicap_tournier = true;
-- bcw DB: 4
-- api DB: 4 (same 4 tournaments)
```

Real records:
| ID | Title | Discipline | balls_goal | innings_goal | player_class |
|----|-------|------------|-----------|--------------|--------------|
| 14210 | 1.Vorgabepokal | 34 (Freie Partie klein) | NULL | NULL | NULL |
| 12430 | 4. Vorgabeturnier Freie Partie | 34 | NULL | 20 | NULL |
| 17400 | 4. Vorgabepokal | 34 | NULL | NULL | NULL |
| 17385 | 3. Vorgabepokal | 34 | NULL | NULL | NULL |

**`balls_goal` is NULL** in 4/4 cases (per-Seeding via `seedings.balls_goal`, NOT tournament-level). **`innings_goal` is NULL in 3/4** (the one with `innings_goal=20` is a tournament-level setting, not part of handicap math).

Confirms D-11: `parameter_ranges` returning `{}` for handicap_tournier=true is correct because:
1. `tournament.balls_goal` is NULL → the verifier's `next if raw.nil?` check (line 1034) already skips it.
2. `tournament.innings_goal` may be set, but it's open-ended for handicap — no master-data range exists.
3. Returning `{}` short-circuits the entire verification (line 1027 `return [] if ranges.empty?`).

`Seeding` model has `balls_goal :integer` column (line 9 — verified). Per-seeding handicap targets are set when individual participants are added; never tournament-level for handicap tournaments.

**4-known estimate is correct.** No edge cases discovered.

## Test Strategy Recommendations

### D-16 Test Layout (recommended)

```ruby
# test/models/discipline_test.rb (additions)

# Phase 39 D-16: parameter_ranges(tournament:) DTP-backed lookup
# ============================================================

class DisciplinePhase39Test < ActiveSupport::TestCase
  # D-16(a): DTP-Hit Normal
  test "parameter_ranges returns reduced..canonical Range on exact DTP hit" do
    tournament = tournaments(:local_freie_partie_klein_class_1)  # NEW fixture
    discipline = disciplines(:discipline_freie_partie_klein)
    ranges = discipline.parameter_ranges(tournament: tournament)
    assert_equal (188..250), ranges[:balls_goal]   # 250 * 0.75 = 187.5 → floor 187..wait, 188 — verify
    assert_equal (11..15),   ranges[:innings_goal]
  end

  # D-16(b): Class fallback walk
  test "parameter_ranges walks PLAYER_CLASS_ORDER on class miss" do
    tournament = tournaments(:local_dreiband_gross_class_I)  # No I in plan, only II,III
    ranges = disciplines(:dreiband_gross).parameter_ranges(tournament: tournament)
    refute_empty ranges, "should fallback to class II"
  end

  # D-16(c): Walk-Miss
  test "parameter_ranges returns {} when walk exhausts PLAYER_CLASS_ORDER" do
    tournament = tournaments(:local_strange_class)  # player_class not in any DTP
    assert_equal({}, disciplines(:dreiband_gross).parameter_ranges(tournament: tournament))
  end

  # D-16(d): Non-DTP discipline
  test "parameter_ranges returns {} for non-DTP discipline" do
    tournament = tournaments(:local)  # Pool, BK-2kombi, etc.
    assert_equal({}, disciplines(:bk2_kombi).parameter_ranges(tournament: tournament))
  end

  # D-16(e): handicap_tournier=true
  test "parameter_ranges returns {} for handicap tournament" do
    tournament = tournaments(:local_handicap)  # NEW fixture, handicap_tournier: true
    assert_equal({}, disciplines(:discipline_freie_partie_klein).parameter_ranges(tournament: tournament))
  end

  # D-16(f): tournament_plan=nil
  test "parameter_ranges returns {} when tournament has no plan" do
    tournament = tournaments(:local_no_plan)  # NEW fixture, tournament_plan_id: nil
    assert_equal({}, disciplines(:discipline_freie_partie_klein).parameter_ranges(tournament: tournament))
  end
end
```

### Fixture Additions

```yaml
# test/fixtures/discipline_tournament_plans.yml (CREATE)

freie_partie_klein_5p_class1:
  id: 50_000_001
  discipline: discipline_freie_partie_klein
  tournament_plan: t04_5
  players: 5
  player_class: "1"
  points: 250
  innings: 15
  created_at: <%= 1.year.ago %>
  updated_at: <%= 1.day.ago %>

freie_partie_klein_5p_class3:
  id: 50_000_002
  # ... etc
```

```yaml
# test/fixtures/tournaments.yml (extend)

local_freie_partie_klein_class_1:
  id: 50_000_100
  title: "Freie Partie klein, class 1"
  season_id: 50_000_001
  organizer_id: 50_000_001
  organizer_type: "Region"
  discipline_id: 50_000_004  # Freie Partie klein
  tournament_plan_id: 50_000_100  # t04_5 (5 players)
  player_class: "1"
  state: "tournament_mode_defined"
  date: <%= 2.weeks.from_now %>
  created_at: <%= 1.month.ago %>
  updated_at: <%= 1.day.ago %>

local_handicap:
  id: 50_000_101
  title: "Handicap Tournament"
  # ... handicap_tournier: true
```

```yaml
# test/fixtures/seedings.yml (extend)

local_seed_1:
  id: 50_000_010
  player_id: 50_001_001
  tournament_id: 50_000_100
  tournament_type: "Tournament"
  state: "seeded"
  position: 1
# ... 4 more for 5-player tournament
```

### D-17 System Test Update

```ruby
# test/system/tournament_parameter_verification_test.rb:31
# OLD:
.find { |t| t.discipline&.parameter_ranges&.any? }
# NEW:
.find { |t| t.discipline&.parameter_ranges(tournament: t)&.any? }

# Line 133:
# OLD:
safe_value = @tournament.discipline.parameter_ranges[:balls_goal].first + 5
# NEW:
safe_value = @tournament.discipline.parameter_ranges(tournament: @tournament)[:balls_goal].first + 5
```

Add new test cases:
- Pool tournament → modal does NOT fire (D-10 confirmation)
- BK-2kombi tournament → modal does NOT fire
- Handicap tournament → modal does NOT fire
- Non-handicap Karambol with class fallback → modal flags out-of-range correctly

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL | DTP query | ✓ | 16+ (psql client tested) | — |
| Rails 7.2 / Ruby 3.2.1 | All code | ✓ | matches `.ruby-version` | — |
| ActiveRecord has_many | Discipline → DTP | ✓ | already wired (line 26) | — |
| Minitest | Tests | ✓ | bundled with Rails | — |
| FactoryBot | Optional for tests | ✓ | loaded but unused | use fixtures (Finding 2) |

**No missing dependencies.** All Phase 39 work uses tools and infrastructure already in the codebase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The 4-known handicap tournaments are exhaustive | Finding 7 | If a 5th handicap tournament has different shape (e.g., balls_goal NOT NULL at tournament level), D-11 still applies — `{}` for handicap is unconditional. Low risk. |
| A2 | `tournament.player_class` is always String or nil (not symbol/int) | Pitfall 3 | The form select sends strings; controllers don't munge. Verified by reading `_form.html.erb:56` — `options_for_select(["I", ..., "7"])` produces strings. Low risk. |
| A3 | D-08 `floor` semantics: `(80*0.75).floor = 60` | Spec | Ruby's `Float#floor` returns Integer; `60.0.floor == 60`. Verified by inspection. No risk. |
| A4 | The recommended `range_from_canonical(0) → nil` (skip) is acceptable per D-08 | Pitfall 2 / Recommendation | This is a **researcher recommendation**, not in CONTEXT.md. CONTEXT.md doesn't address `points=0`/`innings=0`. The planner SHOULD ask the user during planning whether (a) skip the field (recommended), (b) return `0..0` (literal), or (c) return some other sentinel. |
| A5 | Empty-string vs NULL player_class is treated as "no walk start" | Pitfall 3 | This may need user confirmation. PLAYER_CLASS_ORDER doesn't include `""` so `index("")` returns nil → walk doesn't start → `{}`. For Nordcup/Petit-Grand-Prix where DTP class is NULL, the lookup `find_by(player_class: nil)` would actually match (AR translates `nil` → SQL `IS NULL`). Recommend explicit handling. |

## Open Questions (RESOLVED)

1. **Should DTP rows with `points=0` AND `innings=0` skip verification or return `0..0`?**
   - What we know: 32 of 464 DTP rows (Petit/Grand Prix + Nordcup) have `points=0, innings=0`. Returning `0..0` would false-fire on every realistic operator input.
   - What's unclear: CONTEXT.md doesn't address this case.
   - Recommendation: Return `nil` (skip) for zero-canonical fields; if BOTH balls_goal AND innings_goal are zero, return `{}`. Confirm with user during planning.
   - **RESOLVED:** per RQ-01 — return {} when both points=0 AND innings=0 (zero-canonical Cup-series for Petit/Grand Prix + Nordcup; the TournamentPlan delegates Score-Targets to the per-Discipline of the individual cup-tournaments).

2. **`seedings.count` (D-03) vs `seedings.where.not(state: 'no_show').count` (existing controller)?**
   - What we know: D-03 says bare `seedings.count`; existing `tournaments_controller.rb#finalize_modus:196` uses no_show-filtered. The existing finalize_modus method DOES use the filtered count when looking up DTPs for a different purpose. Inconsistency in the codebase.
   - What's unclear: which is the intended source of truth?
   - Recommendation: Follow CONTEXT.md D-03 verbatim, document the discrepancy. Revisit if production bug surfaces.
   - **RESOLVED:** per RQ-02 — bare `tournament.seedings.count` verbatim per CONTEXT.md D-03. No state filter.

3. **`tournament.player_class.to_s` empty-string handling: walk attempted or skip?**
   - What we know: empty-string returns `nil` from `PLAYER_CLASS_ORDER.index("")`, so walk doesn't start (per current recommended composition).
   - What's unclear: should we instead start walk from worst class ("7" or "1" or "I")? D-05 doesn't specify behavior for blank input.
   - Recommendation: When `tournament.player_class.blank?`, return `{}` immediately (treat as no input → no verification). Mirrors D-11 conservative philosophy.
   - **RESOLVED:** per RQ-03 — return {} immediately when `tournament.player_class.blank?`. No walk attempt.

4. **Should `test/integration/tournament_verification_sentinels_test.rb` be deleted in Phase 39 or carried as test debt?**
   - What we know: 7 tests test the dead `UI_07_SENTINEL_VALUES` exemption logic. After D-12+D-13, all 7 are testing dead/no-op code paths.
   - What's unclear: planner-level decision — D-13 is a deletion decision; the test file is implicitly its corollary but isn't named in CONTEXT.md.
   - Recommendation: Delete in the same phase. Note the deletion in the SUMMARY as a Phase 39 cleanup item.
   - **RESOLVED:** per RQ-04 — delete `test/integration/tournament_verification_sentinels_test.rb` in Plan 39-02 Task 2.

5. **System test fixture compatibility with new DTP-required setup:**
   - The `:local` fixture has `tournament_plan_id: 50_000_100` but no seedings, and no `discipline_tournament_plans.yml` exists.
   - Today's test `tournament_parameter_verification_test.rb` finds a tournament via `Tournament.joins(:discipline).where(...).find { |t| t.discipline&.parameter_ranges&.any? }` — this works because today `parameter_ranges` is constant-driven.
   - After Phase 39, that finder will return `nil` because no DTP fixtures exist.
   - Recommendation: The plan MUST add DTP fixtures + seedings in lock-step with the code change. Skipping fixtures will break the system test.
   - **RESOLVED:** per RQ-05 — Plan 39-01 Task 1 lands DTP fixtures + tournament/seedings fixtures + impl + tests in the same plan, atomically.

## Sources

### Primary (HIGH confidence)
- Source code (read directly):
  - `app/models/discipline.rb` (435 lines) — current parameter_ranges implementation, schema, constants
  - `app/models/discipline_tournament_plan.rb` (47 lines) — DTP model
  - `app/models/tournament.rb` (lines 1-100, 280-320, 510-540) — schema, AASM states, before_save data extraction
  - `app/models/seeding.rb` (lines 1-50) — schema with balls_goal column
  - `app/controllers/tournaments_controller.rb` (lines 1-50, 178, 196-292, 321-345, 1010-1080) — UI_07 constants, verify method, start action, select_modus, existing DTP query pattern
  - `test/models/discipline_test.rb` (271 lines, full read)
  - `test/system/tournament_parameter_verification_test.rb` (147 lines, full read)
  - `test/integration/tournament_verification_sentinels_test.rb` (lines 1-107)
  - `test/fixtures/disciplines.yml`, `tournament_plans.yml`, `seedings.yml`, `tournaments.yml`
  - `.agents/skills/scenario-management/SKILL.md`, `.agents/skills/extend-before-build/SKILL.md`
  - `CLAUDE.md`, `.planning/config.json`
- Live database queries:
  - `psql -d carambus_bcw_development` — 11 queries across `discipline_tournament_plans`, `disciplines`, `tournaments`, `player_classes`
  - `psql -d carambus_api_development` — 3 cross-validation queries on tournaments

### Secondary (MEDIUM confidence)
- CONTEXT.md decision references to Phase 38 / 38.1 / 38.4 / 38.5 / 38.6 / 38.7 (not re-verified — accepted as authoritative project history)

### Tertiary (LOW confidence)
- None — no WebSearch performed (this is a refactor of internal code; external research not required)

## Metadata

**Confidence breakdown:**
- Method composition: HIGH — derived directly from existing `tournaments_controller.rb#finalize_modus` pattern (line 217-225)
- Standard stack: HIGH — Rails 7.2 + AR has_many + Minitest, all already in Gemfile
- Architecture: HIGH — 30 LOC in 3 methods, no new abstractions
- Pitfalls: HIGH — 6 pitfalls all verified against live DB or source code
- Test strategy: MEDIUM — fixture skeleton requires user/planner sign-off on shape
- Open Questions: 5 documented — recommend resolving Q1 (zero-canonical handling) and Q3 (empty-string player_class) before plan execution

**Research date:** 2026-05-06
**Valid until:** 2026-06-06 (stable refactor; DB schema is invariant)

---

## Pre-Flight Reminder for the Planner

1. **Scenario-management:** All code edits MUST happen in `carambus_master/`. Pull master before editing (it's 2 commits behind origin/master at research time).
2. **Test fixtures must land in the same plan as the code change.** A plan that adds the new method but no DTP fixtures will break `tournament_parameter_verification_test.rb` (currently passing).
3. **Sequence-sensitive deletions:**
   - DELETE `UI_07_SENTINEL_VALUES` (controller line 45)
   - DELETE `UI_07_SHARED_RANGES`, `UI_07_DISCIPLINE_SPECIFIC_RANGES`, `DISCIPLINE_PARAMETER_RANGES` (discipline.rb lines 60-94)
   - DELETE `test/integration/tournament_verification_sentinels_test.rb` (entire file — Pitfall 6)
   - REDUCE `UI_07_FIELDS` to `%i[balls_goal innings_goal]`
   - REPLACE `Discipline#parameter_ranges` body with new method using keyword arg `tournament:`
   - UPDATE `tournaments_controller.rb:1026` to pass `tournament:`
   - UPDATE `test/system/tournament_parameter_verification_test.rb:31, 133` for new signature
   - REPLACE/EXTEND `test/models/discipline_test.rb` parameter_ranges tests per D-16
4. **Fixtures gate behavior:** Without `discipline_tournament_plans.yml` fixture, all D-16 (a)/(b)/(c) tests will incorrectly assert `{}`. Add fixture before writing tests.
5. **Confirm Open Question 1 with user before plan ships:** zero-canonical (`points=0/innings=0`) DTP rows behavior is unspecified in CONTEXT.md.
