---
phase: 41
slug: versions-sync-tagging
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-12
---

# Phase 41 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from 41-RESEARCH.md "## Validation Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Minitest (Rails default, per CLAUDE.md — NOT RSpec) |
| **Config file** | `test/test_helper.rb` (WebMock + FactoryBot + LocalProtectorTestOverride already wired) |
| **Quick run command** | `bin/rails test test/models/region_taggable_sync_test.rb test/tasks/region_taggings_test.rb` |
| **Full suite command** | `bin/rails test` (or `bin/rails test:critical` for concerns+scraping subset) |
| **Estimated runtime** | ~quick: seconds; full: minutes |

---

## Sampling Rate

- **After every task commit:** `bin/rails test test/models/region_taggable_sync_test.rb test/tasks/region_taggings_test.rb`
- **After every plan wave:** `bin/rails test:critical`
- **Before `/gsd-verify-work`:** Full suite (`bin/rails test`) green **+** read-only production selection-query sign-off (Open Question 1) obtained before ANY prod mutation.
- **Max feedback latency:** < 60 seconds (quick command)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 41-01-01 | 01 | 0 | H1-01 | — | N/A | unit | `bin/rails test test/models/region_taggable_sync_test.rb -n /selection/` | ❌ W0 | ⬜ pending |
| 41-01-02 | 01 | 0 | H1-02 | — | N/A | unit (`skip_unless_api_server`) | `bin/rails test test/models/region_taggable_sync_test.rb -n /global_context_true/` | ❌ W0 | ⬜ pending |
| 41-01-03 | 01 | 0 | H1-01 | — | N/A | unit | `bin/rails test test/models/region_taggable_sync_test.rb -n /idempotent/` | ❌ W0 | ⬜ pending |
| 41-01-04 | 01 | 0 | H1-03 | — | N/A | unit (`skip_unless_api_server`) | `bin/rails test test/models/region_taggable_sync_test.rb -n /touch_forces_version/` | ❌ W0 | ⬜ pending |
| 41-02-01 | 02 | 1 | H1-03 | — | organizer resolves before tournament apply | integration | `bin/rails test test/models/version_test.rb` (extend) | ❌ W0 | ⬜ pending |
| 41-02-02 | 02 | 1 | H1-01/H1-03 | — | rake task idempotent end-to-end | task test | `bin/rails test test/tasks/region_taggings_test.rb` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/models/region_taggable_sync_test.rb` — new file: selection criterion, `region.update!(global_context: true)` → new version tagged `global_context: true` + `region_id` = record's own column, idempotency (2nd selection = empty), `tournament.touch` forces a version (blank `object_changes`, populated `object`). Gate on `skip_unless_api_server` (`test/test_helper.rb:107-109`), mirroring `version_test.rb`'s HTTP-stub scenario gate.
- [ ] `test/tasks/region_taggings_test.rb` — new file: rake-task test modeled on `test/tasks/auto_reserve_tables_test.rb` (`Rails.application.load_tasks`, `Rake::Task[...].invoke`, `.reenable` in teardown). End-to-end + no-op-on-second-invocation.
- [ ] Fixtures: use base-offset IDs `>= MIN_ID` style (e.g. `REGION_BASE_ID = 52_000_2xx`) as in `auto_reserve_tables_test.rb`; do NOT reuse production ids (25 / 18488).
- [ ] No framework install needed — Minitest + WebMock + FactoryBot already present.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Production selection-query result (exact affected regions) | H1-01 | Runs against live authority DB, requires user sign-off before mutation | `ssh api` → `cd carambus_api/current` → read-only `bin/rails runner` selection query; user reviews list |
| Post-deploy `get_updates` snapshot shows `global_context=true` on Region fix version | H1-04 | Requires live authority + a local server after cron | `curl`/`URI get_updates?last_version_id=<vor Region-Version>`; on a local server: `Region.exists?(<id>)`, tournament present, `Thread.current[:carambus_sync_apply_failures]` empty for int. tournaments |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter (after Wave 0 stubs land)

**Approval:** pending
