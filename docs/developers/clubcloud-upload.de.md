# ClubCloud Upload-System

## Übersicht

Das Carambus-System bietet zwei Methoden zur Übertragung von Turnierergebnissen in die ClubCloud:
1. **Automatischer Einzel-Upload** (Standard seit 2024) - Jedes Spiel wird sofort nach Abschluss hochgeladen
2. **Manueller CSV-Batch-Upload** (Fallback) - CSV-Datei wird am Ende des Turniers generiert

## Automatischer Einzel-Upload

### Aktivierung

Der automatische Upload wird über eine Checkbox im Tournament-Monitor gesteuert:

```ruby
# app/views/tournaments/tournament_monitor.html.erb
<%= check_box_tag :auto_upload_to_cc, "1", @tournament.auto_upload_to_cc?, 
    class: "border-2", 
    data: { reflex: "change->TournamentReflex#auto_upload_to_cc", id: @tournament.id } %>
```

**Standard:** Aktiviert (`default: true`)

### Datenbank-Schema

```ruby
# Migration
add_column :tournaments, :auto_upload_to_cc, :boolean, default: true, null: false
```

### Upload-Logik

Der Upload erfolgt in `lib/tournament_monitor_state.rb` nach Spielabschluss:

```ruby
def finalize_game_result(table_monitor)
  # ... Spiel-Daten speichern ...
  
  # Automatische Übertragung in die ClubCloud
  if tournament.tournament_cc.present? && tournament.auto_upload_to_cc?
    Rails.logger.info "[TournamentMonitorState] Attempting ClubCloud upload for game[#{game.id}]..."
    result = Setting.upload_game_to_cc(table_monitor)
    
    if result[:success]
      if result[:dry_run]
        Rails.logger.info "[TournamentMonitorState] 🧪 ClubCloud upload DRY RUN completed"
      elsif result[:skipped]
        Rails.logger.info "[TournamentMonitorState] ⊘ ClubCloud upload skipped (already uploaded)"
      else
        Rails.logger.info "[TournamentMonitorState] ✓ ClubCloud upload successful"
      end
    else
      Rails.logger.warn "[TournamentMonitorState] ✗ ClubCloud upload failed: #{result[:error]}"
    end
  end
end
```

### Upload-Methode

Die Haupt-Upload-Logik befindet sich in `app/models/setting.rb`:

```ruby
def self.upload_game_to_cc(table_monitor)
  # 1. Hole Spiel und Turnier-Informationen
  game = table_monitor.game
  tournament = game.tournament
  tournament_cc = tournament.tournament_cc
  
  # 2. Prüfe ob Spiel bereits hochgeladen wurde (Duplicate Prevention)
  return { success: true, skipped: true } if game.data["cc_uploaded_at"].present?
  
  # 3. Login in ClubCloud
  session_id = Setting.ensure_logged_in
  
  # 4. Mappe Carambus-Spielname zu ClubCloud-Format
  cc_group_name = map_game_gname_to_cc_group_name(game.gname)
  
  # 5. Finde GroupItemId in ClubCloud
  group_item_id = find_group_item_id(tournament, cc_group_name)
  
  # 6. Erstelle POST-Request an ClubCloud
  url = "#{region_cc.base_url}/admin/einzel/meisterschaft/createErgebnisSave.php"
  form_data = {
    "groupItemId" => group_item_id,
    "sportlerOneId" => player1.cc_id,
    "sportlerTwoId" => player2.cc_id,
    "resultOne" => ba_results["Ergebnis1"],
    "resultTwo" => ba_results["Ergebnis2"],
    # ... weitere Felder ...
  }
  
  # 7. Sende Request und verarbeite Antwort
  res = http.request(req)
  
  # 8. Markiere Spiel als hochgeladen
  game.data["cc_uploaded_at"] = Time.current.iso8601
  game.save!
  
  return { success: true, error: nil }
end
```

### Spielnamen-Mapping

Carambus-Spielnamen werden zu ClubCloud-konformen Namen konvertiert:

