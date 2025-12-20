# ClubCloud Upload Feedback für Admins

## Überblick

ClubCloud-Upload-Fehler werden automatisch für den Admin sichtbar gemacht, ohne dass in den Logs gesucht werden muss.

## Features

### 1. Strukturierte Error-Tracking

Upload-Fehler werden in `tournament.data["cc_upload_errors"]` gespeichert:

```ruby
tournament.data["cc_upload_errors"] = {
  "game_id" => {
    "timestamp" => "2025-12-10T20:30:00Z",
    "game_gname" => "group1:1-2",
    "error" => "Gruppe 'group1:1-2' konnte nicht zugeordnet werden"
  }
}
```

### 2. Konsistente Log-Prefixes

Alle ClubCloud-relevanten Logs haben das Prefix `[CC-Upload]`:

```
[CC-Upload] ✓ Successfully uploaded game[123] (Spieler1 vs Spieler2, group1:1-2)
[CC-Upload] ✗ Upload failed for game[124]: Gruppe konnte nicht zugeordnet werden
[CC-Upload] Exception: Connection timeout for game[125]
```

**Logs filtern:**
```bash
# Development
tail -f log/development.log | grep "\[CC-Upload\]"

# Production
tail -f log/production.log | grep "\[CC-Upload\]"

# Nur Fehler
tail -f log/production.log | grep "\[CC-Upload\].*✗\|Exception\|failed"
```

### 3. Benutzerfreundliche Fehlermeldungen

Klare, deutsche Fehlermeldungen für häufige Probleme:

| Fehler | Bedeutung | Lösung |
|--------|-----------|--------|
| `Gruppe 'group1:1-2' konnte nicht zugeordnet werden` | Name-Mapping fehlt | Turniervorbereitung erneut durchführen oder Mapping prüfen |
| `Spieler X nicht in ClubCloud registriert` | Spieler hat keine cc_id/ba_id | Spieler in ClubCloud-Teilnehmerliste eintragen |
| `ClubCloud login failed` | Login-Probleme | Credentials prüfen (siehe `docs/clubcloud_credentials.md`) |
| `Upload fehlgeschlagen (HTTP 404)` | ClubCloud-URL falsch | `region_cc.base_url` prüfen |

### 4. Automatisches Cleanup

- **Erfolgreicher Upload**: Fehler wird automatisch aus `cc_upload_errors` gelöscht
- **Erneuter Fehler**: Überschreibt alten Fehler-Eintrag mit neuem Timestamp

## Admin-UI Integration

### Tournament Show Page

Füge folgendes zu `app/views/tournaments/show.html.erb` hinzu:

```erb
<% if @tournament.data["cc_upload_errors"].present? %>
  <div class="alert alert-warning">
    <h4>⚠️ ClubCloud Upload-Fehler</h4>
    <p>Einige Spiele konnten nicht zu ClubCloud übertragen werden:</p>
    <ul>
      <% @tournament.data["cc_upload_errors"].each do |game_id, error_data| %>
        <li>
          <strong>Spiel <%= error_data["game_gname"] %></strong>
          (Game ID: <%= game_id %>)
          <br>
          <span class="text-danger"><%= error_data["error"] %></span>
          <br>
          <small class="text-muted">
            <%= Time.parse(error_data["timestamp"]).strftime("%d.%m.%Y %H:%M:%S") %>
          </small>
        </li>
      <% end %>
    </ul>
    <p class="mb-0">
      <small>
        Fehler werden automatisch entfernt, wenn der Upload erfolgreich ist.
        Bei Fragen siehe <a href="<%= docs_path('clubcloud_upload_feedback') %>">Dokumentation</a>.
      </small>
    </p>
  </div>
<% end %>
```

### Tournament Monitor Dashboard

Für Live-Feedback während des Turniers:

```erb
<% cc_errors_count = @tournament.data["cc_upload_errors"]&.size || 0 %>
<% if cc_errors_count > 0 %>
  <div class="alert alert-warning alert-dismissible fade show" role="alert">
    <strong>ClubCloud-Status:</strong>
    <%= cc_errors_count %> Spiel<%= "e" if cc_errors_count > 1 %> konnten nicht übertragen werden.
    <a href="<%= tournament_path(@tournament) %>#cc-errors">Details ansehen</a>
    <button type="button" class="close" data-dismiss="alert" aria-label="Close">
      <span aria-hidden="true">&times;</span>
    </button>
  </div>
<% end %>
```

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
tournaments_with_errors = Tournament.where("data->'cc_upload_errors' IS NOT NULL")

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
    when /konnte nicht zugeordnet/
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
- [ClubCloud Name Mapping](../bin/test-cc-name-mapping.rb)
- [Log Prefixes Reference](logging_conventions.md)

