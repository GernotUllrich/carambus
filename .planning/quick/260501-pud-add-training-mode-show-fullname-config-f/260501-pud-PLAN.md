---
phase: 260501-pud
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/models/table_monitor/options_presenter.rb
  - test/models/table_monitor/options_presenter_test.rb
  - config/carambus.yml.erb
  - config/carambus.yml
autonomous: true
requirements:
  - QUICK-260501-pud-01
must_haves:
  truths:
    - "When training_mode_show_fullname is unset/false, presenter returns truncated name (simple_firstname.presence || lastname) for non-team non-guest player in training mode (current behavior preserved bit-for-bit)."
    - "When training_mode_show_fullname is true, presenter returns player.fullname for non-team non-guest player in training mode."
    - "Tournament-mode path (show_tournament_monitor.id present) returns player.fullname unconditionally — UNCHANGED by the flag."
    - "Guest path (player.guest? true) returns player.fullname unconditionally — UNCHANGED by the flag."
    - "Team path (player.is_a?(Team)) returns player.fullname unconditionally — UNCHANGED by the flag."
    - "config/carambus.yml.erb default block contains training_mode_show_fullname: false (explicit, documents the flag's existence)."
    - "config/carambus.yml (gitignored compiled mirror) is in sync with config/carambus.yml.erb."
  artifacts:
    - path: "app/models/table_monitor/options_presenter.rb"
      provides: "Single guard branch in both fullname blocks (player_a + player_b) reading Carambus.config.training_mode_show_fullname"
      contains: "Carambus.config.training_mode_show_fullname"
    - path: "test/models/table_monitor/options_presenter_test.rb"
      provides: "RED-then-GREEN tests pinning both flag=true and flag=false (default) paths for non-team non-guest training-mode player"
      contains: "training_mode_show_fullname"
  key_links:
    - from: "app/models/table_monitor/options_presenter.rb"
      to: "Carambus.config.training_mode_show_fullname"
      via: "OpenStruct attribute read at request time (config memoized at process boot)"
      pattern: "Carambus\\.config\\.training_mode_show_fullname"
    - from: "config/carambus.yml.erb"
      to: "config/carambus.yml"
      via: "Manual sync (Phase 38.4 D-decision: Carambus.config reads .yml, not .erb)"
      pattern: "training_mode_show_fullname"
---

<objective>
Add `Carambus.config.training_mode_show_fullname` (default `false`) to control whether training-mode partials (no `tournament_monitor`) show the full player name (`player.fullname`) or the disambiguation-shortened form (`simple_firstname.presence || lastname`) for registered, non-team, non-guest players.

Purpose: Tomorrow's BCW Grand Prix (2026-05-02) runs in Training Mode with a mix of external guests and registered club members. The operator wants full names visible for everyone on the scoreboard; today, registered players are silently truncated while guests already get full names. A boolean flag in `carambus.yml` lets BCW flip the behavior without code changes, and lets every other scenario keep current behavior unchanged.

Output:
- A `Carambus.config.training_mode_show_fullname` guard inserted as ONE new `elsif` branch in the existing if/elsif/else ladder in `options_presenter.rb` (extend-before-build SKILL — single small guard inside the existing predicate, no new helper class, no parallel rendering path).
- 5 unit tests pinning the flag's true/false behavior on the non-team non-guest training-mode path AND the unchanged-by-flag tournament/guest paths.
- Default value `training_mode_show_fullname: false` documented in `carambus.yml.erb` `default:` section, mirrored to `carambus.yml` per Phase 38.4 sync convention.

Operator workflow (NOT in scope here): After this code lands and is deployed, BCW operator sets `training_mode_show_fullname: true` in `carambus_bcw/config/carambus.yml.erb` AND `carambus_bcw/config/carambus.yml` (production block), then deploys via Capistrano before the Grand Prix.
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@.agents/skills/extend-before-build/SKILL.md
@.agents/skills/scenario-management/SKILL.md
@app/models/table_monitor/options_presenter.rb
@test/models/table_monitor/options_presenter_test.rb
@config/carambus.yml.erb
@config/carambus.yml

