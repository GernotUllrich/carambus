# Scenario Management System

Das Scenario Management System ermöglicht es, verschiedene Deployment-Umgebungen (Scenarios) für Carambus zu verwalten und automatisch zu deployen.

## Überblick

Das System unterstützt verschiedene Szenarien wie:
- **carambus**: Hauptproduktionsumgebung
- **carambus_location_5101**: Lokale Server-Instanz für Standort 5101
- **carambus_location_2459**: Lokale Server-Instanz für Standort 2459
- **carambus_location_2460**: Lokale Server-Instanz für Standort 2460

## Grundkonzepte

### Scenario-Konfiguration

Jedes Scenario wird durch eine `config.yml` Datei definiert:

```yaml
scenario:
  name: carambus
  application_name: carambus
  basename: carambus

environments:
  development:
    database_name: carambus_development
    database_username: carambus_user
    webserver_host: localhost
    webserver_port: 3000
    ssh_host: localhost
    ssh_port: 22
    ssl_enabled: false
    
  production:
    database_name: carambus_production
    database_username: carambus_user
    webserver_host: new.carambus.de
    webserver_port: 80
    ssh_host: new.carambus.de
    ssh_port: 8910
    ssl_enabled: true
```

### Automatische Sequence-Verwaltung

Das System stellt sicher, dass alle Datenbank-Sequences korrekt auf > 50.000.000 gesetzt werden, um Konflikte mit dem `LocalProtector` zu vermeiden.

## Verfügbare Tasks

### Scenario-Erstellung

```bash
# Neues Scenario erstellen
rake "scenario:create[scenario_name]"

# Rails-Root für Scenario erstellen
rake "scenario:create_rails_root[scenario_name]"
```

### Development-Setup

```bash
# Development-Umgebung einrichten
rake "scenario:setup[scenario_name,development]"

# Mit Rails-Root-Verzeichnis
rake "scenario:setup_with_rails_root[scenario_name,development]"
```

### Production-Deployment

```bash
# Vollständiges Production-Deployment
rake "scenario:deploy[scenario_name]"

# Mit Konfliktanalyse
rake "scenario:deploy_with_conflict_analysis[scenario_name]"
```

### Datenbank-Management

```bash
# Datenbank-Dump erstellen
rake "scenario:create_database_dump[scenario_name,environment]"

# Datenbank wiederherstellen
rake "scenario:restore_database_dump[scenario_name,environment]"
```

## Deployment-Prozess

### 1. Konfigurationsdateien generieren

Das System generiert automatisch:
- `database.yml`
- `carambus.yml`
- `nginx.conf`
- `puma.service`
- `puma.rb`
- `deploy.rb`
- `production.rb`

### 2. Datenbank-Setup

- **Template-Optimierung**: Verwendet `createdb --template` für schnelle Datenbank-Erstellung
- **Automatische Transformationen**: Setzt Scenario-spezifische Einstellungen
- **Sequence-Reset**: Stellt sicher, dass alle Sequences > 50.000.000 sind

### 3. Capistrano-Deployment

- **Git-Deployment**: Automatisches Code-Deployment
- **Asset-Precompilation**: CSS/JS-Build
- **Database-Migration**: Automatische Schema-Updates
- **Service-Management**: Puma/Nginx-Konfiguration
- **SSL-Setup**: Automatische Let's Encrypt-Integration

## Optimierungen

### Database Template

**Vorher:**
```bash
pg_dump carambus_api_development | psql temp_db
```

**Nachher:**
```bash
createdb temp_db --template=carambus_api_development
```

**Vorteil:** Deutlich schneller bei großen Datenbanken.

### Integrierte SSL-Verwaltung

SSL-Zertifikate werden automatisch über Capistrano verwaltet:
- Automatische Let's Encrypt-Integration
- Nginx-Konfiguration mit SSL
- Automatische Zertifikatserneuerung

### Automatische Sequence-Verwaltung

Das System führt automatisch `Version.sequence_reset` aus:
- Nach jedem Database-Restore
- Bei jedem Production-Deployment
- Verhindert `LocalProtector`-Konflikte

## Troubleshooting

### Häufige Probleme

#### 1. Sequence-Konflikte

**Problem:** `ActiveRecord::RecordNotDestroyed` Fehler
**Lösung:** `Version.sequence_reset` ausführen

```bash
bundle exec rails runner 'Version.sequence_reset'
```

#### 2. Bundle-Command nicht gefunden

**Problem:** `bundle: command not found` auf Server
**Lösung:** System verwendet automatisch `$HOME/.rbenv/bin/rbenv exec bundle`

#### 3. SSL-Zertifikat-Probleme

**Problem:** SSL-Setup schlägt fehl
**Lösung:** Prüfen Sie die Domain-Konfiguration und Nginx-Status

```bash
sudo certbot certificates
sudo nginx -t
```

## Best Practices

### Scenario-Namenskonvention

- **Hauptproduktion**: `carambus`
- **Lokale Server**: `carambus_location_[ID]`
- **Entwicklung**: `carambus_development`

### Datenbank-Backup

Erstellen Sie regelmäßig Backups:
```bash
rake "scenario:create_database_dump[carambus,production]"
```

### Deployment-Test

Testen Sie Deployments in Development-Umgebung:
```bash
rake "scenario:setup[carambus,development]"
```

## Integration mit bestehenden Systemen

Das Scenario Management System ersetzt:
- ❌ Manuelle Docker-Konfiguration
- ❌ Manuelle Mode-Switching
- ❌ Manuelle SSL-Setup
- ❌ Manuelle Database-Management

**Vorteile:**
- ✅ Automatisierte Deployments
- ✅ Konsistente Konfiguration
- ✅ Einfache Wartung
- ✅ Skalierbare Architektur
