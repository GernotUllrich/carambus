---
phase: 41-versions-sync-tagging
plan: 01
type: execute
wave: 0
depends_on: []
files_modified:
  - test/models/region_taggable_sync_test.rb
autonomous: true
requirements: [H1-01, H1-02, H1-03]
must_haves:
  truths:
    - "The locked selection query returns exactly the Regions that organize a region_id IS NULL Tournament OR League AND have global_context != true"
    - "After a Region's global_context flips to true it is no longer selected (idempotent selection)"
    - "region.update!(global_context: true) creates a NEW PaperTrail version tagged global_context=true and region_id = the record's own region_id column"
    - "tournament.touch forces a fresh version with blank object_changes and a populated object snapshot, ordered AFTER a preceding region version (higher version id)"
  artifacts:
    - path: "test/models/region_taggable_sync_test.rb"
      provides: "Characterization tests proving the four sync mechanisms the Phase 41 task relies on"
      contains: "class RegionTaggableSyncTest"
  key_links:
    - from: "test/models/region_taggable_sync_test.rb"
      to: "app/models/concerns/region_taggable.rb#update_version_region_data"
      via: "region.update!(global_context: true) → after_save hook tags latest version from the record's global_context COLUMN"
      pattern: "update!\\(global_context: true\\)"
    - from: "test/models/region_taggable_sync_test.rb"
      to: "PaperTrail Events::Update#changed_notably? touch special-case"
      via: "record.touch forces a version even with zero attribute diff"
      pattern: "\\.touch"
---

<objective>
Lock the four sync mechanisms the Phase 41 data-fix depends on into characterization tests BEFORE the rake task exists (Nyquist Wave 0). These tests do not touch the task — they prove the underlying ActiveRecord + PaperTrail behaviour that 41-RESEARCH.md verified against the gem source, so the task in Plan 02 is built against a green, executable ground truth.

Purpose: Turn 41-RESEARCH.md's HIGH-confidence mechanism claims (selection criterion, version tagging from the `global_context` COLUMN, selection idempotency, touch-forces-version) into fast regression guards that fail loudly if PaperTrail behaviour or the RegionTaggable hook ever drifts.
Output: `test/models/region_taggable_sync_test.rb` (new, 4 tests) — green.
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
<!-- Extracted from codebase — executor uses these directly, no exploration needed. -->

app/models/concerns/region_taggable.rb (after_save hook that tags the version — DO NOT modify in this phase):
  after_save :update_version_region_data
  def update_version_region_data
    return unless PaperTrail.request.enabled?
    record_versions = self.versions rescue []
    if record_versions.any?
      latest_version = record_versions.last
      if latest_version && previous_changes.present?
        latest_item = latest_version.item            # LIVE record, re-queried → reads current COLUMN values
        region_id = latest_item.region_id if latest_item.respond_to?(:region_id)
        global_context = latest_item.global_context if latest_item.respond_to?(:global_context)
        latest_version.update_columns(region_id: region_id, global_context: global_context) ...
      end
    end
  end

test/test_helper.rb (scenario gate — PaperTrail is active ONLY when carambus_api_url is blank):
  def skip_unless_api_server
    skip "Nur auf API-Server (carambus_api_url leer)" if LOCAL_SERVER_SCENARIO
  end

Fixture-ID convention (from test/tasks/auto_reserve_tables_test.rb): base-offset IDs >= MIN_ID (50_000_000).
  REGION_BASE_ID = 52_000_200   # do NOT reuse production ids 25 / 18488