<interfaces>
<!-- Key contracts the executor needs. Extracted from codebase. -->

From config/application.rb (lines 10-21):
```ruby
module Carambus
  def self.config
    @config ||= begin
                  yaml = YAML.load_file(Rails.root.join('config', 'carambus.yml'))
                  settings = yaml['default'].merge(yaml[Rails.env] || {})
                  OpenStruct.new(settings)
                end
  end

  def self.config=(new_config)
    @config = new_config
  end
end
```

Behavior implications:
- `Carambus.config` is memoized via `@config ||=` and is an OpenStruct. Reading `Carambus.config.training_mode_show_fullname` on a YAML that does NOT contain the key returns `nil` → falsy → preserves current behavior. NO migration / per-scenario change required for non-BCW deployments to keep working.
- Tests overriding via `Carambus.config = OpenStruct.new(original.to_h.merge(...))` and restoring in `ensure` is the safe pattern (the public setter exists for exactly this).

From app/models/table_monitor/options_presenter.rb (player_a, lines 105-112; player_b, lines 136-143 IDENTICAL with @gps[1]):
```ruby
fullname: if show_tournament_monitor&.id.present? ||
  @gps[0]&.player.is_a?(Team)
            @gps[0]&.player&.fullname
          elsif @gps[0]&.player&.guest?
            @gps[0]&.player&.fullname
          else
            @gps[0]&.player&.simple_firstname.presence || @gps[0]&.player&.lastname
          end,
```

Target post-change shape (player_a; player_b mirrors verbatim with @gps[1]):
```ruby
fullname: if show_tournament_monitor&.id.present? ||
  @gps[0]&.player.is_a?(Team)
            @gps[0]&.player&.fullname
          elsif @gps[0]&.player&.guest?
            @gps[0]&.player&.fullname
          elsif Carambus.config.training_mode_show_fullname
            # Optionaler Training-Mode-Override für vollständige Spielernamen
            # (z. B. BCW Grand Prix 2026-05-02). Default false → unverändertes
            # Verhalten für alle anderen Szenarien.
            @gps[0]&.player&.fullname
          else
            @gps[0]&.player&.simple_firstname.presence || @gps[0]&.player&.lastname
          end,
```

The if/elsif arms (Tournament-mode + Team, Guest) are UNCHANGED — the new `elsif` is inserted between the existing `elsif guest?` and the existing `else`. Only the else-branch is the path that flips behavior.

From test/models/table_monitor/options_presenter_test.rb (helper, lines 71-106):
```ruby
def build_tm_with_game(player_a_attrs: {}, player_b_attrs: {}, data_overrides: {})
  player_a = Player.create!(firstname: ..., lastname: ..., guest: ..., id: 50_000_000 + rand(1_000_000))
  player_b = Player.create!(...)
  game = Game.create!(data: minimal_data(data_overrides), gname: "presenter_test_#{SecureRandom.hex(4)}")
  GameParticipation.create!(game: game, player: player_a, role: "playera")
  GameParticipation.create!(game: game, player: player_b, role: "playerb")
  tm = TableMonitor.create!(state: "playing", data: minimal_data(data_overrides), game: game)
  mock_location = OpenStruct.new(id: 1, name: "Test Location")
  mock_table = OpenStruct.new(location: mock_location)
  tm.define_singleton_method(:table) { mock_table }
  [tm, player_a, player_b, game]
end
```

This helper produces a TableMonitor with `tournament_monitor == nil` (training mode), non-team non-guest players — exactly the path the flag toggles. Reuse it.

Existing test on line 285 stubs tournament_monitor with a PartyMonitor mock — copy that pattern verbatim for tests D and E.

From STATE.md Phase 38.4 D-decision (line 82):
> "carambus.yml (compiled/ignored) must be kept in sync with carambus.yml.erb manually — Carambus.config reads the local .yml, not the .erb template"

Both files MUST be edited in this plan; otherwise the test (which boots Rails and reads carambus.yml) sees the OLD config. The default value `false` is the safe baseline regardless — but explicit documentation in YAML helps operators discover the flag.
</interfaces>

# Project conventions to honor (from CLAUDE.md)

