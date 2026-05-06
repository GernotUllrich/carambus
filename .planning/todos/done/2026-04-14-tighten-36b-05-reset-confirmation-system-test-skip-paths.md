---
created: 2026-04-14T19:26:11.314Z
title: Tighten 36B-05 reset confirmation system test skip paths
area: testing
files:
  - test/system/tournament_reset_confirmation_test.rb:36-47
---

## Problem

The 36B-05 Capybara system test
`test/system/tournament_reset_confirmation_test.rb` was supposed to
catch the Stimulus scope bug fixed in commit 5ef81ab0 (reset/force-reset
trigger buttons had no ancestor `data-controller="confirmation-modal"`
because the modal partial was rendered at the end of `<body>` in the
application layout — a sibling, not an ancestor of the triggers).

Instead, the bug shipped. Looking at `visit_tournament_or_skip`
(lines 36-47):

```ruby
def visit_tournament_or_skip
  visit tournament_path(@tournament)
  if page.has_text?("Internal Server Error", wait: 0) ||
     page.has_text?("We're sorry, but something went wrong", wait: 0)
    skip "tournament show page renders 500 in test env..."
  end
  return if page.has_css?("[data-controller='confirmation-modal']", visible: :all, wait: 0)
  skip "layout partial 'shared/confirmation_modal' not present..."
end
```

The test has three different skip paths before it ever exercises the
click. Presumably the fixture tournament was rendering a 500 or the
layout-level modal was present but the click action silently no-op'd
because the modal was a sibling of the trigger button — and the
`assert_no_selector "[data-controller='confirmation-modal'].hidden"`
assertion after `find("button[data-action=...]").click` never actually
ran in CI. Net effect: the test was green while the feature was dead.

## Solution

1. Fix the underlying fixture problem so `visit tournament_or_skip`
   no longer needs the `500` skip path. Likely the `tournaments(:local)`
   fixture's organizer association is polymorphic and doesn't resolve
   in test env — see the comment in lines 30-36 pointing at
   `_show.html.erb:5 tournament.organizer.shortname`
2. Remove the `has_css?` skip (lines 44-47). With the 5ef81ab0 fix the
   modal partial is always rendered per-page, so its presence is a
   precondition, not a best-effort check
3. Add a failing test BEFORE any fix that proves Stimulus dispatches
   the action to the correct controller — e.g.,
   `find("button[data-action*='confirmation-modal#open']").click` and
   then `assert_selector ".fixed.inset-0:not(.hidden)"` to verify the
   modal became visible. If Stimulus is misscoped, this assertion fails
4. Run the full file in CI (not local skip) to catch regressions

## Notes

This is a "why didn't the test catch it" postmortem item, not a
feature change. The tightened test should be written to REPRODUCE the
Stimulus scope bug first, then validated against the 5ef81ab0 fix to
confirm it goes green.

## Closure

Resolved 2026-05-06 by quick task 260506-i6h. Fix: see
`.planning/quick/260506-i6h-fix-tournament-discipline-test-fixtures-/260506-i6h-SUMMARY.md`
and the corresponding commit. Key changes:
  - test/fixtures/tournaments.yml :: local — explicit organizer_id/season_id columns + tournament_plan: t04_5
  - test/system/tournament_reset_confirmation_test.rb — visit_tournament_or_skip: flunk-not-skip + has_css? skip removed; .hidden selector corrected to target root div; Stimulus scope guard added to test 1
