---
phase: 41-versions-sync-tagging
plan: 02
type: execute
wave: 1
depends_on: [1]
files_modified:
  - lib/tasks/region_taggings.rake
  - test/tasks/region_taggings_test.rb
  - test/models/version_test.rb
autonomous: true
requirements: [H1-01, H1-02, H1-03]
must_haves:
  truths:
    - "A new rake task region_taggings:fix_international_organizer_context exists in the EXISTING region_taggings namespace, defaulting to a READ-ONLY preview and mutating only when ARMED=1"
    - "In armed mode the task sets global_context=true on selected Regions via an INSTANCE-level update! (PaperTrail-tracked → new tagged version), then touches their region_id-nil tournaments/leagues AFTER (higher version id)"
    - "A second armed run is a no-op: selected Regions are empty (already global_context=true) and no tournament is re-touched (its latest version now postdates the region fix)"
    - "A redelivered (touched) tournament version applies successfully via Version.update_from_carambus_api once the Region's global_context version has been applied first"
  artifacts:
    - path: "lib/tasks/region_taggings.rake"
      provides: "fix_international_organizer_context task (DRY-RUN default + ARMED mutate)"
      contains: "task fix_international_organizer_context"
    - path: "test/tasks/region_taggings_test.rb"
      provides: "End-to-end + idempotent no-op-on-second-invocation task test"
      contains: "class RegionTaggingsTaskTest"
    - path: "test/models/version_test.rb"
      provides: "Ordered-redelivery integration test (region version applied before tournament version)"
      contains: "redeliver"
  key_links:
    - from: "lib/tasks/region_taggings.rake#fix_international_organizer_context"
      to: "app/models/concerns/region_taggable.rb#update_version_region_data"
      via: "region.update!(global_context: true) triggers the after_save version-tagging hook"
      pattern: "update!\\(global_context: true\\)"
    - from: "lib/tasks/region_taggings.rake#fix_international_organizer_context"
      to: "PaperTrail version ordering"
      via: "rec.touch runs AFTER region.update! → tournament version id > region version id"
      pattern: "\\.touch"
    - from: "test/models/version_test.rb"
      to: "app/models/version.rb#update_from_carambus_api"
      via: "region payload (global_context=true) shifted/applied before the tournament payload"
      pattern: "update_from_carambus_api"
---

<objective>
Build the Phase 41 data-fix as an idempotent, PaperTrail-tracked rake task in the EXISTING `region_taggings` namespace, with a mandatory read-only preview default and an explicit ARMED opt-in for mutation. Prove it end-to-end with a task test (including no-op-on-second-run) and prove the ordered-redelivery apply path with an integration test.

Purpose: Deliver H1-01 (idempotent PaperTrail-tracked fix task), H1-02 (Region row + new version tagged global_context=true), and H1-03 (skipped international tournaments/leagues redelivered via fresh versions in Region-before-Tournament order) as executable, tested code — ready for the gated production run in Plan 03.
Output: extended `lib/tasks/region_taggings.rake`, new `test/tasks/region_taggings_test.rb`, extended `test/models/version_test.rb`.
</objective>

<execution_context>
@/Users/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/workflows/execute-plan.md
@/Users/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/41-versions-sync-tagging/41-CONTEXT.md
@.planning/phases/41-versions-sync-tagging/41-RESEARCH.md
@.planning/phases/41-versions-sync-tagging/41-VALIDATION.md

<interfaces>
<!-- Extracted from codebase — use directly. -->

lib/tasks/region_taggings.rake — EXISTING file. `namespace :region_taggings do ... end` wraps all tasks.
  The existing `tag_with_gobal_context`/`update_all` helpers use `update_all` (bypass PaperTrail) —
  READ AS ANTI-PATTERN REFERENCE ONLY, never call them. Add the new task INSIDE the existing namespace.

app/models/application_record.rb — ApplicationRecord.local_server? == Carambus.config.carambus_api_url.present?
  On the authority it is FALSE (PaperTrail active, LocalProtector save-guard inactive).

PaperTrail introspection (defensive guard): PaperTrail.enabled? && PaperTrail.request.enabled? → true on authority.

app/models/version.rb#update_from_carambus_api — client apply loop: get_updates returns versions
  ordered id ASC; client does `vers.shift` front-to-back; when object_changes blank it uses YAML.load(h["object"]).

