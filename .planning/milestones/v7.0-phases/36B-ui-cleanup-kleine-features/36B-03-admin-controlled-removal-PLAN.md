---
phase: 36B
plan: 03
type: execute
wave: 2
depends_on: ["36B-02"]
files_modified:
  - app/views/tournaments/tournament_monitor.html.erb
  - app/reflexes/tournament_reflex.rb
  - app/models/tournament.rb
  - test/models/tournament_test.rb
autonomous: true
requirements: [UI-03]
tags: [ui, reflex, model, test, gate, cleanup]

must_haves:
  truths:
    - "The admin_controlled checkbox no longer renders on the tournament monitor parameter form"
    - "TournamentReflex no longer defines an admin_controlled handler"
    - "Tournament#player_controlled? (the gate method) unconditionally returns true regardless of the admin_controlled column value"
    - "The admin_controlled column still exists in the schema (no migration was run)"
    - "A minimum Minitest unit test asserts that player_controlled? ignores admin_controlled"
  artifacts:
    - path: "app/views/tournaments/tournament_monitor.html.erb"
      provides: "tournament_monitor parameter form without the admin_controlled checkbox row"
    - path: "app/reflexes/tournament_reflex.rb"
      provides: "TournamentReflex with ATTRIBUTE_METHODS no longer containing admin_controlled"
    - path: "app/models/tournament.rb"
      provides: "Tournament#player_controlled? always-true gate"
    - path: "test/models/tournament_test.rb"
      provides: "Test coverage for the new player_controlled? semantics"
  key_links:
    - from: "app/reflexes/tournament_reflex.rb"
      to: "ATTRIBUTE_METHODS hash"
      via: "admin_controlled key removed"
      pattern: "admin_controlled"
    - from: "app/models/tournament.rb player_controlled?"
      to: "unconditional true"
      via: "method body no longer reads admin_controlled?"
      pattern: "def player_controlled"
---

<objective>
Implement UI-03: remove the manual round-change control feature from the UI and simplify the load-bearing gate in `tournament.rb`.

**What this plan changes (D-09, D-10):**
1. Remove the `admin_controlled` checkbox row from `tournament_monitor.html.erb` (the row added with i18n label in plan 02 — note that plan 02 does NOT wrap this row in a tooltip, so there is no tooltip wrapper to remove).
2. Remove the `admin_controlled` entry from `TournamentReflex::ATTRIBUTE_METHODS` (no more live update handler).
3. Change `Tournament#player_controlled?` (at `app/models/tournament.rb` ~line 381-384) so it unconditionally returns `true` — auto-advance always happens.
4. Add a Minitest unit test asserting the new semantics using an existing fixture (`tournaments(:local)`).

**What this plan explicitly does NOT change (D-11, D-12):**
- The `admin_controlled` column stays in the schema (no migration, no `remove_column`).
- The `admin_controlled` key stays in the attribute-delegation block at `tournament.rb:239-268` (used by TournamentLocal delegation). It is still read from global records.
- The `admin_controlled` key stays in the data-persistence block at `tournament.rb:319-329`.
- Fixtures that set `admin_controlled: true/false` stay untouched.
- The `tournaments.monitor_form.labels.admin_controlled` and `tournaments.monitor_form.tooltips.admin_controlled` i18n keys stay in the YAML files (they were added by plan 02 and removing them would cause YAML churn for no benefit; they become unused keys, which is fine).

