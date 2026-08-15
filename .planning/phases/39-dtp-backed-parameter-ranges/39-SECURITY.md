---
phase: 39
slug: dtp-backed-parameter-ranges
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-07
---

# Phase 39 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

Phase 39 refactored `Discipline#parameter_ranges` from a hardcoded constant
into a DTP (DisciplineTournamentPlan)-backed query, migrated the single
production caller in `tournaments_controller.rb#verify_tournament_start_parameters`
to the new keyword-arg signature, narrowed `UI_07_FIELDS` from 7 to 2
entries, and deleted the dead `UI_07_SENTINEL_VALUES` exemption logic
plus its 7-test integration regression file. Read-side AR-query refactor
over an existing global-record table.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| HTTP request → `tournaments_controller#start` | Operator submits tournament-start form with operator-supplied `balls_goal` / `innings_goal` integers; verifier compares against master-data Range from DTP query. | Operator integers (untrusted) → `range.cover?(value)` boolean → optional verification modal |
| Controller → `Discipline#parameter_ranges(tournament:)` | Read-only AR query against `discipline_tournament_plans` (global record table, `id < 50_000_000`). | `tournament_plan_id`, `players` (count of seedings), `player_class` strings → bound AR parameters → `points` / `innings` integers → Ruby Range |
| Test harness → fixtures | Test-only DTP/tournament/seeding fixtures loaded into test DB. | Static YAML → test DB tables; never reaches production load path. |

No new HTTP entry points, no auth changes, no schema changes, no new write paths.

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-39-01 | I (Information disclosure) | `Discipline#parameter_ranges` (model) | accept | `app/models/discipline.rb:69-117` uses only AR DSL (`where`, `find_by`); zero `sanitize_sql`, zero string-interpolated `where`. All bound values flow through AR parameterization. DTP table has no PII columns (only `points`, `innings`, `players`, `player_class`). Method returns Hash of native Ruby Ranges only — no DTP record fields leak. | closed |
| T-39-02 | T (Tampering) | Test fixtures (DTP, tournaments, seedings) | accept | `test/fixtures/discipline_tournament_plans.yml` and the extended `tournaments.yml` / `seedings.yml` files load only into the test DB via `bin/rails db:test:prepare`. No production-load path references the new fixtures. | closed |
| T-39-03 | T (Tampering) | `tournaments_controller#verify_tournament_start_parameters` | accept | `app/controllers/tournaments_controller.rb:27-30` defines `UI_07_FIELDS = %i[balls_goal innings_goal].freeze` (size 2). Verifier still iterates only this list and calls `range.cover?(value)`. `UI_07_SENTINEL_VALUES` constant + its `next if` guard removed (zero matches across `app/` and `test/`). Narrowing reduces false-positives only, no new false-negatives in the 2 retained fields. | closed |
| T-39-04 | I (Information disclosure) | Controller error paths (verifier failures) | accept | `app/controllers/tournaments_controller.rb:1021-1026` builds a failure list of `{field, value, range, label}` entries — static symbol, operator-supplied integer, master-data Range, I18n string. No tournament internals, user data, or DB internals leak through `parameter_ranges` flow. | closed |
| T-39-05 | D (Denial of Service) | DTP query in tournament-start hot path | accept | Originally claimed "indices already exist" — re-grounded in this audit (see Accepted Risks Log RA-39-05): `discipline_tournament_plans` has ~464 production rows, no explicit indices on schema; sequential scans complete in microseconds. Operator-authenticated, low-frequency hot path with three early-return short-circuits (handicap / no-plan / blank-class) before the DB hit. Acceptable at current scale. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| RA-39-01 | T-39-01 | Read-only AR query against global DTP table; AR-parameterized; no PII columns. No further mitigation warranted. | gernot.ullrich@gmail.com | 2026-05-07 |
| RA-39-02 | T-39-02 | Test-only fixtures; zero production exposure. | gernot.ullrich@gmail.com | 2026-05-07 |
| RA-39-03 | T-39-03 | Verifier authority narrowed; cannot introduce new false-negatives in retained fields. | gernot.ullrich@gmail.com | 2026-05-07 |
| RA-39-04 | T-39-04 | Failure payload contains only non-sensitive comparison context. | gernot.ullrich@gmail.com | 2026-05-07 |
| RA-39-05 | T-39-05 | Mitigation re-grounded after audit found no `t.index` declarations on `discipline_tournament_plans` in `db/schema.rb:217-226`. At ~464 rows the sequential scan completes in microseconds and the hot path is operator-authenticated with three early-return short-circuits before the DB hit. Adding a composite `(discipline_id, tournament_plan_id, players, player_class)` index is deferred as optional future maintenance, not a security blocker. | gernot.ullrich@gmail.com | 2026-05-07 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-07 | 5 | 5 | 0 | gsd-security-auditor (initial audit; T-39-05 re-grounded after schema verification) |

## Security Audit 2026-05-07

| Metric | Count |
|--------|-------|
| Threats found | 5 |
| Closed | 5 |
| Open | 0 |

Auditor result: 4/5 SECURED on first pass; T-39-05 returned as OPEN_THREAT (non-critical, claim/reality mismatch — `db/schema.rb:217-226` shows zero `t.index` declarations on `discipline_tournament_plans` while PLAN-39-02 claimed "indices already exist"). `block_on: critical_only` policy did not block phase closure. User accepted T-39-05 with re-grounded rationale (RA-39-05).

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-07
