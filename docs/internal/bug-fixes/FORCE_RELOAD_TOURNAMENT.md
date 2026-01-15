# Force Reload Tournament from API Server

## Overview

This feature allows system administrators to force a complete reload of tournament data (including results) from the API server, even for closed tournaments that already have ClubCloud results.

## Use Case

When a tournament has been completed and closed on the API server (api.carambus.de), but the local development or location server is out of sync, a sysadmin can force a complete reload without needing to use the Rails console.

## How to Use

### Via Web Interface (Preferred)

1. Navigate to the tournament show page (e.g., `/tournaments/17385`)
2. Scroll down to the "Admin Actions" section at the bottom
3. Look for the button labeled **"Sysadmin: Force Reload Tournament from API Server"** (German: "Sysadmin: Turnier vom API-Server neu laden")
4. Click the button
5. Confirm the action in the dialog box

**Important:** This button is only visible to users with privileged access:
- System administrators (`system_admin?` role)
- Users in the `PRIVILEGED` list in `app/models/user.rb`

### Via Rails Console (Alternative)

If you prefer to use the Rails console:

```ruby
# For a specific tournament (e.g., tournament ID 17385)
Version.update_from_carambus_api(update_tournament_from_cc: 17385, reload_games: true)
```

## What Happens

When you force reload a tournament with `reload_games: true`:

1. **Local Server Side:**
   - The tournament is completely reset (`@tournament.reset_tournament`)
   - All local tournament data is cleared
   - The system calls the API server to get fresh data

2. **API Server Side:**
   - Scrapes the tournament from ClubCloud (`scrape_single_tournament_public(reload_game_results: true)`)
   - Fetches all tournament details, seedings, games, and results
   - Creates version records for all changes

3. **Synchronization:**
   - The local server receives the version records from the API server
   - All tournament data (seedings, games, results, rankings) is recreated locally
   - The tournament data is now in sync with the API server

## Technical Details

### Controller Action

Located in `app/controllers/tournaments_controller.rb`:

```ruby
def reload_from_cc
  reload_games = params[:reload_games] == "true"
  
  if local_server?
    if reload_games
      # Complete reset and load games from ClubCloud
      @tournament.reset_tournament
      Version.update_from_carambus_api(update_tournament_from_cc: @tournament.id)
    else
      # Setup mode: only reset local seedings
      @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all
      @tournament.reset_tmt_monitor! if @tournament.tournament_monitor.present?
      Version.update_from_carambus_api(update_tournament_from_cc: @tournament.id, reload_games: false)
    end
  else
    # API Server: Scrape from ClubCloud
    @tournament.scrape_single_tournament_public(reload_game_results: reload_games)
  end
  
  redirect_back_or_to(tournament_path(@tournament))
end
```

### Authorization

The button uses the `current_user&.privileged_access?` method which checks:

```ruby
def privileged_access?
  system_admin? || PRIVILEGED.include?(email)
end
```

Additionally, the `ensure_local_server` before_action has been modified to allow privileged users to bypass the ClubCloud results write-protection when using `reload_from_cc` with `reload_games=true`:

```ruby
# Sysadmin darf mit reload_games=true auch geschlossene Turniere neu laden
if action_name == 'reload_from_cc' && params[:reload_games] == 'true' && current_user&.privileged_access?
  return
end
```

### Translations

- **German:** `tournaments.show.force_reload_from_api` and `tournaments.show.force_reload_confirm`
- **English:** Same keys in English locale file

## Safety Considerations

⚠️ **Warning:** This action:
- **Completely resets** the tournament on the local server
- **Deletes all local tournament data** (seedings, games, results)
- **Cannot be undone** easily
- Should only be used when you're certain the API server has the correct/newer data

## Related Code

- View: `app/views/tournaments/show.html.erb` (lines 186-194)
- Controller: `app/controllers/tournaments_controller.rb` (lines 120-144)
- Model: `app/models/version.rb` (lines 177-374)
- Routes: `config/routes.rb` (line 209)
- Translations: `config/locales/de.yml` and `config/locales/en.yml`

## Example Scenario

**Problem:** Tournament ID 17385 in `carambus_bcw` is closed and has results on newapi.carambus.de, but the local bcw server shows outdated or missing data.

**Solution:**
1. Login as sysadmin to the bcw server
2. Navigate to `/tournaments/17385`
3. Click the "Sysadmin: Force Reload Tournament from API Server" button
4. Confirm the action
5. Wait for the synchronization to complete
6. The tournament now shows the correct results from the API server

## History

This feature was implemented to restore functionality that existed before the new wizard implementation, where admins could force a reload of closed tournaments from the API server without needing console access.

