---
status: diagnosed
trigger: "in http://0.0.0.0:3007/locations/0819bf0d7893e629200c20497ef9cfff?data-turbo=false&sb_state=free_game_detail&table_id=4 muss es möglich sein, die BK2-Kombi Disziplin auszuwählen - und/oder auch per shortcut auf http://0.0.0.0:3007/locations/1?sb_state=free_game&table_id=4"
created: 2026-04-23T14:00:00Z
updated: 2026-04-23T14:20:00Z
---

## Current Focus

hypothesis: CONFIRMED — BK2-Kombi is missing from FOUR hardcoded whitelists/routers in the free-game (non-tournament) selection UI path. It also bypasses the `discipline.data`-driven derivation entirely because that only fires for tournament-backed games.
test: Traced the full path from `/locations/:id?sb_state=free_game[_detail]` → `LocationsController#show` → `scoreboard_free_game_*` render → `_quick_game_buttons` partial → `start_game` controller → `TableMonitor::GameSetup.derive_free_game_form`
expecting: Confirmed all candidates A/D/F are actual root-cause contributors; candidates B/C/E are not applicable (no discipline_type filter, no region scope, shortcut path is a subset of path A).
next_action: Return diagnosis (goal: find_root_cause_only). Plan-phase --gaps to own the fix.

## Symptoms

expected: BK2-Kombi discipline (id 107, data={"free_game_form":"bk2_kombi"}) is selectable from the free_game / free_game_detail start UI on /locations/:id?sb_state=...&table_id=N
actual: BK2-Kombi discipline is NOT offered in the discipline selection UI; user cannot reach the BK2-Kombi scoreboard without manual DB manipulation
errors: None — feature is simply absent from the UI
reproduction: Open http://0.0.0.0:3007/locations/:id?sb_state=free_game_detail&table_id=4 or ?sb_state=free_game&table_id=4; attempt to select BK2-Kombi discipline; it does not appear in the list
started: Discovered during UAT for Phase 38.1 (2026-04-23); the discipline was wired at the data layer (id 107 data={"free_game_form":"bk2_kombi"}) and for the scoreboard partial, but nothing in 38.1 added it to the discipline-selection UI.

## Eliminated

- hypothesis: "Filter by discipline_type / game_type restricts list"
  evidence: "The free-game UI does NOT query `Discipline.where(...)` at all for the picker. The picker is a hardcoded Alpine.js radio-select driven by the literal array `Discipline::KARAMBOL_DISCIPLINE_MAP` (indices 0..13). No database query, therefore no type/scope filter is in play."
  timestamp: 2026-04-23T14:18:00Z

- hypothesis: "Region / parent-region scope excludes Discipline 107"
  evidence: "Same as above — no `Discipline.where` executes in the free-game selection path. Region scoping is not the cause."
  timestamp: 2026-04-23T14:18:00Z

## Evidence

- timestamp: 2026-04-23T14:05:00Z
  checked: app/controllers/locations_controller.rb `show` action, case-statement on session[:sb_state]
  found: |
    Lines 126-197 handle sb_state=="free_game": always renders `scoreboard_free_game_karambol_quick` when `@table.present?` and a club is present. No discipline parameter from the URL is considered.
    Lines 198-284 handle sb_state=="free_game_detail": at line 263-264 composes template name as
      `"scoreboard_free_game_#{TableKind::TABLE_KIND_FREE_GAME_SETUP[@table.table_kind.name]}"`
    which for a Small Billard table resolves to `scoreboard_free_game_karambol_new` — there is no bk2_kombi template name, and the mapping is many-to-one (every kegel/small-billard kind maps to "karambol_new").
  implication: Controller has no branch that could ever route a user to a BK2-Kombi-aware selection screen. Entry point is karambol-only for Small Billard tables.