```ruby
def self.map_game_gname_to_cc_group_name(gname)
  direct_mappings = {
    # Gruppen (numerisch zu alphabetisch)
    /^group1[:\/]/i => "Gruppe A",
    /^group2[:\/]/i => "Gruppe B",
    /^group3[:\/]/i => "Gruppe C",
    /^group4[:\/]/i => "Gruppe D",
    
    # Finalrunden
    /^hf1$/i => "Halbfinale",
    /^hf2$/i => "Halbfinale",
    /^fin$/i => "Finale",
    
    # Platzierungsspiele
    /^p<3-4>$/i => "Spiel um Platz 3",
    /^p<5-6>$/i => "Spiel um Platz 5",
    # ... weitere Mappings ...
  }
  
  # Prüfe direkte Mappings
  direct_mappings.each do |pattern, cc_name|
    return cc_name if pattern.match?(gname)
  end
  
  # Fallback auf generische Gruppen-Extraktion
  if (m = gname.match(/group(\d+)/i))
    group_num = m[1].to_i
    return "Gruppe #{('A'..'Z').to_a[group_num - 1]}"
  end
  
  nil
end
```

### Fehlerbehandlung

**Duplicate Prevention:**
```ruby
# Spiel wird mit Timestamp markiert
game.data["cc_upload_in_progress"] = Time.current.iso8601
game.save!

# Nach erfolgreichem Upload
game.data.delete("cc_upload_in_progress")
game.data["cc_uploaded_at"] = Time.current.iso8601
game.save!
```

**Error Logging:**
```ruby
# Fehler werden im tournament.data gespeichert
tournament.data["cc_upload_errors"] ||= []
tournament.data["cc_upload_errors"] << {
  game_id: game.id,
  error: error_msg,
  timestamp: Time.current.iso8601
}
tournament.save!
```

**Retry-Mechanismus:**
- Bei Fehler wird `cc_upload_in_progress` entfernt
- Nächster Finalisierungsversuch löst erneuten Upload aus

### DRY RUN Mode

Im Development-Environment wird kein echter Upload durchgeführt:

```ruby
if Rails.env.development?
  Rails.logger.info "[CC-Upload] 🧪 DRY RUN MODE"
  Rails.logger.info "[CC-Upload] Would upload game[#{game.id}]:"
  Rails.logger.info "[CC-Upload]   Group: #{game.gname} → #{cc_group_name}"
  # ... Log-Ausgaben ...
  return { success: true, dry_run: true }
end
```

## CSV-Batch-Upload

### Generierung

Die CSV-Datei wird am Turnier-Ende generiert:

```ruby
# lib/tournament_monitor_support.rb
def write_finale_csv_for_upload
  game_data = []
  
  tournament.games.where("games.id >= #{Game::MIN_ID}").each do |game|
    # WICHTIG: Verwende gleiche Mapping-Logik wie Single-Game-Upload
    gruppe = Setting.map_game_gname_to_cc_group_name(game.gname)
    
    # Fallback auf alte Logik
    unless gruppe.present?
      Rails.logger.warn "[CSV-Export] Could not map game.gname '#{game.gname}'"
      gruppe = "#{game.gname =~ /^group/ ? "Gruppe" : game.gname}"
    end
    
    partie = game.seqno
    gp1 = game.game_participations.where(role: "playera").first
    gp2 = game.game_participations.where(role: "playerb").first
    ended = game.ended_at
    
    next unless gp1.present? && gp2.present?
    
    # CSV-Format: GRUPPE;PARTIE;SATZ-NR;SPIELER1;SPIELER2;PUNKTE1;PUNKTE2;...
    game_data << "#{gruppe};#{partie};;#{gp1.player.cc_id};#{gp2.player.cc_id};#{gp1.result};\
#{gp2.result};#{gp1.innings};#{gp2.innings};#{gp1.hs};#{gp2.hs};#{ended.strftime("%d.%m.%Y")};\
#{ended.strftime("%H:%M")}"
  end
  
  # Schreibe CSV-Datei
  f = File.new("#{Rails.root}/tmp/result-#{tournament.cc_id}.csv", "w")
  f.write(game_data.join("\n"))
  f.close
  
  # Versende per E-Mail
  NotifierMailer.result(tournament, current_admin.email, 
                       "Turnierergebnisse - #{tournament.title}",
                       "result-#{tournament.id}.csv",
                       "#{Rails.root}/tmp/result-#{tournament.id}.csv").deliver
end
```

