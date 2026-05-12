# ClubCloud-MCP-Server: Quickstart für die technische Stellvertretung

> 🛑 **STOP — bist Du selbst der Club-Sportwart?**
>
> Diese Doku ist NICHT für Dich. Sie richtet sich an Deine technische Stellvertretung
> (Landessportwart, Carambus-Admin oder Carambus-Entwickler). Du brauchst keinen
> Code-Editor und kein Terminal.
>
> **Deine 2 Optionen:**
>
> 1. **Setup-Service vor Ort:** Frag Deinen Carambus-Admin nach einem Setup-Termin — er
>    installiert den MCP-Server direkt auf Deinem Rechner (siehe
>    [Setup-Service-Doku](clubcloud-mcp-setup-service.de.md)). Danach bedienst Du den MCP-Server
>    über Claude Desktop ohne weitere Technik.
> 2. **Aufgaben weiterleiten:** Schick Deine Anmelde-/Cleanup-/Akkreditierungs-Aufgaben
>    per E-Mail/Telefon an Deine technische Stellvertretung — sie nutzt den MCP-Server für
>    Dich (siehe [Sportwart-FAQ](#sportwart-faq--wenn-du-als-sportwart-hier-landest) weiter
>    unten in dieser Doku).

> **Wer Du sein solltest, um diese Doku produktiv zu nutzen:**
> Du bist die technische Stellvertretung des Club-Sportwarts (Landessportwart, Carambus-Admin
> oder Carambus-Entwickler). Du hast einen Mac/Windows/Linux mit Terminal und kannst eine
> JSON-Konfigurationsdatei editieren. Der Club-Sportwart selbst bedient den MCP-Server NICHT —
> er leitet seine Aufgaben per E-Mail/Telefon an Dich weiter (siehe Sportwart-FAQ unten).
>
> **Wenn Du selbst der Sportwart bist:** Springe zur [Sportwart-FAQ](#sportwart-faq--wenn-du-als-sportwart-hier-landest) — Du brauchst eine technische Person als Stellvertretung.

## Worum geht es?

Der MCP-Server bündelt die häufigsten ClubCloud-Admin-Aufgaben in Claude Desktop. Statt 12-15 Klicks pro Turnieranmeldung in der CC-UI tippst Du eine natürlichsprachliche Nachricht in Claude und bestätigst 2-4 Rückfragen. Drei Spickzettel decken die Hauptworkflows ab: E-Mail-Anmeldung, Status-Frage zu einem Turnier, und das Sperren der Meldeliste.

## In 5 Minuten startklar

1. **Claude Desktop installieren.** macOS-Download: [claude.ai/download](https://claude.ai/download). Windows ist verfügbar; Linux nutze die Web-Version + lokalen Server.
2. **Carambus-Repo lokal verfügbar machen.** Ein Carambus-Region-Checkout reicht (z.B. `~/DEV/carambus/carambus_bcw` für die NBV-Region). Falls noch nicht vorhanden, Carambus-Admin fragen. Die Region wird per `CC_REGION`-Environment-Variable konfiguriert (Default: `NBV`).
3. **`claude_desktop_config.json` öffnen.**
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`
4. **Folgenden Eintrag hinzufügen** (Pfad zu Deinem lokalen Carambus-Repo anpassen):
   ```json
   {
     "mcpServers": {
       "carambus-clubcloud": {
         "command": "/Pfad/zu/deinem/carambus_bcw/bin/mcp-server",
         "env": {
           "CC_REGION": "NBV"
         }
       }
     }
   }
   ```
5. **Claude Desktop neu starten.** Der MCP-Server wird automatisch von Claude gestartet, sobald Du den Chat öffnest.
6. **Im Chat fragen:** „Liste mir alle offenen Eurokegel-Turniere im NBV." Wenn Du eine konkrete Liste mit Namen + Datum bekommst, läuft der Server.

Bei Problemen siehe Setup-Doku ([clubcloud-mcp-setup.de.md](clubcloud-mcp-setup.de.md)) §Troubleshooting.

## Erste echte Aufgabe — Status zu einem Turnier

Beispieldialog mit dem Spickzettel `turnier-status-und-anmelden`:

```
Du:     Hallo carambus, gib mir den Status zur NDM Endrunde Eurokegel.

Claude: NDM Endrunde Eurokegel, 2026-05-30, Wedel/BCW. Meldeschluss
        2026-05-23. Bereits angemeldet: Müller, Schmidt, Weber.
        Möchtest Du Spieler ergänzen?

Du:     Ja, melde Gernot Ullrich an.

Claude: Ich finde 2 Spieler namens Gernot Ullrich. Gernot Ullrich (Jg. 1955,
        BCW) oder Gernot Ullrich (Jg. 1972, BC Hamburg)?

Du:     BCW.

Claude: Gernot Ullrich (BCW) hat 12 Eurokegel-Spiele in der laufenden Saison —
        Plausibilitäts-Check OK. Dry-Run der Anmeldung (armed:false): IDs
        passen, Konsistenz-Check OK. Bestätigst Du mit „armed"?

Du:     armed.

Claude: Eingetragen. Aktuelle Meldeliste: Müller, Schmidt, Weber, Ullrich.
```

Drei kurze Rückfragen, fertig — statt 8-10 Klicks in der CC-UI.

## Verfügbare Spickzettel

Spickzettel sind strukturierte Schritt-für-Schritt-Anleitungen, die Claude Desktop als MCP-Resources unter `cc://workflow/scenarios/{slug}` abruft. Du kannst sie auch direkt zitieren („nutze den Spickzettel turnier-status-und-anmelden").

| Slug | Wann nutzen? | Trigger |
|---|---|---|
| `anmeldung-aus-email` | Du hast eine E-Mail mit Spielerliste vom Sportwart | E-Mail-getriggert |
| `turnier-status-und-anmelden` | Du fragst nach dem Status eines Turniers + meldest ggf. an | Status-getriggert |
| `meldeliste-finalisieren` | Liste vor Turnier sperren (destruktiv, `armed:true` Pflicht) | Destruktive Schreibaktion |

Pro Slug existiert ein Vorher/Nachher-Vergleich CC-UI vs. Claude:
- [`clubcloud-mcp-klickreduktion-anmeldung-aus-email.de.md`](clubcloud-mcp-klickreduktion-anmeldung-aus-email.de.md)
- [`clubcloud-mcp-klickreduktion-turnier-status-und-anmelden.de.md`](clubcloud-mcp-klickreduktion-turnier-status-und-anmelden.de.md)
- [`clubcloud-mcp-klickreduktion-meldeliste-finalisieren.de.md`](clubcloud-mcp-klickreduktion-meldeliste-finalisieren.de.md)

## Sportwart-FAQ — Wenn Du als Sportwart hier landest

**Frage:** Ich bin Club-Sportwart und habe nur einen Browser. Kann ich den MCP-Server selbst benutzen?

**Antwort:** In v0.1 (heute): Nein. Der MCP-Server läuft technisch auf einem Rechner mit Carambus-Setup (Ruby-Umgebung, claude_desktop_config.json, Carambus-Repo). Diese Umgebung hast Du nicht, und Du musst sie auch nicht haben.

**Stellvertretungs-Modell:**

1. **Sportwart sammelt Anmelde-Anfragen** (E-Mails, Telefon-Notizen).
2. **Sportwart leitet die Anfrage weiter** an seine technische Stellvertretung — typischerweise:
   - Den **Landessportwart** (falls technisch versiert + Carambus-Setup vorhanden)
   - Den **Carambus-Admin** Eures Vereins (falls vorhanden)
   - Den **Carambus-Entwickler** (Notfall-Pfad)
3. **Stellvertretung bedient den MCP-Server** mit dem turnier-status-und-anmelden- oder anmeldung-aus-email-Spickzettel. Dauer: ~2-3 Minuten pro Anmeldung.
4. **Stellvertretung bestätigt zurück an den Sportwart**: „Eintrag gemacht, hier die aktuelle Meldeliste."

**Frage:** Wann kann ich es selbst benutzen?

**Antwort:** **v0.2** (Termin: 2026-08-15) bringt den vollständigen Sportwart-Workflow inklusive der heute fehlenden Tools (Meldeschluss verschieben, Teilnehmerliste-Pflege am Turniertag) — siehe v0.2-Lücken-Block unten. v0.2 wird zusätzlich einen **Setup-Service** anbieten: ein Carambus-Admin kommt einmalig zu Dir, installiert Claude Desktop + den MCP-Server, und Du kannst danach im Browser-Stil mit Claude Desktop arbeiten ohne weiteren Terminal-Bedarf.

## Was v0.1 NICHT abdeckt — v0.2-Backlog

| Aufgabe | v0.1 (heute) | v0.2 (Termin 2026-08-15) |
|---|---|---|
| Spieler vor Meldeschluss anmelden | ✓ `cc_register_for_tournament` | ✓ |
| **Meldeschluss verschieben** (z.B. wegen drohender Absage) | ❌ in CC-UI weiter | 🎯 geplant: `cc_update_tournament_deadline` |
| Spieler NACH Meldeschluss anmelden (Nachmeldungen) | ❌ blockiert auf #2 | 🎯 funktioniert nach #2 |
| Akkreditierungs-Workflow / Teilnehmerliste-Pflege am Turniertag | ❌ in CC-UI weiter | 🎯 geplant: `cc_add_participant_to_finalized_list` |
| Liste vor Turnier sperren | ✓ `cc_finalize_teilnehmerliste` | ✓ |
| Spieler abmelden (Stornierung) | ❌ in CC-UI weiter | 🎯 `cc_unregister_for_tournament` (Substrat aus Phase 4 bereit) |

**Bis v0.2 fertig ist (geplant 2026-08-15), erledige diese Aufgaben in der CC-UI wie bisher.** Der Sportwart bzw. seine technische Stellvertretung bleiben in den fehlenden Workflows beim klassischen Klick-Pfad.

## Wo gibt's mehr Hilfe?

- **Setup-Doku** [clubcloud-mcp-setup.de.md](clubcloud-mcp-setup.de.md) — für Erstinstallation, Troubleshooting, Mock-Mode-Tests
- **Entwickler-Handbuch** [`docs/developers/clubcloud-mcp-server.de.md`](../developers/clubcloud-mcp-server.de.md) — nur falls Du den Server erweitern willst
- **4-Schichten-Sicherheitsnetz** für destruktive Tools (`armed:true` Pflicht, Mock-Mode-Default in Tests, Production-Block, Detail-Dry-Run-Echo) — gilt für alle Schreibaktionen wie Meldeliste-Finalisieren
- **Bug? Fehlermeldung?** Carambus-Issue-Tracker oder direkter Kontakt zum Carambus-Admin
