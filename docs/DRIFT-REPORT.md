# Drift-Report: Dokumentation vs. Code — Re-Verifikation nach Refactor

> Neuer Abgleich der **struktur-gekoppelten technischen Docs** gegen den aktuellen Code, nachdem ein breiter Refactor gelandet ist (**116 geänderte + 16 gelöschte `.rb`-Dateien** seit dem letzten Audit: Scoping, User-Personas, Discipline-Detection, CC-Controller, MCP-Umbau, Party-/Liga-Spieltag, Tournament::CcSync). Der graphify-Graph wurde zuvor auf denselben Stand aktualisiert (3.992 Nodes).

**Methodik:** pro Doc konkrete Claims (Klassen/Services, AASM-States, Methoden-Signaturen, Assoziationen, Routes, Config) gegen die echte Quelle prüfen → MATCH / DRIFT / GAP, `Datei:Zeile`-belegt; Verifier-Fan-out (9 Agenten), verify-before-edit, de/en synchron.

## Scope dieses Laufs

Verifiziert (~23 eindeutige Docs): `developers/services/*` (tournament-monitor, table-monitor, tournament, party-monitor, region-cc, league, umb, video-crossref), `developers/` (mcp-architektur-naht, per-user-cc-identitaet, clubcloud-mcp-server, external-tournament-bridge, tournament-architecture-overview, umb-scraping-implementation/methods, er-diagram, database-design, region-tagging-cleanup-summary, developer-guide, clubcloud-upload), `reference/` (api, search, glossary).

Nicht in diesem Lauf (Code unverändert oder nutzer-/prozedural): übrige `developers/`-Docs, `managers/`, `administrators/`, historische `internal/`-Notes.

## Gesamtbilanz

- **22 handlungsrelevante Befunde** (14 DRIFT, 8 GAP) — Schweregrad 4 hoch, 11 mittel, 7 niedrig.
- **16 behoben und committet**, 6 bewusst zurückgestellt (niedrig / neue Doku nötig).
- **72 Aussagen als korrekt verifiziert** (MATCH) — der Refactor hat die dokumentierte Struktur überwiegend NICHT verletzt.

Kernmuster: fast aller Drift entstand, weil der Refactor **neue Fähigkeiten hinzufügte**, die die Docs noch nicht kannten — nicht durch widersprüchliche Umbenennungen. Gelöschte Features (Page-CMS, Subscriptions/Billing) waren nie dokumentiert → keine Geister.

## Behobene Befunde im Detail

**`clubcloud-mcp-server.de.md §2 (Hinweis zwei Tool-Listing-Pfade)`**

- `[DRIFT·medium]` HTTP path uses the hardcoded RoleToolMap::ALL_TOOLS list via ToolRegistry.tool_classes_for(user); a new tool must additionally be entered in RoleToolMap::ALL_TOOLS.

**`clubcloud-mcp-server.de.md §6 (ToolRegistry + RoleToolMap reference)`**

- `[DRIFT·high]` ToolRegistry.tools_for(user) returns RoleToolMap::ALL_TOOLS for every authenticated user; tool_count_for(_role_key) is a stub returning ALL_TOOLS.size for every key; the Final-Stub delivers ALL_TOOLS to all authenticated users.

**`docs/developers/database-design.en.md (and .de.md)`**

- `[DRIFT·high]` RegionTaggable Seeding example returns an ARRAY of region ids and calls find_dbu_region_id_if_global: `tournament ? [tournament.region_id, (...organizer_id...), find_dbu_region_id_if_global].compact : []`

**`docs/developers/region-tagging-cleanup-summary.de.md`**

- `[DRIFT·medium]` 'Noch zu erledigen' section: league.rb, region.rb, tournament.rb, club.rb, player.rb STILL contain `region_ids |= [region.id]` and must be updated to `region_id = region.id`

**`docs/developers/services/umb.en.md:10 / umb.de.md:10 (DisciplineDetector row)`**

- `[DRIFT·medium]` DisciplineDetector 'Maps tournament names to Discipline records via regex and DB ILIKE fallback' — no mention of title-based derivation

**`docs/developers/services/umb.en.md:24-25 / umb.de.md:24-25 (Detailed Documentation links)`**

- `[DRIFT·medium]` Links point to ../umb-scraping-implementation.md and ../umb-scraping-methods.md

**`docs/developers/services/video-crossref.en.md:115-116 / de:115-116 (AI fallback model)`**

- `[DRIFT·high]` AI fallback uses model gpt-4o-mini with response_format: { type: "json_object" } (OpenAI)

**`external-tournament-bridge.en.md / .de.md (summary endpoint table + body)`**

