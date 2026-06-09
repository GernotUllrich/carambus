# Turnier-Duplikat-Behandlungssystem

## Übersicht

Dieses System befasst sich mit dem Problem von doppelten Turnieren mit unterschiedlichen `cc_id` Werten während des Scrapings. Die Quelle (ClubCloud) stellt dasselbe Turnier (gleicher Name, Saison, Veranstalter) manchmal unter mehr als einer `cc_id` bereit. Ohne Behandlung würden wiederholte Scraping-Läufe zwischen den verschiedenen `cc_id`-Versionen hin- und herwechseln. Dieses System markiert die überholte `cc_id` als verlassen, sodass zukünftige Läufe sie überspringen.

## Wie es funktioniert

### 1. Inkrementelle Deduplizierung pro Zeile (Live-Scrape-Pfad)

Die Deduplizierung erfolgt **inkrementell, Zeile für Zeile**, innerhalb von
`Region#scrape_single_tournament_public(season, opts = {})`
(`app/models/region.rb`). Im Live-Scrape gibt es **keinen vorgelagerten
Gruppierungs-Durchlauf nach Namen**; jede Turnierzeile aus der ClubCloud-Liste
wird der Reihe nach verarbeitet:

1. Die `cc_id` der aktuellen Zeile wird aus dem Turnier-Link gelesen.
2. Wenn diese `cc_id` bereits auf der Überspringliste der verlassenen Einträge
   steht (`AbandonedTournamentCcSimple.is_abandoned?(cc_id, context)`), wird die
   Zeile vollständig übersprungen.
3. Andernfalls sucht der Scraper nach einem **bestehenden** `TournamentCc`,
   dessen zugehöriges `Tournament` denselben **Titel, dieselbe Saison und
   denselben Veranstalter**, aber eine **andere `cc_id`** hat:

   ```ruby
   existing_tc_for_tournament = TournamentCc.joins(:tournament)
     .where(tournaments: { title: name, season: season, organizer: self })
     .where.not(cc_id: cc_id)
     .first
   ```

4. Existiert ein solcher Datensatz, wird er als veraltetes Duplikat behandelt:
   seine `old_cc_id` wird als verlassen markiert, und der Scraper fährt mit der
   **aktuell gescrapten `cc_id`** fort und erstellt/aktualisiert dafür ein
   `TournamentCc`.

### 2. Auswahlverhalten

Das **implementierte** Verhalten ist einfach: **die aktuell gescrapte `cc_id`
behalten und die vorherige** mit demselben Turniertitel gefundene verlassen.
Die „aktuelle Zeile gewinnt", weil die ClubCloud-Liste die maßgebliche Quelle
dafür ist, was gerade live ist.

> **Noch nicht implementiert (Design-Ziel):** Eine reichere Auswahllogik —
> *hat Spiele > hat Setzlisten > höchste `cc_id`* — wurde als zukünftige
> Verbesserung skizziert, ist aber **kein** Teil des Live-Scrape-Pfads. Die
> vorhandene teilweise Setzlisten-/Spiele-Prüfung
> (`Region#check_tournament_status`) wird nur von der diagnostischen
> `analyze_duplicates`-Berichtsaufgabe verwendet, nicht zur automatischen
> Auswahl.

### 3. Verlassenheits-Verfolgung

