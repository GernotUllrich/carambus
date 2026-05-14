# ClubCloud-MCP Cloud-Quickstart (v0.3+)

> **Für Sportwarte, Turnierleiter, LSW.** 1 Seite. Du musst nur Claude Code installieren und 2 Terminal-Zeilen tippen — Rest läuft auf carambus.de.

---

## Was ist das?

Ein Hilfsmittel, mit dem du typische ClubCloud-Admin-Aufgaben **per natürlicher Sprache in Claude Code** erledigst — statt klick-intensive Form-Submits in der CC-UI.

Beispiele (was du tippst → was passiert):

| Du tippst | Tool reagiert mit |
|-----------|-------------------|
| „Status NDM Endrunde Eurokegel?" | Turnier-Detail + Meldeliste + Termine |
| „Anmelde Müller in Eurokegel" | Dry-Run + Bestätigungs-Frage → Anmeldung |
| „Akk Müller, Schmidt, Weber in Eurokegel" | 3 Akkreditierungen in einem Step |
| „Meldeschluss eine Woche verschieben" | Dry-Run → Live-Update |

---

## Was du brauchst (~5 Minuten Vorbereitung)

- **Mac (macOS 12+), Windows (10/11) oder Linux**
- **Claude Code** — gratis von Anthropic: <https://claude.ai/code>
- **Carambus-Account** auf carambus.de (Email + Passwort; bei Bedarf vorab `Passwort vergessen`-Flow)
- **Terminal-App** (siehe Plattform-Hinweis unten)
- Internetverbindung

---

## Plattform-Hinweis (lesen vor Schritt 3!)

Die Setup-Kommandos unten sind in **Bash-Syntax** (Mac/Linux-Standard).

