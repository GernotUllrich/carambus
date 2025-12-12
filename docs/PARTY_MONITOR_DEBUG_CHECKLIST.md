# Party Monitor Reflex Debugging Checklist

## Status Summary

✅ Code pulled to carambus_bcw (commits 4b92240, 1d75aaa, e20cd0d)  
✅ JavaScript controller created (`party_monitor_controller.js`)  
✅ Assets compiled (2025-12-12 12:26:09)  
✅ Server restarted (2025-12-12 12:28:04)  
✅ WebSocket connecting properly  
✅ StimulusReflex channel subscribed  

## Live Debugging Steps

### Step 1: Open Browser Console
1. Navigate to Party Monitor page (http://localhost:3003/party_monitors/XXX)
2. Open DevTools (F12 or Cmd+Option+I)
3. Go to Console tab

### Step 2: Check Stimulus Controller Registration
In the console, type:
```javascript
Stimulus.router.modulesByIdentifier.keys()
```

**Expected:** Should include "party-monitor" in the list  
**If not:** JavaScript not compiled properly or browser cache issue

### Step 3: Check if Controller Connected
After page loads, look for console message:
```
PartyMonitor controller connected!
```

**Expected:** Should appear immediately on page load  
**If not:** 
- Controller not registered (see Step 2)
- `data-controller="party_monitor"` missing from view
- JavaScript error preventing connection

### Step 4: Check WebSocket Connection
In DevTools → Network tab:
1. Filter by "WS" (WebSocket)
2. Look for `/cable` with status "101 Switching Protocols"
3. Click on it → Messages tab
4. Should see subscription confirmations including StimulusReflex::Channel

**If not connected:** ActionCable issue, not StimulusReflex issue

### Step 5: Try Assigning a Player
1. In "Spielberechtigte" select box, select a player
2. Click the left arrow (◄) "Melden" button
3. **Watch the Console** for:
   - "Before assign_player_a" message (from our lifecycle callback)
   - Any errors or warnings
4. **Watch the Network → WS tab** for:
   - Message sent with target "PartyMonitorReflex#assign_player_a"
   - Response message

### Step 6: Check Server Logs
In terminal:
```bash
tail -f /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/log/development.log | grep -i "party\|reflex\|assign"
```

Then click the button again. **Expected to see:**
```
[ActionCable] StimulusReflex::Channel#receive
PartyMonitorReflex#assign_player_a
======== assign_player_a
Seeding Create
morph :page
```

### Step 7: Check Database
Open Rails console:
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
rails console
```

Then:
```ruby
# Get your party (replace ID with actual)
party = Party.find(XXX)  

# Check seedings before
party.seedings.where(role: "team_a").count

# Click the assign button in browser

# Check seedings after (reload console first)
party.reload
party.seedings.where(role: "team_a").count  # Should increase by 1

# View the seedings
party.seedings.where(role: "team_a").pluck(:player_id)
```

## Diagnostic Decision Tree

### ❌ "PartyMonitor controller connected!" NOT in console
→ **Problem:** JavaScript controller not loading
→ **Solution:** 
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
yarn build
# Restart server
# Hard refresh browser (Cmd+Shift+R)
```

### ❌ Message appears but clicking does nothing (no logs)
→ **Problem:** Reflex not triggering
→ **Check:**
- Is button disabled? (check if `@party_monitor.state == "seeding_mode"`)
- Any JavaScript errors in console?
- WebSocket connected? (Network → WS tab)
- Try clicking other reflexes on the page - do THEY work?

### ❌ Server logs show reflex running but UI doesn't update
→ **Problem:** `morph :page` not working
→ **Check console for:**
- "Morph" messages from StimulusReflex
- Errors about morphing
- Check if `@assigned_players_a_ids` is set (add Rails.logger.info)

### ❌ Database changes but page reload doesn't show them
→ **Problem:** Database transaction or query issue
→ **Check:**
- Is it creating Seedings in correct table/database?
- Are the queries in `setup_view_variables` correct?
- Try querying manually in rails console

### ❌ Everything works except it requires server restart
→ **Problem:** Caching issue
→ **This WAS the original problem - should be fixed now!**

## Add Temporary Debug Logging

Edit `/app/reflexes/party_monitor_reflex.rb`:

```ruby
def assign_player(ab)
  Rails.logger.info "🔵 START assign_player_#{ab}"
  Rails.logger.info "🔵 Params: #{params.inspect}"
  
  assigned_players_ids = Player.joins(:seedings).where(seedings: { tournament: @party, role: "team_#{ab}" }).ids
  Rails.logger.info "🔵 Currently assigned: #{assigned_players_ids.inspect}"
  
  add_ids = Array(params["availablePlayer#{ab.upcase}Id"]).map(&:to_i) - assigned_players_ids
  Rails.logger.info "🔵 Will add: #{add_ids.inspect}"
  
  add_ids.each do |pid|
    seeding = Seeding.create(player_id: pid, tournament: @party, role: "team_#{ab}", position: 1)
    Rails.logger.info "🔵 Created seeding: #{seeding.id}, errors: #{seeding.errors.full_messages}"
  end
  
  Rails.logger.info "🔵 Before setup_view_variables - @assigned_players_a_ids: #{@assigned_players_a_ids.inspect}"
  setup_view_variables  # This should already be called by before_reflex
  Rails.logger.info "🔵 After setup_view_variables - @assigned_players_a_ids: #{@assigned_players_a_ids.inspect}"
  
  Rails.logger.info "🔵 About to morph :page"
  morph :page
  Rails.logger.info "🔵 END assign_player_#{ab}"
rescue StandardError => e
  Rails.logger.error "🔴 ERROR in assign_player_#{ab}: #{e.message}"
  Rails.logger.error "🔴 Backtrace: #{e.backtrace.first(10).join("\n")}"
end
```

## Quick Test Command

Run this in terminal while testing:
```bash
tail -f /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/log/development.log | grep "🔵\|🔴\|assign_player\|morph"
```

Then click the button and watch the output.

## Expected Flow (When Working)

1. Click button
2. Browser console: "Before assign_player_a"
3. WebSocket sends message to server
4. Server logs: "🔵 START assign_player_a"
5. Server creates Seeding record
6. Server runs setup_view_variables
7. Server executes morph :page
8. StimulusReflex morphs DOM
9. Players move in UI
10. Counts update

## Still Not Working?

If after all this it still doesn't work:
1. Share the browser console output
2. Share the server log output (with 🔵 markers)
3. Share Network → WS → Messages
4. Share rails console output showing database state

This will help pinpoint exactly where the flow breaks!

