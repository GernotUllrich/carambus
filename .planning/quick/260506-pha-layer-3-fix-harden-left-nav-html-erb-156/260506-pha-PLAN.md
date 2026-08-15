---
phase: 260506-pha
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/views/application/_left_nav.html.erb
  - test/integration/left_nav_system_admin_test.rb
autonomous: true
requirements:
  - L3-NAV-PICKER
  - L3-NAV-REGRESSION-TEST

must_haves:
  truths:
    - "Migration link expanded into a nested submenu listing all Regions (one link per Region, alphabetical by shortname)"
    - "Each Region in DB has a corresponding `migration_cc_region_path(region)` link in the submenu — concrete Region instance, never nil"
    - "No reference to `Region[1]` remains in `_left_nav.html.erb` — the original hardcoded id=1 lookup is gone"
    - "Sidebar renders without crash for system_admin even when DB has zero Regions (empty submenu, no `UrlGenerationError`)"
    - "Sibling Club Cloud submenu links (Meta Maps, Region Ccs, Branch Ccs, …) still render unchanged"
    - "Migration submenu uses the existing nested-collapsible pattern (button with `data-action='click->sidebar#toggle'` followed by `<ul ... data-sidebar-target='submenu'>`) so the Stimulus controller's `toggle` method (uses `nextElementSibling`) Just Works at the second nesting level"
    - "Regression integration test exists at `test/integration/left_nav_system_admin_test.rb` and is GREEN (signed-in `users(:system_admin)` hitting `root_path`)"
    - "36B-06 system test (`test/system/tournament_verification_modal_test.rb`) still 4/4 GREEN — no regression to today's earlier 260506-o93 victory"
  artifacts:
    - path: "app/views/application/_left_nav.html.erb"
      provides: "Migration link expanded into Region-picker submenu"
      contains: "migration_cc_region_path(region)"
    - path: "test/integration/left_nav_system_admin_test.rb"
      provides: "Regression guard: per-Region migration links + no hardcoded `Region[1]`"
      contains: "system_admin"
  key_links:
    - from: "app/views/application/_left_nav.html.erb (Migration submenu body)"
      to: "Region.order(:shortname, :name).each"
      via: "ERB iteration emitting one <li> per Region"
      pattern: "Region\\.order.*\\.each"
    - from: "app/views/application/_left_nav.html.erb (each iteration body)"
      to: "migration_cc_region_path(region)"
      via: "concrete Region instance from each-block, never Region[1] / never nil"
      pattern: "migration_cc_region_path\\(region\\)"
    - from: "test/integration/left_nav_system_admin_test.rb"
      to: "root_path render under sign_in users(:system_admin)"
      via: "ActionDispatch::IntegrationTest"
      pattern: "sign_in users\\(:system_admin\\)"
---

<objective>
Replace the hardcoded `migration_cc_region_path(Region[1])` link in
`app/views/application/_left_nav.html.erb:156` with a **nested Region-picker
submenu**: clicking "Migration" expands a sub-list of all Regions in the DB,
each linking to its own per-Region migration page.

The original line raised `ActionController::UrlGenerationError: No route matches
{action: "migration_cc", controller: "regions", id: nil}` whenever Region[1]
was nil — crashing the sidebar render for system_admin users on any DB without
the global Region 1 (test fixtures, fresh dev DBs, mid-migration states).

**Fix shape correction (per user interrupt):** the previous "wrap in
`if Region[1].present?`" approach was REJECTED. The Migration link's purpose is
**per-Region migration** — picking a specific Region from the central API.
Defaulting to Region[1] (or hiding the link entirely) doesn't let the admin
choose. The user must be ASKED which Region. Solution: expand the single link
into a submenu that lists every Region; the admin clicks the one they want.

This matches the existing Sidebar UX pattern (8 top-level Club Cloud submenu
items each use the same nested-collapsible structure with the Stimulus
`toggle` action). The `sidebar_controller.js` `toggle` method uses
`event.currentTarget.nextElementSibling` — works at any nesting level — so the
Stimulus side needs zero changes.

Purpose: close the last open production-edge follow-up from today's work with
a fix that **gives admins the right tool for the job** (per-Region picker)
instead of a dead-end no-op (hidden link). bcw operators are `club_admin` and
never trigger this nav block, but other deployments (system_admin on phat /
api / fresh checkouts) hit the 500 — and now also get a usable per-Region
picker, not just a non-crashing absence.

Output:
- Replace 1-line ERB Migration entry with a ~16-line nested submenu (button +
  `<ul>` iterating `Region.order(:shortname, :name)`).
- 1 new integration test file: `test/integration/left_nav_system_admin_test.rb`.
- Verification that 36B-06 stays 4/4 GREEN.
</objective>