- **macOS:** Terminal.app öffnen → alle Kommandos funktionieren direkt.
- **Linux:** Dein Standard-Terminal → alle Kommandos funktionieren direkt.
- **Windows:** Drei Wege, **wir empfehlen Git Bash**:
   1. **Git Bash (empfohlen)** — Git für Windows installieren (gratis: <https://git-scm.com/download/win>); danach „Git Bash" als Terminal-App. Alle Kommandos funktionieren **identisch zu Mac/Linux**. Einfachster Pfad für Nicht-Entwickler.
   2. **PowerShell** — native Windows-Shell. Eigene Syntax (siehe Anhang „PowerShell-Variante" am Ende dieser Seite).
   3. **WSL2** — Linux-Subsystem unter Windows (für Power-User). Identisch zu Mac/Linux.

---

## Setup in 6 Schritten (~15 Minuten)

### Schritt 1 — Claude Code installieren

- macOS / Windows: Download über <https://claude.ai/code>
- Linux: via curl-Installer (siehe Anthropic-Doku auf derselben Seite)
- Verify im Terminal:
  ```bash
  claude --version
  ```

### Schritt 2 — Carambus-Login testen

- Öffne <https://carambus.de/login> im Browser
- Logge dich mit deinem Account ein → Dashboard sollte erreichbar sein
- Falls 401/422 → Passwort-Reset-Flow nutzen

### Schritt 3 — Login-Token holen

Im Terminal ausführen (Email + Passwort durch deine ersetzen):

```bash
TOKEN=$(curl -sS -X POST https://carambus.de/login \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"DEINE_EMAIL","password":"DEIN_PW"}}' \
  -D - | grep -i '^authorization:' | sed -E 's/^[Aa]uthorization:[[:space:]]*//' | tr -d '\r\n')

echo "Token: $TOKEN"
```

**Sanity-Check:** Output muss mit `Token: Bearer eyJ...` beginnen (~224 Zeichen). Wenn nicht → siehe Troubleshooting unten.

### Schritt 4 — MCP-Server registrieren

```bash
claude mcp add-json --scope user carambus-remote "{
  \"type\": \"http\",
  \"url\": \"https://carambus.de/mcp?stateless=1\",
  \"headers\": {
    \"Authorization\": \"$TOKEN\",
    \"Accept\": \"application/json, text/event-stream\"
  }
}"
```

### Schritt 5 — Verify

```bash
claude mcp get carambus-remote
```

Erwartete Ausgabe:

```
carambus-remote:
  Scope: User config (available in all your projects)
  Status: ✓ Connected
  Type: http
  URL: https://carambus.de/mcp?stateless=1
  Headers:
    Authorization: Bearer eyJ...
    Accept: application/json, text/event-stream
```

### Schritt 6 — Smoke-Test in Claude Code

- Starte eine **neue Claude-Code-Session** (`claude` im Terminal oder Claude.app neu öffnen)
- Frage: **„Welche carambus-remote Tools hast du?"**

Erwartete Tool-Anzahl je nach deiner Rolle:

| Rolle | Anzahl Tools |
|-------|--------------|
| Landessportwart (LSW) | **22 Tools** (volle Suite) |
| Turnierleiter (TL) | **19 Tools** (Akkreditierung am Turniertag) |
| Sportwart (SW) | **16 Tools** (Anmeldungs-Lebenszyklus vor Turnier) |

Wenn falsche Anzahl → Carambus-Admin Bescheid sagen; deine `mcp_role` muss in der Datenbank angepasst werden.

---

## Erste Beispiel-Dialoge

Nach erfolgreichem Setup gleich ausprobieren — alles **read-only**, keine Datenänderungen:

- „Welche Region bin ich?"
- „Liste die offenen Turniere in NBV"
- „Status NDM Endrunde Eurokegel?"
- „Suche Spieler Meissner in NBV"

Bei produktiven Aufgaben (Anmeldung, Akkreditierung, Meldeschluss) bekommst du immer erst einen **Dry-Run mit Bestätigungs-Frage** — keine versehentlichen Datenänderungen möglich.

---

## Troubleshooting (Kurz-Cheatsheet)

| Symptom | Ursache | Lösung |
|---------|---------|--------|
| `claude mcp get` → `Failed to connect` | Token expired (>24h) | Schritt 3 wiederholen + `claude mcp remove carambus-remote -s user` + Schritt 4 neu |
| Token-Wert in Schritt 3 ist leer | Login-Daten falsch ODER curl-Pipe-Problem | Email/Passwort prüfen; Browser-Login-Test (Schritt 2) wiederholen |
| `$TOKEN` enthält nur "Bearer" (ohne `eyJ...`) | Setup-Doku-Pre-13-06.4-Versionen nutzten `awk '{print $2}'` | Schritt 3 mit der oben gezeigten `sed`-Variante (nicht `awk`) ausführen |
| Tool-Liste leer / 0 Tools | `User.mcp_role` nicht gesetzt | Carambus-Admin kontaktieren |
| 401 nach erfolgreichem Setup | Token expired | Token erneuern (Schritt 3 wiederholen) |

Bei weiteren Problemen: dein Carambus-Admin / die technische Stellvertretung ist erreichbar.

---

## Token-Lifetime + Refresh

- **Bearer-Token ist 24h gültig.**
- Bei Ablauf siehst du in Claude Code einen **401-Fehler**.
- **Refresh:** Schritt 3 (Token holen) + Schritt 4 (MCP neu registrieren — nach `claude mcp remove carambus-remote -s user`) wiederholen.

---

## DSGVO + Audit-Trail

- Login + Tool-Aufrufe sind pro User in der Datenbank protokolliert (`mcp_audit_trails`)
- Du kannst jederzeit **DSGVO-Auskunfts-Recht** anfordern (Export deines Audit-Trails)
- Keine ClubCloud-Credentials werden via Claude-Cloud übertragen — alles läuft über deinen Bearer-Token an carambus.de

---

## Was kommt als nächstes?

Nach erfolgreichem Setup:

1. **Probe-Lauf mit Test-Turnier** (im Walkthrough-Termin mit deinem Carambus-Admin)
2. **Eigene Aufgaben** im echten Sportwart-/Turnierleiter-Alltag

Persona-spezifische Spickzettel (was tippt man typischerweise):

- **Sportwart-Tagesablauf vor Turnier:** Spickzettel-Anker für Anmelde-Lebenszyklus
- **Akkreditierung am Turniertag:** Spickzettel-Anker für Akkreditierungs-Lebenszyklus

Beide werden im Walkthrough-Termin gezeigt + sind direkt in Claude Code abrufbar:
- „Zeige Spickzettel sportwart-tagesablauf-vor-turnier"
- „Zeige Spickzettel akkreditierung-am-turniertag"

---

## Weiterführend (für technisch Interessierte)

- **Vollständige Setup-Service-Doku** (inkl. STDIO-Setup-Pfad, DSGVO-Details, Troubleshooting-Vollversion): <https://gernotullrich.github.io/carambus/managers/clubcloud-mcp-setup-service/>
- **Entwickler-Handbuch** (MCP-Server-Architektur, Tool-Code): <https://gernotullrich.github.io/carambus/developers/clubcloud-mcp-server/>

---

## Anhang — PowerShell-Variante (Windows ohne Git Bash)

Falls du auf Windows weder Git Bash noch WSL2 hast, hier die gleichen Schritte in PowerShell-Syntax. Funktionell identisch zum bash-Pfad oben.

### Schritt 3 (PowerShell) — Token holen

```powershell
$response = Invoke-WebRequest -Uri "https://carambus.de/login" `
  -Method POST `
  -ContentType "application/json" `
  -Headers @{ "Accept" = "application/json" } `
  -Body '{"user":{"email":"DEINE_EMAIL","password":"DEIN_PW"}}'

$TOKEN = $response.Headers["Authorization"]
Write-Host "Token: $TOKEN"
```

**Sanity-Check:** Output muss mit `Token: Bearer eyJ...` beginnen.

### Schritt 4 (PowerShell) — MCP-Server registrieren

```powershell
$config = @{
  type    = "http"
  url     = "https://carambus.de/mcp?stateless=1"
  headers = @{
    Authorization = "$TOKEN"
    Accept        = "application/json, text/event-stream"
  }
} | ConvertTo-Json -Depth 3 -Compress

claude mcp add-json --scope user carambus-remote $config
```

### Schritt 5 + 6 (PowerShell)

Identisch zur bash-Variante:

```powershell
claude mcp get carambus-remote
```

(Die `claude`-CLI selbst ist plattform-unabhängig; nur die Shell-Syntax drumherum unterscheidet sich.)

### Token-Refresh (PowerShell)

Bei 401-Fehler:

```powershell
claude mcp remove carambus-remote -s user
# dann Schritt 3 + 4 wiederholen
```

### PowerShell-spezifische Stolperer

| Symptom | Ursache | Lösung |
|---------|---------|--------|
| `Invoke-WebRequest : Cannot find ...` | Alte PowerShell-Version (<5.1) | Aktuelles PowerShell 7+ via `winget install Microsoft.PowerShell` |
| `$TOKEN` ist leer obwohl Login OK | Authorization-Header-Casing | In Schritt 3 statt `["Authorization"]` ggf. `["authorization"]` (lowercase) versuchen |
| `claude mcp add-json` Syntax-Fehler | JSON-Escaping kaputt | Statt inline `$config` → JSON in temp-Datei schreiben und via `--from-file` (falls Claude Code es unterstützt) ODER zurück zu Git Bash wechseln |

---

*Cloud-Quickstart v0.3+ (Plan 14-01, 2026-05-14). Dieser 1-Seiter ersetzt für Sportwarte/Turnierleiter/LSW die ausführliche Setup-Service-Doku Sektionen 1-8 (STDIO-Pfad). Plattform-Hinweis + PowerShell-Anhang ergänzt für Windows-Kompatibilität.*
