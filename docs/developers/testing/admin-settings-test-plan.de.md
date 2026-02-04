# Admin Settings Configuration - Test Plan

## Test Environment Setup

### Prerequisites
1. Rails application running in development mode
2. Admin user with access to settings page
3. Git repository for testing lock file prevention
4. Scenario configured in carambus_data/scenarios/

### Test Data

#### Valid Quick Game Presets JSON
```json
{
  "small_billard": [
    {
      "category": "Test Category",
      "buttons": [
        {
          "balls": 50,
          "innings": 15,
          "discipline": "Test Discipline",
          "allow_follow_up": true
        }
      ]
    }
  ]
}
```

#### Invalid Quick Game Presets JSON
```json
{
  "small_billard": [
    {
      "category": "Test",
      "buttons": [
        {
          "balls": 50,
          "innings": 15,
          // This comment causes JSON parse error
        }
      ]
    ]
  }
}
```

## Test Cases

### TC001: View Settings Page
**Objective**: Verify settings page loads correctly with existing configuration

**Steps**:
1. Navigate to `/admin/settings`
2. Verify all existing settings are displayed
3. Verify `quick_game_presets` textarea shows current JSON

**Expected Result**:
- Page loads without errors
- All fields populated with current values
- JSON is properly formatted and readable
- Lock status indicator shows if lock file exists

**Status**: [ ] Pass [ ] Fail

---

### TC002: Edit Simple Settings
**Objective**: Verify basic settings can be edited and saved

**Steps**:
1. Navigate to `/admin/settings`
2. Change `season_name` to "2026/2027"
3. Change `support_email` to "test@example.com"
4. Click "Update Configuration"

**Expected Result**:
- Success message displayed: "Configuration updated successfully..."
- Lock file created at `config/carambus.yml.lock`
- Lock status indicator appears on page
- Settings persist after page reload

**Verification**:
```bash
# Check lock file exists
ls -la config/carambus.yml.lock

# Check carambus.yml content
grep "season_name" config/carambus.yml
grep "support_email" config/carambus.yml
```

**Status**: [ ] Pass [ ] Fail

---

### TC003: Edit Quick Game Presets (Valid JSON)
**Objective**: Verify quick_game_presets can be edited with valid JSON

**Steps**:
1. Navigate to `/admin/settings`
2. Edit `quick_game_presets` textarea with valid JSON (see Test Data)
3. Click "Update Configuration"

**Expected Result**:
- Success message displayed
- Lock file created
- JSON properly saved to carambus.yml
- After restart, quick game buttons reflect changes

**Verification**:
```bash
# Check YAML structure
cat config/carambus.yml | grep -A 20 "quick_game_presets"

# Restart and verify in UI
rails restart
# Visit location scoreboard and check quick game buttons
```

**Status**: [ ] Pass [ ] Fail

---

### TC004: Edit Quick Game Presets (Invalid JSON)
**Objective**: Verify validation prevents saving invalid JSON

**Steps**:
1. Navigate to `/admin/settings`
2. Edit `quick_game_presets` with invalid JSON (see Test Data)
3. Click "Update Configuration"

**Expected Result**:
- Error message displayed: "Invalid JSON for quick_game_presets: ..."
- Configuration NOT saved
- Redirected back to settings page
- Lock file NOT created
- Original values preserved

**Status**: [ ] Pass [ ] Fail

---

### TC005: Lock File Prevents Scenario Generation
**Objective**: Verify lock file prevents scenario:prepare_development from overwriting

**Steps**:
1. Edit settings via admin interface (creates lock file)
2. Run: `rake scenario:prepare_development[test_scenario]`
3. Check console output
4. Verify carambus.yml unchanged

**Expected Result**:
- Console shows: "⚠️  SKIPPED: carambus.yml (lock file exists - manually edited)"
- Console shows: "Remove {path}/carambus.yml.lock to allow regeneration"
- carambus.yml contains manual edits, not regenerated content

**Verification**:
```bash
# Run scenario task
cd carambus_master
rake scenario:prepare_development[test_scenario]

# Check carambus.yml unchanged
git diff config/carambus.yml
```

**Status**: [ ] Pass [ ] Fail

---

### TC006: Lock File Prevents Scenario Update
**Objective**: Verify lock file prevents scenario:update from overwriting

**Steps**:
1. Edit settings via admin interface (creates lock file)
2. Run: `rake scenario:update[test_scenario]`
3. Check console output
4. Verify carambus.yml unchanged

