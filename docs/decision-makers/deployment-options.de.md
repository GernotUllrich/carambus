# Deployment-Optionen für Carambus

Ein detaillierter Vergleich aller Betriebsmodelle mit Entscheidungshilfen für verschiedene Einsatzszenarien.

## Übersicht der Deployment-Optionen

Carambus bietet drei grundlegende Deployment-Modelle, die sich in Komplexität, Kosten und Einsatzzweck unterscheiden:

| Aspekt | Cloud-Hosting | On-Premise Server | Raspberry Pi All-in-One |
|--------|---------------|-------------------|-------------------------|
| **Ideal für** | Verbände, Multi-Standort | Datenschutz-sensibel | Einzelvereine |
| **Initiale Kosten** | Gering | Mittel-Hoch | Sehr gering |
| **Laufende Kosten** | 10-50 EUR/Monat | Strom + Internet | Nur Strom (~2 EUR/Monat) |
| **IT-Kenntnisse** | Mittel | Hoch | Gering |
| **Setup-Zeit** | 2-4 Stunden | 1-2 Tage | 30-60 Minuten |
| **Internet erforderlich** | Ja (immer) | Nein (optional) | Nein (optional) |
| **Wartungsaufwand** | Gering | Mittel | Sehr gering |
| **Skalierbarkeit** | Exzellent | Gut | Begrenzt |
| **Datenkontrolle** | Beim Provider | Vollständig | Vollständig |

---

## Option 1: Cloud-Hosting

### Beschreibung

Das System wird auf einem gemieteten Webserver (VPS, Cloud-Instanz) installiert und ist über das Internet für alle Nutzer erreichbar. Der Betreiber muss sich nicht um Hardware kümmern, zahlt aber laufende Hosting-Gebühren.

### Technische Anforderungen

**Server-Spezifikationen (Minimum)**:
- **CPU**: 2 vCores
- **RAM**: 4 GB
- **Speicher**: 20 GB SSD
- **Bandbreite**: 1 TB/Monat
- **Betriebssystem**: Ubuntu 22.04 LTS oder neuer

**Empfohlene Spezifikationen** (für 100+ parallele Nutzer):
- **CPU**: 4 vCores
- **RAM**: 8 GB
- **Speicher**: 50 GB SSD
- **Bandbreite**: Unbegrenzt
- **Backup**: Tägliche Snapshots

### Hosting-Provider (Beispiele)

#### Budget-Option: Hetzner Cloud
- **Modell**: CPX21
- **Preis**: ~8 EUR/Monat
- **Specs**: 3 vCPU, 4 GB RAM, 80 GB SSD
- **Standort**: Deutschland (DSGVO-konform)
- **Geeignet für**: Bis 50 parallele Nutzer

#### Standard-Option: DigitalOcean
- **Modell**: Droplet 4GB
- **Preis**: ~24 USD/Monat
- **Specs**: 2 vCPU, 4 GB RAM, 80 GB SSD
- **Standort**: Frankfurt verfügbar
- **Geeignet für**: Bis 100 parallele Nutzer

#### Premium-Option: AWS/Azure
- **Preis**: Ab 30 EUR/Monat (variabel)
- **Vorteil**: Enterprise-Grade, Auto-Scaling
- **Geeignet für**: Große Verbände, kritische Anwendungen

### Vorteile

✅ **Zentrale Verwaltung**: Ein System für alle Vereine/Standorte  
✅ **Überall verfügbar**: Zugriff von jedem Ort mit Internet  
✅ **Keine Hardware**: Kein eigener Server erforderlich  
✅ **Einfache Skalierung**: Bei Bedarf mehr Ressourcen buchen  
✅ **Automatische Backups**: Meist im Hosting-Paket enthalten  
✅ **Professionelle Infrastruktur**: 99.9% Uptime-Garantie  
✅ **SSL-Zertifikate**: Kostenlos via Let's Encrypt  

### Nachteile