- `[GAP·medium]` The bridge exposes /api/external_tournament/* endpoints tables, seeding, round_start, round_result, tournament/lock_table/start_game/acknowledge_result/end_tournament, player_reconcile, clubs, club_players, player_rankings, disciplines, …

**`external-tournament-bridge.en.md:12-24 / .de.md:12-24 (summary table)`**

- `[GAP·low]` Summary endpoint table enumerates the bridge endpoints.

**`mcp-architektur-naht.en.md / .de.md §4 (Layer 1 tier gating)`**

- `[DRIFT·medium]` ToolRegistry.tools_for(user) filters on cc_write_access?: a read-only user does not receive write tools.

**`mcp-architektur-naht.en.md / .de.md §8 (checklist item 7)`**

- `[DRIFT·high]` A new CC write tool must be registered in role_tool_map.rb (WRITE_TOOLS) AND in SpielleiterChatService::TOOL_CLASSES (two separate lists — drift trap!).

**`table-monitor.{en,de}.md`**

- `[GAP·medium]` save_result return hash keys: Gruppe, Partie, Spieler1/2, Innings1/2, Ergebnis1/2, Aufnahmen1/2, Höchstserie1/2, Tischnummer

**`tournament-monitor.{en,de}.md`**

- `[GAP·medium]` ResultProcessor entry points list (report_result, accumulate_results, update_ranking, update_game_participations) — omits public advance_round_after_match_close

**`tournament.en.md / tournament.de.md`**

- `[GAP·medium]` The Tournament:: namespace consists of exactly 3 services in app/services/tournament/ (PublicCcScraper, RankingCalculator, TableReservationService).

**`umb-scraping-implementation.{en,de}.md`**

- `[GAP·medium]` Umb::DisciplineDetector maps tournament names to Discipline records via regex + DB-ILIKE fallback (only).
- `[DRIFT·medium]` The Umb:: sub-namespace contains 7 classes + 1 module (part of 10 services total).

## Was der Refactor an neuen Fähigkeiten brachte (jetzt dokumentiert)

- **`Tournament::CcSync::`** Sub-Namespace (AccreditationPush / FinalizePush, Phase 44) — Tournament-Services 3→5.
- **`advance_round_after_match_close`** (Phase 38.8) — deferred Runden-Progressions-Kaskade nach `close_match!`.
- **Party-/Liga-Spieltag-Endpoints** (Plan 48): `party` / `party_game_result` / `party_close` an der External-Tournament-Bridge.
- **Zweistufige Discipline-Detection** — `DisciplineDetector#detect_with_title_fallback` + `Discipline.classify_from_title` (title-basierte Ableitung, curated overrides).
- **MCP Persona-Gating** — `ToolRegistry.tools_for(user)` liefert persona-gefilterte Subsets (nicht mehr `ALL_TOOLS` für alle); Write-Tools nur bei `cc_write_access? && local_server?`; Single-Source-Tool-Registrierung (D-34-3).
- **Video-KI** nutzt Anthropic Claude Haiku (nicht OpenAI) für Metadaten-Extraktion.
- **RegionTaggable** liefert jetzt eine einzelne Region-ID (Verzweigung nach `tournament_type`), nicht mehr ein Array.

## Nachgezogen (nach dem Re-Audit erledigt)

- **MCP-Tool-Inventar voll-refresht** (`clubcloud-mcp-server.de.md`): von veraltet 23 auf real **46 registrierte Tools (29 Read / 16 Write / 1 Self-Service)** aktualisiert, inkl. Persona-Gating (`cc_write_access? && local_server?`). Dabei aufgedeckt: der **Drift-Guard-Test ist ROT** — `EXPECTED_TOOL_NAMES` (39) hinkt der dynamischen Registry (46) hinterher, 7 Tools fehlen (cc_clone_tournament(s), cc_open_in_tournament_app, cc_open_party_in_app, cc_party_status, cc_prepare_tournament, cc_start_party_day). Als Code/Test-Fix ausgelagert (Chip). Korrigiert die frühere Fehlannahme „Smoke-Test synchron".
- **`BranchTaggable` / `Scopable`-Subsystem dokumentiert** — neues Doc `developers/branch-scoping.{de,en}.md`. Zentrale Erkenntnis: das `branch_taggings.rake`-Backfill wurde wieder entfernt (update_columns umgeht before_save + LocalProtector sperrt Globals → `branch_id` bleibt NULL auf synchronisierten Records); Branch-Facette wird zur **Query-Zeit** über `discipline.root` / `Branch.discipline_ids_for` aufgelöst. Stalen Kommentar-Verweis in `branch_taggable.rb` als Code-Fix ausgelagert (Chip).

## Offen (niedrig)

- Einige vor-refactor bestehende Label-Ungenauigkeiten (z. B. „ApplicationService" für PORO-Scraper) — surgical belassen.

## Verbleibende Code-Punkte → an PAUL (unverändert)

Reine Code-Bugs aus früheren Läufen (Handoff: `carambus_gu/.paul/handoffs/HANDOFF-2026-06-08-code-fixes-from-docs-audit.md`): fehlender `StreamDeployJob` (`deploy_all`), `Shot include Translatable` ohne `source_language`-Spalte, `Table#pre_heating_time_in_hours` Token-Bug.

## Einordnung (graphify-Caveat)

Der graphify-Graph ist Landkarte/Discovery, kein Drift-Detektor: `INFERRED`-Kanten sind verrauscht. Der belastbare Abgleich lief gegen den echten Code (`EXTRACTED`-Struktur + Quelle).
