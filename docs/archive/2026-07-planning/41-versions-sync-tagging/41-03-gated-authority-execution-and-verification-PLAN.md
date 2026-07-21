---
phase: 41-versions-sync-tagging
plan: 03
type: execute
wave: 2
depends_on: [2]
files_modified: []
autonomous: false
requirements: [H1-01, H1-04]
must_haves:
  truths:
    - "A read-only DRY-RUN preview of the affected Regions + tournament/league touch counts is presented to the user on the authority BEFORE any mutation, and the user explicitly signs off (or aborts)"
    - "The armed task runs on the authority only after sign-off, creating the Region global_context=true versions FIRST and the redelivered tournament/league versions AFTER (higher version id)"
    - "get_updates?last_version_id=<one before the Region fix version> returns the Region version with global_context=true"
    - "After the normal hourly cron, a German regional server has the previously-missing organizer Region present and applies the international tournaments with zero apply-failures"
  artifacts:
    - path: ".planning/phases/41-versions-sync-tagging/41-03-SUMMARY.md"
      provides: "Record of the affected-region list, armed-run output, and verification evidence (get_updates snapshot + local-server check)"
      contains: "global_context"
  key_links:
    - from: "authority: ARMED=1 bin/rails region_taggings:fix_international_organizer_context"
      to: "hourly carambus:retrieve_updates cron on regional servers"
      via: "new PaperTrail versions filtered by Version.for_region and applied via update_from_carambus_api"
      pattern: "get_updates"
---

<objective>
Execute the tested Phase 41 fix on the production authority (api.carambus.de) under an explicit read-only-preview → user-sign-off → armed-run gate, then verify propagation via the `get_updates` HTTP snapshot and a regional-server spot-check. No repo code changes — this plan runs the Plan 02 task on the live authority and captures verification evidence for H1-04.

Purpose: Deliver H1-04 (reproducible verification: `get_updates` shows `global_context=true`; apply-failures for international tournaments = 0) and the production-side half of H1-01 (the idempotent task actually run), honoring the locked constraint "Prod-/Datenänderung erst nach ausdrücklicher User-Freigabe" and "all local servers via the normal cron — no manual per-server re-sync".
Output: `.planning/phases/41-versions-sync-tagging/41-03-SUMMARY.md` with the affected-region list, armed-run log, and verification evidence.
</objective>

<execution_context>
@/Users/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/workflows/execute-plan.md
@/Users/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/41-versions-sync-tagging/41-CONTEXT.md
@.planning/phases/41-versions-sync-tagging/41-RESEARCH.md
@.agents/skills/scenario-management/SKILL.md

<notes>
- All work is on the existing branch `scenario/api/versions-sync-tagging`. Do NOT create a new branch, do NOT edit other scenario checkouts, do NOT push to master.
- The task file must be present on the authority. Deploy the branch to api.carambus.de (Capistrano flow per scenario-management) BEFORE running, or run from the deployed checkout at `carambus_api/current` once the task lands there.
- Authority scenario: `Carambus.config.carambus_api_url` is blank → PaperTrail active, `ApplicationRecord.local_server?` false. The task's own guards enforce this and will refuse to run otherwise.
- Verification HTTP endpoint `get_updates` is exempt from the `system_admin_only` gate (versions_controller.rb:6, H33 fix d44c88cc) → reachable unauthenticated for the read-only snapshot.
- Redelivery volume estimate (RESEARCH Q6): ~379 forced touches for UMB alone; prod may be a low multiple across affected regions ~18-40. `find_each` batching in the task handles this.
</notes>
</context>

<tasks>

