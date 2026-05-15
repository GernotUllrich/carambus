# ClubCloud-MCP Cloud-Quickstart

> **Für Sportwarte, Turnierleiter, Landessportwarte.** 1 Seite. Du loggst Dich auf der Carambus-Seite Deiner Region ein, kopierst einen Setup-Befehl in Dein Terminal — fertig.

---

## Was ist das?

Ein Hilfsmittel, mit dem Du typische ClubCloud-Sportwart-Aufgaben **per natürlicher Sprache in Claude Code** erledigst — statt klick-intensive Form-Submits in der ClubCloud-UI.

Beispiele (was Du tippst → was passiert):

| Du tippst | Tool reagiert mit |
|-----------|-------------------|
| „Status NDM Endrunde Eurokegel?" | Turnier-Detail + Meldeliste + Termine |
| „Anmeldung Müller in Eurokegel" | Dry-Run + Bestätigungs-Frage → Anmeldung |
| „Akkreditierung Müller, Schmidt, Weber in Eurokegel" | 3 Akkreditierungen in einem Step |
| „Meldeschluss eine Woche verschieben" | Dry-Run → Live-Update |

Begriffe wie Meldeliste, Endrangliste, Spielbericht, Teilnehmerliste sind im [ClubCloud-Glossar](clubcloud-scenarios/cc-glossary.de.md) erklärt.

---

## Was Du brauchst (~3 Minuten Vorbereitung)

- **Mac (macOS 12+), Windows (10/11) oder Linux**
- **Claude Code** — gratis von Anthropic: <https://claude.ai/code>
- **Carambus-Account** auf der Seite Deiner Region (z.B. `https://nbv.carambus.de` für NBV-Sportwarte) — Email + Passwort; Dein Carambus-Admin nennt Dir Deine richtige Region-Domain
- **Browser** (Chrome / Firefox / Safari / Edge — egal welcher)
- **Terminal-App** (Mac: Terminal.app · Windows: Git Bash, PowerShell oder cmd · Linux: Standard-Terminal — nur für eine einzige Copy-Paste-Zeile)
- Internetverbindung

> **Per-Region-Hinweis:** Jede Region hat ihre eigene Carambus-Domain (z.B. `nbv.carambus.de`, `bcw.carambus.de`). Dein Carambus-Admin sagt Dir vorab, welche URL für Dich gilt. Alle weiteren URLs in dieser Anleitung leiten sich davon ab.

---

## Setup in 3 Schritten (~5 Minuten)

### Schritt 1 — Claude Code installieren

- Download über <https://claude.ai/code>
- Verify im Terminal:
  ```
  claude --version
  ```

### Schritt 2 — Setup-Befehl auf Deiner Region-Seite holen

- Browser öffnen: `https://nbv.carambus.de/login` (oder Deine Region-Domain) → mit Deinem Account einloggen
- Browser-Tab wechseln zu: `https://nbv.carambus.de/mcp/setup`
- Du siehst eine Seite mit Deinem fertigen Setup-Befehl + Restlaufzeit-Banner Deines Login-Tokens
- Klick auf **„📋 In Zwischenablage kopieren"**

### Schritt 3 — Setup-Befehl in Terminal pasten

- Terminal öffnen
- Befehl pasten (Mac: ⌘+V · Windows/Linux: rechte Maustaste oder Ctrl+Shift+V)
- Enter drücken

**Verify:**

```
claude mcp get carambus-remote
```

Erwartete Ausgabe:

```
carambus-remote:
  Status: ✓ Connected
```

**Smoke-Test in Claude Code:**

- Starte eine **neue Claude-Code-Session**
- Frage: **„Welche carambus-remote Tools hast Du?"**

Erwartete Tool-Anzahl je nach Deiner Rolle:

| Rolle | Anzahl Tools |
|-------|--------------|
| Landessportwart (LSW) | **22 Tools** (volle Suite) |
| Turnierleiter (TL) | **19 Tools** (Akkreditierung am Turniertag) |
| Sportwart (SW) | **16 Tools** (Anmeldungs-Lebenszyklus vor Turnier) |

Wenn falsche Anzahl → Carambus-Admin Bescheid sagen; Dein Wirkbereich (Sportwart-Locations + -Disziplinen bzw. Turnierleiter-Zuweisung) muss noch konfiguriert werden. Details in [`cc-roles`](clubcloud-scenarios/cc-roles.de.md).

---

## Erste Beispiel-Dialoge

Nach erfolgreichem Setup gleich ausprobieren — alles **read-only**, keine Datenänderungen:

- „Welche Region bin ich?"
- „Liste die offenen Turniere in NBV"
- „Status NDM Endrunde Eurokegel?"
- „Suche Spieler Meissner in NBV"

Bei produktiven Aufgaben (Anmeldung, Akkreditierung, Meldeschluss) bekommst Du immer erst einen **Dry-Run mit Bestätigungs-Frage** — keine versehentlichen Datenänderungen möglich.

---

## Login-Token: Lifetime + Renew

