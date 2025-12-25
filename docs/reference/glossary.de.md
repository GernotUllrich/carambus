# Carambus Glossar

## Wichtige Begriffe und Konzepte

Dieses Glossar erklärt die wichtigsten Begriffe in Carambus und wie sie zusammenhängen.

---

## 🏆 Turniere (Einzelwettbewerbe)

### Tournament (Turnier)
Ein **Tournament** ist ein Einzelwettbewerb, bei dem Spieler individuell (nicht in Teams) gegeneinander antreten.

**Eigenschaften:**
- Hat eine **Discipline** (Freie Partie, Dreiband, etc.)
- Hat einen **Modus** (K.O., Schweizer System, Jeder gegen Jeden)
- Hat ein **Datum** und einen **Ort** (Location)
- Wird von einer **Region** oder einem **Club** organisiert

### Seeding (Turnier-Teilnahme)
Ein **Seeding** ist die Teilnahme eines Spielers an einem Turnier.

**Zusammenhang:**
- Ein Tournament hat viele Seedings
- Jedes Seeding verbindet einen Player mit einem Tournament
- Enthält Position, Status, Ergebnis

**Beispiel:**
- Tournament: "Westfalen Open 2024"
- Seedings: Meyer (Position 1), Schmidt (Position 2), ...

---

## 🏅 Ligen (Mannschaftswettbewerbe)

### League (Liga)
Eine **League** ist ein Mannschaftswettbewerb über eine Saison.

**Eigenschaften:**
- Hat mehrere **LeagueTeams** (Mannschaften)
- Läuft über eine **Season** (Saison)
- Hat eine **Discipline** (meist Dreiband oder Freie Partie)
- Wird von einer **Region** organisiert

**Beispiel:** "Bundesliga Nord 2024/2025"

### LeagueTeam (Mannschaft)
Ein **LeagueTeam** ist eine Mannschaft innerhalb einer Liga.

**Eigenschaften:**
- Gehört zu einer **League**
- Gehört zu einem **Club** (Verein)
- Hat mehrere **Spieler** (über SeasonParticipations)

**Beispiel:** "BC Hamburg 1" (Mannschaft des BC Hamburg in der Bundesliga Nord)

### Party (Spieltag)
Ein **Party** ist ein **Spieltag**, an dem sich **zwei LeagueTeams** treffen.

**Wichtig zu verstehen:**
- Ein Party ist NICHT eine "Feier", sondern ein **Spieltag**!
- Ein Spieltag = ein Treffen von genau 2 Mannschaften
- An einem Spieltag werden mehrere **PartyGames** (Einzelspiele) ausgetragen

**Struktur:**
```
League: Bundesliga Nord
  └── Party 1: BC Hamburg vs. BV Wedel (Hinrunde, 15.10.2024)
  └── Party 2: BV Wedel vs. BC Hamburg (Rückrunde, 20.03.2025)
```

**Typischer Ablauf:**
1. **Hinrunde:** Jedes Team spielt einmal gegen jedes andere (Heim oder Auswärts)
2. **Rückrunde:** Die gleichen Begegnungen mit getauschtem Heimrecht

### PartyGame (Einzelspiel innerhalb eines Spieltags)
Ein **PartyGame** ist ein **einzelnes Spiel** zwischen zwei Spielern während eines Spieltags (Party).

**Wichtig zu verstehen:**
- Ein Party (Spieltag) besteht aus **mehreren PartyGames**
- Jedes PartyGame ist ein Spiel: Spieler A vs. Spieler B
- Die Reihenfolge ist durch den **Game Plan** festgelegt
- Typisch: 6-12 PartyGames pro Party (Spieltag)

**Hierarchie:**
```
League (Liga)
  └── LeagueTeam (Mannschaft 1 und 2)
        └── Party (Spieltag zwischen 2 Teams)
              └── PartyGame 1: Spieler A1 vs. Spieler B1
              └── PartyGame 2: Spieler A2 vs. Spieler B2
              └── PartyGame 3: Spieler A1 vs. Spieler B3
              └── ... (weitere PartyGames)
```

