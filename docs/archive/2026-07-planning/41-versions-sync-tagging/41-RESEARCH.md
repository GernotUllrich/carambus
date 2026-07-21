# Phase 41: Version-Sync Tagging — International Organizer Regions - Research

**Researched:** 2026-07-12
**Domain:** PaperTrail version-creation semantics + Carambus custom version-sync (`get_updates`/`for_region`) replication path
**Confidence:** HIGH (all core mechanisms verified by reading gem source + live read-only queries against the dev/authority-scenario DB; no library-version guessing involved)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Fix-Strategie**
- **Option A** (Daten-Fix), NICHT Option B (region-scoped tagging int. Turniere). Entscheidung User 2026-07-12.
- Der `global_context?`-Code-Fix (`when Region`-Case) ist als **separate Folge-Entscheidung** markiert und gehört NICHT in diese Phase. Der Daten-Fix darf NICHT über `region_taggings:update_all` / `global_context?` laufen (dessen `else false` für Region würde die kuratierte 1–17-Taggung regressieren = bekannter Footgun).

**Selektionskriterium (idempotent)**
- Betroffene Regions = alle `Region`, die Organizer (`organizer_type="Region"`, `organizer_id=<region.id>`) eines `region_id IS NULL`-`Tournament` ODER `-League` sind UND `global_context != true`.
- Lokal verifiziert (2026-07-12): trifft exakt UMB (Region 25, 433 global getaggte Turniere). Prod hat weitere int. Organizer-Regions im id-Bereich ~18–40 — der Task selektiert sie datengetrieben, nicht per Hardcode-Liste.

**Sync-Mechanik (User-Vorgabe 2026-07-12, kritisch)**
- Alle Local-Server werden über den **normalen Cron-Update-Zyklus** synchronisiert. KEIN manueller Per-Server-Re-Sync ab früherem `last_version_id`.
- ⇒ Der Fix MUSS mit **aktiviertem PaperTrail** speichern, sodass NEUE Version-Rows entstehen. Version-Tagging erfolgt via `RegionTaggable#update_version_region_data` (`region_taggable.rb:118-138`), das die Version aus der **`global_context`-SPALTE des Records** setzt (NICHT aus `global_context?`). D.h. `global_context`-Spalte true setzen + PaperTrail-getrackter Save ⇒ neue Version mit `global_context=true`.
- Bereits übersprungene int. Turniere (Cursor ist vorbei, z. B. Tournament 18488 / Version 13306420) erreichen die Locals nur über **frische Versionen** (Touch/save_with_version), in Reihenfolge **NACH** der jeweiligen Region (niedrigere Version-id zuerst), damit der `organizer` beim Apply schon existiert.
- Nuance für Planer/Research: `update!` ohne echte Attributänderung erzeugt KEINE Version — für die Region-Row ist die Spaltenänderung false→true die echte Änderung (ok); für Turniere ohne Attributänderung muss ein Version-Erzwingen (`paper_trail.save_with_version` / touch) genutzt werden.

**Ausführungsort & Zugang**
- Task läuft auf der Authority: `ssh api` → `cd carambus_api/current`.
- Prod-/Datenänderung erst nach ausdrücklicher User-Freigabe (Erhebung read-only zuerst).

### Claude's Discretion
- None explicitly delegated in CONTEXT.md beyond "task selects data-driven, not hardcoded list" (already a locked decision, not discretion).

### Deferred Ideas (OUT OF SCOPE)
- `RegionTaggable#global_context?` `when Region`-Case (schließt den `region_taggings:update_all`-Footgun; braucht Semantik-Entscheidung, damit deutsche 1–17-Kuratierung nicht regressiert).
- Region 11 (BVNRW) `gc=false` obwohl deutscher LV — separater Daten-Check.
- Handoff H2 (branch_id) → Phase 42; Handoff H3 (Disziplin-Baum) → Phase 43 (je eigene offene fachliche Fragen).
</user_constraints>

## Summary

This phase is a **data-fix + forced-redelivery task** running on the Authority (api.carambus.de), not a UI or library-integration phase. All eight uncertainty questions in the brief were resolved by reading PaperTrail 15.2.0 gem source directly (`bundle show paper_trail` → `~/.rbenv/.../paper_trail-15.2.0`) and cross-checking against live read-only queries on the dev checkout, which — critically — runs in the exact same "authority scenario" as production (`Carambus.config.carambus_api_url` is blank, so `ApplicationRecord.local_server?` is `false`, `has_paper_trail` is active, `PaperTrail.request.enabled?` is `true`). This makes the dev DB a faithful stand-in for verifying mechanism (not data volume — prod has more affected regions ~18-40).

