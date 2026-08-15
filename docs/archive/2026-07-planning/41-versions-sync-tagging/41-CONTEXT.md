# Phase 41: Version-Sync Tagging — International Organizer Regions - Context

**Gathered:** 2026-07-12
**Status:** Ready for planning
**Source:** carambus-UX Authority-Handoff (`CARAMBUS-API-GLOBAL-CONTEXT-REGIONS-HANDOFF.md`) + User-Entscheidungen (2026-07-12)

<domain>
## Phase Boundary

Behebt auf der **Authority** (carambus_api production, api.carambus.de) die Tagging-Inkonsistenz, durch die internationale Organizer-Regions nicht zu deutschen Regional-Servern replizieren, während die von ihnen organisierten (global getaggten) Turniere überallhin replizieren → dangling `organizer` → Sync-Apply scheitert („Organisiert von muss ausgefüllt werden").

**In-Scope:** idempotenter, PaperTrail-getrackter Daten-Fix (`global_context=true` auf betroffene Regions) + Redelivery der zuvor übersprungenen internationalen Turniere über frische Versionen, sodass der **normale Cron-Update-Zyklus** alle Local-Server versorgt. Verifikation.

**Out-of-Scope:** `RegionTaggable#global_context?`-Code-Fix (fehlender `when Region`-Case); Nebenbefund Region 11 (BVNRW `gc=false`); Handoff H2 (branch_id, → Phase 42); Handoff H3 (Disziplin-Baum, → Phase 43).
</domain>

<decisions>
## Implementation Decisions (locked)

### Fix-Strategie
- **Option A** (Daten-Fix), NICHT Option B (region-scoped tagging int. Turniere). Entscheidung User 2026-07-12.
- Der `global_context?`-Code-Fix (`when Region`-Case) ist als **separate Folge-Entscheidung** markiert und gehört NICHT in diese Phase. Der Daten-Fix darf NICHT über `region_taggings:update_all` / `global_context?` laufen (dessen `else false` für Region würde die kuratierte 1–17-Taggung regressieren = bekannter Footgun).

### Selektionskriterium (idempotent)
- Betroffene Regions = alle `Region`, die Organizer (`organizer_type="Region"`, `organizer_id=<region.id>`) eines `region_id IS NULL`-`Tournament` ODER `-League` sind UND `global_context != true`.
- Lokal verifiziert (2026-07-12): trifft exakt UMB (Region 25, 433 global getaggte Turniere). Prod hat weitere int. Organizer-Regions im id-Bereich ~18–40 — der Task selektiert sie datengetrieben, nicht per Hardcode-Liste.

### Sync-Mechanik (User-Vorgabe 2026-07-12, kritisch)
- Alle Local-Server werden über den **normalen Cron-Update-Zyklus** synchronisiert. KEIN manueller Per-Server-Re-Sync ab früherem `last_version_id`.
- ⇒ Der Fix MUSS mit **aktiviertem PaperTrail** speichern, sodass NEUE Version-Rows entstehen. Version-Tagging erfolgt via `RegionTaggable#update_version_region_data` (`region_taggable.rb:118-138`), das die Version aus der **`global_context`-SPALTE des Records** setzt (NICHT aus `global_context?`). D.h. `global_context`-Spalte true setzen + PaperTrail-getrackter Save ⇒ neue Version mit `global_context=true`.
- Bereits übersprungene int. Turniere (Cursor ist vorbei, z. B. Tournament 18488 / Version 13306420) erreichen die Locals nur über **frische Versionen** (Touch/save_with_version), in Reihenfolge **NACH** der jeweiligen Region (niedrigere Version-id zuerst), damit der `organizer` beim Apply schon existiert.
- Nuance für Planer/Research: `update!` ohne echte Attributänderung erzeugt KEINE Version — für die Region-Row ist die Spaltenänderung false→true die echte Änderung (ok); für Turniere ohne Attributänderung muss ein Version-Erzwingen (`paper_trail.save_with_version` / touch) genutzt werden.

### Ausführungsort & Zugang
- Task läuft auf der Authority: `ssh api` → `cd carambus_api/current`.
- Prod-/Datenänderung erst nach ausdrücklicher User-Freigabe (Erhebung read-only zuerst).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Root-Cause-Handoff (liegt im carambus-Checkout, untracked)
- `/Users/gullrich/DEV/carambus/carambus/CARAMBUS-API-GLOBAL-CONTEXT-REGIONS-HANDOFF.md` — vollständiger Befund, Option A/B, To-do, Verifikationsweg.

### Code (carambus_api)
- `app/models/version.rb:47-48` — `for_region`-Scope (`region_id IS NULL OR region_id = ? OR global_context = TRUE`), Filter beim `get_updates`.
- `app/models/version.rb:~455-474` — Sync-Apply Create-/Update-Zweig + 2026-06-17-Härtung (skip+log fehlgeschlagener Applies).
- `app/models/concerns/region_taggable.rb:11-53` — `find_associated_region_id` (Region → `id`).
- `app/models/concerns/region_taggable.rb:55-79` — `global_context?` (kein `when Region`-Case → `else false`; NICHT in dieser Phase anfassen).
- `app/models/concerns/region_taggable.rb:118-138` — `update_version_region_data` (tagt Version aus Record-Spalten; nur wenn `PaperTrail.request.enabled?`).
- `lib/tasks/region_taggings.rake:106-114` — `tag_with_gobal_context`-Muster (Region-Row + Version-Rows). ACHTUNG: nutzt `update_all` (bypassed PaperTrail) — als Referenzmuster lesen, aber der neue Task muss PaperTrail-getrackt speichern (siehe Sync-Mechanik).
- `config/initializers/paper_trail.rb` — YAML-Serializer; keine Callback-Tagging-Logik (bestätigt: Tagging liegt in RegionTaggable).

### Projekt-Konventionen
- `CLAUDE.md`, `.agents/skills/scenario-management/SKILL.md` (Arbeit im Branch `scenario/api/versions-sync-tagging`).
</canonical_refs>

<specifics>
## Specific Ideas

- Verifikationsweg (ohne Test-DB, aus Handoff): `URI("https://api.carambus.de/versions/get_updates?last_version_id=<vor Region-Version-id>")` → Region-Version mit `global_context=true`; `Region.exists?(25)` auf Local-Server nach Cron → true.
- Idempotenz-Test: zweiter Task-Lauf erzeugt keine neuen Versionen (alle betroffenen Regions bereits `global_context=true`).
- Lokale Diagnose-Fakten (2026-07-12): UMB=Region 25 `gc=false, region_id=nil`, organisiert 433 `region_id=nil`-Turniere; Tournament 18488 `organizer=Region#25, region_id=nil`.
</specifics>

<deferred>
## Deferred Ideas

- `RegionTaggable#global_context?` `when Region`-Case (schließt den `region_taggings:update_all`-Footgun; braucht Semantik-Entscheidung, damit deutsche 1–17-Kuratierung nicht regressiert).
- Region 11 (BVNRW) `gc=false` obwohl deutscher LV — separater Daten-Check.
- Handoff H2 (branch_id) → Phase 42; Handoff H3 (Disziplin-Baum) → Phase 43 (je eigene offene fachliche Fragen).
</deferred>

---

*Phase: 41-versions-sync-tagging*
*Context gathered: 2026-07-12*
