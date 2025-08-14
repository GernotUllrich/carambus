# Turnier-Duplikat-Behandlungssystem

## Übersicht

Dieses System befasst sich mit dem Problem von doppelten Turnieren mit unterschiedlichen `cc_id` Werten während des Scrapings. Wenn die Quelle mehrere Turniere mit demselben Namen, Datum und derselben Disziplin, aber unterschiedlichen `cc_id` Werten enthält, erkennt und behandelt dieses System sie automatisch, um das Hin- und Herwechseln zwischen verschiedenen Versionen zu verhindern.

## Wie es funktioniert

### 1. Duplikat-Erkennung
- Während des Scrapings werden Turniere nach Namen gruppiert
- Wenn mehrere Turniere denselben Namen haben, werden sie als Duplikate identifiziert
- Das System analysiert jedes Duplikat, um zu bestimmen, welches behalten werden soll

### 2. Auswahllogik
Das System priorisiert Turniere in dieser Reihenfolge:
1. **Hat Spiele** - Dies ist die definitive Version, das Turnier ist aktiv und wird verwendet
2. **Hat Setzlisten** - Turniermanager haben begonnen, an dieser Version zu arbeiten (Vor-Turnier-Setup)
3. **Keine Setzlisten und keine Spiele** - Saubere Turniere (niedrigste Priorität)
4. **Höchste cc_id** - Wenn alle denselben Datenstatus haben, ist die höchste cc_id normalerweise die richtige

### 3. Verlassenheits-Verfolgung
- Verlassene `cc_id` Werte werden in der `abandoned_tournament_ccs` Tabelle gespeichert
- Zukünftige Scraping-Läufe überspringen diese verlassenen `cc_id` Werte
- Dies verhindert das Hin- und Herwechseln, das Sie erlebt haben

## Datenbankschema

### AbandonedTournamentCc Modell
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

## Verwendung

### Automatische Behandlung
Das System funktioniert automatisch, wenn Sie ausführen:
```bash
rake scrape:tournaments_optimized
```

### Manuelle Verwaltung

#### Duplikate analysieren
```bash
rake scrape:analyze_duplicates REGION=NBV SEASON=2023/2024
```

#### Verlassene Turniere auflisten
```bash
rake scrape:list_abandoned_tournaments REGION=NBV SEASON=2023/2024
```

#### Manuell als verlassen markieren
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

#### Alte Datensätze bereinigen
```bash
# Datensätze älter als 365 Tage bereinigen (Standard)
rake scrape:cleanup_abandoned_tournaments

# Datensätze älter als 180 Tage bereinigen
rake scrape:cleanup_abandoned_tournaments DAYS=180
```

## Implementierungsdetails

### Modifizierte Methoden

#### Region#scrape_tournaments_optimized
- Gruppiert jetzt Turniere nach Namen vor der Verarbeitung
- Erkennt Duplikate und wendet Auswahllogik an
- Markiert verlassene cc_ids für zukünftige Läufe

#### Neue private Methoden
- `process_single_tournament`: Behandelt einzelne Turniere
- `process_duplicate_tournaments`: Behandelt Duplikatgruppen

### AbandonedTournamentCc Modell
- `is_abandoned?`: Überprüft, ob eine cc_id verlassen ist
- `mark_abandoned!`: Markiert eine cc_id als verlassen
- `analyze_duplicates`: Analysiert Duplikate für eine Region/Saison
- `cleanup_old_records`: Entfernt alte verlassene Datensätze

## Erweiterte Funktionen

### Duplikat-Analyse

#### Automatische Erkennung
```ruby
# Duplikate für eine Region/Saison analysieren
duplicates = AbandonedTournamentCc.analyze_duplicates('NBV', '2023/2024')

duplicates.each do |duplicate|
  puts "Turnier: #{duplicate.tournament_name}"
  puts "Verlassene cc_id: #{duplicate.cc_id}"
  puts "Ersetzt durch: #{duplicate.replaced_by_cc_id}"
  puts "Grund: #{duplicate.reason}"
end
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

# Benutzerdefiniert: 180 Tage
AbandonedTournamentCc.cleanup_old_records(days: 180)

# Sehr aggressiv: 90 Tage
AbandonedTournamentCc.cleanup_old_records(days: 90)
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
# Duplikate für eine bestimmte Region analysieren
rails console
region = Region.find_by(shortname: 'NBV')
duplicates = region.analyze_tournament_duplicates('2023/2024')
puts duplicates.inspect
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