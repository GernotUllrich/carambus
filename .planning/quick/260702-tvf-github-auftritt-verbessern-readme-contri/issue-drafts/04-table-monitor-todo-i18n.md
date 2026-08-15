# i18n: resolve the `# TODO: I18n` marker in TableMonitor

**Labels:** good first issue, help wanted

## Summary

`app/models/table_monitor.rb` line 337 carries a `# TODO: I18n` comment directly above the AASM state-machine block. The AASM states (`new`, `ready`, `warmup`, `match_shootout`, `playing`, …) have no localized display names — anywhere the raw state value surfaces in the UI, it appears as an untranslated English/technical token.

## Why it matters

The scoreboard and tournament monitor are the most user-visible parts of Carambus — table operators are volunteers, and the UI default language is German. State names leaking through as raw identifiers look unpolished. This task is well-scoped: add locale entries and a small helper, no state-machine logic changes.

## Where

- `app/models/table_monitor.rb:337` — the `# TODO: I18n` marker above `aasm column: "state" do … end`
- `config/locales/de.yml` and `config/locales/en.yml` — add a `table_monitor.states.*` (or follow the existing `activerecord`/view-key conventions) subtree
- Views/helpers that render `table_monitor.state` (grep for `.state` usages in `app/views/table_monitors/`)

## Suggested approach

1. List the AASM states defined in the block below line 337.
2. Add DE + EN translations under a sensible key namespace (check `config/locales/*.yml` for how other AASM models, e.g. `Tournament`, localize states — follow that pattern).
3. Where views render the raw state, replace with `t("table_monitor.states.#{table_monitor.state}")` (or a small helper).
4. Remove the `# TODO: I18n` comment once addressed.
5. Run `bin/rails test test/models/table_monitor_test.rb` and `bundle exec standardrb`.

## Definition of done

- `grep -n "TODO: I18n" app/models/table_monitor.rb` returns nothing.
- Every AASM state of `TableMonitor` has a DE and EN translation entry.
- `bin/rails test test/models/table_monitor_test.rb` passes; `bundle exec standardrb` is clean on changed files.
