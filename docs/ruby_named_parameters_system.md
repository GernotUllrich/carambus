# Carambus Ruby Named Parameters System

## 🎯 **Übersicht**

Das **Ruby Named Parameters System** bietet eine **vollständig in Ruby/Rake implementierte** Alternative zu Shell-Scripts. Es ist **perfekt für RubyMine Debugging** und eliminiert die Fehleranfälligkeit von positionellen Parametern.

## 🚀 **Schnellstart**

### **Grundlegende Verwendung**
```bash
# API Mode mit named parameters
bundle exec rails 'mode:named:api' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production MODE_HOST=newapi.carambus.de MODE_PORT=3001

# LOCAL Mode mit named parameters
bundle exec rails 'mode:named:local' MODE_SEASON_NAME='2025/2026' MODE_CONTEXT=NBV MODE_API_URL='https://newapi.carambus.de/'
```

## 📋 **Verfügbare Parameter**

### **Alle Parameter (alphabetisch)**
- `MODE_API_URL` - API URL für LOCAL Mode
- `MODE_APPLICATION_NAME` - Anwendungsname
- `MODE_BASENAME` - Deploy Basename
- `MODE_BRANCH` - Git Branch
- `MODE_CLUB_ID` - Club ID
- `MODE_CONTEXT` - Context Identifier
- `MODE_DATABASE` - Datenbankname
- `MODE_DOMAIN` - Domain Name
- `MODE_HOST` - Server Hostname
- `MODE_LOCATION_ID` - Location ID
- `MODE_PORT` - Server Port
- `MODE_PUMA_SCRIPT` - Puma Management Script
- `MODE_RAILS_ENV` - Rails Environment
- `MODE_SEASON_NAME` - Season Identifier

## 🎯 **Verwendungsbeispiele**

### **1. API Server Deployment**
```bash
bundle exec rails 'mode:named:api' \
  MODE_BASENAME=carambus_api \
  MODE_DATABASE=carambus_api_production \
  MODE_HOST=newapi.carambus.de \
  MODE_PORT=3001 \
  MODE_DOMAIN=api.carambus.de \
  MODE_RAILS_ENV=production \
  MODE_BRANCH=master \
  MODE_PUMA_SCRIPT=manage-puma-api.sh
```

### **2. Local Server Deployment**
```bash
bundle exec rails 'mode:named:local' \
  MODE_SEASON_NAME='2025/2026' \
  MODE_APPLICATION_NAME=carambus \
  MODE_CONTEXT=NBV \
  MODE_API_URL='https://newapi.carambus.de/' \
  MODE_BASENAME=carambus \
  MODE_DATABASE=carambus_api_development \
  MODE_DOMAIN=carambus.de \
  MODE_LOCATION_ID=1 \
  MODE_CLUB_ID=357 \
  MODE_HOST=new.carambus.de \
  MODE_RAILS_ENV=production
```

### **3. Entwicklungsumgebung**
```bash
bundle exec rails 'mode:named:api' \
  MODE_BASENAME=carambus_api \
  MODE_DATABASE=carambus_api_development \
  MODE_HOST=localhost \
  MODE_PORT=3001 \
  MODE_RAILS_ENV=development
```

## 💾 **Konfigurationen Verwalten**

### **Konfiguration Speichern**
```bash
bundle exec rails 'mode:named:save[production_api]' \
  MODE_BASENAME=carambus_api \
  MODE_DATABASE=carambus_api_production \
  MODE_HOST=newapi.carambus.de \
  MODE_PORT=3001
```

### **Gespeicherte Konfigurationen Auflisten**
```bash
bundle exec rails 'mode:named:list'
```

### **Konfiguration Laden**
```bash
bundle exec rails 'mode:named:load[production_api]'
```

## 🔧 **RubyMine Debugging**

### **Vollständige Debugging-Unterstützung**

Das Ruby/Rake-System bietet **perfekte RubyMine-Integration**:

#### **1. Breakpoints setzen**
```ruby
# In lib/tasks/mode_named.rake
def parse_named_parameters_from_env
  params = {}
  
  # Setze Breakpoint hier
  %i[season_name application_name context api_url basename database domain location_id club_id rails_env host port branch puma_script].each do |param|
    env_var = "MODE_#{param.to_s.upcase}"
    params[param] = ENV[env_var] if ENV[env_var]
  end
  
  params  # Setze Breakpoint hier
end
```

#### **2. Step-by-Step Debugging**
- **Step Into**: Gehe in Methoden hinein
- **Step Over**: Überspringe Methoden
- **Step Out**: Gehe aus Methoden heraus
- **Variables Inspector**: Sehe alle Parameter-Werte

#### **3. RubyMine Run Configuration**
```
Run -> Edit Configurations -> Rake
Task: mode:named:api
Environment Variables:
  MODE_BASENAME=carambus_api
  MODE_DATABASE=carambus_api_production
  MODE_HOST=newapi.carambus.de
  MODE_PORT=3001
```

## 🆚 **Vergleich: Ruby vs Shell**

### **Ruby/Rake System (Empfohlen)**
```bash
bundle exec rails 'mode:named:api' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production
```

