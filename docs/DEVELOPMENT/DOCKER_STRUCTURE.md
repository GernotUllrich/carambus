# 🐳 Carambus Docker-Struktur

## 📋 Übersicht

Die Docker-Struktur wurde neu organisiert, um **Development** und **Production** als übergeordnete Modi zu behandeln, die alle Deployment-Typen durchdringen.

## 🏗️ Neue Struktur

```
Production-Modi (2 verschiedene Systeme):
├── API-Server: Ist der zentrale API-Server (newapi.carambus.de)
└── Local-Server: Hat eine Carambus API URL, die auf den API-Server verweist

Development-Modus (übergeordnet):
├── Beide Production-Modi können im Development-Modus getestet werden
├── Auf dem Mac Mini parallel lauffähig
└── Für Inter-System-Kommunikation (z.B. Region-Filter-Tests)
```

## 🚀 Development-Modus (Mac Mini)

### Einzelne Systeme

#### API-Server (Development)
```bash
# Mit spezifischer Umgebungsdatei
docker-compose -f docker-compose.development.api-server.yml --env-file env.development.api-server up

# Oder mit Standard-Umgebungsdatei
docker-compose -f docker-compose.development.api-server.yml up
```
- **Ports**: Web: 3001, PostgreSQL: 5433, Redis: 6380
- **Datenbank**: `carambus_api_development`
- **Deployment-Typ**: `API_SERVER`
- **Merkmale**: Ist der zentrale API-Server (im Development-Modus)

#### Local-Server (Development)
```bash
# Mit spezifischer Umgebungsdatei
docker-compose -f docker-compose.development.local-server.yml --env-file env.development.local-server up

# Oder mit Standard-Umgebungsdatei
docker-compose -f docker-compose.development.local-server.yml up
```
- **Ports**: Web: 3000, PostgreSQL: 5432, Redis: 6379
- **Datenbank**: `carambus_local_development`
- **Deployment-Typ**: `LOCAL_SERVER`
- **Merkmale**: Hat Carambus API URL, die auf API-Server verweist

#### Web-Client (Development)
```bash
# Mit spezifischer Umgebungsdatei
docker-compose -f docker-compose.development.web-client.yml --env-file env.development.web-client up

# Oder mit Standard-Umgebungsdatei
docker-compose -f docker-compose.development.web-client.yml up
```
- **Ports**: Web: 3002, PostgreSQL: 5434, Redis: 6381
- **Datenbank**: `carambus_web_development`
- **Deployment-Typ**: `WEB_CLIENT`
- **Merkmale**: Scoreboard/Display-Interface

### Parallele Systeme (Development-Modus)

Für die Entwicklung mit mehreren Systemen gleichzeitig auf dem Mac Mini (z.B. für Region-Filter-Tests):

```bash
# Alle drei Systeme parallel starten
docker-compose -f docker-compose.development.parallel.yml --env-file env.development.parallel up

# Oder mit Standard-Umgebungsdatei
docker-compose -f docker-compose.development.parallel.yml up
```

**Vorteile der parallelen Entwicklung:**
- Alle Systeme laufen gleichzeitig auf dem Mac Mini
- Verschiedene Ports für jede Datenbank/Redis-Instanz
- **Inter-System-Kommunikation möglich** (Local-Server ↔ API-Server über Carambus API URL)
- Test von Region-Filtern und Synchronisierung
- **Beide Production-Modi im Development-Modus testbar**

## 🚀 Production-Modus

### Einzelne Systeme

#### API-Server (Production)
```bash
docker-compose -f docker-compose.production.api-server.yml --env-file env.production.api-server up
```
- **Ports**: Web: 3000, PostgreSQL: 5432, Redis: 6379
- **Datenbank**: `carambus_api_production`
- **Deployment-Typ**: `API_SERVER`
- **Merkmale**: Ist der zentrale API-Server (newapi.carambus.de)

#### Local-Server (Production)
```bash
docker-compose -f docker-compose.production.local-server.yml --env-file env.production.local-server up
```
- **Ports**: Web: 3000, PostgreSQL: 5432, Redis: 6379
- **Datenbank**: `carambus_local_production`
- **Deployment-Typ**: `LOCAL_SERVER`
- **Merkmale**: Hat Carambus API URL, die auf API-Server verweist

