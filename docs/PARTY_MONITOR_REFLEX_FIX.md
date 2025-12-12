# Party Monitor Reflex UI Feedback Fix

## Problem

The reflexes in `PartyMonitorReflex` (e.g., `assign_player_a`, `remove_player_a`, etc.) were not showing any immediate UI feedback after execution. The database changes were happening correctly, but users only saw the updated UI after a server restart and page reload.

## Root Cause

**TWO critical issues were preventing reflexes from working:**

### Issue 1: Missing Stimulus Controller
The view had `data-controller="party_monitor"` but there was no corresponding `party_monitor_controller.js` file! Without this controller:
- StimulusReflex couldn't register the controller
- Reflex actions couldn't be triggered via the WebSocket
- No DOM morphing could occur

### Issue 2: No Explicit Morph Command
Even if the controller existed, the reflex methods didn't specify how to update the UI. They were:
1. Modifying the database (creating/destroying `Seeding` records) ✅
2. But NOT telling StimulusReflex to update the page ❌

Without calling `morph :page`, StimulusReflex doesn't know it should re-render anything.

### Issue 3: Missing Instance Variables
The view template requires many instance variables to render properly, but these weren't being set in the reflex, only in the controller's `show` action.

## Solution

**Three fixes were applied:**

### Fix 1: Created Missing Stimulus Controller
Created `/app/javascript/controllers/party_monitor_controller.js` that extends `ApplicationController`:
- Registers with StimulusReflex on connect
- Enables reflex actions to be triggered from the view
- Adds lifecycle callbacks for debugging (beforeAssignPlayerA, assignPlayerASuccess, etc.)

### Fix 2: Added Explicit Morph Commands
Added `morph :page` calls to reflex methods:
- `assign_player()` - now calls `morph :page` after creating seedings
- `remove_player()` - now calls `morph :page` after destroying seedings
- `edit_parameter()` - now calls `morph :page` after updating parameters

This tells StimulusReflex to re-render the entire page after database changes.

### Fix 3: Setup Instance Variables
Added a new private method `setup_view_variables` that mirrors the logic in `PartyMonitorsController#show`. This method sets up all the necessary instance variables:

- `@league`
- `@assigned_players_a_ids` / `@assigned_players_b_ids`
- `@available_players_a_ids` / `@available_players_b_ids`
- `@available_replacement_players_a_ids` / `@available_replacement_players_b_ids`
- `@available_fitting_table_ids`
- `@tournament_tables`
- `@tables_from_plan`

This method is called from the `load_objects` before_reflex callback, ensuring all instance variables are properly set before any reflex action executes and before the page is morphed.

## Changes Made

### 1. Created Stimulus Controller

**File:** `/app/javascript/controllers/party_monitor_controller.js`

```javascript
import ApplicationController from './application_controller'

export default class extends ApplicationController {
  connect () {
    super.connect()
    console.log("PartyMonitor controller connected!")
  }
}
```

### 2. Added `morph :page` to Reflex Methods

**File:** `/app/reflexes/party_monitor_reflex.rb`

```ruby
def assign_player(ab)
  # ... database updates ...
  morph :page  # Added this line
end

def remove_player(ab)
  # ... database updates ...
  morph :page  # Added this line
end
```

### 3. Added `setup_view_variables` Method

**File:** `/app/reflexes/party_monitor_reflex.rb`

```ruby
def setup_view_variables
  # Set up all instance variables needed by the view
  # This mirrors what the controller's show action does
  @league = @party.league
  @assigned_players_a_ids = Player.joins(:seedings).where(seedings: { role: "team_a", tournament_type: "Party",
                                                                      tournament_id: @party.id }).order("players.lastname").ids
  # ... (full implementation in the file)
end
```

### 2. Modified `load_objects` to Call `setup_view_variables`

```ruby
def load_objects
  @party_monitor = PartyMonitor.find(element.dataset["id"])
  @party = @party_monitor.party
  setup_view_variables  # Added this line
end
```

### 3. Added Admin Security Check to `reset_party_monitor`

Also fixed a security issue where the `reset_party_monitor` method was missing an admin check that was present in the `carambus_bcw` version:

```ruby
def reset_party_monitor
  unless current_user&.admin?
    flash[:alert] = "Nur Administratoren können den Party Monitor zurücksetzen."
    Rails.logger.warn "Unauthorized reset_party_monitor attempt by user: #{current_user&.id}"
    return
  end
  # ... rest of method
end
```

## How StimulusReflex Works

For context, here's how StimulusReflex handles updates:

1. **User clicks button** → Triggers reflex (e.g., `assign_player_a`)
2. **Server executes reflex method** → Database changes happen
3. **Instance variables are set** → From `before_reflex :load_objects` and `setup_view_variables`
4. **View is re-rendered** → Using the current controller action's view template
5. **DOM is morphed** → StimulusReflex intelligently updates only changed parts
6. **User sees update** → Instant feedback!

Without step 3 properly setting instance variables, step 4 fails silently, resulting in no UI update.

## Testing

After this fix:
1. Clicking "Melden" (assign) button should immediately move players between lists
2. Clicking "Abmelden" (remove) button should immediately move players back
3. Player counts `[X]` should update in real-time
4. No server restart should be needed to see changes

## Related Files

- `/app/javascript/controllers/party_monitor_controller.js` - The Stimulus controller (CREATED)
- `/app/reflexes/party_monitor_reflex.rb` - The reflex file (MODIFIED)
- `/app/controllers/party_monitors_controller.rb` - Controller with original `show` action logic
- `/app/views/party_monitors/show.html.erb` - Uses `data-controller="party_monitor"`
- `/app/views/party_monitors/_party_monitor.html.erb` - The view that requires these variables

## Deployment

Remember: Changes must be made in `carambus_master` directory only, then committed and pushed. Other scenario directories will get the updates through `deploy-scenario` scripts or git pull.

