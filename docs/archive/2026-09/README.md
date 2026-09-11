# Archive - September 2026

Dieses Verzeichnis enthält Dokumente, die im September 2026 aus der lebenden Dokumentation genommen wurden,
weil sie abgeschlossene Vorgänge beschreiben. Sie bleiben als historische Referenz erhalten und werden nicht
mehr gepflegt.

## Inhalt

### Domain-Migration (1 Dokument)
- `MIGRATION_NEW_TO_PRODUCTION_DOMAINS.de.md` - Umstellung der temporären Subdomains `newapi.carambus.de` /
  `new.carambus.de` auf `api.carambus.de` / `carambus.de` (Januar 2026, Commit `b319bcc1`)
  - **Herkunft:** `docs/administrators/MIGRATION_NEW_TO_PRODUCTION_DOMAINS.de.md`
  - **Grund:** Die Migration ist abgeschlossen. Der Re-Audit vom 2026-09-11 (Phase 16, `docs/DRIFT-REPORT.md`)
    fand darin 8 Befunde (u. a. `carambus_master`, `git pull` auf dem Server, Dienstnamen ohne `puma-`,
    eine nicht existierende API-Route); statt sie zu korrigieren, wurde das Dokument archiviert.
  - **Nicht mehr ausführen.** Die Befehle beschreiben den Stand von Januar 2026.

## Status

Alle Dokumente in diesem Verzeichnis dokumentieren **abgeschlossene** Arbeiten. Für aktuelle
Dokumentation siehe:
- `docs/administrators/` - Installation und Betrieb
- `docs/developers/` - Aktuelle Entwickler-Dokumentation

`docs/archive/` ist in `mkdocs.yml` per `exclude_docs` von der Website ausgenommen.

---

**Erstellt:** 2026-09-11
**Quelle:** Phase 16 (Plan 16-02), Fix-Liste aus dem Re-Audit von `docs/administrators/`
