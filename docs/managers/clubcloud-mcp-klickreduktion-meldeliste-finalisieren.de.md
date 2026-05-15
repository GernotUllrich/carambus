# Klick-Reduktion: Meldeliste / Teilnehmerliste finalisieren

> **Status:** Inhalt-Refresh post-Phase-14-G.10 Authority-Modell (Plan 14-G.11, 2026-05-16). Screenshots werden vom User nachgeliefert (Test-CC oder Prod-CC mit redacted PII; siehe `docs/developers/clubcloud-mcp-workflow-scenarios.de.md` §"Hinweise zur Klick-Reduktions-Doku-Quelle"). Hintergrund-Wissen aus `docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md` extrahiert.

## Worum geht's?

Diese Aktion **sperrt** die Teilnehmerliste eines Turniers in ClubCloud — danach sind keine Anmelde-Änderungen mehr möglich. Ohne Finalisierung kann ClubCloud keine Ergebnis-Uploads aus Carambus akzeptieren (du bekommst dann eine Fehlermeldung beim Upload-Versuch). Mit Claude Desktop wird die Aktion durch ein **Dry-Run-First-Pattern** geschützt: du siehst zuerst, was passieren würde, dann erst nach explizitem OK wird wirklich finalisiert.

## Vorher: Teilnehmerliste-Finalisierung in CC-UI

Ungefähr 6-8 Klicks, ~1-2 Minuten, 4 Kontextwechsel (Carambus ↔ E-Mail/zweiter Tab ↔ ClubCloud-Web ↔ Carambus). Wirkt klein, ist aber häufig — und wenn das falsche Turnier oder eine unvollständige Liste finalisiert wird, ist das nicht mehr rückgängig zu machen.

1. **Login auf ClubCloud-Web** (parallel zu Carambus, weil oft nach Upload-Fehler ausgelöst)
   ![CC-Login-Maske](images/cc-meldeliste-vorher-01-login.png) <!-- TODO: Screenshot durch User -->
2. **Verband-Dashboard öffnen** (z. B. NBV)
   ![Verband-Dashboard](images/cc-meldeliste-vorher-02-verband.png) <!-- TODO: Screenshot durch User -->
3. **Menü → Turniere → spezifisches Turnier öffnen**
   ![Turnier öffnen](images/cc-meldeliste-vorher-03-turnier.png) <!-- TODO: Screenshot durch User -->
4. **Tab „Teilnehmer" / „Meldeliste"**
   ![Tab Teilnehmer](images/cc-meldeliste-vorher-04-tab.png) <!-- TODO: Screenshot durch User -->
5. **Liste auf Vollständigkeit prüfen** (manuell durchscrollen, bei langen Listen erfahrungsgemäß fehleranfällig)
   ![Liste Pruefung](images/cc-meldeliste-vorher-05-liste-pruefen.png) <!-- TODO: Screenshot durch User -->
6. **„Finalisieren"-Button** (genaue UI-Bezeichnung **[SME-CONFIRM]**)
   ![Finalisieren-Button](images/cc-meldeliste-vorher-06-button.png) <!-- TODO: Screenshot durch User -->
7. **Bestätigungs-Dialog**
   ![Bestätigungs-Dialog](images/cc-meldeliste-vorher-07-bestaetigung.png) <!-- TODO: Screenshot durch User -->
8. **Zurück zu Carambus, Upload erneut versuchen**
   ![Carambus Upload](images/cc-meldeliste-vorher-08-carambus-upload.png) <!-- TODO: Screenshot durch User -->

**Häufige Fehlerquellen:** Falsches Turnier finalisiert (nicht rückgängig zu machen); unvollständige Liste finalisiert weil schlecht prüfbar; Übergabe-Pannen wenn TM keine ausreichende CC-Rolle hat (siehe `teilnehmerliste-finalisieren.de.md` Übergabe-Sektion).

## Nachher: Finalisierung mit Claude Desktop

1 Prompt + 2-3 Bestätigungen + 1 finales OK, ~30-60 Sekunden, 1 Kontext (Claude Desktop). Dry-Run-First schützt vor falschem Turnier oder unvollständiger Liste.

1. **„Claude, finalisiere die Meldeliste für {Turnier} — kannst du mir vorher den Dry-Run zeigen?"**
   ![Claude Desktop mit Finalisierungs-Prompt](images/cc-meldeliste-nachher-01-prompt.png) <!-- TODO: Screenshot durch User -->
2. **Claude führt durch Region/Turnier-Bestätigung**, zeigt die aktuelle Teilnehmerliste, zeigt Dry-Run-Effekte, fragt explizit nach OK.
   - „Region: NBV?"
   - „Welches Turnier? (Carambus-ID oder CC-Meisterschaft-ID)"
   - „Hier ist die aktuelle Teilnehmerliste — sind alle Spieler dabei?"
   - „Dry-Run zeigt: nach Finalisierung wären keine Änderungen mehr möglich, CC akzeptiert dann Ergebnis-Uploads. Soll ich das wirklich tun?"
   ![Claude-Konversation Schritt-Sequenz](images/cc-meldeliste-nachher-02-konversation.png) <!-- TODO: Screenshot durch User -->
3. **Bestätigen — Claude finalisiert die Liste; bei fehlender CC-Rolle gibt es eine konkrete Übergabe-Anweisung.**
   ![Erfolg-Meldung oder Eskalation](images/cc-meldeliste-nachher-03-ergebnis.png) <!-- TODO: Screenshot durch User -->