### CSV-Format

```
GRUPPE;PARTIE;SATZ-NR;SPIELER1-ID;SPIELER2-ID;PUNKTE1;PUNKTE2;AUFNAHMEN1;AUFNAHMEN2;HS1;HS2;DATUM;UHRZEIT
Gruppe A;1;;98765;95678;100;85;24;23;16;9;15.12.2024;14:30
Gruppe A;2;;12345;98765;120;95;25;24;18;12;15.12.2024;15:15
Halbfinale;1;;98765;54321;150;140;30;29;22;18;15.12.2024;16:00
Finale;1;;98765;12345;200;185;35;34;28;25;15.12.2024;17:00
```

### Konsistenz

**Wichtig:** CSV und Single-Game-Upload verwenden **identische** Spielnamen-Mapping:

```ruby
# BEIDE verwenden diese Methode:
Setting.map_game_gname_to_cc_group_name(game.gname)
```

Dies garantiert:
- ✅ Konsistente Spielnamen in beiden Upload-Methoden
- ✅ ClubCloud-Kompatibilität
- ✅ Korrekte Alphabetische Gruppennamen (A, B, C statt 1, 2, 3)

## Voraussetzungen

### Tournament-Konfiguration

```ruby
# Ein Tournament benötigt:
tournament.tournament_cc.present?     # ClubCloud-Verknüpfung
tournament.auto_upload_to_cc?         # Upload aktiviert (optional)

# TournamentCc enthält:
tournament_cc.cc_id                   # ClubCloud-Turnier-ID
tournament_cc.group_cc.data["positions"]  # Gruppen-Mappings
```

### RegionCc-Konfiguration

```ruby
# Region benötigt ClubCloud-Credentials:
region_cc.base_url                    # z.B. "https://ndbv.de"
region_cc.login_username              # Admin-Login
region_cc.login_password              # Admin-Passwort
```

### Spieler-Identifikation

```ruby
# Spieler benötigen ClubCloud-ID:
player.cc_id || player.ba_id          # DBU-Nummer
```

## Testing

### Unit Tests

```ruby
# test/models/setting_test.rb
test "map_game_gname_to_cc_group_name converts group1 to Gruppe A" do
  assert_equal "Gruppe A", Setting.map_game_gname_to_cc_group_name("group1")
  assert_equal "Gruppe A", Setting.map_game_gname_to_cc_group_name("Gruppe 1")
end

test "map_game_gname_to_cc_group_name converts finals" do
  assert_equal "Finale", Setting.map_game_gname_to_cc_group_name("fin")
  assert_equal "Halbfinale", Setting.map_game_gname_to_cc_group_name("hf1")
end
```

### Integration Tests

```ruby
# test/integration/tournament_upload_test.rb
test "automatic upload after game finalization" do
  tournament = create_tournament_with_cc
  table_monitor = create_finished_game
  
  # Auto-Upload ist aktiviert
  assert tournament.auto_upload_to_cc?
  
  # Finalisiere Spiel
  tournament.tournament_monitor.finalize_game_result(table_monitor)
  
  # Prüfe Upload-Status
  assert table_monitor.game.data["cc_uploaded_at"].present?
end
```

### Manual Testing (Development)

```bash
# Start Rails Console
rails console

# Aktiviere DRY RUN
Rails.env = "development"

# Simuliere Upload
game = Game.last
table_monitor = game.table_monitor
result = Setting.upload_game_to_cc(table_monitor)

# Prüfe Log-Output
# => [CC-Upload] 🧪 DRY RUN MODE
# => [CC-Upload] Would upload game[123]:
# => [CC-Upload]   Group: group1 → Gruppe A
```

## Monitoring

### Log-Ausgaben

