# Carambus Mode Switcher

Der Carambus Mode Switcher ermöglicht es Ihnen, einfach zwischen **LOCAL** und **API** Modi zu wechseln, indem Sie einen einzigen Entwicklungsordner verwenden, wodurch die Notwendigkeit entfällt, zwei separate Ordner zu verwalten.

## 🎯 **Übersicht**

Anstatt separate `carambus` und `carambus_api` Ordner zu haben, können Sie jetzt einen einzigen Ordner mit einem Mode Switcher verwenden, der automatisch die notwendigen Konfigurationsdateien mit ERB-Templates aktualisiert.

## 🔄 **Modus-Unterschiede**

### **LOCAL Modus**
- **carambus_api_url**: `https://newapi.carambus.de/`
- **Datenbank**: `carambus_development`
- **Deploy Server**: Lokaler Testserver (`192.168.178.81`)
- **Deploy Basename**: `carambus`
- **Log-Datei**: `development-local.log` (symbolischer Link)
- **Server Port**: 3001
- **Umgebung**: `development-local`
- **Kontext**: `NBV`
- **Zweck**: Testen der `local_server?` Funktionalität

### **API Modus**
- **carambus_api_url**: Leer (nil)
- **Datenbank**: `carambus_api_development`
- **Deploy Server**: Produktionsserver (`carambus.de`)
- **Deploy Basename**: `carambus_api`
- **Log-Datei**: `development-api.log` (symbolischer Link)
- **Server Port**: 3000
- **Umgebung**: `development-api`
- **Kontext**: Leer (nil)
- **Zweck**: Normale API-Entwicklung

## 🚀 **Verwendung**

### **Rake Tasks (Primäre Methode)**

```bash
# Wechseln zu LOCAL Modus
bundle exec rails mode:local

# Wechseln zu API Modus
bundle exec rails mode:api

# Aktuellen Modus prüfen
bundle exec rails mode:status

# Backup erstellen
bundle exec rails mode:backup
```

### **Manueller Server-Start**

```bash
# LOCAL Modus Server
bundle exec rails server -p 3001 -e development-local

# API Modus Server
bundle exec rails server -p 3000 -e development-api

# LOCAL Modus Konsole
bundle exec rails console -e development-local

# API Modus Konsole
bundle exec rails console -e development-api
```

## 📁 **Geänderte Dateien**

Der Mode Switcher verwendet ERB-Templates, um diese Konfigurationsdateien zu generieren:

1. **`config/carambus.yml`** (generiert aus `config/carambus.yml.erb`)
   - `carambus_api_url` Wert
   - `context` Wert
   - `basename` Wert
   - `carambus_domain` Wert
   - `location_id` Wert
   - `application_name` Wert
   - `club_id` Wert

2. **`config/database.yml`** (generiert aus `config/database.yml.erb`)
   - Entwicklungsdatenbank-Name

3. **`config/deploy.rb`** (generiert aus `config/deploy.rb.erb`)
   - Deploy Basename (behebt Ordner-Namen-Abhängigkeit)

4. **`log/development.log`**
   - Symbolischer Link zu modus-spezifischer Log-Datei
   - `development-local.log` für LOCAL Modus
   - `development-api.log` für API Modus

## 🛡️ **Sicherheitsfunktionen**

### **Automatische Backups**
- Erstellt zeitstempel-basierte Backups vor dem Modus-Wechsel
- Backups werden in `tmp/mode_backups/` gespeichert
- Einfache Wiederherstellung bei Bedarf

### **Status-Prüfung**
- Zeigt aktuelle Konfiguration vor dem Wechsel
- Zeigt Modus-Unterschiede klar an
- Validiert Konfigurationsdateien

### **Template-Validierung**
- Prüft auf erforderliche ERB-Template-Dateien
- Gibt klare Fehlermeldungen aus, wenn Templates fehlen
- Stellt ordnungsgemäße Template-Substitution sicher

## 🎨 **Visuelle Indikatoren**

### **Mode Helper**
Verwenden Sie den `ModeHelper` in Ihren Views, um den aktuellen Modus anzuzeigen:

```erb
<!-- Einfacher Modus-Badge -->
<%= render_mode_indicator %>

<!-- Modus-Badge mit Tooltip -->
<%= render_mode_tooltip %>
```

### **Verfügbare Methoden**
- `current_mode` - Gibt 'LOCAL' oder 'API' zurück
- `mode_badge_class` - CSS-Klassen für Styling
- `mode_icon` - Emoji-Icon (🏠 für LOCAL, 🌐 für API)
- `mode_description` - Menschenlesbare Beschreibung

## 🔧 **Konfiguration**

### **ERB-Templates**
Der Mode Switcher verwendet diese ERB-Template-Dateien:

- **`config/carambus.yml.erb`** - Hauptkonfigurations-Template
- **`config/database.yml.erb`** - Datenbank-Konfigurations-Template  
- **`config/deploy.rb.erb`** - Deployment-Konfigurations-Template

### **Template-Variablen**
Die Templates verwenden diese Variablen, die während des Modus-Wechsels ersetzt werden:

- `<%= carambus_api_url %>` - API-URL für den Modus
- `<%= database %>` - Datenbank-Name für den Modus
- `<%= basename %>` - Deploy Basename für den Modus
- `<%= context %>` - Kontext-Identifier für den Modus
- `<%= carambus_domain %>` - Domain für den Modus
- `<%= location_id %>` - Location-ID für den Modus
- `<%= application_name %>` - Anwendungsname
- `<%= club_id %>` - Club-ID für den Modus

## 📋 **Workflow-Beispiele**

### **Testen der Local Server Funktionalität**
```bash
# Wechseln zu LOCAL Modus
bundle exec rails mode:local

# LOCAL Server starten
bundle exec rails server -p 3001 -e development-local

# local_server? Funktionalität testen
# Die Anwendung verhält sich jetzt so, als würde sie lokal laufen
```

### **Normale API-Entwicklung**
```bash
# Wechseln zu API Modus
bundle exec rails mode:api

# API Server starten
bundle exec rails server -p 3000 -e development-api

# Normale API-Entwicklung mit Produktions-API-Verbindung
```

### **Beide Umgebungen gleichzeitig ausführen**
```bash
# Terminal 1: LOCAL Server starten
bundle exec rails mode:local
bundle exec rails server -p 3001 -e development-local

# Terminal 2: API Server starten
bundle exec rails mode:api
bundle exec rails server -p 3000 -e development-api

# Sie können jetzt beide Umgebungen nebeneinander testen!
```

### **Schnelle Modus-Prüfung**
```bash
# Aktuellen Modus vor Änderungen prüfen
bundle exec rails mode:status

# Ausgabe-Beispiel:
# Current Configuration:
#   API URL: https://newapi.carambus.de/
#   Context: NBV
#   Database: carambus_development
#   Deploy Basename: carambus
#   Log File: development-local.log
# Current Mode: LOCAL
```

## 🚨 **Wichtige Hinweise**

1. **Datenbank-Erstellung**: Sie müssen beide Datenbanken erstellen:
   ```bash
   # Option 1: Bestehenden Datenbank-Dump importieren (empfohlen)
   createdb carambus_development
   psql -d carambus_development -f /pfad/zu/ihrem/dump.sql
   
   # Option 2: Neue Datenbank erstellen (falls kein Dump verfügbar)
   bundle exec rails db:create RAILS_ENV=development
   # Dann Modi wechseln und die andere Datenbank erstellen
   ```

2. **ERB-Templates**: Stellen Sie sicher, dass alle erforderlichen ERB-Template-Dateien existieren:
   - `config/carambus.yml.erb`
   - `config/database.yml.erb`
   - `config/deploy.rb.erb`

3. **Umgebungsvariablen**: Der Mode Switcher bewahrt Ihre bestehende Umgebungsvariablen-Konfiguration.

4. **Git-Integration**: Konfigurationsänderungen werden nicht automatisch committed. Committen Sie Modus-Änderungen bei Bedarf.

5. **Backup-Wiederherstellung**: Um von einem Backup wiederherzustellen:
   ```bash
   cp tmp/mode_backups/config_backup_TIMESTAMP/* config/
   ```

## 🔍 **Fehlerbehebung**

### **Häufige Probleme**

1. **Fehlende ERB-Templates**: Stellen Sie sicher, dass alle Template-Dateien existieren:
   ```bash
   ls -la config/*.erb
   ```

2. **Datenbank-Verbindungsfehler**: Stellen Sie sicher, dass beide Datenbanken existieren:
   ```bash
   # Option 1: Bestehenden Datenbank-Dump importieren (empfohlen)
   createdb carambus_development
   psql -d carambus_development -f /pfad/zu/ihrem/dump.sql
   
   # Option 2: Neue Datenbank erstellen (falls kein Dump verfügbar)
   bundle exec rails db:create RAILS_ENV=development
   ```

3. **Konfiguration nicht aktualisiert**: Prüfen Sie Dateiberechtigungen und versuchen Sie bei Bedarf `sudo`.

4. **Template-Substitutionsfehler**: Überprüfen Sie die ERB-Syntax in Template-Dateien.

### **Verifikation**
Nach dem Modus-Wechsel die Änderungen verifizieren:

```bash
# carambus.yml prüfen
grep -A 5 "development:" config/carambus.yml

# database.yml prüfen
grep -A 3 "development:" config/database.yml

# deploy.rb basename prüfen
grep "set :basename," config/deploy.rb

# Log-Datei-Link prüfen
ls -la log/development.log
```

### **Template-Debugging**
Um Template-Probleme zu debuggen:

```bash
# Template-Inhalt prüfen
cat config/carambus.yml.erb
cat config/database.yml.erb
cat config/deploy.rb.erb

# Überprüfen, ob Template-Variablen korrekt formatiert sind
grep -n "<%=" config/*.erb
```

---

*Dieser erweiterte Mode Switcher verwendet ERB-Templates für bessere Wartbarkeit und eliminiert die Komplexität der Verwaltung von zwei separaten Entwicklungsordnern, während eine klare Trennung zwischen lokalen Tests und API-Entwicklungsmodi beibehalten wird.* 