Schema (db/schema.rb):
  regions:  region_id integer, global_context boolean default false, shortname string (unique)
  versions: item_type, item_id, event, object text, object_changes text, region_id integer, global_context boolean default false
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Selection-criterion + idempotency characterization tests</name>
  <read_first>
    - test/models/region_taggable_sync_test.rb (the file being created — confirm it does not already exist)
    - test/tasks/auto_reserve_tables_test.rb (fixture-ID convention: REGION_BASE_ID = 52_000_200; Tournament.create! / Region.create! patterns)
    - app/models/concerns/region_taggable.rb (find_associated_region_id — for understanding the Region case; NOT modified)
    - .planning/phases/41-versions-sync-tagging/41-CONTEXT.md (selection criterion, locked)
  </read_first>
  <action>
    Create `test/models/region_taggable_sync_test.rb` with `# frozen_string_literal: true`, `require "test_helper"`, and `class RegionTaggableSyncTest < ActiveSupport::TestCase`. Define `REGION_BASE_ID = 52_000_200` and a season via `seasons(:current)`.

    Add a private helper `affected_regions` that runs the LOCKED selection query VERBATIM (identical to what the Plan 02 task uses):
    ```ruby
    def affected_regions
      ids = (Tournament.where(region_id: nil, organizer_type: "Region").distinct.pluck(:organizer_id) +
             League.where(region_id: nil, organizer_type: "Region").distinct.pluck(:organizer_id)).uniq
      Region.where(id: ids).where.not(global_context: true)
    end
    ```

    Test 1 — `test "selection returns only regions organizing a region_id-nil record with global_context not true"`:
    Create three regions with base-offset ids:
      - region_intl  = Region.create!(id: REGION_BASE_ID + 1, shortname: "INTL", name: "Intl Body", global_context: false, region_id: nil)
      - region_fixed = Region.create!(id: REGION_BASE_ID + 2, shortname: "FIXD", name: "Already Global", global_context: true, region_id: nil)
      - region_reg   = Region.create!(id: REGION_BASE_ID + 3, shortname: "REGD", name: "Regional", global_context: false)
    Create tournaments (minimal valid — reuse the auto_reserve_tables_test.rb create pattern: season:, organizer:, single_or_league: "single", date:):
      - a region_id: nil tournament organized by region_intl  (→ region_intl MUST be selected)
      - a region_id: nil tournament organized by region_fixed (→ NOT selected: global_context already true)
      - a tournament WITH region_id: region_reg.id organized by region_reg (→ NOT selected: region_id present)
    Assert `affected_regions.pluck(:id)` includes region_intl.id and excludes region_fixed.id and region_reg.id.

    Test 2 — `test "selection is idempotent: after global_context flips true the region drops out"`:
    Reuse the region_intl + its region_id-nil tournament from Test 1's setup pattern. Assert region_intl is selected. Then `region_intl.update_columns(global_context: true)` (update_columns is fine here — this test asserts the QUERY, not versioning). Assert `affected_regions.pluck(:id)` no longer includes region_intl.id (empty of it) — proving a second task run selects nothing.

    Also add a League-organizer variant assertion inside Test 1 (or a Test 1b): a region_id: nil League organized by a 4th region (id REGION_BASE_ID + 4, global_context: false) is ALSO selected — proves the `Tournament OR League` union clause.

    German comments for the business rule (Selektionskriterium), English for technical terms per CLAUDE.md. Clean up created records in a `teardown` if fixtures don't auto-rollback (transactional tests are on by default, so teardown is usually unnecessary — do NOT disable transactional tests).
  </action>
  <verify>
    <automated>bin/rails test test/models/region_taggable_sync_test.rb -n /selection/ -n /idempotent/</automated>
  </verify>
  <acceptance_criteria>
    - `test/models/region_taggable_sync_test.rb` exists and contains `class RegionTaggableSyncTest`
    - File contains `REGION_BASE_ID = 52_000_200` and does NOT contain the literal production ids `25` or `18488` as fixture ids
    - File contains `.where(region_id: nil, organizer_type: "Region")` and `.where.not(global_context: true)` (locked selection clause)
    - `bin/rails test test/models/region_taggable_sync_test.rb -n /selection/` exits 0
    - `bin/rails test test/models/region_taggable_sync_test.rb -n /idempotent/` exits 0
  </acceptance_criteria>
  <done>Selection-criterion and idempotency tests are green; the query used is byte-for-byte the clause Plan 02's task will run.</done>
</task>