**Tooltip count bookkeeping:** plan 02 produces exactly **16** tooltip triggers on `tournament_monitor.html.erb` (all 17 labels wrapped except `admin_controlled`). Plan 03 Task 1 deletes the entire `admin_controlled` row, which had NO tooltip wrapper, so the post-plan-03 tooltip count stays at **16** (not 15 — the row didn't carry one).

**Wave-2 rationale:** this plan depends on plan 02 (wave 1) because both edit `tournament_monitor.html.erb` and plan 02's i18n conversion must land before plan 03 removes the row.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md
@.planning/REQUIREMENTS.md
@app/models/tournament.rb
@app/reflexes/tournament_reflex.rb
@app/views/tournaments/tournament_monitor.html.erb
@test/models/tournament_test.rb
@test/fixtures/tournaments.yml

<interfaces>
<!-- Current state of the load-bearing gate (from Tournament model) -->
<!-- Line numbers are from the file AT PLANNING TIME — re-verify with grep -->

def player_controlled?
  # players can advance from Game-Finished-OK without admin or referee interaction?
  !admin_controlled?
end

<!-- CALLERS of player_controlled? (known) -->
app/views/tournament_monitors/_current_games.html.erb:133,135
  uses tm.player_controlled? to decide whether to show "OK?" or the
  I18n.t('table_monitor.status.wait_check') fallback. This branch stays
  functional — after the change, player_controlled? is always true, so
  the "OK?" path is always taken. That's the intended auto-advance UX.

<!-- TournamentReflex::ATTRIBUTE_METHODS hash (app/reflexes/tournament_reflex.rb:30-48) -->
ATTRIBUTE_METHODS = {
  innings_goal: "I",
  timeouts: "I",
  balls_goal: "I",
  timeout: "I",
  admin_controlled: "B",   # <-- remove this line
  auto_upload_to_cc: "B",
  continuous_placements: "B",
  gd_has_prio: "B",
  kickoff_switches_with: "S",
  allow_follow_up: "B",
  allow_overflow: "B",
  color_remains_with_set: "B",
  fixed_display_left: "K",
  sets_to_play: "I",
  sets_to_win: "I",
  time_out_warm_up_first_min: "I",
  time_out_warm_up_follow_up_min: "I"
}

<!-- Existing tournaments fixture (test/fixtures/tournaments.yml) -->
tournaments(:local) — id: 50_000_001, title: "Local Test Tournament",
  organizer: nbv (Region), discipline: carom_3band, state: "registration"
  (No admin_controlled value set → defaults to nil/false from schema default)
</interfaces>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Remove admin_controlled checkbox row from tournament_monitor.html.erb and reflex handler from tournament_reflex.rb</name>
  <files>
    app/views/tournaments/tournament_monitor.html.erb
    app/reflexes/tournament_reflex.rb
  </files>
  <read_first>
    - app/views/tournaments/tournament_monitor.html.erb (full file — find the row that contains `check_box_tag :admin_controlled`)
    - app/reflexes/tournament_reflex.rb lines 30-48 (ATTRIBUTE_METHODS hash — the define_method loop at lines 50-72 auto-generates the handler from this hash)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-09
  </read_first>
  <action>
**A — `app/views/tournaments/tournament_monitor.html.erb`:** Delete the entire parameter row that contains the admin_controlled checkbox. The row is a full `<div class="flex flex-row space-x-4 items-center">...</div>` block. Locate it by greping for `check_box_tag :admin_controlled` and delete the enclosing `<div class="flex flex-row space-x-4 items-center">` wrapper, everything inside, and the closing `</div>`.

After plan 02 (which does NOT wrap admin_controlled in a tooltip), the row looks like:
```erb
<div class="flex flex-row space-x-4 items-center">
  <span class="w-1/2 text-right text-sm"><%= label_tag t('tournaments.monitor_form.labels.admin_controlled') %></span>
  <span id="tournament_admin_controlled"><%= check_box_tag :admin_controlled, "1", @tournament.admin_controlled?, class: "border-2", data: { reflex: "change->TournamentReflex#admin_controlled", id: @tournament.id } %></span>
</div>
```

Delete this whole block. Do not touch any other parameter row.

**B — `app/reflexes/tournament_reflex.rb`:** Remove the `admin_controlled: "B",` line from `ATTRIBUTE_METHODS` (currently line ~35). Do NOT touch the `define_method` loop at lines ~50-72 — it iterates over the hash, so removing the key automatically removes the handler.

The resulting hash must still have all other 16 keys intact:
- innings_goal, timeouts, balls_goal, timeout, auto_upload_to_cc, continuous_placements, gd_has_prio, kickoff_switches_with, allow_follow_up, allow_overflow, color_remains_with_set, fixed_display_left, sets_to_play, sets_to_win, time_out_warm_up_first_min, time_out_warm_up_follow_up_min

Do NOT add any compensating code (e.g., rewriting existing records). The column persists; read-only access is still supported via the delegation block at `tournament.rb:239-268`.
  </action>
  <verify>
    <automated>bundle exec erblint app/views/tournaments/tournament_monitor.html.erb && bundle exec standardrb app/reflexes/tournament_reflex.rb && ruby -c app/reflexes/tournament_reflex.rb</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "admin_controlled" app/views/tournaments/tournament_monitor.html.erb` returns `0`
    - `grep -c "check_box_tag :admin_controlled" app/views/tournaments/tournament_monitor.html.erb` returns `0`
    - `grep -c "admin_controlled:" app/reflexes/tournament_reflex.rb` returns `0` (hash key is gone)
    - `grep -c "ATTRIBUTE_METHODS" app/reflexes/tournament_reflex.rb` returns `2` (declaration + each loop)
    - `grep -c ":innings_goal" app/reflexes/tournament_reflex.rb` returns `>= 1` (hash still has other entries)
    - `grep -c ":auto_upload_to_cc" app/reflexes/tournament_reflex.rb` returns `>= 1` (other entries still present)
    - `grep -c "data-controller=\"tooltip\"" app/views/tournaments/tournament_monitor.html.erb` returns **exactly `16`** (unchanged from plan 02 — the deleted row had no tooltip wrapper)
    - `bundle exec erblint app/views/tournaments/tournament_monitor.html.erb` exits 0
    - `bundle exec standardrb app/reflexes/tournament_reflex.rb` exits 0
  </acceptance_criteria>
  <done>
    Checkbox row is gone from the view, reflex hash no longer has the admin_controlled key, every other parameter row and reflex handler still intact, lints clean. Tooltip count is still 16.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Simplify player_controlled? gate in tournament.rb to always return true</name>
  <files>
    app/models/tournament.rb
    test/models/tournament_test.rb
  </files>
  <read_first>
    - app/models/tournament.rb (re-grep `def player_controlled` to find the current line — CONTEXT.md says ~lines 382-384 but the file may have shifted; use grep, not literal line numbers)
    - app/models/tournament.rb lines 239-268 (attribute-delegation block that must remain intact — see D-11)
    - app/models/tournament.rb lines 319-329 (data-persistence block that must remain intact)
    - test/models/tournament_test.rb (existing test file — mirror its conventions, do NOT re-enable LocalProtector, do not run strong_migrations)
    - test/fixtures/tournaments.yml (confirm `:local` fixture exists — id 50_000_001, Local Test Tournament)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-10, §D-11, §D-12, §D-19
  </read_first>
  <behavior>
    Test 1: `player_controlled?` returns `true` when admin_controlled=true (previously returned `false` — the old gate was `!admin_controlled?`)
    Test 2: `player_controlled?` returns `true` when admin_controlled=false
    Test 3: `player_controlled?` returns `true` when admin_controlled=nil
    Test 4: Calling `player_controlled?` never raises.
  </behavior>
  <action>
**A — Write the test first (RED).** Add a new test block to `test/models/tournament_test.rb`:

```ruby
  test "player_controlled? always returns true regardless of admin_controlled (UI-03 D-10)" do
    # D-10: the round-advance gate becomes unconditional — auto-advance always happens.
    # Historically `player_controlled?` returned `!admin_controlled?`; the column still
    # exists on global records (D-11) but must no longer block auto-advance.
    #
    # Uses tournaments(:local) fixture (id 50_000_001) to avoid fragile Tournament.create!
    # with minimal attributes that may fail validation. The fixture already satisfies
    # all required associations (season, organizer, discipline).
    t = tournaments(:local)

    t.admin_controlled = true
    assert t.player_controlled?, "player_controlled? must ignore admin_controlled=true"

    t.admin_controlled = false
    assert t.player_controlled?, "player_controlled? must be true when admin_controlled=false"

    t.admin_controlled = nil
    assert t.player_controlled?, "player_controlled? must be true when admin_controlled=nil"
  end
```

Add this test inside the existing `class TournamentTest < ActiveSupport::TestCase` class, at the end just before `end`. Do NOT modify other existing tests.

Note: the assertion does not persist the mutation (`t.admin_controlled = X` sets the in-memory attribute only). `player_controlled?` is a pure instance method that reads the attribute; no DB round-trip is required. This avoids touching the fixture file and sidesteps LocalProtector concerns.

Run the test — it MUST fail against the current implementation (old gate returns `!admin_controlled?` which is `false` when `admin_controlled: true`).

**B — Change the implementation (GREEN).** In `app/models/tournament.rb`, find the method (use `grep -n "def player_controlled" app/models/tournament.rb` — CONTEXT.md says ~lines 381-384 but DO NOT hard-code line numbers; tolerate drift). Replace the method body. Current:

```ruby
def player_controlled?
  # players can advance from Game-Finished-OK without admin or referee interaction?
  !admin_controlled?
end
```

New:

```ruby
def player_controlled?
  # UI-03 D-10: Auto-advance ist jetzt der einheitliche Default — der Rundenwechsel
  # erfolgt immer automatisch, sobald das letzte Spiel einer Runde am Scoreboard
  # bestätigt ist. Die admin_controlled-Spalte bleibt (D-11) für Kompatibilität mit
  # globalen Records, hat aber keine funktionale Wirkung mehr.
  true
end
```

Keep the method name `player_controlled?` (with the `?`) exactly — many callers (including `app/views/tournament_monitors/_current_games.html.erb:133,135`) already rely on this name.

Do NOT touch:
- The attribute-delegation block at `tournament.rb:~239-268` — `admin_controlled` stays in the `%i[...]` symbol list.
- The `create_tournament_local(..., admin_controlled: read_attribute(:admin_controlled), ...)` at `~line 254` — the delegation still mirrors the column to TournamentLocal for schema compatibility.
- The `before_save` block at `~lines 313-331` that iterates `%w[... admin_controlled ...]` — the column still reads from `data` hash on import.

**C — Run the test again (still GREEN).** The new Minitest test must pass. Other existing tournament tests must still pass (do not break fixture-based tests).
  </action>
  <verify>
    <automated>bin/rails test test/models/tournament_test.rb -x && bundle exec standardrb app/models/tournament.rb</automated>
  </verify>
  <acceptance_criteria>
    - `grep -q "def player_controlled?" app/models/tournament.rb` exits 0 (method still exists, same name)
    - `grep -c "def player_controlled" app/models/tournament.rb` returns `1`
    - `! grep -q "!admin_controlled" app/models/tournament.rb` is true (the negation `!admin_controlled` expression no longer appears anywhere in the file — this is a looser grep than "inside player_controlled?" but is grep-verifiable)
    - `grep -c "admin_controlled" app/models/tournament.rb` returns `>= 4` (D-11: column stays in attribute-list at ~line 239, create_tournament_local at ~254, before_save at ~321, etc.)
    - `grep -c 'player_controlled\? always returns true' test/models/tournament_test.rb` returns `1`
    - `bin/rails test test/models/tournament_test.rb` exits 0 (the new test passes AND all existing tests in the file still pass — this is the semantic assertion that replaces fragile grep-based body inspection per W-2)
    - `bundle exec standardrb app/models/tournament.rb` exits 0
  </acceptance_criteria>
  <done>
    `player_controlled?` is an unconditional-true method; the `admin_controlled` column is still referenced by the delegation/persistence blocks (D-11); the new Minitest test passes using `tournaments(:local)` fixture; no other tournament tests regress.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| scoreboard → server | TableMonitorReflex triggers round-advance via player_controlled? gate |
| global records → local server | admin_controlled column read from imported tournaments |

## STRIDE Threat Register (ASVS L1)

| Threat ID | Category | Component | Disposition | Mitigation |
|-----------|----------|-----------|-------------|------------|
| T-36b03-01 | Repudiation (R) / Tampering (T) | Tournament auto-advances when operator expected manual control and is mid-way through a game | mitigate | D-10 makes auto-advance the single source of truth (gate unconditionally `true`). The user decision is explicit and unambiguous — there is no longer ANY UI input path to re-enable admin control. The Minitest unit test asserts the new semantics. Manual UAT in carambus_bcw confirms the auto-advance behavior matches operator expectation. |
| T-36b03-02 | Tampering (T) | A caller passes `admin_controlled: true` via API/Reflex and expects the old behavior | accept | After this plan, there is no Reflex handler that accepts `admin_controlled` (removed from `ATTRIBUTE_METHODS`). Direct `update_attribute(:admin_controlled, true)` calls from outside the app still write the column, but the gate ignores the value — so the old threat (a stale `admin_controlled: true` blocking auto-advance) is now impossible. |
| T-36b03-03 | Denial of service (D) | Schema drift from leaving the column behind | accept | Per D-11, leaving the column is deliberate. Global records (id < MIN_ID) may still have the column populated from external sources; removing it would break read compatibility with ExternalRecord delegation. Column drop is deferred to a post-v7.0 cleanup phase. |
| T-36b03-04 | Information disclosure (I) | Unused i18n keys `tournaments.monitor_form.labels.admin_controlled` and `tournaments.monitor_form.tooltips.admin_controlled` remain in YAML | accept | No PII, no secrets — just unused translation keys. Removing them would cause a YAML churn-conflict with plan 02; leaving them is lower risk. A future docs-cleanup pass can prune unused keys across all locales. |
</threat_model>

<verification>
1. `bundle exec erblint app/views/tournaments/tournament_monitor.html.erb` exits 0.
2. `bundle exec standardrb app/models/tournament.rb app/reflexes/tournament_reflex.rb` exits 0.
3. `bin/rails test test/models/tournament_test.rb` exits 0.
4. `git diff app/models/tournament.rb` shows ONLY the body of `player_controlled?` changing — no deletions from the attribute-delegation block, no schema changes.
5. Manual UAT (user runs in carambus_bcw, outside this plan's automation): confirm the Turnier-Monitor parameter form no longer shows the "Tournament Manager checks results" / "Rundenwechsel manuell bestätigen" checkbox; confirm the scoreboard auto-advances rounds without intervention.
</verification>

<success_criteria>
- UI-03: ✅ admin_controlled checkbox removed from UI, reflex handler removed, gate simplified to always-true, unit test asserts new semantics using `tournaments(:local)` fixture, column and attribute-list entries preserved (D-11), tooltip count on tournament_monitor.html.erb stays at 16
</success_criteria>

<output>
After completion, create `.planning/phases/36B-ui-cleanup-kleine-features/36B-03-SUMMARY.md` listing: ERB row deletion, Reflex hash key deletion, gate simplification, new Minitest test (fixture-based), and explicit non-changes (D-11 preservation).
</output>
</content>
</invoke>