test/tasks/auto_reserve_tables_test.rb — task-test template:
  require "rake"; setup { Rails.application.load_tasks if Rake::Task.tasks.empty? }; teardown { Rake::Task.clear }
  Base-offset ids: REGION_BASE_ID = 52_000_200 etc. Invoke via Rake::Task["ns:task"].invoke; .reenable to run twice.

test/models/version_test.rb:99-146 — existing update_from_carambus_api round-trip test:
  skip_unless_local_server; build payload array of {id,item_type,item_id,event,object:YAML.dump(attrs),object_changes:nil,created_at};
  stub_request(:get, /.../versions/get_updates/).to_return(status:200, body: payload.to_json); assert_nothing_raised { Version.update_from_carambus_api({}) }.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add region_taggings:fix_international_organizer_context (DRY-RUN default + ARMED mutate)</name>
  <read_first>
    - lib/tasks/region_taggings.rake (the file being modified — read lines 1-114 for the namespace + tag_with_gobal_context anti-pattern reference)
    - app/models/concerns/region_taggable.rb:118-138 (update_version_region_data — fires automatically on the update!; do NOT duplicate)
    - app/models/application_record.rb (local_server? definition)
    - .planning/phases/41-versions-sync-tagging/41-RESEARCH.md ("Recommended task shape" + Q6 idempotent touch + Anti-Patterns)
    - .planning/phases/41-versions-sync-tagging/41-CONTEXT.md (locked selection + sync mechanics)
  </read_first>
  <action>
    Inside the EXISTING `namespace :region_taggings do ... end` block in `lib/tasks/region_taggings.rake` (do NOT touch the existing `update_all`/`tag_with_gobal_context`/`verify`/`set_global_context`/`update_existing_versions` tasks), add this new task. Use `# frozen_string_literal: true` is already governed at file top — match existing file style. German comments for the business rule, English for technical terms.

    ```ruby
    desc "Phase 41 (H1): int. Organizer-Regions global_context=true taggen (PaperTrail-getrackt) + hängengebliebene int. Turniere/Ligen redelivern. Read-only Preview per Default; ARMED=1 zum Mutieren."
    task fix_international_organizer_context: :environment do
      # Guard: nur auf der Authority — dort ist PaperTrail aktiv und der LocalProtector-Save-Guard inaktiv
      raise "Abbruch: Task nur auf der Authority ausführen (Carambus.config.carambus_api_url muss leer sein)" if ApplicationRecord.local_server?
      # Guard: PaperTrail MUSS aktiv sein, sonst entstehen keine Versionen → stiller No-op, Fix propagiert nicht
      unless PaperTrail.enabled? && PaperTrail.request.enabled?
        raise "Abbruch: PaperTrail ist deaktiviert — ohne neue Versionen erreicht der Fix keinen Local-Server"
      end

      armed = ENV["ARMED"] == "1"
      puts "== region_taggings:fix_international_organizer_context — #{armed ? "ARMED (mutating)" : "DRY-RUN (read-only preview)"} =="

      # Selektionskriterium (locked, CONTEXT.md): Regions, die Organizer eines region_id IS NULL
      # Tournament ODER League sind UND global_context != true. Datengetrieben, keine Hardcode-Liste.
      affected_region_ids =
        (Tournament.where(region_id: nil, organizer_type: "Region").distinct.pluck(:organizer_id) +
         League.where(region_id: nil, organizer_type: "Region").distinct.pluck(:organizer_id)).uniq
      regions_to_fix = Region.where(id: affected_region_ids).where.not(global_context: true)

      puts "Betroffene Regions (#{regions_to_fix.count}):"
      regions_to_fix.order(:id).each do |region|
        t_count = Tournament.where(organizer_type: "Region", organizer_id: region.id, region_id: nil).count
        l_count = League.where(organizer_type: "Region", organizer_id: region.id, region_id: nil).count
        puts "  Region ##{region.id} #{region.shortname} — #{t_count} Turniere, #{l_count} Ligen (region_id IS NULL)"
      end

      unless armed
        puts "DRY-RUN: keine Änderungen geschrieben. Ausführen mit: ARMED=1 bin/rails region_taggings:fix_international_organizer_context"
        next
      end

      regions_to_fix.find_each do |region|
        region.update!(global_context: true) # echte Spaltenänderung → neue Version, von RegionTaggable#update_version_region_data getaggt
        fix_version = region.versions.order(:id).last
        # Redelivery: Turniere/Ligen dieser Region NACH der Region-Version touchen (höhere Version-id → Organizer appliziert zuerst)
        [Tournament, League].each do |klass|
          klass.where(organizer_type: "Region", organizer_id: region.id, region_id: nil).find_each do |rec|
            last_v_time = rec.versions.maximum(:created_at)
            next if last_v_time && last_v_time > fix_version.created_at # Idempotenz: bereits nach dem Fix reversioniert → skip
            rec.touch # erzwingt frische Version trotz 0 Attribut-Diff (PaperTrail on: touch)
          end
        end
        puts "  Region ##{region.id} #{region.shortname}: global_context=true (Version ##{fix_version.id}), Turniere/Ligen redelivered"
      end
      puts "Fertig."
    end
    ```

    Do NOT call `region_taggings:update_all`, `global_context?`, `update_all`, or `update_columns` for the mutating steps — the mutation MUST go through instance-level `update!`/`touch` so PaperTrail fires (RESEARCH Pitfall 1). Do NOT add a `when Region` fix to `global_context?` (out of scope).
  </action>
  <verify>
    <automated>ruby -c lib/tasks/region_taggings.rake && bin/rails region_taggings:fix_international_organizer_context 2>&1 | grep -qiE "DRY-RUN|Betroffene Regions|Authority"; echo "exit=$?"</automated>
  </verify>
  <acceptance_criteria>
    - `lib/tasks/region_taggings.rake` contains `task fix_international_organizer_context`
    - File contains `.where(region_id: nil, organizer_type: "Region")` and `.where.not(global_context: true)` (locked selection)
    - File contains `region.update!(global_context: true)` and `rec.touch` (instance-level, PaperTrail-tracked)
    - File contains the ARMED gate: `ENV["ARMED"] == "1"` and the `unless armed ... next` DRY-RUN early return
    - File contains both defensive guards: `ApplicationRecord.local_server?` raise AND `PaperTrail.enabled? && PaperTrail.request.enabled?` raise
    - The new task does NOT call `update_all` or `global_context?` anywhere inside its body (grep the task body)
    - `ruby -c lib/tasks/region_taggings.rake` reports `Syntax OK`
  </acceptance_criteria>
  <done>The task exists in the existing namespace, previews read-only by default, mutates only under ARMED=1 via PaperTrail-tracked instance saves, is idempotent by construction, and refuses to run off-authority or with PaperTrail disabled.</done>
