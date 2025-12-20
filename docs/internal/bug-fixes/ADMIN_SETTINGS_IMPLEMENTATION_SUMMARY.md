# Admin Settings Configuration - Implementation Summary

## Overview

Implemented a feature allowing administrators to edit carambus.yml parameters through the web interface, with automatic lock file creation to prevent scenario deployment tasks from overwriting manual changes.

## Implementation Date

October 30, 2025

## Changes Made

### 1. View Layer (app/views/admin/settings/index.html.erb)

#### Added Advanced Settings Section
- New field group for JSON-based configuration
- Textarea for `quick_game_presets` with monospace font
- Help text explaining JSON format
- 20 rows for comfortable editing

#### Added Lock Status Indicator
- Warning banner when lock file exists
- Shows lock file path
- Yellow/orange styling for visibility
- Clear instructions for removing lock

#### Enhanced Notice Section
- Updated text to explain lock file creation
- Added information about restart requirement
- Improved styling for better UX

#### CSS Enhancements
```css
.field-unit textarea {
  width: 100%;
  min-height: 200px;
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.notice code {
  background: rgba(0,0,0,0.05);
  padding: 2px 6px;
  border-radius: 3px;
  font-family: monospace;
}
```

### 2. Controller Layer (app/controllers/admin/settings_controller.rb)

#### Modified `index` Action
- Added `@quick_game_presets_json` with pretty-printed JSON
- Added `@config_locked` flag based on lock file existence
- Uses `JSON.pretty_generate` for human-readable format

#### Modified `create` Action
- Added JSON field parsing logic
- Validates JSON syntax before saving
- Returns error message if JSON invalid
- Passes `create_lock: true` to `Carambus.save_config`
- Enhanced success message to mention lock file

#### Updated Permitted Parameters
- Added `:quick_game_presets` to `config_params`

### 3. Application Configuration (config/application.rb)

#### Modified `Carambus.save_config` Method
- Added optional `create_lock` parameter (default: false)
- Creates `config/carambus.yml.lock` when requested
- Lock file contains metadata:
  - `created_at`: ISO 8601 timestamp
  - `created_by`: "admin_settings"
  - `message`: Human-readable explanation

### 4. Scenario Tasks (lib/tasks/scenarios.rake)

#### Modified `generate_carambus_yml`
- Checks for lock file before generating
- Skips generation if locked
- Logs warning message with lock file path
- Returns true (non-fatal) to allow task to continue

#### Modified File Copy Operations (3 locations)
- `prepare_scenario_for_development` (line ~1465)
- `update_scenario` (line ~2126)
- Each checks for `carambus.yml.lock` before copying
- Shows skip message if locked
- Provides instructions for allowing regeneration

#### Leveraged Existing Upload Function
- `upload_config_file` helper already checks for `.lock` files
- Remote lock file checking already implemented (line ~2788)
- No changes needed for production upload protection

## File Modifications Summary

| File | Changes | Lines Modified |
|------|---------|----------------|
| app/views/admin/settings/index.html.erb | Added JSON field, lock indicator, styling | ~40 lines |
| app/controllers/admin/settings_controller.rb | JSON parsing, validation, lock check | ~30 lines |
| config/application.rb | Lock file creation in save_config | ~10 lines |
| lib/tasks/scenarios.rake | Lock file checks in 3 functions | ~30 lines |
| **Total** | | **~110 lines** |

## New Files Created

1. **docs/ADMIN_SETTINGS_CONFIGURATION.md** (300+ lines)
   - Complete feature documentation
   - Usage examples
   - Troubleshooting guide
   - Best practices

2. **testing/ADMIN_SETTINGS_TEST_PLAN.md** (350+ lines)
   - 12 comprehensive test cases
   - Test data and setup instructions
   - Results tracking table
   - Sign-off section

## Feature Capabilities

### Editable Parameters

#### Standard Fields (Text Input)
- application_name
- carambus_api_url
- carambus_domain
- queue_adapter
- season_name
- force_update
- no_local_protection
- support_email
- business_name
- business_address

#### Dropdown Fields
- context (Region)
- location_id
- club_id

#### JSON Fields (Textarea)
- **quick_game_presets**: Complete configuration for quick game buttons
  - Supports multiple table kinds (small_billard, match_billard, etc.)
  - Categories with multiple buttons
  - Full button configuration (balls, innings, discipline, label, allow_follow_up)

### Lock File Protection

#### Local Protection
- Lock file: `config/carambus.yml.lock`
- Prevents: `scenario:prepare_development`, `scenario:update`
- Checked before: File copy operations

#### Remote Protection  
- Lock file: `/var/www/{basename}/shared/config/carambus.yml.lock`
- Prevents: `scenario:prepare_deploy` upload
- Checked before: SCP upload operations

## Usage Flow

```
1. Admin navigates to /admin/settings
   ↓
2. Edits configuration (including JSON)
   ↓
3. Clicks "Update Configuration"
   ↓
4. Controller validates JSON
   ↓
5. If valid: Saves to carambus.yml + creates lock
   ↓
6. Success message + lock warning displayed
   ↓
7. Admin restarts application
   ↓
8. New config takes effect
   ↓
9. Scenario deployment tasks respect lock
```

