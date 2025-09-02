# Carambus Docker Development Environment

## 🚀 **Schnellstart**

### **WICHTIG: Zuerst Mode setzen!**

```bash
# Für API Server (Port 3001, 5433, 6380)
rake mode:api

# Für Local Server (Port 3000, 5432, 6379)  
rake mode:local

# Für beide parallel (Ports werden automatisch angepasst)
rake mode:parallel
```

### **1. Entwicklungsumgebung starten:**

#### **API Server Mode:**

```bash
cd docker/development
docker-compose -f docker-compose.mode.api.yml up --build
```

#### **Local Server Mode:**

```bash
cd docker/development
docker-compose -f docker-compose.mode.local.yml up --build
```

#### **Beide parallel (falls verfügbar):**

```bash
cd docker/development
docker-compose -f docker-compose.development.parallel.yml up --build
```

## 🔧 **Mode-System erklärt**

### **Was macht `rake mode:*`?**

- **Konfigurationsdateien** generiert
- **Ports** werden angepasst
- **Umgebungsvariablen** gesetzt
- **Datenbank-URLs** konfiguriert

### **Port-Zuordnung:**

#### **API Server Mode:**

- **Rails App**: <http://localhost:3001>
- **PostgreSQL**: localhost:5433
- **Redis**: localhost:6380

#### **Local Server Mode:**

- **Rails App**: <http://localhost:3000>
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

## 📁 **Verzeichnisstruktur**

```
docker/development/
├── docker-compose.mode.api.yml        # API Server Mode
├── docker-compose.mode.local.yml      # Local Server Mode
├── docker-compose.development.parallel.yml  # Beide parallel
├── README.md                          # Diese Datei
└── database/                          # Optional: Database dumps
    └── carambus_api_development.sql.gz
```

## 🎯 **Asset-Build-Prozess**

Der Container führt automatisch aus:

1. **yarn build:css** - TailwindCSS kompilieren
2. **yarn build** - esbuild JavaScript bauen
3. **rails assets:precompile** - Rails Assets vorbereiten
4. **Rails Server starten** - Anwendung läuft

## 🐛 **Debugging**

### **Logs anzeigen:**

```bash
# API Server
docker-compose -f docker-compose.mode.api.yml logs -f web

# Local Server
docker-compose -f docker-compose.mode.local.yml logs -f web
```

### **Container-Bash:**

```bash
# API Server
docker-compose -f docker-compose.mode.api.yml exec web bash

# Local Server
docker-compose -f docker-compose.mode.local.yml exec web bash
```

### **Rails Console:**

```bash
# API Server
docker-compose -f docker-compose.mode.api.yml exec web bundle exec rails console

# Local Server
docker-compose -f docker-compose.mode.local.yml exec web bundle exec rails console
```

## 🧹 **Aufräumen**

### **Container stoppen:**

```bash
# API Server
docker-compose -f docker-compose.mode.api.yml down

# Local Server
docker-compose -f docker-compose.mode.local.yml down
```

### **Alles löschen (inkl. Daten):**

```bash
# API Server
docker-compose -f docker-compose.mode.api.yml down -v

# Local Server
docker-compose -f docker-compose.mode.local.yml down -v
```

## ⚠️ **Wichtige Hinweise**

- **Mode setzen**: Immer zuerst `rake mode:api` oder `rake mode:local` ausführen
- **Credentials**: Werden aus `./config/credentials` gemountet
- **Source Code**: Wird live aus dem aktuellen Verzeichnis geladen
- **Assets**: Werden bei jedem Start neu gebaut
- **Datenbank**: Wird als Volume gespeichert (bleibt erhalten)
- **Ports**: Werden automatisch durch `rake mode:*` angepasst

## 🔄 **Asset-Updates**

Bei Änderungen an CSS/JS:

1. **Container neu starten** (Assets werden automatisch neu gebaut)
2. **Oder manuell im Container:**

   ```bash
   docker-compose -f docker-compose.mode.api.yml exec web yarn build:css
   docker-compose -f docker-compose.mode.api.yml exec web yarn build
   ```

## 🎯 **Workflow für verschiedene Modi**

### **Nur API Server testen:**

```bash
rake mode:api
cd docker/development
docker-compose -f docker-compose.mode.api.yml up --build
```

### **Nur Local Server testen:**

```bash
rake mode:local
cd docker/development
docker-compose -f docker-compose.mode.local.yml up --build
```

### **Beide parallel testen:**

```bash
rake mode:parallel
cd docker/development
docker-compose -f docker-compose.development.parallel.yml up --build
```