#### Web-Client (Production)
```bash
docker-compose -f docker-compose.production.web-client.yml --env-file env.production.web-client up
```
- **Ports**: Web: 3000, PostgreSQL: 5432, Redis: 6379
- **Datenbank**: `carambus_web_production`
- **Deployment-Typ**: `WEB_CLIENT`
- **Merkmale**: Scoreboard/Display-Interface

### Generische Production-Konfiguration

```bash
docker-compose -f docker-compose.production.yml --env-file env.production up
```

## 📊 Port-Zuordnung

### Development (parallele Systeme auf Mac Mini)
| System | Web | PostgreSQL | Redis |
|--------|-----|------------|-------|
| API-Server | 3001 | 5433 | 6380 |
| Local-Server | 3000 | 5432 | 6379 |
| Web-Client | 3002 | 5434 | 6381 |

### Production (Standard-Ports)
| System | Web | PostgreSQL | Redis |
|--------|-----|------------|-------|
| Alle Systeme | 3000 | 5432 | 6379 |

## ⚙️ Umgebungsdateien

### Development
- `env.development.api-server` - API-Server im Development-Modus
- `env.development.local-server` - Local-Server im Development-Modus
- `env.development.web-client` - Web-Client im Development-Modus
- `env.development.parallel` - Alle Systeme parallel im Development-Modus

### Production
- `env.production.api-server` - API-Server im Production-Modus
- `env.production.local-server` - Local-Server im Production-Modus
- `env.production.web-client` - Web-Client im Production-Modus
- `env.production` - Generische Production-Konfiguration

## 🔧 Verwendung

### 1. Entwicklung mit einem System (Mac Mini)
```bash
# Local-Server für lokale Entwicklung
docker-compose -f docker-compose.development.local-server.yml up
```

### 2. Entwicklung mit mehreren Systemen (Mac Mini)
```bash
# Alle Systeme parallel für Inter-System-Tests
docker-compose -f docker-compose.development.parallel.yml up
```

### 3. Production-Deployment
```bash
# API-Server in Production
docker-compose -f docker-compose.production.api-server.yml up
```

## 🎯 Architektur-Vorteile

1. **Klare Trennung**: Development vs. Production als übergeordnete Modi
2. **Parallele Entwicklung**: Mehrere Systeme können gleichzeitig auf dem Mac Mini laufen
3. **Inter-System-Kommunikation**: Test von Region-Filtern und Synchronisierung
4. **Port-Konflikte vermieden**: Verschiedene Ports für parallele Systeme
5. **Flexibilität**: Einzelne oder parallele Systeme je nach Bedarf
6. **Konsistenz**: Einheitliche Struktur für alle Deployment-Typen
7. **Korrekte Architektur**: 2 Production-Modi - API-Server (zentral) und Local-Server (mit Carambus API URL)

## 🔄 Migration von der alten Struktur

Die alten Dateien bleiben kompatibel:
- `docker-compose.development.yml` → `docker-compose.development.local-server.yml`
- `env.development` → `env.development.local-server`

Für neue Projekte wird die neue Struktur empfohlen.

## 🚀 Schnellstart-Skript

Für parallele Development-Systeme auf dem Mac Mini:

```bash
# Alle drei Systeme parallel starten
./start-development-parallel.sh

# Ports:
# - API-Server: 3001 (PostgreSQL: 5433, Redis: 6380)
# - Local-Server: 3000 (PostgreSQL: 5432, Redis: 6379)
# - Web-Client: 3002 (PostgreSQL: 5434, Redis: 6381)
```

## 🔧 Carambus API URL konfigurieren

### Für Local-Server (Development und Production)
```bash
# In der .env Datei
CARAMBUS_API_URL=https://newapi.carambus.de

# Oder in der Rails-Konfiguration
config.carambus_api_url = 'https://newapi.carambus.de'
```

### Inter-System-Kommunikation
- **Local-Server** hat Carambus API URL, die auf **API-Server** verweist
- **Synchronisierung** zwischen Local-Server und API-Server
- **Region-Filter** können zwischen Systemen getestet werden

---

**🎯 Ziel**: Saubere, redundanzfreie Docker-Struktur mit korrekter Architektur

**🏗️ Architektur**: 2 Production-Modi - API-Server (zentral) und Local-Server (mit Carambus API URL), beide im Development-Modus testbar! 