</task>

<task type="auto">
  <name>Task 2: Rake-task test — end-to-end armed run + no-op on second invocation</name>
  <read_first>
    - test/tasks/auto_reserve_tables_test.rb (full — the task-test template: load_tasks, invoke, reenable, teardown Rake::Task.clear, base-offset ids)
    - lib/tasks/region_taggings.rake (the task from Task 1 — the subject under test)
    - test/test_helper.rb:104-115 (skip_unless_api_server — version creation needs the authority scenario)
    - test/models/region_taggable_sync_test.rb (Plan 01 fixture patterns to reuse)
  </read_first>
  <action>
    Create `test/tasks/region_taggings_test.rb` with `# frozen_string_literal: true`, `require "test_helper"`, `require "rake"`, and `class RegionTaggingsTaskTest < ActiveSupport::TestCase`. Model it on `test/tasks/auto_reserve_tables_test.rb`:
      - `REGION_BASE_ID = 52_000_210` (distinct offset from Plan 01 to avoid id collisions across files)
      - `setup { Rails.application.load_tasks if Rake::Task.tasks.empty? }`
      - `teardown { Rake::Task.clear }`
      - Helper to run the task armed: `def run_task_armed; ENV["ARMED"] = "1"; Rake::Task["region_taggings:fix_international_organizer_context"].reenable; Rake::Task["region_taggings:fix_international_organizer_context"].invoke; ensure; ENV.delete("ARMED"); end`

    Test A — `test "armed run tags the international organizer region and redelivers its stuck tournament end-to-end"`:
      - `skip_unless_api_server` (version creation only on authority scenario)
      - region_intl = Region.create!(id: REGION_BASE_ID + 1, shortname: "TSKI", name: "Task Intl", global_context: false, region_id: nil)
      - tournament = Tournament.create!(id: REGION_BASE_ID + 2, title: "Task Stuck Intl", season: seasons(:current), organizer: region_intl, single_or_league: "single", date: 1.week.from_now, region_id: nil)
      - `t_versions_before = tournament.versions.count`
      - `run_task_armed`
      - `region_intl.reload`; assert `region_intl.global_context == true`
      - `region_version = region_intl.versions.reload.last`; assert `region_version.global_context == true`
      - `tournament.reload`; assert `tournament.versions.count == t_versions_before + 1` (redelivered)
      - assert `tournament.versions.reload.last.id > region_version.id` (Region-before-Tournament ordering)

    Test B — `test "second armed run is a no-op: no new versions"`:
      - `skip_unless_api_server`
      - Same setup as Test A (fresh ids REGION_BASE_ID + 3 / + 4).
      - `run_task_armed` (first run — fixes + redelivers)
      - `region_version_count = region_intl.reload.versions.count`; `tournament_version_count = tournament.reload.versions.count`
      - `run_task_armed` (second run)
      - assert `region_intl.reload.versions.count == region_version_count` (region already global_context=true → not selected → no new version)
      - assert `tournament.reload.versions.count == tournament_version_count` (latest tournament version now postdates the region fix → not re-touched)

    Test C — `test "dry-run default does not mutate"`:
      - `skip_unless_api_server`
      - region_intl = Region.create!(id: REGION_BASE_ID + 5, shortname: "TSKD", name: "Task DryRun", global_context: false, region_id: nil)
      - Tournament.create!(id: REGION_BASE_ID + 6, ...organizer: region_intl, region_id: nil, ...)
      - Ensure ARMED is unset. `Rake::Task["region_taggings:fix_international_organizer_context"].reenable; Rake::Task[...].invoke`
      - assert `region_intl.reload.global_context == false` (preview only — no mutation)

    Wrap task invocations that print to stdout in `capture_io { ... }` if the test output noise is undesirable (optional). Keep German domain comments.
  </action>
  <verify>
    <automated>bin/rails test test/tasks/region_taggings_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - `test/tasks/region_taggings_test.rb` exists and contains `class RegionTaggingsTaskTest`
    - File contains `Rake::Task["region_taggings:fix_international_organizer_context"]` and `.reenable`
    - File contains a second-run no-op assertion comparing `versions.count` before/after the second invocation
    - File contains a dry-run assertion `global_context == false` after a non-armed invocation
    - `bin/rails test test/tasks/region_taggings_test.rb` exits 0 (tests green or cleanly skipped under local-server scenario)
  </acceptance_criteria>
  <done>The task is proven end-to-end (tag + ordered redelivery), idempotent on a second armed run, and non-mutating in the default dry-run mode.</done>
