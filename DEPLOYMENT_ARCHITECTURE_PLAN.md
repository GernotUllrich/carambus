# Carambus Deployment Architecture Plan

## 📋 Aktueller Status: PHAT Consulting Location Setup
- **Projekt**: carambus_location_2459 (PHAT Consulting)
- **Status**: Erfolgreich implementiert ✅
- **Datenbanken**: carambus_location_2459_development, carambus_location_2459_test ✅
- **Migrationen**: Alle 129 Migrationen erfolgreich ✅
- **Konfiguration**: Lokale Entwicklung ohne username/password ✅

## 🎯 Vereinfachung des Test- und Deploy-Betriebs

### Problemstellung
- Aktueller Ansatz ist zu komplex für relativ wenige Varianten
- Konfusion durch mode-switch bei gleichen Namen mit verschiedenen Inhalten
- Fehlende Übersichtlichkeit bei verschiedenen Szenarien

### Lösungsansatz: Getrennte Rails Root Folders

#### 1. Grundprinzip
- **Zielumgebungen**: Kompletter Rails root folder pro Szenario
- **Entwicklungsumgebung**: Direkte Konfiguration (keine Links aus /shared/)
- **Langzeitgedächtnis**: Separates Repo `/carambus_data` für Konfigurationen

#### 2. Szenario-Management
```
carambus_data/
├── scenarios/
│   ├── carambus_api/
│   │   ├── development/
│   │   └── production/
│   ├── carambus_location_2459/
│   │   ├── development/
│   │   └── production/
│   └── carambus_location_XXXX/
│       ├── development/
│       └── production/
└── templates/
    ├── database.yml.erb
    ├── carambus.yml.erb
    ├── credentials/
    └── environments/
```

#### 3. Konfigurationsdateien pro Szenario
```
{Rails.root}/config/
├── carambus.yml
├── database.yml
├── credentials/
│   ├── production.key
│   └── production.yml.enc
├── environments/
│   └── production.rb
└── nginx.conf

{Rails.root}/database_dumps/
└── {scenario_name}_{environment}_{timestamp}.sql.gz
```

### 4. Template-basierte Generierung

#### MODE-Parameter in carambus_data
```yaml
# carambus_data/scenarios/carambus_location_2459/config.yml
scenario:
  name: carambus_location_2459
  description: PHAT Consulting Location
  location_id: 2459
  context: NBV
  region_id: 1
  club_id: 2459

environments:
  development:
    database_name: carambus_location_2459_development
    server_port: 3000
    mode: development
    
  production:
    database_name: carambus_location_2459_production
    server_port: 80
    mode: production
    ssl_enabled: true
```

#### Template-Beispiele
```erb
# templates/database.yml.erb
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: <%= @config['database_name'] %>
  host: localhost
  # Keine username/password für lokale Entwicklung

test:
  <<: *default
  database: <%= @config['database_name'].gsub('_development', '_test') %>
  host: localhost

production:
  <<: *default
  database: <%= @config['database_name'] %>
  username: <%= @config['database_username'] %>
  password: <%= @config['database_password'] %>
  host: <%= @config['database_host'] %>
```

### 5. Workflow für neue Szenarien

#### Schritt 1: Szenario definieren
```bash
# Neues Szenario erstellen
rake scenario:create[carambus_location_2460,2460,NBV]
```

#### Schritt 2: Konfiguration generieren
```bash
# Rails root folder generieren
rake scenario:generate[carambus_location_2460]
```

#### Schritt 3: Datenbank aufsetzen
```bash
# Datenbank erstellen und migrieren
cd carambus_location_2460
rails db:create db:migrate
```

#### Schritt 4: Daten laden
```bash
# NBV-Daten für Location 2460 extrahieren
rake data:extract[carambus_location_2460,2460]
```

### 6. Deployment-Prozess

#### Entwicklungsumgebung
- Direkte Konfiguration in Rails root folder
- Keine Links aus /shared/
- Lokale Entwicklung ohne Authentifizierung

#### Produktionsumgebung
- Kompletter Rails root folder pro Szenario
- Alle Konfigurationsdateien direkt im Projekt
- Keine Abhängigkeit von /shared/

### 7. Synchronisierung zwischen Szenarien

#### Daten-Synchronisierung
```bash
# NBV-Daten zwischen API und Location synchronisieren
rake sync:nbv[carambus_api_production,carambus_location_2459_production]
```

#### Konfigurations-Synchronisierung
```bash
# Templates zwischen Szenarien synchronisieren
rake sync:config[carambus_api,carambus_location_2459]
```

### 8. Vorteile des neuen Ansatzes

#### Übersichtlichkeit
- ✅ Eindeutige Beziehung zwischen Szenario und Rails root folder
- ✅ Keine Konfusion durch mode-switch
- ✅ Klare Trennung zwischen Entwicklung und Produktion

#### Wartbarkeit
- ✅ Template-basierte Generierung
- ✅ Versionierte Konfigurationen in carambus_data
- ✅ Einfache Skripte für häufige Operationen

#### Skalierbarkeit
- ✅ Einfaches Hinzufügen neuer Szenarien
- ✅ Konsistente Struktur über alle Szenarien
- ✅ Wiederverwendbare Templates

