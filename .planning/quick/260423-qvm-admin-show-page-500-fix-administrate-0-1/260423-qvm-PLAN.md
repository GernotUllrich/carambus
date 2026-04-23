---
phase: 260423-qvm
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - config/initializers/administrate_rails71_shim.rb
  - app/controllers/admin/training_examples_controller.rb
  - app/views/admin/training_concepts/show.html.erb
  - config/routes.rb
  - test/integration/admin_views_smoke_test.rb
autonomous: false
requirements:
  - P0-ADMIN-SHOW-500
  - P1-CONTROLLER-M2M-CLEANUP
  - P2-ADMIN-SMOKE-TESTS

must_haves:
  truths:
    - "Show /admin/training_examples/15 and /admin/training_examples/16 return HTTP 200 (down from 500) after Commit A"
    - "SVG ball-configuration partial renders on both Show pages for UAT (Gabriëls klein/exact and Conti Coup 10 match/qualitative)"
    - "Admin::TrainingExamplesController has no move_up or move_down methods after Commit B"
    - "Admin::TrainingExamplesController#destroy no longer references training_concept_id FK after Commit B"
    - "config/routes.rb has no move_up/move_down route declarations on training_examples resource after Commit B"
    - "app/views/admin/training_concepts/show.html.erb has no button_to calls to move_up_admin_training_example_path / move_down_admin_training_example_path after Commit B"
    - "No admin view under app/views/ references the removed helpers (grep gate passes empty)"
    - "/admin/training_concepts/:id Show page still renders HTTP 200 after Commit B (no regression from helper removal)"
    - "test/integration/admin_views_smoke_test.rb exists and passes (or skips) after Commit C"
    - "Full test suite remains at 0 failures / 0 errors (baseline 1282/0/0/13)"
  artifacts:
    - path: "config/initializers/administrate_rails71_shim.rb"
      provides: "public :warn shim for ActiveSupport::Deprecation under Rails 7.1+"
      contains: "public :warn"
    - path: "app/controllers/admin/training_examples_controller.rb"
      provides: "cleaned controller without obsolete move_up/move_down/training_concept_id FK logic"
    - path: "app/views/admin/training_concepts/show.html.erb"
      provides: "training_concepts Show page with move_up/move_down training_example button_to blocks removed (Sortierung column kept as placeholder or column dropped)"
    - path: "config/routes.rb"
      provides: "training_examples routes without move_up/move_down member actions"
    - path: "test/integration/admin_views_smoke_test.rb"
      provides: "Index+Show smoke coverage for the 4 actually-routed admin dashboards (training_examples, training_concepts, shots, training_sources). Adding ball_configurations and start_positions to admin namespace is deferred as backlog."
  key_links:
    - from: "Admin show.html.erb render_field(HasMany)"
      to: "public visibility on ActiveSupport::Deprecation.warn"
      via: "config/initializers/administrate_rails71_shim.rb"
      pattern: "public :warn"
    - from: "Admin TrainingExamples Index navigation"
      to: "Admin Controller destroy (redirects to Index, not ambiguous Parent Concept)"
      via: "app/controllers/admin/training_examples_controller.rb#destroy"
      pattern: "admin_training_examples_path"
    - from: "Admin TrainingConcepts Show page Sortierung column"
      to: "Removal of references to move_up_admin_training_example_path / move_down_admin_training_example_path"
      via: "app/views/admin/training_concepts/show.html.erb"
      pattern: "grep returns empty for move_(up|down)_admin_training_example"
---

