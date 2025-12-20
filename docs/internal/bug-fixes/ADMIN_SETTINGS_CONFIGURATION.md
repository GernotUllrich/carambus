# Admin Settings Configuration

## Overview

The admin settings interface allows administrators to edit carambus.yml configuration parameters directly through the web interface. When settings are saved, a lock file is automatically created to prevent scenario deployment tasks from overwriting the manually configured values.

## Features

### Editable Configuration Parameters

#### System Settings
- **application_name**: Name of the application
- **carambus_api_url**: URL to the Carambus API server
- **carambus_domain**: Domain for the Carambus application
- **queue_adapter**: ActiveJob queue adapter (async, sidekiq, etc.)
- **season_name**: Current season identifier (e.g., "2025/2026")
- **force_update**: Force update flag ('true' or 'false')
- **no_local_protection**: Disable local data protection ('true' or 'false')

#### Contact Settings
- **support_email**: Support contact email
- **business_name**: Business name for footer/legal
- **business_address**: Business address for legal notice

#### Location Settings
- **Location**: Dropdown to select location (filtered by region)
- **Club**: Dropdown to select club (filtered by region)

#### Advanced Settings (JSON)
- **quick_game_presets**: JSON configuration for quick game buttons per table kind

### Quick Game Presets Format

The `quick_game_presets` parameter accepts JSON in the following format:

```json
{
  "small_billard": [
    {
      "category": "Freie Partie",
      "buttons": [
        {
          "balls": 40,
          "innings": 20,
          "discipline": "Freie Partie klein",
          "allow_follow_up": true
        },
        {
          "balls": 80,
          "innings": 20,
          "discipline": "Freie Partie klein",
          "allow_follow_up": true
        }
      ]
    },
    {
      "category": "Dreiband",
      "buttons": [
        {
          "balls": 30,
          "innings": 25,
          "discipline": "Dreiband klein",
          "allow_follow_up": true
        }
      ]
    }
  ],
  "match_billard": [
    {
      "category": "Dreiband",
      "buttons": [
        {
          "balls": 20,
          "innings": 30,
          "discipline": "Dreiband groß",
          "allow_follow_up": true
        }
      ]
    }
  ]
}
```

#### Button Configuration Fields
- **balls**: Target balls/points (0 for open ended)
- **innings**: Maximum innings (0 for open ended)
- **discipline**: Name of the discipline
- **label**: Optional custom label (e.g., "-/20" for open balls with 20 innings)
- **allow_follow_up**: Boolean indicating if follow-up games are allowed

## Lock File Mechanism

### How It Works

1. **Creation**: When an admin saves settings via the web interface, a lock file is automatically created at:
   - Local: `config/carambus.yml.lock`
   - Production Server: `/var/www/{basename}/shared/config/carambus.yml.lock`

2. **Lock File Content**:
```yaml
---
created_at: "2025-10-30T12:34:56Z"
created_by: "admin_settings"
message: "Configuration manually edited via admin settings. Prevents scenario deployment from overwriting."
```

3. **Protection Scope**: The lock file prevents the following scenario tasks from overwriting `carambus.yml`:
   - `rake scenario:prepare_development` - skips carambus.yml copy
   - `rake scenario:update` - skips carambus.yml update
   - `rake scenario:prepare_deploy` - skips carambus.yml upload to server

### When Lock Files Are Checked

#### Local Development
- During `scenario:prepare_development` when copying config files to Rails root
- During `scenario:update` when pulling git changes and updating config files
- Location checked: `{rails_root}/config/carambus.yml.lock`

#### Production Server
- During `scenario:prepare_deploy` when uploading configuration files
- Uses helper function `upload_config_file` which checks for remote lock
- Location checked: `/var/www/{basename}/shared/config/carambus.yml.lock`

### Removing Lock Files

#### Local Lock File
```bash
# Remove from Rails root
rm config/carambus.yml.lock

# Remove from scenario config directory
rm ../carambus_data/scenarios/{scenario_name}/development/carambus.yml.lock
```

#### Remote Lock File (Production Server)
```bash
# SSH into production server
ssh -p {port} www-data@{host}

# Remove lock file
sudo rm /var/www/{basename}/shared/config/carambus.yml.lock
```

#### Via Rake Task (Future Enhancement)
```bash
# Planned: unlock command to remove lock files
rake scenario:unlock_config[scenario_name]
```

## Usage Examples

### Example 1: Editing Quick Game Presets

1. Navigate to **Admin > Settings** in the web interface
2. Scroll to **Advanced Settings (JSON)**
3. Edit the `quick_game_presets` JSON:
   ```json
   {
     "small_billard": [
       {
         "category": "Trainingsmodus",
         "buttons": [
           {
             "balls": 20,
             "innings": 10,
             "discipline": "Freie Partie klein",
             "label": "Training 20/10",
             "allow_follow_up": false
           }
         ]
       }
     ]
   }
   ```