</task>

<task type="auto">
  <name>Task 3: Integration test — ordered redelivery applies (region version before tournament version)</name>
  <read_first>
    - test/models/version_test.rb:92-146 (existing update_from_carambus_api round-trip test — payload shape + stub_request + skip_unless_local_server)
    - app/models/version.rb (update_from_carambus_api apply loop + the create/update branch ~418-468 that resolves organizer)
    - .planning/phases/41-versions-sync-tagging/41-RESEARCH.md (Q4 ordering, Q5 apply path)
  </read_first>
  <action>
    Extend `test/models/version_test.rb` (do NOT create a new file) with one integration test that proves H1-03's apply-side guarantee: a redelivered international tournament version applies successfully when the Region's global_context version is applied FIRST in the same ordered batch.

    Test — `test "redelivered international tournament applies after its organizer region version is applied first"`:
      - `skip_unless_local_server` (the apply path is the local-server side, matching the existing round-trip test)
      - Build a two-element payload array in ascending version-id order (mirrors get_updates id ASC + client .shift):
          1. Region payload (LOWER id, e.g. id: 990_001): item_type "Region", item_id a base-offset id (e.g. 52_000_250), event "update", object: YAML.dump of region attrs including "global_context" => true, "shortname" => "INTX", "name" => "Intl Apply", object_changes: nil.
          2. Tournament payload (HIGHER id, e.g. id: 990_002): item_type "Tournament", item_id 52_000_251, event "update", object: YAML.dump of tournament attrs including "organizer_type" => "Region", "organizer_id" => 52_000_250, "region_id" => nil, "title" => "Intl Apply Tournament", "single_or_league" => "single", "season_id" => seasons(:current).id, "date" => 1.week.from_now, object_changes: nil.
      - Ensure neither record pre-exists locally: `Region.where(id: 52_000_250).destroy_all; Tournament.where(id: 52_000_251).destroy_all` in setup of the test.
      - Stub the HTTP GET: `stub_request(:get, /#{Regexp.escape(Carambus.config.carambus_api_url)}\/versions\/get_updates/).to_return(status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"})`
      - `assert_nothing_raised { Version.update_from_carambus_api({}) }`
      - Assert `Region.exists?(52_000_250)` is true (organizer created first)
      - Assert `Tournament.exists?(52_000_251)` is true — the tournament applied WITHOUT the "Organisiert von muss ausgefüllt werden" failure, because its organizer Region was applied first (ordering invariant).
      - `ensure`: `Tournament.where(id: 52_000_251).destroy_all; Region.where(id: 52_000_250).destroy_all` (mirror the existing test's ensure-cleanup at version_test.rb:144-146).

    Match the exact payload/stub conventions already in version_test.rb (String keys, YAML.dump, object_changes nil to trigger the full-snapshot apply branch). Use `unprotected = true` on any pre-seeded records if LocalProtector would otherwise block (mirror line 108) — but here records are CREATED by the apply path, so pre-seeding is only the cleanup.
  </action>
  <verify>
    <automated>bin/rails test test/models/version_test.rb -n /redeliver/</automated>
  </verify>
  <acceptance_criteria>
    - `test/models/version_test.rb` contains a test whose name matches `/redeliver/` and includes `organizer` resolution
    - The payload array orders the Region version (lower id) BEFORE the Tournament version (higher id)
    - Test uses `stub_request(:get, /...\/versions\/get_updates/)` and `Version.update_from_carambus_api`
    - Test asserts both `Region.exists?` and `Tournament.exists?` true after apply, with an `ensure` cleanup block
    - `bin/rails test test/models/version_test.rb` exits 0 (new test green or cleanly skipped under authority scenario)
  </acceptance_criteria>
  <done>The apply-side ordering guarantee (organizer Region applied before its tournament) is proven with a stubbed get_updates round-trip — the exact failure mode the phase fixes.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

The new task runs only via authenticated SSH shell on the authority (guarded by `ApplicationRecord.local_server?` refusing to run elsewhere). No new HTTP-reachable surface. The `get_updates` endpoint exercised by the integration test is pre-existing and unchanged.

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-41-02 | — | region_taggings:fix_international_organizer_context | N/A (accept) | Per 41-RESEARCH.md Security Domain: no applicable ASVS threats — internal data-consistency fix executed via authenticated shell on a single trusted server; no new externally-reachable code path. The two defensive guards (authority-only + PaperTrail-enabled) fail loudly rather than silently mis-mutating. The `get_updates` auth exemption is pre-existing (H33, `d44c88cc`) and explicitly out of scope. |
</threat_model>

<verification>
- `ruby -c lib/tasks/region_taggings.rake` → Syntax OK.
- `bin/rails region_taggings:fix_international_organizer_context` (no ARMED) → prints the DRY-RUN preview and mutates nothing (safe to run locally in the authority scenario).
- `bin/rails test test/tasks/region_taggings_test.rb test/models/version_test.rb test/models/region_taggable_sync_test.rb` → green.
- `bin/rails test:critical` → green (concerns + scraping regression, per CLAUDE.md wave-merge sampling).
</verification>

<success_criteria>
- `region_taggings:fix_international_organizer_context` exists in the existing namespace, DRY-RUN by default, ARMED-gated mutation, both defensive guards present, idempotent selection + touch.
- Task test proves armed end-to-end + no-op on second armed run + non-mutating dry-run.
- Integration test proves ordered redelivery applies (organizer resolves before tournament).
- No use of `update_all` / `global_context?` for mutation; no `when Region` global_context? change.
</success_criteria>

<output>
After completion, create `.planning/phases/41-versions-sync-tagging/41-02-SUMMARY.md`.
</output>
