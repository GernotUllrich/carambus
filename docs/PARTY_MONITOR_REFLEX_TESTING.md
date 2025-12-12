# Testing Party Monitor Reflex UI Feedback

## Test Scenario: Player Assignment

### Prerequisites
1. Navigate to a Party Monitor page
2. Ensure you're in `seeding_mode` state
3. Have available players in both teams' "Spielberechtigte" lists

### Test Steps for `assign_player_a`

1. **Initial State Check**
   - Note the count `[X]` next to "Mitspieler" (should be current number)
   - Note the count `[X]` next to "Spielberechtigte" (should be current number)

2. **Select a Player**
   - In the right "Spielberechtigte" select box, click on a player name
   - The player should be highlighted

3. **Click Assign Button**
   - Click the left arrow button (◄) labeled "Melden"
   - **Expected immediate behavior:**
     - The player should move from "Spielberechtigte" to "Mitspieler" list
     - "Mitspieler" count should increment by 1
     - "Spielberechtigte" count should decrement by 1
     - No page reload should occur
     - Update should happen within ~100-500ms

4. **Verify Database**
   - If you refresh the page manually, the change should persist
   - A new `Seeding` record should exist in the database

### Test Steps for `remove_player_a`

1. **Select an Assigned Player**
   - In the left "Mitspieler" select box, click on a player name

2. **Click Remove Button**
   - Click the right arrow button (►) labeled "Abmelden"
   - **Expected immediate behavior:**
     - The player should move from "Mitspieler" back to "Spielberechtigte" list
     - "Mitspieler" count should decrement by 1
     - "Spielberechtigte" count should increment by 1
     - No page reload should occur

### Test Steps for Team B

Repeat the above tests but with Team B ("Gast-Mannschaft"):
- Use `assign_player_b` by clicking the left arrow in the Team B section
- Use `remove_player_b` by clicking the right arrow in the Team B section

### Test: Multiple Players

1. Select multiple players (Ctrl+Click or Shift+Click)
2. Click assign/remove button
3. All selected players should move together
4. Counts should update accordingly

### Test: Prepare Next Round

After assigning enough players (minimum 4, maximum 8 by default):
1. Click "Mannschaftsaufstellung abschließen"
2. The party monitor should transition from `seeding_mode` to the next state
3. Player lists should become disabled (grayed out)
4. Button should become disabled

## What Was Broken Before

**Before the fix:**
- Clicking assign/remove buttons appeared to do nothing
- Player lists didn't update
- Counts didn't change
- Only after server restart + page reload would changes be visible
- Database was being updated correctly, but UI wasn't reflecting it

**After the fix:**
- All updates happen immediately in the UI
- StimulusReflex properly morphs the DOM
- User gets instant feedback
- No need to reload or restart

## Debugging

If issues occur, check:

1. **Browser Console**
   ```javascript
   // Should see StimulusReflex events
   stimulus-reflex:before
   stimulus-reflex:success
   stimulus-reflex:after
   ```

2. **Rails Logs**
   ```
   ======== assign_player_a
   ```

3. **ActionCable Connection**
   - Check browser console for WebSocket connection
   - Should be connected to `/cable`

4. **Instance Variables**
   - In rails console or logs, verify `@assigned_players_a_ids` is set
   - Should be an array of integer player IDs

## Common Issues

### UI Still Not Updating

**Possible causes:**
1. JavaScript errors preventing StimulusReflex from working
   - Check browser console for errors
2. ActionCable not connected
   - Check for WebSocket errors in console
3. View is using different variable names
   - Verify variable names match between controller and reflex
4. Turbo interfering
   - Note: Buttons have `data: { turbo: false }` to disable Turbo

### Performance Issues

If updates are slow:
- Check database query performance in logs
- The `setup_view_variables` method does multiple database queries
- Consider adding indexes if needed

### Flash Messages Not Showing

Flash messages should appear at the top of the page. If not:
- Check if your layout includes flash message rendering
- StimulusReflex should automatically handle flash messages

## Related Files to Check

- `/app/reflexes/party_monitor_reflex.rb` - The reflex implementation
- `/app/views/party_monitors/_party_monitor.html.erb` - The view template
- `/app/controllers/party_monitors_controller.rb` - Controller show action
- Browser DevTools → Network → WS (WebSocket) - ActionCable traffic

