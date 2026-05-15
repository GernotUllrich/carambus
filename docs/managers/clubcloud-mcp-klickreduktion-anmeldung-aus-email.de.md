# Klick-Reduktion: Anmeldung aus E-Mail

> **Status:** Inhalt-Refresh post-Phase-14-G.10 Authority-Modell (Plan 14-G.11, 2026-05-16). Screenshots werden vom User nachgeliefert (Test-CC oder Prod-CC mit redacted PII; siehe `docs/developers/clubcloud-mcp-workflow-scenarios.de.md` §"Hinweise zur Klick-Reduktions-Doku-Quelle").

## Worum geht's?

Du bekommst als Turniermanager eine E-Mail mit Spielern, die für ein Turnier angemeldet werden sollen. Statt jetzt 12-15 Mausklicks in der ClubCloud-UI zu tätigen — und dabei E-Mail-Tab, Browser, Notizzettel parallel zu jonglieren — schickst du den E-Mail-Inhalt an Claude Desktop, bestätigst 3 Rückfragen und bist fertig. Das hier ist ein konkretes Vorher/Nachher-Beispiel.

## Vorher: Anmeldung in der ClubCloud-UI

Ungefähr 12-15 Klicks, ~3-5 Minuten, 4 Kontextwechsel (E-Mail ↔ Browser ↔ ClubCloud ↔ E-Mail), bei mehreren Spielern multipliziert sich das.

1. **Login auf ClubCloud-Web**
   ![CC-Login-Maske](images/cc-anmeldung-vorher-01-login.png) <!-- TODO: Screenshot durch User -->
2. **Verband-Dashboard öffnen** (z. B. NBV)
   ![Verband-Dashboard](images/cc-anmeldung-vorher-02-verband.png) <!-- TODO: Screenshot durch User -->
3. **Menü → Anmeldungen / Meldelisten**
   ![Menü Anmeldungen](images/cc-anmeldung-vorher-03-menu-anmeldungen.png) <!-- TODO: Screenshot durch User -->