**Erfolgreicher Upload:**
```
[TournamentMonitorState] ✓ ClubCloud upload successful for game[123]
[CC-Upload] ✓ Successfully uploaded game[123] (Max Mustermann vs John Doe, group1) to ClubCloud
```

**Fehler:**
```
[TournamentMonitorState] ✗ ClubCloud upload failed for game[123]: HTTP 500: Internal Server Error
[CC-Upload] Upload fehlgeschlagen (HTTP 500: Internal Server Error) for game[123]
```

**Duplicate Prevention:**
```
[TournamentMonitorState] ⊘ ClubCloud upload skipped for game[123] (already uploaded)
```

### Error Tracking

```ruby
# Fehler werden im Tournament gespeichert:
tournament.data["cc_upload_errors"]
# => [
#   {
#     "game_id" => 123,
#     "error" => "Group 'group1' not found in ClubCloud",
#     "timestamp" => "2024-12-27T10:30:45Z"
#   }
# ]

# Anzeige im Tournament Monitor
tournament.tournament_monitor.data["cc_upload_errors_count"] # => 1
```

## Best Practices

### Für Entwickler

1. **Verwende immer `map_game_gname_to_cc_group_name`** für Spielnamen
2. **Teste mit DRY RUN** vor Production-Deployment
3. **Logge alle Fehler** in `tournament.data["cc_upload_errors"]`
4. **Implementiere Duplicate Prevention** (Check + Timestamp)
5. **Verwende Transactions** für atomare Operationen

### Für Administratoren

1. **Aktiviere Auto-Upload** für Standard-Turniere
2. **Deaktiviere Auto-Upload** für Offline-Turniere
3. **Überwache Error-Log** im Tournament Monitor
4. **Nutze CSV-Backup** bei Upload-Problemen
5. **Prüfe ClubCloud-Credentials** bei Login-Fehlern

## Troubleshooting

### Problem: "Group 'group1' not found in ClubCloud"

**Ursache:** Gruppe wurde in ClubCloud nicht erstellt oder hat anderen Namen.

**Lösung:**
```ruby
# Prüfe verfügbare Gruppen:
tournament.tournament_cc.group_cc.data["positions"]
# => { "Gruppe A" => 123, "Gruppe B" => 124 }

# Prüfe Mapping:
Setting.map_game_gname_to_cc_group_name("group1")
# => "Gruppe A"
```

### Problem: "Player not found"

**Ursache:** Spieler hat keine `cc_id` oder `ba_id`.

**Lösung:**
```ruby
# Prüfe Spieler-IDs:
player = game.game_participations.first.player
player.cc_id  # => nil
player.ba_id  # => 12345 (DBU-Nummer)

# Setze cc_id:
player.update(cc_id: player.ba_id)
```

### Problem: "ClubCloud login failed"

**Ursache:** Ungültige oder fehlende Credentials.

**Lösung:**
```ruby
# Prüfe Region-Credentials:
region_cc = tournament.organizer.region_cc
region_cc.login_username  # => "admin@example.com"
region_cc.login_password  # => "***"

# Teste Login:
session_id = Setting.ensure_logged_in
# => "abc123def456..." (Session-ID)
```

## Performance

### Upload-Geschwindigkeit

- **Single-Game-Upload:** ~1-2 Sekunden pro Spiel
- **CSV-Batch-Upload:** Einmalig am Ende (~5-10 Sekunden)

### Optimierung

```ruby
# Background Job für Upload (optional)
class ClubCloudUploadJob < ApplicationJob
  def perform(table_monitor_id)
    table_monitor = TableMonitor.find(table_monitor_id)
    Setting.upload_game_to_cc(table_monitor)
  end
end

# Aufruf in finalize_game_result:
ClubCloudUploadJob.perform_later(table_monitor.id)
```

## Siehe auch

- [Manager-Dokumentation: ClubCloud Integration](../managers/clubcloud-integration.de.md)
- [Manager-Dokumentation: Einzelturnier-Verwaltung](../managers/single-tournament.de.md)
- [API-Referenz](../reference/API.de.md)