Verlassene `cc_id`-Werte werden festgehalten, damit zukünftige Läufe sie
überspringen. Daran sind zwei verschiedene Modelle beteiligt — siehe
[Datenbankmodelle](#datenbankmodelle).

## Datenbankmodelle

Es gibt **zwei getrennte Modelle** mit unterschiedlichen Rollen:

### `AbandonedTournamentCcSimple` — Überspringliste des Live-Scrapes

`app/models/abandoned_tournament_cc_simple.rb`, Tabelle
`abandoned_tournament_cc_simples`. Dies ist das schlanke Modell, das der
**Live-Scraper tatsächlich schreibt und liest**. Es speichert nur das, was
nötig ist, um eine `cc_id` bei folgenden Läufen zu überspringen:

| Spalte         | Beschreibung                                  |
|----------------|-----------------------------------------------|
| `cc_id`        | Die verlassene Turnier-`cc_id`                |
| `context`      | Der Regions-Kontext (z.B. `dbu`, `nbv`)       |
| `abandoned_at` | Wann es als verlassen markiert wurde          |

Klassenmethoden:
- `is_abandoned?(cc_id, context)` — Überspringliste prüfen.
- `mark_abandoned!(cc_id, context)` — zur Überspringliste hinzufügen (no-op bei Duplikat).

### `AbandonedTournamentCc` — manuelles / diagnostisches Modell

`app/models/abandoned_tournament_cc.rb`, Tabelle `abandoned_tournament_ccs`.
Dies ist das **reichere Audit-Modell**, das von den manuellen/diagnostischen
Rake-Aufgaben verwendet wird (`analyze_duplicates`,
`list_abandoned_tournaments`, `mark_tournament_abandoned`,
`cleanup_abandoned_tournaments`). Der Live-Scrape-Pfad schreibt **nicht** in
dieses Modell.

```ruby
# Felder:
- cc_id: Die verlassene Turnier-cc_id
- context: Der Regions-Kontext (z.B. 'dbu', 'nbv')
- region_shortname: Der Regions-Kurzname
- season_name: Der Saisonname
- tournament_name: Der Turniername
- abandoned_at: Wann es als verlassen markiert wurde
- reason: Warum es verlassen wurde
- replaced_by_cc_id: Welche cc_id es ersetzt hat
- replaced_by_tournament_id: Welches Turnier es ersetzt hat
```

Klassenmethoden:
- `is_abandoned?(cc_id, context)` — prüft, ob eine cc_id verlassen ist.
- `mark_abandoned!(cc_id, context, region_shortname, season_name, tournament_name, reason:, replaced_by_cc_id:, replaced_by_tournament_id:)` — legt einen reichen Verlassenheits-Eintrag an/aktualisiert ihn.
- `for_region_season(region_shortname, season_name)` — Scope für die Auflistung.
- `find_duplicate_tournaments(region_shortname, season_name, tournament_name)` — geordnete Duplikat-Suche.
- `analyze_duplicates(region_shortname, season_name)` — gruppiert die Live-ClubCloud-Liste nach Namen und meldet doppelte `cc_id`s mit ihrem Setzlisten-/Spiele-/Verlassen-Status.
- `cleanup_old_records(days = 365)` — entfernt alte Datensätze (positionales `days`).

## Verwendung

### Automatische Behandlung
Die inkrementelle Deduplizierung läuft automatisch als Teil des öffentlichen
Turnier-Scrapes (`Season#scrape_single_tournaments_public_cc` →
`Region#scrape_single_tournament_public`), der von den regulären
Scraping-Aufgaben aufgerufen wird (z.B. `scrape:daily_update`).

> **Hinweis zu `scrape:scrape_tournaments_optimized`:** Es existiert eine
> separate Rake-Aufgabe `scrape:scrape_tournaments_optimized`, die
> `Season#scrape_tournaments_optimized` aufruft, das wiederum
> `Region#scrape_tournaments_optimized(season, opts)` aufruft. **Diese
> Region-Methode ist derzeit nicht definiert**, daher ist diese Aufgabe kein
> funktionierender Einstiegspunkt für die oben beschriebene Deduplizierung. Der
> funktionierende Dedup-Pfad ist `Region#scrape_single_tournament_public`.

### Manuelle Verwaltung

#### Duplikate analysieren
```bash
rake scrape:analyze_duplicates REGION=NBV SEASON=2023/2024
```

#### Verlassene Turniere auflisten
```bash
rake scrape:list_abandoned_tournaments REGION=NBV SEASON=2023/2024
```

#### Manuell als verlassen markieren (reiches Modell)
```bash
rake scrape:mark_tournament_abandoned \
  CC_ID=123 \
  CONTEXT=nbv \
  REGION=NBV \
  SEASON=2023/2024 \
  TOURNAMENT="Turniername" \
  REASON="Manuelle Bereinigung" \
  REPLACED_BY_CC_ID=456
```

#### Eine cc_id als verlassen markieren (einfache Überspringliste)
```bash
rake scrape:mark_abandoned_simple CC_ID=123 CONTEXT=nbv
```

#### Alte Datensätze bereinigen
```bash
# Datensätze älter als 365 Tage bereinigen (Standard)
rake scrape:cleanup_abandoned_tournaments

# Datensätze älter als 180 Tage bereinigen
rake scrape:cleanup_abandoned_tournaments DAYS=180
```

## Implementierungsdetails

### Wo die Deduplizierung liegt

- **Einstieg (funktionierender Pfad):**
  `Season#scrape_single_tournaments_public_cc(opts)` iteriert über alle
  Regionen und ruft `Region#scrape_single_tournament_public(season, opts)` auf.
- **Dedup-Logik:** innerhalb von `Region#scrape_single_tournament_public`
  (`app/models/region.rb`, etwa Zeilen 505–545). Sie prüft die
  Überspringliste, sucht ein bestehendes `TournamentCc` mit gleichem Titel und
  anderer `cc_id`, verlässt die alte über `AbandonedTournamentCcSimple` und
  behält die aktuelle `cc_id`.

Es gibt **keine** Hilfsmethoden `process_single_tournament` oder
`process_duplicate_tournaments` — die Logik steht inline in
`scrape_single_tournament_public`.

## Erweiterte Funktionen

### Duplikat-Analyse

#### Automatische Erkennung
```ruby
# Duplikate für eine Region/Saison analysieren.
# Achtung: analyze_duplicates gibt einen menschenlesbaren STRING-Bericht
# zurück (kein Array von Datensätzen) und scrapet die Live-ClubCloud-Liste.
report = AbandonedTournamentCc.analyze_duplicates('NBV', '2023/2024')
puts report
```

#### Manuelle Überprüfung
```ruby
# Bestimmte cc_id als verlassen markieren
AbandonedTournamentCc.mark_abandoned!(
  cc_id: 123,
  context: 'nbv',
  region_shortname: 'NBV',
  season_name: '2023/2024',
  tournament_name: 'Beispielturnier',
  reason: 'Manuelle Bereinigung',
  replaced_by_cc_id: 456
)
```

### Bereinigungsstrategien

#### Zeitbasierte Bereinigung
```ruby
# Standard: 365 Tage
AbandonedTournamentCc.cleanup_old_records

# Benutzerdefiniert: 180 Tage (positionales Argument, kein Keyword)
AbandonedTournamentCc.cleanup_old_records(180)

# Sehr aggressiv: 90 Tage
AbandonedTournamentCc.cleanup_old_records(90)
```

#### Regionsbasierte Bereinigung
```ruby
# Nur bestimmte Region bereinigen
AbandonedTournamentCc.where(region_shortname: 'NBV').cleanup_old_records

# Mehrere Regionen bereinigen
regions = ['NBV', 'BBV', 'SBV']
AbandonedTournamentCc.where(region_shortname: regions).cleanup_old_records
```

## Monitoring und Berichterstattung

### Duplikat-Statistiken
```ruby
# Anzahl der Duplikate pro Region
AbandonedTournamentCc.group(:region_shortname).count

# Anzahl der Duplikate pro Saison
AbandonedTournamentCc.group(:season_name).count

# Häufigste Gründe für Verlassenheit
AbandonedTournamentCc.group(:reason).count
```

### Performance-Metriken
```ruby
# Durchschnittliche Verarbeitungszeit für Duplikate
start_time = Time.current
# Duplikat-Verarbeitung
end_time = Time.current
processing_time = end_time - start_time

puts "Duplikat-Verarbeitung dauerte: #{processing_time} Sekunden"
```

## Fehlerbehebung

### Häufige Probleme

#### 1. Duplikate werden nicht erkannt
- **Ursache**: Unterschiedliche Namensformatierung
- **Lösung**: Namensnormalisierung implementieren
- **Beispiel**: "Turnier 2024" vs "Turnier-2024"

#### 2. Falsche Auswahl bei Duplikaten
- **Ursache**: Unvollständige Datenanalyse
- **Lösung**: Zusätzliche Kriterien hinzufügen
- **Beispiel**: Berücksichtigung von Teilnehmerzahlen

#### 3. Performance-Probleme
- **Ursache**: Große Datenmengen
- **Lösung**: Batch-Verarbeitung implementieren
- **Beispiel**: Verarbeitung in Chunks von 1000

### Debugging

#### Logs aktivieren
```ruby
# Debug-Logging für Duplikat-Verarbeitung
Rails.logger.level = Logger::DEBUG

# Spezifische Logs für Duplikate
Rails.logger.debug "Verarbeite Duplikatgruppe: #{duplicate_group.inspect}"
```

#### Manuelle Überprüfung
```bash
# Duplikate für eine bestimmte Region/Saison analysieren (Live-ClubCloud-Liste)
rails console
report = AbandonedTournamentCc.analyze_duplicates('NBV', '2023/2024')
puts report
```

## Best Practices

### Für Entwickler

#### 1. Duplikat-Erkennung
- **Robuste Logik**: Implementieren Sie mehrere Erkennungskriterien
- **Fallback-Strategien**: Haben Sie Backup-Logik für Edge Cases
- **Performance**: Optimieren Sie für große Datenmengen

#### 2. Datenqualität
- **Validierung**: Überprüfen Sie alle Eingabedaten
- **Konsistenz**: Halten Sie Datenformate konsistent
- **Backup**: Sichern Sie Daten vor der Verarbeitung

#### 3. Monitoring
- **Logs**: Protokollieren Sie alle wichtigen Aktionen
- **Metriken**: Überwachen Sie Performance und Erfolgsraten
- **Alerts**: Benachrichtigen Sie bei Problemen

### Für Administratoren

#### 1. Regelmäßige Wartung
- **Tägliche Überprüfung**: Überprüfen Sie Scraping-Ergebnisse
- **Wöchentliche Bereinigung**: Führen Sie Bereinigungsaufgaben aus
- **Monatliche Analyse**: Analysieren Sie Trends und Probleme

#### 2. Datenbankpflege
- **Indizes**: Stellen Sie sicher, dass alle Abfragen indiziert sind
- **Partitionierung**: Erwägen Sie Partitionierung für große Tabellen
- **Archivierung**: Archivieren Sie alte verlassene Datensätze

#### 3. Benutzerkommunikation
- **Transparenz**: Informieren Sie Benutzer über Duplikat-Behandlung
- **Dokumentation**: Dokumentieren Sie alle Änderungen
- **Schulungen**: Schulen Sie Benutzer im Umgang mit Duplikaten

## Zukünftige Verbesserungen

### Geplante Features

#### 1. Intelligente Duplikat-Erkennung
- **Machine Learning**: Automatische Erkennung von Duplikaten
- **Fuzzy Matching**: Erkennung ähnlicher Namen
- **Kontextanalyse**: Berücksichtigung von Turnier-Kontext

#### 2. Erweiterte Bereinigungsstrategien
- **Automatische Bereinigung**: Intelligente Zeitplanung
- **Benutzerdefinierte Regeln**: Konfigurierbare Bereinigungsrichtlinien
- **Rollback-Funktionalität**: Wiederherstellung gelöschter Datensätze

#### 3. Verbessertes Monitoring
- **Dashboard**: Echtzeit-Überwachung der Duplikat-Behandlung
- **Berichte**: Detaillierte Analysen und Statistiken
- **Integration**: Anbindung an externe Monitoring-Tools

### Roadmap

#### Phase 1 (Q1 2025)
- Grundlegende Duplikat-Erkennung implementieren
- Basis-Bereinigungsfunktionen hinzufügen
- Einfaches Monitoring einrichten

#### Phase 2 (Q2 2025)
- Intelligente Auswahllogik verbessern
- Erweiterte Bereinigungsstrategien implementieren
- Dashboard für Administratoren entwickeln

#### Phase 3 (Q3 2025)
- Machine Learning Integration
- Vollautomatische Duplikat-Behandlung
- Erweiterte Berichterstattung 