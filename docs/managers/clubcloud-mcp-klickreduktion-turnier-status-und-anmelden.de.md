# Klick-Reduktion: Turnier-Status prüfen und Spieler anmelden

> **Status:** Doku-Skeleton aus Plan 05-04 (v0.1). Screenshots werden in v0.2 (Termin 2026-08-15)
> mit echtem Sportwart-Walkthrough nachgeliefert. TODO-Image-Markers sind konkret formuliert.

## Worum geht's?

Du hörst von einem Turnier (Forum, Talk im Verein, Kalender, Anruf vom Sportwart) und willst:
(a) den Status sehen — Datum, Ort, Meldeschluss, schon angemeldete Spieler — und
(b) ggf. eigene Spieler ergänzen.

Statt 7-10 Klicks in der ClubCloud-UI (Login → Verband → Menü → Disziplin → Turnierliste →
Detail → Tab wechseln → Spieler suchen → anmelden → bestätigen) führen 3-4 Rückfragen in Claude
Desktop zum gleichen Ergebnis. Das hier ist ein konkretes Vorher/Nachher-Beispiel.

## Vorher: Status-Frage in der ClubCloud-UI

Ungefähr 7-10 Klicks, ~2-3 Minuten, 2-3 Kontextwechsel (Notiz/E-Mail ↔ Browser ↔ ClubCloud).
Bei mehreren Anmeldungen multipliziert sich das.

1. **Login auf ClubCloud-Web**
   ![CC-Login-Maske](images/cc-status-vorher-01-login.png) <!-- TODO: Screenshot der CC-Login-Form mit Verband-Auswahl -->
2. **Verband-Dashboard öffnen** (z.B. NBV)
   ![Verband-Dashboard](images/cc-status-vorher-02-verband.png) <!-- TODO: Screenshot des NBV-Dashboards mit Hauptnavigation -->
3. **Menü → Turniere/Meisterschaften**
   ![Menü Turniere](images/cc-status-vorher-03-menu-turniere.png) <!-- TODO: Screenshot der CC-Hauptnavigation mit aufgeklapptem Turniere-Menü -->
4. **Disziplin auswählen** (z.B. „Eurokegel")
   ![Disziplin-Auswahl](images/cc-status-vorher-04-disziplin.png) <!-- TODO: Screenshot der Disziplin-Filter-Dropdown mit Eurokegel ausgewählt -->
5. **Turnier in der Liste finden + öffnen** (Name-Filter oder durchscrollen)
   ![Turnier-Liste](images/cc-status-vorher-05-turnier-liste.png) <!-- TODO: Screenshot der Turnier-Übersicht mit Filter-Suchleiste; markierte Reihe „NDM Endrunde Eurokegel" -->
6. **Turnier-Detailseite ansehen** (Datum, Ort, Meldeschluss prüfen)
   ![Turnier-Detail](images/cc-status-vorher-06-detail.png) <!-- TODO: Screenshot der Turnier-Detailseite mit allen Header-Daten + Meldeschluss-Hinweis -->
7. **Tab/Sektion „Meldeliste" wechseln** (bereits angemeldete Spieler ansehen)
   ![Meldeliste-Tab](images/cc-status-vorher-07-meldeliste.png) <!-- TODO: Screenshot des Meldeliste-Tabs mit ~5-10 angemeldeten Spielern -->
8. **Spieler-Liste lesen** (Doppelanmeldungen prüfen)
   ![Spieler-Liste](images/cc-status-vorher-08-spielerliste.png) <!-- TODO: Screenshot der Liste mit Spielernamen + Vereinen + Geburtsjahr -->
9. **Falls anmelden: Tab zurück zu „Anmelden"**
   ![Anmelden-Tab](images/cc-status-vorher-09-anmelden-tab.png) <!-- TODO: Screenshot Tab-Wechsel zum Anmelde-Formular -->
10. **Spieler suchen + auswählen + anmelden**
    ![Anmelde-Aktion](images/cc-status-vorher-10-anmelden.png) <!-- TODO: Screenshot der Spielersuche + Treffer + Anmelde-Button -->

## Nachher: Status-Frage in Claude Desktop

Beispieldialog (5-7 Wechsel; basiert auf dem `turnier-status-und-anmelden`-Spickzettel):

```
Du:     Hallo carambus, gib mir den Status zur NDM Endrunde Eurokegel.

Claude: NDM Endrunde Eurokegel, 2026-05-30, Wedel/BCW. Meldeschluss
        2026-05-23. Bereits angemeldet: Müller (BCW), Schmidt (BC Hamburg),
        Weber (BCW). Möchtest Du Spieler ergänzen?

Du:     Ja, melde Gernot Ullrich (BCW) an.

Claude: Gernot Ullrich (BCW, Jg. 1955) gefunden. Erfahrungs-Check: 12
        Eurokegel-Spiele in der laufenden Saison + Ranking vorhanden. Kein
        Plausibilitäts-Problem.
        Dry-Run der Anmeldung (armed:false): IDs konsistent, Konsistenz-Check
        OK. Bestätigst Du mit „armed"?

Du:     armed.

Claude: Eingetragen. Aktuelle Meldeliste: Müller, Schmidt, Weber, Ullrich.
```

Drei kurze Antworten — Status, Spieler, Bestätigung — fertig.

## Aufwands-Vergleich

| Maß | CC-UI (vorher) | Claude (nachher) |
|---|---|---|
| Klicks/Antworten | 7-10 Klicks | 3-4 Antworten |
| Zeit pro Anmeldung | ~2-3 Minuten | ~1 Minute |
| Kontextwechsel | 2-3 (Notiz ↔ Browser ↔ CC) | 0 (alles im Chat) |
| Plausibilitäts-Check | manuell durchdenken | automatisch via Heuristik |
| Doppelanmeldungs-Erkennung | manuell scrollen | automatisch in Antwort enthalten |

Bei mehreren Spielern in einer Sitzung: Klicks und Kontextwechsel multiplizieren sich in CC-UI; in
Claude wiederholt sich der Spieler-Such-Schritt natürlichsprachlich.
