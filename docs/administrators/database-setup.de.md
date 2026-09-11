# 🗄️ **Datenbank-Setup für Entwickler**

Dieses Dokument beschreibt, wie Sie eine Entwicklungsdatenbank für ein Carambus-Szenario einrichten.

Die Datenbank heißt `<szenario>_development` (z. B. `carambus_bcw_development`). Maßgeblich ist
`database:` in `config/database.yml` des Szenario-Checkouts bzw. `database_name` in
`carambus_data/scenarios/<szenario>/config.yml`.

## 🚀 **Schnellstart (Empfohlen)**

### **Option 1: Über das Scenario Management**

Der reguläre Weg, aus einem beliebigen aktuellen carambus-Checkout:

```bash
bin/rails "scenario:prepare_development[<szenario>,development]"
```

Der Task leitet `<szenario>_development` aus `carambus_api_development` ab (Vorlage per `createdb --template`)
und setzt danach die Sequences für lokale Daten zurück.

!!! warning "Voraussetzungen und Seiteneffekte"
    - **SSH-Zugang zur Authority:** Ist `carambus_api_development` nicht vorhanden oder älter als die
      Produktion der Authority, holt der Task sie per SSH als `www-data` von `api.carambus.de`. Diesen
      Zugang haben derzeit nur die Betreiber von Carambus.
    - **Ersetzt `carambus_api_development`:** Liegen bei der Authority neuere Daten, wird die lokale
      `carambus_api_development` gesichert, gelöscht und neu aufgebaut; die Sicherung wird danach wieder
      gelöscht. Das betrifft jeden Checkout, der dieselbe Datenbank nutzt.
    - **Ersetzt `<szenario>_development`:** Eine vorhandene Szenario-Datenbank wird gelöscht und neu
      angelegt. Enthält sie lokale Daten (IDs ab 50.000.000), bricht der Task ohne `FORCE=true` ab.

### **Option 2: Datenbank-Dump importieren**

Dumps entstehen und landen über die Scenario-Tasks an einer festen Stelle:

```bash
# Dump anlegen: carambus_data/scenarios/<szenario>/database_dumps/<szenario>_<env>_<YYYYMMDD_HHMMSS>.sql.gz
bin/rails "scenario:create_database_dump[<szenario>,development]"

# Jüngsten Dump dieses Szenarios einspielen (löscht die Ziel-Datenbank vorher)
bin/rails "scenario:restore_database_dump[<szenario>,development]"
```

Von Hand einspielen:

```bash
createdb <szenario>_development
gunzip -c /pfad/zu/<datei>.sql.gz | psql <szenario>_development
```

**Erwartete Meldungen (können ignoriert werden)**
```
ERROR: role "www_data" does not exist
invalid command \restrict
invalid command \unrestrict
ERROR: relation "table_name" already exists
ERROR: multiple primary keys for table "table_name" are not allowed
ERROR: relation "index_name" already exists
ERROR: constraint "constraint_name" for relation "table_name" already exists
ERROR: duplicate key value violates unique constraint "ar_internal_metadata_pkey"
```

Die ersten drei stammen aus Dumps der Authority: Die Rolle `www_data` gibt es lokal nicht, und ein neueres
`pg_dump` schreibt Meta-Befehle, die ein älteres lokales `psql` überspringt. Beide erscheinen auch während
`scenario:prepare_development`; der Task meldet trotzdem Erfolg. Die übrigen treten auf, wenn die Datenbank
bereits teilweise initialisiert war.

### **Option 3: Leere Datenbank (nur Schema)**

```bash
bin/rails db:create
bin/rails db:migrate
```

Danach enthält die Datenbank nur das Schema, **keine Stammdaten**. `db:seed` legt nichts an
(`db/seeds.rb` enthält keinen ausführbaren Code). Für eine lauffähige Instanz führt der Weg über
Option 1 oder 2.

## 🔧 **Detaillierte Anleitung**

### **Voraussetzungen**

- PostgreSQL ist installiert und läuft
- `createdb` und `psql` Kommandos sind verfügbar
- Für Option 1: SSH-Zugang zur Authority (siehe oben) oder eine aktuelle lokale `carambus_api_development`
- Für Option 2: ein Dump unter `carambus_data/scenarios/<szenario>/database_dumps/`

### **Dump-Datei prüfen**

```bash
# Vorhandene Dumps
ls -lh ~/DEV/carambus/carambus_data/scenarios/<szenario>/database_dumps/

# Erste Zeilen anzeigen
gunzip -c /pfad/zu/<datei>.sql.gz | head -20
```

### **Datenbank erstellen**

```bash
# Neue Datenbank erstellen
createdb <szenario>_development

# Oder mit spezifischen Parametern
createdb -h localhost -U username <szenario>_development
```

### **Dump importieren**

```bash
# Einfacher Import
gunzip -c /pfad/zu/<datei>.sql.gz | psql -d <szenario>_development

# Mit spezifischen Parametern
gunzip -c /pfad/zu/<datei>.sql.gz | psql -h localhost -U username -d <szenario>_development
```

### **Import überwachen**

```bash
# Datenbank-Verbindung testen
psql -d <szenario>_development -c "SELECT version();"
psql -d <szenario>_development -c "\dt"
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
   dropdb <szenario>_development
   createdb <szenario>_development
   ```

3. **Import schlägt fehl**
   ```bash
   # Fehler aus dem Import herausfiltern
   gunzip -c /pfad/zu/<datei>.sql.gz | psql -d <szenario>_development 2>&1 | grep -i error
   ```

### **Verifikation**

Nach dem Import sollten Sie folgende Tabellen sehen:

```bash
psql -d <szenario>_development -c "\dt" | grep -E "(users|clubs|tournaments|leagues)"
```

## 📚 **Weitere Ressourcen**

- [PostgreSQL Dokumentation](https://www.postgresql.org/docs/)
- [Rails Database Guide](https://guides.rubyonrails.org/active_record_migrations.html)
- [Carambus Entwicklerhandbuch](../developers/developer-guide.md)
- [Installations-Übersicht](installation-overview.md)

---

**Tipp**: Verwenden Sie für die Entwicklung eine aus der Authority abgeleitete Datenbank (Option 1 oder 2); nur sie enthält die globalen Stammdaten und das aktuelle Schema.