**Expected Result**:
- Console shows: "⚠️  SKIPPED: carambus.yml (lock file exists - manually edited)"
- carambus.yml preserves manual edits

**Status**: [ ] Pass [ ] Fail

---

### TC007: Remove Lock File and Regenerate
**Objective**: Verify configuration can be regenerated after removing lock

**Steps**:
1. Edit settings via admin interface (creates lock file)
2. Remove lock file: `rm config/carambus.yml.lock`
3. Run: `rake scenario:prepare_development[test_scenario]`
4. Check carambus.yml regenerated

**Expected Result**:
- Lock file removed successfully
- Console shows: "✅ carambus.yml copied to Rails root"
- carambus.yml regenerated from template
- Manual edits overwritten

**Status**: [ ] Pass [ ] Fail

---

### TC008: Production Server Lock File
**Objective**: Verify remote lock file prevents upload to production

**Prerequisites**: Production server accessible via SSH

**Steps**:
1. SSH to production server
2. Create lock file: `sudo touch /var/www/{basename}/shared/config/carambus.yml.lock`
3. Run: `rake scenario:prepare_deploy[test_scenario]`
4. Check console output

**Expected Result**:
- Console shows: "🔒 Skipped carambus.yml (locked on server)"
- carambus.yml NOT uploaded to server
- Deployment continues (not fatal error)

**Verification**:
```bash
# On server, check modification time
ssh -p {port} www-data@{host} \
  'ls -la /var/www/{basename}/shared/config/carambus.yml'
# Should show old timestamp
```

**Status**: [ ] Pass [ ] Fail

---

### TC009: Lock Status Indicator
**Objective**: Verify UI correctly shows lock file status

**Test 9a: Lock File Exists**
1. Create lock file manually: `touch config/carambus.yml.lock`
2. Navigate to `/admin/settings`
3. Verify lock warning banner displayed

**Expected Result**:
- Warning banner visible with yellow/orange background
- Shows lock file path
- Message indicates protection active

**Test 9b: No Lock File**
1. Remove lock file: `rm config/carambus.yml.lock`
2. Reload `/admin/settings`
3. Verify no lock warning

**Expected Result**:
- No lock warning banner
- Normal notice about restarting application

**Status**: [ ] Pass [ ] Fail

---

### TC010: JSON Pretty Formatting
**Objective**: Verify JSON is displayed in human-readable format

**Steps**:
1. Save quick_game_presets as minified JSON (all one line)
2. Reload `/admin/settings`
3. Check textarea content

**Expected Result**:
- JSON properly indented with 2 spaces
- Arrays and objects on separate lines
- Easy to read and edit

**Status**: [ ] Pass [ ] Fail

---

### TC011: Application Restart Required
**Objective**: Verify configuration changes require restart to take effect

**Steps**:
1. Note current `season_name` in application
2. Change `season_name` via admin settings
3. Check application WITHOUT restarting
4. Restart application
5. Check application again

**Expected Result**:
- Before restart: Old value still shown in app
- After restart: New value reflected in app
- Notice clearly states restart required

**Status**: [ ] Pass [ ] Fail

---

### TC012: Multiple Fields Update
**Objective**: Verify multiple fields can be changed in one save

**Steps**:
1. Change 5+ fields simultaneously:
   - season_name
   - support_email
   - carambus_domain
   - location_id
   - quick_game_presets
2. Click "Update Configuration"
3. Verify all changes saved

**Expected Result**:
- All fields saved correctly
- Single lock file created
- Single success message
- All changes visible after page reload

**Status**: [ ] Pass [ ] Fail

---

## Test Results Summary

| Test Case | Status | Notes | Tester | Date |
|-----------|--------|-------|--------|------|
| TC001 | | | | |
| TC002 | | | | |
| TC003 | | | | |
| TC004 | | | | |
| TC005 | | | | |
| TC006 | | | | |
| TC007 | | | | |
| TC008 | | | | |
| TC009 | | | | |
| TC010 | | | | |
| TC011 | | | | |
| TC012 | | | | |

## Known Issues

Document any issues found during testing:

1. 
2. 
3. 

## Sign-off

**Tested by**: ________________  
**Date**: ________________  
**Environment**: ________________  
**Build/Commit**: ________________  

**Test Result**: [ ] All Pass [ ] Some Failures [ ] Not Tested

**Notes**:

