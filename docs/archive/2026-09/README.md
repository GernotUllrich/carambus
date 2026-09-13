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

### Streaming-Rollout (1 Dokument)
- `streaming-consolidation-testing-guide.md` - Testanleitung zum Rollout der drei Stream-Ziele
  (`youtube` / `local` / `custom`, Januar 2026, Commit `9d8e7863`, Migration `20260109210439`)
  - **Herkunft:** `docs/administrators/streaming-consolidation-testing-guide.md`
  - **Grund:** Der Rollout ist abgeschlossen; das Dokument war nicht in der Navigation und wurde von keinem
    anderen Doc verlinkt. Der Re-Audit vom 2026-09-11 fand darin 6 Doc-Befunde, beim Archivieren offen:
    Neustart/Speichern bei laufendem Stream soll laut Test wieder „Active“ zeigen (der Code stoppt nur),
    Rollback per `rails db:rollback` aus `carambus_master` (nimmt heute eine andere Migration zurück),
    Diagnose über `journalctl` und `stream-table-1.conf` statt über `/var/log/carambus/stream-table-<table_id>.log`
    mit der richtigen `table_id`, Pi-Overlay-Prüfung über `scoreboard_overlay` statt `scoreboard_text`,
    CPU-Erwartung mit Hardware-Encoding und Chromium (heute libx264, kein Chromium im Streaming-Pfad).
    Aktuelle Anleitung: `docs/administrators/streaming-setup.de.md`.
  - **Nicht mehr ausführen.** Wiederherstellen bei Bedarf per `git log --follow` auf die neue Datei.

### Entscheider-Seiten, Fassung Dezember 2025 (8 Dokumente)
- `decision-makers/{index,executive-summary,features-overview,deployment-options}.{de,en}.md` - die frühere
  Fassung von `docs/decision-makers/`
  - **Herkunft:** `docs/decision-makers/` (gleiche Dateinamen; dort steht seit 2026-09-13 die Neufassung)
  - **Grund:** Die Prüfung gegen den Code in Phase 17 (Plan 17-02, `docs/DRIFT-REPORT.md`) fand 156 Befunde,
    39 davon schwer: nicht vorhandene Funktionen (Pool-/Snooker-Turniere, Offline-App, Zwei-Faktor-Anmeldung,
    Online-Buchung, Webhooks …), ein Raspberry-Pi-Image, das es nicht gibt, drei Betriebsmodelle, von denen nur
    eines belegt ist, und keine Angabe zur Abhängigkeit von der Authority. Statt 156 Stellen zu korrigieren,
    wurden die Seiten auf das Belegte neu gefasst.
  - **Nicht mehr zitieren.** Die Kosten-, Zeit- und Leistungsangaben der alten Fassung sind unbelegt.

## Status

Alle Dokumente in diesem Verzeichnis dokumentieren **abgeschlossene** Arbeiten. Für aktuelle
Dokumentation siehe:
- `docs/administrators/` - Installation und Betrieb
- `docs/developers/` - Aktuelle Entwickler-Dokumentation

`docs/archive/` ist in `mkdocs.yml` per `exclude_docs` von der Website ausgenommen.

---

**Erstellt:** 2026-09-11
**Quelle:** Phase 16 (Pläne 16-02 und 16-04), Fix-Liste aus dem Re-Audit von `docs/administrators/`
