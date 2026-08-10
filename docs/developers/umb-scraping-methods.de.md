# UMB Scraping — Methoden-Referenz

Diese Seite dokumentiert die öffentlichen Einstiegspunkte und Schlüsselmethoden der `Umb::`-Namespace-Services. Eine Übersicht der Architektur und Designentscheidungen findet sich in der [Architektur-Dokumentation](umb-scraping-implementation.md).

## Scraper-Einstiegspunkte

### `Umb::FutureScraper`

**Datei:** `app/services/umb/future_scraper.rb`

```ruby
Umb::FutureScraper.new.call
```

**Parameter:** keine

**Beschreibung:** Scrapt `FutureTournaments.aspx` der UMB-Webseite. Parst die HTML-Tabelle inkl. monatsübergreifender Ereignisse und wendet Duplikat-Prüfung (Titel + Datum ±30 Tage) an.

!!! warning "Duplikat-Prüfung nutzt den Ort NICHT als Filter"
    Bis 2026-08 floss `location_text` in die Prüfung ein. Als die UMB-Übersicht
    das Ortsformat von `CITY (Country)` auf `CITY / Country (Country)` umstellte,
    lieferte `extract_location` plötzlich `", Turkey"` statt `"Ankara, Turkey"` —
    die Prüfung fand bestehende Turniere nicht mehr wieder und legte bei **jedem
    Lauf** eine neue Kopie an (43 Dubletten-Gruppen im Produktionsbestand).
    Der Ort dient jetzt nur noch als Tiebreaker bei mehreren Kandidaten.
    Bereinigung des Altbestands: `rake umb:dedupe_tournaments`.

**DB-Effekte:**
- Erstellt oder aktualisiert `InternationalTournament`-Datensätze
- Erstellt bei Bedarf `Location`-, `Season`- und `Region` (UMB Organizer)-Datensätze

**Rückgabewert:** `Integer` — Anzahl gespeicherter/aktualisierter Turniere

---

### `Umb::ArchiveScraper`

**Datei:** `app/services/umb/archive_scraper.rb`

```ruby
Umb::ArchiveScraper.new.call(start_id: 1, end_id: 500)
```

**Parameter:**

| Parameter | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `start_id:` | Integer | `1` | Erste zu prüfende Turnier-ID |
| `end_id:` | Integer | `500` | Letzte zu prüfende Turnier-ID (inklusiv) |
| `batch_size:` | Integer | `50` | Rate-Limiting: Sleep nach jeweils dieser Anzahl IDs |

**Beschreibung:** Scannt `TournametDetails.aspx?ID=N` sequentiell für jede ID im angegebenen Bereich. Bricht früh ab bei 50 aufeinanderfolgenden nicht gefundenen IDs. Überspringt bereits bekannte Turniere (per `external_id`).

**DB-Effekte:**
- Erstellt neue `InternationalTournament`-Datensätze für entdeckte Turniere
- Erstellt bei Bedarf `Location`-, `Season`- und `Region`-Datensätze

**Rückgabewert:** `Integer` — Anzahl gespeicherter Turniere

---

### `Umb::DetailsScraper`

**Datei:** `app/services/umb/details_scraper.rb`

```ruby
Umb::DetailsScraper.new.call(tournament_id_or_record, create_games: true, parse_pdfs: false)
```

**Parameter:**

| Parameter | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `tournament_id_or_record` | Integer / InternationalTournament | — | ID aus der Datenbank oder ein bestehender Datensatz |
| `create_games:` | Boolean | `true` | Ob `InternationalGame`-Datensätze aus der HTML-Tabelle angelegt werden sollen |
| `parse_pdfs:` | Boolean | `false` | Ob die PDF-Pipeline (PlayerList, GroupResults, Ranking) ausgeführt wird |

**Beschreibung:** Scrapt eine Turnier-Detailseite von `TournametDetails.aspx?ID=N`. Extrahiert und kategorisiert PDF-Links, aktualisiert Turnierfelder (Ort, Season, Organizer). Wenn `create_games: true`, werden `InternationalGame`-Datensätze mit `type: 'InternationalGame'` (STI) angelegt. Wenn `parse_pdfs: true`, werden alle drei PdfParser-Services unabhängig ausgeführt.

**DB-Effekte:**
- Aktualisiert bestehenden `InternationalTournament`-Datensatz
- Erstellt `InternationalGame`-Datensätze (wenn `create_games: true`)
- Erstellt `Seeding`- und `GameParticipation`-Datensätze (wenn `parse_pdfs: true`)

**Rückgabewert:** `InternationalTournament`-Datensatz bei Erfolg, `false` bei Fehler

---

## PDF-Parser

### `Umb::PdfParser::PlayerListParser`

**Datei:** `app/services/umb/pdf_parser/player_list_parser.rb`

```ruby
Umb::PdfParser::PlayerListParser.new(pdf_text).parse
```

**Eingabe:** Extrahierter PDF-Text (String) einer UMB-Spielerliste (Setzliste)

**Ausgabe:** Array von Hashes mit diesen Schlüsseln:

```ruby
[
  { position: 1, caps_name: "JASPERS", mixed_name: "Dick", nationality: "NL", stage: "main" },
  { position: 2, caps_name: "CAUDRON", mixed_name: "Frédéric", nationality: "BE", stage: "main" },
  { position: 44, caps_name: "MUELLER", mixed_name: "Hans", nationality: "DE", stage: "qualification" },
  # ...
]
```

