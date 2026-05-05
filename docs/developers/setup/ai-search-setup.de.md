# KI-Suche Setup - Schnellstart

## ⚡ Schnelle Einrichtung (5 Minuten)

### 1. OpenAI API Key besorgen

1. Gehe zu: https://platform.openai.com
2. Erstelle einen Account (falls noch nicht vorhanden)
3. Navigiere zu: "API Keys" im Dashboard
4. Klicke: "Create new secret key"
5. **Kopiere den Key** (beginnt mit `sk-...`)
   
   ⚠️ **WICHTIG:** Der Key wird nur einmal angezeigt!

### 2. Key in Rails Credentials einfügen

**Für Development (lokale Entwicklung):**

```bash
cd /Users/gullrich/DEV/carambus/carambus_master
EDITOR="code --wait" rails credentials:edit --environment development
```

Falls VS Code nicht dein Standard-Editor ist:
```bash
# Mit nano:
EDITOR="nano" rails credentials:edit --environment development

# Mit vim:
EDITOR="vim" rails credentials:edit --environment development

# Mit TextEdit (macOS):
EDITOR="open -W -n" rails credentials:edit --environment development
```

**Füge folgende Zeilen hinzu:**

```yaml
openai:
  api_key: sk-dein-echter-api-key-hier
```

**Speichern:**
- VS Code: `Cmd+S`, dann Editor schließen
- nano: `Ctrl+X`, dann `Y`, dann `Enter`
- vim: `:wq`

**Für Production (auf dem API-Server):**

```bash
ssh www-data@dein-api-server.de
cd /pfad/zum/carambus
EDITOR="nano" rails credentials:edit --environment production
```

Gleichen Inhalt einfügen wie oben.

### 3. Rails Server neu starten

**Development:**
```bash
bin/dev  # oder: rails s
```

**Production:**
```bash
sudo systemctl restart puma-carambus.service
# oder je nach Setup:
sudo systemctl restart puma
```

### 4. Testen

1. Im Browser: Carambus öffnen
2. In der Navigation: **"KI-Assistent"** Button klicken
3. Beispiel-Anfrage eingeben: `"Turniere in Hamburg letzte 2 Wochen"`
4. Enter drücken
5. ✅ Bei Erfolg: Automatische Navigation zur gefilterten Turnier-Liste

## 🔍 Verifizierung

### Prüfen ob API Key geladen wird

**Development:**
```bash
rails runner "puts Rails.application.credentials.dig(:openai, :api_key).present? ? 'API Key gefunden ✓' : 'API Key fehlt ✗'"
```

**Production:**
```bash
RAILS_ENV=production rails runner "puts Rails.application.credentials.dig(:openai, :api_key).present? ? 'API Key gefunden ✓' : 'API Key fehlt ✗'"
```

### Log-Überprüfung

**Development:**
```bash
tail -f log/development.log
```

**Production:**
```bash
tail -f log/production.log
```

Bei erfolgreicher Anfrage siehst du:
```
Processing by Api::AiSearchController#create
Parameters: {"query"=>"Turniere in Hamburg"}
AiSearchService: Query processed successfully
```

Bei fehlendem API Key:
```
⚠️  OpenAI API key not configured in credentials. AI search will not work.
```

## 🚨 Troubleshooting

### Problem: "OpenAI nicht konfiguriert"

**Ursache:** API Key nicht in credentials  
**Lösung:** 
1. Schritt 2 wiederholen
2. Sicherstellen dass `openai:` und `api_key:` richtig eingerückt sind (YAML-Syntax!)
3. Server neu starten

**Richtig:**
```yaml
openai:
  api_key: sk-...
```

**Falsch:**
```yaml
openai:
api_key: sk-...  ❌ (falsche Einrückung)
```

### Problem: Credentials-Datei kann nicht bearbeitet werden

**Fehler:** `Credentials file not found` oder `Key not found`

**Lösung:**

1. **Development Key fehlt:**
   ```bash
   # Key-Datei aus carambus_data kopieren:
   cp ../carambus_data/scenarios/development/credentials/development.key config/credentials/
   ```

2. **Production Key fehlt:**
   ```bash
   # Auf dem Server:
   cp /pfad/zu/carambus_data/credentials/production.key config/credentials/
   ```

3. **Neu generieren (nur als letzter Ausweg!):**
   ```bash
   # Development:
   rm config/credentials/development.yml.enc
   EDITOR="code --wait" rails credentials:edit --environment development
   
   # Achtung: Alte Keys gehen verloren! Backup machen!
   ```

### Problem: Server startet nicht nach Änderung

**Ursache:** Syntax-Fehler in credentials  
**Lösung:**
```bash
# Credentials erneut öffnen und Syntax prüfen
EDITOR="code --wait" rails credentials:edit --environment development

# YAML-Syntax online validieren:
# https://www.yamllint.com/
```

### Problem: "Fehler bei der KI-Anfrage"

**Mögliche Ursachen:**
1. **Kein Guthaben:** OpenAI Account aufladen (min. $5)
2. **Rate Limit:** Zu viele Anfragen (unwahrscheinlich bei normalem Gebrauch)
3. **Netzwerkproblem:** Internet-Verbindung prüfen
4. **Falscher Key:** Key in OpenAI Dashboard überprüfen

**Prüfen:**
```bash
# In Rails Console
rails c

# Test-Anfrage:
client = OpenAI::Client.new
response = client.models.list
puts response
# Sollte Liste von Modellen anzeigen
```

### Problem: KI-Assistent Button wird nicht angezeigt

**Ursache:** JavaScript nicht geladen  
**Lösung:**
```bash
# Assets neu kompilieren:
yarn build
yarn build:css
rails assets:precompile

# Oder in Development:
bin/dev
```

## 💰 Kosten-Management

### Guthaben prüfen

https://platform.openai.com/account/billing/overview

### Nutzung überwachen

https://platform.openai.com/usage

### Budget-Limit setzen

1. Gehe zu: https://platform.openai.com/account/billing/limits
2. Setze "Hard limit" (z.B. $10)
3. Setze "Soft limit" für Email-Benachrichtigungen (z.B. $5)

### Erwartete Kosten

Bei normalem Gebrauch (< 1000 Anfragen/Monat):
- **~€0.08 pro Monat**
- **~€1.00 pro Jahr**

## 📚 Weiterführende Dokumentation

Detaillierte Dokumentation: `docs/ai_search.md`

Dort findest du:
- Beispiele für Suchanfragen
- Alle unterstützten Entities
- Filter-Syntax
- Technische Details

## ✅ Checkliste

- [ ] OpenAI Account erstellt
- [ ] API Key generiert und kopiert
- [ ] Key in development credentials eingefügt
- [ ] Key in production credentials eingefügt (falls deployed)
- [ ] Rails Server neu gestartet
- [ ] Test-Anfrage erfolgreich
- [ ] Budget-Limit in OpenAI gesetzt
- [ ] Dokumentation gelesen

## 🎯 Nächste Schritte

Nach erfolgreichem Setup:

1. **Beispiele ausprobieren** (siehe `docs/ai_search.md`)
2. **Team informieren** über neue Funktion
3. **Feedback sammeln** zur Verbesserung
4. **Nutzung monitoren** im OpenAI Dashboard

---

**Bei Problemen:** Siehe Troubleshooting-Sektion oder `docs/ai_search.md`  
**Status:** MVP - Minimum Viable Product  
**Version:** 1.0.0