### 9. Migration von bestehenden Szenarien

#### Schritt 1: Bestehende Konfigurationen exportieren
```bash
# Aktuelle Konfigurationen in carambus_data speichern
rake migrate:export_configs
```

#### Schritt 2: Neue Struktur generieren
```bash
# Rails root folders für alle Szenarien erstellen
rake migrate:generate_roots
```

#### Schritt 3: Datenbanken migrieren
```bash
# Bestehende Datenbanken in neue Struktur überführen
rake migrate:databases
```

### 10. Nächste Schritte

1. **carambus_data Repo erstellen**
   - Struktur für Szenarien und Templates
   - MODE-Parameter in YAML-Format

2. **Template-System implementieren**
   - ERB-Templates für alle Konfigurationsdateien
   - Generator-Skripte für neue Szenarien

3. **Migration bestehender Szenarien**
   - Export aktueller Konfigurationen
   - Generierung neuer Rails root folders

4. **PHAT Consulting Location migrieren**
   - carambus_location_2459 in neue Struktur überführen
   - NBV-Daten-Subset erstellen

5. **Deployment-Pipeline anpassen**
   - Capistrano für neue Struktur konfigurieren
   - Nginx-Konfiguration pro Szenario

## 🚀 Ziel: Vereinfachter, wartbarer Deploy-Betrieb

Mit diesem Ansatz wird der Deploy-Betrieb deutlich vereinfacht:
- **Eindeutige Zuordnung** zwischen Szenario und Rails root folder
- **Template-basierte Generierung** für Konsistenz
- **Versionierte Konfigurationen** in carambus_data
- **Einfache Skripte** für häufige Operationen
- **Klare Trennung** zwischen Entwicklung und Produktion

## 📝 Code-Entwicklung und Git-Workflow

### Repository-Struktur
```
carambus/                    # Haupt-Repository (Code-Entwicklung)
├── app/                     # Rails-Anwendung
├── config/                  # Basis-Konfiguration
├── lib/                     # Shared Libraries
└── ...

carambus_data/              # Konfigurations-Repository
├── scenarios/              # Szenario-Konfigurationen
├── templates/              # ERB-Templates
└── ...

carambus_location_2459/     # Generierter Rails Root Folder
├── config/                 # Szenario-spezifische Konfiguration
├── database_dumps/         # Szenario-spezifische Daten
└── ...
```

### Entwicklungs-Workflow

#### 1. Hauptentwicklung in `carambus`
- **Code-Änderungen**: Immer im Haupt-Repository `carambus`
- **Commits**: Alle Feature-Entwicklung in `carambus`
- **Branches**: Feature-Branches in `carambus` für neue Entwicklungen

#### 2. Szenario-spezifische Entwicklung
```bash
# Feature-Branch für Location-spezifische Änderungen
git checkout -b feature/location-2459-specific
# Entwicklung und Tests
git commit -m "Add location-specific feature for PHAT Consulting"
git push origin feature/location-2459-specific
# Merge in main/master
git checkout main
git merge feature/location-2459-specific
```

#### 3. Konfigurations-Management
- **carambus_data**: Nur Konfigurationen und Templates
- **Keine Code-Änderungen** in carambus_data
- **Versionierung** der Konfigurationen über Git-Tags

### Szenario-Namenskonvention

#### Aktuelle Situation
- `carambus_api` → Historisch gewachsen, nicht optimal
- `carambus_location_2459` → Klar und eindeutig

#### Vorgeschlagene Umbenennung
```bash
# Umbenennung des Haupt-Szenarios
carambus_api → carambus_main
# oder einfach
carambus_api → carambus
```

#### Neue Struktur
```
carambus_data/scenarios/
├── carambus/              # Haupt-Szenario (ehemals carambus_api)
│   ├── development/
│   └── production/
├── carambus_location_2459/ # PHAT Consulting
│   ├── development/
│   └── production/
└── carambus_location_XXXX/ # Weitere Locations
    ├── development/
    └── production/
```

### Deployment-Workflow

#### 1. Code-Deployment
```bash
# Code wird immer aus carambus deployed
cd carambus
git pull origin main
bundle install
rails assets:precompile
```

#### 2. Konfigurations-Deployment
```bash
# Konfiguration wird aus carambus_data generiert
cd carambus_data
rake scenario:deploy[carambus_location_2459,production]
```

#### 3. Datenbank-Deployment
```bash
# Datenbank-Setup pro Szenario
rake db:setup[carambus_location_2459,production]
```

### Vorteile der neuen Struktur

#### Klarheit
- ✅ `carambus` = Code-Entwicklung
- ✅ `carambus_data` = Konfigurationen
- ✅ `carambus_location_XXXX` = Generierte Rails Root Folders

#### Workflow
- ✅ Einheitliche Code-Entwicklung in `carambus`
- ✅ Szenario-spezifische Branches für Features
- ✅ Klare Trennung zwischen Code und Konfiguration

#### Skalierbarkeit
- ✅ Einfaches Hinzufügen neuer Szenarien
- ✅ Konsistente Namenskonvention
- ✅ Wiederverwendbare Templates
