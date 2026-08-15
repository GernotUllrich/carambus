# Phase 1: Characterization Tests & Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-09
**Phase:** 01-characterization-tests-hardening
**Areas discussed:** Test scope strategy, Test file organization, AASM hardening approach, Reek integration

---

## Test Scope Strategy

### How deep should characterization tests go?

| Option | Description | Selected |
|--------|-------------|----------|
| Critical paths only | Focus on state transitions, callbacks, broadcasts, sync operations. ~30-40 tests total. | ✓ |
| All public methods | Pin every public method with at least one test. ~100+ tests. | |
| Risk-based coverage | Map extraction boundaries, test only those methods. Most targeted. | |

**User's choice:** Critical paths only
**Notes:** None

### How to handle after_commit callback testing?

| Option | Description | Selected |
|--------|-------------|----------|
| test_commit_callbacks gem | Fire after_commit inside transactional tests. Minimal infrastructure change. | ✓ |
| Non-transactional test class | Separate base class with use_transactional_tests = false. Most accurate but slower. | |
| You decide | Claude picks the best approach. | |

**User's choice:** test_commit_callbacks gem
**Notes:** None

### VCR strategy for RegionCc?

| Option | Description | Selected |
|--------|-------------|----------|
| Use existing cassettes | Reuse test/snapshots/vcr/. Faster but may not cover all sync paths. | |
| Record fresh cassettes | Re-record against real ClubCloud API. Complete coverage. | ✓ |
| Mock HTTP directly | WebMock stubs. More control, no API dependency, more setup work. | |

**User's choice:** Record fresh cassettes
**Notes:** None

---

## Test File Organization

### Where should characterization tests live?

| Option | Description | Selected |
|--------|-------------|----------|
| test/characterization/ | New dedicated directory. Clear separation. Easy to run as group. | ✓ |
| test/models/ | Alongside existing model tests. Rails convention. | |
| test/concerns/ | With existing concern tests. | |

**User's choice:** test/characterization/
**Notes:** None

### How to name characterization test files?

| Option | Description | Selected |
|--------|-------------|----------|
| table_monitor_char_test.rb | Clear _char_ suffix. Easy to grep. | ✓ |
| table_monitor_characterization_test.rb | More explicit, slightly verbose. | |
| You decide | Claude picks naming. | |

**User's choice:** table_monitor_char_test.rb
**Notes:** None

---

## AASM Hardening

### How to enable whiny_transitions?

| Option | Description | Selected |
|--------|-------------|----------|
| Global in model | Set in TableMonitor AASM block. Fix broken tests — they're real bugs. | ✓ |
| Only in new char tests | Keep current config, enable in char tests via setup block. Safer. | |
| Global + fix existing | Enable globally AND fix any existing tests that break. Most thorough. | |

**User's choice:** Global in model
**Notes:** None

### Include PartyMonitor in char tests?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include PartyMonitor | STI subclass. Extraction affects it. Pin both now. | ✓ |
| TableMonitor only | Focus on parent. Test PartyMonitor differences later. | |
| You decide | Claude assesses risk during implementation. | |

**User's choice:** Yes, include PartyMonitor
**Notes:** None

---

## Reek Integration

### How to integrate Reek?

| Option | Description | Selected |
|--------|-------------|----------|
| One-time report | Run reek, save to .planning/ as baseline. Run again after Phase 5. No CI. | ✓ |
| Add to Gemfile + CI | Add gem, configure .reek.yml, add to pipeline. Ongoing enforcement. | |
| You decide | Claude picks approach. | |

**User's choice:** One-time report
**Notes:** None

---

## Claude's Discretion

- Test method grouping within char test files
- Specific state transitions to prioritize
- Whether to add test:characterization Rake task

## Deferred Ideas

None.
