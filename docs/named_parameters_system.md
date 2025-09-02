# Carambus Named Parameters System

## 🎯 **Übersicht**

Das Named Parameters System bietet eine **robuste Alternative** zu den positionellen Parametern. Es eliminiert die Fehleranfälligkeit durch falsche Parameter-Reihenfolge und macht die Konfiguration **selbstdokumentierend**.

## 🚀 **Schnellstart**

### **Installation**
```bash
# Script ist bereits ausführbar
chmod +x bin/mode-named.sh
```

### **Grundlegende Verwendung**
```bash
# API Mode mit named parameters
./bin/mode-named.sh api --basename=carambus_api --database=carambus_api_production --host=newapi.carambus.de --port=3001

# LOCAL Mode mit named parameters
./bin/mode-named.sh local --season-name='2025/2026' --context=NBV --api-url='https://newapi.carambus.de/'
```

## 📋 **Verfügbare Parameter**

### **Alle Parameter (alphabetisch)**
- `--api-url=VALUE` - API URL für LOCAL Mode
- `--application-name=VALUE` - Anwendungsname
- `--basename=VALUE` - Deploy Basename
- `--branch=VALUE` - Git Branch
- `--club-id=VALUE` - Club ID
- `--context=VALUE` - Context Identifier
- `--database=VALUE` - Datenbankname
- `--domain=VALUE` - Domain Name
- `--host=VALUE` - Server Hostname
- `--location-id=VALUE` - Location ID
- `--port=VALUE` - Server Port
- `--puma-script=VALUE` - Puma Management Script
- `--rails-env=VALUE` - Rails Environment
- `--season-name=VALUE` - Season Identifier

## 🎯 **Verwendungsbeispiele**

### **1. API Server Deployment**
```bash
./bin/mode-named.sh api \
  --basename=carambus_api \
  --database=carambus_api_production \
  --host=newapi.carambus.de \
  --port=3001 \
  --domain=api.carambus.de \
  --rails-env=production \
  --branch=master \
  --puma-script=manage-puma-api.sh
```

### **2. Local Server Deployment**
```bash
./bin/mode-named.sh local \
  --season-name='2025/2026' \
  --application-name=carambus \
  --context=NBV \
  --api-url='https://newapi.carambus.de/' \
  --basename=carambus \
  --database=carambus_api_development \
  --domain=carambus.de \
  --location-id=1 \
  --club-id=357 \
  --host=new.carambus.de \
  --rails-env=production \
  --branch=master \
  --puma-script=manage-puma.sh
```

### **3. Entwicklungsumgebung**
```bash
./bin/mode-named.sh api \
  --basename=carambus_api \
  --database=carambus_api_development \
  --host=localhost \
  --port=3001 \
  --rails-env=development
```

## 💾 **Konfigurationen Speichern und Laden**

### **Konfiguration Speichern**
```bash
# Speichere API Hetzner Konfiguration
./bin/mode-named.sh save api_hetzner \
  --basename=carambus_api \
  --database=carambus_api_production \
  --host=newapi.carambus.de \
  --port=3001 \
  --domain=api.carambus.de \
  --rails-env=production \
  --branch=master \
  --puma-script=manage-puma-api.sh

# Speichere Local Hetzner Konfiguration
./bin/mode-named.sh save local_hetzner \
  --season-name='2025/2026' \
  --context=NBV \
  --api-url='https://newapi.carambus.de/' \
  --basename=carambus \
  --database=carambus_api_development \
  --domain=carambus.de \
  --host=new.carambus.de \
  --rails-env=production
```

### **Gespeicherte Konfigurationen Anzeigen**
```bash
./bin/mode-named.sh list
```

**Ausgabe:**
```
📋 Saved configurations:
  api_hetzner: basename=carambus_api,database=carambus_api_production,host=newapi.carambus.de,port=3001,domain=api.carambus.de,rails-env=production,branch=master,puma-script=manage-puma-api.sh
  local_hetzner: season-name=2025/2026,context=NBV,api-url=https://newapi.carambus.de/,basename=carambus,database=carambus_api_development,domain=carambus.de,host=new.carambus.de,rails-env=production,branch=master,puma-script=manage-puma.sh
```

### **Konfiguration Laden**
```bash
# Lade gespeicherte Konfiguration
./bin/mode-named.sh load api_hetzner
```

## 🔧 **Technische Details**

### **Parameter-Parsing**
Das System unterstützt mehrere Formate:

#### **1. Key=Value Format**
```bash
--basename=carambus_api --database=carambus_api_production
```