- **Dein Login-Token ist 90 Tage gültig** (Default-Konfiguration; Dein Carambus-Admin kann das per Region anders einstellen).
- Auf der Setup-Seite siehst Du immer die **Restlaufzeit** Deines Tokens als Banner — wenn weniger als ~14 Tage übrig sind, sanft renewen.
- **Renew:** `https://nbv.carambus.de/mcp/setup` neu laden → neuen Befehl kopieren → in Terminal pasten (vorher `claude mcp remove carambus-remote -s user`).

---

## Troubleshooting (Kurz-Cheatsheet)

| Symptom | Ursache | Lösung |
|---------|---------|--------|
| /mcp/setup → Weiterleitung auf /login | Nicht eingeloggt | Erst über `https://nbv.carambus.de/login` einloggen, dann zurück zu /mcp/setup |
| Copy-Button kopiert nichts | Browser blockt Clipboard-API (selten) | Code-Block manuell markieren + Cmd/Ctrl+C |
| `claude mcp get` → `Failed to connect` | Token expired (selten — typisch alle ~3 Monate) | Setup-Seite neu laden + neuen Befehl pasten (vorher `claude mcp remove carambus-remote -s user`) |
| 401 nach erfolgreichem Setup | Token expired oder revoked | Token erneuern (Setup-Seite neu laden) |
| Tool-Liste leer / 0 Tools | Wirkbereich nicht konfiguriert | Carambus-Admin kontaktieren — er setzt Sportwart-Locations + -Disziplinen bzw. Turnierleiter-Zuweisung; Details in [`cc-roles`](clubcloud-scenarios/cc-roles.de.md) |
| Setup-Befehl wirft Quoting-Fehler in PowerShell/cmd | Single-Quotes werden anders behandelt | Git Bash nutzen ODER PowerShell-Variante über Carambus-Admin holen |

Bei weiteren Problemen: Dein Carambus-Admin ist erreichbar.

---

## Drehbuch vs. Real-Task — Hin-Rück-Symmetrie-Schutz

Claude führt Workflows **deterministisch nach Spickzettel** ab (siehe nächste Sektion). Wenn Claude bei einer Real-Task von Dir anders fragt als beim Drehbuch — z.B. ein zusätzlicher Disambiguation-Schritt bei mehrdeutigem Spieler-Namen — ist das **Schutz, kein Bug**: Tool prüft auf jeden mehrdeutigen Match und fragt explizit nach (Vorname + Geburtsjahr + Verein), statt zu raten.

**Hin-Rück-Symmetrie:** Bei destruktiven Aktionen (Anmeldung, Akkreditierung, Meldeschluss-Verschiebung, Liste-Finalisierung) zeigt Claude immer erst einen **Dry-Run** mit allen Effekten. Erst Dein explizites „OK" / „armed" / „Bestätige" löst die echte Aktion aus.

---

## Was kann ich tun? — Tagesablauf-Spickzettel

Persona-spezifische Spickzettel sind in Claude Code direkt abrufbar:

- **Sportwart-Tagesablauf vor Turnier:** Anmelde-Lebenszyklus
- **Akkreditierung am Turniertag:** für Turnierleiter
- **Meldeliste finalisieren:** sperrt Liste vor Spielbericht-Upload

Frage Claude: „Zeige Spickzettel sportwart-tagesablauf-vor-turnier" oder „Zeige Spickzettel akkreditierung-am-turniertag".

UX-Vergleich CC-Klicks vs MCP-Workflow (für Walkthrough-Vorbereitung):

- [Anmeldung aus E-Mail](clubcloud-mcp-klickreduktion-anmeldung-aus-email.de.md)
- [Meldeliste finalisieren](clubcloud-mcp-klickreduktion-meldeliste-finalisieren.de.md)
- [Turnier-Status prüfen + anmelden](clubcloud-mcp-klickreduktion-turnier-status-und-anmelden.de.md)

---

## DSGVO + Audit-Trail

- Login + Tool-Aufrufe sind pro User in der Datenbank protokolliert (`mcp_audit_trails`).
- Du kannst jederzeit **DSGVO-Auskunfts-Recht** anfordern (Export Deines Audit-Trails) — Anfrage über Deinen Carambus-Admin; Details in [Setup-Service §DSGVO](clubcloud-mcp-setup-service.de.md#8-dsgvo-compliance--datenschutz).
- Keine ClubCloud-Credentials werden via Claude-Cloud übertragen — alles läuft über Deinen Login-Token an Deine Region-Seite.

---

## Weiterführend

- [`cc-glossary`](clubcloud-scenarios/cc-glossary.de.md) — ClubCloud-Begriffe (Meldeliste, Endrangliste, Spielbericht, …)
- [`cc-roles`](clubcloud-scenarios/cc-roles.de.md) — CC-Rollen + Brücke zu Carambus-MCP-Authority (Wirkbereich-Modell)
- [Setup-Service-Doku](clubcloud-mcp-setup-service.de.md) — Per-Region-Server-Setup, Authority-Console, DSGVO-Vollversion (für Carambus-Admins)

---

*Cloud-Quickstart (Plan 14-G.11, 2026-05-16). Browser-Setup-Pfad ist Default. CLI-Power-User-Variante in [Setup-Service §Power-User-CLI-Anhang](clubcloud-mcp-setup-service.de.md#power-user-cli-anhang).*
