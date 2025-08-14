# Spielplan-Rekonstruktion

Dieses Dokument erklärt, wie Spielpläne aus bestehenden Daten rekonstruiert werden können, ohne neu zu scrapen.

## Übersicht

Nach dem Scrapen von Ligen mit `opts[:cleanup] == true` können die Spielpläne inkonsistent mit den neuen Daten werden. Diese Funktionalität ermöglicht es, Spielpläne aus den bestehenden parties und party_games Daten zu rekonstruieren, ohne ein vollständiges Neu-Scrapen durchzuführen.

## Hauptfunktionen

- **Effiziente Strukturanalyse**: Analysiert nur eine Partie pro Liga, um die Spielplanstruktur zu extrahieren (da sich die Struktur innerhalb einer Saison nicht ändert)
- **Geteilte Spielpläne**: Ligen mit derselben Region, Disziplin und demselben Namen, aber verschiedenen Saisons teilen sich denselben Spielplan
- **Umfassende Statistiken**: Analysiert alle Partien, um genaue Statistiken für Spielpunkte, Sätze, Bälle, Aufnahmen usw. zu erstellen

## Methoden

### Instanzmethode

```ruby
league.reconstruct_game_plan_from_existing_data
```

Rekonstruiert den Spielplan für eine einzelne Liga aus ihren bestehenden parties und party_games Daten.

### Klassenmethoden

```ruby
# Spielpläne für alle Ligen einer Saison rekonstruieren
League.reconstruct_game_plans_for_season(season, opts = {})

# Bestehende Spielpläne für eine Saison löschen
League.delete_game_plans_for_season(season, opts = {})

# Ligen finden, die denselben Spielplan teilen sollten
League.find_leagues_with_same_gameplan(league)

# Bestehenden geteilten Spielplan finden oder erstellen
League.find_or_create_shared_gameplan(league)
```

### Filteroptionen

Die Klassenmethoden unterstützen Filterung über den `opts` Parameter:

```ruby
# Nach Regions-Kurzname filtern
opts = { region_shortname: 'BBV' }

# Nach Disziplin filtern
opts = { discipline: 'Pool' }

# Nach beiden filtern
opts = { region_shortname: 'BBV', discipline: 'Pool' }

# Beispielverwendung
results = League.reconstruct_game_plans_for_season(season, opts)
```

## Rake-Tasks

### Spielpläne für eine Saison rekonstruieren

```bash
# Alle Spielpläne für eine Saison rekonstruieren
rake carambus:reconstruct_game_plans[2021/2022]

# Spielpläne für eine bestimmte Region rekonstruieren
rake carambus:reconstruct_game_plans[2021/2022,BBV]

# Spielpläne für eine bestimmte Disziplin rekonstruieren
rake carambus:reconstruct_game_plans[2021/2022,,Pool]

# Spielpläne für eine bestimmte Region und Disziplin rekonstruieren
rake carambus:reconstruct_game_plans[2021/2022,BBV,Pool]
```

### Spielplan für eine bestimmte Liga rekonstruieren

```bash
rake carambus:reconstruct_league_game_plan[123]
```

### Spielpläne für eine Saison löschen

```bash
# Alle Spielpläne für eine Saison löschen
rake carambus:delete_game_plans[2021/2022]

# Spielpläne für eine bestimmte Region löschen
rake carambus:delete_game_plans[2021/2022,BBV]

# Spielpläne für eine bestimmte Disziplin löschen
rake carambus:delete_game_plans[2021/2022,,Pool]

# Spielpläne für eine bestimmte Region und Disziplin löschen
rake carambus:delete_game_plans[2021/2022,BBV,Pool]
```

### Spielpläne für eine Saison bereinigen und rekonstruieren

```bash
# Alle Spielpläne für eine Saison bereinigen und rekonstruieren
rake carambus:clean_and_reconstruct_game_plans[2021/2022]

# Mit Filteroptionen
rake carambus:clean_and_reconstruct_game_plans[2021/2022,BBV,Pool]
```

## Verwendungsbeispiele

### Einzelne Liga

```ruby
# Liga finden
league = League.find(123)

# Spielplan rekonstruieren
league.reconstruct_game_plan_from_existing_data

# Status überprüfen
puts "Spielplan rekonstruiert: #{league.game_plan.present?}"
```

### Mehrere Ligen

```ruby
# Alle Ligen einer Saison
season = Season.find_by(name: '2021/2022')
results = League.reconstruct_game_plans_for_season(season)

puts "Rekonstruiert: #{results[:reconstructed]}"
puts "Fehler: #{results[:errors]}"
```

### Mit Filterung

```ruby
# Nur BBV Ligen
opts = { region_shortname: 'BBV' }
results = League.reconstruct_game_plans_for_season(season, opts)

# Nur Pool-Disziplin
opts = { discipline: 'Pool' }
results = League.reconstruct_game_plans_for_season(season, opts)
```

## Fehlerbehebung

### Häufige Probleme

1. **Fehlende Partien**: Wenn keine parties Daten vorhanden sind, kann der Spielplan nicht rekonstruiert werden
2. **Inkonsistente Daten**: Unterschiedliche Strukturen zwischen Partien können zu Problemen führen
3. **Fehlende Berechtigungen**: Stellen Sie sicher, dass der Benutzer die erforderlichen Berechtigungen hat

### Debugging

```ruby
# Debug-Informationen aktivieren
Rails.logger.level = Logger::DEBUG

# Spielplan-Rekonstruktion mit Logging
league.reconstruct_game_plan_from_existing_data

# Logs überprüfen
tail -f log/development.log
```

## Best Practices

### Vor der Rekonstruktion
- **Backup erstellen**: Sichern Sie alle wichtigen Daten
- **Datenqualität prüfen**: Stellen Sie sicher, dass die parties Daten konsistent sind
- **Berechtigungen überprüfen**: Vergewissern Sie sich, dass Sie die erforderlichen Rechte haben

### Nach der Rekonstruktion
- **Ergebnisse validieren**: Überprüfen Sie, ob alle Spielpläne korrekt erstellt wurden
- **Statistiken vergleichen**: Vergleichen Sie die Statistiken mit den ursprünglichen Daten
- **Fehler protokollieren**: Dokumentieren Sie alle aufgetretenen Probleme

### Performance-Optimierung
- **Batch-Verarbeitung**: Verwenden Sie die Klassenmethoden für große Datenmengen
- **Filterung**: Nutzen Sie Filteroptionen, um nur relevante Daten zu verarbeiten
- **Monitoring**: Überwachen Sie den Fortschritt bei langen Laufzeiten 