<objective>
Repair the Carambus Admin views for TrainingExample so Gernot can visually validate
the v0.9 ontology examples (#15 Gabriëls, #16 Conti Coup 10) including the SVG
ball-configuration diagram Claudia shipped in commit 84fa6578.

Three layered fixes, executed as three separate git commits on
`feature/training-system` (already checked out, NO worktree isolation).

Commit A — P0 blocker shim: Administrate 0.19.0 calls `ActiveSupport::Deprecation.warn`
as a public class method, but Rails 7.1+ made `Kernel#warn` private on the class
singleton. Every Admin Show page that renders a `Field::HasMany` / `:through`
association currently 500s with "private method `warn' called for
ActiveSupport::Deprecation:Class". An initializer restores public visibility so
Admin Show pages render again. Longer-term gem upgrade/replacement is deferred
and tracked as backlog.

Commit B — P1 controller & view cleanup: v0.9 Phase D removed the 1:N
`training_concept_id` FK on TrainingExample (now M2M via TrainingConceptExample
with weight + sequence_number on the join). `destroy`, `move_up`, `move_down`,
and the `resource_params` tag_list handling in
`app/controllers/admin/training_examples_controller.rb` still reference the
obsolete world. The helper calls `move_up_admin_training_example_path` /
`move_down_admin_training_example_path` live in
`app/views/admin/training_concepts/show.html.erb` (lines 117 and 128, NOT in
training_examples/show.html.erb — verified via grep) — these must be removed
in the same commit that drops the routes, otherwise the training_concepts
Show page regresses to 500. Interactive per-concept sorting is deferred
(backlog item).

Commit C — P2 safety net: add a Minitest integration smoke test at
`test/integration/admin_views_smoke_test.rb` covering Index + Show for the
FOUR admin dashboards actually mounted under `namespace :admin` in
config/routes.rb: training_examples, training_concepts, shots,
training_sources. `ball_configurations` and `start_positions` are NOT
currently routed under /admin (no namespace entry in routes.rb; no
ball_configuration_dashboard.rb file exists — only start_position_dashboard.rb
exists as an orphan). Adding them is deferred and recorded as backlog in the
SUMMARY. Tests guard with `skip` when no records exist in fixtures — we do
NOT create new fixtures here (seed-only records like #15 / #16 are not in
test fixtures).

Between Commit A and Commit B there is a human verification checkpoint:
Gernot opens both Show pages in the browser at http://localhost:3008 and
confirms (a) HTTP 200, (b) SVG diagram renders with three balls on a table
with diamonds. If visual ball positions look wrong, that feedback goes to
Claudia (seed coordinates), NOT Paul (out of scope here).

Purpose: Unblock ontology-validation UAT; stop silent admin regressions via
smoke coverage; remove v0.9 Phase D residues from controllers.

Output: 3 commits on feature/training-system (not pushed), green smoke tests,
Gernot visual confirmation of Show pages.
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/CLAUDE.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/.paul/HANDOFF-2026-04-23-admin-views-review.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/.paul/STATE.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/app/controllers/admin/training_examples_controller.rb
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/app/dashboards/training_example_dashboard.rb
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/app/views/admin/training_examples/show.html.erb
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/app/views/admin/training_concepts/show.html.erb
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/app/views/admin/shared/_ball_configuration_diagram.html.erb
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/app/models/training_example.rb
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_gu/app/models/concerns/taggable.rb

<facts>
Working copy & runtime:
- Branch: feature/training-system (no worktree — execute here directly)
- Dev server: http://localhost:3008 (from main working copy, already running)
- Test baseline: 1282 runs / 0 failures / 0 errors / 13 skips
- Ruby 3.2.1, Rails 7.2.0.beta2, Administrate 0.19.0, PostgreSQL
- DO NOT PUSH. User decides push separately.
- DO NOT update .paul/STATE.md or .planning/STATE.md in commits — orchestrator handles state.

Routes today (config/routes.rb, verified by Read at plan-revision time):
- Lines 478-490: Nested `resources :training_examples, shallow: true do` inside `resources :training_concepts do` block. The example-level `member do / patch :move_up / patch :move_down / end` spans lines 479-482. Inside that (lines 483-488) a `resources :shots, shallow: true do` block contains its OWN `member do / patch :move_up / patch :move_down / end` — SHOTS MOVE ACTIONS STAY (they are out of scope for this cleanup).
- Lines 493-498: Standalone `resources :training_examples, only: [:index] do / member do / patch :move_up / patch :move_down / end / end`.
- Lines 500-505: `resources :shots, only: [:index] do member do patch :move_up; patch :move_down end end` — STAYS (Admin::ShotsController handles this; out of scope).

Admin namespace (dashboards actually routed under `namespace :admin` at time of this revision):
- translations (index only, line 17)
- incomplete_records (line 19)
- users (line 418)
- settings (line 419)
- scoreboard_messages (line 429)
- stream_configurations (line 435)
- player_duplicates (line 447)
- international_sources (line 457)
- videos (line 458)
- pages (line 460)
- training_concepts (line 474)
- training_examples (nested on line 478 + standalone on line 493)
- shots (nested on line 483 + standalone on line 500)
- training_sources (line 507)
- tags (line 513)

NOT routed under /admin (checker blocker #2, verified):
- ball_configurations — NO entry in config/routes.rb under namespace :admin; NO file app/dashboards/ball_configuration_dashboard.rb
- start_positions — NO entry in config/routes.rb under namespace :admin (app/dashboards/start_position_dashboard.rb DOES exist but is orphaned)

Dashboards present on disk (app/dashboards/*.rb, verified):
- discipline, incomplete_record, international_source, page, player_duplicate, scoreboard_message, setting, shot, start_position, stream_configuration, tag, training_concept, training_example, training_source, user, video.
  (No ball_configuration_dashboard.rb.)

Smoke-test scope (reduced per checker blocker #2):
- training_examples, training_concepts, shots, training_sources.
- Deferred (SUMMARY backlog note): ball_configurations + start_positions need either a routes.rb entry + missing dashboard, or explicit removal from the v0.9 UI plan.

Controller today (app/controllers/admin/training_examples_controller.rb):
- Line 3: `before_action :set_training_concept, only: [:new, :create]` — STAYS
- Line 15-21: `valid_action?` — REMOVE `move_up`/`move_down` branch (line 19)
- Line 19: `return true if %w[move_up move_down].include?(name.to_s)` — REMOVE
- Line 61-73: `destroy` — rewrite: no training_concept_id lookup, redirect to `admin_training_examples_path`
- Line 75-94: `move_up` — REMOVE ENTIRELY
- Line 96-115: `move_down` — REMOVE ENTIRELY
- Line 119-121: `set_training_concept` — STAYS (nested-route correct for new/create)
- Line 123-129: `scoped_resource` — STAYS (uses `:through` which still works)
- Line 131-138: `resource_params` — `tag_list` line STAYS (Taggable IS included, see below)

TrainingExample Taggable check (verified via reading source):
- app/models/training_example.rb line 3: `include Taggable`
- app/models/concerns/taggable.rb lines 23-32: defines `tag_list=` and `tag_list`
- Conclusion: `resource_params` line 136 (`whitelisted[:tag_list] = params[resource_name][:tag_list] if params[resource_name][:tag_list]`) is still correct; LEAVE IT. Document finding in commit message for Commit B.

training_examples Show page today (app/views/admin/training_examples/show.html.erb) — VERIFIED via grep at plan-revision:
- Does NOT reference `move_up_admin_training_example_path` or `move_down_admin_training_example_path`.
- The Sortierung column in this file (around lines 135-158 pre-revision plan text) targets `move_up_admin_shot_path` / `move_down_admin_shot_path` — those are SHOT paths, STAY.
- DECISION: LEAVE training_examples/show.html.erb UNMODIFIED by this plan.

training_concepts Show page today (app/views/admin/training_concepts/show.html.erb) — VERIFIED via grep at plan-revision:
- Line 117: `move_up_admin_training_example_path(example),` inside a `button_to(…)` block spanning lines 115-123 (inside `<% if index > 0 %>`).
- Line 128: `move_down_admin_training_example_path(example),` inside a `button_to(…)` block spanning lines 126-134 (inside `<% if index < examples.size - 1 %>`).
- Both button_to blocks sit inside the single `<td>` (Sortierung column) that spans lines 113-136.
- The surrounding table is rendered only `<% if page.resource.training_examples.any? %>` (line 71).
- Since the routes removal in Commit B would cause this Show page to 500 on render, these button_to calls MUST be removed in the SAME commit.

Grep gate (MUST return EMPTY after edit, before Commit B is finalized):
- `grep -rn "move_up_admin_training_example\|move_down_admin_training_example" app/views/ app/helpers/`

Fixtures available in test/fixtures/ (verified):
- clubs.yml, players.yml, regions.yml, tournaments.yml, …
- training_sources.yml (EXISTS)
- NO fixtures for: training_examples, training_concepts, shots, ball_configurations, start_positions, taggings, tags
- Conclusion: Smoke test must use `Model.order(:id).first` with `skip "no fixture/seed record available"` guard for Show tests on entities without fixtures.

Seed records present in dev DB (NOT in test DB):
- TrainingExample #15 (Gabriëls), #16 (Conti Coup 10)
- Conti Coup 10 has 3 ShotEvents, 2 BallConfigurations
- These are dev-DB only; do not assume they exist in test DB.
</facts>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Commit A — Administrate Rails 7.1+ deprecator shim</name>
  <files>config/initializers/administrate_rails71_shim.rb</files>
  <action>
Create NEW file `config/initializers/administrate_rails71_shim.rb` with the following content:

```ruby
# frozen_string_literal: true

# Administrate 0.19.0 × Rails 7.1+ Kompatibilitäts-Shim
#
# Problem:
#   Rails 7.1 hat Kernel#warn auf Klassen-Ebene als private markiert.
#   ActiveSupport::Deprecation erbt von Kernel, daher ist
#   `ActiveSupport::Deprecation.warn(...)` als Klassenmethodenaufruf
#   unter Rails 7.1+ privat und wirft NoMethodError.
#
# Betroffen:
#   Administrate 0.19.0 ruft in `app/views/fields/has_many/_show.html.erb`
#   (Zeile 21) direkt `ActiveSupport::Deprecation.warn(...)` auf. Damit
#   crasht jede Admin-Show-Seite, die ein Field::HasMany / HasOne /
#   BelongsTo rendert, mit 500.
#
# Fix (kurzfristig):
#   Sichtbarkeit der `warn`-Klassenmethode auf ActiveSupport::Deprecation
#   wieder public machen. Das wiederholt exakt das Rails-6-/7.0-Verhalten,
#   ohne die Deprecation-Semantik zu ändern (die Meldung landet weiterhin
#   im Standard-Deprecator).
#
# Langfrist-Strategie (deferred, Backlog):
#   - Administrate auf eine Release updaten, die Rails 7.1+ unterstützt
#     (Entscheidung auf Carambus-API-Scope-Ebene, siehe Handoff
#     `.paul/HANDOFF-2026-04-23-admin-views-review.md` P0).
#   - Alternativ: Administrate durch Avo / ActiveAdmin ersetzen oder
#     dedizierte Admin-Views schreiben (z.B. SVG-Partial-Pattern wie
#     `admin/shared/_ball_configuration_diagram.html.erb`).
#
# Dieser Shim ist bewusst klein und rein additiv — er entfernt nichts,
# ändert keine Deprecation-Messages und kann nach einem Administrate-
# Upgrade entfernt werden (mit einem ordentlichen Grep nach dem Namen
# dieses Files).

Rails.application.config.after_initialize do
  # Gate: nur aktiv, wenn die Methode existiert UND derzeit privat ist.
  # So wird der Shim bei zukünftigen Rails- oder Administrate-Versionen
  # automatisch zum No-Op, statt falschen Zustand zu konservieren.
  if defined?(ActiveSupport::Deprecation) &&
     ActiveSupport::Deprecation.respond_to?(:warn, true) &&
     !ActiveSupport::Deprecation.respond_to?(:warn, false)
    class << ActiveSupport::Deprecation
      public :warn
    end
  end
end
```

Notes:
- File MUST start with `# frozen_string_literal: true` per CLAUDE.md conventions.
- The gate (respond_to? check with include_private true then false) ensures the shim becomes a no-op when Rails/Administrate fix this upstream.
- Use `after_initialize` so the shim runs after ActiveSupport::Deprecation class is fully loaded.
- DO NOT monkey-patch `Administrate::Field::HasMany` directly — the root cause is visibility on ActiveSupport::Deprecation, and fixing it there also protects any other code path that calls the same method.

After writing the file:
1. Run `git add config/initializers/administrate_rails71_shim.rb`
2. Commit with message (use heredoc):
   ```
   fix(admin): shim ActiveSupport::Deprecation.warn for Administrate 0.19 on Rails 7.1+

   Rails 7.1 made Kernel#warn private at class-level. Administrate 0.19.0
   calls `ActiveSupport::Deprecation.warn(...)` as a public class method
   (see its `app/views/fields/has_many/_show.html.erb`), which now crashes
   with "private method `warn' called for ActiveSupport::Deprecation:Class"
   — every Admin Show page that renders a HasMany / HasOne / BelongsTo
   field returned HTTP 500.

   Shim restores public visibility on ActiveSupport::Deprecation.warn
   (class-level), guarded by respond_to?(:warn, true/false) so it becomes
   a no-op once Rails or Administrate resolves this upstream.

   Longer-term strategy (Administrate gem upgrade / replacement / dedicated
   admin views) is tracked as backlog in
   .paul/HANDOFF-2026-04-23-admin-views-review.md (P0 options A/B/C/D).

   Unblocks ontology UAT on /admin/training_examples/15 (Gabriëls) and
   /admin/training_examples/16 (Conti Coup 10).
   ```
3. After commit, verify dev-server response:
   - `curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3008/admin/training_examples/15` → expect 200 (or 302 if redirected to login; in that case follow up with authenticated session outside the plan).
   - `curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3008/admin/training_examples/16` → expect 200 (or 302).
   - NOTE: Dev server must be running. Rails picks up initializer changes only on restart — restart the server (`bin/rails server -p 3008` or via foreman) BEFORE curl.
  </action>
  <verify>
    <automated>grep -q "public :warn" config/initializers/administrate_rails71_shim.rb &amp;&amp; grep -q "frozen_string_literal" config/initializers/administrate_rails71_shim.rb &amp;&amp; bin/rails runner 'Rails.application.config.after_initialize {}; raise "shim missing" unless File.read("config/initializers/administrate_rails71_shim.rb").include?("public :warn"); puts "PASS"' 2>&amp;1 | tail -1 | grep -q PASS &amp;&amp; git log -1 --pretty=format:'%s' | grep -q "shim ActiveSupport::Deprecation.warn"</automated>
  </verify>
  <done>
- File `config/initializers/administrate_rails71_shim.rb` exists, starts with `# frozen_string_literal: true`, contains `public :warn` inside a `class << ActiveSupport::Deprecation` block, and the block is gated by a respond_to check.
- Git log shows a commit with subject starting "fix(admin): shim ActiveSupport::Deprecation.warn".
- After dev server restart, Admin Show pages no longer 500 on the deprecation visibility path (verified in Task 2 by Gernot).
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: Checkpoint — Gernot öffnet Show-Pages, prüft SVG-Diagramm visuell</name>
  <what-built>
After Commit A (initializer shim), the Admin Show pages for TrainingExample should render instead of returning 500.

The Show page for each example displays:
- Administrate's standard attribute list (id, title, parent/children, tags, start_position, shots, …)
- The custom SVG ball-configuration section from Claudia's commit 84fa6578, rendering:
  - The start-position BallConfiguration (three balls on a carom table with diamond markers)
  - One SVG per shot showing the end BallConfiguration after that shot
- The shots table (the Sortierung column on shots remains — that's shot-level sort, separate from the training_example-level move_up/down being removed in Commit B).

Expected visual content:
- Example #15 (Gabriëls): table_variant="klein" (210×105 cm), position_type=exact. SVG shows B1 (white), B2 (yellow), B3 (red) at Gretillat-derived coordinates.
- Example #16 (Conti Coup 10): table_variant="match" (284×142 cm), position_type=qualitative. SVG shows balls at qualitative positions + 3 shot-end diagrams.
  </what-built>
  <how-to-verify>
Prerequisite: dev server must be running and must have been restarted after Commit A so the initializer loads.

1. Restart dev server if not already restarted after Commit A:
   - `foreman start -f Procfile.dev` (full stack) OR
   - `bin/rails server -p 3008` (Rails-only)

2. Open http://localhost:3008/admin/training_examples/15 in browser (logged in as admin).
   - Must return HTTP 200, NOT 500.
   - Page must render Administrate's standard Show layout.
   - Scroll to the "🎱 Ball-Konfigurationen" section: expect at least one SVG showing a table with three balls (B1 white, B2 yellow, B3 red), diamond markers on the banden, and a caption line showing `Tisch: klein` and `Position-Typ: exact`.
   - Shot-end diagrams: expect one SVG per shot (Gabriëls has multiple shots).

3. Open http://localhost:3008/admin/training_examples/16 in browser.
   - Must return HTTP 200.
   - Expect the "🎱 Ball-Konfigurationen" section with start-position SVG (`Tisch: match`, `Position-Typ: qualitative`) plus 3 shot-end SVGs (Shot #1, #2, #3).

4. If HTTP 500 or missing SVG:
   - Check dev server log (`log/development.log`) for the failing stacktrace.
   - If still the old `private method 'warn'` error: initializer was not loaded → confirm server was restarted and the file is at `config/initializers/administrate_rails71_shim.rb`.
   - If a different error surfaces (e.g., another HasMany field crashes): report back — might be another Administrate-0.19 × Rails-7.1+ path not covered by the warn shim.

5. Visual plausibility check (UAT):
   - Are ball positions inside the table rectangle, not outside?
   - For Gabriëls: does the starting position look like a typical Gretillat opener? (If visually wrong but technically rendering: that's Claudia's seed-coordinate refinement, NOT Paul scope — mention in resume signal but do not block.)
   - For Conti Coup 10: similar check. Qualitative positions are coarser than exact; plausibility, not pixel-accuracy.
  </how-to-verify>
  <resume-signal>
Type "approved" to continue to Commits B and C.

Alternatively describe what you saw:
- "approved, but Gabriëls coordinates feel off — hand off to Claudia" (continue plan, note for Claudia handoff)
- "still 500 on #15" (stop plan, debug: restart server? log excerpt? different error?)
- "renders but SVG section missing" (stop plan, likely partial-include regression)
  </resume-signal>
</task>

<task type="auto">
  <name>Task 3: Commit B — Remove move_up/move_down + M2M-aware destroy + clean up training_concepts Show helpers</name>
  <files>
app/controllers/admin/training_examples_controller.rb
config/routes.rb
app/views/admin/training_concepts/show.html.erb
  </files>
  <action>
**Step 0 — Re-verify line numbers before editing** (plan was authored against a specific snapshot; defensive re-check catches drift):

```
grep -n "patch :move_up\|patch :move_down\|resources :training_examples\|resources :shots\|resources :training_concepts" config/routes.rb
grep -n "move_up_admin_training_example\|move_down_admin_training_example" app/views/admin/training_concepts/show.html.erb
```

Expected from the routes grep (line numbers must match or be within ±2 of these; if drifted further, re-locate by structure, not blind line numbers):
- `474:    resources :training_concepts do` (start of nested block)
- `478:      resources :training_examples, shallow: true do`
- `480:          patch :move_up` and `481:          patch :move_down` (example-level, inside line 479 `member do` … 482 `end`)
- `483:        resources :shots, shallow: true do`
- `485:            patch :move_up` and `486:            patch :move_down` (shot-level inside nested block — STAYS)
- `493:    resources :training_examples, only: [:index] do` (standalone)
- `495:        patch :move_up` and `496:        patch :move_down` (standalone, inside line 494 `member do` … 497 `end`)
- `500:    resources :shots, only: [:index] do` (standalone shots — STAYS)

Expected from the view grep:
- `117:                  move_up_admin_training_example_path(example),`
- `128:                  move_down_admin_training_example_path(example),`

**Step 1 — Verify Taggable inclusion (documented finding for commit message):**
Run: `bin/rails runner 'puts TrainingExample.include?(Taggable)'`
Expected output: `true` (confirmed via reading source; documents that `resource_params` tag_list line STAYS).

**Step 2 — Edit `app/controllers/admin/training_examples_controller.rb`:**

2a. `valid_action?` method (currently lines 15-21). Remove the move_up/move_down allow-list line. Target diff:
```diff
     def valid_action?(name, resource = resource_class)
       # "new" ist nur gültig, wenn wir von einem TrainingConcept kommen
       return false if name.to_s == 'new' && params[:training_concept_id].blank?
-      # Sortier-Actions erlauben
-      return true if %w[move_up move_down].include?(name.to_s)
       super
     end
```

2b. `destroy` method (currently lines 61-73). Replace with M2M-aware version that redirects to Index:
```ruby
    def destroy
      # v0.9 Phase D: TrainingExample ↔ TrainingConcept ist jetzt M2M
      # (training_concept_examples mit weight + sequence_number). Es gibt
      # keinen eindeutigen Parent-Concept mehr, daher Redirect zum Index.
      if requested_resource.destroy
        redirect_to admin_training_examples_path,
                    notice: "Trainingsbeispiel wurde erfolgreich gelöscht."
      else
        redirect_to admin_training_example_url(requested_resource, host: request.host, port: request.port),
                    alert: "Trainingsbeispiel konnte nicht gelöscht werden: #{requested_resource.errors.full_messages.join(', ')}"
      end
    end
```

2c. Remove the entire `move_up` method (currently lines 75-94, including the blank line before/after). Target: no remaining reference to `training_concept.training_examples.order(:sequence_number)` or `update_column(:sequence_number, …)` on a TrainingExample context.

2d. Remove the entire `move_down` method (currently lines 96-115). Same criteria.

2e. Leave `set_training_concept` (lines 119-121) AS-IS — it is correct for the nested new/create route `/admin/training_concepts/:id/training_examples/new`.

2f. Leave `scoped_resource` (lines 123-129) AS-IS — uses the has_many :through which still works.

2g. Leave `resource_params` (lines 131-138) AS-IS including the tag_list tap. TrainingExample still includes `Taggable` (verified Step 1), so `tag_list=` is still a valid setter.

**Step 3 — Edit `config/routes.rb` (explicit, line-number-anchored, verbal instructions — NO diff blocks):**

Before editing, re-open the file and confirm the structural landmarks from Step 0. If line numbers drifted, translate each edit below to its structurally equivalent location (look for the nearest `resources :training_examples` token, not blind line numbers).

**Step 3a — Nested block inside `resources :training_concepts`:**

Delete exactly lines 479-482 of `config/routes.rb` — the four-line block:

```
      member do
        patch :move_up
        patch :move_down
      end
```

These four lines sit directly beneath `resources :training_examples, shallow: true do` on line 478 and before `resources :shots, shallow: true do` on line 483. Leave line 478 (`resources :training_examples, shallow: true do`) and line 483 onward intact. The four deletions MUST preserve the nested `resources :shots, shallow: true do … member do patch :move_up; patch :move_down; end … end` block (lines 483-488) — that block belongs to SHOTS and stays exactly as written. Re-indent nothing; surrounding braces stay balanced because the removed block is self-contained `member do … end`.

After the deletion, the `resources :training_examples, shallow: true do` block should read:

```ruby
      resources :training_examples, shallow: true do
        resources :shots, shallow: true do
          member do
            patch :move_up
            patch :move_down
          end
        end
      end
```

**Step 3b — Standalone `resources :training_examples, only: [:index]`:**

Delete exactly lines 494-497 of `config/routes.rb` — the four-line block:

```
      member do
        patch :move_up
        patch :move_down
      end
```

These four lines sit directly beneath `resources :training_examples, only: [:index] do` on line 493. After removing the member block, collapse the now-empty `do … end` on line 493/498 by replacing line 493 with the single-line form:

```ruby
    resources :training_examples, only: [:index]
```

…and deleting the dangling `end` that previously closed line 498. (In other words: turn the 6-line block on lines 493-498 into a single line `resources :training_examples, only: [:index]`.)

**Step 3c — Standalone shots block (lines 500-505) stays AS-IS.** Do not touch it. Shots move_up/down is handled by Admin::ShotsController and is out of scope.

**Step 3d — After edits, re-verify:**

```
bin/rails routes 2>&1 | grep -c "move_up_admin_training_example"
```
Expected: 0

```
bin/rails routes 2>&1 | grep -c "move_up_admin_shot"
```
Expected: ≥ 1

```
grep -c "^\s*patch :move_up\|^\s*patch :move_down" config/routes.rb
```
Expected: 4 (two for nested shots block inside training_concepts→training_examples→shots; two for standalone shots). NOT 8.

**Step 4 — Edit `app/views/admin/training_concepts/show.html.erb`:**

This is the file that the checker blocker #1 flagged — and the grep in Step 0 confirms `move_up_admin_training_example_path` is at line 117 and `move_down_admin_training_example_path` is at line 128.

The Sortierung `<td>` cell spans roughly lines 113-136. It contains two `button_to(…)` blocks — one for "↑" (up) guarded by `<% if index > 0 %>` and one for "↓" (down) guarded by `<% if index < examples.size - 1 %>`.

Choose ONE of the two strategies below. Strategy A (preferred, simpler) drops the whole Sortierung column. Strategy B keeps the column as a visual placeholder showing only the sequence_number so the table layout stays unchanged.

**Strategy A — Drop the Sortierung column entirely (preferred):**

1. Remove the `<th style="padding: 10px; text-align: center; width: 80px;">Sortierung</th>` line in the table header (around line 79).
2. Remove the entire `<td>` … `</td>` that contains both button_to blocks (from the `<td style="padding: 10px; text-align: center;">` opener to its matching `</td>` — roughly lines 113-136).

The `<tr>` now has 5 columns instead of 6. No other layout changes.

**Strategy B — Keep the column, remove only the button_to blocks:**

1. Leave the `<th>…Sortierung</th>` header untouched.
2. Inside the `<td style="padding: 10px; text-align: center;">` on roughly line 113, remove both `<% if index > 0 %> … button_to(…) … <% end %>` blocks (the ↑ and ↓ blocks, roughly lines 114-135). Replace with a simple read-only display, for example:

```erb
            <td style="padding: 10px; text-align: center; color: #bdc3c7;">
              —
            </td>
```

…or leave the cell empty (`<td></td>`), either is fine.

Either strategy MUST result in the training_concepts Show template no longer referencing the removed route helpers. Do not attempt to re-wire the buttons to a new action in this commit — per-concept re-ordering via TrainingConceptExample.sequence_number is deferred (backlog).

**Step 5 — GREP GATE (BLOCKING before commit):**

Run the cross-app grep:

```
grep -rn "move_up_admin_training_example\|move_down_admin_training_example" app/views/ app/helpers/
```

This grep MUST return EMPTY. If any hit remains, fix that file before proceeding. Do not rely on `|| true` — the exit code matters. Sample script:

```
if grep -rn "move_up_admin_training_example\|move_down_admin_training_example" app/views/ app/helpers/ > /tmp/move_helper_grep.txt 2>&1; then
  echo "BLOCKER: stale move helper references remain:"
  cat /tmp/move_helper_grep.txt
  exit 1
else
  echo "grep gate PASS"
fi
```

**Step 6 — Sanity checks before commit:**

Run the following and ensure each returns as expected:
```
grep -n "def move_up\|def move_down" app/controllers/admin/training_examples_controller.rb
```
Expected: no match (exit 1).

```
grep -n "training_concept_id = requested_resource.training_concept_id" app/controllers/admin/training_examples_controller.rb
```
Expected: no match (exit 1).

**Step 7 — Run controller + integration tests (narrower scope; full suite is Task 4's job):**
```
RAILS_ENV=test bin/rails test test/controllers test/integration
```
Expected: 0 failures, 0 errors. Skips acceptable. If the controller/integration subset is green, proceed; the global baseline is re-asserted in Task 4.

**Step 8 — Commit:**
```
git add app/controllers/admin/training_examples_controller.rb config/routes.rb app/views/admin/training_concepts/show.html.erb
```

Commit message (heredoc):
```
fix(admin): remove obsolete move_up/move_down + M2M-aware destroy in training_examples

v0.9 Phase D (commit fd835718) replaced the 1:N TrainingExample →
TrainingConcept FK with an M2M through TrainingConceptExample (carrying
weight + sequence_number). The admin/training_examples_controller still
referenced the removed world:

- destroy looked up training_concept_id on the example and redirected
  to the former parent concept — ambiguous under M2M.
- move_up / move_down read example.sequence_number (column dropped from
  training_examples) and swapped via example.training_concept
  (association dropped).

This commit:
- Rewrites destroy to redirect to admin_training_examples_path (Index);
  per-concept context is deferred until there is a concrete UX need.
- Removes move_up and move_down methods entirely.
- Drops the move_up/move_down allow-list branch in valid_action?.
- Removes move_up/move_down route members from training_examples in
  config/routes.rb (both nested under training_concepts and standalone).
- Removes button_to calls to move_up_admin_training_example_path /
  move_down_admin_training_example_path from
  app/views/admin/training_concepts/show.html.erb (lines 117 and 128),
  which would otherwise 500 once the routes are gone. Per-concept
  re-ordering UX is deferred.
- Leaves scoped_resource, set_training_concept, and resource_params
  intact (set_training_concept is still correct for nested new/create;
  resource_params tag_list handling stays because TrainingExample
  include Taggable verified via rails runner).
- Leaves the shots move_up/move_down routes and the Sortierung column
  in training_examples/show.html.erb untouched — shots-level sorting is a
  separate concern handled by Admin::ShotsController.

Interactive per-concept re-ordering on the join (TrainingConceptExample.
sequence_number) is deferred and tracked as a backlog idea.

Paired with Commit A (Administrate warn shim) in plan
.planning/quick/260423-qvm-admin-show-page-500-fix-administrate-0-1.
```
  </action>
  <verify>
    <automated>test -z "$(grep -nE 'def move_up|def move_down' app/controllers/admin/training_examples_controller.rb)" &amp;&amp; test -z "$(grep -n 'training_concept_id = requested_resource.training_concept_id' app/controllers/admin/training_examples_controller.rb)" &amp;&amp; ! grep -rnq "move_up_admin_training_example\|move_down_admin_training_example" app/views/ app/helpers/ &amp;&amp; [ "$(bin/rails routes 2>/dev/null | grep -c 'move_up_admin_training_example')" = "0" ] &amp;&amp; [ "$(bin/rails routes 2>/dev/null | grep -c 'move_up_admin_shot')" -ge "1" ] &amp;&amp; RAILS_ENV=test bin/rails test test/controllers test/integration 2>&amp;1 | tail -5 | grep -E '0 failures' &amp;&amp; git log -1 --pretty=format:'%s' | grep -q "remove obsolete move_up/move_down"</automated>
  </verify>
  <done>
- `app/controllers/admin/training_examples_controller.rb` has no `def move_up` or `def move_down`, no reference to `training_concept_id = requested_resource.training_concept_id`, and the valid_action? no longer allow-lists move_up/move_down.
- `config/routes.rb` has no `patch :move_up` / `patch :move_down` declarations inside any training_examples resource block.
- `bin/rails routes` still emits move_up/move_down for shots (proves we didn't over-reach).
- `app/views/admin/training_concepts/show.html.erb` has no references to `move_up_admin_training_example_path` or `move_down_admin_training_example_path`.
- Cross-app grep (`grep -rn "move_up_admin_training_example\|move_down_admin_training_example" app/views/ app/helpers/`) returns empty.
- Controller + integration test subset: 0 failures, 0 errors.
- One new commit on feature/training-system with subject "fix(admin): remove obsolete move_up/move_down + M2M-aware destroy in training_examples".
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 4: Commit C — Admin views smoke tests (Index + Show)</name>
  <files>test/integration/admin_views_smoke_test.rb</files>
  <behavior>
Smoke-test spec (behaviors that must be asserted):
- GET /admin/training_examples (Index) returns success (200 or redirect-to-login in test env).
- GET /admin/training_examples/:id (Show) returns success WHEN a record exists; otherwise test is skipped with a clear message.
- Same Index+Show pattern for: training_concepts, shots, training_sources.
- The list is restricted to the FOUR admin dashboards actually mounted under `namespace :admin` in config/routes.rb. `ball_configurations` and `start_positions` are NOT currently routed under /admin and are deferred (see SUMMARY backlog).
- Tests must authenticate as an admin user (use Devise test helpers + users.yml fixture). If the first admin user cannot be derived, fall back to a skip.
- Tests must NOT create new fixtures or seed records (explicit scope boundary: seed-only records like #15/#16 are not in test DB).
- Test count: 8 (4 dashboards × 2 actions). Each test pair uses `skip` if the underlying model has zero rows in the test DB.
  </behavior>
  <action>
**Step 0 — Precondition check (Commit A shim must exist on disk):**
```
test -f config/initializers/administrate_rails71_shim.rb || { echo 'BLOCKER: Commit A shim missing — Task 1 not applied'; exit 1; }
```
If the shim file is missing, stop immediately and report — Commit A precedes this task.

**Step 1 — Inspect existing test infrastructure:**
```
cat test/test_helper.rb | head -80
ls test/fixtures/
grep -l "sign_in\|Devise::Test" test/**/*.rb 2>/dev/null | head -5
cat test/fixtures/users.yml 2>/dev/null | head -60
```
Check:
- Does `test/test_helper.rb` already include Devise's integration test helpers? If so, re-use the same include pattern.
- Is there an admin user in `test/fixtures/users.yml` (look for `admin: true` or similar role flag)? If yes, use that fixture record.
- If no admin user fixture exists, the test file must skip gracefully rather than break the baseline.

**Step 2 — Verify the DASHBOARDS list against actual routes (defensive):**
```
bin/rails routes | grep "^\s*admin_" | awk '{print $2}' | grep -oE "^/admin/[a-z_]+" | sort -u
```
This lists the actual admin endpoint stems. Confirm that `training_examples`, `training_concepts`, `shots`, and `training_sources` are all present. If any is missing, adjust the DASHBOARDS constant accordingly and note it in the commit message. `ball_configurations` and `start_positions` are EXPECTED to be absent (deferred).

**Step 3 — Create `test/integration/admin_views_smoke_test.rb`:**

```ruby
# frozen_string_literal: true

require "test_helper"

# Smoke tests for the Administrate admin dashboards most affected by the
# v0.9 ontology changes. These tests only assert "renders without 500",
# not content — they catch regressions like the Rails 7.1 × Administrate
# 0.19 Deprecation.warn visibility crash (see commit of
# config/initializers/administrate_rails71_shim.rb).
#
# Scope: the FOUR admin dashboards actually mounted under `namespace :admin`
# in config/routes.rb at the time of writing:
#   - training_examples
#   - training_concepts
#   - shots
#   - training_sources
#
# Deferred (backlog — not in this commit):
#   - ball_configurations: no routes.rb entry, no dashboard file
#   - start_positions:     no routes.rb entry (dashboard file exists, orphaned)
# Those two require either (a) adding the routes + missing dashboard, or
# (b) explicitly dropping them from the v0.9 admin UI plan.
#
# Fixtures are intentionally NOT extended for this: seed-only records
# (e.g. TrainingExample #15 / #16 in dev DB) are out of scope for the
# test suite. When a model has zero rows in the test DB, the Show test
# is skipped with a clear message. Index tests run unconditionally — an
# empty collection is a valid 200 response.
class AdminViewsSmokeTest < ActionDispatch::IntegrationTest
  # Admin dashboards covered by this smoke sweep. Each entry: the URL
  # helper stem (no "admin_" prefix, no pluralization) and the Ruby model
  # constant used for the Show lookup.
  DASHBOARDS = [
    { stem: "training_examples", model: "TrainingExample" },
    { stem: "training_concepts", model: "TrainingConcept" },
    { stem: "shots",             model: "Shot" },
    { stem: "training_sources",  model: "TrainingSource" }
  ].freeze

  setup do
    @admin_user = find_admin_user
  end

  DASHBOARDS.each do |dashboard|
    stem  = dashboard[:stem]
    model = dashboard[:model]

    define_method("test_admin_#{stem}_index_renders") do
      skip "no admin user fixture available" unless @admin_user
      sign_in_admin!(@admin_user)

      get "/admin/#{stem}"
      assert_includes [200, 302], response.status,
        "Expected 200 or 302 on /admin/#{stem}, got #{response.status}. Body head: #{response.body[0..300]}"
    end

    define_method("test_admin_#{stem}_show_renders") do
      skip "no admin user fixture available" unless @admin_user
      klass = safe_constantize(model)
      skip "model #{model} not defined" unless klass

      record = klass.order(:id).first
      skip "no #{model} record in test DB (fixtures/seed not present)" unless record

      sign_in_admin!(@admin_user)
      get "/admin/#{stem}/#{record.id}"
      assert_includes [200, 302], response.status,
        "Expected 200 or 302 on /admin/#{stem}/#{record.id}, got #{response.status}. Body head: #{response.body[0..300]}"
    end
  end

  private

  # Locate an admin user from fixtures. Tolerant: looks for common role
  # flags (`admin`, `role: admin`, `roles: ["admin"]`) and falls back to
  # the first user if none found. Returns nil if the users table is empty.
  def find_admin_user
    return nil unless defined?(User)

    admin_candidates = [
      -> { User.where(admin: true).first rescue nil },
      -> { User.where(role: "admin").first rescue nil },
      -> { User.all.find { |u| u.respond_to?(:admin?) && u.admin? } rescue nil }
    ]
    admin_candidates.each do |lookup|
      u = lookup.call
      return u if u
    end
    User.first
  rescue StandardError
    nil
  end

  # Sign in the admin via Devise integration helpers if available,
  # otherwise simulate via the session. Matches the approach used
  # elsewhere in the suite if possible.
  def sign_in_admin!(user)
    if respond_to?(:sign_in)
      sign_in user
    elsif defined?(Warden::Test::Helpers)
      login_as(user, scope: :user)
    else
      # Last-resort: set session directly. Brittle but keeps the smoke
      # test from being useless in projects without Devise helpers wired.
      post "/users/sign_in", params: { user: { email: user.email, password: "password" } }
    end
  end

  def safe_constantize(name)
    name.constantize
  rescue NameError
    nil
  end
end
```

**Step 4 — Integrate Devise test helpers if needed:**
If `test/test_helper.rb` does NOT already include Devise integration helpers, add the include (edit minimally). Typical line:
```ruby
class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
```
Place this inside the existing ActionDispatch test configuration section. If unclear, first grep the helper for existing Devise setup — if the suite already works without it, assume integration helpers are already present.

**Step 5 — Run the new test file:**
```
bin/rails test test/integration/admin_views_smoke_test.rb 2>&1 | tail -30
```
Expected: 8 runs, 0 failures, 0 errors. Skips are OK (most tests will skip because test DB is empty for training_* entities).

**Step 6 — Run full suite to confirm baseline:**
```
RAILS_ENV=test bin/rails test 2>&1 | tail -10
```
Expected: 0 failures, 0 errors. Run count will increase by 8 from baseline (1282 → ~1290). Skip count will increase by up to 8 as well.

**Step 7 — Commit:**
```
git add test/integration/admin_views_smoke_test.rb
# only add test_helper.rb if it was modified in Step 4
git add test/test_helper.rb 2>/dev/null || true
```

Commit message (heredoc):
```
test(admin): add Index+Show smoke tests for admin views

Adds test/integration/admin_views_smoke_test.rb covering GET Index and
GET Show for the four admin dashboards actually mounted under
`namespace :admin` in config/routes.rb:

- training_examples
- training_concepts
- shots
- training_sources

Goal: catch regressions like the Administrate 0.19 × Rails 7.1+
Deprecation.warn visibility crash (fixed in commit of
config/initializers/administrate_rails71_shim.rb) at CI time instead of
via manual browser UAT.

Tests are content-agnostic — they only assert the page rendered without
500 (accepting 200 or 302 to handle auth redirects). Show tests skip
when no record exists in the test DB; this is intentional because
seed-only records (e.g. TrainingExample #15/#16 in dev DB) are out of
fixture scope per Paul/Claudia scope split 2026-04-23.

Deferred (backlog):
- ball_configurations and start_positions are NOT currently routed
  under /admin (no routes.rb entry; ball_configuration_dashboard.rb
  does not exist, start_position_dashboard.rb is orphaned). Adding
  them to the admin namespace (or explicitly dropping them from the
  v0.9 admin UI plan) is out of this task's scope.
- Fixtures for training_example / training_concept / shot so Show
  tests no longer skip.
- Extend smoke sweep to Edit form views (currently Index+Show only).
```
  </action>
  <verify>
    <automated>test -f config/initializers/administrate_rails71_shim.rb &amp;&amp; test -f test/integration/admin_views_smoke_test.rb &amp;&amp; bin/rails test test/integration/admin_views_smoke_test.rb 2>&amp;1 | tail -5 | grep -E '0 failures, 0 errors' &amp;&amp; RAILS_ENV=test bin/rails test 2>&amp;1 | tail -5 | grep -E '0 failures, 0 errors' &amp;&amp; git log -1 --pretty=format:'%s' | grep -q "smoke tests for admin views"</automated>
  </verify>
  <done>
- `config/initializers/administrate_rails71_shim.rb` present (precondition from Commit A).
- `test/integration/admin_views_smoke_test.rb` exists, defines 8 test methods (4 dashboards × Index/Show).
- Running just the new file: 8 runs, 0 failures, 0 errors, skips ≥ 0 (skips OK when test DB has no rows).
- Full suite: 0 failures, 0 errors. Run count up by ~8 from 1282 baseline (target ~1290).
- New commit on feature/training-system with subject "test(admin): add Index+Show smoke tests for admin views".
- Commit message records ball_configurations + start_positions as deferred (they are not routed under /admin today).
  </done>
</task>

</tasks>

<verification>
After all tasks complete, run these cross-cutting checks:

1. Three commits on feature/training-system in correct order:
   ```
   git log --oneline -n 4
   ```
   Top three messages (most recent first):
   - `test(admin): add Index+Show smoke tests for admin views`
   - `fix(admin): remove obsolete move_up/move_down + M2M-aware destroy in training_examples`
   - `fix(admin): shim ActiveSupport::Deprecation.warn for Administrate 0.19 on Rails 7.1+`
   (The 4th should be the previous tip: `d4fda370 Ontologie v0.9 Phase E: Seeds neu`.)

2. No push occurred:
   ```
   git status -sb
   ```
   Should show `## feature/training-system` ahead of origin by 3.

3. Working tree clean:
   ```
   git status --porcelain
   ```
   Expected: empty.

4. Dev-server Show pages return 200 (manual, via Task 2 UAT already captured).

5. Full test suite green:
   ```
   RAILS_ENV=test bin/rails test 2>&1 | tail -5
   ```
   Expected: `N runs, A assertions, 0 failures, 0 errors, X skips` with N ≈ 1290.

6. No regressions in existing admin. Smoke-exercise the Show render path where move helpers used to live:
   ```
   curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3008/admin/training_concepts
   curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3008/admin/clubs
   curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3008/admin/training_concepts/$(bin/rails runner 'puts TrainingConcept.first&.id' 2>/dev/null)
   ```
   Expected: 200 or 302 for each (not 500). The third curl specifically exercises the training_concepts Show template where the move helpers were referenced before Commit B — it MUST NOT 500.

7. Cross-app grep gate (must return empty):
   ```
   grep -rn "move_up_admin_training_example\|move_down_admin_training_example" app/views/ app/helpers/
   ```
</verification>

<success_criteria>
All of the following must be true for this plan to be considered complete:

1. `config/initializers/administrate_rails71_shim.rb` exists with `public :warn` shim, gated by a respond_to check, prefixed with `# frozen_string_literal: true`. (Commit A)

2. Gernot confirms in Task 2 checkpoint that /admin/training_examples/15 and /admin/training_examples/16 both render HTTP 200 with the SVG ball-configuration partial visible. (Task 2 resume signal = "approved")

3. `app/controllers/admin/training_examples_controller.rb` contains no `move_up` or `move_down` methods, no `training_concept_id = requested_resource.training_concept_id`, and `valid_action?` no longer allow-lists move_up/move_down. `scoped_resource`, `set_training_concept`, and `resource_params` (incl. tag_list) remain. (Commit B)

4. `config/routes.rb` has no `patch :move_up` / `patch :move_down` inside any `resources :training_examples` block. Shots `patch :move_up`/`patch :move_down` remain. `bin/rails routes` confirms 0 hits for `move_up_admin_training_example`, ≥ 1 for `move_up_admin_shot`. (Commit B)

5. `app/views/admin/training_concepts/show.html.erb` contains no calls to `move_up_admin_training_example_path` or `move_down_admin_training_example_path`, and the training_concepts Show page still renders HTTP 200 (verified via curl in the cross-cutting verification step). (Commit B)

6. Cross-app grep gate (`grep -rn "move_up_admin_training_example\|move_down_admin_training_example" app/views/ app/helpers/`) returns empty. (Commit B)

7. `test/integration/admin_views_smoke_test.rb` exists with 8 test methods covering 4 dashboards × Index/Show. File runs clean: 0 failures, 0 errors. (Commit C)

8. Full test suite (`RAILS_ENV=test bin/rails test`) reports 0 failures, 0 errors. Run count increased from baseline 1282 by the 8 new tests (approximately 1290 ± 1). (Commit C)

9. Exactly 3 new commits on `feature/training-system`, not pushed. No state files (.paul/STATE.md, .planning/STATE.md) modified in any of the 3 commits.

10. No Administrate gem version change in Gemfile / Gemfile.lock (upgrade deferred per user).
</success_criteria>

<output>
After completion, create `.planning/quick/260423-qvm-admin-show-page-500-fix-administrate-0-1/260423-qvm-SUMMARY.md` with:

- SHAs of the 3 commits (Commit A shim, Commit B controller + routes + training_concepts view cleanup, Commit C smoke tests)
- Gernot's UAT signal from Task 2 checkpoint (approved / noted deviations / Claudia handoff items)
- Final test suite counts (runs / assertions / failures / errors / skips)
- Flag any observed side-effects: other admin pages now rendering that previously 500d (positive side-effect of the shim); any admin page still 500ing (would indicate a second incompat path beyond warn visibility)
- Deferred items to update on .paul/STATE.md Deferred Issues table (not committed here, orchestrator writes):
  - Administrate gem upgrade / replacement decision (P0 long-term)
  - Interactive per-concept reordering via TrainingConceptExample.sequence_number (P1 deferred)
  - Fixtures for training_examples, training_concepts, shots, training_sources so smoke Show tests stop skipping (P2 deferred)
  - **Adding `ball_configurations` and `start_positions` to the admin namespace deferred** — out of this task's scope. Either (a) add routes.rb entries + create ball_configuration_dashboard.rb (and wire up the orphan start_position_dashboard.rb), or (b) explicitly drop them from the v0.9 admin UI plan. Track as backlog on .paul/STATE.md next to the other deferred items.
- Possible follow-ups for Claudia if ball positions looked off in UAT (seed coordinate refinement)
</output>
