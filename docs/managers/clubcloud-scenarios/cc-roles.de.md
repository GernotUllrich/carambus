# ClubCloud-Rollenmodell

> **Status:** Aus `.planning/clubcloud-admin-appendix-DRAFT.md` (Phase 36c) extrahiert. `[SME-CONFIRM]`-Marker bleiben verbatim — Auflösung in einem zukünftigen Doc-Promotion-Workflow.

## Überblick

ClubCloud unterscheidet mehrere Rollen, die für Turnier-Workflows relevant sind. **[SME-CONFIRM]** die genauen Rollennamen und die genauen Berechtigungsgrenzen — die nachfolgende Tabelle ist eine Best-Effort-Rekonstruktion aus den Phase-36-Review-Notizen (F-36-23) und sollte nicht als maßgeblich angesehen werden.

## Rollentabelle

| Rolle | Typischer Inhaber | CC-Berechtigungen relevant für Turniere |
|-------|-------------------|----------------------------------------|
| **Club-Sportwart** | Der Sportwart des gastgebenden Vereins | Kann fehlende Spieler zur CC-Spielerdatenbank hinzufügen, die Teilnehmerliste finalisieren, Spielergebnisse für eigene Turniere des Vereins hochladen |
| **Region-Sportwart** | Regionaler Turnierbetreuer | Alle Club-Sportwart-Rechte für alle Vereine in der Region; kann neue Turniere in CC anlegen |
| **Turnierleiter** (CC-Rolle, nicht zu verwechseln mit dem Carambus-Konzept) | Pro Turnier zugewiesen | Kann das Turnier einsehen, Ergebnisse erfassen; kann Finalisierungsrechte haben oder auch nicht **[SME-CONFIRM]** |
| **Verbands-Sportwart** | Verbandsebene | Obermenge der Region-Sportwart-Rechte |
| **Member** (Standard) | Jeder CC-registrierte Spieler | Nur-Lesen für die meisten Turnierdaten |

## Praktische Konsequenz

**Die Person, die ein Carambus-Turnier am Veranstaltungsort physisch durchführt, ist nicht immer dieselbe Person, die die CC-Berechtigungen hat, um die Teilnehmerliste zu finalisieren oder einen fehlenden Spieler hinzuzufügen.** Dies ist die organisatorische Hauptursache der meisten ClubCloud-bezogenen Verwirrungen bei Turnieren.

## Abgrenzung zu Carambus-Rollen

Diese Rollen sind ClubCloud-seitig, nicht Carambus-seitig. Carambus-Benutzerrollen (z.B. `club_admin`) sind separat. Das MCP-Write-Tool `cc_finalize_teilnehmerliste` setzt mindestens Club-Sportwart-Rechte voraus; bei fehlender Berechtigung antwortet CC mit einem Fehler, den der Server per D-11 trust-CC-and-parse-error-Pattern als strukturierten MCP-Fehler weiterreicht.

*Quelle: .planning/clubcloud-admin-appendix-DRAFT.md (Phase 36c, 2026-04-14). [SME-CONFIRM]-Marker bleiben unaufgelöst — Resolution in einem zukünftigen Doc-Promotion-Workflow.*