<execution_context>
@/Users/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/workflows/execute-plan.md
@/Users/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@.agents/skills/scenario-management/SKILL.md
@.agents/skills/extend-before-build/SKILL.md
@app/views/application/_left_nav.html.erb
@app/javascript/controllers/sidebar_controller.js
@app/models/region.rb
@config/routes.rb
@app/controllers/regions_controller.rb
@test/fixtures/regions.yml
@test/fixtures/users.yml
@test/integration/users_test.rb
@test/test_helper.rb

<scenario_mode>
**Debugging Mode in carambus_bcw** (LOCKED 5). bcw was at HEAD `62068962` at
intake; commits in bcw are explicitly fine. Cross-checkout sync is deferred per
user. Other checkouts (`carambus_master`, `carambus_phat`, `carambus_api`) are
known to be ~10 commits behind from this morning's push — that's the user's
deferred sync, NOT a precondition violation for THIS quick task. Do not run
`/git pull` in master/phat/api as part of this task.
</scenario_mode>

<extend_before_build>
This task is a textbook SKILL match: **extend the existing nested-collapsible
sidebar pattern** (8 sibling implementations already live in this file at
lines 21-114, 39-58, 59-76, 77-94, 95-114, 115-140, 141-182, plus the implicit
Docs section at 183-203). Do NOT introduce a new sidebar component, a Region-
picker partial, a helper, or a JS controller. Re-use the exact button + `<ul
data-sidebar-target="submenu">` shape and the `click->sidebar#toggle` action.
The `sidebar_controller.js#toggle` method (uses `nextElementSibling`) handles
arbitrary nesting depth, confirmed by reading the controller — so a 2nd-level
collapsible just works.
</extend_before_build>

<diagnosis>
The original bug diagnosis is unchanged: `migration_cc_region_path(Region[1])`
on line 156 calls a member route that requires a non-nil `:id`. When the
`regions` table has no row at id=1, `Region[1]` returns nil, the route helper
raises `ActionController::UrlGenerationError`, and the entire sidebar render
500s — taking down every page for system_admin users on that DB.

**What changed in the fix shape (user interrupt):** the original plan would
have wrapped this in `if Region[1].present?`, hiding the link entirely when
Region 1 is absent. That's wrong because:

1. The Migration link's **purpose** is per-Region migration (pull a specific
   Region's data from the central API). It is not a "Region 1 default" — id=1
   was an accident of legacy fixture ordering, not a semantic choice.
2. **Defaulting to a different Region** (e.g. `Region[1] || Region.first`)
   would silently lead admins to migrate the WRONG region's data — a far
   worse bug than a 500.
3. **Hiding the link entirely** (`if Region[1].present?`) leaves the admin
   with no way to trigger migration at all on a DB where Region[1] hasn't
   synced — which is exactly the state where they MOST need to migrate.

The correct fix is a **picker UI**: ask the admin which Region. We already
have a known-good pattern for picker submenus in this very file (8 examples).
Use it.

**Edge case — empty Regions table:** if `Region.count == 0`, the iterator
emits zero `<li>`s. The submenu opens to an empty list. No crash, no broken
links. This is acceptable: there's literally nothing to migrate to in that
state, and the empty submenu is its own correct UX answer ("nothing to pick").
The fixtures guarantee 4 regions (NBV/BBV/BBL/DBU at id 50_000_001…4) so
the test always exercises the populated branch; we add a separate test point
for "renders 200 and submenu is present" but don't gate on the count.
</diagnosis>

<interfaces>
<!-- Key contracts the executor needs. Extracted from the codebase. -->

**The exact pattern to extend** — copied verbatim from
`app/views/application/_left_nav.html.erb` lines 21-38 (Organisation submenu,
the simplest top-level example). **Match the BUTTON / SVG / UL classes
exactly** when building the new Migration nested submenu, EXCEPT that the
nested Migration submenu lives 1 level deeper, so its button/ul indentation
is 14 spaces (matching the `<li>` it replaces) and its inner `<li>` body
indentation is 16 spaces. The Stimulus action attribute and `data-sidebar-
target` attribute do NOT change — `nextElementSibling` works at any depth.

```erb
<li>
  <button data-action="sidebar#toggle" class="w-full flex items-center justify-between p-2 text-gray-800 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white rounded">
    <span class="flex items-center">
      <!-- icon SVG goes here, OR omit it for nested 2nd-level submenus -->
      <%= I18n.t("home.index.organisation", :default => "Organisation") %>
    </span>
    <svg class="w-4 h-4 transform transition-transform text-gray-800 dark:text-gray-300" data-sidebar-target="icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
    </svg>
  </button>
  <ul class="pl-4 hidden list-none" data-sidebar-target="submenu">
    <li><%= link_to "...", some_path, class: 'block p-2 text-gray-700 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white rounded' %></li>
    <!-- … -->
  </ul>
</li>
```

For the **nested** Migration submenu specifically — since it's already
inside a submenu, drop the leading icon `<svg>` from the `<span>` (siblings
at lines 155, 159, 160-179 don't have icons either; they're plain text
links). Keep only the right-side chevron SVG (the one with `data-sidebar-
target="icon"` and `M19 9l-7 7-7-7` path) so the rotate-on-toggle animation
matches sibling top-level entries.

