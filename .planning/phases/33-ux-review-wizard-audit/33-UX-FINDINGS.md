# Phase 33 — UX Findings: Tournament Wizard Audit

**Phase:** 33-ux-review-wizard-audit
**Date:** 2026-04-13
**Status:** In progress — Plan 01 scaffold

---

## Reproduction recipe

Use these shell and `rails console` snippets to reproduce the wizard walkthrough. A future auditor can copy-paste these commands verbatim to re-run the walkthrough without hunting for context.

```bash
# Start dev server
bin/rails server

# In another shell, pick a reproduction tournament
bin/rails runner 'puts Tournament.order(created_at: :desc).where(aasm_state: %w[prepared seeding_open new_tournament]).limit(5).pluck(:id, :title, :aasm_state)'

# Record the chosen tournament here:
# TOURNAMENT_ID=<fill_in_from_output>
# AASM_STATE=<fill_in>
# URL: http://localhost:3000/tournaments/<TOURNAMENT_ID>
```

**Instructions for Plan 02 auditor:** Before beginning the browser walkthrough, run the `rails runner` command above, pick a tournament with an early AASM state (`prepared`, `seeding_open`, or `new_tournament`), and fill in `TOURNAMENT_ID` and `AASM_STATE` in the lines above. Commit those values so Phase 34/36 can re-observe the same tournament without having to search again.

The wizard is only visible when all three conditions are true: the current user is a `tournament_director`, the server is `local_server?` (not the API server), and the tournament does not have ClubCloud results (`!@tournament.has_clubcloud_results?`). Verify these preconditions are met before walking through each action.

---

## Canonical wizard partial — grep evidence (UX-01)

This section preserves the machine-checkable evidence proving that `_wizard_steps_v2.html.erb` is the only wizard partial rendered by `show.html.erb`. Downstream agents can re-run these commands verbatim to re-verify.

### Command 1: all wizard_steps / wizard_step references across app/, config/, test/

```
grep -rn "wizard_steps\|wizard_step" app/ config/ test/
```

Output:

```
app/views/tournaments/_wizard_steps.html.erb:26:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps.html.erb:29:      status: wizard_step_status(tournament, 1),
app/views/tournaments/_wizard_steps.html.erb:31:        text: wizard_step_status(tournament, 1) == :completed ? 'Erneut bearbeiten' : 'Spieler bearbeiten',
app/views/tournaments/_wizard_steps.html.erb:42:    <div class="wizard-step <%= step_class(wizard_step_status(tournament, 2)) %> wizard-step-optional">
app/views/tournaments/_wizard_steps.html.erb:45:          <%= step_icon(wizard_step_status(tournament, 2)) %>
app/views/tournaments/_wizard_steps.html.erb:108:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps.html.erb:111:      status: wizard_step_status(tournament, 3),
app/views/tournaments/_wizard_steps.html.erb:116:        class: wizard_step_status(tournament, 3) != :active ? 'opacity-25' : ''
app/views/tournaments/_wizard_steps.html.erb:119:      warning: wizard_step_status(tournament, 3) == :active,
app/views/tournaments/_wizard_steps.html.erb:124:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps.html.erb:127:      status: wizard_step_status(tournament, 4),
app/views/tournaments/_wizard_steps.html.erb:133:        class: wizard_step_status(tournament, 4) != :active ? 'opacity-25' : ''
app/views/tournaments/_wizard_steps.html.erb:141:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps.html.erb:144:      status: wizard_step_status(tournament, 5),
app/views/tournaments/_wizard_steps.html.erb:149:        class: wizard_step_status(tournament, 5) != :active ? 'opacity-25' : ''
app/views/tournaments/_wizard_steps.html.erb:157:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps.html.erb:160:      status: wizard_step_status(tournament, 6),
app/views/tournaments/_wizard_steps.html.erb:165:        class: "#{wizard_step_status(tournament, 6) != :active ? 'opacity-25' : ''} #{tournament.tournament_started? ? 'btn-success' : ''}"
app/views/tournaments/_wizard_steps.html.erb:168:      warning: wizard_step_status(tournament, 6) == :active && !tournament.tournament_started?,
app/views/tournaments/_wizard_steps.html.erb:175:<% if wizard_step_status(tournament, 2) == :active && tournament.organizer.is_a?(Region) %>
app/views/tournaments/show.html.erb:35:    <%= render 'wizard_steps_v2', tournament: @tournament %>
app/views/tournaments/_wizard_steps_v2.html.erb:29:    <div class="wizard-step <%= step_class(wizard_step_status(tournament, 1)) %> wizard-step-optional">
app/views/tournaments/_wizard_steps_v2.html.erb:32:          <%= step_icon(wizard_step_status(tournament, 1)) %>
app/views/tournaments/_wizard_steps_v2.html.erb:38:            <% if wizard_step_status(tournament, 1) == :completed %>
app/views/tournaments/_wizard_steps_v2.html.erb:140:  <div class="wizard-step <%= step_class(wizard_step_status(tournament, 2)) %>">
app/views/tournaments/_wizard_steps_v2.html.erb:143:        <%= step_icon(wizard_step_status(tournament, 2)) %>
app/views/tournaments/_wizard_steps_v2.html.erb:163:        <% if non_local_seedings_count > 0 && wizard_step_status(tournament, 2) == :active %>
app/views/tournaments/_wizard_steps_v2.html.erb:170:        <% if wizard_step_status(tournament, 2) == :active && !tournament.data['invitation_filename'].present? && non_local_seedings_count == 0 %>
app/views/tournaments/_wizard_steps_v2.html.erb:198:      <% step_2_status = wizard_step_status(tournament, 2) %>
app/views/tournaments/_wizard_steps_v2.html.erb:247:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps_v2.html.erb:250:      status: wizard_step_status(tournament, 3),
app/views/tournaments/_wizard_steps_v2.html.erb:257:      warning: wizard_step_status(tournament, 3) == :active ? "Dieser Schritt bleibt offen bis zur endgültigen Festschreibung in Schritt 4" : false,
app/views/tournaments/_wizard_steps_v2.html.erb:268:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps_v2.html.erb:271:      status: wizard_step_status(tournament, 4),
app/views/tournaments/_wizard_steps_v2.html.erb:277:        class: wizard_step_status(tournament, 4) != :active ? 'opacity-25' : ''
app/views/tournaments/_wizard_steps_v2.html.erb:286:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps_v2.html.erb:289:      status: wizard_step_status(tournament, 5),
app/views/tournaments/_wizard_steps_v2.html.erb:294:        class: wizard_step_status(tournament, 5) != :active ? 'opacity-25' : ''
app/views/tournaments/_wizard_steps_v2.html.erb:303:  <div class="wizard-step <%= step_class(wizard_step_status(tournament, 6)) %>">
app/views/tournaments/_wizard_steps_v2.html.erb:306:        <%= step_icon(wizard_step_status(tournament, 6)) %>
app/views/tournaments/_wizard_steps_v2.html.erb:317:        <% if wizard_step_status(tournament, 6) == :active && !tournament.tournament_started %>
app/views/tournaments/_wizard_steps_v2.html.erb:350:      <% elsif wizard_step_status(tournament, 6) == :active %>
app/views/tournaments/_wizard_steps_v2.html.erb:355:      <% elsif wizard_step_status(tournament, 6) == :completed %>
app/helpers/tournament_wizard_helper.rb:36:  def wizard_step_status(tournament, step_number)
app/helpers/tournament_wizard_helper.rb:159:    wizard_step_status(tournament, step_number) == :active
```

**Notes on output:**

- `app/views/tournaments/_wizard_steps.html.erb` — this is the retirement-candidate partial file itself. It contains internal `render 'wizard_step'` calls (rendering `_wizard_step.html.erb`) and `wizard_step_status` helper calls. The file **exists** but is **not rendered by `show.html.erb`** — it has no external caller in the codebase (see Command 2 below).
- `app/views/tournaments/_wizard_steps_v2.html.erb` — the canonical partial. Its occurrences are all internal (self-referencing helper calls within the partial body and a `render 'wizard_step'` sub-partial call). The single external entry point is `show.html.erb:35`.
- `app/helpers/tournament_wizard_helper.rb` — helper defining `wizard_step_status` used by both partials.
- No matches in `config/` or `test/`.