- timestamp: 2026-04-23T14:07:00Z
  checked: app/models/table_kind.rb
  found: |
    Lines 29-38 — `TABLE_KIND_FREE_GAME_SETUP` maps every TableKind to "pool" | "snooker" | "karambol_new". "Small Billard" → "karambol_new". No "bk2_kombi" value anywhere.
    Lines 40-49 — `TABLE_KIND_DISCIPLINE_NAMES["Small Billard"]` lists 8 disciplines: "Dreiband klein", "Freie Partie klein", "Einband klein", "Cadre 52/2", "Cadre 35/2", "Biathlon", "Nordcup", "Petit/Grand Prix". **"BK2-Kombi" is missing.**
  implication: Two hardcoded whitelists exclude BK2-Kombi. `TABLE_KIND_FREE_GAME_SETUP` keeps the user on the karambol screen; `TABLE_KIND_DISCIPLINE_NAMES` (if/where consumed) would also omit it.

- timestamp: 2026-04-23T14:09:00Z
  checked: app/views/locations/scoreboard_free_game_karambol_new.html.erb (the free_game_detail template for Small Billard)
  found: |
    Line 176: `<input name='free_game_form' value='karambol' type='hidden'/>` — hardcoded.
    Line 209: `discipline: <%= Discipline::KARAMBOL_DISCIPLINE_MAP.index(options[:player_a][:discipline].presence || "Freie Partie klein").to_i %>`
    Lines 252-323: six `radio_select` partials with `values: [0..5]` or `[6..13]` and displays ["3Band", "Frei", "1Band", "52/2", "35/2", "Eurok"] etc.
    `displays` arrays are hand-authored short labels; `values` are indices into `KARAMBOL_DISCIPLINE_MAP`.
  implication: The free_game_detail discipline picker is a hardcoded Alpine.js radio-select over KARAMBOL_DISCIPLINE_MAP indices. It cannot render BK2-Kombi because (a) KARAMBOL_DISCIPLINE_MAP does not include it and (b) the displays array is fixed-length with no BK2 slot.

- timestamp: 2026-04-23T14:11:00Z
  checked: app/models/discipline.rb KARAMBOL_DISCIPLINE_MAP constant
  found: |
    Lines 130-145 — 14 entries total:
    ```
    ["Dreiband klein", "Freie Partie klein", "Einband klein", "Cadre 52/2",
     "Cadre 35/2", "Eurokegel", "Dreiband groß", "Freie Partie groß",
     "Einband groß", "Cadre 71/2", "Cadre 47/2", "Cadre 47/1",
     "5-Pin Billards", "Biathlon"]
    ```
    Index positions 0..5 are the Small Billard set used by free_game_detail; **"BK2-Kombi" is not present anywhere.**
  implication: The source-of-truth constant for the free-game discipline dropdown excludes BK2-Kombi. Any fix that only writes `discipline.data["free_game_form"]` (already done in Plan 02 Path A/B) is invisible to this UI path because the UI never queries the Discipline table.

- timestamp: 2026-04-23T14:13:00Z
  checked: app/views/locations/_quick_game_buttons.html.erb + config/carambus.yml
  found: |
    _quick_game_buttons.html.erb lines 4-17 — hardcoded 3-way branch: `is_pool`, `is_snooker`, else karambol. No `is_bk2_kombi` branch.
    Lines 71-131 — form generation has hardcoded `<% if is_pool %>`, `<% elsif is_snooker %>`, `<% else %>` (karambol). Karambol branch sets `quick_game_form=karambol`, never `bk2_kombi`.
    config/carambus.yml lines 21-45 — `quick_game_presets.small_billard` has categories "Freie Partie", "Dreiband", "Eurokegel" only. **No BK2-Kombi category.**
  implication: The `sb_state=free_game` shortcut UI has no entry point for BK2-Kombi; it also would need its own button set in carambus.yml AND a new is_bk2_kombi branch AND an end-to-end quick_game_form=bk2_kombi value that start_game can translate.

- timestamp: 2026-04-23T14:15:00Z
  checked: app/controllers/table_monitors_controller.rb#start_game
  found: |
    Lines 129-178 — discipline/points normalization branches on `p[:free_game_form]`:
      - `== "pool"` → uses `Discipline::POOL_DISCIPLINE_MAP[discipline_choice.to_i]`
      - `== "karambol"` → uses `Discipline::KARAMBOL_DISCIPLINE_MAP[discipline_choice.to_i]`
      - `== "snooker"` → snooker-specific param handling
      - **No `== "bk2_kombi"` branch.**
    Line 205: `@table_monitor.start_game(p)` — hands off to TableMonitor::GameSetup with whatever free_game_form survived.
  implication: Even if the user submitted a request with free_game_form=bk2_kombi, the controller has no knowledge of what BK2-specific options it should set. discipline_a / discipline_b would remain blank or pick a karambol discipline by index, mis-routing the game.

