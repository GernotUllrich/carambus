# Carambus Server-Architektur

## Überblick

Carambus nutzt eine **verteilte Architektur** mit einem zentralen **API Server** und mehreren **Local Servern**. Dieses Design ermöglicht effiziente Datenverwaltung und optimale Performance für lokale Spielorte.

---

## 🌐 Zwei Server-Typen

### API Server (Zentraler Server)

Der **API Server** ist die zentrale Datenquelle für alle Carambus-Installationen.

**Aufgaben:**
1. **Scraping externer Daten**
   - Lädt Daten von ClubCloud (regionale Verbände)
   - Lädt Daten von billardarea.de (historisch)
   - Importiert Turnierdaten, Spieler, Clubs, etc.
   - Aktualisiert Ranglisten und Ergebnisse

2. **Zentrale Datenhaltung**
   - Speichert **alle** Daten aus **allen** Regionen
   - Vollständige Datenbank mit allen Verbänden
   - Master-Datenquelle für Synchronisation

3. **Datensynchronisation**
   - Verteilt Daten an Local Servers
   - Filtert Daten nach Region (siehe unten)
   - Stellt APIs für Daten-Abfragen bereit

**Hosting:**
- Typischerweise auf dediziertem Server (VPS/Cloud)
- Läuft 24/7
- Hohe Bandbreite für Scraping
- Große Datenbank (alle Regionen)

**Beispiel:** carambus.de (API Server für ganz Deutschland)

---

### Local Server (Regionaler/Vereins-Server)

Ein **Local Server** ist eine Carambus-Installation für einen spezifischen Standort (Verein, Spiellokal, Region).

**Aufgaben:**
1. **Lokale Spielverwaltung**
   - Verwaltet Turniere am Standort
   - Steuert Scoreboards in Echtzeit
   - Lokale Daten-Erfassung

2. **Regionale Datenhaltung**
   - Speichert nur Daten der **eigenen Region** (gefiltert!)
   - Plus: Global relevante Daten (DBU-Turniere, etc.)
   - Plus: Eigene Local Data (siehe unten)

3. **Offline-Fähigkeit**
   - Kann unabhängig vom API Server arbeiten
   - Wichtig für Spieltage (keine Abhängigkeit von Internet)
   - Synchronisiert später mit API Server

**Hosting:**
- Typischerweise Raspberry Pi im Vereinslokal
- Oder Server beim Landesverband
- Läuft lokal im Netzwerk
- Kleinere Datenbank (nur eigene Region)

**Beispiel:** 
- BC Hamburg Local Server (nur Hamburg-Daten + DBU-Turniere)
- BV Westfalen Local Server (nur Westfalen-Daten + DBU-Turniere)

---

## 🔄 Datenfluss

### 1. Scraping (API Server)

```
ClubCloud (NBV) → API Server → scraping → Datenbank (alle Regionen)
ClubCloud (BVW) → API Server → scraping → Datenbank (alle Regionen)
...
```

### 2. Synchronisation (API → Local)

```
API Server (alle Daten)
    ↓ Filter: region_id = Hamburg
Local Server Hamburg (nur Hamburg-Daten + Global)
    ↓ 
Scoreboards, Turniere, etc.
```

### 3. Local Data Upload (Local → API)

```
Local Server Hamburg
    ↓ erstellt Turnier (Local Data, ID > 50.000.000)
    ↓ Upload zu API Server
API Server (speichert Local Data)
    ↓ Synchronisation
Andere Local Server (erhalten Hamburg's Local Data)
```

---

## 🔢 Local Data - Spezieller ID-Bereich

### Was ist Local Data?

**Local Data** sind Daten, die auf einem **Local Server erstellt** werden und nicht durch Scraping vom API Server kommen.

**Einfach gesagt:** Alles was der Verein **selbst** erstellt und verwaltet, ohne dass es in der überregionalen ClubCloud erfasst ist.

### ID-Bereiche

```
IDs:           1 - 49.999.999    → Von API Server (gescraped aus ClubCloud)
IDs: 50.000.000 - 99.999.999    → Local Data (lokal im Verein erstellt)
```

**Warum wichtig?**
- ✅ Local Server kann **offline** arbeiten
- ✅ Keine ID-Konflikte zwischen Servern
- ✅ Klare Unterscheidung: Extern vs. Intern
- ✅ Verein hat volle Kontrolle über eigene Daten

---

### 💡 Praktische Beispiele für Local Data

#### 1. Vereinsturnier ohne ClubCloud-Buchführung

**Szenario:** Der BC Hamburg organisiert ein internes Vereinsturnier zum Jahresabschluss.

```
Problem:
- Turnier findet nur im Verein statt
- Soll NICHT in ClubCloud eingetragen werden (intern)
- Braucht trotzdem Carambus für Scoreboards und Verwaltung

Lösung mit Local Data:
- Turnier lokal erstellen → ID: 50.012.345
- Vollständige Carambus-Funktionalität
- Scoreboards, Setzung, Ergebnisse
- Bleibt lokal, nicht in ClubCloud
```