### Command 2: render calls targeting wizard partials in show.html.erb and _show.html.erb

```
grep -n "render.*wizard" app/views/tournaments/show.html.erb app/views/tournaments/_show.html.erb
```

Output:

```
app/views/tournaments/show.html.erb:35:    <%= render 'wizard_steps_v2', tournament: @tournament %>
```

**Conclusion (UX-01):** `show.html.erb` contains exactly one render call for a wizard partial, on line 35, and it renders `_wizard_steps_v2.html.erb`. The non-canonical partials `_wizard_steps.html.erb` and `_wizard_step.html.erb` are never rendered from `show.html.erb` or `_show.html.erb`. `_wizard_steps_v2.html.erb` is the canonical wizard partial.

---

## Happy-path action audit

The six sections below correspond to the six wizard actions that comprise the happy path. Plan 02 fills in Intent, Observed, and Screenshot for each, and records findings in the table. Plan 03 assigns stable IDs (F-01, F-02, ...) once all findings are gathered.

---

## new

**Intent:** _to be filled by Plan 02_
**Observed:** _to be filled by Plan 02_
**Screenshot:** _to be filled by Plan 02_

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| _TBD_ | _TBD_ | _to be filled by Plan 02_ | _TBD_ | _TBD_ |

---

## create

**Intent:** _to be filled by Plan 02_
**Observed:** _to be filled by Plan 02_
**Screenshot:** _to be filled by Plan 02_

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| _TBD_ | _TBD_ | _to be filled by Plan 02_ | _TBD_ | _TBD_ |

---

## edit

**Intent:** _to be filled by Plan 02_
**Observed:** _to be filled by Plan 02_
**Screenshot:** _to be filled by Plan 02_

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| _TBD_ | _TBD_ | _to be filled by Plan 02_ | _TBD_ | _TBD_ |

---

## finish_seeding

**Intent:** _to be filled by Plan 02_
**Observed:** _to be filled by Plan 02_
**Screenshot:** _to be filled by Plan 02_

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| _TBD_ | _TBD_ | _to be filled by Plan 02_ | _TBD_ | _TBD_ |

---

## start

**Intent:** _to be filled by Plan 02_
**Observed:** _to be filled by Plan 02_
**Screenshot:** _to be filled by Plan 02_

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| _TBD_ | _TBD_ | _to be filled by Plan 02_ | _TBD_ | _TBD_ |

---

## tournament_started_waiting_for_monitors

**Intent:** _to be filled by Plan 02_
**Observed:** _to be filled by Plan 02_
**Screenshot:** _to be filled by Plan 02_

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| _TBD_ | _TBD_ | _to be filled by Plan 02_ | _TBD_ | _TBD_ |

---

## Non-happy-path actions (not reviewed)

_to be filled by Plan 03 per D-07_

---

## Tier classification key

Tier classification rules per D-11 and D-12. Every finding in the tables above must be classified by the **highest layer touched** by the change needed to fix it. No judgment — mechanical classification:

**Tier 1** = view / copy / new partial / i18n key / help text only. The fix lives entirely in ERB templates, locale YAML files, or static copy. No controller, route, service, or AASM change required.

**Tier 2** = any controller change, route change, or service object change. The fix requires modifying `tournaments_controller.rb`, `config/routes.rb`, or a service class (even if a view also changes). Tier 2 takes precedence over Tier 1 if both layers are touched.

**Tier 3** = any AASM state machine change. This means a modification to the `aasm` block in `tournament.rb` — adding, removing, or renaming states or events. Tier 3 takes precedence over Tier 2 and Tier 1.

**Ambiguous cases** resolve to the **higher tier**, not the lower one.

**Gating rule (D-12):** Every Tier 3 row has `Gate: blocked-needs-test-plan` instead of `Gate: open`. Phase 36 may only unblock a Tier 3 item by attaching an explicit test-coverage plan in its own `PLAN.md` and referencing the finding ID. This rule exists because AASM state machine changes carry the highest regression risk — the tournament lifecycle is central to the entire application and has no system-level test coverage today.

**Finding type values:** `ux | bug | missing-feature`

**Gate values:** `open` (default) | `blocked-needs-test-plan` (Tier 3 only)
