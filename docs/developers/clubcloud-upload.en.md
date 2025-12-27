# ClubCloud Upload System

## Overview

The Carambus system offers two methods for transferring tournament results to ClubCloud:
1. **Automatic Single-Game Upload** (Default since 2024) - Each game is uploaded immediately after completion
2. **Manual CSV Batch Upload** (Fallback) - CSV file is generated at tournament end

## Automatic Single-Game Upload

### Activation

Automatic upload is controlled via a checkbox in the Tournament Monitor:

```ruby
# app/views/tournaments/tournament_monitor.html.erb
<%= check_box_tag :auto_upload_to_cc, "1", @tournament.auto_upload_to_cc?, 
    class: "border-2", 
    data: { reflex: "change->TournamentReflex#auto_upload_to_cc", id: @tournament.id } %>
```

**Default:** Enabled (`default: true`)

### Database Schema

```ruby
# Migration
add_column :tournaments, :auto_upload_to_cc, :boolean, default: true, null: false
```

### Upload Logic

The upload occurs in `lib/tournament_monitor_state.rb` after game completion:

```ruby
def finalize_game_result(table_monitor)
  # ... Save game data ...
  
  # Automatic transfer to ClubCloud
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

### Upload Method

The main upload logic is located in `app/models/setting.rb`:

```ruby
def self.upload_game_to_cc(table_monitor)
  # 1. Get game and tournament information
  game = table_monitor.game
  tournament = game.tournament
  tournament_cc = tournament.tournament_cc
  
  # 2. Check if game was already uploaded (Duplicate Prevention)
  return { success: true, skipped: true } if game.data["cc_uploaded_at"].present?
  
  # 3. Login to ClubCloud
  session_id = Setting.ensure_logged_in
  
  # 4. Map Carambus game name to ClubCloud format
  cc_group_name = map_game_gname_to_cc_group_name(game.gname)
  
  # 5. Find GroupItemId in ClubCloud
  group_item_id = find_group_item_id(tournament, cc_group_name)
  
  # 6. Create POST request to ClubCloud
  url = "#{region_cc.base_url}/admin/einzel/meisterschaft/createErgebnisSave.php"
  form_data = {
    "groupItemId" => group_item_id,
    "sportlerOneId" => player1.cc_id,
    "sportlerTwoId" => player2.cc_id,
    "resultOne" => ba_results["Ergebnis1"],
    "resultTwo" => ba_results["Ergebnis2"],
    # ... more fields ...
  }
  
  # 7. Send request and process response
  res = http.request(req)
  
  # 8. Mark game as uploaded
  game.data["cc_uploaded_at"] = Time.current.iso8601
  game.save!
  
  return { success: true, error: nil }
end
```

### Game Name Mapping

Carambus game names are converted to ClubCloud-compliant names:

```ruby
def self.map_game_gname_to_cc_group_name(gname)
  direct_mappings = {
    # Groups (numeric to alphabetic)
    /^group1[:\/]/i => "Gruppe A",
    /^group2[:\/]/i => "Gruppe B",
    /^group3[:\/]/i => "Gruppe C",
    /^group4[:\/]/i => "Gruppe D",
    
    # Finals
    /^hf1$/i => "Halbfinale",
    /^hf2$/i => "Halbfinale",
    /^fin$/i => "Finale",
    
    # Placement games
    /^p<3-4>$/i => "Spiel um Platz 3",
    /^p<5-6>$/i => "Spiel um Platz 5",
    # ... more mappings ...
  }
  
  # Check direct mappings
  direct_mappings.each do |pattern, cc_name|
    return cc_name if pattern.match?(gname)
  end
  
  # Fallback to generic group extraction
  if (m = gname.match(/group(\d+)/i))
    group_num = m[1].to_i
    return "Gruppe #{('A'..'Z').to_a[group_num - 1]}"
  end
  
  nil
end
```

### Error Handling

**Duplicate Prevention:**
```ruby
# Game is marked with timestamp
game.data["cc_upload_in_progress"] = Time.current.iso8601
game.save!