❌ **Laufende Kosten**: Monatliche Gebühren  
❌ **Internet-Abhängigkeit**: Funktioniert nur mit Internetverbindung  
❌ **Datenschutz**: Daten liegen beim Provider  
❌ **Shared Resources**: Performance kann schwanken  

### Kosten-Kalkulation (36 Monate)

**Budget-Setup (Hetzner CPX21)**:
- Hosting: 8 EUR × 36 = 288 EUR
- Domain: 10 EUR/Jahr × 3 = 30 EUR
- **Gesamt**: ~320 EUR

**Standard-Setup (DigitalOcean)**:
- Hosting: 24 USD × 36 ≈ 760 EUR
- Domain: 10 EUR/Jahr × 3 = 30 EUR
- Backup-Service: 5 USD × 36 ≈ 160 EUR
- **Gesamt**: ~950 EUR

### Setup-Prozess

1. **VPS buchen** (30 Minuten)
   - Account bei Hosting-Provider erstellen
   - Server-Instanz auswählen und starten
   - SSH-Zugang einrichten

2. **System vorbereiten** (1 Stunde)
   - Ubuntu installieren (meist vorinstalliert)
   - Firewall konfigurieren
   - Updates einspielen
   - PostgreSQL installieren

3. **Carambus installieren** (1-2 Stunden)
   - Ruby und Rails-Dependencies installieren
   - Carambus-Code per Git auschecken
   - Datenbank einrichten
   - Assets kompilieren

4. **Webserver konfigurieren** (30 Minuten)
   - Nginx installieren und konfigurieren
   - SSL-Zertifikat via Let's Encrypt
   - Domain-DNS konfigurieren

5. **Produktiv schalten** (15 Minuten)
   - Systemd-Service einrichten
   - Server starten und testen
   - Monitoring aktivieren

**Gesamt-Zeitaufwand**: 3-4 Stunden (für erfahrene Admins)

### Wartung

**Regelmäßig erforderlich**:
- Security-Updates: 1× monatlich (15 Minuten)
- Carambus-Updates: Bei Bedarf (30 Minuten)
- Backup-Checks: 1× wöchentlich (5 Minuten)
- Performance-Monitoring: Laufend (automatisiert)

**Geschätzter Zeitaufwand**: 2-3 Stunden/Monat

### Empfohlen für

- ✅ Landes- oder Bundesverbände mit vielen Vereinen
- ✅ Vereine mit mehreren Spielstätten
- ✅ Turniere mit Online-Anmeldung von extern
- ✅ Szenarien, wo von überall Zugriff benötigt wird
- ✅ Organisationen mit IT-Budget aber ohne IT-Personal

---

## Option 2: On-Premise Server

### Beschreibung

Das System läuft auf einem eigenen Server im Vereinsheim oder Rechenzentrum. Volle Kontrolle über Hardware und Daten, aber auch Verantwortung für Betrieb und Wartung.

### Hardware-Optionen

#### Budget: Raspberry Pi 4 (8GB) als Server
- **Kosten**: ~100 EUR
- **Verbrauch**: ~5W (~1 EUR/Monat)
- **Performance**: Gut für kleine Vereine (<50 Mitglieder)
- **Vorteil**: Sehr günstig, lautlos, kompakt

#### Standard: Intel NUC / Mini-PC
- **Kosten**: 300-500 EUR
- **Specs**: Intel i3/i5, 8-16 GB RAM, 256 GB SSD
- **Verbrauch**: ~15W (~3 EUR/Monat)
- **Performance**: Sehr gut für mittelgroße Vereine
- **Vorteil**: Leise, kompakt, zuverlässig

#### Premium: Tower-Server / NAS
- **Kosten**: 800-2.000 EUR
- **Specs**: Xeon/Ryzen, 32+ GB RAM, RAID-Storage
- **Verbrauch**: ~50-100W (~10-20 EUR/Monat)
- **Performance**: Exzellent, auch für große Verbände
- **Vorteil**: Professionell, ausfallsicher (RAID), erweiterbar

### Netzwerk-Anforderungen