**Was Claude für dich übernimmt:**
- Tool-Sequenz (Region → Turnier → Liste-Anzeige → Dry-Run → echte Aktion) wird vom Spickzettel `cc://workflow/scenarios/meldeliste-finalisieren` deterministisch geführt.
- **Dry-Run-First** ist Pflicht-Pattern: keine destruktive CC-Aktion ohne vorheriges Zeigen der Effekte + explizites User-OK.
- Bei fehlender CC-Rolle (CC gibt 403): Claude eskaliert mit konkreter Übergabe-Anweisung („Bitte den Sportwart anrufen — sobald gemacht, sag Bescheid").
- Bei doppelter Finalisierung erkennt Claude den Fehler-Status und erklärt, dass der Upload jetzt funktionieren sollte.

## Vorher/Nachher-Tabelle

| Phase | Tool/UI | Klick-Anzahl | geschätzte Zeit | Fehler-Anfälligkeit | Kontextwechsel |
|---|---|---|---|---|---|
| **Vorher** | CC-Web-UI | 6-8 | 1-2 min | hoch (falsches Turnier finalisiert; unvollständige Liste übersehen; Übergabe-Pannen) | Carambus ↔ Browser-Tab ↔ CC ↔ Carambus (≥4 Wechsel) |
| **Nachher** | Claude Desktop | 1 Prompt + 2-3 Bestätigungen + 1 finales OK | 30-60 s | niedrig (Dry-Run-First; Liste wird angezeigt; bei 403 konkrete Eskalation) | nur Claude Desktop |

**Was sich besonders auszahlt:** Wochenend-Stapel (mehrere Turniere am selben Tag finalisieren). Vorher: ~10 min konzentriertes Klicken pro Turnier × 3 Turniere = 30 min mit hohem Fehler-Risiko. Nachher: ~3 min im Dialog mit Claude, mit Dry-Run-Schutz pro Turnier.

## Spickzettel-Datei

Die maschinell ausgeführte Schritt-Sequenz steht in `docs/managers/clubcloud-scenarios/meldeliste-finalisieren.de.json` (5 Schritte, JSON-Schema-Format gemäß `docs/developers/clubcloud-mcp-workflow-scenarios.de.md`).

Pattern: `cc_lookup_region` → `cc_lookup_tournament` → `cc_lookup_teilnehmerliste` → `cc_finalize_teilnehmerliste(armed:false)` → User-OK → `cc_finalize_teilnehmerliste(armed:true)`.

## Voraussetzungen

- Dein **Sportwart-Wirkbereich** umfasst gastgebenden Verein + Disziplin des Turniers (`sportwart_location_ids` + `sportwart_discipline_ids`; siehe [`cc-roles`](clubcloud-scenarios/cc-roles.de.md) für die Authority-Brücke). Sonst lehnt der MCP-Server ab — Claude eskaliert mit konkreter Telefon-Übergabe-Anweisung an einen Sportwart mit passendem Wirkbereich oder den Landessportwart.
- Du bist auf der Carambus-Seite Deiner Region (z.B. `https://nbv.carambus.de`) eingeloggt + hast den MCP-Setup-Befehl gepastet (siehe [Cloud-Quickstart](clubcloud-mcp-cloud-quickstart.de.md)).
- Die Teilnehmerliste ist **vollständig** — keine Last-Minute-Anmeldungen mehr erwartet (Finalisierung ist Einweg-Aktion und nicht rückgängig).
- Das Turnier ist in CC angelegt mit allen geplanten Spielern auf der Meldeliste.

## Edge-Cases

- **Fehlender Wirkbereich:** Der MCP-Server lehnt mit Authority-Meldung ab. Claude eskaliert mit konkretem Wortlaut: „Dein Sportwart-Wirkbereich deckt {Verein} / {Disziplin} nicht ab. Bitte den zuständigen Sportwart oder Landessportwart anrufen, dass er die Liste für Dich finalisiert. Sobald das gemacht ist, sag Bescheid." (Pattern aus `teilnehmerliste-finalisieren.de.md` §"Übergabe wenn der Turnierleiter nicht die nötige Berechtigung hat".)
- **Falsches Turnier:** TM bestätigt im Dry-Run-Schritt — Claude zeigt explizit Turnier-Title und Teilnehmer-Anzahl, sodass falsches Turnier erkennbar ist, bevor armed:true ausgeführt wird.
- **Unvollständige Liste:** Schritt 3 (`cc_lookup_teilnehmerliste`) zeigt die Liste explizit + fragt nach Vollständigkeit. Bei „nein" empfiehlt Claude, zuerst die fehlenden Spieler über `cc://workflow/scenarios/anmeldung-aus-email` anzumelden.
- **Doppelte Finalisierung:** CC weist die zweite Finalisierung mit einem Fehler zurück. Claude erkennt den Status und erklärt: „Liste ist bereits finalisiert. Wenn du das vorher gemacht hast (oder ein Kollege), ist das OK — der Upload sollte jetzt funktionieren."

---
*Klick-Reduktion-Doku — Plan 03-03 + Plan 14-G.11 Authority-Refresh (2026-05-16)*
*Spickzettel-Datei: `docs/managers/clubcloud-scenarios/meldeliste-finalisieren.de.json` · Format-Spec: `docs/developers/clubcloud-mcp-workflow-scenarios.de.md` · Hintergrund: `docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md`*