4. Click **Update Configuration**
5. Restart the Rails application for changes to take effect
6. A lock file is automatically created

### Example 2: Changing Season Name

1. Navigate to **Admin > Settings**
2. Find **season_name** field
3. Change to "2026/2027"
4. Click **Update Configuration**
5. Restart application
6. Lock file prevents scenario deployment from reverting this change

### Example 3: Allowing Regeneration

If you want to allow scenario deployment to regenerate configuration:

```bash
# Remove lock file
rm config/carambus.yml.lock

# Next scenario deployment will regenerate carambus.yml
rake scenario:prepare_development[scenario_name]
```

## Validation

### JSON Validation
The controller validates JSON fields before saving:
- If invalid JSON is submitted, an error message is displayed
- The configuration is not saved if validation fails
- Error message shows the JSON parsing error details

### Field Validation
- Integer fields (location_id, club_id) are automatically converted
- String fields are saved as-is
- JSON fields are parsed and stored as Ruby hashes

## Visual Indicators

### Lock Status Warning
When a lock file exists, a warning banner is displayed:

```
⚠️ Configuration Lock Active:
Your settings are protected from being overwritten by scenario deployment tasks.
Lock file: config/carambus.yml.lock
```

### Deployment Console Messages

When scenarios.rake encounters a locked file:
```
⚠️ SKIPPED: carambus.yml (lock file exists - manually edited)
Remove /path/to/carambus.yml.lock to allow regeneration
```

When uploading to production server:
```
🔒 Skipped carambus.yml (locked on server)
```

## Best Practices

1. **Document Changes**: Keep track of manual configuration changes
2. **Test Changes**: Test configuration changes in development before production
3. **Backup**: Take backup of carambus.yml before making major changes
4. **Version Control**: Lock files are typically ignored by git (add to .gitignore)
5. **Coordination**: Inform team members when locking production configuration
6. **Regular Review**: Periodically review locked configurations for relevance

## Troubleshooting

### Configuration Not Taking Effect
**Problem**: Changed settings but application still uses old values  
**Solution**: Restart the Rails application (settings are loaded at startup)

### Deployment Overwrites Settings
**Problem**: Scenario deployment overwrote my manual changes  
**Solution**: Lock file may have been removed or not created properly. Re-apply changes and verify lock file exists.

### Invalid JSON Error
**Problem**: Cannot save quick_game_presets due to JSON error  
**Solution**: Validate JSON syntax using online validator (jsonlint.com) before submitting

### Cannot Access Settings Page
**Problem**: Settings page shows error or won't load  
**Solution**: Check Rails logs for errors. Ensure carambus.yml exists and is valid YAML.

## Technical Details

### Files Modified

1. **app/views/admin/settings/index.html.erb**
   - Added textarea for `quick_game_presets` JSON editing
   - Added lock status indicator
   - Added help text and warnings

2. **app/controllers/admin/settings_controller.rb**
   - Added JSON parsing for `quick_game_presets`
   - Added `quick_game_presets` to permitted parameters
   - Added JSON validation with error handling
   - Added lock file status check

3. **config/application.rb**
   - Modified `Carambus.save_config` to accept `create_lock` parameter
   - Added lock file creation logic with metadata

4. **lib/tasks/scenarios.rake**
   - Modified `generate_carambus_yml` to check for lock files
   - Modified `prepare_scenario_for_development` to skip locked files
   - Modified `update_scenario` to skip locked files
   - Uses existing `upload_config_file` helper for remote lock checking

### Lock File Schema

```yaml
---
created_at: "ISO 8601 timestamp"
created_by: "admin_settings"
message: "Human-readable explanation"
```

## Future Enhancements

1. **Lock File Management UI**
   - View lock file details in admin interface
   - Button to remove lock file from UI
   - Warning when about to remove lock

2. **Configuration History**
   - Track changes to configuration over time
   - Ability to revert to previous versions
   - Audit log of who changed what

3. **Enhanced Validation**
   - JSON schema validation for quick_game_presets
   - Preview quick game buttons before saving
   - Validate discipline names against database

4. **Multi-Environment Support**
   - Edit development and production separately
   - Sync settings between environments
   - Environment-specific lock files

## Related Documentation

- [Quick Game Configuration Guide](../QUICK_GAME_CONFIG_GUIDE.md)
- [Scenario Deployment Guide](../SCENARIO_DEPLOYMENT.md)
- [Configuration Management](../CONFIGURATION.md)

