# Archiv: GSD-Planungsartefakte (Stand 2026-07-20)

Gesichert beim Entfernen des GSD-Planungs-Frameworks (`.planning/` + `.claude/get-shit-done`).
Das Projekt arbeitet seither ausschliesslich mit PAUL (`.paul/`) bzw. direkt/interaktiv —
siehe CLAUDE.md, Abschnitt "Workflow (Paul-first)".

## Warum hier

Diese Dateien lagen unter `.planning/` und waren dort ueberwiegend **gitignored**
(`.gitignore` ignorierte `/.planning/phases/`, `/.planning/debug/`, `/.planning/milestones/`
u.a.) — beim Loeschen waeren sie also unwiederbringlich verloren gewesen. Der Rest von
`.planning/` (PROJECT/ROADMAP/STATE/HISTORY/MILESTONES/RETROSPECTIVE, seeds, specs,
erledigte todos) war getrackt und bleibt ueber die Git-Historie rekonstruierbar.

## Inhalt

| Verzeichnis | Was |
|---|---|
| `40-mcp-server-clubcloud/` | Vollstaendige Designdoku zum MCP-Server fuer ClubCloud (CONTEXT, RESEARCH, REVIEW, VERIFICATION, DISCUSSION-LOG, 6x PLAN/SUMMARY). Zugehoeriger Branch: `origin/mcp-server`. |
| `41-versions-sync-tagging/` | Versions-Sync-Tagging (CONTEXT, RESEARCH, VALIDATION, PLANs/SUMMARYs, `deferred-items.md`). Zugehoeriger Branch: `origin/scenario/api/versions-sync-tagging`. |
| `debug/` | Debug-Analyse `scoreboard-old-innings-panel-race.md`. |
| `todos-pending/` | Vier zum Zeitpunkt der Archivierung OFFENE Todos — echte, noch nicht erledigte Arbeitsposten (siehe unten). |

## Offene Todos (waren `pending`, nicht erledigt)

- `2026-05-06-detail-form-mehrsatzspiel-toggle-not-persisting-sets-to-win`
- `2026-05-06-implement-bk-tiebreak-nachstoss-canonical-spec`
- `2026-05-07-local-mkdocs-config-drift-produces-broken-html`
- `2026-05-07-scrape-player-class-from-tournament-title`

## Hinweis zu Code-Kommentaren

Einige Kommentare in `app/` und `test/` verweisen noch auf `.planning/...`-Pfade
(z.B. `.planning/phases/38.7-.../38.7-CONTEXT.md`, `.planning/debug/bk2-nachstoss-banner-missing.md`).
Diese Dokumente existierten **schon vor** dieser Archivierung nicht mehr — die Verweise
liefen also bereits ins Leere und sind hier auch nicht wiederherstellbar.
