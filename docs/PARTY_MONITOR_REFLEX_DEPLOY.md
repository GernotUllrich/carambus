# Party Monitor Reflex Deployment & Testing Guide

## What Was Fixed

The PartyMonitor reflexes were completely broken due to THREE critical missing pieces:

### 1. Missing Stimulus Controller ⚠️ CRITICAL
**Problem:** The view had `data-controller="party_monitor"` but no corresponding JavaScript controller existed.
- Result: StimulusReflex never registered
- Result: Reflex actions never triggered
- Result: WebSocket messages never sent

**Fix:** Created `/app/javascript/controllers/party_monitor_controller.js`

### 2. Missing Morph Commands ⚠️ CRITICAL  
**Problem:** Reflex methods updated the database but never told StimulusReflex to update the UI.
- Result: Database changed, but UI remained stale
- Result: Only server restart showed changes

**Fix:** Added `morph :page` to:
- `assign_player(ab)`
- `remove_player(ab)`
- `edit_parameter()`

### 3. Missing Instance Variables
**Problem:** View template needs many instance variables that weren't set in reflexes.

**Fix:** Added `setup_view_variables` method called from `before_reflex :load_objects`

## Deployment Steps

### 1. Server-Side Code (Already Pushed)
```bash
cd /path/to/scenario  # e.g., carambus_bcw
git pull origin master
```

### 2. JavaScript Assets (IMPORTANT!)
The JavaScript controller needs to be compiled into the asset bundle:

```bash
# If using esbuild (your project uses this):
yarn build

# Or if there's a full asset pipeline:
yarn build
yarn build:css
rails assets:precompile  # May not be needed for development
```

### 3. Restart Server
**This is REQUIRED because:**
- JavaScript controllers are loaded at server startup
- New controller won't be available until restart

```bash
# Stop the server (Ctrl+C or systemctl stop)
# Then start it again

# For systemd services:
sudo systemctl restart carambus_bcw  # or whatever the service name is

# For manual Puma/Rails:
# Stop with Ctrl+C, then:
rails server  # or bin/dev or whatever you use
```

### 4. Clear Browser Cache (Optional but Recommended)
- Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows/Linux)
- Or clear browser cache entirely
- Or open in private/incognito window

## Testing Checklist

### ✅ Test 1: Check Stimulus Controller Loads
1. Open browser DevTools (F12)
2. Go to Console tab
3. Navigate to a PartyMonitor page
4. **Expected:** See message: `"PartyMonitor controller connected!"`
5. **If not:** JavaScript not compiled or server not restarted

### ✅ Test 2: Check WebSocket Connection
1. In DevTools, go to Network tab
2. Filter by "WS" (WebSocket)
3. Refresh the page
4. **Expected:** See `/cable` connection with status 101 (Switching Protocols)
5. **If not:** ActionCable not running or blocked

### ✅ Test 3: Assign Player (Team A)
1. Navigate to a PartyMonitor in `seeding_mode`
2. In "Spielberechtigte" (right side, Team A), select a player
3. Click the left arrow button (◄) "Melden"
4. **Expected immediate behavior:**
   - Player moves from right to left list
   - "Mitspieler" count increments
   - "Spielberechtigte" count decrements
   - No page reload
   - Update within ~500ms
5. **Check Console:** Should see reflex lifecycle messages

### ✅ Test 4: Remove Player (Team A)
1. In "Mitspieler" (left side, Team A), select a player
2. Click the right arrow button (►) "Abmelden"
3. **Expected immediate behavior:**
   - Player moves from left to right list
   - Counts update accordingly
   - No page reload

### ✅ Test 5: Team B (Same as above)
Repeat tests 3 and 4 for "Gast-Mannschaft" (Team B)

### ✅ Test 6: Multiple Players
1. Select multiple players (Ctrl+Click)
2. Assign/remove them
3. **Expected:** All selected players move together

### ✅ Test 7: Edit Parameters
1. Change a dropdown in "Disziplin Parameter"
2. **Expected:** Value saves immediately without page reload

## Troubleshooting

### Problem: "PartyMonitor controller connected!" never appears

**Possible causes:**
1. JavaScript not compiled
   ```bash
   yarn build
   ```

2. Server not restarted after pulling new code
   ```bash
   sudo systemctl restart carambus_bcw
   ```

3. Browser cached old JavaScript
   - Hard refresh (Cmd+Shift+R)
   - Clear cache
   - Try private/incognito window

### Problem: UI still doesn't update after clicking

**Check Console for errors:**
- Red errors indicate JavaScript problems
- Look for "StimulusReflex" or "ActionCable" errors

**Check Server Logs:**
```bash
tail -f log/development.log
# or
journalctl -u carambus_bcw -f
```

Look for:
- `======== assign_player_a` (confirms reflex ran)
- Error messages or stack traces

**Check WebSocket:**
- Network tab → WS filter
- Click "Melden" button
- Should see messages sent/received
- If no messages, WebSocket not connected

### Problem: Players assigned but lists don't update

This was the original problem! Should be fixed now with `morph :page`.

**If still occurring:**
1. Check that `morph :page` is in the reflex methods
2. Check console for JavaScript errors preventing morph
3. Check if `setup_view_variables` is setting all needed variables

### Problem: Works in development, broken in production

**Check asset compilation:**
```bash
RAILS_ENV=production rails assets:precompile
```

**Check if JavaScript is being served:**
- View page source
- Look for `<script>` tags loading application.js or similar
- Check browser Network tab for 404s on JavaScript files

## Files Changed (Summary)

### Created:
- `app/javascript/controllers/party_monitor_controller.js` ← **NEW**

### Modified:
- `app/reflexes/party_monitor_reflex.rb`
  - Added `setup_view_variables` method
  - Added `morph :page` to player assignment methods
  - Added admin check to `reset_party_monitor`

### Documentation:
- `docs/PARTY_MONITOR_REFLEX_FIX.md` - Technical explanation
- `docs/PARTY_MONITOR_REFLEX_TESTING.md` - Testing guide
- `docs/PARTY_MONITOR_REFLEX_DEPLOY.md` - This file

## Success Criteria

✅ Console shows "PartyMonitor controller connected!"  
✅ WebSocket shows connected in Network tab  
✅ Clicking assign/remove shows immediate UI update  
✅ No page reload needed  
✅ Database changes persist after refresh  
✅ Multiple players can be moved at once  
✅ Counts update correctly  

If all of the above work, the fix is successful! 🎉

## Questions or Issues?

If problems persist after following this guide:
1. Check all items in Troubleshooting section
2. Check server logs for errors
3. Check browser console for errors
4. Verify all three files (controller JS, reflex RB, and compiled assets)
5. Try in a fresh browser session (private/incognito)

