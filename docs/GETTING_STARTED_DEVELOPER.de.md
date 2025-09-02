# 🚀 **Schnelleinstieg für Entwickler**

Willkommen bei Carambus! Dieser Guide hilft dir, schnell mit der Entwicklung zu beginnen.

## 📋 **Voraussetzungen**

- **Ruby 3.2+** (empfohlen: 3.2.1)
- **Rails 7.2+**
- **PostgreSQL 15+**
- **Redis**
- **Git**
- **SSH-Key** für GitHub-Zugriff

## 🔑 **GitHub-Zugriff einrichten (Wichtig!)**

**Das Repository verwendet SSH-Authentifizierung, nicht HTTPS!**

### **Schritt 1: SSH-Key generieren**
```bash
# SSH-Key generieren
ssh-keygen -t rsa -b 4096 -C "deine-email@example.com"

# SSH-Key zu ssh-agent hinzufügen
ssh-add ~/.ssh/id_rsa

# Öffentlichen Schlüssel anzeigen
cat ~/.ssh/id_rsa.pub
```

### **Schritt 2: SSH-Key zu GitHub hinzufügen**
1. Den öffentlichen Schlüssel kopieren (Ausgabe von `cat ~/.ssh/id_rsa.pub`)
2. GitHub → Settings → SSH and GPG keys → "New SSH key"
3. Schlüssel einfügen und speichern

### **Schritt 3: SSH-Verbindung testen**
```bash
# Test der SSH-Verbindung
ssh -T git@github.com

# Sollte ausgeben: "Hi username! You've successfully authenticated..."
```

## 🖥️ **Lokales Setup**

```bash
# Repository klonen (WICHTIG: SSH-URL verwenden!)
git clone git@github.com:GernotUllrich/carambus.git
cd carambus

# Dependencies installieren
bundle install
yarn install

# Datenbank einrichten
# Option 1: Bestehenden Datenbank-Dump importieren (empfohlen)
# Stellen Sie sicher, dass Sie eine Datenbank-Dump-Datei haben (z.B., carambus_api_development_YYYYMMDD_HHMMSS.sql)
# Datenbank erstellen und Dump importieren:
createdb carambus_development
psql -d carambus_development -f /pfad/zu/ihrem/dump.sql

# Option 2: Neue Datenbank erstellen (falls kein Dump verfügbar)
rails db:create
rails db:migrate
rails db:seed

# Server starten
rails server
```

## 🔑 **Credentials einrichten**

**Wichtig:** Du brauchst die `development.key` und `credentials.yml.enc` von einem funktionierenden System.

### **Schritt 1: Credentials kopieren**
```bash
# Diese Dateien in config/credentials/ kopieren:
# - development.key
# - credentials.yml.enc

# Beispiel (von einem anderen System):
cp /path/to/working/system/config/credentials/development.key config/credentials/
cp /path/to/working/system/config/credentials/credentials.yml.enc config/credentials/
```

### **Schritt 2: Datenbank-Dump importieren**
```bash
# Datenbank-Dump importieren:
psql -d carambus_development -f /path/to/carambus_api_development_dump.sql
```

**Woher bekommen?**
- Von einem anderen Entwickler im Team
- Aus deinem lokalen `carambus_api` Ordner
- Vom Team Lead

## 🗄️ **Datenbank einrichten**

### **Option 1: Automatisch über Enhanced Mode System (Empfohlen)**
```bash
# 1. Enhanced Mode konfigurieren - das importiert automatisch alle Dumps!
bundle exec rails 'mode:api' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_development

# 2. Server starten
rails server
```

### **Option 2: Manuell über psql**
```bash
# Datenbank-Dump manuell importieren
gunzip -c /path/to/carambus_api_development_dump.sql.gz | psql -d carambus_development
```

### **Option 3: Mit leerer Datenbank starten**
```bash
# Falls kein Dump vorhanden:
rails db:create
rails db:migrate
```

## 🚨 **Häufige Probleme & Lösungen**

### **GitHub-Zugriff funktioniert nicht**
```bash
# SSH-Key überprüfen
ssh-add -l

# Falls leer, Key hinzufügen:
ssh-add ~/.ssh/id_rsa

# SSH-Verbindung testen
ssh -T git@github.com
```

### **PostgreSQL läuft nicht**
```bash
# PostgreSQL starten
sudo systemctl start postgresql
sudo systemctl status postgresql

# Oder auf macOS:
brew services start postgresql
```

### **Redis läuft nicht**
```bash
# Redis starten
sudo systemctl start redis
sudo systemctl status redis

# Oder auf macOS:
brew services start redis
```

### **Ports sind belegt**
```bash
# Ports überprüfen
lsof -i :3000
lsof -i :5432
lsof -i :6379

# Falls belegt, andere Ports verwenden oder Services stoppen
```

### **Credentials-Fehler**
```bash
# Entwicklungsschlüssel kopieren
cp /path/to/working/system/config/credentials/development.key config/credentials/
cp /path/to/working/system/config/credentials/credentials.yml.enc config/credentials/
```

### **Datenbank-Fehler**
```bash
# Datenbank neu erstellen
rails db:drop
rails db:create
rails db:migrate

# Oder Dump importieren (über psql)
gunzip -c /path/to/dump.sql.gz | psql -h localhost -U www_data -d carambus_api_development
```

**Hinweis zu Dump-Import-Fehlern**: Beim Import eines Datenbank-Dumps können einige Fehler auftreten, die ignoriert werden können:
- `relation "table_name" already exists` - Tabelle existiert bereits
- `multiple primary keys for table "table_name" are not allowed` - Primärschlüssel bereits definiert
- `relation "index_name" already exists` - Index existiert bereits
- `constraint "constraint_name" for relation "table_name" already exists` - Constraint bereits definiert
- `duplicate key value violates unique constraint` - Metadaten bereits gesetzt

Diese Fehler sind normal, wenn die Datenbank bereits teilweise initialisiert wurde.

## 🔍 **Erste Schritte nach dem Setup**

1. **Server starten**: `rails server`
2. **Browser öffnen**: http://localhost:3000
3. **Admin-Interface**: http://localhost:3000/admin
4. **API testen**: http://localhost:3000/api

## 📚 **Nächste Schritte**

- [Entwicklerhandbuch](DEVELOPER_GUIDE.md) lesen
- [API-Dokumentation](API.md) studieren
- [Datenbankdesign](database_design.md) verstehen
- [Enhanced Mode System](enhanced_mode_system.de.md) für Deployment-Konfiguration
- Mit dem Team sprechen über aktuelle Tasks

## 🆘 **Hilfe benötigt?**

- **Team Lead**: Gernot Ullrich
- **Dokumentation**: Dieses Repository
- **Issues**: GitHub Issues verwenden
- **Chat**: Team-Chat (Slack/Discord)

---

**Viel Erfolg beim Einstieg! 🎯** 