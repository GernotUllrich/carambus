# ClubCloud-Glossar

> **Status:** Aus dem damaligen Planungsentwurf `.planning/clubcloud-admin-appendix-DRAFT.md` (Phase 36c; die Datei existiert nicht mehr) extrahiert + Per-Region-Begriffe ergänzt (Plan 14-G.11, 2026-05-16). `[SME-CONFIRM]`-Marker bleiben verbatim — Auflösung in einem zukünftigen Doc-Promotion-Workflow.

## ClubCloud-Begriffe

**Branch**
Im ClubCloud-Kontext bezeichnet "Branch" eine organisatorische Einheit (z.B. Verband oder Region), die Turniere und Ligen unter sich verwaltet. [SME-CONFIRM] — der Begriff erscheint im CC-API-PATH_MAP-Kontext; genaue semantische Abgrenzung zu "Region" und "Liga" muss durch SME bestätigt werden.

**Endrangliste**
Die abschließende Rangliste eines Turniers, die nach Abschluss aller Spiele in ClubCloud eingetragen wird. Die Endrangliste ist eine separate Datenentität — CC berechnet sie nicht automatisch aus den hochgeladenen Spielergebnissen (Stand v7.0, F-36-34). Carambus berechnet die Endrangliste aus dem Spielbaum; CCI-01/CCI-03 (v7.1) werden das Hochladen automatisieren.

**Meldeliste**
Synonym für Teilnehmerliste in bestimmten CC-API-Kontexten (z.B. `releaseMeldeliste` als API-Action-Name für die Finalisierung der Teilnehmerliste). Die Meldeliste listet alle angemeldeten Teilnehmer eines Turniers auf.

**Spielbericht**
Das Dokument oder der Datensatz, der die Ergebnisse eines einzelnen Spiels enthält. In CC wird der Spielbericht pro Spiel hochgeladen. Fehler beim Upload (z.B. nicht finalisierte Teilnehmerliste) blockieren alle Spielberichte des betroffenen Turniers.

**Spielerdatenbank**
Die zentrale Datenbank in ClubCloud, die alle registrierten Spieler enthält. Jeder Spielbericht-Upload in CC muss einem Spieler-Datensatz aus dieser Datenbank zugeordnet werden. Fehlende Spieler müssen vor dem Upload von einem Club-Sportwart+ in der Spielerdatenbank angelegt werden.

**Sportwart-Ebenen**
Die hierarchischen Ebenen der Sportwart-Rolle in ClubCloud: Club-Sportwart (Vereinsebene) → Region-Sportwart (Regionsebene) → Verbands-Sportwart (Verbandsebene). Jede höhere Ebene schließt die Rechte der unteren ein. [SME-CONFIRM] — die genaue Hierarchie und ob es weitere Zwischenebenen gibt, muss durch SME bestätigt werden.

**Teilnehmerliste**
Die Liste aller Teilnehmer eines Turniers in ClubCloud. Sie muss vor dem ersten Spielbericht-Upload finalisiert ("gesperrt") werden, damit CC die Identität jedes Ergebnisses vertrauen kann. Die Finalisierung ist eine Einweg-Aktion. Synonym zur Meldeliste in der CC-API.

## Carambus-Per-Region-Begriffe

**Per-Region-Scenario**
Eine Carambus-Instanz, die exklusiv für eine Region läuft (z.B. `carambus_nbv` für NBV). Jede Region hat eigene Domain, eigene PostgreSQL-DB und eigene Credentials (daraus das devise-jwt-Secret). Jedes Szenario wird mit `bin/rails "scenario:deploy[<name>]"` deployt (Stage `production`); Region-Stages wie `cap nbv deploy` gibt es nicht.

**`Carambus.config.context`**
Pflicht-Key in `config/carambus.yml`, der die Region-Identität der laufenden Instanz festlegt (z.B. `context: nbv`). Wird vom MCP-Server für Region-Filterung in Tool-Calls genutzt; ersetzt das frühere `User.cc_region`-Feld als Source-of-Truth.

**`request.base_url`-Pattern**
Architektur-Konvention im Setup-Helper-UI (`/mcp/setup`), die den Setup-Befehl mit der Domain der aufgerufenen Instanz ableitet (z.B. `https://nbv.carambus.de/mcp?stateless=1`). Macht die Helper-UI über alle Per-Region-Scenarios hinweg ohne Code-Branch wiederverwendbar.

**Region.shortname Convention**
`Region.shortname` ist in der DB UPPERCASE persistiert (`NBV`, `BVBW`). Lowercase ist nur der ClubCloud-Kontext `RegionCc.context` (`nbv`, `bvbw`). Match-Lookups (`Region.find_by(shortname: "NBV")`) sind case-sensitive — UPPERCASE verwenden. `bcw` ist keine Region, sondern ein Standort-Server der Region NBV.

**Sportwart-Wirkbereich (Authority-Layer)**
Explizite Persona am User (`persona_grants`: `sportwart` oder `landessportwart`) plus Spielorte (`sportwart_locations`; beim Landessportwart alle) und Disziplinen (`sportwart_disciplines`, leer = alle). Ohne Persona wirkt der Wirkbereich nicht. Er entscheidet pro Schreib-Aufruf, ob der User Authority für das Turnier hat. Ersetzt das frühere globale `User.cc_role`-Enum. Details + Mapping zur CC-Rolle siehe [`cc-roles`](cc-roles.de.md).

**Tool-Authorization-Layer**
Der MCP-Server prüft pro Tool-Call via `BaseTool.authorize!` (in `lib/mcp_server/tools/base_tool.rb`), ob der User Authority für die konkrete Operation hat (Wirkbereich-Match — beim Landessportwart mit regionweitem Spielort-Scope —, Turnierleiter-Match über FK oder `UserTournament`, oder `admin?`-Bypass für `club_admin`/`system_admin`). Filterung erfolgt **vor** Ausführung — kein 403 vom CC nötig.

*Quelle: damaliger Planungsentwurf .planning/clubcloud-admin-appendix-DRAFT.md (Phase 36c, 2026-04-14; nicht mehr vorhanden) + Plan 14-G.11 Per-Region-Substrate (2026-05-16). [SME-CONFIRM]-Marker bleiben unaufgelöst — Resolution in einem zukünftigen Doc-Promotion-Workflow.*