**Minimal**:
- LAN-Anschluss (100 Mbit/s)
- Zugriff auf lokales Netzwerk
- Optional: Internetzugang für ClubCloud-Sync

**Empfohlen**:
- Gigabit-LAN
- Statische IP im lokalen Netz
- USV (Unterbrechungsfreie Stromversorgung)
- VPN für Remote-Zugriff

**Für Internet-Zugriff** (optional):
- Statische öffentliche IP oder DynDNS
- Port-Forwarding im Router (Ports 80, 443)
- SSL-Zertifikat

### Vorteile

✅ **Volle Datenkontrolle**: Alle Daten bleiben im Haus  
✅ **Keine laufenden Kosten**: Nur einmalige Hardware-Anschaffung  
✅ **Internet-unabhängig**: Funktioniert auch bei Ausfall  
✅ **Schnell im LAN**: Beste Performance für lokale Nutzer  
✅ **DSGVO-sicher**: Ideal für datenschutzsensible Umgebungen  
✅ **Anpassbar**: Volle Kontrolle über Konfiguration  

### Nachteile

❌ **Hardware-Anschaffung**: Initiale Investition erforderlich  
❌ **Wartungsaufwand**: Updates, Backups selbst durchführen  
❌ **IT-Kenntnisse**: Linux-Kenntnisse erforderlich  
❌ **Stromkosten**: Kontinuierliche Betriebskosten  
❌ **Ausfallrisiko**: Kein professionelles Hosting-SLA  
❌ **Kein Remote-Zugriff**: Nur im lokalen Netz (außer VPN)  

### Kosten-Kalkulation (36 Monate)

**Budget-Setup (Raspberry Pi 4)**:
- Hardware: 100 EUR
- Stromkosten: 1 EUR × 36 = 36 EUR
- Backup (USB-HDD): 50 EUR
- **Gesamt**: ~186 EUR

**Standard-Setup (Intel NUC)**:
- Hardware: 400 EUR
- Stromkosten: 3 EUR × 36 = 108 EUR
- USV: 80 EUR
- Backup-NAS: 150 EUR
- **Gesamt**: ~738 EUR

**Premium-Setup (Tower-Server)**:
- Hardware: 1.500 EUR
- Stromkosten: 15 EUR × 36 = 540 EUR
- USV: 200 EUR
- Netzwerk-Switch: 100 EUR
- **Gesamt**: ~2.340 EUR

### Setup-Prozess

1. **Hardware beschaffen** (Lieferzeit variabel)
2. **Betriebssystem installieren** (1 Stunde)
   - Ubuntu Server 22.04 LTS installieren
   - Netzwerk konfigurieren
   - SSH einrichten
3. **System härten** (1 Stunde)
   - Firewall aktivieren (ufw)
   - Fail2ban installieren
   - Automatische Updates konfigurieren
4. **Carambus installieren** (2-3 Stunden)
   - Dependencies installieren
   - PostgreSQL einrichten
   - Carambus deployen
5. **Backup einrichten** (1 Stunde)
   - Tägliche Datenbank-Backups
   - Backup-Script automatisieren

**Gesamt-Zeitaufwand**: 6-8 Stunden (für erfahrene Linux-Admins)

### Wartung

**Regelmäßig erforderlich**:
- Security-Updates: 1× wöchentlich (10 Minuten)
- Backup-Checks: 1× wöchentlich (10 Minuten)
- Hardware-Check: 1× monatlich (30 Minuten)
- Log-Monitoring: Bei Problemen

**Geschätzter Zeitaufwand**: 3-4 Stunden/Monat

### Empfohlen für

- ✅ Vereine mit eigener IT-Infrastruktur
- ✅ Datenschutz-sensible Umgebungen
- ✅ Vereine mit IT-affinen Mitgliedern
- ✅ Szenarien ohne zuverlässiges Internet
- ✅ Langfristige Kostenminimierung gewünscht

---

## Option 3: Raspberry Pi All-in-One

### Beschreibung

