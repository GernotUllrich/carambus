# ClubCloud-Rollenmodell

> **Status:** Aus dem damaligen Planungsentwurf `.planning/clubcloud-admin-appendix-DRAFT.md` (Phase 36c; die Datei existiert nicht mehr) extrahiert + Carambus-Authority-Brücke ergänzt (Plan 14-G.11, 2026-05-16). `[SME-CONFIRM]`-Marker bleiben verbatim — Auflösung in einem zukünftigen Doc-Promotion-Workflow.

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

Die obigen Rollen sind **ClubCloud-seitig**. In Carambus / im MCP-Server entscheiden eine
**explizite Persona** (`users.persona_grants`, Phase 38) und ein **Wirkbereich** (Spielorte +
Disziplinen), welche Operationen ein User ausführen darf.

> **Wichtig (Stand Phase 34-01/38):** Die **Tool-Liste** hängt von der Persona ab
> (`ToolRegistry.tools_for`, Tiers in `RoleToolMap`). Jeder authentifizierte User bekommt
> 29 lesende Tools und `cc_link_my_player`, zusammen **30 Tools**. Mit CC-Schreibrecht
> (`system_admin`, Sportwart-Persona oder Turnierleitung) kommen auf einem Region- oder
> Local-Server die **16 Schreib-Tools** dazu, zusammen **46**. Auf der Authority ist der Chat
> für alle read-only. Danach wird **jeder Schreib-Aufruf** am konkreten Turnier über
> `BaseTool.authorize!` geprüft.

| Carambus-Persona | Voraussetzung | Wirksame Operationen | Mapping zur CC-Rolle |
|------------------|---------------|----------------------|----------------------|
| **Sportwart** | `persona_grants: ["sportwart"]`, dazu `sportwart_locations` (Location-IDs) und `sportwart_disciplines` (Disziplin-IDs, leer = alle) | Schreib-Operationen für Turniere an den zugeordneten Spielorten und in den zugeordneten Disziplinen | entspricht CC-Club-Sportwart-Berechtigung für die Schnittmenge der Wirkbereich-Felder |
| **Turnierleiter** | `tournament.turnier_leiter_user_id = user.id` **oder** `UserTournament` mit `role: "turnier_leiter"` (lokale Zuordnung) | Schreib-Operationen für genau das zugewiesene Turnier | entspricht CC-Turnierleiter-Rolle für genau dieses eine Turnier |
| **Landessportwart (LSW)** | `persona_grants: ["landessportwart"]` | Schreib-Operationen für Turniere an allen Spielorten; der Disziplin-Filter gilt weiter | entspricht CC-Verbands-Sportwart |
| **SysAdmin** | role `system_admin` | Schreib-Tools ohne Persona; `admin?`-Bypass in der TournamentPolicy (gilt für `club_admin` und `system_admin`). Auf der Authority wie alle read-only | technische Admin-Eskalation |

Die Persona setzt nur ein `system_admin` (Admin-Formular `/admin/users`, Feld „Sportwart-Persona“).

**Authority-Hook:** `lib/mcp_server/tools/base_tool.rb` enthält den `authorize!`-Check,
der pro Tool prüft, ob die betroffene Location/Disziplin im Wirkbereich liegt bzw.
der User für das Ziel-Turnier als TL eingetragen ist. Bei fehlender Authority gibt
der MCP-Server eine klare Eskalations-Meldung zurück (kein 403 vom CC) — der
Sportwart weiß sofort, wen er anrufen muss.

**Tool-Anzahl-Implikationen** (Verifikation aus User-Sicht): rund 30 Tools ohne
Schreibrecht, rund 46 mit Schreibrecht auf einem Region- oder Local-Server; innerhalb der
Schreib-Tools zeigen sich Unterschiede erst beim Ausführen über die Authority-Eskalation — Details in
[Cloud-Quickstart §Erste Beispiel-Dialoge](../clubcloud-mcp-cloud-quickstart.de.md#erste-beispiel-dialoge).

**Wirkbereich-Setup-Console-Befehle:** siehe
[Setup-Service §5 Authority-Layer](../clubcloud-mcp-setup-service.de.md#5-authority-layer-sportwart-wirkbereich-tl-fk).

*Quelle: damaliger Planungsentwurf .planning/clubcloud-admin-appendix-DRAFT.md (Phase 36c, 2026-04-14; nicht mehr vorhanden) + Plan 14-G.11 Authority-Brücke (2026-05-16). [SME-CONFIRM]-Marker bleiben unaufgelöst — Resolution in einem zukünftigen Doc-Promotion-Workflow.*
