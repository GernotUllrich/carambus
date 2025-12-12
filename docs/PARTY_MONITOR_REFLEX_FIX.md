# PartyMonitor Reflex Issue - Root Cause Analysis

## Problem
PartyMonitor reflex actions (assign_player, remove_player) were not providing immediate UI feedback in development environment. The same code worked perfectly in production.

## Root Cause
**Stale JavaScript assets in development.**

The `app/assets/builds/application.js` file was from Nov 28, while testing was on Dec 12. The outdated JavaScript build was missing critical updates or had cached versions of StimulusReflex handlers.

## Solution
Rebuild JavaScript assets:

```bash
cd carambus_master
yarn build
yarn build:css
```

Then restart the Rails development server.

## Key Learnings

1. **Always check asset build dates** when reflexes/Stimulus controllers behave unexpectedly in development
2. **Production works differently** because deployment always rebuilds assets fresh
3. **StimulusReflex's default behavior is perfect** - no need for explicit `morph` commands, `redirect_to`, or custom JavaScript
4. The simple reflex pattern works:
   - Modify the database
   - Let StimulusReflex automatically re-render the controller action
   - The controller sets fresh instance variables
   - The view gets updated automatically

## Original Working Code

The PartyMonitorReflex should be kept simple:

```ruby
def assign_player(ab)
  assigned_players_ids = Player.joins(:seedings).where(seedings: { tournament: @party, role: "team_#{ab}" }).ids
  add_ids = Array(params["availablePlayer#{ab.upcase}Id"]).map(&:to_i) - assigned_players_ids
  add_ids.each do |pid|
    Seeding.create(player_id: pid, tournament: @party, role: "team_#{ab}", position: 1)
  end
  Rails.logger.info "======== assign_player_#{ab}"
rescue StandardError => e
  Rails.logger.info "======== #{e} #{e.backtrace}"
end

private

def load_objects
  @party_monitor = PartyMonitor.find(element.dataset["id"])
  @party = @party_monitor.party
end
```

No explicit morphing, no instance variable setup in the reflex - just database operations.

## When StimulusReflex Doesn't Work

Before diving into code changes, check:

1. ✅ Are JavaScript assets up to date? (`ls -lh app/assets/builds/application.js`)
2. ✅ Is Redis running? (`redis-cli ping`)
3. ✅ Are there WebSocket connection errors in browser console?
4. ✅ Are there ActionCable errors in Rails logs?
5. ✅ Is the Stimulus controller connected? (check browser console)

## Development vs Production Differences

| Aspect | Development | Production |
|--------|------------|------------|
| Assets | Manual rebuild needed | Auto-rebuilt on deploy |
| Caching | Often disabled | Enabled |
| WebSockets | Local Redis | Production Redis |
| JavaScript | Source maps available | Minified |

## Prevention

Consider adding a pre-commit hook or reminder to rebuild assets after pulling changes that might affect JavaScript controllers or StimulusReflex behavior.
