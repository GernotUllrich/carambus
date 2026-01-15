# Migration: newapi/new.carambus.de → api/carambus.de

## Übersicht

Dieses Dokument beschreibt die Schritte zur Migration von den temporären "new"-Subdomains zu den finalen Production-Domains:
- `newapi.carambus.de` → `api.carambus.de`
- `new.carambus.de` → `carambus.de`

## Voraussetzungen

- Root/sudo-Zugriff auf den Hetzner-Server
- SSH-Zugriff als www-data User
- DNS-Zugriff zum Aktualisieren der A-Records

## Phase 1: API-Server (newapi → api.carambus.de)

### Schritt 1.1: Code-Änderungen committen (auf lokalem Mac)

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master

# Alle Änderungen hinzufügen
git add .

# Commit
git commit -m "Migration: Umbenennung newapi/new zu api/carambus.de Domains

- Nginx-Konfigurationen aktualisiert
- Shell-Skripte umbenannt und aktualisiert
- Dokumentation aktualisiert
- scenarios.rake API-URL angepasst
- Named modes aktualisiert"

# Push
git push carambus master
```

### Schritt 1.2: DNS für api.carambus.de vorbereiten

**DNS ist bereits konfiguriert:**

Es existiert bereits ein Wildcard-DNS-Eintrag `*.carambus.de` → Hetzner Server IP.

```bash
# Testen (auf lokalem Mac)
dig api.carambus.de
dig carambus.de
```

Beide sollten auf die gleiche IP zeigen wie `newapi.carambus.de`.

### Schritt 1.3: SSL-Zertifikate übernehmen

**Alte Zertifikate von carambus.de können übernommen werden:**

```bash
# SSH zum Server
ssh -p 8910 www-data@carambus.de

# Vorhandene Zertifikate überprüfen
sudo ls -la /etc/letsencrypt/live/

# Wenn api.carambus.de noch nicht existiert, von carambus.de kopieren/linken
# oder neues Zertifikat erstellen:
sudo certbot certonly --nginx -d api.carambus.de

# Überprüfen
sudo ls -la /etc/letsencrypt/live/api.carambus.de/
```

**Erwartetes Ergebnis:**
```
fullchain.pem -> ../../archive/api.carambus.de/fullchain1.pem
privkey.pem -> ../../archive/api.carambus.de/privkey1.pem
```

### Schritt 1.4: Code auf Server deployen

```bash
# Auf lokalem Mac: Code pushen (falls noch nicht geschehen)
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
git push carambus master

# Auf dem Server: In das Basis-Verzeichnis wechseln
ssh -p 8910 www-data@carambus.de
cd /var/www/carambus_api

# Code aktualisieren
git pull origin master

# Mit Capistrano deployen
cap production deploy
```

**Hinweis:** Capistrano deployed automatisch nach `/var/www/carambus_api/releases/` und setzt den `current` Symlink.

### Schritt 1.5: Nginx-Konfiguration für api.carambus.de erstellen

**Nginx-Config wird NICHT aus docker-trial verwendet, sondern manuell erstellt:**

```bash
# Auf dem Server
# Die bestehende newapi.carambus.de Config als Vorlage nehmen
sudo cp /etc/nginx/sites-available/newapi.carambus.de \
  /etc/nginx/sites-available/api.carambus.de

# Mit Editor anpassen (vim/nano)
sudo nano /etc/nginx/sites-available/api.carambus.de
```

**Zu ändernde Zeilen in der Config:**
- `server_name newapi.carambus.de;` → `server_name api.carambus.de;`
- `ssl_certificate /etc/letsencrypt/live/newapi.carambus.de/fullchain.pem;` → `ssl_certificate /etc/letsencrypt/live/api.carambus.de/fullchain.pem;`
- `ssl_certificate_key /etc/letsencrypt/live/newapi.carambus.de/privkey.pem;` → `ssl_certificate_key /etc/letsencrypt/live/api.carambus.de/privkey.pem;`
- Alle Log-Pfade: `newapi.carambus.de` → `api.carambus.de`
- Am Ende: `if ($host = newapi.carambus.de)` → `if ($host = api.carambus.de)`

```bash
# Symlink erstellen
sudo ln -sf /etc/nginx/sites-available/api.carambus.de \
  /etc/nginx/sites-enabled/api.carambus.de

# Nginx-Konfiguration testen
sudo nginx -t
```

**Erwartetes Ergebnis:**
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### Schritt 1.6: Nginx neu laden

```bash
# Nginx neu laden (ohne Downtime)
sudo systemctl reload nginx