#### 2. Trainingsspiele zur Leistungsmessung

**Szenario:** Spieler wollen ihre Entwicklung verfolgen, aber nicht jedes Training in die ClubCloud eintragen.

```
Beispiel BC Hamburg:
- Jeden Dienstag: Training mit 8 Spielern
- Erfassung über Scoreboards
- Statistiken: GD-Entwicklung, Höchstserien, etc.
- Lokale Rangliste für den Verein

Local Data:
- Training-Games: IDs 50.100.001, 50.100.002, ...
- Nur im Verein sichtbar
- Langzeit-Statistiken möglich
- Motiviert Spieler (messbare Verbesserung!)
```

#### 3. Gastspieler im Verein

**Szenario:** Ein Spieler aus einem anderen Verein besucht regelmäßig und nimmt an Trainings teil.

```
Problem:
- Spieler ist nicht Vereinsmitglied
- Steht nicht in ClubCloud als BC Hamburg Spieler
- Soll trotzdem am Scoreboard spielen können

Lösung:
- Gastspieler lokal anlegen → ID: 50.200.123
- Kann an lokalen Spielen teilnehmen
- Erscheint NICHT in offiziellen Listen
- Wird NICHT an API Server synchronisiert
```

#### 4. Tischreservierung mit Heizungssteuerung

**Szenario:** Der Verein hat ein automatisches Reservierungssystem für die Billardtische mit Heizungssteuerung.

```
Local Data Tabellen:
- Reservierungen: ID 50.300.001, 50.300.002, ...
- Tischbelegungen
- Heizungs-Zeitpläne
- Vereinsinterne Verwaltung

Warum lokal?
- Nicht relevant für andere Vereine
- Keine ClubCloud-Integration nötig
- Schneller Zugriff (lokal)
- Datenschutz (nur Vereinsmitglieder)
```

#### 5. Interne Vereinsmeisterschaft über mehrere Wochen

**Szenario:** Der Verein organisiert eine mehrwöchige interne Meisterschaft.

```
Setup:
- League (lokal): "BC Hamburg Wintermeisterschaft"
  ID: 50.400.001
- LeagueTeams (lokal): "Die Alten", "Die Jungen", etc.
  IDs: 50.400.010, 50.400.011, ...
- Parties (Spieltage): Jeden Freitag
  IDs: 50.400.100, 50.400.101, ...
- PartyGames: Hunderte von Spielen
  IDs: 50.400.500+

Vorteil:
- Vollständige Liga-Verwaltung im Verein
- Nicht in offizieller ClubCloud
- Eigene Regeln und Modus möglich
- Langzeitstatistiken lokal gespeichert
```

---

### 🔄 Was passiert mit Local Data?

#### Lokal erstellt (Local Server):
```
BC Hamburg Local Server
  ↓ Turnier erstellen
  ID: 50.012.345 (Local Data)
  cc_id: NULL (nicht in ClubCloud)
```

#### Optional: Upload zum API Server
```
Local Server
  ↓ rake sync:to_api (falls gewünscht)
API Server
  ↓ speichert mit gleicher ID
  ID: 50.012.345 bleibt erhalten!
```

#### Synchronisation zu anderen Local Servern
```
API Server (hat jetzt BC Hamburg Local Data)
  ↓ Synchronisation (regional gefiltert!)
Andere NBV-Server bekommen es
  ↓
BV Wedel Local Server sieht:
  "BC Hamburg Vereinsturnier" (read-only)
```

**Wichtig:**
- Local Data bleibt **geschützt** (LocalProtector)
- Nur der **Ersteller-Server** kann bearbeiten
- Andere Server: **nur lesen**
- Kein versehentliches Überschreiben

---

### 🎯 Wann nutzt man Local Data?

**Nutze Local Data für:**
- ✅ Vereinsinterne Turniere
- ✅ Trainingsspiele und Statistiken
- ✅ Gastspieler ohne Vereinsmitgliedschaft
- ✅ Reservierungssysteme
- ✅ Interne Ligen/Meisterschaften
- ✅ Alles was NICHT in ClubCloud soll

**Nutze gescrapte Daten für:**
- ✅ Offizielle Verbandsturniere
- ✅ Bundesliga-Spieltage
- ✅ Ranglisten-Turniere
- ✅ Regionale Meisterschaften
- ✅ Alles was in ClubCloud steht

### Synchronisation von Local Data

1. **Local Server:** Turnier erstellen (ID 50.001.234)
2. **Upload zu API Server:** POST /api/tournaments
3. **API Server:** Speichert mit gleicher ID
4. **Synchronisation:** Andere Local Server erhalten das Turnier
5. **Regionale Filterung:** Nur relevante Regionen erhalten es

---

## 📊 Vergleich: API vs Local Server