# After successful upload
game.data.delete("cc_upload_in_progress")
game.data["cc_uploaded_at"] = Time.current.iso8601
game.save!
```

**Error Logging:**
```ruby
# Errors are stored in tournament.data
tournament.data["cc_upload_errors"] ||= []
tournament.data["cc_upload_errors"] << {
  game_id: game.id,
  error: error_msg,
  timestamp: Time.current.iso8601
}
tournament.save!
```

**Retry Mechanism:**
- On error, `cc_upload_in_progress` is removed
- Next finalization attempt triggers new upload

### DRY RUN Mode

In the development environment, no actual upload is performed:

```ruby
if Rails.env.development?
  Rails.logger.info "[CC-Upload] 🧪 DRY RUN MODE"
  Rails.logger.info "[CC-Upload] Would upload game[#{game.id}]:"
  Rails.logger.info "[CC-Upload]   Group: #{game.gname} → #{cc_group_name}"
  # ... Log outputs ...
  return { success: true, dry_run: true }
end
```

## CSV Batch Upload

### Generation

The CSV file is generated at tournament end:

```ruby
# lib/tournament_monitor_support.rb
def write_finale_csv_for_upload
  game_data = []
  
  tournament.games.where("games.id >= #{Game::MIN_ID}").each do |game|
    # IMPORTANT: Use same mapping logic as single-game upload
    gruppe = Setting.map_game_gname_to_cc_group_name(game.gname)
    
    # Fallback to old logic
    unless gruppe.present?
      Rails.logger.warn "[CSV-Export] Could not map game.gname '#{game.gname}'"
      gruppe = "#{game.gname =~ /^group/ ? "Gruppe" : game.gname}"
    end
    
    partie = game.seqno
    gp1 = game.game_participations.where(role: "playera").first
    gp2 = game.game_participations.where(role: "playerb").first
    ended = game.ended_at
    
    next unless gp1.present? && gp2.present?
    
    # CSV format: GROUP;GAME;SET;PLAYER1;PLAYER2;POINTS1;POINTS2;...
    game_data << "#{gruppe};#{partie};;#{gp1.player.cc_id};#{gp2.player.cc_id};#{gp1.result};\
#{gp2.result};#{gp1.innings};#{gp2.innings};#{gp1.hs};#{gp2.hs};#{ended.strftime("%d.%m.%Y")};\
#{ended.strftime("%H:%M")}"
  end
  
  # Write CSV file
  f = File.new("#{Rails.root}/tmp/result-#{tournament.cc_id}.csv", "w")
  f.write(game_data.join("\n"))
  f.close
  
  # Send via email
  NotifierMailer.result(tournament, current_admin.email, 
                       "Tournament Results - #{tournament.title}",
                       "result-#{tournament.id}.csv",
                       "#{Rails.root}/tmp/result-#{tournament.id}.csv").deliver
end
```

### CSV Format

```
GROUP;GAME;SET;PLAYER1-ID;PLAYER2-ID;POINTS1;POINTS2;INNINGS1;INNINGS2;HS1;HS2;DATE;TIME
Gruppe A;1;;98765;95678;100;85;24;23;16;9;15.12.2024;14:30
Gruppe A;2;;12345;98765;120;95;25;24;18;12;15.12.2024;15:15
Halbfinale;1;;98765;54321;150;140;30;29;22;18;15.12.2024;16:00
Finale;1;;98765;12345;200;185;35;34;28;25;15.12.2024;17:00
```

### Consistency

**Important:** CSV and single-game upload use **identical** game name mapping:

```ruby
# BOTH use this method:
Setting.map_game_gname_to_cc_group_name(game.gname)
```

This guarantees:
- ✅ Consistent game names in both upload methods
- ✅ ClubCloud compatibility
- ✅ Correct alphabetic group names (A, B, C instead of 1, 2, 3)

## Prerequisites

### Tournament Configuration

```ruby
# A tournament requires:
tournament.tournament_cc.present?     # ClubCloud link
tournament.auto_upload_to_cc?         # Upload enabled (optional)

# TournamentCc contains:
tournament_cc.cc_id                   # ClubCloud tournament ID
tournament_cc.group_cc.data["positions"]  # Group mappings
```

### RegionCc Configuration

```ruby
# Region requires ClubCloud credentials:
region_cc.base_url                    # e.g. "https://ndbv.de"
region_cc.login_username              # Admin login
region_cc.login_password              # Admin password
```

### Player Identification

```ruby
# Players require ClubCloud ID:
player.cc_id || player.ba_id          # DBU number
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
  
  # Auto-upload is enabled
  assert tournament.auto_upload_to_cc?
  
  # Finalize game
  tournament.tournament_monitor.finalize_game_result(table_monitor)
  
  # Check upload status
  assert table_monitor.game.data["cc_uploaded_at"].present?
