# 🚀 Getting Started Guide für neue Carambus-Entwickler

## 👋 Willkommen im Team!

Dieser Guide hilft dir, in 2-3 Stunden eine funktionierende Entwicklungsumgebung aufzusetzen und deine erste Änderung zu implementieren.

## 🎯 Was du erreichen wirst:

1. ✅ **Entwicklungsumgebung läuft** auf deinem MacBook
2. ✅ **API Server startet** erfolgreich
3. ✅ **Erste Änderung** implementiert und getestet
4. ✅ **Verständnis** der Carambus-Architektur

## 📋 Voraussetzungen

### Auf deinem MacBook:
- **Ruby 3.2+** (wird automatisch installiert)
- **PostgreSQL** (wird automatisch installiert)
- **Git** (sollte bereits installiert sein)
- **Docker Desktop** (für das empfohlene Setup)

### Keine Vorkenntnisse nötig:
- ❌ Docker (wird erklärt)
- ❌ Carambus-spezifisches Wissen
- ❌ Billard-Fachwissen

## 🚀 Schnellstart (30 Minuten)

### Option 1: Docker-Setup (Empfohlen)
```bash
# Terminal öffnen und ausführen:
git clone https://github.com/GernotUllrich/carambus.git
cd carambus

# Docker-Setup starten (alles läuft automatisch)
docker-compose -f docker-compose.development.api-server.yml up
```

### Option 2: Manuelles Setup (Für Experten)
```bash
# Abhängigkeiten installieren
bundle install

# Datenbank erstellen (falls nicht vorhanden)
rails db:create

# Server starten
rails server -p 3001
```

### Schritt 3: Erfolg testen
Öffne http://localhost:3001 in deinem Browser. Du solltest die Carambus-Startseite sehen!

## 🐳 Docker-Setup verstehen

### Was macht das Docker-Setup?
Das `docker-compose.development.api-server.yml` startet automatisch:

- **PostgreSQL** auf Port 5433 (vermeidet Konflikte)
- **Redis** auf Port 6380 (vermeidet Konflikte)  
- **Rails** auf Port 3001 (vermeidet Konflikte)
- **Alle Abhängigkeiten** werden automatisch installiert

### Ports verstehen:
- **Web-Server**: Port 3001 (http://localhost:3001)
- **PostgreSQL**: Port 5433 (lokale Entwicklung)
- **Redis**: Port 6380 (lokale Entwicklung)

### Environment-Variablen:
Das Setup verwendet `env.development.api-server` mit:
- `RAILS_ENV=development`
- `DEPLOYMENT_TYPE=API_SERVER`
- Angepasste Ports für lokale Entwicklung

## 🔑 Credentials und lokale Entwicklung

### Was du vom Team-Lead brauchst:
Der Team-Lead gibt dir einen **lokalen Entwicklungsordner** (außerhalb des Repositories) mit:

- **Credentials**: `development.key` und `credentials.yml.enc`
- **Datenbank-Dump**: `carambus_api_development_dump.sql.gz`
- **Docker-Setup**: Angepasste Compose-Dateien

### Wo diese Dateien hin gehören:
```bash
# Credentials kopieren
cp /path/to/local-dev-folder/config/credentials/* config/credentials/

# Datenbank-Dump kopieren
mkdir -p doc/doc-local/docker/
cp /path/to/local-dev-folder/database/*.sql.gz doc/doc-local/docker/

# Docker-Setup kopieren
cp /path/to/local-dev-folder/docker-compose.development.api-server.yml .
cp /path/to/local-dev-folder/env.development.api-server .
```

## 🏗️ Was ist Carambus? (15 Minuten)

### Architektur verstehen:
```
┌─────────────────┐    ┌─────────────────┐
│   Local Server  │    │   API Server    │
│  (Scoreboards)  │◄──►│  (Zentrale API) │
│                 │    │                 │
└─────────────────┘    └─────────────────┘
```

### Was du entwickelst:
- **API Server**: Zentrale API für alle Carambus-Clients
- **Scraper**: Sammelt Daten von externen Quellen (BA/CC)
- **Datenbank**: Verwaltet Turniere, Spieler, Ligen

## 🔧 Erste Aufgabe: Scraper verstehen (30 Minuten)

### Was ist ein Scraper?
Ein Scraper ist ein Programm, das automatisch Daten von Websites sammelt.

### Wo findest du den Scraper?
```bash
# Scraper-Code finden:
find . -name "*scraper*" -type f
```

### Erste Änderung:
1. **Scraper-Code öffnen** in deinem Editor
2. **Kleine Änderung** machen (z.B. Kommentar hinzufügen)
3. **Testen** ob der Server noch läuft
4. **Erfolgserlebnis** haben! 🎉

## 🆘 Häufige Probleme und Lösungen

### Docker-Probleme:
```bash
# Docker läuft nicht
open -a Docker

# Ports sind belegt
docker-compose down
docker-compose -f docker-compose.development.api-server.yml up
```

### Credentials-Probleme:
```bash
# Falls Rails nach secret_key_base fragt
# Team-Lead gibt dir die development.key und credentials.yml.enc
```

### Datenbank-Probleme:
```bash
# Falls Datenbank nicht startet
docker-compose logs postgres
```

## 📚 Nächste Schritte

### Heute noch:
- [ ] Entwicklungsumgebung läuft
- [ ] Erste Änderung implementiert
- [ ] Verständnis der Architektur

### Diese Woche:
- [ ] Größere Änderung am Scraper
- [ ] Tests schreiben
- [ ] Pull Request erstellen

### Nächste Woche:
- [ ] Docker-Umgebung verstehen
- [ ] Lokale Tests durchführen
- [ ] Code-Reviews geben

## 🆘 Hilfe bekommen

### Bei Problemen:
1. **Sofort fragen** - nicht warten!
2. **Screenshots** von Fehlermeldungen
3. **Terminal-Ausgabe** kopieren

### Kontakte:
- **Team-Chat**: [Slack/Discord Link]
- **Code-Review**: [GitHub Link]
- **Dokumentation**: [Link zu dieser Seite]

## 🎯 Erfolgsmetriken

### Nach 2 Stunden:
- ✅ Server läuft auf Port 3001
- ✅ Browser zeigt Carambus-Seite
- ✅ Erste Änderung implementiert

### Nach 1 Woche:
- ✅ Verständnis der Scraper-Architektur
- ✅ Selbstständige Implementierung
- ✅ Erste Pull Request

### Nach 1 Monat:
- ✅ Vollständige Integration ins Team
- ✅ Code-Reviews geben
- ✅ Neue Features entwickeln

## 🔄 Feedback geben

### Was funktioniert gut?
- [ ] Diese Anleitung
- [ ] Entwicklungsumgebung
- [ ] Team-Support

### Was kann verbessert werden?
- [ ] Dokumentation
- [ ] Setup-Prozess
- [ ] Architektur-Erklärung

---

**🎉 Herzlichen Glückwunsch! Du bist jetzt Teil des Carambus-Entwicklungsteams!**

**💡 Tipp**: Beginne mit kleinen Änderungen und steigere dich langsam. Das Team hilft dir dabei! 