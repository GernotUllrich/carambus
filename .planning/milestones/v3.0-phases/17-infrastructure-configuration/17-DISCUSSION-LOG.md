# Phase 17: Infrastructure & Configuration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 17-infrastructure-configuration
**Areas discussed:** Cable adapter strategy, local_server? override, Smoke test design

---

## Cable Adapter Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Global switch to async | Change cable.yml test adapter to async globally. Simpler. Run existing channel tests after to verify they still pass. | ✓ |
| Per-test override | Keep cable.yml as test adapter. In ApplicationSystemTestCase setup, switch to async via ActionCable config + restart. More isolated but more complex. | |
| Env var toggle | Use ENV['CABLE_ADAPTER'] in cable.yml. System tests set CABLE_ADAPTER=async. Most flexible but adds env var complexity. | |

**User's choice:** Global switch to async
**Notes:** Simplest approach. Verify existing channel unit tests (TournamentChannelTest, TournamentMonitorChannelTest) still pass after the change.

---

## local_server? Override

| Option | Description | Selected |
|--------|-------------|----------|
| Add test section to carambus.yml | Add test: section with carambus_api_url. Config-based, works across all test types. | ✓ |
| Stub in ApplicationSystemTestCase only | Override ApplicationRecord.local_server? in system test setup. Scoped but thread-local stubs may not cross to Puma threads. | |
| Set in test_helper.rb globally | Set Carambus.config.carambus_api_url in test_helper.rb. Broadest change. | |

**User's choice:** Add test section to carambus.yml
**Notes:** Clean config-based approach. Need to verify no existing tests depend on local_server? being false.

---

## Smoke Test Design — Wait Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Capybara built-in wait | Use assert_selector with Capybara's default wait time. Simplest. | ✓ |
| Custom polling helper | Write assert_broadcast_received helper that polls for DOM changes. More explicit, reusable. | |
| Cable status indicator | Add data-cable-status attribute in JS connected() callback. Most reliable but requires JS change. | |

**User's choice:** Capybara built-in wait
**Notes:** Keep it simple for Phase 17.

## Smoke Test Design — AASM Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| You decide | Claude picks simplest state change that produces visible DOM update | ✓ |
| Let me specify | User specifies a specific transition | |

**User's choice:** You decide (Claude's discretion)

---

## Claude's Discretion

- Exact AASM transition for smoke test
- Multi-session Capybara helper API design
- AR connection pool configuration
- suppress_broadcast reset in teardown
