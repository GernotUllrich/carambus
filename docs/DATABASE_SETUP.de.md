# 🗄️ **Datenbank-Setup für Entwickler**

Dieses Dokument beschreibt, wie Sie eine neue Entwicklungsdatenbank für Carambus einrichten können.

## 🚀 **Schnellstart (Empfohlen)**

### **Option 1: Datenbank-Dump importieren**

1. **Datenbank-Dump beschaffen**
   - Von einem anderen Entwickler im Team
   - Aus Ihrem lokalen `carambus_api` Ordner
   - Vom Team Lead

2. **Datenbank erstellen und Dump importieren**
   ```bash
   # Datenbank erstellen
   createdb carambus_development
   
   # Dump importieren
   psql -d carambus_development -f /pfad/zu/ihrem/dump.sql
   
   # Beispiel:
   psql -d carambus_development -f tmp/carambus_api_development_20250813_230822.sql
   ```

3. **Erwartete Fehler (können ignoriert werden)**
   ```
   ERROR: relation "table_name" already exists
   ERROR: multiple primary keys for table "table_name" are not allowed
   ERROR: relation "index_name" already exists
   ERROR: constraint "constraint_name" for relation "table_name" already exists
   ERROR: duplicate key value violates unique constraint "ar_internal_metadata_pkey"
   ```

   Diese Fehler sind normal, wenn die Datenbank bereits teilweise initialisiert wurde.

### **Option 2: Neue Datenbank erstellen**

```bash
# Nur verwenden, wenn kein Dump verfügbar ist
rails db:create
rails db:migrate
rails db:seed
```

## 🔧 **Detaillierte Anleitung**

### **Voraussetzungen**

- PostgreSQL ist installiert und läuft
- `createdb` und `psql` Kommandos sind verfügbar
- Sie haben Zugriff auf eine Datenbank-Dump-Datei

### **Dump-Datei vorbereiten**

1. **Dump-Datei finden**
   ```bash
   # Typische Namen:
   # - carambus_api_development_YYYYMMDD_HHMMSS.sql
   # - carambus_development_dump.sql
   # - carambus_api_development.sql
   ```

2. **Dump-Datei überprüfen**
   ```bash
   # Dateigröße prüfen
   ls -lh /pfad/zu/ihrem/dump.sql
   
   # Erste Zeilen anzeigen
   head -20 /pfad/zu/ihrem/dump.sql
   ```

### **Datenbank erstellen**

```bash
# Neue Datenbank erstellen
createdb carambus_development

# Oder mit spezifischen Parametern
createdb -h localhost -U username carambus_development
```

### **Dump importieren**

```bash
# Einfacher Import
psql -d carambus_development -f /pfad/zu/ihrem/dump.sql

# Mit spezifischen Parametern
psql -h localhost -U username -d carambus_development -f /pfad/zu/ihrem/dump.sql

# Mit Fortschrittsanzeige
psql -d carambus_development -f /pfad/zu/ihrem/dump.sql -v ON_ERROR_STOP=0
```

### **Import überwachen**

```bash
# Import-Logs anzeigen
tail -f /var/log/postgresql/postgresql-*.log

# Datenbank-Verbindung testen
psql -d carambus_development -c "SELECT version();"
psql -d carambus_development -c "\dt"
```

## 🐳 **Docker-Integration**

### **Automatischer Import**

Wenn Sie Docker verwenden, können Sie den Dump automatisch importieren lassen:

```yaml
# docker-compose.yml
services:
  postgres:
    volumes:
      - ./database/carambus_development.sql:/docker-entrypoint-initdb.d/carambus_development.sql
```

### **Manueller Import in Docker-Container**

```bash
# Dump in laufenden Container importieren
docker exec -i container_name psql -U username -d database_name < dump.sql

# Beispiel:
docker exec -i carambus_postgres_1 psql -U www_data -d carambus_development < dump.sql
```

## 🚨 **Fehlerbehebung**

### **Häufige Probleme**

1. **Berechtigungsfehler**
   ```bash
   # PostgreSQL-Benutzer überprüfen
   sudo -u postgres psql -c "\du"
   
   # Benutzer erstellen falls nötig
   sudo -u postgres createuser --interactive username
   ```

2. **Datenbank existiert bereits**
   ```bash
   # Datenbank löschen und neu erstellen
   dropdb carambus_development
   createdb carambus_development
   ```

3. **Import schlägt fehl**
   ```bash
   # Dump-Datei auf Syntax-Fehler prüfen
   psql -d carambus_development -f dump.sql 2>&1 | grep -i error
   
   # Dump-Datei reparieren (falls nötig)
   sed -i 's/CREATE SCHEMA IF NOT EXISTS "public";//' dump.sql
   ```

### **Verifikation**

Nach dem Import sollten Sie folgende Tabellen sehen:

```bash
psql -d carambus_development -c "\dt" | grep -E "(users|clubs|tournaments|leagues)"
```

## 📚 **Weitere Ressourcen**

- [PostgreSQL Dokumentation](https://www.postgresql.org/docs/)
- [Rails Database Guide](https://guides.rubyonrails.org/active_record_migrations.html)
- [Carambus Entwicklerhandbuch](DEVELOPER_GUIDE.de.md)

---

**Tipp**: Verwenden Sie immer einen Datenbank-Dump für die Entwicklung, da dieser alle aktuellen Daten und das korrekte Schema enthält.
