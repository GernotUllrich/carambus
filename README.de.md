# Carambus - Billard-Turnierverwaltungssystem

[![Ruby](https://img.shields.io/badge/Ruby-3.2+-red.svg)](https://ruby-lang.org)
[![Rails](https://img.shields.io/badge/Rails-7.2-blue.svg)](https://rubyonrails.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-11+-blue.svg)](https://postgresql.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Carambus ist ein umfassendes Billard-Turnierverwaltungssystem, das eine vollständige Automatisierung der Billard-Betriebsabläufe von der Turnierplanung bis zur Datenerfassung und Ergebnisübertragung bietet. Entwickelt mit Ruby on Rails und modernen Webtechnologien bietet es Echtzeit-Scoreboards, Ligaverwaltung und nahtlose Integration mit externen Billard-Datenbanken.

## 🎯 Funktionen

### Turnierverwaltung
- **Vollständiger Turnierlebenszyklus**: Von der Erstellung bis zu den Endergebnissen
- **Mehrere Spieltypen**: Unterstützung für 3-Banden, 1-Bande und andere Disziplinen
- **Flexible Formate**: K.-o.-System, Rundenturnier und benutzerdefinierte Formate
- **Echtzeit-Überwachung**: Live-Spielverfolgung und Scoreboard-Anzeigen

### Ligaverwaltung
- **Team-basierte Organisation**: Verwaltung von Ligateams und Spielerkadern
- **Saisonverwaltung**: Organisation von Turnieren in Saisons
- **Spielplanung**: Automatische und manuelle Spielplanung
- **Ergebnisverfolgung**: Umfassende Statistiken und Ranglisten

### Echtzeit-Funktionen
- **Live-Scoreboards**: WebSocket-gestützte Echtzeit-Anzeigen
- **Tisch-Monitore**: Einzelne Tischüberwachung und -steuerung
- **Sofortige Updates**: Echtzeit-Datensynchronisation über Geräte hinweg
- **Responsive Design**: Funktioniert auf Desktop, Tablet und Mobilgeräten

### Datenintegration
- **Externe Datenbanksynchronisation**: Integration mit BA (Billard-Verband) und CC (Competition Center)
- **Datenschutz**: Lokaler Datenschutz mit externer Synchronisation
- **Regionsverwaltung**: Intelligente regionsbasierte Datenorganisation
- **Mehrsprachige Unterstützung**: Deutsche und englische Benutzeroberflächen

## 🚀 Schnellstart

### Voraussetzungen
- Ruby 3.2 oder höher
- PostgreSQL 11 oder höher
- Redis 5 oder höher
- Node.js 14 oder höher

### Installation

1. **Repository klonen**
   ```bash
   git clone https://github.com/your-username/carambus.git
   cd carambus
   ```

2. **Abhängigkeiten installieren**
   ```bash
   bundle install
   yarn install
   ```

3. **Datenbank einrichten**
   ```bash
   cp config/database.yml.example config/database.yml
   # database.yml mit Ihren PostgreSQL-Zugangsdaten bearbeiten
   
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. **Umgebungskonfiguration**
   ```bash
   cp config/application.yml.example config/application.yml
   # application.yml mit Ihrer Konfiguration bearbeiten
   ```

5. **Anwendung starten**
   ```bash
   rails server
   ```

6. **Anwendung aufrufen**
   Öffnen Sie Ihren Browser und navigieren Sie zu `http://localhost:3000`

## 📚 Dokumentation

- **[Entwicklerleitfaden](docs/DEVELOPER_GUIDE.de.md)**: Umfassender Leitfaden für Entwickler
- **[Datenbankdesign](docs/database_design.md)**: Detailliertes Datenbankschema und Beziehungen
- **[Scoreboard-Einrichtung](docs/scoreboard_autostart_setup.md)**: Scoreboard-Konfigurationsanleitung
- **[Turnierverwaltung](docs/tournament.md)**: Turnier-Workflow-Dokumentation
- **[Deployment-Anleitung](doc/doc/Runbook)**: Produktions-Deployment-Anweisungen

## 🏗️ Architektur

### Technologie-Stack
- **Backend**: Ruby on Rails 7.2
- **Datenbank**: PostgreSQL mit erweitertem Datenmodell
- **Frontend**: Hotwire (Turbo + Stimulus) + Stimulus Reflex
- **Echtzeit**: Action Cable mit Redis
- **Authentifizierung**: Devise mit rollenbasierter Autorisierung
- **Admin-Interface**: Administrate für einfache Verwaltung
- **Deployment**: Capistrano + Puma + Nginx

### Hauptkomponenten
- **Models**: Umfangreiche ActiveRecord-Models mit Concerns für geteilte Funktionalität
- **Controller**: RESTful Controller mit JSON-API-Unterstützung
- **Views**: ERB-Templates mit responsivem Design
- **Channels**: Action Cable Channels für Echtzeit-Funktionen
- **Jobs**: Hintergrund-Job-Verarbeitung
- **Services**: Geschäftslogik-Kapselung

## 🎮 Verwendungsbeispiele

### Turnier erstellen
```ruby
# Neues Turnier erstellen
tournament = Tournament.create!(
  name: "Regionalmeisterschaft 2024",
  discipline: Discipline.find_by(name: "3-Banden"),
  start_date: Date.today + 1.week,
  location: Location.find_by(name: "Billard Club Wedel")
)

# Teilnehmer hinzufügen
players.each do |player|
  tournament.seedings.create!(player: player)
end

# Spielplan generieren
tournament.generate_game_plan
```

### Echtzeit-Scoreboard
```javascript
// Mit Scoreboard-Channel verbinden
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()
const subscription = consumer.subscriptions.create("TableMonitorChannel", {
  received(data) {
    // Scoreboard-Anzeige aktualisieren
    updateScoreboard(data)
  }
})
```

## 🤝 Mitwirken

Wir freuen uns über Beiträge aus der Community! Bitte lesen Sie unseren [Beitragsleitfaden](docs/DEVELOPER_GUIDE.de.md#mitwirken) für Details.

### Entwicklungs-Setup
1. Repository forken
2. Feature-Branch erstellen
3. Änderungen vornehmen
4. Tests für neue Funktionalität hinzufügen
5. Sicherstellen, dass alle Tests bestehen
6. Pull Request einreichen

### Code-Qualität
- Ruby-Stilrichtlinien befolgen (Standard Ruby)
- Umfassende Tests schreiben
- Dokumentation für neue Features aktualisieren
- Aussagekräftige Commit-Nachrichten verwenden

## 📋 Anforderungen

### Systemanforderungen
- **Entwicklung**: Jedes moderne Betriebssystem mit Ruby 3.2+
- **Produktion**: Raspberry Pi 4 (4GB RAM) oder Äquivalent
- **Datenbank**: PostgreSQL 11+ mit ordnungsgemäßer Indizierung
- **Cache**: Redis 5+ für Session-Speicherung und Action Cable

### Browser-Unterstützung
- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## 🚀 Deployment

### Produktions-Deployment
Carambus ist für den Einsatz auf Raspberry Pi oder ähnlicher Hardware konzipiert:

```bash
# Server-Setup (siehe Runbook für Details)
# Anwendungs-Deployment über Capistrano
cap production deploy

# Service-Management
sudo systemctl start carambus
sudo systemctl enable carambus
```

### Docker-Unterstützung
```bash
# Mit Docker bauen und ausführen
docker-compose up -d

# Oder benutzerdefiniertes Image bauen
docker build -t carambus .
docker run -p 3000:3000 carambus
```

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz - siehe die [LICENSE](LICENSE)-Datei für Details.

## 🙏 Danksagungen

- **Dr. Gernot Ullrich**: Ursprünglicher Entwickler und Projektgründer
- **Billardclub Wedel 61 e.V.**: Der Billardclub, der dieses Projekt inspiriert hat
- **Ruby on Rails Community**: Für das ausgezeichnete Framework und Ökosystem
- **Hotwire Team**: Für die modernen Echtzeit-Webtechnologien

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/your-username/carambus/issues)
- **Diskussionen**: [GitHub Discussions](https://github.com/your-username/carambus/discussions)
- **Dokumentation**: [Projekt Wiki](https://github.com/your-username/carambus/wiki)

## 🔗 Links

- **Website**: [carambus.de](https://carambus.de)
- **Dokumentation**: [docs/](docs/)
- **API-Dokumentation**: [docs/api.md](docs/api.md)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)

---

**Carambus** - *Kompromisslose Automatisierung der Billard-Betriebsabläufe*

*Entwickelt mit ❤️ für die Billard-Community* 