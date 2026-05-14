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

## Was du brauchst (~3 Minuten Vorbereitung)

- **Mac (macOS 12+), Windows (10/11) oder Linux**
- **Claude Code** — gratis von Anthropic: <https://claude.ai/code>
- **Carambus-Account** auf carambus.de (Email + Passwort; bei Bedarf vorab `Passwort vergessen`-Flow)
- **Browser** (Chrome/Firefox/Safari/Edge — egal welcher)
- **Terminal-App** (Mac: Terminal.app / Windows: Git Bash, PowerShell oder cmd / Linux: Standard-Terminal — für eine einzige Copy-Paste-Zeile)
- Internetverbindung

---

## Setup in 3 Schritten (~5 Minuten)

### Schritt 1 — Claude Code installieren

- Download über <https://claude.ai/code>
- Verify im Terminal:
  ```
  claude --version
  ```

### Schritt 2 — Setup-Befehl auf carambus.de holen

- Browser öffnen: <https://carambus.de/login> → mit deinem Account einloggen
- Browser-Tab wechseln zu: <https://carambus.de/mcp/setup>
- Du siehst eine Seite mit deinem fertigen Setup-Befehl
- Klick auf **„📋 In Zwischenablage kopieren"**

### Schritt 3 — Setup-Befehl in Terminal pasten

- Terminal öffnen
- Befehl pasten (Mac: ⌘+V / Windows/Linux: rechte Maustaste oder Ctrl+Shift+V)
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
| /mcp/setup → Weiterleitung auf /login | Nicht eingeloggt | Erst über <https://carambus.de/login> einloggen, dann zurück zu /mcp/setup |
| Copy-Button kopiert nichts | Browser blockt Clipboard-API (selten) | Code-Block manuell markieren + Cmd/Ctrl+C |
| `claude mcp get` → `Failed to connect` | Token expired (>24h) | <https://carambus.de/mcp/setup> neu laden + neuen Befehl pasten (vorher `claude mcp remove carambus-remote -s user`) |
| 401 nach erfolgreichem Setup | Token expired | Token erneuern (Setup-Seite neu laden) |
| Tool-Liste leer / 0 Tools | `User.mcp_role` nicht gesetzt | Carambus-Admin kontaktieren |
| Setup-Befehl wirft Quoting-Fehler in PowerShell/cmd | Single-Quotes werden anders behandelt | Git Bash nutzen ODER CLI-Anhang am Ende dieser Seite |

Bei weiteren Problemen: dein Carambus-Admin / die technische Stellvertretung ist erreichbar.

---

## Token-Lifetime + Refresh

- **Bearer-Token ist 24h gültig.**
- Bei Ablauf siehst du in Claude Code einen **401-Fehler**.
- **Refresh:** <https://carambus.de/mcp/setup> neu laden → neuen Befehl kopieren → in Terminal pasten (vorher `claude mcp remove carambus-remote -s user`).

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

## Anhang — CLI-Setup für Power-User

Falls du keinen Browser nutzen willst oder Setup automatisieren möchtest (z.B. CI/CD-Pipeline, mehrere Maschinen): hier der direkte CLI-Pfad.

### Bash-Variante (Mac / Linux / Windows mit Git Bash oder WSL2)

```bash
# 1. Token holen
TOKEN=$(curl -sS -X POST https://carambus.de/login \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"DEINE_EMAIL","password":"DEIN_PW"}}' \
  -D - | grep -i '^authorization:' | sed -E 's/^[Aa]uthorization:[[:space:]]*//' | tr -d '\r\n')
echo "Token: $TOKEN"   # erwartet: Bearer eyJ...

# 2. MCP-Server registrieren
claude mcp add-json --scope user carambus-remote "{
  \"type\": \"http\",
  \"url\": \"https://carambus.de/mcp?stateless=1\",
  \"headers\": {
    \"Authorization\": \"$TOKEN\",
    \"Accept\": \"application/json, text/event-stream\"
  }
}"

# 3. Verify
claude mcp get carambus-remote
```

### PowerShell-Variante (Windows nativ)

```powershell
# 1. Token holen
$response = Invoke-WebRequest -Uri "https://carambus.de/login" `
  -Method POST `
  -ContentType "application/json" `
  -Headers @{ "Accept" = "application/json" } `
  -Body '{"user":{"email":"DEINE_EMAIL","password":"DEIN_PW"}}'
$TOKEN = $response.Headers["Authorization"]
Write-Host "Token: $TOKEN"   # erwartet: Bearer eyJ...

# 2. MCP-Server registrieren
$config = @{
  type    = "http"
  url     = "https://carambus.de/mcp?stateless=1"
  headers = @{
    Authorization = "$TOKEN"
    Accept        = "application/json, text/event-stream"
  }
} | ConvertTo-Json -Depth 3 -Compress

claude mcp add-json --scope user carambus-remote $config

# 3. Verify
claude mcp get carambus-remote
```

### CLI-spezifische Stolperer

| Symptom | Ursache | Lösung |
|---------|---------|--------|
| Token-Wert beginnt nicht mit `Bearer eyJ...` (Bash) | Login-Daten falsch ODER curl-Pipe-Problem | Email/Passwort prüfen; Browser-Login-Test (https://carambus.de/login) wiederholen |
| `$TOKEN` enthält nur "Bearer" (ohne `eyJ...`) | Pre-Plan-13-06.4-Snippet nutzte `awk '{print $2}'` | Die oben gezeigte `sed`-Variante nutzen (nicht `awk`) |
| `Invoke-WebRequest : Cannot find ...` (PowerShell) | Alte PowerShell-Version (<5.1) | Aktuelles PowerShell 7+ via `winget install Microsoft.PowerShell` |
| `claude mcp add-json` Quoting-Fehler (PowerShell) | JSON-Escaping divergent | Browser-Pfad nutzen ODER Git Bash installieren |

**Token-Refresh** (CLI): identisch zum Browser-Pfad — vor neuem Setup ein `claude mcp remove carambus-remote -s user` ausführen, dann obigen Block neu laufen lassen.

---

*Cloud-Quickstart v0.3+ (Plan 14-01.5, 2026-05-14). Browser-Setup-Pfad ist Default; CLI-Anhang für Power-User erhalten. Ersetzt für Sportwarte/Turnierleiter/LSW die ausführliche Setup-Service-Doku Sektionen 1-8 (STDIO-Pfad).*