## Validation & Error Handling

### JSON Validation
```ruby
begin
  config[key] = JSON.parse(config[key])
rescue JSON::ParserError => e
  flash[:alert] = "Invalid JSON for #{key}: #{e.message}"
  redirect_to admin_settings_path
  return
end
```

### Benefits
- Prevents invalid JSON from breaking application
- Clear error messages show exact problem
- Original values preserved on error
- Lock file not created if validation fails

## Console Output Examples

### During Scenario Preparation (Locked)
```
📁 Step 3: Copying basic configuration files to Rails root...
   ✅ database.yml copied to Rails root
   ⚠️  SKIPPED: carambus.yml (lock file exists - manually edited)
   Remove /path/to/carambus.yml.lock to allow regeneration
```

### During Scenario Update (Locked)
```
📋 Updating configuration files...
   ✅ Updated database.yml
   ⚠️  SKIPPED: carambus.yml (lock file exists - manually edited)
```

### During Production Upload (Locked)
```
📤 Step 4.5: Uploading configuration files to server...
   ✅ Uploaded database.yml
   🔒 Skipped carambus.yml (locked on server)
```

## Integration Points

### Existing Systems
- **Carambus.config**: Uses existing config loading mechanism
- **Carambus.save_config**: Extended with lock file support
- **Settings Controller**: Extended existing CRUD operations
- **Scenarios.rake**: Integrated with existing deployment workflow

### No Breaking Changes
- All changes backward compatible
- Lock file creation optional
- Existing code works without modification
- Graceful degradation if lock file missing

## Security Considerations

1. **Admin Only**: Settings page requires admin authentication
2. **Input Validation**: JSON validated before saving
3. **File Permissions**: Lock files created with standard permissions
4. **SQL Injection**: No direct SQL (uses ActiveRecord)
5. **XSS**: HTML escaped in views
6. **Path Traversal**: Uses Rails.root.join for safe paths

## Performance Impact

- **Minimal**: Lock file check is fast file existence test
- **No Database Queries**: Lock files are filesystem-based
- **Caching**: Config loaded once at startup
- **Memory**: Lock file metadata < 1KB

## Known Limitations

1. **Application Restart Required**: Config changes need restart
2. **No UI Lock Management**: Must remove lock files manually
3. **No Version History**: Previous values not tracked
4. **Single User Edit**: No concurrent edit protection
5. **No Schema Validation**: JSON structure not validated beyond syntax

## Future Enhancements

### Phase 2 (Planned)
1. Lock file management UI
   - View lock details
   - Remove lock button
   - Lock/unlock toggle

2. Configuration preview
   - Preview quick game buttons
   - Validate discipline names
   - Test JSON before save

3. Change history
   - Track all modifications
   - Revert to previous version
   - Audit log with user and timestamp

### Phase 3 (Potential)
1. JSON Schema validation
2. Multi-environment editing
3. Configuration export/import
4. Real-time config reload (without restart)
5. Bulk lock file management

## Testing Recommendations

### Manual Testing
1. Test TC001-TC012 from test plan
2. Verify lock file creation
3. Test JSON validation
4. Test scenario deployment with locks
5. Test production upload protection

### Automated Testing (Future)
```ruby
# Suggested test structure
describe Admin::SettingsController do
  describe "POST #create" do
    context "with valid JSON" do
      it "creates lock file"
      it "saves quick_game_presets"
    end
    
    context "with invalid JSON" do
      it "shows error message"
      it "does not save config"
      it "does not create lock file"
    end
  end
end
```

## Deployment Checklist

- [x] Code implemented in carambus_master
- [x] Documentation created
- [x] Test plan created
- [ ] Manual testing completed
- [ ] Code review by team
- [ ] Commit and push to repository
- [ ] Deploy to development environment
- [ ] Test in development
- [ ] Deploy to production
- [ ] Update operations documentation
- [ ] Train administrators on new feature

## Rollback Plan

If issues are discovered:

1. **Immediate**: Remove lock files to restore normal deployment
```bash
rm config/carambus.yml.lock
```

2. **Code Rollback**: Revert these commits
```bash
git revert <commit-hash>
```

3. **Database**: No database changes (safe to rollback)

4. **Lock Files**: Automatically ignored after rollback

## Support & Maintenance

### Contact
- **Developer**: [Your Name]
- **Documentation**: docs/ADMIN_SETTINGS_CONFIGURATION.md
- **Issues**: GitHub Issues

### Monitoring
- Check lock files don't accumulate unnecessarily
- Monitor for invalid JSON errors in logs
- Track restart frequency after config changes

## Conclusion

This implementation provides a user-friendly way for administrators to customize Carambus configuration through the web interface while protecting those changes from being overwritten by automated deployment tasks. The lock file mechanism ensures manual edits persist across deployments without requiring changes to deployment workflows.

The feature integrates seamlessly with existing code, requires minimal performance overhead, and provides clear feedback to both administrators and deployment engineers about configuration protection status.