# Status überprüfen
sudo systemctl status nginx

# Überprüfen, dass beide Configs aktiv sind
ls -la /etc/nginx/sites-enabled/ | grep carambus
```

**Erwartetes Ergebnis:**
```
api.carambus.de -> /etc/nginx/sites-available/api.carambus.de
newapi.carambus.de -> /etc/nginx/sites-available/newapi.carambus.de
```

### Schritt 1.7: Testen

```bash
# Auf lokalem Mac oder Server
curl -I https://api.carambus.de
```

**Erwartetes Ergebnis:**
- HTTP/2 200 OK
- Server funktioniert auf neuer Domain

**Im Browser testen:**
- https://api.carambus.de
- Sollte die gleiche Seite wie newapi.carambus.de zeigen

### Schritt 1.8: Logs überprüfen

```bash
# Error-Log checken
sudo tail -f /var/log/nginx/api.carambus.de_error.log

# Access-Log checken
sudo tail -f /var/log/nginx/api.carambus.de_access.log
```

### Schritt 1.9: Alte newapi-Konfiguration deaktivieren (Optional, später)

**WICHTIG:** Erst nach erfolgreicher Migration und wenn alle Clients aktualisiert sind!

```bash
# Alte Config deaktivieren
sudo rm /etc/nginx/sites-enabled/newapi.carambus.de

# Nginx neu laden
sudo systemctl reload nginx
```

## Phase 2: Local Server (new → carambus.de)

**Hinweis:** `carambus.de` ist ein Local Server (wie andere location_* Instanzen), läuft aber auf dem gleichen Hetzner-Server wie der API-Server. Der einzige Unterschied zu anderen Local Servers: Kein Region-Filtering.

### Schritt 2.1: DNS für carambus.de vorbereiten

**DNS ist bereits konfiguriert:**

Der Wildcard-DNS-Eintrag `*.carambus.de` deckt auch die Haupt-Domain ab.

```bash
# Testen
dig carambus.de
```

### Schritt 2.2: SSL-Zertifikat für carambus.de überprüfen/erstellen

```bash
# SSH zum Server (gleicher Server wie API)
ssh -p 8910 www-data@carambus.de

# Zertifikat überprüfen (sollte bereits existieren)
sudo ls -la /etc/letsencrypt/live/carambus.de/

# Falls nicht vorhanden, erstellen:
sudo certbot certonly --nginx -d carambus.de
```

### Schritt 2.3: Nginx-Konfiguration für carambus.de erstellen

**Analog zu api.carambus.de - bestehende Config kopieren und anpassen:**

```bash
# Die bestehende new.carambus.de Config als Vorlage nehmen
sudo cp /etc/nginx/sites-available/new.carambus.de \
  /etc/nginx/sites-available/carambus.de

# Mit Editor anpassen
sudo nano /etc/nginx/sites-available/carambus.de
```

**Zu ändernde Zeilen:**
- `server_name new.carambus.de;` → `server_name carambus.de;`
- `ssl_certificate /etc/letsencrypt/live/new.carambus.de/fullchain.pem;` → `ssl_certificate /etc/letsencrypt/live/carambus.de/fullchain.pem;`
- `ssl_certificate_key /etc/letsencrypt/live/new.carambus.de/privkey.pem;` → `ssl_certificate_key /etc/letsencrypt/live/carambus.de/privkey.pem;`
- Alle Log-Pfade: `new.carambus.de` → `carambus.de`
- Am Ende: `if ($host = new.carambus.de)` → `if ($host = carambus.de)`
- Root-Pfad prüfen: sollte `/var/www/carambus/current/public` sein

```bash
# Symlink erstellen
sudo ln -sf /etc/nginx/sites-available/carambus.de \
  /etc/nginx/sites-enabled/carambus.de

# Nginx-Konfiguration testen
sudo nginx -t

# Nginx neu laden
sudo systemctl reload nginx
```

### Schritt 2.4: Testen

```bash
# Testen
curl -I https://carambus.de
```

**Im Browser:**
- https://carambus.de
- Sollte die Hauptseite zeigen

### Schritt 2.5: Alte new.carambus.de Konfiguration deaktivieren (Optional, später)

```bash
# Erst nach erfolgreicher Migration!
sudo rm /etc/nginx/sites-enabled/new.carambus.de
sudo systemctl reload nginx
```

## Phase 3: Lokale Scenario-Deployments aktualisieren

Alle lokalen Scenario-Deployments (carambus_location_*, carambus_bcw, etc.) müssen ihre `config/carambus.yml` aktualisieren:

### Option A: Automatisch durch prepare_development

```bash
# Im jeweiligen Scenario-Verzeichnis
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_location_XXXX

