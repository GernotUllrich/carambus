---
created: 2026-04-23T11:30:00.000Z
title: Fix Version#update_from_carambus_api YAML.load vs JSON-text collision
area: sync
files:
  - app/models/version.rb:328-346
discovered_in: 38.1-02
blocking: All sync of structured content to `disciplines.data` (and any other text column that stores JSON convention)
---

## Problem

The PaperTrail-based sync in `Version#update_from_carambus_api` has a fallback
branch that re-parses `args["data"]` via `YAML.load` when the initial
`obj.valid?` check fails. Because valid JSON is also valid YAML flow syntax,
`YAML.load('{"free_game_form":"bk2_kombi"}')` returns a **Ruby Hash** instead
of the original JSON string. The subsequent `update_columns(args)` call then
rejects the Hash for the `text` column with `can't cast Hash`.

The error is swallowed by the surrounding `rescue StandardError => e` at
`version.rb:348`, so the sync silently drops the update and moves on. No
visible failure unless you tail the log.

## Reproduction

Discovered 2026-04-23 when syncing Discipline id 107 after Phase 38.1 Plan 02
Path A write. The first structured content ever written to
`disciplines.data`. Stack trace captured in the plan runbook.

## Impact

- Until fixed, every **local server** (carambus_phat, carambus_master,
  additional BCW instances) must do a Path B `unprotected=true` write to keep
  its local `Discipline.find(107).data` in sync with production.
- Any future change to `Discipline.find(107)` in production will silently
  overwrite the Path B writes on local servers — tracked as reconciliation debt.
- Likely affects other text columns that store JSON-ish content (e.g.
  `tournament.data`, `group_cc.data` — they already use the
  `data.is_a?(String) ? JSON.parse(data) : data` guard on the read side, so
  their writes go through a different path, but the sync path is shared).

## Root cause

`app/models/version.rb:328-331` (fallback branch when `obj.valid?` is false):

```ruby
else
  args = YAML.load(h["object"])
  args["data"] = YAML.load(args["data"]) if args["data"].present?
  args["remarks"] = YAML.load(args["remarks"]) if args["remarks"].present?
end
```

This `YAML.load(args["data"])` was correct for the legacy convention where
`data` was YAML-serialized. It is wrong for JSON-encoded text. The safest
fix probably sniffs `args["data"].start_with?("{", "[")` and uses `JSON.parse`
for JSON-looking strings, falling back to `YAML.load` otherwise — but that
deserves a real discussion about whether the re-parse is needed at all.

## Solution sketch (needs discussion)

1. Add characterization tests for the current fallback behavior (what sets
   `obj.valid?` to false in the first place? maybe that check itself is
   stale).
2. Decide whether the re-parse is still necessary. If yes, sniff the payload
   shape. If no, drop lines 330-331 and 338-339.
3. Fix the re-parse path to preserve text content as text when the column is
   a plain `text` attribute (vs. a serialized Hash attribute).
4. Verify with a round-trip sync test: write JSON text on carambus_api,
   assert it lands verbatim on carambus_bcw after
   `Version#update_from_carambus_api`.

## Out of scope

- The unrelated question of "why does `obj.valid?` return false for
  Discipline 107 in the first place?" — that's a separate investigation; may
  be a stale uniqueness constraint or a validator that references data not
  yet populated during sync.

## References

- Phase 38.1 Plan 02 runbook: `.planning/phases/38.1-bk2-kombi-minimum-viable-support/38.1-02-DISCIPLINE-DATA-WRITE.md` (Execution Log section)
- Phase 38.1 Plan 02 SUMMARY.md (Path B workaround rationale)

---

## Closure (Phase 38.4-17, 2026-04-25)

Closed by Phase 38.4 Plan 01 (commit references in 38.4-01-SUMMARY.md). The
`Version.safe_parse` / `safe_parse_for_text_column` helpers replaced all 4
`YAML.load(args["data/remarks"])` callsites. 9 regression tests in
`test/models/version_test.rb` lock the fix in place. This file is moved to
`done/` for bookkeeping — the underlying code fix landed in Plan 38.4-01.