#### **2. JSON Format (über Umgebungsvariable)**
```bash
export MODE_PARAMS='{"basename":"carambus_api","database":"carambus_api_production"}'
./bin/mode-named.sh api
```

#### **3. Environment Variables**
```bash
export MODE_BASENAME=carambus_api
export MODE_DATABASE=carambus_api_production
./bin/mode-named.sh api
```

### **Rake Task Integration**
Das System verwendet neue Rake Tasks:
- `mode:local_named` - LOCAL Mode mit named parameters
- `mode:api_named` - API Mode mit named parameters

### **Konfigurationsdateien**
Gespeicherte Konfigurationen werden in `~/.carambus_named_mode_params.*` Dateien gespeichert.

## 🆚 **Vergleich: Named vs Positionelle Parameter**

### **Positionelle Parameter (Alt)**
```bash
# Fehleranfällig - Reihenfolge muss exakt stimmen
bundle exec rails "mode:api[2025/2026,carambus_api,,,carambus_api,carambus_api_production,api.carambus.de,,,production,newapi.carambus.de,3001,master,manage-puma-api.sh]"
```

**Probleme:**
- ❌ Reihenfolge muss exakt stimmen
- ❌ Schwer zu lesen und verstehen
- ❌ Fehleranfällig bei Änderungen
- ❌ Keine Selbstdokumentation

### **Named Parameters (Neu)**
```bash
# Robuster - Parameter sind selbstdokumentierend
./bin/mode-named.sh api \
  --basename=carambus_api \
  --database=carambus_api_production \
  --host=newapi.carambus.de \
  --port=3001
```

**Vorteile:**
- ✅ Parameter sind selbstdokumentierend
- ✅ Reihenfolge ist irrelevant
- ✅ Nur benötigte Parameter angeben
- ✅ Einfach zu lesen und verstehen
- ✅ Robuster gegen Fehler

## 🎯 **Best Practices**

### **1. Konfigurationen Speichern**
```bash
# Speichere häufig verwendete Konfigurationen
./bin/mode-named.sh save production_api --basename=carambus_api --database=carambus_api_production --host=newapi.carambus.de --port=3001
./bin/mode-named.sh save development_api --basename=carambus_api --database=carambus_api_development --host=localhost --port=3001
```

### **2. Nur Änderungen Angeben**
```bash
# Nur die Parameter angeben, die sich von den Defaults unterscheiden
./bin/mode-named.sh api --host=localhost --port=3001 --rails-env=development
```

### **3. Konfigurationen Dokumentieren**
```bash
# Kommentiere deine Konfigurationen
./bin/mode-named.sh save production_api \
  --basename=carambus_api \
  --database=carambus_api_production \
  --host=newapi.carambus.de \
  --port=3001 \
  --comment="Production API server on Hetzner"
```

## 🔄 **Migration von Positionellen Parametern**

### **Schritt 1: Bestehende Konfiguration Analysieren**
```bash
# Verwende das alte System um die aktuellen Parameter zu sehen
./bin/mode-params.sh status detailed
```

### **Schritt 2: Named Parameters Erstellen**
```bash
# Konvertiere zu named parameters basierend auf der Ausgabe
./bin/mode-named.sh save my_config \
  --basename=carambus_api \
  --database=carambus_api_production \
  --host=newapi.carambus.de \
  --port=3001
```

### **Schritt 3: Neue Konfiguration Testen**
```bash
# Teste die neue Konfiguration
./bin/mode-named.sh load my_config
./bin/mode-named.sh status
```

## 🚀 **Deployment Workflow**

### **1. Konfiguration Vorbereiten**
```bash
# Lade gespeicherte Konfiguration
./bin/mode-named.sh load api_hetzner
```

### **2. Konfiguration Validieren**
```bash
# Überprüfe die aktuelle Konfiguration
./bin/mode-named.sh status detailed
```

### **3. Deployment Ausführen**
```bash
# Deploy mit der validierten Konfiguration
bundle exec cap production deploy
```

## ✅ **Vorteile des Named Parameters Systems**

1. **Robustheit**: Keine Fehler durch falsche Parameter-Reihenfolge
2. **Lesbarkeit**: Parameter sind selbstdokumentierend
3. **Flexibilität**: Nur benötigte Parameter angeben
4. **Wartbarkeit**: Einfach zu verstehen und zu ändern
5. **Dokumentation**: Parameter-Namen dienen als Dokumentation
6. **Speicherung**: Konfigurationen können gespeichert und wiederverwendet werden

Das Named Parameters System macht die Deployment-Konfiguration **viel robuster und benutzerfreundlicher**! 🎉