<task type="checkpoint:decision" gate="blocking">
  <name>Task 1: Read-only preview on the authority + user sign-off</name>
  <read_first>
    - lib/tasks/region_taggings.rake (confirm the fix task is present/deployed)
    - .planning/phases/41-versions-sync-tagging/41-CONTEXT.md ("Ausführungsort & Zugang"; "Prod-/Datenänderung erst nach ausdrücklicher User-Freigabe")
    - .planning/phases/41-versions-sync-tagging/41-RESEARCH.md (Open Question 1: run the read-only selection query first, present list for sign-off)
    - .agents/skills/scenario-management/SKILL.md (deploy-to-authority workflow)
  </read_first>
  <action>Deploy the `scenario/api/versions-sync-tagging` branch to the authority (or confirm the Plan 02 task is present in `carambus_api/current`), then run the DRY-RUN preview read-only: `ssh api` → `cd carambus_api/current` → `bin/rails region_taggings:fix_international_organizer_context` (no ARMED). Capture the "Betroffene Regions (N):" output verbatim and present the full list (region ids, shortnames, tournament/league counts) to the user for a proceed/abort decision. Mutate nothing in this task.</action>
  <decision>Proceed with the armed mutation on the authority, or abort, based on the read-only preview of exactly which Regions will be tagged and how many tournaments/leagues will be redelivered.</decision>
  <context>
    The selection is data-driven, not hardcoded — locally it matches exactly UMB (Region 25) but production is expected to include more international organizer Regions (id range ~18-40). The user MUST see the actual production list and touch counts before any write. This is the locked gate.

    Steps the executor performs / instructs:
    1. Ensure the branch `scenario/api/versions-sync-tagging` (with the Plan 02 task) is deployed to the authority, or the task file is present in `carambus_api/current`.
    2. On the authority, run the DRY-RUN (default) preview:
       `ssh api` → `cd carambus_api/current` → `bin/rails region_taggings:fix_international_organizer_context`
       (No ARMED env var → read-only. Prints "Betroffene Regions (N):" with per-region tournament/league counts, mutates nothing.)
    3. Present the full printed list (region ids, shortnames, tournament/league counts) verbatim to the user.
  </context>
  <options>
    <option id="proceed">
      <name>Proceed to armed run</name>
      <pros>Fixes the dangling-organizer sync failure for the confirmed regions; propagates via normal cron.</pros>
      <cons>Writes new versions on production (idempotent + reversible only by nature of being additive versions).</cons>
    </option>
    <option id="abort">
      <name>Abort / investigate</name>
      <pros>No production writes; time to reconcile if the affected list contains unexpected regions (e.g. a German LV that should NOT be globally tagged).</pros>
      <cons>Sync failure for international tournaments persists.</cons>
    </option>
  </options>
  <verify>
    <automated>MANUAL — read-only preview run on the authority; no automated command in this repo. The Plan 02 task test already proves the preview mutates nothing.</automated>
  </verify>
  <acceptance_criteria>
    - The DRY-RUN preview was run on the authority and its "Betroffene Regions (N):" output captured verbatim into the SUMMARY.
    - The output shows NO mutation occurred (preview mode).
    - The user explicitly selected `proceed` or `abort`.
  </acceptance_criteria>
  <resume-signal>Select: proceed or abort (and, if proceed, confirm the affected-region list looks correct — no unexpected German Landesverband regions).</resume-signal>
  <done>DRY-RUN preview run read-only; affected-region list captured and shown to the user; user selected proceed or abort.</done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 2: Armed run on the authority (after sign-off)</name>
  <read_first>
    - lib/tasks/region_taggings.rake (the armed code path + ordering guarantee)
    - .planning/phases/41-versions-sync-tagging/41-RESEARCH.md (Q4 ordering, Q6 batched touches)
  </read_first>
  <action>ONLY after `proceed` in Task 1. On the authority: `ssh api` → `cd carambus_api/current` → `ARMED=1 bin/rails region_taggings:fix_international_organizer_context`. Capture the per-region "global_context=true (Version ##...)" stdout into the SUMMARY, then run the two read-only `bin/rails runner` evidence snippets in how-to-verify to confirm each fixed region's latest version has `event: "update", global_context: true` and that a redelivered tournament's latest version id exceeds its region's fix version id.</action>
  <what-built>The Plan 02 task, ARMED. It sets `global_context=true` on the selected Regions via PaperTrail-tracked `update!` (new tagged version FIRST), then `touch`es their region_id-nil tournaments/leagues (fresh versions AFTER, higher id), skipping any already re-versioned since the region fix (idempotent).</what-built>
  <how-to-verify>
    1. Only after `proceed` in Task 1. On the authority:
       `ssh api` → `cd carambus_api/current` → `ARMED=1 bin/rails region_taggings:fix_international_organizer_context`
    2. Capture the full stdout (per-region "global_context=true (Version ##...)" lines) into the SUMMARY.
    3. Immediately record, read-only, for each fixed region:
       `bin/rails runner 'r=Region.find(<id>); v=r.versions.order(:id).last; puts v.attributes.slice("id","event","region_id","global_context").inspect'`
       → expect `event: "update", global_context: true`.
    4. Record `Version.maximum(:id)` before/after is not required, but confirm at least one redelivered tournament's latest version id is GREATER than its organizer region's fix version id:
       `bin/rails runner 'r=Region.find(<id>); rv=r.versions.order(:id).last; t=Tournament.where(organizer_type:"Region",organizer_id:r.id,region_id:nil).first; puts [rv.id, t.versions.order(:id).last.id].inspect'`
       → expect the tournament version id > region version id.
  </how-to-verify>
  <verify>
    <automated>MANUAL — armed run executes on the live authority via SSH; not runnable from this repo/CI. Correctness of the mutation logic is covered by test/tasks/region_taggings_test.rb (Plan 02).</automated>
  </verify>
  <acceptance_criteria>
    - Armed run completed; per-region "global_context=true (Version ##...)" output captured in the SUMMARY.
    - For each fixed region, its latest version has `event: "update", global_context: true`.
    - At least one redelivered tournament's latest version id > its region's fix version id (ordering invariant holds on production data).
  </acceptance_criteria>
  <resume-signal>Type "armed-run-complete" once the armed task finished and the per-region version evidence is captured.</resume-signal>
  <done>Armed run completed; each fixed region's latest version is global_context=true; ordering invariant (region version id < tournament version id) confirmed on production data.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3: Verify propagation — get_updates snapshot + regional-server spot-check</name>
  <read_first>
    - .planning/phases/41-versions-sync-tagging/41-RESEARCH.md (Q7 verification paths; "Additional confirmed context" — hourly cron)
    - .planning/phases/41-versions-sync-tagging/41-VALIDATION.md (Manual-Only Verifications table)
    - app/models/version.rb (for_region filter; Thread.current[:carambus_sync_apply_failures]; APPLY FAILED log line ~473)
  </read_first>
  <action>Run the reproducible authority `get_updates` snapshot (`curl -s "https://api.carambus.de/versions/get_updates?last_version_id=<region_fix_version_id-1>&region_id=<affected region id>"`) and confirm the Region version carries `"global_context": true`. Then, after the normal hourly cron (no manual per-server re-sync), spot-check one German regional server per how-to-verify: `Region.exists?`, the previously-stuck tournament present, and zero new `APPLY FAILED` log lines for those tournament ids. Optionally re-run the DRY-RUN preview on the authority to confirm 0 affected regions (idempotency). Record all evidence in the SUMMARY.</action>
  <what-built>Verification evidence that the fix reached the sync surface (authority HTTP) and, after the normal hourly cron, a regional server (H1-04).</what-built>
  <how-to-verify>
    1. Authority HTTP snapshot (reproducible, unauthenticated — get_updates is H33-exempt):
       `curl -s "https://api.carambus.de/versions/get_updates?last_version_id=<region_fix_version_id - 1>&region_id=<an affected local region id>"`
       → the response includes the Region version with `"global_context": true` (organizer now replicable to that region).
    2. Wait for the normal hourly `carambus:retrieve_updates` cron on a German regional server (no manual per-server re-sync — locked constraint). Then on that regional server:
       - `bin/rails runner 'puts Region.exists?(<fixed region id>)'` → expect `true` (organizer now present locally).
       - `bin/rails runner 'puts Tournament.exists?(<a previously-stuck int. tournament id, e.g. 18488>)'` → expect `true` (redelivered + applied).
       - Confirm the `[Version.sync] APPLY FAILED` log lines for those international tournament ids no longer appear on subsequent cron runs (grep the log; `Thread.current[:carambus_sync_apply_failures]` empty for them).
    3. Optional idempotency confirmation on the authority: re-run DRY-RUN preview → "Betroffene Regions (0):" for the fixed regions (they now have global_context=true).
  </how-to-verify>
  <verify>
    <automated>MANUAL — verification spans the live authority HTTP endpoint and a regional server after the hourly cron; not runnable from this repo. The apply-side ordering guarantee is covered automatically by the Plan 02 integration test (version_test.rb /redeliver/).</automated>
  </verify>
  <acceptance_criteria>
    - `get_updates?last_version_id=<region_fix_version_id-1>&region_id=<affected region>` returns the Region version with `global_context: true` (captured in SUMMARY).
    - On a regional server after cron: `Region.exists?(<id>)` true, the previously-stuck international tournament present, and no new `APPLY FAILED` log entries for those tournament ids.
    - Re-running the DRY-RUN preview on the authority reports 0 affected regions (idempotency confirmed on production).
  </acceptance_criteria>
  <resume-signal>Type "verified" with the get_updates snapshot + regional-server evidence, or describe any residual apply-failures.</resume-signal>
  <done>get_updates snapshot shows global_context=true; regional server post-cron has the organizer + tournaments with zero apply-failures; second DRY-RUN preview reports 0 affected regions.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