<task type="auto">
  <name>Task 2: PaperTrail version-tagging + touch-forces-version characterization tests (skip_unless_api_server)</name>
  <read_first>
    - test/models/region_taggable_sync_test.rb (the file from Task 1 — extend it)
    - app/models/concerns/region_taggable.rb:118-138 (update_version_region_data — reads latest_item.global_context COLUMN)
    - test/test_helper.rb:104-115 (skip_unless_api_server gate)
    - test/models/version_test.rb:99-146 (skip gate usage + version payload/round-trip conventions)
    - .planning/phases/41-versions-sync-tagging/41-RESEARCH.md (Q1 tagging path, Q3 touch-forces-version, Code Examples section)
  </read_first>
  <action>
    Extend `test/models/region_taggable_sync_test.rb` with two mechanism tests, each guarded by `skip_unless_api_server` as the FIRST line (PaperTrail is only active in the authority scenario, `carambus_api_url` blank — mirrors version_test.rb).

    Test 3 — `test "region update! global_context_true creates a new version tagged global_context true from the record column"`:
      - `skip_unless_api_server`
      - Create region_intl = Region.create!(id: REGION_BASE_ID + 5, shortname: "INT2", name: "Intl Body 2", global_context: false, region_id: nil)
      - Record `before = region_intl.versions.count`
      - `region_intl.update!(global_context: true)` (INSTANCE-level update! — real column change → PaperTrail after_update fires → RegionTaggable#update_version_region_data tags the version)
      - Assert `region_intl.versions.count == before + 1` (a NEW version was created — NOT bypassed)
      - `v = region_intl.versions.reload.last`
      - Assert `v.global_context == true` (version tagged from the record's global_context COLUMN, per update_version_region_data)
      - Assert `v.region_id == region_intl.region_id` (the record's OWN region_id column — nil here for a top-level intl body, mirroring UMB Region 25). Use `assert_equal region_intl.region_id, v.region_id`.

    Test 4 — `test "tournament touch_forces_version with blank object_changes and populated object, ordered after region version"`:
      - `skip_unless_api_server`
      - Create region_intl = Region.create!(id: REGION_BASE_ID + 6, shortname: "INT3", name: "Intl Body 3", global_context: false, region_id: nil)
      - Create tournament = Tournament.create!(id: REGION_BASE_ID + 7, title: "Intl Stuck Tournament", season: seasons(:current), organizer: region_intl, single_or_league: "single", date: 1.week.from_now, region_id: nil)
      - `region_intl.update!(global_context: true)`; `region_version = region_intl.versions.reload.last`
      - Record `before = tournament.versions.count`
      - `tournament.touch` (forces a version despite zero attribute diff — PaperTrail on: touch default + changed_notably? touch special-case)
      - `tv = tournament.versions.reload.last`
      - Assert `tournament.versions.count == before + 1` (touch DID create a version)
      - Assert `tv.object_changes.blank?` (touch stores no object_changes)
      - Assert `tv.object.present?` (full YAML snapshot present — the client apply fallback path consumes this)
      - Assert `tv.id > region_version.id` (ORDERING: touch happened after update! → higher version id → organizer applies before tournament on the client per get_updates ascending-id + client .shift)

    Keep German comments for the domain rule, English for the PaperTrail/technical mechanics.
  </action>
  <verify>
    <automated>bin/rails test test/models/region_taggable_sync_test.rb -n /global_context_true/ -n /touch_forces_version/</automated>
  </verify>
  <acceptance_criteria>
    - File contains `skip_unless_api_server` at least twice (once per mechanism test)
    - File contains `region_intl.update!(global_context: true)` (INSTANCE-level, not update_all/update_columns for the version-creating step)
    - File contains `tournament.touch` and assertions on `object_changes` blank + `object` present + `tv.id > region_version.id`
    - `bin/rails test test/models/region_taggable_sync_test.rb` exits 0 (all 4+ tests green or skipped under the local-server scenario)
  </acceptance_criteria>
  <done>Version-tagging and touch-forces-version mechanisms are locked as tests, gated to the authority scenario; the ordering invariant (region version id < tournament version id) is asserted.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

None introduced by this plan — it adds test files only; no runtime code path, no external input.

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-41-01 | — | test/models/region_taggable_sync_test.rb | N/A (accept) | Per 41-RESEARCH.md Security Domain: no applicable ASVS threats. This plan adds Minitest characterization tests only — no externally-reachable surface, no new input validation path, no auth/session change. `get_updates` auth exemption is pre-existing and out of scope. |
</threat_model>

<verification>
- `bin/rails test test/models/region_taggable_sync_test.rb` runs; selection/idempotency tests execute in any scenario; version-mechanism tests execute on the authority scenario and skip cleanly on a local-server scenario (no failures).
- The selection clause in the test is identical to the clause Plan 02's task will run (grep both files for `.where(region_id: nil, organizer_type: "Region")`).
</verification>

<success_criteria>
- 4 characterization tests exist in `test/models/region_taggable_sync_test.rb`, green (version tests skip under local-server scenario).
- No production ids (25 / 18488) used as fixture ids; base-offset REGION_BASE_ID = 52_000_200 convention followed.
- The locked selection criterion is captured verbatim and passing.
</success_criteria>

<output>
After completion, create `.planning/phases/41-versions-sync-tagging/41-01-SUMMARY.md`.
</output>