- `# frozen_string_literal: true` already present at top of options_presenter.rb — don't re-add or remove.
- German comments for business logic, English for technical terms — the new guard's inline comment IS German.
- Standard linting: match the surrounding style of the if/elsif lines.
- `bin/rails test test/models/table_monitor/options_presenter_test.rb` is the targeted command. Full suite is heavier; not required for this quick task.

# Scenario-management caveat

CWD is `carambus_bcw/`. Per scenario-management SKILL Default Workflow (Normal Mode), code edits belong in `carambus_master/` and propagate to BCW via `git pull`. **Before editing, the executor MUST run the pre-edit precondition check from the SKILL** (verify all 4 checkouts are clean wrt master OR on dedicated feature branches). If any checkout has unpushed master-tracking commits or dirty working tree on conflicting files, STOP and ask the user.

If user has NOT entered Debugging Mode for `carambus_bcw`, the code edits (presenter.rb + tests + carambus.yml.erb default-block + carambus.yml default-block) MUST be applied to `carambus_master/` (path same relative to repo root). The user then handles `git pull` in `carambus_bcw/` as part of deployment.

If user explicitly enters Debugging Mode for `carambus_bcw`, edits go to the current CWD `carambus_bcw/` and the user later requests commit + sync.

The plan tasks below use repo-relative paths. Executor adapts the absolute prefix based on mode at execution time. **The BCW-only `training_mode_show_fullname: true` override is OUT OF SCOPE for this plan** — it is the operator's deployment step in BCW's `production:` block.

