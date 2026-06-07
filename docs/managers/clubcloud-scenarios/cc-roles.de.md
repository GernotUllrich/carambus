# ClubCloud-Rollenmodell

> **Status:** Aus `.planning/clubcloud-admin-appendix-DRAFT.md` (Phase 36c) extrahiert + Carambus-Authority-Brücke ergänzt (Plan 14-G.11, 2026-05-16). `[SME-CONFIRM]`-Marker bleiben verbatim — Auflösung in einem zukünftigen Doc-Promotion-Workflow.

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

## Brücke zu Carambus-MCP-Authority

Die obigen Rollen sind **ClubCloud-seitig**. In Carambus / im MCP-Server entscheidet
ein **Wirkbereich-Modell** (Plan 14-G3+G4) — kein globales Rollen-Enum mehr —, welche
Operationen ein User ausführen darf.

> **Wichtig (Stand Plan 14-G.2):** Der MCP-Server differenziert die **Tool-Liste**
> nicht mehr nach Persona. Jeder authentifizierte User bekommt vom `ToolRegistry`
> dieselbe vollständige Liste aller **23 MCP-Tools** (`RoleToolMap::ALL_TOOLS` =
> 17 Read-Tools + 6 Write-Tools). Die Autorisierung erfolgt **pro Tool-Call und pro
> Datensatz** über `BaseTool.authorize!` — nicht durch ein verkleinertes Tool-Subset.
> Die folgende Tabelle beschreibt daher *welche Operationen* eine Persona erfolgreich
> ausführen kann, nicht wie viele Tools sie in der Tool-Liste sieht.

| Carambus-Persona | Authority-Felder | Wirksame Operationen | Mapping zur CC-Rolle |
|------------------|------------------|----------------------|----------------------|
| **Sportwart** | `user.sportwart_location_ids = [...]` (Vereins-IDs)<br>`user.sportwart_discipline_ids = [...]` (Disziplin-IDs) | Anmeldungs-Lebenszyklus vor Turnier für Locations/Disziplinen im Wirkbereich | entspricht CC-Club-Sportwart-Berechtigung für die Schnittmenge der Wirkbereich-Felder |
| **Turnierleiter** | `tournament.turnier_leiter_user_id = user.id` (Single-FK pro Turnier) | Write-Operationen für genau das zugewiesene Turnier (TL-FK-Match) | entspricht CC-Turnierleiter-Rolle für genau dieses eine Turnier |
| **Landessportwart (LSW)** | `user.admin?` (Bypass aller Wirkbereich-Checks) | volle Suite (alle 23 Tools wirksam) | entspricht CC-Verbands-Sportwart |
| **SysAdmin** | `user.super_user?` | volle Suite + Override | technische Admin-Eskalation |

**Authority-Hook:** `lib/mcp_server/tools/base_tool.rb` enthält den `authorize!`-Check,
der pro Tool prüft, ob die betroffene Location/Disziplin im Wirkbereich liegt bzw.
der User für das Ziel-Turnier als TL eingetragen ist. Bei fehlender Authority gibt
der MCP-Server eine klare Eskalations-Meldung zurück (kein 403 vom CC) — der
Sportwart weiß sofort, wen er anrufen muss.

**Tool-Anzahl-Implikationen** (Verifikation aus User-Sicht): Die Tool-Liste ist für
alle authentifizierten User identisch (23 Tools); Unterschiede zeigen sich erst beim
Ausführen über die Authority-Eskalation — Details + Smoke-Test in
[Cloud-Quickstart §Erste Beispiel-Dialoge](../clubcloud-mcp-cloud-quickstart.de.md#erste-beispiel-dialoge).

**Wirkbereich-Setup-Console-Befehle:** siehe
[Setup-Service §5 Authority-Layer](../clubcloud-mcp-setup-service.de.md#5-authority-layer-sportwart-wirkbereich-tl-fk).

*Quelle: .planning/clubcloud-admin-appendix-DRAFT.md (Phase 36c, 2026-04-14) + Plan 14-G.11 Authority-Brücke (2026-05-16). [SME-CONFIRM]-Marker bleiben unaufgelöst — Resolution in einem zukünftigen Doc-Promotion-Workflow.*