Die eleganteste Lösung für kleine bis mittelgroße Vereine: Ein Raspberry Pi dient gleichzeitig als Server UND als Kiosk-Display. Angeschlossen an einen TV/Monitor im Vereinsheim zeigt er permanent das Tournament-Monitor oder Scoreboard an. Andere Geräte (Tablets, Smartphones) können sich im lokalen Netzwerk verbinden.

### Hardware-Setup

#### Basis-Kit (~150 EUR)
- **Raspberry Pi 4 (8 GB)**: ~90 EUR
- **Netzteil (USB-C, 3A)**: ~10 EUR
- **Micro-SD-Karte (64 GB)**: ~15 EUR
- **Gehäuse mit Lüfter**: ~15 EUR
- **HDMI-Kabel**: ~10 EUR
- **Total**: ~140 EUR

#### Touch-Display-Setup (~350 EUR)
- Basis-Kit: ~140 EUR
- **Offizieller 7" Touch-Display**: ~80 EUR
- **Display-Halterung**: ~20 EUR
- **Touch-Stift**: ~10 EUR
- Optional: Tragbares Gehäuse: ~100 EUR
- **Total**: ~350 EUR

#### Professional Setup (~500 EUR)
- **Raspberry Pi 5 (8 GB)**: ~120 EUR
- Zubehör: ~30 EUR
- **Externes Touch-Display (10-15")**: ~250 EUR
- **Robustes Tablet-Gehäuse**: ~100 EUR
- **Total**: ~500 EUR

### Software-Setup

**Vorinstalliertes Image verfügbar** (empfohlen):
- Download des vorkonfigurierten Images
- Auf SD-Karte flashen (mit Balena Etcher)
- Einmalige Konfiguration (WLAN, Vereinsname)
- **Zeitaufwand**: 30 Minuten

**Manuelle Installation**:
- Raspberry Pi OS Lite installieren
- Carambus-Installationsskript ausführen
- Kiosk-Modus konfigurieren
- **Zeitaufwand**: 2-3 Stunden

### Kiosk-Modus Features

- **Automatischer Start**: System bootet direkt in Chromium-Browser
- **Fullscreen**: Keine Menüleisten oder Desktop sichtbar
- **Auto-Refresh**: Bei Verbindungsproblemen
- **Screensaver**: Dimmen nach Inaktivität
- **Touch-Optimierung**: Große Buttons, Gestensteuerung
- **Fernwartung**: SSH-Zugriff für Updates

### Vorteile

✅ **Extrem günstig**: Geringste Gesamtkosten aller Optionen  
✅ **Plug & Play**: Vorkonfiguriertes Image verfügbar  
✅ **All-in-One**: Server + Display in einem Gerät  
✅ **Stromsparend**: < 15W, ~2 EUR/Monat  
✅ **Kompakt**: Passt hinter jeden Monitor  
✅ **Lautlos**: Keine Lüfter (mit passiver Kühlung)  
✅ **Touch-fähig**: Direkte Bedienung am Display  
✅ **Internet-optional**: Funktioniert vollständig offline  

### Nachteile

❌ **Begrenzte Performance**: Nicht für > 100 Mitglieder  
❌ **Single Point of Failure**: Gerät ist Server UND Display  
❌ **SD-Karten-Risiko**: Kann nach Jahren ausfallen (vermeidbar mit SSD)  
❌ **Nicht skalierbar**: Für Multi-Standort ungeeignet  

### Kosten-Kalkulation (36 Monate)

**Standard-Setup**:
- Hardware: 150 EUR (einmalig)
- Stromkosten: 2 EUR × 36 = 72 EUR
- SD-Karten-Ersatz: 15 EUR (nach 2 Jahren)
- **Gesamt**: ~237 EUR

**Amortisation im Vergleich**:
- **vs. Cloud (Hetzner)**: Amortisation nach 18 Monaten
- **vs. Cloud (DigitalOcean)**: Amortisation nach 10 Monaten

### Setup-Prozess (mit vorkonfiguriertem Image)

1. **Hardware beschaffen** (Online-Bestellung, 3-5 Tage)
2. **Image herunterladen** (15 Minuten)
   - Von GitHub-Releases herunterladen
   - Mit Balena Etcher auf SD-Karte flashen
3. **Raspberry Pi einrichten** (15 Minuten)
   - SD-Karte einsetzen
   - HDMI an Monitor/TV anschließen
   - Strom anschließen → startet automatisch
4. **Ersteinrichtung** (10 Minuten)
   - WLAN konfigurieren (wenn kein LAN)
   - Vereinsnamen und Logo hochladen
   - Admin-Account anlegen
5. **Fertig!** System ist einsatzbereit

**Gesamt-Zeitaufwand**: 30-60 Minuten

### Wartung

**Sehr wartungsarm**:
- Updates: 1× monatlich per SSH (5 Minuten)
- Backup: Automatisch auf USB-Stick (optional)
- Hardware: Gelegentlich Staub entfernen

**Geschätzter Zeitaufwand**: < 1 Stunde/Monat

### Typische Einsatzszenarien

#### Szenario A: Tisch-Monitor
- Raspberry Pi + 7" Touch-Display
- Montage an Wand neben Billardtisch
- Zeigt aktuelles Scoreboard
- Spieler können selbst Punkte eintragen

#### Szenario B: Turnier-Display
- Raspberry Pi an vorhandenen TV/Beamer
- Zentrale Anzeige im Vereinsheim
- Zeigt Tournament-Monitor mit allen Spielen
- Automatische Rotation zwischen Ansichten

#### Szenario C: Mobile Schiedsrichter-Station
- Raspberry Pi + großes Tablet-Display (10-15")
- In tragbarem Gehäuse
- Schiedsrichter trägt zu jedem Tisch
- Erfasst Ergebnisse direkt vor Ort

### Empfohlen für

- ✅ Kleine Vereine (< 100 Mitglieder)
- ✅ Budget-bewusste Installationen
- ✅ Einfache, wartungsarme Lösung gewünscht
- ✅ Einzelstandort (kein Multi-Verein-Betrieb)
- ✅ Primär lokale Nutzung im Vereinsheim
- ✅ Schneller Start ohne IT-Kenntnisse

---

## Vergleichs-Matrix: Erweitert

### Performance-Vergleich

| Metrik | Cloud (Standard) | On-Premise (NUC) | Raspberry Pi 4 |
|--------|------------------|------------------|----------------|
| **Max. parallele Nutzer** | 100+ | 50-100 | 20-30 |
| **Seitenladezeit** | 300-500ms | 100-200ms | 500-800ms |
| **WebSocket-Latenz** | 50-100ms | < 10ms | 10-30ms |
| **Datenbank-Größe** | Unbegrenzt | Abhängig von Disk | 32 GB praktisch |
| **Backup-Geschwindigkeit** | Schnell | Sehr schnell | Langsam |

### Sicherheits-Vergleich

| Aspekt | Cloud | On-Premise | Raspberry Pi |
|--------|-------|------------|--------------|
| **Physische Sicherheit** | Professionell | Mittel | Gering |
| **Netzwerk-Isolierung** | Provider | Selbst | Selbst |
| **DDoS-Schutz** | Inklusive | Selbst | N/A |
| **Datenschutz** | Provider | Vollständig | Vollständig |
| **Update-Frequenz** | Hoch | Mittel | Mittel |
| **Penetration-Testing** | Provider | Selbst | Selbst |

### Verfügbarkeits-Vergleich

| Kriterium | Cloud | On-Premise | Raspberry Pi |
|-----------|-------|------------|--------------|
| **Uptime-SLA** | 99.9% | N/A | N/A |
| **Redundanz** | Vorhanden | Optional | Keine |
| **Strom-Ausfall** | USV vorhanden | USV empfohlen | Problematisch |
| **Hardware-Defekt** | Schneller Ersatz | Selbst besorgen | SD-Karte austauschen |
| **MTTR (Mean Time to Repair)** | < 1 Stunde | 1-24 Stunden | < 1 Stunde |

---

## Entscheidungshilfe: Welche Option passt zu mir?

### Flowchart

```
Haben Sie mehr als 200 Mitglieder?
├─ JA → Wie viele Standorte?
│   ├─ Mehrere → **Cloud-Hosting** (empfohlen)
│   └─ Einer → On-Premise Server (Premium)
│
└─ NEIN → Ist Ihr Budget < 300 EUR?
    ├─ JA → **Raspberry Pi All-in-One** (empfohlen)
    └─ NEIN → Benötigen Sie externe Zugriffe?
        ├─ JA → Cloud-Hosting oder On-Premise + VPN
        └─ NEIN → Raspberry Pi oder On-Premise
```

### Schnell-Check: Ihre Situation

**Sie sollten Cloud-Hosting wählen, wenn**:
- Sie mehrere Vereine/Standorte haben
- Sie von überall Zugriff benötigen
- Sie keine IT-Personal haben
- Sie schnell starten wollen
- Sie Skalierbarkeit benötigen

**Sie sollten On-Premise wählen, wenn**:
- Sie strenge Datenschutz-Anforderungen haben
- Sie IT-Personal oder IT-affine Mitglieder haben
- Sie langfristig Kosten sparen wollen
- Sie Internet-Unabhängigkeit wünschen
- Sie volle Kontrolle über alle Aspekte benötigen

**Sie sollten Raspberry Pi wählen, wenn**:
- Sie ein kleiner Verein sind (< 100 Mitglieder)
- Sie minimales Budget haben
- Sie schnell und einfach starten wollen
- Sie primär lokale Nutzung haben
- Sie eine wartungsarme Lösung wünschen

---

## Migrations-Pfade

### Von Raspberry Pi zu Cloud

**Wann sinnvoll**: Verein wächst, externe Zugriffe werden wichtig

**Prozess**:
1. Datenbank-Backup vom Raspberry Pi erstellen
2. Cloud-Server aufsetzen
3. Backup auf Cloud-Server importieren
4. DNS/URLs umstellen
5. Raspberry Pi als lokaler Display-Client weiterverwenden

**Aufwand**: 2-3 Stunden, **kein Datenverlust**

### Von Raspberry Pi zu On-Premise

**Wann sinnvoll**: Performance-Anforderungen steigen

**Prozess**:
- Identisch zu oben, nur Ziel ist lokaler Server statt Cloud

### Von Cloud zu On-Premise

**Wann sinnvoll**: Datenschutz-Anforderungen ändern sich, langfristige Kostensenkung

**Prozess**:
1. On-Premise-Server aufbauen
2. Datenbank-Backup von Cloud herunterladen
3. Auf lokalem Server importieren
4. Testen im Parallel-Betrieb
5. Umstellen und Cloud kündigen

**Aufwand**: 4-6 Stunden

---

## Zusammenfassung

| Kriterium | Cloud | On-Premise | Raspberry Pi |
|-----------|-------|------------|--------------|
| **Beste Wahl für** | Verbände | Datenschutz | Kleine Vereine |
| **Kosten (3 Jahre)** | 320-950 EUR | 186-2.340 EUR | ~237 EUR |
| **Setup-Zeit** | 3-4 h | 6-8 h | 0.5-1 h |
| **Wartung/Monat** | 2-3 h | 3-4 h | < 1 h |
| **IT-Skills** | Mittel | Hoch | Gering |
| **Skalierbarkeit** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Einfachheit** | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |

**Empfehlung**: Die meisten kleinen bis mittleren Vereine fahren mit der **Raspberry Pi All-in-One-Lösung** am besten. Sie ist kostengünstig, einfach zu installieren und vollkommen ausreichend für den typischen Vereinsbetrieb.

---

*Für individuelle Beratung zu Ihrer spezifischen Situation kontaktieren Sie uns unter gernot.ullrich@gmx.de*



