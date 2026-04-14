---
created: 2026-04-14T19:26:11.314Z
title: Refactor 36B-06 verification gate to PRG redirect pattern
area: general
files:
  - app/controllers/tournaments_controller.rb:311-317
  - app/views/tournaments/tournament_monitor.html.erb:64
---

## Problem

Phase 36B-06 added a server-side parameter verification gate in
`TournamentsController#start` (lines 311-317):

```ruby
unless params[:parameter_verification_confirmed].to_s == "1"
  failures = verify_tournament_start_parameters(@tournament, params)
  if failures.any?
    @verification_failure = build_verification_failure_payload(failures)
    render :tournament_monitor and return
  end
end
```

On verification failure it `render :tournament_monitor` without a
redirect. This is architecturally broken in two distinct ways that
together produced three separate user-visible bugs in the 260414-tms
debug session:

1. **Turbo Stream mismatch (commit 8a948c93):** Turbo submitted the
   start form as TURBO_STREAM, but the render returns plain HTML.
   Turbo silently discarded the response — user saw nothing. Patched
   by disabling Turbo on the form.

2. **URL bar pollution (commit 23d65963):** After the render, the
   browser URL bar is /tournaments/:id/start (a POST-only route). On
   the confirmed re-submit, `redirect_back_or_to` picked up that URL
   from the Referer and redirected to GET /start → routing error.
   Patched by replacing redirect_back_or_to with plain redirect_to.

Both patches are workarounds for the root architectural issue: render
instead of redirect violates the Post/Redirect/Get pattern, which
exists precisely to prevent Referer/URL-bar confusion on POST-handled
views.

## Solution

Refactor the verification failure path to use PRG:

1. On failure, store `@verification_failure` payload in
   `flash[:verification_failure]` (or equivalent session store) and
   `redirect_to tournament_monitor_tournament_path(@tournament)`
2. In the `tournament_monitor` GET action, read the flash and assign
   `@verification_failure` if present
3. `tournament_monitor.html.erb` renders the modal with `auto_open:
   true` when `@verification_failure` is present (unchanged)
4. Revert the two patches applied during 260414-tms:
   - Remove `data: { turbo: false }` from the start form (Turbo
     Stream can handle redirects natively)
   - The redirect_back_or_to question becomes moot since the URL bar
     is now on tournament_monitor_tournament_path, not /start
5. Verify the 36B-06 system test (tournament_parameter_verification_test.rb)
   still covers the flow end-to-end after refactor

## Notes

Consider whether the flash payload approach is safe given that
`build_verification_failure_payload` may contain state-dependent
structured data. If flash is too coarse, session-scoped storage or
a short-lived cache key works too.