</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED — write failing tests for training_mode_show_fullname flag</name>
  <files>test/models/table_monitor/options_presenter_test.rb</files>
  <behavior>
    Five new tests appended to `TableMonitor::OptionsPresenterTest`:

    All tests use the existing `build_tm_with_game` helper plus a new `with_config(**overrides) { ... }` private helper that:
      1. Saves `original = Carambus.config`
      2. Stubs `Carambus.config = OpenStruct.new(original.to_h.merge(overrides))`
      3. Yields
      4. ENSURE-restores `Carambus.config = original`

    **Test A — flag false, non-team non-guest, training mode → truncated (CURRENT BEHAVIOR)**
    - Players: Max Muster + Erika Beispiel (non-guest, non-team, training mode via empty tournament_monitor)
    - flag = false
    - Verifies player_a/player_b fullnames equal `simple_firstname.presence || lastname` (executor first inspects `Player.new(firstname: "Max", lastname: "Muster").simple_firstname` to know whether to assert "Muster" or "M Muster" or whatever the helper actually returns; assertion uses the actual computed expected value, NOT a guess).
    - PASSES today.

    **Test B — flag true, non-team non-guest, training mode → fullname**
    - Same players as A
    - flag = true
    - assert_equal player_a.fullname, result["player_a"]["fullname"]
    - assert_equal player_b.fullname, result["player_b"]["fullname"]
    - **FAILS today** (this is the RED test). Today's else-branch ignores the flag and always truncates.

    **Test C — flag true, GUEST player goes through guest branch (UNCHANGED)**
    - Player A guest=true, Player B guest=false
    - flag = true
    - assert_equal player_a.fullname, result["player_a"]["fullname"]   (guest path produces fullname — proves guest path UNCHANGED)
    - assert_equal player_b.fullname, result["player_b"]["fullname"]   (registered, flag=true → fullname via new branch)
    - PASSES today (player_a goes through guest arm regardless of flag).

    **Test D — flag true + tournament_monitor present → fullname via tournament arm (UNCHANGED)**
    - Use the same `tm.define_singleton_method(:tournament_monitor) { mock_party_monitor }` stub trick as the existing line-285 test.
    - flag = true
    - assert_equal player_a.fullname, result["player_a"]["fullname"]   (tournament arm hit — flag irrelevant)
    - PASSES today.

    **Test E — flag false + tournament_monitor present → fullname via tournament arm (UNCHANGED)**
    - Same tm stub as D, flag = false
    - assert_equal player_a.fullname, result["player_a"]["fullname"]
    - PASSES today (regression-guard partner of D).

    All 5 tests live at the end of `TableMonitor::OptionsPresenterTest`. The `with_config` helper sits near the top of the test file (after `build_tm_with_game`, before Test 1).

    Run: `bin/rails test test/models/table_monitor/options_presenter_test.rb`
    Expected RED: Test B FAILS. Tests A, C, D, E PASS. Pre-existing 11+ tests still PASS.
  </behavior>
  <action>
    1. Open test/models/table_monitor/options_presenter_test.rb.
    2. Add a private helper near the top, immediately after the closing `end` of `build_tm_with_game` (around line 106):
       ```ruby
       def with_config(**overrides)
         original = Carambus.config
         Carambus.config = OpenStruct.new(original.to_h.merge(overrides))
         yield
       ensure
         Carambus.config = original
       end
       ```
    3. Append the 5 tests (A, B, C, D, E) per `<behavior>` above. Test description strings can be German for the BR-specific tests (e.g. `test "training_mode_show_fullname=true zeigt fullname im Training-Mode für non-team non-guest Spieler" do`); helper method names stay English.
    4. For Test A, before writing the assertion line, add a one-time inline verification by calling `Player.new(firstname: "Max", lastname: "Muster").simple_firstname` in a Rails runner OR by reading `app/models/player.rb`'s `simple_firstname` method — pin the exact expected truncated value in the assertion. This avoids a false RED in Test A.
    5. Run `bin/rails test test/models/table_monitor/options_presenter_test.rb` — capture output. Expected: Test B fails, all others pass. If Test A also fails, the executor's `simple_firstname` expectation was wrong — fix Test A's assertion (this is a test-correctness issue, not code).
    6. Do NOT edit options_presenter.rb in this task.
    7. Do NOT edit carambus.yml(.erb) in this task — flag is unset by default, OpenStruct returns nil → falsy; tests A/D/E rely on this; Test B sets it true explicitly via `with_config`.
  </action>
  <verify>
    <automated>cd "$(git rev-parse --show-toplevel)" && bin/rails test test/models/table_monitor/options_presenter_test.rb 2>&1 | tail -40</automated>
  </verify>
  <done>
    Test B fails with assertion message indicating flag=true did not produce fullname (else-branch hit instead of new elsif). Tests A, C, D, E pass. Pre-existing 11+ tests in the file still pass (no regressions). Failure output captured for the SUMMARY.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN — add Carambus.config.training_mode_show_fullname guard to both fullname blocks</name>
  <files>app/models/table_monitor/options_presenter.rb</files>
  <behavior>
    The else-branch ladder in BOTH `player_a` (lines ~105-112) and `player_b` (lines ~136-143) `fullname:` blocks gets ONE new `elsif Carambus.config.training_mode_show_fullname` arm inserted between the existing `elsif … guest?` and the existing `else`. After the change, Test B from Task 1 turns GREEN; Tests A, C, D, E remain GREEN; pre-existing 11+ tests stay GREEN.

    Extend-before-build SKILL applied: ONE additional elsif on the existing predicate ladder. NO new helper method, NO new class, NO new module, NO new partial branch in views.
  </behavior>
  <action>
    1. Open app/models/table_monitor/options_presenter.rb.
    2. Locate the `player_a` `fullname:` block (lines 105-112). Insert a new `elsif` BEFORE the final `else`:
       ```ruby
       fullname: if show_tournament_monitor&.id.present? ||
         @gps[0]&.player.is_a?(Team)
                   @gps[0]&.player&.fullname
                 elsif @gps[0]&.player&.guest?
                   @gps[0]&.player&.fullname
                 elsif Carambus.config.training_mode_show_fullname
                   # Optionaler Training-Mode-Override für vollständige Spielernamen
                   # (z. B. BCW Grand Prix 2026-05-02). Default false → unverändertes
                   # Verhalten für alle anderen Szenarien.
                   @gps[0]&.player&.fullname
                 else
                   @gps[0]&.player&.simple_firstname.presence || @gps[0]&.player&.lastname
                 end,
       ```
    3. Apply the IDENTICAL change to the `player_b` `fullname:` block (lines 136-143), with `@gps[1]` instead of `@gps[0]`. Place the German inline comment in BOTH blocks (alternative: place it once above player_a and reference "siehe oben" in player_b — executor's call; verbatim duplication is fine).
    4. Match indentation of the surrounding lines exactly (the file's existing `if`/`elsif`/`else` columns at lines 105-112 / 136-143 are the reference).
    5. Re-run: `bin/rails test test/models/table_monitor/options_presenter_test.rb` — all 5 new tests + 11+ pre-existing tests must PASS.
    6. Run `bundle exec standardrb app/models/table_monitor/options_presenter.rb test/models/table_monitor/options_presenter_test.rb` — accept any non-semantic autocorrects. If standardrb forces a structural rewrite of the if/elsif/else (unlikely), preserve the 4-arm semantic and don't merge any arms.
  </action>
  <verify>
    <automated>cd "$(git rev-parse --show-toplevel)" && bin/rails test test/models/table_monitor/options_presenter_test.rb 2>&1 | tail -20 && bundle exec standardrb app/models/table_monitor/options_presenter.rb test/models/table_monitor/options_presenter_test.rb 2>&1 | tail -10</automated>
  </verify>
  <done>
    All 5 new tests + 11+ pre-existing tests in options_presenter_test.rb pass. standardrb reports zero offenses (or only auto-corrected non-semantic ones). The new `elsif Carambus.config.training_mode_show_fullname` arm appears in BOTH player_a and player_b fullname blocks. The German inline comment is present.
  </done>
</task>

<task type="auto">
  <name>Task 3: Document default in carambus.yml.erb + sync carambus.yml</name>
  <files>config/carambus.yml.erb, config/carambus.yml</files>
  <action>
    1. Open config/carambus.yml.erb. In the `default:` block (starts line 2), add a new key BEFORE the `quick_game_presets:` line (around line 19, after `club_id: nil`):
       ```yaml
         # Wenn true, zeigt der Scoreboard im Training-Mode (kein tournament_monitor)
         # für registrierte Nicht-Team-Nicht-Gast-Spieler den vollständigen Namen
         # statt der disambiguierten Kurzform. Default false → unverändertes Verhalten.
         # Aktivieren z. B. bei BCW-Grand-Prix mit gemischtem Gast/Mitglieder-Feld
         # via per-scenario carambus.yml(.erb) override.
         training_mode_show_fullname: false
       ```
    2. Open config/carambus.yml. Apply the IDENTICAL `default:` block addition with the same key and value (`training_mode_show_fullname: false`). Do NOT add the key to development/production blocks here — those will inherit from default unless explicitly overridden.
    3. Verify the YAML still parses: `cd $(git rev-parse --show-toplevel) && ruby -ryaml -e "puts YAML.load_file('config/carambus.yml').dig('default', 'training_mode_show_fullname').inspect"` — expected output: `false`.
    4. Verify the .erb still renders to valid YAML in dev: `cd $(git rev-parse --show-toplevel) && bin/rails runner "puts Carambus.config.training_mode_show_fullname.inspect"` — expected output: `false` (or `nil` if Rails reads carambus.yml without the key — that's fine, but `false` is preferred for explicitness).
    5. Re-run the test suite to confirm no regression: `bin/rails test test/models/table_monitor/options_presenter_test.rb` — all tests must still PASS.
  </action>
  <verify>
    <automated>cd "$(git rev-parse --show-toplevel)" && ruby -ryaml -e "v = YAML.load_file('config/carambus.yml').dig('default', 'training_mode_show_fullname'); puts v.inspect; exit (v == false ? 0 : 1)" && grep -c "training_mode_show_fullname: false" config/carambus.yml.erb && bin/rails test test/models/table_monitor/options_presenter_test.rb 2>&1 | tail -10</automated>
  </verify>
  <done>
    Both `config/carambus.yml.erb` (default: block, before `quick_game_presets:`) and `config/carambus.yml` (default: block) contain `training_mode_show_fullname: false`. YAML parses cleanly. Rails runner returns `false` for `Carambus.config.training_mode_show_fullname` in dev. All 16+ options_presenter tests still pass. The verify command above exits 0 only if YAML key is present and equals `false`, the .erb has the key, and tests pass.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| operator → Carambus.config | Trusted (only operators with file-system + deploy access edit carambus.yml). No remote write surface. |
| Carambus.config → presenter render | Internal — boolean read at request time. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-260501-01 | I (Information disclosure) | options_presenter.rb fullname branch | accept | Flag deliberately exposes fullname. Tournament arm + guest arm already exposed it; new arm extends the same disclosure model to registered training-mode players when explicitly enabled. Operator-controlled. |
| T-260501-02 | T (Tampering) | Carambus.config OpenStruct in tests | mitigate | Test helper `with_config` uses `ensure` block to restore original Carambus.config — prevents test-state leakage between tests in the suite. Pinned by Task 1's helper design. |
| T-260501-03 | E (Elevation of privilege) | scenario-management cross-checkout edits | mitigate | Pre-edit precondition check (scenario-management SKILL) MUST run before any file edit. Task descriptions explicitly call this out. Default Workflow is Normal Mode → carambus_master only; Debugging Mode is opt-in. |
</threat_model>

<verification>
After all 3 tasks pass:

1. `bin/rails test test/models/table_monitor/options_presenter_test.rb` → 16+ tests, 0 failures, 0 errors.
2. `grep -n "training_mode_show_fullname" app/models/table_monitor/options_presenter.rb` → exactly 2 matches (one per fullname block).
3. `grep -n "training_mode_show_fullname" config/carambus.yml.erb config/carambus.yml` → at least 2 matches (one per file in default: block).
4. `grep -c "is_a?(Team)" app/models/table_monitor/options_presenter.rb` → 2 (UNCHANGED — Team arm preserved).
5. `grep -c "guest?" app/models/table_monitor/options_presenter.rb` → 2 (UNCHANGED — guest arm preserved; the count of `&.guest?` calls in the fullname blocks specifically; if the file has additional guest-related code elsewhere, pin via line-anchored grep).
6. Manual smoke (deferred — operator runs in BCW dev): boot rails server, visit a training-mode TableMonitor page with a registered non-team non-guest player, confirm name still truncates with default config. Then set flag true in dev's carambus.yml, restart Rails (config is memoized), reload page — confirm fullname now displays.
</verification>

<success_criteria>
- Test B (RED→GREEN demonstrating flag=true triggers fullname) is GREEN after Task 2.
- Tests A, C, D, E (regression guards for false-default + guest path + tournament path) are all GREEN.
- All 11+ pre-existing options_presenter tests still pass.
- `Carambus.config.training_mode_show_fullname` returns `false` by default after Task 3.
- BCW operator can flip the flag to `true` in `carambus_bcw/config/carambus.yml.erb` + `carambus_bcw/config/carambus.yml` and restart Rails to enable fullnames for the Grand Prix — no further code changes needed.
- standardrb: zero offenses on changed files.
- The change is a single `elsif` on the existing predicate ladder in BOTH player_a and player_b blocks. No new class/module/helper introduced (extend-before-build SKILL satisfied).
- View partials (`_scoreboard.html.erb`, `_warmup.html.erb`, `_shootout.html.erb`) are NOT modified — they read `options[:fullname]` which is now flag-aware via the presenter.
- `git diff --stat` should show: 4 files changed (1 model, 1 test, 2 config), <80 LOC added.
</success_criteria>

<output>
After completion, create `.planning/quick/260501-pud-add-training-mode-show-fullname-config-f/260501-pud-SUMMARY.md` capturing:
- The exact LOC count of the change.
- The standardrb output (clean / autocorrected / offenses).
- The test-suite output (pass count).
- A note for the BCW operator: paths to edit (`config/carambus.yml.erb` AND `config/carambus.yml`) to set `training_mode_show_fullname: true` in BCW's `production:` block (NOT default), and that Rails must be restarted for the config to reload (memoized at boot).
- Confirmation that scenario-management precondition check ran before edits + which checkout received them (carambus_master in Normal Mode, carambus_bcw in Debugging Mode).
</output>