**Vorteile:**
- ✅ **Perfekte RubyMine-Integration**
- ✅ **Vollständiges Debugging**
- ✅ **Step-by-Step Execution**
- ✅ **Variable Inspection**
- ✅ **Breakpoints**
- ✅ **Call Stack**
- ✅ **Error Handling**
- ✅ **Type Safety**

### **Shell Script System (Legacy)**
```bash
./bin/mode-named.sh api --basename=carambus_api --database=carambus_api_production
```

**Nachteile:**
- ❌ **Schwieriges Debugging**
- ❌ **Keine RubyMine-Integration**
- ❌ **Keine Breakpoints**
- ❌ **Keine Variable Inspection**
- ❌ **Schwierige Error-Behandlung**

## 🎯 **Best Practices**

### **1. RubyMine Debugging Workflow**
```bash
# 1. Setze Breakpoints in lib/tasks/mode_named.rake
# 2. Erstelle RubyMine Run Configuration
# 3. Debugge step-by-step
# 4. Inspiziere Variablen
# 5. Teste verschiedene Parameter-Kombinationen
```

### **2. Konfigurationen Speichern**
```bash
# Speichere häufig verwendete Konfigurationen
bundle exec rails 'mode:named:save[production_api]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production MODE_HOST=newapi.carambus.de MODE_PORT=3001
bundle exec rails 'mode:named:save[development_api]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_development MODE_HOST=localhost MODE_PORT=3001
```

### **3. Nur Änderungen Angeben**
```bash
# Nur die Parameter angeben, die sich von den Defaults unterscheiden
bundle exec rails 'mode:named:api' MODE_HOST=localhost MODE_PORT=3001 MODE_RAILS_ENV=development
```

## 🔄 **Migration von Shell Scripts**

### **Schritt 1: Shell Script zu Ruby konvertieren**
```bash
# Alt (Shell)
./bin/mode-named.sh api --basename=carambus_api --host=newapi.carambus.de

# Neu (Ruby)
bundle exec rails 'mode:named:api' MODE_BASENAME=carambus_api MODE_HOST=newapi.carambus.de
```

### **Schritt 2: RubyMine Debugging aktivieren**
1. Öffne `lib/tasks/mode_named.rake` in RubyMine
2. Setze Breakpoints
3. Erstelle Run Configuration
4. Debugge step-by-step

### **Schritt 3: Konfigurationen migrieren**
```bash
# Speichere Shell-Konfigurationen als Ruby-Konfigurationen
bundle exec rails 'mode:named:save[api_hetzner]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production MODE_HOST=newapi.carambus.de MODE_PORT=3001
```

## 🚀 **Deployment Workflow**

### **1. Konfiguration Vorbereiten**
```bash
# Lade gespeicherte Konfiguration
bundle exec rails 'mode:named:load[api_hetzner]'
```

### **2. Konfiguration Anwenden**
```bash
# Wende die geladenen Parameter an
bundle exec rails 'mode:named:api'
```

### **3. Konfiguration Validieren**
```bash
# Überprüfe die aktuelle Konfiguration
bundle exec rails 'mode:status'
```

### **4. Deployment Ausführen**
```bash
# Deploy mit der validierten Konfiguration
bundle exec cap production deploy
```

## 📁 **Dateistruktur**

### **Konfigurationsdateien**
```
config/
├── named_modes/           # Gespeicherte Named-Konfigurationen
│   ├── api_hetzner.yml
│   ├── local_hetzner.yml
│   └── development.yml
├── carambus.yml.erb      # ERB Template
├── database.yml.erb      # ERB Template
├── deploy.rb.erb         # ERB Template
└── deploy/
    └── production.rb.erb # ERB Template
```

### **Rake Tasks**
```
lib/tasks/
├── mode.rake             # Legacy positionelle Parameter
└── mode_named.rake       # Neue Named Parameters (Ruby)
```

## ✅ **Vorteile des Ruby/Rake Systems**

1. **RubyMine Integration**: Perfekte Debugging-Unterstützung
2. **Type Safety**: Ruby-Typisierung und Validierung
3. **Error Handling**: Robuste Fehlerbehandlung
4. **Debugging**: Step-by-Step Debugging mit Breakpoints
5. **Variable Inspection**: Vollständige Variablen-Inspektion
6. **Call Stack**: Call Stack Navigation
7. **IDE Support**: Vollständige IDE-Unterstützung
8. **Maintainability**: Einfache Wartung und Erweiterung

## 🎉 **Fazit**

Das **Ruby Named Parameters System** ist die **ideale Lösung** für RubyMine-Nutzer:

- ✅ **Vollständige Debugging-Unterstützung**
- ✅ **Robuste Parameter-Behandlung**
- ✅ **Einfache Wartung**
- ✅ **IDE-Integration**
- ✅ **Type Safety**

**Empfehlung**: Verwende das Ruby/Rake-System für alle neuen Entwicklungen und migriere bestehende Shell-Script-Konfigurationen schrittweise.

Das Ruby/Rake-System macht die Deployment-Konfiguration **debuggbar, wartbar und robust**! 🚀
