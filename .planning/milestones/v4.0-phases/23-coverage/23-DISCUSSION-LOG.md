# Phase 23: Coverage - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 23-coverage
**Areas discussed:** Controller scope & depth, Reflex testing approach, Auth guard testing, Fixture strategy

---

## Controller Scope & Depth

| Option | Description | Selected |
|--------|-------------|----------|
| All four controllers | Leagues, Parties, PartyMonitors (fix skips + new), LeagueTeams. | ✓ |
| Leagues + Parties + PartyMonitors only | Skip LeagueTeams. | |
| PartyMonitors only | Fix 4 skips, add assign/remove player. | |

**User's choice:** All four controllers (Recommended)

### Depth Sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Key actions + auth guards | index/show public, CRUD admin guard, custom actions. | ✓ |
| Full CRUD for all | Every action tested. | |
| Auth guards only | Only access control tests. | |

**User's choice:** Key actions + auth guards (Recommended)

---

## Reflex Testing Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Critical paths only | 5-6 key methods: start_round, finish_round, assign_player, close_party, reset. | ✓ |
| Full coverage | All 17 methods. | |
| Skip reflex testing | Focus on controller + model. | |

**User's choice:** Critical paths only (Recommended)

---

## Auth Guard Testing

| Option | Description | Selected |
|--------|-------------|----------|
| Per-controller smoke tests | One blocked + one public test per controller. Plus local_server? guard. | ✓ |
| Per-action auth matrix | Full access control matrix per action. | |
| Skip auth testing | Trust Devise works. | |

**User's choice:** Per-controller smoke tests (Recommended)

---

## Fixture Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Fix existing + add minimal new | Fix Party fixture, add League/LeagueTeam/Party chain. Reuse existing. | ✓ |
| FactoryBot factories only | New factories, no fixture changes. | |
| Both fixtures and factories | Fix + factories for complex setups. | |

**User's choice:** Fix existing + add minimal new (Recommended)

---

## Claude's Discretion

- Test file organization
- Additional reflex methods beyond critical 5-6
- Test helper design for AASM state setup
- Channel/job test necessity assessment

## Deferred Ideas

None — discussion stayed within phase scope.