| Aspekt | API Server | Local Server |
|--------|-----------|--------------|
| **Daten-Umfang** | Alle Regionen | Nur eigene Region + Global |
| **Datenbank-Größe** | Groß (~GB) | Klein (~MB) |
| **Scraping** | Ja, aktiv | Nein, empfängt nur |
| **Internet nötig** | Ja, immer | Nein, offline-fähig |
| **Scoreboards** | Selten | Ja, permanent |
| **Hosting** | VPS/Cloud | Raspberry Pi, lokal |
| **Anzahl** | 1 zentral | Viele (pro Verein/Region) |
| **Hauptzweck** | Daten sammeln & verteilen | Spieltage abwickeln |

---

## 🏗️ Typische Setups

### Setup 1: Einzelner Verein

```
API Server (carambus.de)
    ↓ Synchronisation (gefiltert)
Local Server (BC Hamburg, Raspberry Pi)
    ↓ LAN
Scoreboards (3 Tische im Vereinslokal)
```

### Setup 2: Landesverband

```
API Server (carambus.de)
    ↓ Synchronisation (NBV-Daten)
Local Server Landesverband (NBV-Server)
    ↓ Internet
    ├─ Local Server BC Hamburg (Raspberry Pi)
    ├─ Local Server BV Wedel (Raspberry Pi)
    └─ Local Server SC Pinneberg (Raspberry Pi)
```

### Setup 3: Nur API Server (Development/Testing)

```
API Server (localhost:3000)
    ↓ direkt
Browser (Entwickler, keine Scoreboards nötig)
```

---

## 🔐 Sicherheit und Isolation

### Daten-Isolation

**Vorteil der regionalen Filterung:**
- Hamburg sieht **keine** internen Westfalen-Daten
- Kleinere Datenbank = schnellere Queries
- DSGVO-konform (nur relevante Daten)

**Global sichtbar:**
- DBU-Turniere (bundesweit)
- Ranglisten
- Öffentliche Veranstaltungen

**Nicht global:**
- Vereinsinterne Turniere
- Trainings-Partien
- Lokale Spieler-Details

---

## 💡 Warum diese Architektur?

### Problem ohne verteiltes System:
❌ Jeder Verein braucht ständige Internet-Verbindung  
❌ Zentrale Überlastung bei vielen Spieltagen  
❌ Single Point of Failure  
❌ Langsame Scoreboards (Remote-Zugriff)

### Lösung mit API + Local Servern:
✅ Local Server arbeiten offline  
✅ Scoreboards sind blitzschnell (LAN)  
✅ Ausfallsicher (dezentral)  
✅ Skalierbar (viele Local Server möglich)  
✅ Regionale Daten bleiben regional  

---

## 🔧 Technische Details

### Regionale Filterung

```ruby
# API Server hat alles:
Tournament.count # => 5000 (alle Regionen)

# Local Server Hamburg hat nur:
Tournament.where(region_id: nbv_id)
          .or(Tournament.where(global_context: true))
          .count # => 500 (nur Hamburg + Global)
```

### Synchronisation

**Von API → Local:**
```ruby
# Rake Task auf Local Server:
rake sync:from_api[region_id]

# Lädt:
# - Alle Daten mit region_id = Hamburg
# - Alle Daten mit global_context = true
# - Alle Daten mit region_id = NULL
```

**Von Local → API:**
```ruby
# Rake Task auf Local Server:
rake sync:to_api[local_data]

# Uploaded:
# - Alle Daten mit ID >= 50.000.000 (Local Data)
# - Neu erstellte Turniere, Spieler, etc.
```

---

## 📚 Siehe auch

- [Datenbank-Partitionierung](../developers/database-partitioning.de.md) - Technische Details
- [Scenario Management](../developers/scenario-management.de.md) - Entwicklung mit mehreren Scenarios
- [Installation](installation-overview.de.md) - Server aufsetzen
- [Raspberry Pi Setup](raspberry-pi-quickstart.de.md) - Local Server auf Raspberry Pi

---

## ❓ Häufige Fragen

**Q: Kann ein Verein auch ohne API Server arbeiten?**  
A: Ja! Local Server ist vollständig funktionsfähig ohne API Server. Allerdings fehlen dann gescrapte Daten von ClubCloud.

**Q: Muss jeder Verein einen Local Server haben?**  
A: Nein. Vereine können auch direkt den API Server nutzen (über Browser). Local Server ist nur nötig für Scoreboards und Offline-Betrieb.

**Q: Was passiert bei ID-Konflikten?**  
A: Keine Konflikte möglich:
- API Server: IDs < 50.000.000
- Local Server: IDs >= 50.000.000
- Unterschiedliche ID-Bereiche garantieren Eindeutigkeit

**Q: Kann ein Local Server für mehrere Regionen Daten haben?**  
A: Ja! Ein Local Server kann mehrere Regionen filtern. Konfigurierbar über `region_ids` Array.

---

**Version:** 1.0  
**Letzte Aktualisierung:** Oktober 2024  
**Status:** Production in Use