**Stimulus controller (`app/javascript/controllers/sidebar_controller.js`)**
— no changes needed. Confirmed at lines 113-117:

```javascript
toggle(event) {
  const submenu = event.currentTarget.nextElementSibling
  submenu.classList.toggle('hidden')
  event.currentTarget.querySelector('svg').classList.toggle('rotate-180')
}
```

`nextElementSibling` is depth-agnostic — each `<button>` finds its own
following `<ul>` regardless of how deeply nested. The `querySelector('svg')`
call grabs the FIRST svg inside the button, which is the chevron when no
icon-svg is present. This is why we OMIT the leading icon-svg for nested
buttons: `querySelector('svg')` would otherwise rotate the icon-svg, not
the chevron. Verified by reading sibling-pattern usage on lines 22-26 (icon
+ chevron) vs the absent-icon contract we need.

**Region model (`app/models/region.rb`)** — confirmed schema:
- `shortname` :string (UNIQUE indexed, line 28)
- `name` :string
- Both nullable, but in practice every fixture row has both set.
- Class method `Region[id]` → short for `Region.find_by(id: id)`, returns nil
  if absent. (This is the lookup we're REMOVING.)

**Fixtures (`test/fixtures/regions.yml`)** — confirmed contents:
- `nbv` at id `50_000_001`, shortname `NBV`
- `bbv` at id `50_000_002`, shortname `BBV`
- `bbl` at id `50_000_003`, shortname `BBL`
- `dbu` at id `50_000_004`, shortname `DBU`
- **No record at id 1** — so `Region[1]` is nil in the test DB by default.

**Routes (`config/routes.rb:307`):**
```ruby
member do
  get :migration_cc   # /regions/:id/migration_cc
end
```
`migration_cc_region_path(region)` — REQUIRES a Region instance with `id`.
Passing nil raises `UrlGenerationError`. Passing a Region with id=`50_000_001`
yields `/regions/50000001/migration_cc`. Yes, that's a long URL — that's fine.

**Users fixture (`test/fixtures/users.yml`:106-115):** `:system_admin`
exists with role: `system_admin`, plain password "password", confirmed_at set.
`current_user.system_admin?` returns true → activates the Club Cloud nav
block at `_left_nav.html.erb:141`.

**Integration test pattern (`test/integration/users_test.rb`):**
```ruby
class Carambus::UsersTest < ActionDispatch::IntegrationTest
  test "..." do
    sign_in users(:one)
    get root_path
    assert_response :success
  end
end
```
ActionDispatch::IntegrationTest already includes `Devise::Test::IntegrationHelpers`
via `test_helper.rb:127-129`. No extra includes needed.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace hardcoded Migration link with a nested Region-picker submenu</name>
  <files>app/views/application/_left_nav.html.erb</files>
  <action>
**Locate** the current Migration link in `app/views/application/_left_nav.html.erb`.
At intake it lives at line 156 inside the `current_user&.system_admin?` Club
Cloud submenu (lines 141-182). Current text (single `<li>`):

```erb
            <li><%= link_to "Migration", migration_cc_region_path(Region[1]), class: 'block p-2 text-gray-700 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white rounded' %></li>
```

**If a previous revision already changed this line** (e.g. wrapped it in
`if Region[1].present?`), revert/replace whatever exists in this position
back to the canonical pre-fix form before re-applying — the goal is the
nested-submenu shape, not an additive layering on top of the prior wrong
fix. Use `git diff app/views/application/_left_nav.html.erb` to see what's
currently in place, then Edit accordingly. The grep verifications below
will catch leftover `Region[1].present?` artifacts.

**Replace** that single `<li>` with the following nested-submenu block.
Match the surrounding indentation (12 spaces for the outer `<li>`, 14 spaces
for `<button>` and `<ul>`, 16 spaces for inner `<li>`):

```erb
            <li>
              <button data-action="sidebar#toggle" class="w-full flex items-center justify-between p-2 text-gray-700 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white rounded">
                <span>Migration</span>
                <svg class="w-4 h-4 transform transition-transform text-gray-800 dark:text-gray-300" data-sidebar-target="icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                </svg>
              </button>
              <ul class="pl-4 hidden list-none" data-sidebar-target="submenu">
                <% Region.order(:shortname, :name).each do |region| %>
                  <li><%= link_to (region.shortname.presence || region.name), migration_cc_region_path(region), class: 'block p-2 text-gray-700 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white rounded' %></li>
                <% end %>
              </ul>
            </li>
```

**Pattern-match notes:**
- The `<button>` uses `text-gray-700 dark:text-gray-400` (matching the link
  styling of sibling `<li>`s in this same submenu, lines 155, 159, 160-179)
  rather than `text-gray-800 dark:text-gray-300` (which is used for top-level
  buttons at lines 22, 40, 60, 78, 96, 116, 143). Rationale: this nested
  button visually replaces a sibling link, so it should match link colour
  weight, not top-level button colour weight.
- The `<svg>` chevron uses `text-gray-800 dark:text-gray-300` (matches the
  chevron used everywhere else in the file — chevron colour stays consistent
  across nesting levels).
- We OMIT the leading icon `<svg>` from the `<span>`. Sibling links at
  155-179 don't have icons; the chevron-svg is then the FIRST svg inside the
  button, which is what `event.currentTarget.querySelector('svg')` grabs in
  `sidebar_controller.js#toggle` for the rotate animation. (Verified against
  the controller source.)
- The link label uses `region.shortname.presence || region.name` — short
  form when available (and it's UNIQUE indexed, so always present in
  practice), falling back to `name` if `shortname` is blank/nil. `.presence`
  handles empty-string defensively.
- `Region.order(:shortname, :name)` — alphabetical, secondary by name to
  break ties when shortname collides (it shouldn't given the UNIQUE index,
  but the secondary sort is free defensive insurance).
- **Empty case**: if no Regions exist, the `each` block emits zero `<li>`s.
  The `<ul>` opens to an empty list. No crash. This is intentional and
  documented in `<diagnosis>` above.

**Constraints / non-goals:**
- Per the user correction: NO `Region[1]` reference, NO presence-guard,
  NO `Region[1] || Region.first` fallback. The link must always resolve
  to a concrete Region instance (provided by the each-block iterator).
- Per **LOCKED 2** (re-affirmed): only the Migration entry changes. Leave
  the surrounding sibling `<li>`s — Meta Maps (155), Region Ccs (now at the
  position formerly 157), Branch Ccs, … through Discipline Ccs — completely
  untouched. The diff for `_left_nav.html.erb` should show ONE replaced `<li>`
  (the Migration one) becoming a multi-line nested-submenu `<li>`. No other
  lines change.
- Preserve the surrounding `<ul ... data-sidebar-target="submenu">` (line
  154) and its closing `</ul>` (now line ~180) verbatim.
- Do NOT introduce a partial, helper, or constant. SKILL: extend, don't build.
- Do NOT touch the Stimulus controller — `nextElementSibling` already handles
  the new nesting depth.
- Do NOT add I18n keys for "Migration" — kept as the literal string to match
  the rest of the Club Cloud submenu (Meta Maps, Region Ccs, Branch Ccs, …
  are all hardcoded English; this is a system_admin-only block where
  internationalization isn't a goal).
  </action>
  <verify>
    <automated>cd /Users/gullrich/DEV/carambus/carambus_bcw && grep -n 'migration_cc_region_path(region)' app/views/application/_left_nav.html.erb && ! grep -n 'migration_cc_region_path(Region\[1\])' app/views/application/_left_nav.html.erb && ! grep -n 'Region\[1\]\.present?' app/views/application/_left_nav.html.erb && grep -c 'Region\.order' app/views/application/_left_nav.html.erb && grep -B 1 -A 1 'data-action="sidebar#toggle"' app/views/application/_left_nav.html.erb | grep -c 'Migration'</automated>
- (1) `grep migration_cc_region_path(region)` MUST return exactly one line —
  the iteration body of the new submenu. This proves the link resolves to
  a concrete each-block Region, never Region[1] / never nil.
- (2) `! grep migration_cc_region_path(Region[1])` MUST succeed (no match).
  The original hardcoded id=1 lookup is gone.
- (3) `! grep Region[1].present?` MUST succeed (no match). The previous
  rejected fix shape is gone — covers the case where revision-1 left a
  partial wrap behind.
- (4) `grep -c Region.order` MUST return `1` — the iteration is in place.
- (5) The button-context grep MUST find "Migration" near a `data-action=
  "sidebar#toggle"` line, proving the new toggle button is wired up.
- Visual check: open the file and confirm sibling `<li>`s on the lines
  formerly 155 (Meta Maps) and 157+ (Region Ccs onward) are untouched.
  Confirm `<ul data-sidebar-target="submenu">` (line ~154) and its closing
  `</ul>` are unchanged.
- ERB still parses (no syntax error). Run `bundle exec erblint
  app/views/application/_left_nav.html.erb` — no NEW errors vs baseline.
  </verify>
  <done>
The Migration entry in `app/views/application/_left_nav.html.erb` has been
replaced with a nested-submenu block: a button with `data-action="sidebar#
toggle"` followed by a `<ul data-sidebar-target="submenu">` that iterates
`Region.order(:shortname, :name)` and emits one link per Region using
`migration_cc_region_path(region)`. No `Region[1]` reference remains. No
sibling `<li>` is touched. ERB parses cleanly.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add regression integration test for the Region-picker submenu</name>
  <files>test/integration/left_nav_system_admin_test.rb</files>
  <behavior>
- **Test 1 (renders without crash):** signed in as `users(:system_admin)`,
  `Region.where(id: 1)` is empty (true today in fixtures — fixture invariant
  asserted up front). `get root_path` returns 200 (`assert_response :success`)
  and does NOT raise `ActionController::UrlGenerationError`. The body MUST
  contain a sibling Club Cloud submenu link to prove rendering succeeded
  past the Migration block (`assert_match /Meta Maps/, response.body`). The
  body MUST NOT contain any link with `nil` in the migration_cc URL — guard
  against accidental regression to the old hardcoded behavior
  (`assert_no_match %r{/regions//migration_cc}, response.body` — empty :id
  in the URL).
- **Test 2 (per-Region links present and correct):** same setup. The body
  MUST contain a `<a href="…/migration_cc">` for at least the NBV fixture
  (id 50_000_001, shortname `NBV`) — proving the iteration emits real
  per-Region links. Match: `assert_match %r{/regions/50000001/migration_cc},
  response.body`. Also assert the link label `>NBV<` appears, confirming
  `region.shortname` was used (not raw id, not name fallback).
- **Test 3 (no hardcoded Region[1] regression):** scan the rendered HTML for
  any `migration_cc_region_path(nil)`-style URL artifact. Specifically,
  `assert_no_match %r{/regions//migration_cc}, response.body`. If somebody
  in the future re-introduces a Region[1] lookup that returns nil and
  somehow doesn't crash (e.g., conditional fallback), this guards against
  the silent-bad-URL case.
  </behavior>
  <action>
Create a new integration test file at
`test/integration/left_nav_system_admin_test.rb`. Verbatim contents:

```ruby
# frozen_string_literal: true

require "test_helper"

# Regression guard for the Layer 3 fix landed alongside this file:
# `app/views/application/_left_nav.html.erb` previously had:
#
#     <li><%= link_to "Migration", migration_cc_region_path(Region[1]), ... %></li>
#
# When Region[1] was nil (test fixtures, fresh dev DBs, mid-migration), the
# call raised `ActionController::UrlGenerationError` and crashed the entire
# sidebar render for system_admin users.
#
# The original revision attempt wrapped the link in `if Region[1].present?`
# — REJECTED by the user: hiding the link doesn't let the admin pick which
# Region to migrate, and defaulting to a different Region would silently
# migrate the wrong data.
#
# The actual fix expands the single link into a nested Region-picker submenu:
# clicking "Migration" opens a sub-list of all Regions; each entry links to
# its own per-Region migration URL. These tests pin both the absence-of-crash
# property and the presence-of-per-Region-links property.
class LeftNavSystemAdminTest < ActionDispatch::IntegrationTest
  test "root_path renders 200 under system_admin without raising UrlGenerationError" do
    assert_nil Region.find_by(id: 1),
               "fixture invariant: Region[1] must be absent (NBV is at 50_000_001). " \
               "If this assertion fails, somebody added a Region at id=1 to the " \
               "fixtures — which is fine, but update the test accordingly."

    sign_in users(:system_admin)

    assert_nothing_raised do
      get root_path
    end
    assert_response :success

    # Sibling Club Cloud submenu links still render — the Migration block
    # didn't crash the layout.
    assert_match(/Meta Maps/, response.body,
                 "Club Cloud submenu must still render even when Region[1] is absent")
  end

  test "Migration submenu emits one link per Region using migration_cc_region_path(region)" do
    sign_in users(:system_admin)

    get root_path
    assert_response :success

    # The NBV fixture at id 50_000_001 must appear as a real per-Region link.
    # The path helper renders id=50_000_001 as `50000001` (no underscore in URL).
    assert_match(%r{/regions/50000001/migration_cc}, response.body,
                 "Migration submenu must emit a link to NBV's migration_cc URL")

    # The label must use Region#shortname (preferred) — `NBV` for the NBV fixture.
    # Match the literal `>NBV<` substring inside an anchor to avoid false
    # positives from class names / data attributes.
    assert_match(/>NBV</, response.body,
                 "Migration submenu must use region.shortname as the link label")

    # The Migration submenu button itself must be present.
    assert_match(/Migration/, response.body,
                 "Migration submenu button must render")
  end

  test "no broken /regions//migration_cc URL appears in rendered sidebar" do
    sign_in users(:system_admin)

    get root_path
    assert_response :success

    # Guard against any future regression that re-introduces a nil Region
    # lookup — even if the path helper somehow doesn't crash, an empty :id
    # segment in the URL is a smell that THIS test catches.
    assert_no_match(%r{/regions//migration_cc}, response.body,
                    "URL with empty :id segment indicates a nil Region was passed " \
                    "to migration_cc_region_path — regression to the original bug.")
  end
end
```

**Constraints / non-goals:**
- Per **LOCKED 4** (re-affirmed): NO edits to `test_helper.rb`, no new test
  base classes, no Gemfile changes, no `users.yml` changes. Use existing
  `:system_admin` fixture as-is.
- Per **LOCKED 3** (re-affirmed): approach (a) — `ActionDispatch::Integration
  Test` hitting `root_path`. NOT Capybara (heavier, brittle), NOT view-
  rendering in isolation (decoupled from the real layout chain).
- Use existing fixtures only; do not add new fixtures.
- Test class name `LeftNavSystemAdminTest` is intentional (descriptive, no
  namespace nesting — consistent with `tournament_verification_payload_
  serialization_test.rb`, `tiebreak_modal_form_wiring_test.rb`).
- The Test 1 `assert_nil Region.find_by(id: 1)` self-diagnostic catches a
  future fixture change: if somebody adds a Region at id=1 to `regions.yml`,
  the test fails with a clear message pointing the next maintainer at the
  fixture file.
- Tests rely on transactional fixtures (Rails Minitest default) — no manual
  teardown.
- We deliberately do NOT create any Regions inside the tests. The previous
  revision's plan had a "Test 2: Region.create!(id: 1, ...)" case; we
  remove that because (a) the new design doesn't depend on Region[1] and
  (b) the existing 4 fixtures already exercise the populated-iteration
  branch.
  </action>
  <verify>
    <automated>cd /Users/gullrich/DEV/carambus/carambus_bcw && bin/rails test test/integration/left_nav_system_admin_test.rb 2>&1 | tail -25</automated>
All three tests must pass:
- `test_root_path_renders_200_under_system_admin_without_raising_UrlGenerationError`
- `test_Migration_submenu_emits_one_link_per_Region_using_migration_cc_region_path(region)`
- `test_no_broken_/regions//migration_cc_URL_appears_in_rendered_sidebar`

Expected output footer pattern: `3 runs, N assertions, 0 failures, 0 errors,
0 skips`. If any test fails, root-cause before moving on (do NOT skip /
weaken assertions). The most likely failure modes and what they mean:

- "fixture invariant" → somebody added a Region at id=1 to the fixtures.
  Update the test, not the fix.
- "Migration submenu must emit a link to NBV's migration_cc URL" — the
  iteration didn't run; check `Region.order(:shortname, :name).each` is
  present in the ERB and the system_admin block is reached.
- "URL with empty :id segment" → a nil region somehow leaked into the
  iteration; check the each-block body uses `migration_cc_region_path(region)`
  not `migration_cc_region_path(Region[1])`.
- `UrlGenerationError` raised by Test 1 → Task 1's fix didn't apply or
  reverted; re-check the diff.
  </verify>
  <done>
File `test/integration/left_nav_system_admin_test.rb` exists, contains the
three tests described above, and all run GREEN. Without Task 1's fix, Test 1
would have failed with `ActionController::UrlGenerationError` and Test 2
would have failed with no `/regions/50000001/migration_cc` match — confirming
these are real regression guards, not tautologies.
  </done>
</task>

<task type="auto">
  <name>Task 3: Run regression sweep — new test + integration suite + 36B-06 system test</name>
  <files></files>
  <action>
Execute the regression sweep to confirm:
(a) the new test is GREEN (sanity re-run, in case ordering or fixture
    interaction with the broader integration suite differs from the isolated
    run),
(b) the existing integration suite has no NEW regressions,
(c) the 36B-06 system test (today's earlier 4/4 victory from quick-260506-o93)
    is still 4/4 GREEN.

Run these three commands sequentially and capture pass/fail counts for
SUMMARY.md:

```bash
cd /Users/gullrich/DEV/carambus/carambus_bcw

# (a) New test alone — confirms Task 2 didn't depend on isolation
bin/rails test test/integration/left_nav_system_admin_test.rb

# (b) Full integration suite — catches accidental side-effects via shared fixtures
bin/rails test test/integration

# (c) 36B-06 system test — protects today's earlier win
bin/rails test:system TEST=test/system/tournament_verification_modal_test.rb 2>&1 | tail -30
```

If 36B-06's filename has drifted, locate it via:
```bash
find test/system -name "*verification*" -o -name "*36B*" 2>/dev/null
```
Use the actual path from the find result. Intent: "the test that was at 4/4
at end-of-day 2026-05-06 per STATE.md line 31"; do not invent a name.

**Constraints:**
- Verification-only task. NO code edits, NO test edits.
- If (b) shows pre-existing failures unrelated to this change (e.g., the 19
  stale bk2_scoreboard failures noted in STATE.md line 119, or
  `test/integration/bk_param_latent_bugs_test.rb`), document them in
  SUMMARY.md as "pre-existing, not caused by this change". Confirm via
  `git stash` + rerun on the stashed tree if uncertain (and `git stash pop`
  after).
- A regression in 36B-06 is a STOP condition — root-cause before declaring
  done.
- A NEW failure in the integration suite caused by this change is also a
  STOP condition. Likely culprit if it happens: the new test pollutes the
  Region table via transactional fixtures interaction with sibling tests —
  but Test 2 in our file does NOT mutate the DB, so this is improbable.
  </action>
  <verify>
    <automated>cd /Users/gullrich/DEV/carambus/carambus_bcw && bin/rails test test/integration/left_nav_system_admin_test.rb && bin/rails test test/integration 2>&1 | tail -5</automated>
- (a) `3 runs, N assertions, 0 failures, 0 errors, 0 skips`.
- (b) Failures, if any, must be PRE-EXISTING and unrelated to
  `_left_nav.html.erb` / Region / system_admin. Document each in SUMMARY.md
  with file:line where possible.
- (c) `4 runs, N assertions, 0 failures, 0 errors, 0 skips` for 36B-06.
  </verify>
  <done>
Three sweeps completed. New test 3/3 GREEN. Integration suite has no NEW
failures attributable to this change. 36B-06 still 4/4 GREEN. Pass/fail
counts recorded for SUMMARY.md (assertion totals, runtime, any pre-existing
failures explicitly enumerated with file paths).
  </done>
</task>

</tasks>

<threat_model>

## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| HTTP request → view render | A signed-in `system_admin` user hitting any page that includes `_left_nav.html.erb` triggers the broken `migration_cc_region_path(Region[1])` call when Region[1] is nil. No untrusted INPUT crosses this boundary (the value comes from the local DB), but the OUTPUT is a 500 that takes down the whole layout. After the fix, the boundary still has no untrusted input, but now emits a usable per-Region picker. |
| User clicks per-Region migration link → controller action | An admin clicks a link emitted by the new submenu. The clicked URL contains a Region ID drawn from the local DB (server-rendered, not user-tampered). The controller action's authorization (filters in `regions_controller.rb`) gates whether the click actually triggers a migration. Out of scope for this task — we just emit links; the controller decides what to do with the click. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-260506-pha-01 | Denial of Service (D) | `_left_nav.html.erb` Migration link | mitigate | Replace hardcoded `Region[1]` lookup with iteration over `Region.order(:shortname, :name)`. Each rendered link is constructed from a concrete Region instance (provided by `each` block iterator), never nil. Eliminates `UrlGenerationError` regardless of Region[1]'s presence/absence. Empty-table case renders an empty submenu — no crash. |
| T-260506-pha-02 | Information Disclosure (I) | per-Region migration links | accept | The Migration submenu is system_admin-only (gated at line 141 `if current_user&.system_admin?`); enumerating Region IDs in the rendered HTML does not leak data to non-admins. Region IDs are also not secret — they appear elsewhere in the app (in URLs, in fixtures, in any list view). The migration_cc action itself (`def migration_cc; end`) is render-only and authorization-gated through controller filters elsewhere — out of scope. |
| T-260506-pha-03 | Tampering (T) | clicked Region in submenu | accept | An admin who clicks Region X's migration link triggers migration of Region X — exactly the desired behavior, and exactly why this fix shape was chosen over the rejected presence-guard. The "wrong region migrated" risk that the user flagged in their interrupt is now eliminated: the admin EXPLICITLY picks the region, no defaulting. |
| T-260506-pha-04 | Repudiation (R) | n/a | accept | No audit log changes, no PaperTrail surface — pure view + test-file additions. The migration_cc action's audit story is unchanged from before. |
| T-260506-pha-05 | Spoofing / Elevation of Privilege (S/E) | n/a | accept | The Club Cloud submenu visibility is unchanged (`if current_user&.system_admin?` gate untouched). Non-admins still cannot see or click these links. |

</threat_model>

<verification>

## Plan-Level Verification

After all 3 tasks complete:

1. **Diff check:**
   ```bash
   cd /Users/gullrich/DEV/carambus/carambus_bcw
   git diff --stat
   ```
   Expected: 2 files changed (`app/views/application/_left_nav.html.erb`
   modified, `test/integration/left_nav_system_admin_test.rb` added). NO
   other files touched. The view's diff replaces ONE `<li>` with a multi-line
   nested-submenu `<li>`; sibling `<li>`s untouched. Expect roughly +14 / -1
   lines for the view file.

2. **ERB lint:**
   ```bash
   bundle exec erblint app/views/application/_left_nav.html.erb
   ```
   No NEW errors (existing baseline issues, if any, are unrelated).

3. **Standard lint (the test file is new Ruby):**
   ```bash
   bundle exec standardrb test/integration/left_nav_system_admin_test.rb
   ```
   No errors.

4. **must_haves cross-check:**
   - [ ] `grep "migration_cc_region_path(region)" app/views/application/_left_nav.html.erb` returns 1 line
   - [ ] `! grep "migration_cc_region_path(Region\[1\])" app/views/application/_left_nav.html.erb` (no match)
   - [ ] `! grep "Region\[1\]\.present?" app/views/application/_left_nav.html.erb` (no match — covers a partial revision-1 leftover)
   - [ ] `grep "Region.order" app/views/application/_left_nav.html.erb` returns 1 line
   - [ ] The new submenu uses `data-action="sidebar#toggle"` and `data-sidebar-target="submenu"` (matching sibling pattern)
   - [ ] `test/integration/left_nav_system_admin_test.rb` exists and contains `users(:system_admin)`
   - [ ] `bin/rails test test/integration/left_nav_system_admin_test.rb` → 3/3 GREEN
   - [ ] `bin/rails test:system TEST=test/system/tournament_verification_modal_test.rb` → 4/4 GREEN
   - [ ] No edits to `test_helper.rb` / `application_system_test_case.rb` / `Gemfile` / `users.yml` (LOCKED 4)
   - [ ] No edits to `app/javascript/controllers/sidebar_controller.js` (Stimulus controller already supports nested collapsibles)

</verification>

<success_criteria>

This plan is complete when all of the following hold:

1. The Migration entry in `app/views/application/_left_nav.html.erb` has been
   replaced with a nested-collapsible Region-picker submenu: a button with
   `data-action="sidebar#toggle"` followed by a `<ul data-sidebar-target=
   "submenu">` that iterates `Region.order(:shortname, :name)` and emits one
   link per Region using `migration_cc_region_path(region)`.
2. NO reference to `Region[1]` remains in `_left_nav.html.erb`. NO reference
   to `Region[1].present?` remains either (defending against a leftover
   from the previous, rejected revision).
3. The Stimulus `sidebar_controller.js` is unchanged (its `nextElementSibling`
   approach already handles arbitrary nesting).
4. `test/integration/left_nav_system_admin_test.rb` exists with the three
   tests described in Task 2 and all run GREEN.
5. `bin/rails test test/integration` shows no NEW failures introduced by
   this change. Any pre-existing failures are explicitly identified in
   SUMMARY.md.
6. 36B-06 system test (`test/system/tournament_verification_modal_test.rb`
   or actual filename if it differs) is 4/4 GREEN — today's quick-260506-o93
   victory is preserved.
7. No edits to `test_helper.rb`, `application_system_test_case.rb`, `Gemfile`,
   `users.yml`, or any Stimulus / JS file (LOCKED 4 + extension: surgical
   scope; the JS controller already supports the new pattern).
8. Working tree clean except for the two intended files. `git diff --stat`
   shows exactly 2 paths.
9. Per **LOCKED 6**: commit per `/gsd-quick` default. Conventional-commit
   message, e.g.:
   `fix(left_nav): replace Region[1] Migration link with per-Region picker submenu`
   Body should:
   - mention the regression test path
   - mention the LOCKED-3 approach choice (integration test)
   - acknowledge the user's interrupt that corrected the fix shape (picker,
     not presence-guard)

</success_criteria>

<output>
After completion, create `.planning/quick/260506-pha-layer-3-fix-harden-left-nav-html-erb-156/260506-pha-SUMMARY.md` with:

- Commit hash(es) for the bcw checkout
- Test counts: new test (3/3), integration suite (X/Y, list any pre-existing
  failures with file:line), 36B-06 (4/4)
- The diff snippet for the `_left_nav.html.erb` change (the replaced `<li>`
  → nested submenu) — verbatim, so future maintainers can see what shape
  this fix took.
- Confirmation of the LOCKED constraints honored:
  - LOCKED 1 (revised by user interrupt): per-Region picker submenu, NOT
    presence-guard, NOT fallback. Quote the user's German interrupt verbatim
    in the SUMMARY for traceability:
    *"Der Migrationslink macht nur Sinn, mit 1 Region ID. Einen Default
    dort anzunehmen, geht nicht. Es soll ja auf eine ganz bestimmte Region
    migriert werden. Also muss dort eine Frage kommen, welche Region gemeint
    ist."*
  - LOCKED 2: only the Migration entry changed (sibling `<li>`s — Meta Maps,
    Region Ccs, Branch Ccs, … — unchanged in diff)
  - LOCKED 3: approach (a) integration test
  - LOCKED 4: zero touches to test_helper.rb / application_system_test_case.rb
    / Gemfile / users.yml / sidebar_controller.js (the controller is unchanged
    because nested collapsibles already worked)
  - LOCKED 5: scenario-management — operated in Debugging Mode in
    carambus_bcw, no cross-checkout sync attempted
  - LOCKED 6: committed per /gsd-quick default
- Pending Todos in STATE.md: mark "Layer 3 (production-edge bug, system_admin
  only)" as resolved with this commit hash; the v7.1 / 36B-06 saga from
  2026-05-06 is now fully closed.
- Note on UX outcome: system_admin users on any DB now have a working
  per-Region migration picker — a usability improvement, not just a crash
  fix. Worth highlighting because the original "presence-guard" fix would
  have left admins on fresh DBs with no migration UI at all.
</output>
</content>
</invoke>