**Primary recommendation:** Two-step, both PaperTrail-tracked, both idempotent by construction:
1. `region.update!(global_context: true)` for every Region matching the locked selection criterion — a real column change, so PaperTrail's normal `after_update` → `after_save` chain fires, and `RegionTaggable#update_version_region_data` (which runs strictly *after* PaperTrail's own version-creation callback, guaranteed by Rails' `after_update`-before-`after_save` ordering, not by include order) copies `global_context=true`/`region_id` onto the version row it just created.
2. For tournaments/leagues that are permanently stuck (their last version predates the region fix and nothing will naturally re-touch them), force one fresh version each via `tournament.touch` — the gem's `Events::Update#changed_notably?` has an explicit special case (`if @is_touch && changes_in_latest_version.empty? then true`) that guarantees a version is created even with zero attribute diff, with the *full* `object` snapshot (not `object_changes`), which the client-side apply code (`version.rb:419-424,455-459`) already knows how to consume as a fallback.

Both steps run inside a single rake task on the authority; propagation is fully automatic afterward via the existing hourly `carambus:retrieve_updates` cron (`config/schedule.rb:189-191`) — no per-server re-sync needed, matching the locked constraint.

## Core Mechanism Findings (resolves brief's 8 open questions)

### Q1 — Version tagging path (authoritative)

**Confirmed mechanism**, `[VERIFIED: gem source + region_taggable.rb + live query]`:

- `RegionTaggable#update_version_region_data` (`app/models/concerns/region_taggable.rb:118-138`) is an `after_save` callback. It does:
  ```ruby
  return unless PaperTrail.request.enabled?
  record_versions = self.versions rescue []
  if record_versions.any?
    latest_version = record_versions.last
    if latest_version && previous_changes.present?
      latest_item = latest_version.item        # <-- the LIVE record, reloaded via the polymorphic `item` association
      region_id = latest_item.region_id if latest_item.respond_to?(:region_id)
      global_context = latest_item.global_context if latest_item.respond_to?(:global_context)
      latest_version.update_columns(region_id: region_id, global_context: global_context) ...
    end
  end
  ```
  `latest_version.item` is PaperTrail's standard polymorphic `belongs_to :item` association — it re-queries the record by `item_type`/`item_id`, i.e. it reads the **current, post-save column values**, not `global_context?` (the derived predicate method). This is exactly what CONTEXT.md asserts, confirmed by code reading (no runtime instrumentation needed — the code path is unambiguous).
- **Callback ordering is NOT determined by `include` order** (LocalProtector included before RegionTaggable in Region/Tournament/League) — it is guaranteed by Rails' AR callback chain: `after_create`/`after_update` (where PaperTrail's own `record_create`/`record_update` are hooked, see `model_config.rb:39-44,64-81`) always fire **before** `after_save` callbacks, regardless of definition order. So `update_version_region_data` (an `after_save`) is guaranteed to see the version PaperTrail just created in the preceding `after_update`/`after_create` phase. `[VERIFIED: Rails AR callback semantics — well-documented invariant, not dependent on this app's registration order]`
- **The UMB nuance** (Region 25's `region_id` COLUMN is `nil` while `find_associated_region_id` returns `25`): confirmed live —
  ```
  Region 25: region_id=nil, global_context=false   (find_associated_region_id would return 25, but that method is NEVER called by update_version_region_data)
  ```
  `update_version_region_data` reads `latest_item.region_id` — the **column**, not the derived id. Region 25's `region_id` column is `nil` (this column means "which region is *this* Region record itself scoped under" — for a top-level international body like UMB, that's correctly `nil`, i.e. "not scoped to any single German Landesverband"). This is unrelated to `find_associated_region_id` (which is used by the *rake task* `region_taggings:update_all`, not by the after_save hook). **No other code path writes `region_id:`/`global_context:` onto a version** — grepped for `region_id:` / `global_context:` writes on `Version`/`PaperTrail::Version` across `app/` and `lib/`; only `region_taggable.rb:130-133` and the reference-only `lib/tasks/region_taggings.rake:107-114` (`update_all`, explicitly excluded by the locked decision) do this. `[VERIFIED: grep -rn "region_id:\|global_context:" app/ lib/]`

### Q2 — PaperTrail enabled in rake/runner context