**Konkretes Beispiel:**
```
League: Verbandsliga Hamburg 2024/2025
LeagueTeam Heim: BC Hamburg
LeagueTeam Gast: BV Wedel

Party (Spieltag): BC Hamburg vs. BV Wedel
  Datum: 15.10.2024
  Ort: Vereinslokal BC Hamburg
  
  PartyGames:
    1. Müller (Hamburg) vs. Schmidt (Wedel) - 40:35
    2. Meyer (Hamburg) vs. Wagner (Wedel) - 30:40
    3. Müller (Hamburg) vs. Wagner (Wedel) - 40:28
    4. Meyer (Hamburg) vs. Schmidt (Wedel) - 35:40
    5. ... (weitere Paarungen)
  
  Gesamtergebnis: Hamburg 5:3 Wedel
```

### Game Plan
Ein **Game Plan** definiert das Muster der Spiele innerhalb eines Spieltags.

**Beispiel:**
- Runde 1: A1 vs. B1, A2 vs. B2, A3 vs. B3
- Runde 2: A1 vs. B2, A2 vs. B3, A3 vs. B1
- etc.

---

## 👥 Spieler und Teilnahmen

### Player (Spieler)
Ein **Player** ist eine Person, die an Turnieren oder Ligen teilnimmt.

**Eigenschaften:**
- Gehört zu einer **Region** (Heimatverband)
- Kann bei mehreren **Clubs** aktiv sein
- Hat **Rankings** in verschiedenen Disziplinen

### SeasonParticipation (Saison-Teilnahme)
Eine **SeasonParticipation** verbindet einen Spieler mit einem Club für eine bestimmte Saison.

**Warum wichtig:**
- Spieler können die Vereine wechseln
- Pro Saison kann ein Spieler bei verschiedenen Vereinen aktiv sein
- Wird für Ligaberechtigung genutzt

**Beispiel:**
- Spieler: Meyer
- Season: 2024/2025
- Club: BC Hamburg
→ SeasonParticipation: Meyer spielt 2024/2025 für BC Hamburg

### GameParticipation (Spiel-Teilnahme)
Eine **GameParticipation** ist die Teilnahme eines Spielers an einem einzelnen Spiel.

**Unterschied zu Seeding:**
- **Seeding:** Teilnahme an einem **Turnier** (gesamter Wettbewerb)
- **GameParticipation:** Teilnahme an einem **Game** (einzelnes Spiel)

---

## 🖥️ Server-Architektur

