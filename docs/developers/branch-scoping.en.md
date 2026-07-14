# Branch Tagging & Scope Band

## 1. Purpose / Overview

The **Scope Band** is a global, session-persistent slice of the data along
several facets — **Region**, **Season**, **Branch** (billiard discipline family)
and, context-sensitively, **Club**. It answers the question "which slice of the
world is this user currently looking at?" and applies it as a **foreign-key
filter** to the index lists (tournaments, leagues, players …).

Two building blocks make up the subsystem:

- **`BranchTaggable`** (model concern) — derives a `branch_id` from a record's
  discipline (Pool/Snooker/Karambol/Kegel), analogous to `region_id`. The column
  lives on `tournaments` and `leagues`.
- **`Scopable`** (controller concern) — holds Region/Season/Branch/Club as a
  session scope, exposes them via `Current.scope`, and has `SearchService` apply
  them as an FK filter.

**Core design decision — no leak into the search box:** The scope is applied
**separately** from the full-text user search (`params[:sSearch]`). The band
filters over real FK columns (`region_id`, `season_id`, `discipline_id` …); it
never touches the user's search string. "Choose a slice" and "search within the
slice" stay two independent axes.
(Source: `app/controllers/concerns/scopable.rb:1-13`,
`app/services/search_service.rb:51-52`.)

**"No All" — with one exception:** Region and Season are **always** a concrete
value (there is no "All Regions" state). Only **Branch** (and the
context-sensitive Club facet) may be empty, meaning "All Branches" / "All Clubs".
Branch is genuinely cross-cutting, and (still) unclassified disciplines
(`branch_id = nil`) would slip through the grid if a choice were forced.
(Source: `scopable.rb:8-13`.)

---

## 2. `BranchTaggable` Concern

File: `app/models/concerns/branch_taggable.rb`

### Deriving `branch_id`

The concern registers exactly one callback and three methods:

```ruby
included do
  before_save :set_branch_id, if: -> { will_save_change_to_discipline_id? || branch_id.nil? }
end

def find_associated_branch_id
  root = discipline&.root
  root.is_a?(Branch) ? root.id : nil
end

def set_branch_id
  self.branch_id = find_associated_branch_id
end
```

(Source: `branch_taggable.rb:9-22`.)

- `discipline.root` walks the `super_discipline` chain up to the tree root
  (`app/models/discipline.rb:585-587`).
- If the root is a **`Branch`** (Pool/Snooker/Karambol/Kegel), its `id` is set;
  otherwise `nil` (e.g. a discipline not yet rooted under a Branch — the code's
  own example: 10-Ball until the authority-tree fix).
- The callback fires only when `discipline_id` changed **or** when `branch_id` is
  still `nil` — it does not recompute on every save.

### Includers

Only two models carry the column and the concern:

- `Tournament` — `app/models/tournament.rb:65`
- `League` — `app/models/league.rb:37`

### Deliberately lean design (no PaperTrail)

Unlike `RegionTaggable`, `BranchTaggable` runs **no** version/PaperTrail
machinery. There are no `after_save`/`after_destroy` callbacks that back-tag
versions — only the live `branch_id` column. The concern is deliberately minimal
(`branch_taggable.rb:3-5`).

### Backfill of global records — historical note (gotcha)