**Hinweise:**
- Reines PORO — kein DB-Zugriff
- Gibt `[]` zurück bei nil/leerem Input oder fehlenden Spielerzeilen
- `caps_name` ist der Nachname in Großbuchstaben (aus UMB-PDF-Konvention)
- `mixed_name` ist der Vorname in gemischter Schreibweise
- `stage` trennt das gesetzte Hauptfeld vom Qualifikationsfeld

**Drei unterstützte PDF-Layouts.** Stabil sind nur die ersten vier Spalten; was
dahinter steht, hat die UMB mehrfach umgestellt:

| Layout | Beispielzeile |
|---|---|
| Archiv (ab 2013) | `1  BLOMDAHL Torbjorn  SE  1  402  Main Tournament` |
| aktuell (seit 2026) | `1  DERICKS Rene  NL  CEB  Title Holder  UMB-1` |
| Junioren | `1  SANCHEZ Ubaldo  Mexico  15/12/2007  8041  World Champion` |

Das Junioren-Layout führt das Land ausgeschrieben; dort dient das Geburtsdatum
als Anker, weil sich Vorname und Land sonst nicht trennen lassen.

!!! danger "`stage: \"main\"` heißt „war gesetzt“, nicht „hat gespielt“"
    Die Spielerliste entsteht **vor** dem Turnier. Wer sich aus der Qualifikation
    ins Hauptfeld durchsetzt, bleibt hier `"qualification"` — empirisch bestätigt
    am World Cup 2024 (Videos wie `[VEWC2024_L8] F. CAUDRON vs T. TASDEMIR`
    betreffen Spieler, die in der Liste nicht gesetzt waren). Ein harter Filter
    auf `stage == "main"` verliert diese Partien. Für die tatsächliche
    Hauptrunden-Besetzung wären die `MTResults`-PDFs auszuwerten.

---

### `Umb::PdfParser::GroupResultParser`

**Datei:** `app/services/umb/pdf_parser/group_result_parser.rb`

```ruby
Umb::PdfParser::GroupResultParser.new(pdf_text).parse
```

**Eingabe:** Extrahierter PDF-Text (String) eines UMB-Gruppenresultats

**Ausgabe:** Array von Match-Hashes:

```ruby
[
  {
    group: "A",
    player_a: { name: "JASPERS Dick", nationality: nil, points: 30, innings: 14, average: 2.142, match_points: 2, hs: 9 },
    player_b: { name: "CAUDRON Frederic", nationality: nil, points: 25, innings: 14, average: 1.785, match_points: 0, hs: 5 },
    winner_name: "JASPERS Dick"
  },
  # ...
]
```

**Hinweise:**
- Reines PORO — kein DB-Zugriff
- Verwendet Pair-Accumulator-Muster: erste Spielerzeile wird zwischengespeichert, zweite komplettiert das Match
- Gibt `[]` zurück bei nil/leerem Input
- `nationality` ist in Gruppenresultat-PDFs nicht enthalten (immer `nil`)

---

### `Umb::PdfParser::RankingParser`

**Datei:** `app/services/umb/pdf_parser/ranking_parser.rb`

```ruby
Umb::PdfParser::RankingParser.new(pdf_text, type: :final).parse
Umb::PdfParser::RankingParser.new(pdf_text, type: :weekly).parse
```

**Eingabe:**
- `pdf_text` — Extrahierter PDF-Text (String) eines UMB-Rankings
- `type:` — `:final` (Turnier-Abschlussranking) oder `:weekly` (wöchentliches UMB-Weltranking)

**Ausgabe für `type: :final`:**

```ruby
[
  { position: 1, player_name: "JASPERS Dick", nationality: "NL", points: 150, average: 2.500 },
  # ...
]
```

**Ausgabe für `type: :weekly`:**

```ruby
[
  { rank: 1, player_name: "JASPERS Dick", nationality: "NL", points: 1200 },
  # ...
]
```

**Hinweise:**
- Reines PORO — kein DB-Zugriff
- Gibt `[]` zurück bei nil/leerem Input oder unbekanntem Typ
- Wöchentliche Rankings sind unter `files.umb-carom.org/Public/Ranking/` verfügbar

---

## Hilfs-Services

Die folgenden Services werden von den Scrapern intern verwendet und haben keine direkten öffentlichen Einstiegspunkte für den Betrieb:

| Service | Aufgerufen von |
|---------|----------------|
| `Umb::HttpClient` | FutureScraper, ArchiveScraper, DetailsScraper |
| `Umb::DisciplineDetector` | FutureScraper, ArchiveScraper, DetailsScraper |
| `Umb::DateHelpers` | FutureScraper, ArchiveScraper, DetailsScraper |
| `Umb::PlayerResolver` | DetailsScraper |

`Umb::DisciplineDetector` bietet zwei Klassenmethoden: `detect(name)` (nur Regex + DB-ILIKE) und `detect_with_title_fallback(name)` (ergänzt einen titelbasierten `Discipline.classify_from_title`-Fallback mit kuratierten Overrides + Synonymen). `FutureScraper` und `ArchiveScraper` rufen die Fallback-Variante auf; `DetailsScraper` nutzt das reine `detect`. Details in der [Architektur-Dokumentation](umb-scraping-implementation.md) (Abschnitt f).

Eine vollständige Beschreibung dieser Services findet sich in der [Architektur-Dokumentation](umb-scraping-implementation.md).