### ClubCloud
Die **[ClubCloud](https://club-cloud.de/)** ist eine webbasierte Verwaltungssoftware für Sport-Verbände und Vereine.

**Wichtig:** ClubCloud ist **NICHT** Carambus!

**Was ist ClubCloud?**
- Externe Verwaltungssoftware für Verbände
- 14 der 17 deutschen Billard-Verbände nutzen es
- Jeder Verband hat eigene ClubCloud-Instanz (z.B. ndbv.de, westfalenbillard.net)
- Verwaltet: Spieler, Vereine, Turniere, Ligen, Ranglisten

**Beziehung zu Carambus:**
- Carambus **scrap** Daten von ClubCloud (täglich um 4:00 Uhr)
- Carambus ist **unabhängig** und funktioniert auch ohne ClubCloud
- Ergebnisse können per CSV zurück zu ClubCloud exportiert werden

**Siehe:** [ClubCloud-Integration](../managers/clubcloud-integration.de.md) für Details zum Scraping-Prozess

---

### API Server (Zentraler Server)
Der **API Server** ist die zentrale Datenquelle für alle Carambus-Installationen.

**Hauptaufgaben:**
- **Scraping:** Lädt Daten von ClubCloud und anderen externen Quellen
- **Zentrale Datenhaltung:** Speichert **alle** Daten aus **allen** Regionen
- **Synchronisation:** Verteilt Daten an Local Servers (gefiltert nach Region)

**Beispiel:** carambus.de

**Datenquelle:** Scraping von ClubCloud-Instanzen (siehe [ClubCloud-Integration](../managers/clubcloud-integration.de.md))

### Local Server (Regionaler/Vereins-Server)
Ein **Local Server** ist eine Carambus-Installation für einen spezifischen Standort.

**Hauptaufgaben:**
- **Lokale Spielverwaltung:** Turniere, Scoreboards, Spieltage
- **Regionale Daten:** Nur Daten der eigenen Region (vom API Server gefiltert)
- **Offline-Fähigkeit:** Kann unabhängig vom API Server arbeiten

**Vorteile:**
- ✅ Offline-fähig (wichtig bei Spieltagen!)
- ✅ Schnelle Scoreboards (kein Internet nötig)
- ✅ Kleinere Datenbank (nur eigene Region)

**Beispiel:** Raspberry Pi im BC Hamburg Vereinslokal

### Local Data (Lokal erstellte Daten)
**Local Data** sind Daten, die auf einem Local Server erstellt werden (nicht durch Scraping).

**Einfach gesagt:** Alles was der Verein selbst erstellt und verwaltet, ohne dass es in der überregionalen ClubCloud erfasst ist.

**ID-Bereiche:**
- IDs **< 50.000.000:** Von API Server gescraped (aus ClubCloud)
- IDs **≥ 50.000.000:** Local Data (lokal im Verein erstellt)

**Praktische Beispiele:**
- 🏆 Vereinsturnier (Jahresabschluss-Turnier, nicht in ClubCloud)
- 🎯 Trainingsspiele (Dienstag-Training zur Leistungsmessung)
- 👥 Gastspieler (Besucher ohne Vereinsmitgliedschaft)
- 📅 Tischreservierung (mit Heizungssteuerung)
- 🏅 Interne Vereinsmeisterschaft (über mehrere Wochen)

**Warum wichtig:**
- ✅ Offline-fähig (kein Internet nötig)
- ✅ Keine ID-Konflikte
- ✅ Verein hat volle Kontrolle
- ✅ Statistiken für Training
- ✅ LocalProtector verhindert versehentliches Überschreiben

**Beispiel:**
```
Gescraptes Turnier:     ID 12.345 (ClubCloud, offiziell)
Vereinsturnier (lokal): ID 50.001.234 (nur im Verein)
Training-Game (lokal):  ID 50.100.567 (Dienstag-Training)
```

**Siehe auch:** [Server-Architektur](../administrators/server-architecture.de.md)

---

## 📍 Orte und Organisationen

### Region (Landesverband)
Eine **Region** ist ein Billard-Landesverband in Deutschland.

**Beispiele:**
- NBV (Norddeutscher Billard Verband)
- BVW (Billard-Verband Westfalen)
- BBV (Bayerischer Billardverband)

**Nicht verwechseln mit Städten!**
- Hamburg = Stadt
- NBV = Verband (umfasst Hamburg + Schleswig-Holstein + Bremen)

### Club (Verein)
Ein **Club** ist ein Billard-Verein.

**Eigenschaften:**
- Gehört zu einer **Region**
- Hat **Locations** (Spielorte)
- Hat **Players** über SeasonParticipations
- Kann **Tournaments** veranstalten
- Stellt **LeagueTeams** für Ligen

### Location (Spielort)
Eine **Location** ist ein physischer Ort, an dem gespielt wird.

**Eigenschaften:**
- Hat **Tables** (Billardtische)
- Kann zu einem **Club** gehören
- Kann von einer **Region** verwaltet werden
- Wird für **Tournaments** und **Parties** genutzt

**Unterschied:**
- **Club:** Organisation/Verein (BC Hamburg)
- **Location:** Physischer Ort (Vereinslokal, Adresse, Tische)

---

## 📅 Zeitliche Strukturen

### Season (Saison)
Eine **Season** ist eine Spielzeit, typischerweise ein Jahr.

**Format:** `2024/2025` (von Herbst bis Frühjahr)

**Wichtig:**
- Wird für Ligen verwendet
- Wird für Ranglisten verwendet
- SeasonParticipations sind saisonabhängig

---

## 🎮 Disziplinen und Modi

### Discipline (Disziplin)
Eine **Discipline** ist eine Billard-Spielart.

**Wichtigste Disziplinen:**
- **Freie Partie** (Karambol ohne Einschränkungen)
- **Dreiband** (Ball muss 3 Banden berühren)
- **Einband** (Ball muss 1 Bande berühren)
- **Cadre** (Karambol in begrenztem Bereich)
- **Pool** (Billard mit Taschen)
- **Snooker**

### Discipline Phase
Eine **Discipline Phase** definiert Spielregeln innerhalb einer Disziplin.

**Beispiel Freie Partie:**
- Phase 1: 40 Punkte, 60 Aufnahmen
- Phase 2: 50 Punkte, 75 Aufnahmen (für stärkere Spieler)

---

## 🔄 Häufige Verwechslungen

### Party vs. PartyGame
❌ **Falsch:** "Party ist ein einzelnes Spiel"  
✅ **Richtig:** Party ist der **gesamte Spieltag** mit mehreren Spielen

❌ **Falsch:** "PartyGame ist der Spieltag"  
✅ **Richtig:** PartyGame ist **ein einzelnes Spiel** innerhalb des Spieltags

**Merkhilfe:** 
- 1 Party = 1 Spieltag = viele PartyGames
- 1 PartyGame = 1 Spiel = 2 Spieler

### Seeding vs. GameParticipation
❌ **Falsch:** "Beides ist dasselbe"  
✅ **Richtig:** 
- **Seeding:** Teilnahme am **Turnier** (gesamter Wettbewerb)
- **GameParticipation:** Teilnahme am **Game** (einzelnes Spiel)

### Club vs. Location
❌ **Falsch:** "Club ist der Spielort"  
✅ **Richtig:**
- **Club:** Organisation (BC Hamburg e.V.)
- **Location:** Physischer Ort (Vereinslokal mit Adresse + Tischen)

### Region vs. Stadt
❌ **Falsch:** "Hamburg ist eine Region"  
✅ **Richtig:**
- **Hamburg:** Stadt
- **NBV:** Region/Verband (Norddeutscher Billard Verband)
- Der NBV umfasst Hamburg, Schleswig-Holstein, Bremen

---

## 📊 Entity Relationship Übersicht

```
Season (Saison)
  ├── Tournament (Turnier)
  │     └── Seeding (Turnier-Teilnahme)
  │           └── Player
  │
  └── League (Liga)
        ├── LeagueTeam (Mannschaft)
        │     └── Player (über SeasonParticipation)
        │
        └── Party (Spieltag)
              └── PartyGame (Einzelspiel)
                    ├── Player A
                    └── Player B

Region (Verband)
  ├── Club (Verein)
  │     ├── Location (Spielort)
  │     │     └── Table (Tisch)
  │     └── Player (über SeasonParticipation)
  │
  ├── Tournament (von Region organisiert)
  └── League (von Region organisiert)
```

---

## 💡 Praxis-Beispiele

### "Ich will wissen, wie viele Spiele Meyer diese Saison gespielt hat"

**Zwei Arten von Spielen:**

1. **Turnierspiele (in Einzelturnieren):**
   - Über **Seeding** → **Tournament** → **Games**
   - Meyer's Seedings in Season 2024/2025

2. **Ligaspiele (in Mannschaftsspielen):**
   - Über **PartyGame** → **Party** → **League**
   - Meyer's PartyGames in Season 2024/2025

### "Ich will einen Spieltag organisieren"

**Schritte:**
1. **League** und **LeagueTeams** anlegen (falls nicht vorhanden)
2. **Party** erstellen (Spieltag zwischen 2 Teams)
3. **Location** und **Tables** festlegen
4. **Game Plan** auswählen (Spielmuster)
5. **Spieler** aus den Teams auswählen
6. **PartyGames** generieren lassen
7. **Scoreboards** starten

---

## 📚 Siehe auch

- [Turnierverwaltung](../managers/tournament-management.de.md) - Einzelturniere
- [Ligaspieltage](../managers/league-management.de.md) - Mannschaftswettbewerbe
- [Datenbank-Design](../developers/database-design.de.md) - ER-Diagramm
- [Filter & Suche](search.de.md) - Daten finden

---

**Version:** 1.0  
**Letzte Aktualisierung:** Oktober 2024