- timestamp: 2026-04-23T14:17:00Z
  checked: app/services/table_monitor/game_setup.rb
  found: |
    Lines 67-71 (initialize_game): `"free_game_form" => ... derive_free_game_form(tm.tournament_monitor&.tournament)` — derivation only fires when there is a tournament_monitor AND a tournament. Free-game (non-tournament) flows have `tm.tournament_monitor == nil`, so the derivation returns nil and the hardcoded param from the form ("karambol") wins.
    Line 388-389 (build_result_hash): same pattern — `@options["free_game_form"].presence || derive_free_game_form(...tournament)`. The hardcoded "karambol" hidden field has `.presence == "karambol"`, so derivation is never reached.
    Lines 229-253 (derive_free_game_form): implementation correctly reads `JSON.parse(discipline.data)["free_game_form"]` — but only useful IF a tournament with Discipline 107 is attached.
  implication: Plan 02's discipline.data wiring is correct for tournament-backed matches, but the free-game (non-tournament) URL paths the user tested (`sb_state=free_game[_detail]`) NEVER flow through a tournament.discipline lookup — they submit a hardcoded free_game_form from a hidden field. BK2-Kombi needs its own discipline picker + form hidden field + start_game branch to be reachable from the free-game UI.

## Resolution

root_cause: |
  BK2-Kombi has no entry point in the free-game (non-tournament) discipline-selection UI. The path `/locations/:id?sb_state=free_game[_detail]&table_id=N` is governed by FOUR hardcoded whitelists/routers that exclude BK2-Kombi, and the `discipline.data["free_game_form"] == "bk2_kombi"` derivation added in Plan 02 never fires on this path because it is tournament-dependent:

  1. **app/models/table_kind.rb:29-38** — `TABLE_KIND_FREE_GAME_SETUP["Small Billard"] = "karambol_new"` routes the `free_game_detail` view for every Small Billard table to `scoreboard_free_game_karambol_new.html.erb`. No "bk2_kombi" value exists; no branch for a BK2-specific template.

  2. **app/views/locations/scoreboard_free_game_karambol_new.html.erb:176** — the submitted `free_game_form` is a hardcoded hidden field: `<input name='free_game_form' value='karambol' type='hidden'/>`. Lines 252-323 render a hardcoded Alpine.js radio-select with `values: [0..5]` mapping into `Discipline::KARAMBOL_DISCIPLINE_MAP[0..5]`. BK2-Kombi is not in that array and there is no seventh slot.

  3. **app/models/discipline.rb:130-145** — `KARAMBOL_DISCIPLINE_MAP` has 14 entries; "BK2-Kombi" is NOT among them. This constant is the single source of truth for the free_game_detail discipline dropdown and for the post-submit discipline-name lookup in `TableMonitorsController#start_game:147`.

  4. **app/views/locations/_quick_game_buttons.html.erb:4-17 + app/controllers/table_monitors_controller.rb:129-178** — the `sb_state=free_game` shortcut branches hardcoded into `is_pool | is_snooker | (else) karambol`; there is no `is_bk2_kombi` branch, no `quick_game_presets.small_billard` category for BK2 in `config/carambus.yml`, and the controller has no `p[:free_game_form] == "bk2_kombi"` branch to translate BK2-specific options.

  Additionally, `TableMonitor::GameSetup#initialize_game` (line 70) and `#build_result_hash` (lines 388-389) both call `derive_free_game_form(tm.tournament_monitor&.tournament)` — but only when there is a tournament. Free-game (non-tournament) flows never invoke this, so the `discipline.data["free_game_form"] = "bk2_kombi"` value written in Plan 02 Path A+B is unreachable through these URLs regardless of the whitelist fixes above.

fix: (not applied — goal: find_root_cause_only)

verification: (not applied)

files_changed: []
