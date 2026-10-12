# ClubCloud Upload Feedback für Admins

## Überblick

ClubCloud-Upload-Fehler werden strukturiert in `tournament.data["cc_upload_errors"]` und im Log abgelegt.
**Eine Anzeige in der Carambus-Oberfläche gibt es noch nicht**: Wer die Fehler sehen will, liest sie in der
Rails-Konsole oder im Log (siehe unten).

## Features

### 1. Strukturierte Error-Tracking

Upload-Fehler werden in `tournament.data["cc_upload_errors"]` gespeichert:

```ruby
tournament.data["cc_upload_errors"] = {
  "game_id" => {
    "timestamp" => "2025-12-10T20:30:00Z",
    "game_gname" => "group1:1-2",
    "error" => "Gruppe 'group1:1-2' konnte nicht zu ClubCloud-Gruppenname gemappt werden"
  }
}
```

### 2. Konsistente Log-Prefixes

Alle ClubCloud-relevanten Logs haben das Prefix `[CC-Upload]`:

```
[CC-Upload] ✓ Successfully uploaded game[123] (Spieler1 vs Spieler2, group1:1-2)
[CC-Upload] Upload fehlgeschlagen (HTTP 500: Internal Server Error) for game[124]
[CC-Upload] Gruppe 'group1:1-2' konnte nicht zu ClubCloud-Gruppenname gemappt werden for game[125]
```

Eine Zeile `✗ … upload failed` gibt es auch, aber mit anderem Präfix: `[TournamentMonitorState]` bzw.
`[TournamentMonitorsController#update_games]`.

**Logs filtern:**
```bash
# Development (nur Probelauf: im Log steht "DRY RUN MODE", es wird nichts an die ClubCloud gesendet,
# das Spiel gilt trotzdem als hochgeladen)
tail -f log/development.log | grep "\[CC-Upload\]"

# Production
tail -f log/production.log | grep "\[CC-Upload\]"

# Nur Fehler
tail -f log/production.log | grep -E "\[CC-Upload\].*(fehlgeschlagen|Exception|nicht)|upload failed"
```

### 3. Benutzerfreundliche Fehlermeldungen

Klare, deutsche Fehlermeldungen für häufige Probleme:

| Fehler | Bedeutung | Lösung |
|--------|-----------|--------|
| `Gruppe '…' konnte nicht zu ClubCloud-Gruppenname gemappt werden` | Name-Mapping fehlt | Turniervorbereitung erneut durchführen oder Mapping prüfen |
| `Gruppe '…' (gemappt zu '…') wurde nicht in ClubCloud-Turnier gefunden (auch nach Re-Scraping)` | Gruppe fehlt im CC-Turnier | Gruppen im ClubCloud-Turnier prüfen |
| `Spieler X nicht in ClubCloud registriert` | Spieler hat keine cc_id/ba_id | Spieler in ClubCloud-Teilnehmerliste eintragen |
| `ClubCloud login failed` | Login-Probleme | Credentials prüfen (siehe [clubcloud_credentials.md](clubcloud_credentials.md)) |
| `Upload fehlgeschlagen (HTTP 404)` | ClubCloud-URL falsch | `region_cc.base_url` prüfen |

### 4. Automatisches Cleanup

- **Erfolgreicher Upload**: Fehler wird automatisch aus `cc_upload_errors` gelöscht
- **Erneuter Fehler**: Überschreibt alten Fehler-Eintrag mit neuem Timestamp

## Admin-UI Integration

Eine Anzeige der Upload-Fehler in der Oberfläche (Turnierseite, Turnier-Monitor) ist **nicht umgesetzt**. Frühere
Fassungen dieser Seite enthielten dafür ERB-Beispiele zum Einfügen; sie nutzten Bootstrap-Klassen und einen nicht
existierenden Helper und sind entfernt. Eine Umsetzung folgt den [UI-Konventionen](../ui-conventions.md)
(Tailwind-Token, kein hartkodiertes Farbschema).

## API / Console-Zugriff

### Fehler auslesen

```ruby
tournament = Tournament.find(123)
cc_errors = tournament.data["cc_upload_errors"] || {}

# Alle Fehler anzeigen
cc_errors.each do |game_id, error_data|
  puts "Game #{game_id} (#{error_data['game_gname']}): #{error_data['error']}"
end

# Fehler-Anzahl
puts "#{cc_errors.size} Upload-Fehler"
```

### Fehler manuell löschen

```ruby
# Einen spezifischen Fehler löschen
tournament.unprotected = true
tournament.data["cc_upload_errors"].delete("game_id")
tournament.data_will_change!
tournament.save!

# Alle Fehler löschen
tournament.unprotected = true
tournament.data["cc_upload_errors"] = {}
tournament.data_will_change!
tournament.save!
```

### Manueller Retry

```ruby
game = Game.find(123)
table_monitor = TableMonitor.find_by(game_id: game.id)

result = Setting.upload_game_to_cc(table_monitor)
if result[:success]
  puts "✓ Upload erfolgreich"
else
  puts "✗ Upload fehlgeschlagen: #{result[:error]}"
end
```

## Monitoring

### Fehler-Rate überwachen

```ruby
# Alle Turniere mit Upload-Fehlern
# tournaments.data ist eine text-Spalte (serialisiertes JSON); der jsonb-Operator -> funktioniert dort nicht
tournaments_with_errors = Tournament.where("data LIKE ?", "%cc_upload_errors%")
                                    .select { |t| t.data["cc_upload_errors"].present? }

# Statistik
tournaments_with_errors.each do |t|
  error_count = t.data["cc_upload_errors"]&.size || 0
  puts "Tournament #{t.id} (#{t.title}): #{error_count} Fehler"
end
```

### Häufigste Fehler

```ruby
error_types = Hash.new(0)

Tournament.all.each do |t|
  (t.data["cc_upload_errors"] || {}).each do |_, error_data|
    error_msg = error_data["error"]
    # Gruppiere nach Fehler-Typ
    case error_msg
    when /gemappt werden|nicht in ClubCloud-Turnier gefunden/
      error_types["Gruppe nicht zugeordnet"] += 1
    when /nicht in ClubCloud registriert/
      error_types["Spieler nicht registriert"] += 1
    when /login failed/
      error_types["Login-Fehler"] += 1
    else
      error_types["Sonstige"] += 1
    end
  end
end

error_types.sort_by { |_, count| -count }.each do |type, count|
  puts "#{type}: #{count}"
end
```

## Troubleshooting

### Problem: Fehler bleiben nach Upload stehen

**Ursache**: Cleanup-Mechanismus funktioniert nicht.

**Lösung**:
```ruby
# Manuell aufräumen
tournament = Tournament.find(123)
Setting.clear_cc_upload_error(tournament, game)
```

### Problem: Zu viele Fehler in tournament.data

**Ursache**: Viele fehlgeschlagene Uploads akkumulieren.

**Lösung**: Automatisches Cleanup nach X Tagen implementieren oder manuell alte Fehler löschen:

```ruby
# Fehler älter als 7 Tage löschen
cutoff = 7.days.ago

tournament.data["cc_upload_errors"].delete_if do |_, error_data|
  timestamp = Time.parse(error_data["timestamp"])
  timestamp < cutoff
end
tournament.data_will_change!
tournament.save!
```

## Siehe auch

- [ClubCloud Credentials Setup](clubcloud_credentials.md)
- ClubCloud Name Mapping (Skript: bin/test-cc-name-mapping.rb)
- Log Prefixes Reference