# prepare_development ausführen (aktualisiert automatisch vom Master)
bundle exec rails prepare_development
```

### Option B: Manuell git pull

```bash
# Im jeweiligen Scenario-Verzeichnis
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_location_XXXX

# Code vom Master holen
git pull origin master
```

Die neue `carambus.yml.erb` wird dann automatisch verwendet.

## Phase 4: Verifikation

### Checklist

- [ ] DNS für api.carambus.de zeigt auf korrekte IP
- [ ] DNS für carambus.de zeigt auf korrekte IP
- [ ] SSL-Zertifikate für beide Domains erstellt
- [ ] Nginx-Configs für beide Domains installiert
- [ ] Nginx läuft ohne Fehler
- [ ] https://api.carambus.de ist erreichbar
- [ ] https://carambus.de ist erreichbar
- [ ] Puma-Services laufen (carambus_api, carambus)
- [ ] Logs zeigen keine Fehler
- [ ] Lokale Scenarios aktualisiert

### Test-URLs

#### API-Server
```bash
# Health-Check
curl https://api.carambus.de/up

# API-Endpoint testen
curl https://api.carambus.de/api/v1/tournaments
```

#### Main-Server
```bash
# Health-Check
curl https://carambus.de/up

# Hauptseite
curl -I https://carambus.de
```

## Phase 5: Cleanup (nach erfolgreicher Migration)

**Erst wenn alles funktioniert und alle Clients aktualisiert sind!**

### Alte nginx-Configs entfernen

```bash
# Auf dem Server
sudo rm /etc/nginx/sites-enabled/newapi.carambus.de
sudo rm /etc/nginx/sites-available/newapi.carambus.de
sudo rm /etc/nginx/sites-enabled/new.carambus.de
sudo rm /etc/nginx/sites-available/new.carambus.de

# Nginx neu laden
sudo systemctl reload nginx
```

### Alte Zertifikate können bleiben

Die alten Zertifikate in `/etc/letsencrypt/live/newapi.carambus.de/` und `new.carambus.de/` können bleiben. Sie erneuern sich nicht mehr automatisch und können später gelöscht werden.

## Troubleshooting

### Problem: nginx test schlägt fehl

```bash
# Config-Syntax überprüfen
sudo nginx -t

# Detaillierte Fehler anzeigen
sudo nginx -T | grep -A 10 "error"

# Zertifikatspfade überprüfen
sudo ls -la /etc/letsencrypt/live/api.carambus.de/
sudo ls -la /etc/letsencrypt/live/carambus.de/
```

### Problem: SSL-Zertifikat kann nicht erstellt werden

```bash
# Überprüfen, dass DNS aufgelöst wird
dig api.carambus.de

# Let's Encrypt Logs checken
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Manuell mit Webroot erstellen
sudo certbot certonly --webroot \
  -w /var/www/carambus_api/current/public \
  -d api.carambus.de
```

### Problem: 502 Bad Gateway

```bash
# Puma-Status überprüfen
sudo systemctl status carambus_api
sudo systemctl status carambus

# Puma neu starten
sudo systemctl restart carambus_api
sudo systemctl restart carambus

# Logs checken
sudo tail -f /var/log/carambus_api/error.log
sudo tail -f /var/log/nginx/api.carambus.de_error.log
```

### Problem: DNS propagiert nicht

```bash
# DNS von verschiedenen Servern testen
dig api.carambus.de @8.8.8.8
dig api.carambus.de @1.1.1.1

# DNS-Cache leeren (auf lokalem Mac)
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

## Zeitplan

**Geschätzte Dauer:**
- Phase 1 (API-Server): 20-30 Minuten
- Phase 2 (Main-Server): 15-20 Minuten
- Phase 3 (Lokale Scenarios): 5-10 Minuten
- Phase 4 (Verifikation): 10-15 Minuten

**Gesamtzeit: ca. 1 Stunde**

**Beste Zeit:** Außerhalb der Hauptnutzungszeiten, idealerweise morgens oder nachts.

## Rollback-Plan

Falls etwas schiefgeht:

```bash
# Neue Configs deaktivieren
sudo rm /etc/nginx/sites-enabled/api.carambus.de
sudo rm /etc/nginx/sites-enabled/carambus.de

# Nginx neu laden
sudo systemctl reload nginx

# Alte Domains funktionieren weiterhin
```

Die alten Configs bleiben aktiv, bis sie explizit gelöscht werden!
