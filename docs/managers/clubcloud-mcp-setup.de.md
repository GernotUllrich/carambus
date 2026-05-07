# ClubCloud-MCP-Server in Claude Desktop einrichten

## Was ist das?

Der Carambus-MCP-Server verbindet Claude Desktop direkt mit deinem Carambus-System und
ClubCloud. Das bedeutet: Du kannst Claude in einer normalen Konversation fragen
"Welche Teilnehmerliste ist in CC für Turnier 123 hinterlegt?" — und Claude antwortet
mit echten Daten, ohne dass du selbst in ClubCloud nachschauen musst.

Der MCP-Server läuft lokal auf deinem Rechner als Hilfsprogramm im Hintergrund.
Claude Desktop startet es automatisch, wenn du Claude öffnest. Deine CC-Zugangsdaten
bleiben auf deinem Rechner und werden niemals an Anthropic übertragen.

Derzeit verfügbare Funktionen:

- **Read-Lookups**: Region, Liga, Turnier, Teilnehmerliste, Team, Verein, Spielbericht,
  Kategorie, Serie, Spielersuche — direkt aus Carambus-DB oder live aus CC
- **Write-Aktion**: Meldeliste in CC finalisieren (`cc_finalize_teilnehmerliste`)
- **Workflow-Dokumentation**: Schritt-für-Schritt-Anleitungen als MCP-Resources abrufbar

## Voraussetzungen

Bevor du anfängst, stelle sicher, dass folgendes vorhanden ist:

- **Claude Desktop** installiert (macOS: [claude.ai/download](https://claude.ai/download))
- **Carambus-Repo** lokal ausgecheckt (z.B. unter `~/DEV/carambus/carambus_api`)
- **Ruby** und `bundler` verfügbar (`ruby --version` zeigt 3.2.x)
- **Eigene CC-Zugangsdaten** (deine ClubCloud-E-Mail-Adresse + Passwort)
- **Verbandsnummer** (`CC_FED_ID`, z.B. `20` für BCW)

## Schritt-für-Schritt-Installation

### Schritt 3.1 — Bundle-Install

Im Carambus-Verzeichnis:

```bash
cd ~/DEV/carambus/carambus_api
bundle install
```

### Schritt 3.2 — Ausführbarkeit von bin/mcp-server prüfen

```bash
ls -la bin/mcp-server
```

Die Datei muss ein `x`-Bit haben (z.B. `-rwxr-xr-x`). Falls nicht:

```bash
chmod +x bin/mcp-server
```

Testlauf (sollte keine Fehlermeldung zeigen, nur kurz starten und wieder beenden):

```bash
CARAMBUS_MCP_MOCK=1 bin/mcp-server --help 2>&1 | head -5 || true
```

### Schritt 3.3 — claude_desktop_config.json öffnen und Snippet einfügen

Öffne die Konfigurationsdatei von Claude Desktop:

**macOS:**
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

Füge den `mcpServers`-Block ein (oder ergänze ihn, wenn bereits andere Server konfiguriert sind):

```json
{
  "mcpServers": {
    "carambus_clubcloud": {
      "command": "/Users/<DEIN-USER>/DEV/carambus/carambus_api/bin/mcp-server",
      "args": [],
      "env": {
        "CC_USERNAME": "deine-cc-email@example.com",
        "CC_PASSWORD": "dein-cc-passwort",
        "CC_FED_ID": "20",
        "CARAMBUS_MCP_MOCK": "0",
        "RAILS_ENV": "production"
      }
    }
  }
}
```

**Wichtig:** Ersetze `/Users/<DEIN-USER>/` durch deinen tatsächlichen Benutzernamen
und trage deine echten CC-Zugangsdaten ein.

Schütze die Datei vor fremdem Zugriff:
```bash
chmod 600 ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

### Schritt 3.4 — Claude Desktop neu starten

Beende Claude Desktop vollständig (Dock-Icon → Beenden) und starte es neu.
Der MCP-Server startet beim ersten Bedarf automatisch.

### Schritt 3.5 — Test: Verfügbare MCP-Tools abfragen

In einer neuen Claude-Desktop-Konversation eingeben:

> Welche MCP-Tools sind verfügbar?

Claude sollte die `cc_lookup_*`-Tools und `cc_finalize_teilnehmerliste` auflisten.
Anschließend testen:

> Suche in CC nach dem Spieler "Müller"

## Sicherheit & Vorsicht

- **`cc_finalize_teilnehmerliste` ist destruktiv**: Diese Aktion sperrt die Meldeliste in CC.
  Claude fragt standardmäßig nach, bevor er sie wirklich ausführt (`armed: true`).
  Lies die Beschreibung, bevor du bestätigst.
- **Dateizugriff absichern**: `chmod 600` auf `claude_desktop_config.json` verhindert,
  dass andere Benutzer desselben Rechners deine CC-Zugangsdaten lesen können.
- **Kein Produktions-CC im Test-Modus**: Für Tests ohne CC-Verbindung setze
  `CARAMBUS_MCP_MOCK=1` — dann werden keine echten CC-Anfragen gesendet.

## Troubleshooting

### "Server disconnected" in Claude Desktop

**Ursache:** STDOUT-Verschmutzung — ein anderes Programm (z.B. `.profile`-Ausgabe,
Rails-Boot-Banner) schreibt auf STDOUT. Der JSON-RPC-Stream wird dadurch korrumpiert.

**Lösung:**
1. Log prüfen: `~/Library/Logs/Claude/mcp-server-carambus_clubcloud.log`
2. Sicherstellen, dass dein Shell-Profil (`.zshrc`, `.bashrc`) keine `echo`-Ausgaben
   produziert, wenn es nicht interaktiv ist.

### "Server failed to start" / Timeout

**Ursache:** Rails-Boot-Latenz ist zu hoch (kalter Start ~1-5s).

**Lösung:** In der `claude_desktop_config.json` ein Timeout erhöhen:
```json
"env": {
  "MCP_TIMEOUT": "15000",
  ...
}
```

### "CC login failed" / "CC_USERNAME env var not set"

**Ursache:** Zugangsdaten fehlen oder sind falsch eingetragen.

**Sofortlösung:** Mock-Mode aktivieren, um die MCP-Verbindung zu testen:
```json
"CARAMBUS_MCP_MOCK": "1"
```
Im Mock-Mode sind keine CC-Zugangsdaten nötig — alle Lookups geben Testdaten zurück.

### Server startet, aber liefert keine Daten

**Ursache:** `RAILS_ENV` fehlt oder zeigt auf eine nicht vorhandene Datenbank.

**Lösung:** `RAILS_ENV=production` setzen und sicherstellen, dass die Produktionsdatenbank
erreichbar ist (oder `RAILS_ENV=development` für lokale Entwicklungsinstanz).

## Mock-Mode für sicheres Ausprobieren

Wenn du den MCP-Server testen möchtest, ohne echte CC-Anfragen zu senden:

```json
"CARAMBUS_MCP_MOCK": "1"
```

Im Mock-Mode gilt:
- Alle `cc_lookup_*`-Tools geben gefälschte Testdaten zurück
- `cc_finalize_teilnehmerliste` mit `armed: true` wird **nicht** ausgeführt
- Keine CC-Zugangsdaten werden benötigt
- Perfekt für Onboarding, Demos und Funktionstests

**Wichtig:** Mock-Mode ist in Production (`RAILS_ENV=production`) deaktiviert —
Carambus erkennt automatisch, wenn jemand vergessen hat, es zu deaktivieren.
