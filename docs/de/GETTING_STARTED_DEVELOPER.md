# 🚀 **Schnelleinstieg für Entwickler**

Willkommen bei Carambus! Dieser Guide hilft dir, schnell mit der Entwicklung zu beginnen.

## 📋 **Voraussetzungen**

- **Ruby 3.2+** (empfohlen: 3.2.1)
- **Rails 7.2+**
- **PostgreSQL 15+**
- **Redis**
- **Git**
- **Docker** (optional, aber empfohlen)
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

## 🐳 **Option 1: Docker-Setup (Empfohlen)**

```bash
# Terminal öffnen und ausführen:
git clone git@github.com:GernotUllrich/carambus.git
cd carambus

# Docker-Setup starten (alles läuft automatisch)
docker-compose -f docker-compose.development.api-server.yml up
```

**Vorteile:**
- ✅ Alle Dependencies werden automatisch installiert
- ✅ Datenbank wird automatisch eingerichtet
- ✅ Keine Konflikte mit lokalen Services
- ✅ Einfach zu starten/stoppen

## 🖥️ **Option 2: Lokales Setup**

```bash
# Repository klonen (WICHTIG: SSH-URL verwenden!)
git clone git@github.com:GernotUllrich/carambus.git
cd carambus

# Dependencies installieren
bundle install
yarn install

# Datenbank einrichten
rails db:create
rails db:migrate
rails db:seed

# Server starten
rails server
```

## 🔑 **Credentials einrichten**

**Wichtig:** Du brauchst die `development.key` und `credentials.yml.enc` von einem funktionierenden System.

```bash
# Diese Dateien in config/credentials/ kopieren:
# - development.key
# - credentials.yml.enc
```

**Woher bekommen?**
- Von einem anderen Entwickler im Team
- Aus deinem lokalen `carambus_api` Ordner
- Vom Team Lead

## 🗄️ **Datenbank einrichten**

```bash
# Datenbank-Dump importieren (falls verfügbar)
gunzip -c carambus_api_development_dump.sql.gz | rails db:execute

# Oder mit leerer Datenbank starten
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

### **Docker läuft nicht**
```bash
# macOS (MacBook):
open -a Docker
# Warten bis "Docker Desktop is running" in der Menüleiste erscheint

# Linux (Server):
sudo systemctl start docker
sudo systemctl status docker

# Windows:
# Docker Desktop über Start-Menü starten

# Dann warten bis Docker läuft, dann:
docker-compose up
```

### **Docker-Container startet nicht**
```bash
# Container stoppen und neu starten
docker-compose down
docker-compose up --build

# Falls User-Berechtigungsprobleme:
# Docker-Container läuft als root, nicht als www-data
# Das ist normal für Development-Umgebung

# Logs überprüfen
docker-compose logs web
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

# Oder Dump importieren
gunzip -c dump.sql.gz | rails db:execute
```

## 🔍 **Erste Schritte nach dem Setup**

1. **Server starten**: `rails server` oder Docker
2. **Browser öffnen**: http://localhost:3000
3. **Admin-Interface**: http://localhost:3000/admin
4. **API testen**: http://localhost:3000/api

## 📚 **Nächste Schritte**

- [Entwicklerhandbuch](DEVELOPER_GUIDE.md) lesen
- [API-Dokumentation](API.md) studieren
- [Datenbankdesign](database_design.md) verstehen
- Mit dem Team sprechen über aktuelle Tasks

## 🆘 **Hilfe benötigt?**

- **Team Lead**: Gernot Ullrich
- **Dokumentation**: Dieses Repository
- **Issues**: GitHub Issues verwenden
- **Chat**: Team-Chat (Slack/Discord)

---

**Viel Erfolg beim Einstieg! 🎯** 