**Yes, by default**, `[VERIFIED: live rails runner query on dev checkout, same scenario as authority]`:
```
carambus_api_url: nil
Region.paper_trail_options: {:skip=>["#<Proc:...>"], :on=>[:create, :update, :destroy, :touch], :ignore=>[], :only=>[], :meta=>{}}
PaperTrail.request.enabled?: true
PaperTrail.enabled?: true
```
No `PaperTrail.request(enabled: true)` wrapper is required in a `rails runner`/rake task context — it's `true` by default at boot and nothing in this app's initializers disables it outside of request-scoped middleware (which doesn't apply to a runner/rake process). **Recommendation:** the task should still assert this defensively (`raise "PaperTrail disabled!" unless PaperTrail.enabled? && PaperTrail.request.enabled?`) so a future regression fails loudly instead of silently no-op-ing the whole fix.

### Q3 — `has_paper_trail` tracked events; does touch create a version?

`[VERIFIED: paper_trail-15.2.0 gem source, `lib/paper_trail/model_config.rb:109`]`: `has_paper_trail`'s default is `options[:on] ||= %i[create update destroy touch]` — **`:touch` is tracked by default**, confirmed live: `Region.paper_trail_options[:on] == [:create, :update, :destroy, :touch]` (same for `Tournament`, `League`).

**Important side-finding, not in the original brief:** `LocalProtector` (`app/models/local_protector.rb:9-21`) calls `has_paper_trail(skip: lambda { |obj| ... })` intending "skip creating a version if only `updated_at`/`sync_date` changed." **This lambda does nothing** — `ModelConfig#event_attribute_option` (`model_config.rb:211-216`) does `.map { |attr| ... attr.to_s }` on whatever is passed to `skip:`, so the Proc gets stringified into `"#<Proc:0x...>"` and stored in a one-element array that never matches any real column name (`[VERIFIED: Region.paper_trail_options[:skip] => ["#<Proc:0x000000010c776f48 .../local_protector.rb:10 (lambda)>"]`, i.e., `PaperTrail`'s `skip:` option is a *column-name allowlist*, not a version-suppression predicate — the author of `local_protector.rb` used the wrong option shape). **Consequence for this phase (favorable):** the "skip lambda" cannot interfere with our forced `.touch` calls — nothing filters them out.

**Does a bare `record.touch` create a version despite zero attribute diff?** Yes — `Events::Update#changed_notably?` (`paper_trail/events/update.rb:46-52`) special-cases this:
```ruby
def changed_notably?
  if @is_touch && changes_in_latest_version.empty?
    true          # <-- forces version creation for a plain touch, by design
  else
    super
  end
end
```
This is the exact gem-documented mechanism for redelivering unchanged records (the gem's own comment: "If it is a touch event, and changed are empty, it is assumed to be implicit `touch` mutation, and a version is created."). `record_object_changes?` is hard-coded `false` for touch (`!@is_touch && super`), so the resulting version has **no `object_changes`**, only a full `object` snapshot — which the sync-apply loop already handles as its fallback path (see Q5).

**Correct primitive to force a version:** `tournament.touch` (simplest — uses the gem's built-in `on: touch` support) **or** `tournament.paper_trail.save_with_version` (`record_trail.rb:152-157`, the gem's explicit "force a version regardless of `:on`/`:if`/`:unless`" API). Recommendation: **use `.touch`** — it is the narrower, better-tested code path for "no real change, force a version" and does not additionally toggle `PaperTrail.request(enabled: false)` internally the way `save_with_version` does.

### Q4 — Redelivery ordering

`[VERIFIED: app/controllers/versions_controller.rb:105-125, app/models/version.rb:347-349]`. Server side: `get_updates` does `Version.where("id > ?", last_version_id).for_region(region_id).order(id: :asc).limit(20_000)` — strictly ascending by `id`. Client side (`Version.update_from_carambus_api`, `version.rb:347-349`): `while vers.present? do h = vers.shift; ... end` — `.shift` consumes the array front-to-back, i.e., in the same ascending order the server returned it, and `Setting.key_set_value("last_version_id", last_version_id)` advances the cursor one version at a time inside the same `while` loop. **Conclusion confirmed:** creating the Region's `global_context=true` version first (in the same task run), then forcing Tournament/League versions afterward, guarantees Region's version id < Tournament's version id (both draw from the same Postgres sequence), so any regional server applying updates in order will always resolve the `organizer` before hitting the tournament create/update. This holds across multiple sequential `get_updates` calls too, since the cursor only moves forward.

### Q5 — Do tournaments need re-tagging, or just a fresh version?

**Just a fresh version — confirmed by live data, not just theory.** All 45 existing versions of Tournament 18488 (and, by the region's own `region_id`/`global_context` columns, all 433 UMB-organized tournaments) already have `region_id: nil, global_context: false` consistently — this is *already correct* tagging (a `nil` `region_id` on the version matches the `region_id IS NULL` branch of the `for_region` scope, i.e. "replicate to everyone"). The apply failure was never about the *tournament's* version tag — it was 100% about the missing organizer Region locally. `[VERIFIED via `bin/rails runner`, read-only, dev DB]`.

Apply-path confirmation (`version.rb` "update" branch, ~418-468): when `object_changes` is blank (true for a touch-forced version), the code falls to `YAML.load(h["object"])` for **both** the "object exists locally" and "object doesn't exist locally" sub-branches — i.e. the full snapshot is always used, so a `.touch`-forced redelivery re-creates/re-updates the tournament with its complete, valid, current attribute set (organizer now resolvable once the region fix has propagated). **Idempotent behavior on a server that already has the tournament:** the "update" branch's `obj.present?` path does `args.each { |k,v| obj.write_attribute(k,v) }; obj.valid? ...; obj.update_columns(args)` — a full-snapshot re-write of an already-correct record is a safe no-op (same values written back).

### Q6 — Scale & batching; narrower set possible?

**Empirical finding not anticipated in the brief:** not all 433 UMB tournaments are equally "stuck." A live query shows only **54 of 433** tournaments organized by Region 25 have had a version created in the last 7 days — traced via `whodunnit` to `Umb::FutureScraper` / `lib/tasks/umb_update.rake` (a scraper that refreshes **upcoming** tournaments' `data` daily, auto-creating fresh versions). The remaining ~379 (already-completed historical international tournaments) get **no natural future version** — they are the ones that genuinely need a forced `.touch`.

**Recommendation:** don't special-case "already fresh vs. stuck" — simplest, safest, and still idempotent is to force `.touch` on **every** tournament/league matching the selection criterion's organizer set (`region_id IS NULL`, `organizer_type="Region"`, `organizer_id IN <affected_region_ids>`) in the same task run, but make the touch step itself idempotent on re-run by comparing timestamps: only touch a tournament if `tournament.versions.maximum(:created_at)` is older than the corresponding region's just-created global_context-fix version's `created_at` (i.e., "this tournament hasn't been re-versioned since its organizer became visible"). Concretely:
```ruby
region_fix_time = region.versions.where(event: "update").where("global_context = TRUE").order(:id).last.created_at
Tournament.where(organizer_type: "Region", organizer_id: region.id, region_id: nil).find_each do |t|
  next if t.versions.maximum(:created_at)&.> region_fix_time
  t.touch
end
```
This makes a second task run a true no-op for tournaments (nothing to touch, since their latest version now postdates the region fix), satisfying re-run safety without needing a separate marker/Setting key. Volume for UMB alone: ~379 forced touches (prod, across ~18-40 region range, will be a low multiple of that — data-driven, not hardcoded).

### Q7 — Verification without a test DB

Two verified paths, both already demonstrated read-only in this research session:
- **Authority side (read-only query, safe):** `Region.find(<id>).versions.last.attributes.slice("id","event","region_id","global_context")` — confirms the fix version was created with `global_context: true`. Also: `Version.maximum(:id)` before/after, to bound the ordering claim in Q4.
- **HTTP path (per the handoff doc), unauthenticated `get_updates` GET** — `versions_controller.rb:6` explicitly exempts `get_updates`/`last_version`/`current_revision`/`update_carambus` from the `system_admin_only` gate (H33 fix, `d44c88cc`), so this remains reproducible exactly as documented: `GET .../versions/get_updates?last_version_id=<one less than the region fix version id>&region_id=<affected local region>` should now return the Region version with `global_context: true` (or, if queried without `region_id`, just its presence in the un-filtered list).
- **Local-server side (post-cron, not doable from the authority):** `Region.exists?(<id>)` should flip to `true`; look for `Thread.current[:carambus_sync_apply_failures]` entries for the previously-failing tournament ids disappearing from subsequent `[Version.sync] APPLY FAILED` log lines (`version.rb:473`).
- **Existing tests to model from:** `test/models/version_test.rb` already covers `Version.safe_parse`/`safe_parse_for_text_column`/`coerce_serialized_args!`/`update_from_carambus_api` round-trips (unit + one HTTP-stubbed integration test using `stub_request`). **No existing test touches `for_region`, `RegionTaggable`, or `global_context`** — this phase's tests will be net-new. `test/test_helper.rb:107-115` already provides the exact scenario gate needed: `skip_unless_api_server` (skips unless `Carambus.config.carambus_api_url` is blank — i.e., runs exactly in the scenario where `has_paper_trail` is active). `[VERIFIED: grep -rln "for_region\|get_updates\|global_context\|RegionTaggable" test/]`

### Q8 — Validation Architecture

See dedicated section below.

## Additional confirmed context (not explicitly asked, materially affects the plan)

**The standard cron cycle referenced in the locked decision is real and already scheduled**, `[VERIFIED: config/schedule.rb:185-191, lib/tasks/carambus.rake:297-303]`:
```ruby
# config/schedule.rb
every 1.hour, roles: [:local] do
  rake "carambus:retrieve_updates"
end

# lib/tasks/carambus.rake
task retrieve_updates: :environment do
  args = Carambus.config.context.present? ? { region_id: Region.find_by_shortname(Carambus.config.context)&.id } : {}
  (1..10).each.map { |i| Version.update_from_carambus_api(args) }
end
```
Every regional server's `Carambus.config.context` (its own region shortname, e.g. "NBV") resolves to a `region_id` that IS passed to `get_updates`, which activates `.for_region(region_id)` server-side. This is the exact mechanism the bug and fix both hinge on — confirmed to run **hourly**, not daily. Once the Region fix version + forced Tournament touches exist on the authority, **every** regional server will pick them up within the hour, fully automatically, satisfying the locked "no manual per-server re-sync" constraint.

**LocalProtector will not block the Region fix save on the authority**, `[VERIFIED: app/models/application_record.rb:69-77, live query `ApplicationRecord.local_server? => false` on this checkout]`: `disallow_saving_global_records` only raises `ActiveRecord::Rollback` when `id < MIN_ID && ApplicationRecord.local_server? && !unprotected`. `local_server?` is `Carambus.config.carambus_api_url.present?` — the *same* condition that gates `has_paper_trail` in `LocalProtector` (`unless Carambus.config.carambus_api_url.present?`). These two conditions are complements of each other by construction: **PaperTrail is active exactly when `LocalProtector`'s save-blocking guard is inactive.** So on the authority, `region.update!(global_context: true)` needs no `unprotected = true` flag and will not be rolled back, while still creating a version (the opposite is true on a regional server: saves to global records are blocked, and PaperTrail is inactive — consistent with "only the authority produces versions").

## Standard Stack (internal APIs — not third-party)

This phase touches no new gems. The "stack" is 100% existing app + gem internals used correctly:

| API | Location | Purpose | Why this one |
|---|---|---|---|
| `region.update!(global_context: true)` | ActiveRecord, standard | Real attribute change → triggers normal PaperTrail `after_update` version creation | Simplest, uses existing `on_update` callback path, no special-casing needed |
| `record.touch` | ActiveRecord + PaperTrail `on_touch` | Force a version for an unchanged record | Gem-default-enabled (`on: touch`), narrow/well-tested `changed_notably?` special-case, no `object_changes`, full `object` fallback already handled by apply loop |
| `record.paper_trail.save_with_version` | `paper_trail/record_trail.rb:152` | Alternative force-a-version API | Documented gem method; **not** recommended over `.touch` here because it additionally toggles `PaperTrail.request(enabled: false)` around the inner `.save`, an extra moving part not needed for this use case |
| `RegionTaggable#update_version_region_data` | `app/models/concerns/region_taggable.rb:118` | Already-existing `after_save` hook that tags the version | Do not duplicate this logic in the new task — it fires automatically on any tracked save |
| `Region.paper_trail_options`, `PaperTrail.request.enabled?`, `PaperTrail.enabled?` | gem introspection | Defensive assertions in the task | Fail loudly if PaperTrail is somehow disabled in the run context |

**Version verification:** `paper_trail (15.2.0)` confirmed via `bundle show paper_trail` / `Gemfile.lock:519` — no upgrade involved in this phase, purely usage of existing pinned version.

## Architecture Patterns

### Recommended task shape (single rake task, two ordered steps, both idempotent)

```
lib/tasks/region_taggings.rake   (extend, do NOT touch existing `update_all`/`tag_with_gobal_context` tasks)
  namespace :region_taggings do
    desc "Phase 41: tag international organizer Regions global_context=true (PaperTrail-tracked) + redeliver stuck international tournaments/leagues"
    task fix_international_organizer_context: :environment do
      raise "Run only on the Authority" if ApplicationRecord.local_server?
      raise "PaperTrail must be enabled" unless PaperTrail.enabled? && PaperTrail.request.enabled?

      # Step 1 — idempotent selection + fix (locked criterion, verbatim from CONTEXT.md)
      affected_region_ids =
        (Tournament.where(region_id: nil, organizer_type: "Region").distinct.pluck(:organizer_id) +
         League.where(region_id: nil, organizer_type: "Region").distinct.pluck(:organizer_id)).uniq
      regions_to_fix = Region.where(id: affected_region_ids).where.not(global_context: true)

      regions_to_fix.find_each do |region|
        region.update!(global_context: true)   # real attribute change -> new version, tagged by RegionTaggable automatically
        fix_version = region.versions.order(:id).last
        # Step 2 — force redelivery for tournaments/leagues organized by this region,
        # idempotent via version-recency comparison (see Q6)
        [Tournament, League].each do |klass|
          klass.where(organizer_type: "Region", organizer_id: region.id, region_id: nil).find_each do |rec|
            last_v_time = rec.versions.maximum(:created_at)
            next if last_v_time && last_v_time > fix_version.created_at
            rec.touch
          end
        end
      end
    end
  end
```

### Anti-Patterns to Avoid
- **`update_all` for the Region fix:** bypasses ActiveRecord callbacks entirely — no PaperTrail version, no propagation, silently defeats the whole phase. This is the exact footgun in `region_taggings.rake:107-114`'s `tag_with_gobal_context`/`tag_with_region` helpers — read as reference only, never call.
- **Calling `record.global_context?`** to decide the fix — it's a different, narrower predicate (`organizer&.shortname == "DBU"`) with a missing `when Region` case; explicitly deferred out of this phase. The fix must set the **column**, not rely on this method.
- **`PaperTrail.request(enabled: false)` anywhere in this task** — would silently make the entire fix a no-op (no version, no propagation), the opposite of the locked constraint.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Forcing a version on an unchanged record | Custom "insert a Version row manually" SQL/ActiveRecord `Version.create!(...)` | `record.touch` | Gem already has this exact use case built in (`Events::Update#changed_notably?` touch special-case) with correct `object`/`object_changes` semantics that the existing apply loop already understands |
| Tagging the new version's `region_id`/`global_context` | Custom callback or manual `version.update_columns(...)` after save | Nothing — `RegionTaggable#update_version_region_data` already does this automatically for any tracked save | Duplicate logic risks drifting from the one true mechanism; the existing hook is already correct once the underlying column is set |
| Verifying propagation without a test DB | A new HTTP client/script | The exact `Net::HTTP` + `get_updates?last_version_id=` pattern already in the handoff doc and in `Version.http_get_with_ssl_bypass`/`Version.parse_api_json` | Already-tested, already-hardened (H33) helpers exist |

**Key insight:** every mechanism this phase needs (forced versioning, version tagging, ordered redelivery, HTTP verification) already exists correctly in the codebase or the gem — the "fix" is 100% a data operation using existing primitives correctly, not new code beyond a rake task.

## Common Pitfalls

### Pitfall 1: Using `update_all` "for speed" on a large tournament set
**What goes wrong:** No version created, nothing propagates, and the fix silently "succeeds" (data changes locally) while the actual bug persists everywhere else.
**Why it happens:** `update_all`/`update_columns` are the obvious tools for bulk data fixes, and the existing `region_taggings.rake` reference pattern uses exactly this (for a different, callback-order-agnostic use case).
**How to avoid:** Every mutation in this phase must go through instance-level `.update!`/`.touch`/`.save` so AR callbacks (and thus PaperTrail) fire.
**Warning signs:** `region.versions.count` doesn't increase after the "fix" runs.

### Pitfall 2: Assuming `skip:` lambda in `LocalProtector` suppresses touch-created versions
**What goes wrong:** Believing that forcing a `.touch` is unreliable because "there's a skip filter for timestamp-only changes."
**Why it happens:** The comment in `local_protector.rb:6-8` explicitly claims this behavior.
**How to avoid:** Verified: the lambda is stringified into a harmless no-op array entry — it does not filter anything. Confirmed via `Region.paper_trail_options[:skip]` introspection. Do not "fix" this bug as part of this phase (out of scope) but be aware it does not block the plan.

### Pitfall 3: Forgetting `where.not(global_context: true)` allows re-running to re-fix already-fixed regions
**What goes wrong:** A second run of the region-fix step re-saves already-`true` regions, wasting a version (harmless, but noisy and violates the stated idempotency goal).
**Why it happens:** Easy to write the selection query without the negative filter.
**How to avoid:** Selection criterion as locked in CONTEXT.md already includes `global_context != true` — keep it as the WHERE clause, not just a diagnostic.

### Pitfall 4: Forcing tournament touches unconditionally on every run (defeats idempotency for step 2)
**What goes wrong:** Second run re-touches all ~379+ tournaments per region, every time the task is invoked, generating unbounded Version growth.
**Why it happens:** It's the simplest code to write ("just touch everything matching the criterion").
**How to avoid:** Compare `rec.versions.maximum(:created_at)` against the region's fix-version `created_at` (see Q6/Architecture) so a second run finds nothing left to touch.

## Code Examples

### Verifying the mechanism (read-only, safe to run on authority before any write)
```ruby
# Source: this research session, live query against dev checkout (authority scenario)
sel_tournament_region_ids = Tournament.where(region_id: nil, organizer_type: "Region").distinct.pluck(:organizer_id)
sel_league_region_ids     = League.where(region_id: nil, organizer_type: "Region").distinct.pluck(:organizer_id)
affected = Region.where(id: (sel_tournament_region_ids + sel_league_region_ids).uniq).where.not(global_context: true)
affected.pluck(:id, :name, :shortname, :global_context)
# => [[25, "Union Mondiale de Billard", "UMB", false]]   (dev; prod will include ~18-40 range per handoff doc)
```

### Forcing a version with no attribute diff (verified gem source, `paper_trail/events/update.rb:46-52`)
```ruby
# tournament.touch triggers after_touch -> record_update(force:false, is_touch:true)
# -> changed_notably? special-cases is_touch + empty diff to `true` -> version IS created
# -> record_object_changes? is hard-coded false for touch -> object_changes blank, full `object` snapshot stored
tournament.touch
tournament.versions.last.object_changes.present?  # => false
tournament.versions.last.object.present?          # => true (full YAML snapshot)
```

## State of the Art

| Old Approach (reference pattern in codebase) | Current/Recommended Approach | When Changed | Impact |
|---|---|---|---|
| `region_taggings.rake:106-114` `tag_with_gobal_context`/`tag_with_region` via `update_all` | Instance-level `.update!`/`.touch` so PaperTrail fires | This phase (locked decision, Option A) | Only instance-level saves propagate through the normal sync cron; `update_all` is DB-local only |
| Manual per-server re-sync from an earlier `last_version_id` (Option in the original handoff, `CARAMBUS-API-GLOBAL-CONTEXT-REGIONS-HANDOFF.md:69-70`) | Rely on existing hourly `carambus:retrieve_updates` cron | Locked decision 2026-07-12 | Simpler, no manual per-server operations, consistent with "propagation happens via the normal channel" |

**Deprecated/outdated:** The handoff doc's original "Option A" description (`...Danach ein Re-Sync der Local-Server ab einem früheren last_version_id...`) is explicitly superseded by the locked decision — no re-sync step, cron handles it.

## Runtime State Inventory

**Skipped** — this phase is a data-tagging/sync-mechanics fix, not a rename/refactor/migration phase (no strings being renamed across stored data/live config/OS state/secrets/build artifacts). The "Runtime State Inventory" trigger (rename/refactor/migration) does not apply.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Production's `Carambus.config.carambus_api_url` is blank on api.carambus.de (making it the "authority" in the same sense as this dev checkout), and `local_server?` there is `false` | Additional confirmed context | If wrong, `has_paper_trail` would not be active in prod at all, and the entire fix mechanism would need re-verification directly on prod before running (read-only check recommended as first plan step: `Carambus.config.carambus_api_url` and `Region.paper_trail_options` on the authority itself) |
| A2 | Prod's affected-region count/id range (~18-40) matches the handoff doc's estimate; the selection query will find more than just UMB in prod | Selection criterion (locked, from CONTEXT.md) | Low risk — the query is data-driven, not hardcoded, so it will correctly find whatever is actually in prod regardless of this estimate being off |
| A3 | The hourly `carambus:retrieve_updates` cron via `config/schedule.rb:189-191` is actually deployed and running on all production regional servers as configured (not just present in this repo's config) | Additional confirmed context | If some regional servers have a stale/disabled cron, they would not receive the fix automatically — worth a quick post-fix spot-check on 1-2 regional servers, not a plan blocker |

**All other claims in this document are `[VERIFIED]`** via direct gem source reading (`paper_trail-15.2.0`) or live read-only `rails runner`/grep queries against the dev checkout, which itself runs in the authority scenario (`carambus_api_url` blank) — not `[ASSUMED]`.

## Open Questions

1. **Exact production affected-region list**
   - What we know: locally, exactly Region 25 (UMB) matches; the handoff doc estimates id range ~18-40 has more.
   - What's unclear: the precise list/count on production until the read-only selection query is run there.
   - Recommendation: plan's first executable step should be running the **read-only** selection query on the authority and presenting the list for explicit user sign-off before any `.update!`/`.touch` runs (per CONTEXT.md: "Prod-/Datenänderung erst nach ausdrücklicher User-Freigabe").

2. **Volume of forced tournament/league touches in production**
   - What we know: locally ~379 of 433 UMB tournaments would need forcing (the rest self-heal via the daily UMB future-scraper).
   - What's unclear: exact prod volume across all affected regions; could be several thousand touches total.
   - Recommendation: run the touch step in batches (`find_each`, already used in the recommended code) to avoid one giant transaction; no need for a background job given `find_each`'s built-in batching is sufficient for this one-time authority-side operation.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| SSH access to authority (`ssh api`) | Running the task in prod | Assumed ✓ (per CONTEXT.md execution instructions) | — | — |
| `bin/rails runner` / rake on authority | Task execution | ✓ (standard Rails app tooling, already used by existing `carambus.rake`/`region_taggings.rake` tasks) | Rails 7.2.0.beta2 | — |
| PostgreSQL (authority DB) | Region/Tournament/Version reads+writes | ✓ (already required by the app) | — | — |
| `get_updates` HTTP endpoint reachability | Q7 verification path | ✓ (exempted from `system_admin_only` gate per `versions_controller.rb:6`, confirmed working post-H33) | — | — |

No missing dependencies identified; this phase introduces no new external tooling.

## Validation Architecture

### Test Framework
| Property | Value |
|---|---|
| Framework | Minitest (Rails default), per `CLAUDE.md` — NOT RSpec |
| Config file | `test/test_helper.rb` |
| Quick run command | `bin/rails test test/models/region_taggable_sync_test.rb` (new file, see Wave 0 gaps) |
| Full suite command | `bin/rails test` (or `bin/rails test:critical` for the concerns+scraping subset) |

### Phase Requirements → Test Map

No formal `REQUIREMENTS.md` IDs exist for Phase 41 (checked — file predates this phase, last touched 2026-06-09). Behaviors to validate, derived from the locked decisions/CONTEXT.md:

| Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|
| Selection criterion returns exactly the Regions matching the locked WHERE clause | unit | `bin/rails test test/models/region_taggable_sync_test.rb -n /selection/` | ❌ Wave 0 |
| `region.update!(global_context: true)` creates a new version tagged `global_context: true`, `region_id` = record's own `region_id` column | unit (`skip_unless_api_server`) | `bin/rails test test/models/region_taggable_sync_test.rb -n /global_context_true/` | ❌ Wave 0 |
| Second run of the selection query (after the fix) returns zero regions (idempotency) | unit | same file, `-n /idempotent/` | ❌ Wave 0 |
| `tournament.touch` creates a version with blank `object_changes` and populated `object` | unit (`skip_unless_api_server`) | same file, `-n /touch_forces_version/` | ❌ Wave 0 |
| Redelivered tournament version (no organizer locally) applies successfully via `Version.update_from_carambus_api` once the Region version has been applied first | integration (mirrors existing `test/models/version_test.rb` "round-trips" pattern with `stub_request`) | `bin/rails test test/models/version_test.rb` (extend, or new file) | ❌ Wave 0 (new test case) |
| Rake task `region_taggings:fix_international_organizer_context` runs end-to-end against fixtures, is a no-op on second invocation | task test, modeled on `test/tasks/auto_reserve_tables_test.rb` | `bin/rails test test/tasks/region_taggings_test.rb` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `bin/rails test test/models/region_taggable_sync_test.rb test/tasks/region_taggings_test.rb`
- **Per wave merge:** `bin/rails test test:critical` (concerns + scraping, per `CLAUDE.md`)
- **Phase gate:** Full suite (`bin/rails test`) green before `/gsd-verify-work`; plus the read-only production selection-query sign-off (Open Question 1) before any prod mutation.

### Wave 0 Gaps
- [ ] `test/models/region_taggable_sync_test.rb` — new file, covers selection criterion, version tagging mechanism, idempotency, touch-forces-version. Model callback/scenario setup on `skip_unless_api_server` (`test/test_helper.rb:107-109`), exactly as `version_test.rb`'s HTTP-stub test already does for the sibling scenario gate.
- [ ] `test/tasks/region_taggings_test.rb` — new file, models the rake-task test pattern from `test/tasks/auto_reserve_tables_test.rb` (`Rails.application.load_tasks`, `Rake::Task[...].invoke`, `.reenable` in teardown).
- [ ] Fixtures: use IDs `>= Table::MIN_ID`-style base offsets already established in `auto_reserve_tables_test.rb` (e.g. `REGION_BASE_ID = 52_000_2xx`) for created test Regions/Tournaments/Leagues so `LocalProtectorTestOverride` behavior stays consistent with existing test conventions; do NOT reuse production ids like `25`/`18488` in fixtures.
- [ ] No framework install needed — Minitest + WebMock + FactoryBot already wired in `test_helper.rb`.

## Security Domain

`security_enforcement` not set to `false` in `.planning/config.json` (absent under `workflow` block in the read config) → treated as enabled, per instructions.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No | Task runs via authenticated SSH shell access on the authority, not through any HTTP-authenticated surface |
| V3 Session Management | No | No session-based surface touched |
| V4 Access Control | Indirect | `get_updates`/`last_version`/`current_revision` are already deliberately exempted from `system_admin_only` (machine-to-machine sync endpoints, `versions_controller.rb:6`, H33 fix) — this phase does not change that gate, only the data these endpoints return |
| V5 Input Validation | No new surface | The selection query and forced touches run entirely server-side via `rails runner`/rake, no new user input path |
| V6 Cryptography | N/A | Not touched |

### Known Threat Patterns for this stack
None applicable — this is an internal data-consistency fix executed via authenticated shell access on a single trusted server, with no new externally-reachable code path. The one pre-existing, already-mitigated concern (unauthenticated `get_updates`) predates this phase and is explicitly out of scope (already fixed under H33, `d44c88cc`).

## Sources

### Primary (HIGH confidence)
- `paper_trail` gem 15.2.0 source, installed locally: `~/.rbenv/versions/3.2.1/lib/ruby/gems/3.2.0/gems/paper_trail-15.2.0/lib/paper_trail/{model_config.rb,record_trail.rb,events/{base.rb,update.rb}}` — read in full for callback ordering, `on:` defaults, `skip:` option semantics, `changed_notably?`/touch special-case, `save_with_version`.
- `app/models/concerns/region_taggable.rb`, `app/models/version.rb`, `app/models/local_protector.rb`, `app/models/application_record.rb`, `app/controllers/versions_controller.rb`, `lib/tasks/region_taggings.rake`, `lib/tasks/carambus.rake`, `config/schedule.rb` — read in full.
- Live read-only `bin/rails runner` queries against the dev checkout (same "authority" scenario as production: `carambus_api_url` blank) — confirmed `PaperTrail.request.enabled?`, `paper_trail_options`, Region 25 / Tournament 18488 exact state, selection-query result, version history/ordering for Tournament 18488, `ApplicationRecord.local_server?`.
- `.planning/phases/41-versions-sync-tagging/41-CONTEXT.md` (locked decisions) and `/Users/gullrich/DEV/carambus/carambus/CARAMBUS-API-GLOBAL-CONTEXT-REGIONS-HANDOFF.md` (root-cause handoff) — read in full.

### Secondary (MEDIUM confidence)
- None — no WebSearch was needed; everything resolvable from gem source + codebase + live read-only queries.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Core mechanism (version tagging, touch-forces-version, ordering): HIGH — verified directly against installed gem source, not training-data recollection.
- Data facts (Region 25, Tournament 18488, selection-criterion count): HIGH for dev, MEDIUM for exact production numbers (data-driven query will confirm at execution time; the id range ~18-40 is a documented estimate from the handoff, not independently re-verified against prod in this research session).
- Cron/propagation path: HIGH — confirmed by reading `config/schedule.rb` and the exact rake task it invokes, including how `region_id` is threaded into the `for_region` filter.

**Research date:** 2026-07-12
**Valid until:** Stable — this is internal mechanism research against a pinned gem version (15.2.0) and this app's own code; re-verify only if `paper_trail` is upgraded or `RegionTaggable`/`LocalProtector`/`version.rb` change materially.
