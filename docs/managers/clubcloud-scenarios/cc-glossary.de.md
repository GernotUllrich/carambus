# ClubCloud-Glossar

> **Status:** Aus `.planning/clubcloud-admin-appendix-DRAFT.md` (Phase 36c) extrahiert. `[SME-CONFIRM]`-Marker bleiben verbatim — Auflösung in einem zukünftigen Doc-Promotion-Workflow.

## Begriffe

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

*Quelle: .planning/clubcloud-admin-appendix-DRAFT.md (Phase 36c, 2026-04-14). [SME-CONFIRM]-Marker bleiben unaufgelöst — Resolution in einem zukünftigen Doc-Promotion-Workflow.*