> **Caution — stale comment in the code.** The header comment in
> `branch_taggable.rb:5` references a backfill task
> `lib/tasks/branch_taggings.rake`. **That file no longer exists** — it was
> removed in commit `56e67264` (Phase 17 17-03, "Branch facet scope band on
> discipline.root", SB-2).

The original approach was an `update_all` backfill over `discipline.root`
(bypassing `LocalProtector`, because `update_all` fires no callbacks). It was
abandoned because it fundamentally cannot work reliably for **synced global
records** (`id < MIN_ID`):

1. The version apply writes attributes via `update_columns` — which bypasses the
   `BranchTaggable` `before_save`, so `branch_id` is not populated.
2. `LocalProtector` then locks any re-save of global records on local servers.
3. → `branch_id` stays **NULL** on synced global records.

Therefore the scope band resolves the Branch facet **at query time** via
`discipline.root` instead of querying the (empty-on-global-records) `branch_id`
column — see section 3 and `Branch.discipline_ids_for`
(`app/models/branch.rb:22-58`). The `branch_id` column *is* populated on the
authority via the `before_save` during normal saves and serves as a derived
dimension there; but for filtering it is **not** the source of truth.

---

## 3. `Scopable` Concern (the Scope Band)

File: `app/controllers/concerns/scopable.rb`.
Included into `ApplicationController` (`app/controllers/application_controller.rb:21`).

### `SCOPE_FACETS` — facet → FK column

```ruby
SCOPE_FACETS = {
  "region" => "region_id",
  "season" => "season_id",
  "branch" => "branch_id",
  "club"   => "club_id"
}.freeze
```

(Source: `scopable.rb:19-24`.) `club` is the context-sensitive 3rd facet for
models with `scope_extra_facet == :club` (Player) and is filtered via a join.

### Request wiring

`ApplicationController` queues two before_actions
(`application_controller.rb:42-43`):

1. **`capture_scope`** — reads `params[:scope]` and merges the values into
   `session[:scope]`. Values are concrete IDs (no "All"). On a real change it
   additionally calls `persist_scope_preference` (`scopable.rb:47-60`).
2. **`set_current_scope`** — places the resolved FK scope into `Current.scope`,
   which `SearchService` consumes per request (`scopable.rb:79-94`).

**Write-back to user preferences:** Logged-in users remember their slice across
sessions in `preferences["scope"]`. Cleared facets ("All Branches") are removed
from the preference so the default kicks in again. The write is fault-tolerant —
a failed preference write never aborts the request (`scopable.rb:65-76`).

### The "No All except Branch" rule

The concrete default/empty rules live in `ScopeResolver` (defaults section below).
For the band:

- **Region, Season:** always concrete. Fallback chain Session → Preference →
  server context (Region only) → default.
- **Branch, Club:** may stay empty (`nil`), meaning "All Branches"/"All Clubs" —
  in which case **no** filter is set for that facet.

### Defaults (`ScopeResolver`)

File: `app/services/scope_resolver.rb`. The resolver is a pure derivation from
session + user and is used by both the HTTP controller (`Scopable`) **and** the
`SearchReflex` (ActionCable live search) — so the default rules exist in a single
place (`scope_resolver.rb:1-12`, `app/reflexes/search_reflex.rb:44`).

- **Region** (`scope_resolver.rb:32-34`): Session → Preference → server-context
  region → **NBV** (by `shortname`, else first Region; `scope_resolver.rb:76-78`).
  Regional servers set the region from the server context
  (`Carambus.config.context` = region shortname, `scope_resolver.rb:68-73`); the
  global server uses the NBV default.
- **Season** (`scope_resolver.rb:37-39`): Session → Preference → current season;
  during the **season transition** (today ≤ Aug 15 of the start year) the
  **previous season** is the default (`scope_resolver.rb:82-98`).
  `season_transition?` reports this state for a discreet band hint
  (`scope_resolver.rb:53-55`).
- **Branch** (`scope_resolver.rb:42-44`): Session → Preference; otherwise `nil` =
  "All Branches". A set branch preference is respected as the default.
- **Club** (`scope_resolver.rb:47-49`): analogous to Branch.

`fk_scope` builds the hash `{ "region_id" => …, "season_id" => …, "branch_id" =>
…, "club_id" => … }` and **removes `nil` values via `compact`** — empty facets
thus produce no filter (`scope_resolver.rb:22-29`).

### `scope_extra_facet` — which 3rd facet does the band show?

Besides Region and Season, the band shows a context-dependent third facet. It
follows the current controller model via the class method `scope_extra_facet`
(`scopable.rb:207-215`):

| Model    | `scope_extra_facet` | Source                              |
|----------|---------------------|-------------------------------------|
| Default (`ApplicationRecord`) | `:branch` | `application_record.rb:50-52` |
| `Player` | `:club`             | `player.rb:42-44`                   |
| `Club`   | `:none`             | `club.rb:54-56`                     |
| `Location` | `:none`           | `location.rb:90-92`                 |

For an unknown controller, `scope_extra_facet` defensively falls back to
`:branch` (`scopable.rb:213-215`).

### Drill-down mode (`DRILL_FOCUS_KEYS`)

```ruby
DRILL_FOCUS_KEYS = %w[tournament_id league_id club_id party_id].freeze
```

(Source: `scopable.rb:30`.) The drill-down is the generalization of the former
`region_focus`: an **ephemeral arrival context** from `params[:drill] =
{ <parent_fk> => <id> }` that narrows the child list to a parent (e.g. "show the
leagues of this club").

- The **allowlist** `DRILL_FOCUS_KEYS` prevents **column injection**: only these
  four FK columns land in the drill context (`scopable.rb:101-114`).
- An active drill replaces the scope band with **breadcrumbs**
  (`drill_focus_crumbs`, `scopable.rb:122-147`) and is kept **separate** from the
  scope band: `set_current_scope` sets `Current.drill` and empties `Current.scope`
  (`scopable.rb:80-86`).
- The drill writes **nothing** to the session (ephemeral).

A **temporary region focus** (`params[:region_focus]`, from `regions/show`) is a
separate, also ephemeral param with **higher priority** than the persistent band
value: it overrides `region_id` for this request only, without changing
`session[:scope]` (`scopable.rb:88-92`, `scopable.rb:160-176`).

### `Current.scope` / `Current.drill`

`Current` (`app/models/current.rb`) is an `ActiveSupport::CurrentAttributes` with,
among others, two attributes:

- **`Current.scope`** — the scope band's FK filter hash, set per request
  (`current.rb:8`).
- **`Current.drill`** — the ephemeral parent FK of the drill-down, kept
  **separate** from the scope band so `SearchService` filters it directly
  (`where(fk => id)`) rather than running the facet special logic (club_id join)
  (`current.rb:12`).

### Application by `SearchService` (FK filter)

File: `app/services/search_service.rb`. In `call`, the service invokes
`apply_scope` first, then `apply_drill` — **before** the full-text search
(`search_service.rb:22-28`).

**`apply_scope`** (`search_service.rb:57-113`):

1. If `Current.scope` is empty → return unchanged (`:59`).
2. **Column-injection allowlist:** models can exempt themselves entirely via
   `scope_exempt?` (picker lists like `Region`) → early return (`:61`,
   `region.rb:136`). Otherwise each facet is applied only if the model actually
   carries the column (`cols.include?(col)`, `:95`).
3. **Club** (`:72-83`): join-based and season-bound. Only models with a
   `season_participations` association (Player) are filtered
   (`joins(:season_participations).where(club_id:, season_id:)`, distinct); other
   models ignore the Club facet.
4. **Branch** (`:88-93`): The `branch_id` column is **not** queried (NULL on
   global records, SB-2). Instead resolution over the discipline subtree:
   `where(discipline_id: Branch.discipline_ids_for(value))`. Models without
   `discipline_id` ignore the Branch facet (behavior-neutral).
5. **Region** (`:97-110`): Strict models (`scope_region_strict? == true`:
   Location/Player/Club) show only their own `region_id`. Non-strict models
   (leagues/tournaments) additionally include `global_context = TRUE`
   (cross-region records, e.g. DBU leagues).

**`apply_drill`** (`search_service.rb:38-49`): filters each present drill FK
directly via `where(col => value)` — defensively only for columns the model
carries.

`Branch.discipline_ids_for(branch_id)` (`app/models/branch.rb:32-58`) returns all
discipline `id`s whose tree root is that Branch (including the Branch `id`
itself). It builds a process-wide memoized tree index once (`ids_by_root`, one
`pluck`, no N+1 root walk); `reset_discipline_ids_cache!` forces recomputation.
The tree only changes via sync/scrape, so the cache is rebuilt on code reload
(dev) or deploy/restart (prod).

### Option sources for the band view

All option helpers return `[label, id]` pairs (values = IDs, no "All"):

- `scope_region_options` — all regions except `UNKNOWN`, by shortname
  (`scopable.rb:269-271`).
- `scope_season_options` — real "yyyy/yyyy+1" names from 2009 up to
  current year + 2, descending (`scopable.rb:275-280`).
- `scope_branch_options` — `Branch.order(:name)` (`scopable.rb:282-284`).
- `scope_club_options` — clubs of the current scope region, label
  `COALESCE(shortname, name)`, nameless stubs omitted (`scopable.rb:289-295`).

---

## 4. Relation to `RegionTaggable`

`BranchTaggable` is deliberately built as a **lean analogue** of `RegionTaggable`
(`app/models/concerns/region_taggable.rb`). Commonality: both derive an FK
dimension from the record and feed it into the scope filter. The differences:

| Aspect | `RegionTaggable` | `BranchTaggable` |
|--------|------------------|------------------|
| Derived column | `region_id` (+ `global_context`) | `branch_id` |
| Derivation logic | `find_associated_region_id` — big `case` over model class **and** `tournament_type`; returns a **single** ID (`region_taggable.rb:11-53`) | `find_associated_branch_id` — only `discipline.root`, one branch (`branch_taggable.rb:15-18`) |
| Version/PaperTrail tagging | yes — `after_save`/`after_destroy :update_version_region_data`, tags versions for region sync (`region_taggable.rb:7-8`, `:123-143`) | **no** — live column only, no version machinery |
| `global_context` | yes — `global_context?` marks cross-region records (`region_taggable.rb:55-79`) | no |
| Includers | 16 models (Region, Club, Tournament, League, Party, Player, Game, …) | 2 models (Tournament, League) |
| Backfill task | `lib/tasks/region_taggings.rake` (exists, curated) | removed — query-time resolution via `discipline.root` |

The former `find_associated_region_ids` (array) was simplified to a **single** ID
(`find_associated_region_id`); see
[`region-tagging-cleanup-summary.en.md`](region-tagging-cleanup-summary.en.md).
`BranchTaggable` adopted this lean form from the start — plus the omission of the
version machinery.

**Filter asymmetry in `SearchService`:** `region_id` is filtered directly as a
column (with a `global_context` OR for non-strict models). `branch_id`, by
contrast, is **never** filtered as a column but always resolved via
`discipline.root` — precisely because of the NULL problem on synced global
records (section 2).

---

## 5. DB columns & rake backfill tasks

### Migration

`db/migrate/20260702061649_add_branch_id_to_tournaments_and_leagues.rb`:

```ruby
disable_ddl_transaction!

add_column :tournaments, :branch_id, :integer unless column_exists?(...)
add_column :leagues,     :branch_id, :integer unless column_exists?(...)
add_index  :tournaments, :branch_id, algorithm: :concurrently unless ...
add_index  :leagues,     :branch_id, algorithm: :concurrently unless ...
```

Derived FK dimension analogous to `region_id`: **nullable**, **no** FK constraint
(Discipline is global), index concurrently (strong_migrations).

### Schema

- `tournaments.branch_id` (integer) + `index_tournaments_on_branch_id`
  (`db/schema.rb:1462`, `:1464`).
- `leagues.branch_id` (integer) + `index_leagues_on_branch_id`
  (`db/schema.rb:542`, `:544`).

### Rake backfill tasks

- **Branch:** **no active task.** The former `lib/tasks/branch_taggings.rake`
  (`namespace :branch_taggings`, task `update_all_branch_id`) was removed in
  `56e67264` (see section 2). A backfill of global records is not possible; the
  band resolves the Branch facet at query time.
- **Region (analogue):** `lib/tasks/region_taggings.rake` exists and is the
  curated source of truth for DE tagging. Key tasks:
  - `region_taggings:update_all_region_id` — organic region derivation top-down
    (Region → Club → SeasonParticipation → Player etc.).
  - `region_taggings:fix_international_organizer_context` — tags international
    organizer regions as `global_context` (authority only, PaperTrail-tracked;
    `ARMED=1` mutates). DRY-RUN by default.
  - A **recurrence guard** (`guard_derivation_retag!`,
    `region_taggings.rake:126-137`) locks the derivation-based re-tag tasks,
    because `RegionTaggable#global_context?`/`#find_associated_region_id` are
    incomplete and would silently tear down the curated global tagging. Override:
    `FORCE_DERIVATION_RETAG=1`.

---

## 6. Gotchas

1. **`branch_id = nil` for unclassified disciplines.** Disciplines whose tree root
   is (still) not a `Branch` yield `find_associated_branch_id == nil`
   (`branch_taggable.rb:15-18`). Such records carry no Branch and appear only in
   the "All Branches" state. This is the reason for the "No All except Branch"
   exception (`scopable.rb:11-13`).

2. **The `branch_id` column is NOT the filter source.** On synced global records
   (`id < MIN_ID`), `branch_id` stays NULL (update_columns during version apply
   bypasses the `before_save`, `LocalProtector` locks the re-save).
   `SearchService` therefore **never** queries `branch_id` but resolves via
   `Branch.discipline_ids_for` / `discipline.root` (`search_service.rb:88-93`).
   Anyone using the column for their own query must know this gap.

3. **Stale backfill reference in the concern comment.** `branch_taggable.rb:5`
   names `lib/tasks/branch_taggings.rake` — the file no longer exists (removed in
   `56e67264`). No backfill present.

4. **Global vs. regional server — region default.** Regional servers set the
   default region from `Carambus.config.context` (region shortname). The global
   server (empty context) falls back to **NBV** (currently the only region in real
   use; `scope_resolver.rb:31-34`, `:66-78`). DBU is simply a selectable region,
   not a special state.

5. **Season transition shifts the default.** Until Aug 15 of the current season's
   start year, the **previous season** is the season default (final
   results/rankings are settled, the new season is still being planned;
   `scope_resolver.rb:82-98`). `scope_season_transition?` signals this for the band
   hint.

6. **Region-strict vs. non-strict models.** For `region_id` filtering, strict
   models (Player/Club/Location, `scope_region_strict? == true`) show **only**
   their own region; `global_context` there is a sync-retention marker and is
   never shown. Non-strict models (tournaments/leagues) include
   `global_context = TRUE` (`search_service.rb:97-110`, `player.rb:49`,
   `club.rb:61`, `location.rb:97`).

7. **`SearchReflex` bypasses the controller before_actions.** The ActionCable
   live search does not run through `set_current_scope`. It sets `Current.scope`
   itself via the same `ScopeResolver` (`search_reflex.rb:44`) — otherwise the
   scope would be `nil` in the live search.