end
```

### Manual Testing (Development)

```bash
# Start Rails Console
rails console

# Enable DRY RUN
Rails.env = "development"

# Simulate upload
game = Game.last
table_monitor = game.table_monitor
result = Setting.upload_game_to_cc(table_monitor)

# Check log output
# => [CC-Upload] 🧪 DRY RUN MODE
# => [CC-Upload] Would upload game[123]:
# => [CC-Upload]   Group: group1 → Gruppe A
```

## Monitoring

### Log Outputs

**Successful Upload:**
```
[TournamentMonitorState] ✓ ClubCloud upload successful for game[123]
[CC-Upload] ✓ Successfully uploaded game[123] (Max Mustermann vs John Doe, group1) to ClubCloud
```

**Errors:**
```
[TournamentMonitorState] ✗ ClubCloud upload failed for game[123]: HTTP 500: Internal Server Error
[CC-Upload] Upload failed (HTTP 500: Internal Server Error) for game[123]
```

**Duplicate Prevention:**
```
[TournamentMonitorState] ⊘ ClubCloud upload skipped for game[123] (already uploaded)
```

### Error Tracking

```ruby
# Errors are stored in tournament:
tournament.data["cc_upload_errors"]
# => [
#   {
#     "game_id" => 123,
#     "error" => "Group 'group1' not found in ClubCloud",
#     "timestamp" => "2024-12-27T10:30:45Z"
#   }
# ]

# Display in Tournament Monitor
tournament.tournament_monitor.data["cc_upload_errors_count"] # => 1
```

## Best Practices

### For Developers

1. **Always use `map_game_gname_to_cc_group_name`** for game names
2. **Test with DRY RUN** before production deployment
3. **Log all errors** in `tournament.data["cc_upload_errors"]`
4. **Implement duplicate prevention** (check + timestamp)
5. **Use transactions** for atomic operations

### For Administrators

1. **Enable auto-upload** for standard tournaments
2. **Disable auto-upload** for offline tournaments
3. **Monitor error log** in Tournament Monitor
4. **Use CSV backup** for upload problems
5. **Check ClubCloud credentials** for login errors

## Troubleshooting

### Problem: "Group 'group1' not found in ClubCloud"

**Cause:** Group was not created in ClubCloud or has different name.

**Solution:**
```ruby
# Check available groups:
tournament.tournament_cc.group_cc.data["positions"]
# => { "Gruppe A" => 123, "Gruppe B" => 124 }

# Check mapping:
Setting.map_game_gname_to_cc_group_name("group1")
# => "Gruppe A"
```

### Problem: "Player not found"

**Cause:** Player has no `cc_id` or `ba_id`.

**Solution:**
```ruby
# Check player IDs:
player = game.game_participations.first.player
player.cc_id  # => nil
player.ba_id  # => 12345 (DBU number)

# Set cc_id:
player.update(cc_id: player.ba_id)
```

### Problem: "ClubCloud login failed"

**Cause:** Invalid or missing credentials.

**Solution:**
```ruby
# Check region credentials:
region_cc = tournament.organizer.region_cc
region_cc.login_username  # => "admin@example.com"
region_cc.login_password  # => "***"

# Test login:
session_id = Setting.ensure_logged_in
# => "abc123def456..." (Session ID)
```

## Performance

### Upload Speed

- **Single-Game Upload:** ~1-2 seconds per game
- **CSV Batch Upload:** Once at the end (~5-10 seconds)

### Optimization

```ruby
# Background job for upload (optional)
class ClubCloudUploadJob < ApplicationJob
  def perform(table_monitor_id)
    table_monitor = TableMonitor.find(table_monitor_id)
    Setting.upload_game_to_cc(table_monitor)
  end
end

# Call in finalize_game_result:
ClubCloudUploadJob.perform_later(table_monitor.id)
```

## See Also

- [Manager Documentation: ClubCloud Integration](../managers/clubcloud-integration.en.md)
- [Manager Documentation: Single Tournament Management](../managers/single-tournament.en.md)
- [API Reference](../reference/API.en.md)

