# ClubCloud-Integration und Scraping

## Was ist die ClubCloud?

Die **[ClubCloud](https://club-cloud.de/)** ist eine webbasierte Verwaltungssoftware für Sport-Verbände und Vereine in Deutschland.

**Betreiber:** ClubCloud GmbH  
**Website:** https://club-cloud.de/

### Hauptfunktionen der ClubCloud:
- Mitgliederverwaltung
- Turnierplanung und -verwaltung
- Liga-Management (Spieltage, Mannschaften)
- Meldewesen (Turnieranmeldungen, Ummeldungen)
- Ergebniserfassung
- Ranglisten
- Website-CMS für Verbände/Vereine

---

## 🌐 Regionale ClubCloud-Instanzen

**Wichtig:** Es gibt **keine zentrale** ClubCloud für ganz Deutschland!

Stattdessen betreibt jeder Billard-Verband seine **eigene ClubCloud-Instanz**:

### Verbände MIT ClubCloud (14 von 17):

| Verband | Name | ClubCloud-URL |
|---------|------|---------------|
| **DBU** | Deutsche Billard-Union | [billard-union.net](https://billard-union.net/) |
| **BBBV** | Brandenburgischer Billardverband | [billard-brandenburg.net](https://billard-brandenburg.net/) |
| **BLMR** | Billard LV Mittleres Rheinland | [blmr.club-cloud.de](https://blmr.club-cloud.de/) |
| **BLVN** | Billard LV Niedersachsen | [billard-niedersachsen.de](https://billard-niedersachsen.de/) |
| **BVB** | Billard-Verband Berlin | [billardverband-berlin.net](https://billardverband-berlin.net/) |
| **BVBW** | Billard-Verband Baden-Württemberg | [billard-bvbw.de](https://billard-bvbw.de/) |
| **BVNR** | Billard-Verband Niederrhein | [billard-niederrhein.de](https://billard-niederrhein.de/) |
| **BVNRW** | Billard-Verband Nordrhein-Westfalen | [bvnrw.net](https://bvnrw.net/) |
| **BVRP** | Billard Verband Rheinland-Pfalz | [billardverband-rlp.de](https://billardverband-rlp.de/) |
| **BVS** | Billard-Verband-Saar | [billard-ergebnisse.de](https://billard-ergebnisse.de/) |
| **BVW** | Billard-Verband Westfalen | [westfalenbillard.net](https://westfalenbillard.net/) |
| **NBV** | Norddeutscher Billard Verband | [ndbv.de](https://ndbv.de/) |
| **SBV** | Sächsischer Billardverband | [billard-sachsen.de](https://billard-sachsen.de/) |
| **TBV** | Thüringer Billard Verband | [billard-thueringen.de](https://billard-thueringen.de/) |

### Verbände OHNE ClubCloud (3 von 17):

| Verband | Name | Alternative Lösung |
|---------|------|-------------------|
| **BBV** | Bayerischer Billardverband | [billardbayern.de](https://billardbayern.de/) (eigenes System) |
| **HBU** | Hessische Billard Union | (Status unklar) |
| **BLVSA** | Billard LV Sachsen-Anhalt | [blv-sa.de](https://www.blv-sa.de/) (eigenes System) |

**Problem dieser föderalen Struktur:**
- ❌ Keine zentrale Steuerung
- ❌ Datenintegrität nur regional gewährleistet
- ❌ Unterschiedliche Datenqualität pro Region
- ❌ Duplikate möglich bei überregionalen Events (verschiedene lokale Namen)
- ❌ Inkonsistente Schreibweisen (Spieler, Vereine, Locations)

**Vorteil:**
- ✅ Regionale Autonomie
- ✅ Anpassung an lokale Bedürfnisse
- ✅ Unabhängigkeit der Verbände

---

## 🔄 Wie Carambus mit ClubCloud synchronisiert

### Scraping-Konzept

**Wichtig zu verstehen:** Carambus ist **NICHT** Teil der ClubCloud!

Carambus ist eine **eigenständige, unabhängige Anwendung**, die Daten von den ClubCloud-Instanzen **liest** (scraped/extrahiert).

```
ClubCloud-Instanzen (14 regionale Server)
  ndbv.de (NBV)
  billardverband-rlp.de (BVRP)
  westfalenbillard.net (BVW)
  billard-bvbw.de (BVBW)
  ... (10 weitere)
        ↓ Scraping (automatisch + manuell)
Carambus API Server (zentrale Datensammlung)
        ↓ Synchronisation (regional gefiltert)
Carambus Local Servers (Vereine, Raspberry Pi)
        ↓ Lokale Nutzung
Scoreboards, Turnierverwaltung, etc.
```

### Was wird gescraped?

**So ziemlich alles** von den ClubCloud-Instanzen:

- ✅ **Spieler** (Name, DBU-ID, Verein, Kontakt)
- ✅ **Vereine** (Name, DBU-ID, Region, Adresse, Kontakt)
- ✅ **Turniere** (Titel, Datum, Ort, Disziplin, Organisator)
- ✅ **Ligen** (Name, Teams, Spielplan, Saison)
- ✅ **Spieltage** (Parties) mit Terminen
- ✅ **Ergebnisse** (Turnier- und Liga-Ergebnisse)
- ✅ **Ranglisten** (regionale und bundesweite)
- ✅ **Setzlisten** (Turnier-Teilnehmer mit Positionen)
- ✅ **Game Plans** (Spielmuster für Ligen)
- ✅ **LeagueTeams** (Mannschaften mit Spielern)

**Besonderheit:** Jede Region hat eigene **TournamentPlans** (Turniermodi).
Diese sind die Grundlage für das automatisierte Turnier- und Table-Management (TournamentMonitor, TableMonitor).

### Wie oft wird gescraped?

**Automatisch:**
- 🕐 **Täglich um 4:00 Uhr morgens** (Nacht-Job)
- Aktualisiert alle Regionen
- Läuft auf dem API Server

**Manuell:**
- 🎯 **Vor Turnieren** - Aktualisierung der Setzlisten
- 🔄 **Vor Spieltagen** - Aktuelle Mannschafts-Aufstellungen
- 🛠️ **Bei Bedarf** - Admin kann Scraping über UI triggern

**Workflow:**
```ruby
# Automatisch (Cron-Job):
rake regions:scrape_all  # Alle Regionen um 4:00 Uhr

# Manuell (über UI):
Region.find_by(shortname: 'NBV').reload_from_cc
Tournament.find(123).reload_from_cc  # Nur ein Turnier
League.find(456).reload_from_cc_with_details  # Liga mit Details
```

---

## 🆔 Globale IDs und DBU-Daten

Die **[Deutsche Billard-Union (DBU)](https://billard-union.net/)** ist der Dachverband und verwaltet:

**1. Globale IDs (Master-Identifikatoren)**
- **Spieler-IDs (DBU-Nr):** Eindeutig in ganz Deutschland
- **Vereins-IDs (DBU-Nr):** Eindeutig in ganz Deutschland

**2. Bundesweite Daten**
- **Bundesliga** und andere DBU-Turniere
- **Deutsche Meisterschaften**
- **Bundesweite Ranglisten**
- **Kaderdaten**

**Wichtig:** DBU-Daten werden **genauso gescraped** wie regionale Daten!
```
DBU (billard-union.net)
        ↓ Scraping
Carambus API Server
```

**Vorteil der DBU-IDs:**
- ✅ Ein Spieler hat deutschlandweit die gleiche ID
- ✅ Verhindert grundsätzliche Duplikate
- ✅ Ermöglicht überregionale Auswertungen
- ✅ Eindeutige Zuordnung bei Vereinswechsel

**In Carambus:**
```ruby
# Spieler über DBU-ID finden
Player.find_by(dbu_nr: 12345)

# Verein über DBU-ID finden
Club.find_by(dbu_nr: 67890)
```

---

## 🔧 Technische Details

### Scraping-Implementierung

**Carambus scrap öffentlich zugängliche Webseiten** - keine API-Integration!

**Technik:**
- Nokogiri (Ruby HTML/XML Parser)
- HTTP-Requests zu ClubCloud-Seiten
- Extraktion aus HTML-Struktur
- Parsing von Tabellen, Listen, Detailseiten

**Vorteile:**
- ✅ Keine ClubCloud-Änderungen nötig
- ✅ Funktioniert mit öffentlichen Daten
- ✅ Unabhängig von ClubCloud-APIs

**Nachteile:**
- ⚠️ Anfällig für HTML-Struktur-Änderungen
- ⚠️ Parsing-Logik muss angepasst werden bei ClubCloud-Updates

### Authentifizierung

**Für Scraping (Lesen):**
- ✅ **Keine Authentifizierung nötig!**
- Carambus scrap nur **öffentlich zugängliche** Webseiten
- Gleiche Daten die jeder Besucher sieht

**Für CSV-Upload (Schreiben):**
- 🔐 **Authentifizierung erforderlich**
- Login mit Admin-Credentials
- Upload über ClubCloud-Interface
- Manuelle Freigabe in ClubCloud nötig

### Datenintegrität-Probleme und Lösungen

#### Problem 1: Duplikate bei überregionalen Events

**Szenario:** DBU-Turnier mit Teilnehmern aus verschiedenen Regionen

```
ClubCloud NBV: "Spieler Meyer, BC Hamburg"
ClubCloud BVRP: "Spieler Meier, BC Hamburg"  ← Tippfehler!
ClubCloud BVW: "Spieler H. Meyer, Hamburg"   ← Abkürzung!

Problem: 3 verschiedene Einträge für denselben Spieler!
```

**Carambus-Lösung:**

**1. Duplikat-Erkennung mit Synonymen**
```ruby
# Club model speichert Synonyme:
club.synonyms = "BC Hamburg, Billard Club Hamburg, BCH"

# Beim Scraping: Synonym-Matching
# "BC Hamburg" = "Billard Club Hamburg" = gleicher Club
```

**2. Manuelle Merge-Funktionen**
- Index-Listen haben **Merge-Buttons**
- Admin kann Duplikate zusammenführen
- Player.merge(player1, player2)
- Club.merge(club1, club2)
- Tournament.merge(tournament1, tournament2)

**3. DBU-ID als Master**
```ruby
# Bei Konflikt: DBU-ID hat Vorrang
if player1.dbu_nr == player2.dbu_nr
  # Gleicher Spieler → Merge!
end
```

#### Problem 2: Inkonsistente Schreibweisen

**Beispiele:**
- "BC Hamburg" vs. "Billard Club Hamburg"
- "Meyer, Hans" vs. "Hans Meyer"
- "Hamburg" vs. "HH" vs. "Hamburg (Stadt)"

**Carambus-Lösung:**
- Synonym-System (siehe oben)
- Normalisierung bei Import
- Manuelle Korrekturen durch Admins

#### Problem 3: Fehlerhafte Daten in regionaler ClubCloud

**Beispiel:** NBV trägt falsches Turnierdatum ein

**Carambus-Lösung:**
- Local Overrides möglich (LocalProtector)
- Admin kann Daten lokal korrigieren
- Scraping überschreibt **NICHT** geschützte Local Data

---

## 🔄 Synchronisation zurück zur ClubCloud

**Aktueller Stand:** Zwei Upload-Methoden verfügbar

### Methode 1: Automatischer Einzel-Upload (Standard seit 2024)

**Echtzeit-Übertragung während des Turniers:**

```
1. Turnier in Carambus vorbereiten und starten
2. Checkbox "Ergebnisse automatisch in ClubCloud hochladen" aktivieren (Standard)
3. Während des Turniers: Jedes abgeschlossene Spiel wird automatisch übertragen
4. Hintergrund-Prozess überträgt Spielergebnisse sofort nach Finalisierung
5. Automatische Fehlerbehandlung und Wiederholungsversuche
6. Status-Überwachung im Tournament Monitor
```

**Vorteile:**
- ✅ **Echtzeit-Updates:** Ergebnisse sofort sichtbar
- ✅ **Automatisch:** Keine manuelle Arbeit nötig
- ✅ **Robust:** Automatische Fehlerbehandlung
- ✅ **Transparent:** Live-Verfolgung möglich

**Technische Details:**
- Verwendet ClubCloud-Formular-Interface (POST-Request)
- Authentifizierung über Session-Cookie
- Korrekte ClubCloud-Spielnamen (z.B. "Gruppe A:1-2")
- Duplicate-Prevention (bereits hochgeladene Spiele werden übersprungen)
- Error-Logging im Tournament-Data

**Voraussetzungen:**
- Internet-Verbindung während des Turniers
- Gültiges ClubCloud-Login (automatisch über RegionCc)
- `tournament.tournament_cc` vorhanden (automatisch bei ClubCloud-Turnieren)

### Methode 2: Manueller CSV-Upload (Alternative/Backup)

**Batch-Upload nach Turnierablauf:**

```
1. Turnier in Carambus durchführen
2. Ergebnisse in Carambus erfasst (über Scoreboards)
3. Export als CSV-Datei (automatisch per eMail)
4. Login in ClubCloud (mit Admin-Credentials)
5. CSV-Upload über ClubCloud-Interface
6. Manuelle Freigabe/Überprüfung in ClubCloud
```

**Wann verwenden?**
- Bei **Offline-Turnieren** ohne Internet-Verbindung
- Als **Backup** bei Problemen mit automatischem Upload
- Für **Kontrolle** und Überprüfung der Ergebnisse
- Wenn automatischer Upload manuell deaktiviert wurde

**Vorteile:**
- ✅ Funktioniert offline
- ✅ Manuelle Kontrolle möglich
- ✅ CSV als universelles Format
- ✅ Backup-Funktion

**CSV-Datei enthält:**
- Alle Spielergebnisse im ClubCloud-Format
- Korrekte ClubCloud-Spielnamen
- Spielpaarungen, Ergebnisse, Aufnahmen, Höchstserien
- Tischnummern

### Vergleich der Methoden

| Aspekt | Automatischer Upload | CSV-Upload |
|--------|---------------------|------------|
| **Zeitpunkt** | Während des Turniers | Nach dem Turnier |
| **Internet** | Erforderlich | Optional |
| **Manuell** | Nein | Ja |
| **Echtzeit** | Ja | Nein |
| **Fehlerbehandlung** | Automatisch | Manuell |
| **Kontrolle** | Automatisch | Manuell möglich |
| **Empfohlen für** | Standard-Turniere | Offline-Turniere |

**Zukünftig möglich:**
- API-basierte Uploads (wenn ClubCloud API bereitstellt)
- Bi-direktionale Synchronisation
- Erweiterte Fehlerberichterstattung

---

## 💡 Praktische Anwendung

### Szenario 1: Neues Turnier in der ClubCloud

```
1. Verband trägt Turnier in ClubCloud ein (z.B. ndbv.de)
   - "Hamburger Meisterschaft 2024"
   - Datum: 15.11.2024
   - Ort: BC Hamburg
   
2. Carambus scrap automatisch (nachts um 4:00 Uhr)
   - Turnier wird in Carambus-DB importiert
   - ID < 50.000.000 (gescraped)
   - cc_id verweist auf ClubCloud-Eintrag

3. Turnier erscheint in Carambus
   - Unter "Turniere" → Region NBV
   - Mit allen Details von ClubCloud
   - Setzliste kann aktualisiert werden (manuelles Scraping)

4. Turnier-Durchführung mit Carambus
   - TournamentMonitor steuert Ablauf
   - TableMonitor + Scoreboards erfassen Ergebnisse
   - Alles in Carambus gespeichert

5. Ergebnisse zurück zur ClubCloud
   - **Automatisch:** Jedes Spiel wird direkt hochgeladen (Standard, empfohlen)
   - **Alternativ:** CSV-Export aus Carambus
   - **Alternativ:** Upload in ClubCloud (manuell)
   - Veröffentlichung für alle Verbände (automatisch bei Auto-Upload)
```

### Szenario 2: Spieltag vorbereiten

```
1. Liga-Spieltag steht an (z.B. BC Hamburg vs. BV Wedel)
   - Party bereits in ClubCloud eingetragen
   - Teams und Spielplan vorhanden

2. Manuelles Scraping vor Spieltag
   - Admin klickt "Reload from CC" in Carambus
   - Aktuelle Mannschafts-Aufstellungen werden geladen
   - Sicherstellung dass neueste Spieler verfügbar sind

3. Spieltag durchführen
   - Carambus Party Monitor steuert Ablauf
   - Scoreboards erfassen Spiele live
   - Optional: Keine ClubCloud-Verbindung nötig (offline!)

4. Ergebnisse hochladen
   - **Automatisch:** Mit Internet-Verbindung werden Spiele direkt übertragen (empfohlen)
   - **Alternativ (offline):** Nach Spieltag: CSV-Export
   - **Alternativ (offline):** Upload zu ClubCloud (manuell)
   - Aktualisierung der Liga-Tabelle
```

### Szenario 3: Duplikat-Behandlung

```
Problem:
- DBU-Turnier "Deutsche Meisterschaft"
- Spieler "Meyer" aus Hamburg wird in NBV als "Hans Meyer" geführt
- Gleicher Spieler in BVRP als "H. Meyer" geführt
- Carambus scrap beide → 2 Einträge!

Lösung in Carambus:
1. Duplikat-Erkennung (gleiche DBU-ID)
2. Admin nutzt Merge-Funktion in Carambus
3. Player.merge(player_nbv, player_bvrp)
4. Synonyme werden gespeichert
5. Zukünftige Scrapes erkennen beide Namen als gleichen Spieler
```

---

## ❓ Häufige Fragen

**Q: Warum nutzt Carambus nicht die ClubCloud direkt?**  
A: ClubCloud ist für Verbands-Verwaltung optimiert, nicht für Echtzeit-Scoreboards und lokale Offline-Nutzung. Carambus bietet:
- Offline-Fähigkeit für Spieltage
- Schnelle Scoreboards (lokales LAN)
- Eigene Features (TournamentMonitor, TableMonitor)
- Local Data für vereinsinterne Turniere/Training

**Q: Kann ich Carambus ohne ClubCloud nutzen?**  
A: Ja! Mit **Local Data** (ID >= 50.000.000) können Sie komplett unabhängig arbeiten. Scraping ist optional.

**Q: Was passiert wenn ClubCloud ihre HTML-Struktur ändert?**  
A: Das Scraping bricht oder liefert fehlerhafte Daten. Carambus-Entwickler müssen dann die Parsing-Logik anpassen. Regelmäßige Updates wichtig!

**Q: Kann Carambus mit mehreren Regionen gleichzeitig arbeiten?**  
A: Ja! Der API Server scrap alle 14+ ClubCloud-Instanzen. Ein Local Server kann auf Daten mehrerer Regionen zugreifen (konfigurierbar).

**Q: Wie oft sollte ich manuell scrapen?**  
A: 
- Vor **Turnieren:** Setzlisten aktualisieren
- Vor **Spieltagen:** Mannschafts-Aufstellungen prüfen
- Bei **Änderungen:** Wenn ClubCloud-Daten korrigiert wurden

**Q: Werden gelöschte Daten in ClubCloud auch in Carambus gelöscht?**  
A: Nein. Carambus markiert sie nur als "nicht mehr in ClubCloud". Historische Daten bleiben erhalten (wichtig für Statistiken).

---

## 🚀 Zusammenfassung

**Carambus-ClubCloud Integration:**

✅ **Scraping** von 14 regionalen ClubCloud-Instanzen  
✅ **Automatisch** täglich um 4:00 Uhr  
✅ **Manuell** vor Turnieren/Spieltagen  
✅ **Keine Authentifizierung** für Lesen (öffentliche Daten)  
✅ **Automatischer Upload** einzelner Spiele in Echtzeit (Standard seit 2024)  
✅ **CSV-Upload** als Backup für Ergebnisse zurück zur ClubCloud  
✅ **DBU-IDs** als globale Master-Identifikatoren  
✅ **Duplikat-Handling** mit Synonymen und Merge  
✅ **Offline-fähig** durch lokale Datenhaltung  

**Wichtigste Erkenntnis:**
Carambus ist **unabhängig** von ClubCloud und funktioniert auch komplett **ohne**. Das Scraping ist ein **optionaler Service** zur Datenintegration, kein technisches Muss!

---

## 📚 Siehe auch

- [Server-Architektur](../administrators/server-architecture.md) - API vs Local Server
- [Glossar](../reference/glossary.md) - Alle Begriffe erklärt
- [Datenbank-Synchronisierung](../developers/database-partitioning.md) - Technische Details
- [Region Tagging](../developers/region-tagging-cleanup-summary.md) - Regionale Filterung
- [Tournament Duplicate Handling](../developers/tournament-duplicate-handling.md) - Duplikat-Management

---

**Version:** 1.0  
**Letzte Aktualisierung:** Oktober 2024  
**Status:** Vollständig