Execution boundary: authenticated SSH shell on the authority (trusted single server). Verification boundary: the pre-existing, deliberately-unauthenticated `get_updates` machine-to-machine sync endpoint (H33-exempt) — read-only, unchanged by this phase.

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-41-03 | — | authority armed run + get_updates verification | N/A (accept) | Per 41-RESEARCH.md Security Domain: no applicable ASVS threats. Mutation happens only via authenticated SSH on a trusted server behind an explicit user sign-off gate; the read-only preview precedes any write. The `get_updates` auth exemption used for verification is pre-existing (H33, `d44c88cc`) and out of scope — this phase changes only the data those endpoints return, not the gate. |
</threat_model>

<verification>
- Preview run mutated nothing (DRY-RUN); user signed off on the exact affected-region list.
- Armed run produced tagged Region versions (global_context=true) ordered before redelivered tournament versions.
- get_updates snapshot shows global_context=true; regional server post-cron has the organizer + tournaments, zero apply-failures for international tournaments.
- Second DRY-RUN preview reports 0 affected regions (idempotent).
</verification>

<success_criteria>
- H1-04 satisfied: reproducible get_updates snapshot with global_context=true + apply-failures = 0 on a regional server after the normal cron.
- H1-01 satisfied on production: the idempotent task ran; a re-run is a no-op.
- No manual per-server re-sync performed (propagation via the hourly cron only).
- All evidence captured in `41-03-SUMMARY.md`.
</success_criteria>

<output>
After completion, create `.planning/phases/41-versions-sync-tagging/41-03-SUMMARY.md` with: the affected-region list, the armed-run per-region output, the get_updates snapshot, and the regional-server verification evidence.
</output>
