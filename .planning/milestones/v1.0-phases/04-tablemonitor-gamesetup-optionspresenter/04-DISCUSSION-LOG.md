# Phase 4: TableMonitor GameSetup & OptionsPresenter - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the discussion.

**Date:** 2026-04-10
**Phase:** 04-tablemonitor-gamesetup-optionspresenter
**Mode:** discuss (interactive)
**Areas discussed:** All (user selected "You decide on all")

## Questions & Answers

### Gray Area Selection

| Question | Options Presented | Selected |
|----------|-------------------|----------|
| Which areas to discuss? | GameSetup class design, skip_update_callbacks replacement, OptionsPresenter scope, You decide on all | **You decide on all** |

## Decisions Made

All decisions made by Claude based on established Phase 2/3 patterns:

- **GameSetup:** ApplicationService (like Phase 2 syncers) — one-shot operation with AR writes
- **skip_update_callbacks:** Replace with broadcast: false keyword + @suppress_broadcast instance variable
- **OptionsPresenter:** PORO (like Phase 3 ScoreEngine) — read-only view data preparation

## Corrections Made

No corrections — user delegated all decisions to Claude.