4. **Disziplin auswählen** (z. B. „Freie Partie klein")
   ![Disziplin-Auswahl](images/cc-anmeldung-vorher-04-disziplin.png) <!-- TODO: Screenshot durch User -->
5. **Turnier in der Liste finden + öffnen** (Anmeldeschluss prüfen)
   ![Turnier-Liste](images/cc-anmeldung-vorher-05-turnier-liste.png) <!-- TODO: Screenshot durch User -->
6. **Spieler suchen** (Name eintippen)
   ![Spieler-Suche](images/cc-anmeldung-vorher-06-spieler-suche.png) <!-- TODO: Screenshot durch User -->
7. **Spieler aus Trefferliste auswählen** (bei mehrdeutigem Namen Geburtsjahr abgleichen)
   ![Spieler-Treffer](images/cc-anmeldung-vorher-07-spieler-treffer.png) <!-- TODO: Screenshot durch User -->
8. **Anmelde-Button klicken**
   ![Anmelde-Button](images/cc-anmeldung-vorher-08-anmelde-button.png) <!-- TODO: Screenshot durch User -->
9. **Bestätigungs-Dialog**
   ![Bestätigungs-Dialog](images/cc-anmeldung-vorher-09-bestaetigung.png) <!-- TODO: Screenshot durch User -->
10. **Zurück zur Spieler-Suche** (für nächsten Spieler)
    ![Wieder Suche](images/cc-anmeldung-vorher-10-wieder-suche.png) <!-- TODO: Screenshot durch User -->
11. *(Schritte 6-10 wiederholen pro weiterem Spieler)*
12. **Wenn alles erledigt: Liste prüfen + abschließen**
    ![Liste-Pruefung](images/cc-anmeldung-vorher-12-liste-pruefen.png) <!-- TODO: Screenshot durch User -->

**Häufige Fehlerquellen:** Tippfehler beim Spielernamen, falsches Turnier (zwei NBV-Pokale am selben Wochenende), Vergessen einzelner Spieler, Verlust des Kontexts beim Wechsel zurück zur E-Mail.

## Nachher: Anmeldung mit Claude Desktop

1 Prompt + ~3 Bestätigungen, ~30-60 Sekunden, 1 Kontext (Claude Desktop).

1. **E-Mail-Inhalt in Claude Desktop einfügen.**
   ![Claude Desktop mit Anmelde-Prompt](images/cc-anmeldung-nachher-01-prompt.png) <!-- TODO: Screenshot durch User -->
2. **Claude führt durch Region/Turnier/Spieler-Bestätigungen** (3-4 gezielte Rückfragen).
   - „Region: NBV, korrekt?"
   - „Welches Turnier ist gemeint — NBV-Pokal Freie Partie klein (Anmeldeschluss 2026-05-15) oder NBV-Endrangliste Freie Partie klein (Anmeldeschluss 2026-05-20)?"
   - „Welche Spieler aus der E-Mail entsprechen welchen CC-Datensätzen?" (bei Mehrdeutigkeit gezielte Nachfrage mit Geburtsjahr)
   ![Claude-Konversation Schritt-Sequenz](images/cc-anmeldung-nachher-02-konversation.png) <!-- TODO: Screenshot durch User -->
3. **Letzte Bestätigung — Claude meldet die Spieler an.**
   ![Bestätigungs-Übersicht + Erfolg-Meldung](images/cc-anmeldung-nachher-03-erfolg.png) <!-- TODO: Screenshot durch User -->

**Was Claude für dich übernimmt:**
- Die Tool-Sequenz (Region → Turnier → Spielberechtigung → Anmeldung) wird vom Spickzettel `cc://workflow/scenarios/anmeldung-aus-email` deterministisch geführt.
- Stale-CC-Daten werden via `last_sync_age_hours`-Meta erkannt, Claude empfiehlt `force_refresh:true` wenn nötig (z. B. bei Verbandsadmin-Änderungen).
- Bei mehrdeutigen Namen fragt Claude gezielt nach (Vorname + Geburtsjahr), statt zu raten.

## Vorher/Nachher-Tabelle

| Phase | Tool/UI | Klick-Anzahl | geschätzte Zeit | Fehler-Anfälligkeit | Kontextwechsel |
|---|---|---|---|---|---|
| **Vorher** | CC-Web-UI | 12-15 (pro Spieler 5-7) | 3-5 min (für 3 Spieler) | hoch (Tippfehler bei Spielernamen, falsches Turnier, vergessene Spieler) | E-Mail ↔ Browser-Tab ↔ CC ↔ E-Mail (≥4 Wechsel) |
| **Nachher** | Claude Desktop | 1 Prompt + ~3 Bestätigungen | 30-60 s (für 3 Spieler) | niedrig (Claude prüft Spielberechtigung via PlayerRanking-Read-Tool) | nur Claude Desktop |

**Was sich besonders auszahlt:** Sonntagabend-Stapel (10+ Anmelde-E-Mails). Vorher: 30-50 min konzentriertes Klicken. Nachher: ~10 min Konversation.

## Spickzettel-Datei

Die maschinell ausgeführte Schritt-Sequenz (für Claude Desktop) steht in `docs/managers/clubcloud-scenarios/anmeldung-aus-email.de.json` (4 Schritte, JSON-Schema-Format gemäß `docs/developers/clubcloud-mcp-workflow-scenarios.de.md`).

Kein separater Aufwand für dich — Claude liest den Spickzettel automatisch, sobald du nach „Anmeldung aus E-Mail" fragst.

## Voraussetzungen

- Dein **Sportwart-Wirkbereich** umfasst gastgebenden Verein + Disziplin des Turniers (`sportwart_location_ids` + `sportwart_discipline_ids`; siehe [`cc-roles`](clubcloud-scenarios/cc-roles.de.md) für die Authority-Brücke). Sonst lehnt der MCP-Server ab — Claude erklärt dann, wen Du anrufen musst.
- Du bist auf der Carambus-Seite Deiner Region (z.B. `https://nbv.carambus.de`) eingeloggt + hast den MCP-Setup-Befehl gepastet (siehe [Cloud-Quickstart](clubcloud-mcp-cloud-quickstart.de.md)).
- Die anzumeldenden Spieler haben einen **PlayerRanking-Eintrag** in der Disziplin (Spielberechtigung — wird von Claude automatisch geprüft).
- Das Turnier ist in CC angelegt und der Anmeldeschluss ist noch nicht erreicht.

## Edge-Cases

- **Spieler-Name in der E-Mail mehrdeutig:** Claude fragt gezielt nach Vorname + Geburtsjahr + Verein. Niemals raten.
- **Turnier nicht in der Liste:** Claude empfiehlt `force_refresh: true` (Verbandsadmin könnte den Anmeldeschluss in CC verschoben haben — DB ist max. ~2h alt durch carambus:retrieve_updates-Cron).
- **Spieler hat keinen PlayerRanking-Eintrag:** Claude erklärt: „Spieler X ist nicht in PlayerRanking für Disziplin Y gerankt — entweder nicht spielberechtigt oder PlayerRanking-Sync fehlt. Bitte mit Verbandsadmin klären."
- **Dein Wirkbereich deckt diesen Verein/Disziplin nicht ab:** Der MCP-Server lehnt mit klarer Authority-Meldung ab. Claude eskaliert mit konkreter Anleitung, wen Du anrufen musst (typisch: anderer Sportwart mit passendem Wirkbereich oder Landessportwart).

---
*Klick-Reduktion-Doku — Plan 03-02 + Plan 14-G.11 Authority-Refresh (2026-05-16)*
*Spickzettel-Datei: `docs/managers/clubcloud-scenarios/anmeldung-aus-email.de.json` · Format-Spec: `docs/developers/clubcloud-mcp-workflow-scenarios.de.md`*
